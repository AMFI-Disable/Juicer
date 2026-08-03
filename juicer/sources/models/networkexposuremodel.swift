import Foundation
import Combine

public enum ExposureClassification: String, Codable, CaseIterable, Identifiable {
    case localLoopback = "Local Loopback Only"
    case wildcardPublic = "Public / Wildcard Exposure"
    case specificIP = "Specific Network Binding"

    public var id: String { rawValue }
}

public struct NetworkListenerRecord: Identifiable, Codable, Equatable {
    public let id: String
    public let processName: String
    public let pid: Int
    public let user: String
    public let protocolType: String // IPv4 or IPv6
    public let bindAddress: String
    public let port: Int
    public let interface: String // e.g. "lo0", "all interfaces (*)"
    public let classification: ExposureClassification

    public init(id: String = UUID().uuidString, processName: String, pid: Int, user: String, protocolType: String, bindAddress: String, port: Int, interface: String, classification: ExposureClassification) {
        self.id = id
        self.processName = processName
        self.pid = pid
        self.user = user
        self.protocolType = protocolType
        self.bindAddress = bindAddress
        self.port = port
        self.interface = interface
        self.classification = classification
    }
}

public enum NetworkExposureState: Equatable {
    case idle
    case scanning
    case completed(count: Int)
    case failed(error: String)
}

public enum NetworkExposureParser {
    public static func parseLsofOutput(_ output: String) -> [NetworkListenerRecord] {
        var records: [NetworkListenerRecord] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("COMMAND") else { continue }

            let parts = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard parts.count >= 9 else { continue }

            let processName = parts[0]
            guard let pid = Int(parts[1]) else { continue }
            let user = parts[2]
            let proto = parts[4] // IPv4 or IPv6

            // Target name column is usually part 8, e.g. "*:7000" or "127.0.0.1:11434" or "*:7000 (LISTEN)"
            let nameCol = parts[8]
            let cleanName = nameCol.replacingOccurrences(of: "(LISTEN)", with: "").trimmingCharacters(in: .whitespaces)

            guard let lastColon = cleanName.range(of: ":", options: .backwards) else { continue }
            let bindHost = String(cleanName[..<lastColon.lowerBound])
            let portString = String(cleanName[lastColon.upperBound...])
            guard let port = Int(portString) else { continue }

            let classification: ExposureClassification
            let interfaceDescription: String

            if bindHost == "*" || bindHost == "0.0.0.0" || bindHost == "::" || bindHost == "[::]" {
                classification = .wildcardPublic
                interfaceDescription = "All Interfaces (*)"
            } else if bindHost == "127.0.0.1" || bindHost == "localhost" || bindHost == "::1" || bindHost == "[::1]" {
                classification = .localLoopback
                interfaceDescription = "Loopback (lo0)"
            } else {
                classification = .specificIP
                interfaceDescription = bindHost
            }

            records.append(NetworkListenerRecord(
                processName: processName,
                pid: pid,
                user: user,
                protocolType: proto,
                bindAddress: bindHost,
                port: port,
                interface: interfaceDescription,
                classification: classification
            ))
        }
        return records.sorted { $0.port < $1.port }
    }
}

@MainActor
public final class NetworkExposureManager: ObservableObject {
    public static let shared = NetworkExposureManager()

    @Published public private(set) var state: NetworkExposureState = .idle
    @Published public private(set) var records: [NetworkListenerRecord] = []
    @Published public var filterClassification: ExposureClassification? = nil
    @Published public var searchQuery: String = ""

    private init() {}

    public var filteredRecords: [NetworkListenerRecord] {
        records.filter { record in
            let matchesClassification = filterClassification == nil || record.classification == filterClassification
            let matchesSearch = searchQuery.isEmpty ||
                record.processName.localizedCaseInsensitiveContains(searchQuery) ||
                "\(record.pid)".contains(searchQuery) ||
                "\(record.port)".contains(searchQuery) ||
                record.bindAddress.localizedCaseInsensitiveContains(searchQuery)
            return matchesClassification && matchesSearch
        }
    }

    public func scanSockets() {
        state = .scanning
        records = []

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let task = Process()
            task.launchPath = "/usr/sbin/lsof"
            task.arguments = ["-nP", "-iTCP", "-sTCP:LISTEN"]
            let pipe = Pipe()
            let errPipe = Pipe()
            task.standardOutput = pipe
            task.standardError = errPipe

            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let parsed = NetworkExposureParser.parseLsofOutput(output)

                await MainActor.run {
                    self.records = parsed
                    self.state = .completed(count: parsed.count)
                }
            } catch {
                await MainActor.run {
                    self.state = .failed(error: error.localizedDescription)
                }
            }
        }
    }
}
