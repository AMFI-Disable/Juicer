import SwiftUI

struct ScriptTemplate: Identifiable {
    let id = UUID()
    let name: String
    let desc: String
    let code: String
    let icon: String
}

/// Thread-safe UTF-8 output decoder that buffers partial multi-byte sequences across streaming chunks.
private final class ScriptOutputDecoder: @unchecked Sendable {
    private var leftoverData = Data()
    private let lock = NSLock()

    func decode(_ newData: Data) -> String {
        lock.lock()
        defer { lock.unlock() }

        var combined = leftoverData + newData
        guard !combined.isEmpty else { return "" }

        let validLength = utf8ValidPrefixLength(in: combined)
        let validData = combined.prefix(validLength)
        leftoverData = combined.dropFirst(validLength)

        return String(decoding: validData, as: UTF8.self)
    }

    func flush() -> String {
        lock.lock()
        defer { lock.unlock() }

        guard !leftoverData.isEmpty else { return "" }
        let str = String(decoding: leftoverData, as: UTF8.self)
        leftoverData.removeAll()
        return str
    }

    private func utf8ValidPrefixLength(in data: Data) -> Int {
        let count = data.count
        guard count > 0 else { return 0 }

        var lookback = 1
        while lookback <= min(4, count) {
            let byte = data[count - lookback]
            if (byte & 0x80) == 0 {
                return count
            } else if (byte & 0xC0) == 0xC0 {
                var expectedLength = 1
                if (byte & 0xE0) == 0xC0 { expectedLength = 2 } else if (byte & 0xF0) == 0xE0 { expectedLength = 3 } else if (byte & 0xF8) == 0xF0 { expectedLength = 4 }

                if lookback < expectedLength {
                    return count - lookback
                } else {
                    return count
                }
            }
            lookback += 1
        }
        return count
    }
}

struct scriptconsoleview: View {
    @State private var scriptCode: String = ""
    @State private var consoleOutput: String = ""
    @State private var isRunning = false
    @State private var activeProcess: Process?
    @State private var executionTask: Task<Void, Never>?
    @State private var isCancelled = false
    @State private var showExecutionConfirmation = false

    private let defaultTimeoutInterval: TimeInterval = 120.0
    private let maxConsoleLength: Int = 100_000

    private let templates = [
        ScriptTemplate(name: "Flush DNS Cache", desc: "Flush macOS resolver and restart mDNSResponder service.", code: "dscacheutil -flushcache; sudo killall -HUP mDNSResponder\necho '✅ DNS Cache flushed successfully.'", icon: "network"),
        ScriptTemplate(name: "Free Inactive RAM", desc: "Forcibly purge memory caches using macOS system purge.", code: "sudo purge\necho '✅ RAM Purge completed.'", icon: "cpu"),
        ScriptTemplate(name: "Restart Finder & Dock", desc: "Kill and relaunch system Finder window and Dock workspace.", code: "killall Finder; killall Dock\necho '✅ Workspace restarted successfully.'", icon: "window.badge.ellipsis"),
        ScriptTemplate(name: "Clean Xcode Simulators", desc: "Reclaim space by erasing simulated device runtimes.", code: "xcrun simctl erase all\necho '✅ Simulator runtimes cleaned.'", icon: "iphone"),
        ScriptTemplate(name: "Prune Docker system", desc: "Reclaim space by removing stopped containers, unused networks/images.", code: "docker system prune -a --volumes -f\necho '✅ Docker cleanup finished.'", icon: "shippingbox.fill")
    ]

    var body: some View {
        VStack(spacing: 0) {
            headerBar()
            Divider()

            HSplitView {
                // Left Column: Templates selection
                VStack(alignment: .leading, spacing: 0) {
                    Text("Script Library")
                        .font(.headline)
                        .padding()

                    Divider()

                    List(templates) { template in
                        Button(action: { scriptCode = template.code }) {
                            HStack(spacing: 12) {
                                Image(systemName: template.icon)
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.name).font(.subheadline).bold()
                                    Text(template.desc).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.inset)
                }
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 340)

                // Right Column: Editor & Terminal Console
                VStack(spacing: 16) {
                    // Editor Panel
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Script Editor").font(.headline)
                            Spacer()
                            if isRunning {
                                Button("Cancel Action") {
                                    cancelExecution()
                                }
                                .buttonStyle(.bordered).tint(.red)
                            } else {
                                Button(action: { showExecutionConfirmation = true }) {
                                    Label("Execute Script", systemImage: "play.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(scriptCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }

                        TextEditor(text: $scriptCode)
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
                            .frame(minHeight: 180)
                    }

                    // Console Output Terminal
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Execution Console Logs").font(.headline)
                            Spacer()
                            Button("Clear Console") {
                                consoleOutput = ""
                            }
                            .buttonStyle(.bordered).controlSize(.small)
                        }

                        ScrollViewReader { proxy in
                            ScrollView {
                                Text(consoleOutput.isEmpty ? "Ready to run. Execution outputs will stream here in real time." : consoleOutput)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(consoleOutput.isEmpty ? .secondary : .primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .id("console_bottom")
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
                            .onChange(of: consoleOutput) { _ in
                                proxy.scrollTo("console_bottom", anchor: .bottom)
                            }
                        }
                    }
                }
                .padding()
                .frame(minWidth: 400, maxWidth: .infinity)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onDisappear {
            if isRunning {
                cancelExecution()
            }
        }
        .alert("Confirm Script Execution", isPresented: $showExecutionConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Execute", role: .destructive) { runScript() }
        } message: {
            Text("This runs executable shell code with a 120-second timeout and bounded output. Review the script, interpreter, environment, and targets before continuing.")
        }
    }

    @ViewBuilder
    private func headerBar() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Custom Scripts Console")
                    .font(.title2).bold()
                Text("Executable shell code • review path/interpreter, environment, 120-second timeout, and 100,000-character output cap before running.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - Process Execution Runner

    private func appendConsoleOutput(_ text: String) {
        guard !text.isEmpty else { return }
        consoleOutput += StudioSecretRedactor.redact(text)
        if consoleOutput.count > maxConsoleLength {
            let overflow = consoleOutput.count - maxConsoleLength
            let index = consoleOutput.index(consoleOutput.startIndex, offsetBy: overflow)
            consoleOutput = "⚠️ [Console output truncated to limit memory usage]\n" + String(consoleOutput[index...])
        }
    }

    private func runScript() {
        guard !isRunning else { return }
        let commandStr = scriptCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !commandStr.isEmpty else { return }

        isRunning = true
        isCancelled = false
        consoleOutput = "⏳ Initializing shell execution session (Timeout: \(Int(defaultTimeoutInterval))s)...\n\n"

        executionTask = Task.detached(priority: .userInitiated) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/sh")
            proc.arguments = ["-c", commandStr]

            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            await MainActor.run {
                self.activeProcess = proc
            }

            let decoder = ScriptOutputDecoder()
            let fileHandle = pipe.fileHandleForReading

            fileHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                let text = decoder.decode(data)
                if !text.isEmpty {
                    DispatchQueue.main.async {
                        self.appendConsoleOutput(text)
                    }
                }
            }

            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(self.defaultTimeoutInterval * 1_000_000_000))
                if !Task.isCancelled {
                    await MainActor.run {
                        if self.isRunning && self.activeProcess === proc {
                            self.appendConsoleOutput("\n⚠️ Script execution timed out (exceeded limit of \(Int(self.defaultTimeoutInterval))s). Terminating process...\n")
                            self.terminateProcess(proc)
                        }
                    }
                }
            }

            var startError: Error?
            do {
                try proc.run()
                proc.waitUntilExit()
            } catch {
                startError = error
            }

            timeoutTask.cancel()

            fileHandle.readabilityHandler = nil
            let remainingData = (try? fileHandle.readToEnd()) ?? Data()
            let finalOutput = decoder.decode(remainingData) + decoder.flush()

            if !finalOutput.isEmpty {
                await MainActor.run {
                    self.appendConsoleOutput(finalOutput)
                }
            }
            try? fileHandle.close()

            let exitStatus = proc.terminationStatus

            await MainActor.run {
                guard self.activeProcess === proc || self.isRunning else { return }
                let processWasCancelled = self.isCancelled
                self.isRunning = false
                self.activeProcess = nil
                self.executionTask = nil

                if let err = startError {
                    self.appendConsoleOutput("\n❌ System execution error: \(err.localizedDescription)\n")
                } else if processWasCancelled {
                    self.appendConsoleOutput("\n🛑 Execution aborted by user.\n")
                } else if exitStatus == 0 {
                    self.appendConsoleOutput("\n✅ Script completed successfully (Exit Code 0).\n")
                } else {
                    self.appendConsoleOutput("\n❌ Script terminated with non-zero exit code \(exitStatus).\n")
                }
            }
        }
    }

    private func cancelExecution() {
        guard isRunning else { return }
        isCancelled = true
        if let proc = activeProcess {
            terminateProcess(proc)
        }
        executionTask?.cancel()
        executionTask = nil
    }

    private func terminateProcess(_ proc: Process) {
        guard proc.isRunning else { return }
        proc.terminate()

        let pid = proc.processIdentifier
        if pid > 0 {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5) {
                if proc.isRunning {
                    kill(pid, SIGKILL)
                }
            }
        }
    }
}
