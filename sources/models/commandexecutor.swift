import Foundation
import Darwin

enum CommandCategory: String, Equatable {
    case readOnly
    case reversibleMutation
    case destructiveMutation
    case privilegedOrUnsupported
}

enum CommandExecutorError: LocalizedError {
    case executablePathMustBeAbsolute

    var errorDescription: String? {
        switch self {
        case .executablePathMustBeAbsolute:
            return "The executable path must be absolute."
        }
    }
}

struct CommandResult {
    let standardOutput: String
    let standardError: String
    let terminationStatus: Int32?
    let wasTerminated: Bool
    let didTimeOut: Bool
    let wasCancelled: Bool
    let standardOutputWasTruncated: Bool
    let standardErrorWasTruncated: Bool
    let category: CommandCategory
    let launchError: Error?

    var succeeded: Bool {
        !didTimeOut && !wasCancelled && !wasTerminated && launchError == nil && terminationStatus == 0
    }
}

private final class CommandDataBuffer {
    private let lock = NSLock()
    private var value = Data()
    private var truncated = false

    func capture(from handle: FileHandle, maximumBytes: Int) {
        var captured = Data()
        var didTruncate = false

        while true {
            let chunk = handle.readData(ofLength: 64 * 1024)
            guard !chunk.isEmpty else { break }

            let remaining = maximumBytes - captured.count
            if remaining > 0 {
                captured.append(chunk.prefix(remaining))
            }
            if chunk.count > max(remaining, 0) {
                didTruncate = true
            }
        }

        lock.lock()
        value = captured
        truncated = didTruncate
        lock.unlock()
    }

    func snapshot() -> (data: Data, wasTruncated: Bool) {
        lock.lock()
        defer { lock.unlock() }
        return (value, truncated)
    }
}

final class CommandExecutor {
    static let shared = CommandExecutor()

    private init() {}

    @discardableResult
    func run(
        executablePath: String,
        arguments: [String] = [],
        currentDirectoryURL: URL? = nil,
        timeout: TimeInterval = 30,
        category: CommandCategory = .readOnly,
        maximumOutputBytes: Int = 1_048_576,
        cancellationCheck: (() -> Bool)? = nil
    ) -> CommandResult {
        guard executablePath.hasPrefix("/") else {
            return CommandResult(
                standardOutput: "",
                standardError: "",
                terminationStatus: nil,
                wasTerminated: false,
                didTimeOut: false,
                wasCancelled: false,
                standardOutputWasTruncated: false,
                standardErrorWasTruncated: false,
                category: category,
                launchError: CommandExecutorError.executablePathMustBeAbsolute
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            return CommandResult(
                standardOutput: "",
                standardError: "",
                terminationStatus: nil,
                wasTerminated: false,
                didTimeOut: false,
                wasCancelled: false,
                standardOutputWasTruncated: false,
                standardErrorWasTruncated: false,
                category: category,
                launchError: error
            )
        }

        let outputGroup = DispatchGroup()
        let outputData = CommandDataBuffer()
        let errorData = CommandDataBuffer()

        outputGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            outputData.capture(from: outputPipe.fileHandleForReading, maximumBytes: max(0, maximumOutputBytes))
            outputGroup.leave()
        }

        outputGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            errorData.capture(from: errorPipe.fileHandleForReading, maximumBytes: max(0, maximumOutputBytes))
            outputGroup.leave()
        }

        let effectiveTimeout = timeout.isFinite ? max(0, timeout) : 30
        let deadline = Date().addingTimeInterval(effectiveTimeout)
        var wasCancelled = cancellationCheck?() == true
        while process.isRunning && Date() < deadline {
            if cancellationCheck?() == true {
                wasCancelled = true
                break
            }
            Thread.sleep(forTimeInterval: 0.01)
        }

        let didTimeOut = process.isRunning && !wasCancelled && Date() >= deadline
        if process.isRunning {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.1)
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
        }

        process.waitUntilExit()
        outputGroup.wait()
        let outputSnapshot = outputData.snapshot()
        let errorSnapshot = errorData.snapshot()

        return CommandResult(
            standardOutput: String(data: outputSnapshot.data, encoding: .utf8) ?? "",
            standardError: String(data: errorSnapshot.data, encoding: .utf8) ?? "",
            terminationStatus: process.terminationStatus,
            wasTerminated: didTimeOut || wasCancelled || process.terminationReason == .uncaughtSignal,
            didTimeOut: didTimeOut,
            wasCancelled: wasCancelled,
            standardOutputWasTruncated: outputSnapshot.wasTruncated,
            standardErrorWasTruncated: errorSnapshot.wasTruncated,
            category: category,
            launchError: nil
        )
    }
}
