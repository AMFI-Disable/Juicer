import SwiftUI
import AppKit

// MARK: - Models

struct FinderSelectedItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let path: String
    let name: String
    let isDirectory: Bool
    let sizeBytes: Int64
    let modificationDate: Date?

    init(path: String, isDirectory: Bool = false, sizeBytes: Int64 = 0, modificationDate: Date? = nil) {
        self.id = UUID()
        self.path = path
        self.name = (path as NSString).lastPathComponent
        self.isDirectory = isDirectory
        self.sizeBytes = sizeBytes
        self.modificationDate = modificationDate
    }
}

// MARK: - Manager

@MainActor
final class FinderSelectionManager: ObservableObject {
    @Published var selectedItems: [FinderSelectedItem] = []
    @Published var isFetching: Bool = false
    @Published var statusMessage: String = "Ready to inspect Finder selection."
    @Published var errorMessage: String?
    @Published var lastFetchTime: Date?
    @Published var timeoutSeconds: Double = 3.0

    private var fetchTask: Task<Void, Never>?

    deinit {
        fetchTask?.cancel()
    }

    /// Fetches currently selected items from Finder using a bounded AppleScript execution timeout.
    func fetchFinderSelection() {
        fetchTask?.cancel()
        isFetching = true
        errorMessage = nil
        statusMessage = "Querying Finder selection..."

        let timeout = timeoutSeconds

        fetchTask = Task { [weak self] in
            guard let self else { return }

            let result = await Self.executeAppleScriptSelection(timeoutSeconds: timeout)

            guard !Task.isCancelled else { return }

            switch result {
            case .success(let paths):
                let items = Self.processPaths(paths)
                self.selectedItems = items
                self.isFetching = false
                self.lastFetchTime = Date()
                if items.isEmpty {
                    self.statusMessage = "No items currently selected in Finder."
                } else {
                    self.statusMessage = "Successfully fetched \(items.count) item(s) from Finder."
                }
            case .failure(let error):
                self.selectedItems = []
                self.isFetching = false
                self.errorMessage = error.localizedDescription
                self.statusMessage = "Failed to fetch Finder selection: \(error.localizedDescription)"
            }
        }
    }

    func clearSelection() {
        fetchTask?.cancel()
        selectedItems = []
        errorMessage = nil
        statusMessage = "Selection cleared."
    }

    // MARK: - Nonisolated Helpers for Bounded AppleScript Execution

    private enum AppleScriptError: LocalizedError {
        case timedOut(seconds: Double)
        case scriptExecutionFailed(String)
        case invalidScriptOutput

        var errorDescription: String? {
            switch self {
            case .timedOut(let seconds):
                return "AppleScript execution timed out after \(String(format: "%.1f", seconds)) seconds. Finder may be unresponsive."
            case .scriptExecutionFailed(let message):
                return "AppleScript execution failed: \(message)"
            case .invalidScriptOutput:
                return "Received invalid output from Finder AppleScript."
            }
        }
    }

    private static nonisolated func executeAppleScriptSelection(timeoutSeconds: Double) async -> Result<[String], AppleScriptError> {
        let scriptSource = """
        tell application "Finder"
            try
                set theSelection to selection
                if theSelection is {} then
                    return ""
                end if
                set pathList to {}
                repeat with anItem in theSelection
                    set end of pathList to (POSIX path of (anItem as alias))
                end repeat
                set AppleScript's text item delimiters to linefeed
                return pathList as string
            on error errMsg
                return "ERROR:" & errMsg
            end try
        end tell
        """

        return await withTaskGroup(of: Result<[String], AppleScriptError>.self) { group in
            group.addTask {
                return await Task.detached(priority: .userInitiated) { () -> Result<[String], AppleScriptError> in
                    var errorDict: NSDictionary?
                    guard let script = NSAppleScript(source: scriptSource) else {
                        return .failure(.scriptExecutionFailed("Could not initialize NSAppleScript."))
                    }

                    let descriptor = script.executeAndReturnError(&errorDict)

                    if let errorDict = errorDict {
                        let msg = errorDict[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                        return .failure(.scriptExecutionFailed(msg))
                    }

                    guard let stringValue = descriptor.stringValue else {
                        return .success([])
                    }

                    if stringValue.hasPrefix("ERROR:") {
                        let errMsg = String(stringValue.dropFirst(6))
                        return .failure(.scriptExecutionFailed(errMsg))
                    }

                    let paths = stringValue
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }

                    return .success(paths)
                }.value
            }

            group.addTask {
                let nanoseconds = UInt64(max(0.5, timeoutSeconds) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                return .failure(.timedOut(seconds: timeoutSeconds))
            }

            if let firstResult = await group.next() {
                group.cancelAll()
                return firstResult
            }

            return .failure(.timedOut(seconds: timeoutSeconds))
        }
    }

    private static nonisolated func processPaths(_ paths: [String]) -> [FinderSelectedItem] {
        let fm = FileManager.default
        return paths.map { path in
            var isDir: ObjCBool = false
            let exists = fm.fileExists(atPath: path, isDirectory: &isDir)
            var size: Int64 = 0
            var modDate: Date?

            if exists {
                if let attrs = try? fm.attributesOfItem(atPath: path) {
                    size = (attrs[.size] as? Int64) ?? 0
                    modDate = attrs[.modificationDate] as? Date
                }
            }

            return FinderSelectedItem(
                path: path,
                isDirectory: isDir.boolValue,
                sizeBytes: size,
                modificationDate: modDate
            )
        }
    }
}

// MARK: - View

struct finderselectionview: View {
    @StateObject private var manager = FinderSelectionManager()

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            Divider()

            controlsSection
                .padding()

            if manager.isFetching {
                fetchingPlaceholder
            } else if let error = manager.errorMessage {
                errorPlaceholder(error)
            } else if manager.selectedItems.isEmpty {
                emptyPlaceholder
            } else {
                itemsList
            }

            statusBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header
    private var headerSection: some View {
        JuicerFeatureHeader(
            title: "Finder Selection Inspector",
            subtitle: "Query, inspect, and process items currently selected in macOS Finder with timeout protection.",
            icon: "macwindow.on.rectangle",
            refreshing: manager.isFetching,
            action: { manager.fetchFinderSelection() }
        )
        .accessibilityLabel("Finder Selection Inspector header")
        .accessibilityHint("Shows overview and refresh button for inspecting current Finder selection")
        .padding()
    }

    // MARK: - Controls
    private var controlsSection: some View {
        HStack(spacing: 16) {
            Button(action: { manager.fetchFinderSelection() }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                    Text("Fetch Selection")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(manager.isFetching)
            .accessibilityLabel("Fetch Finder selection button")
            .accessibilityHint("Triggers AppleScript query to fetch currently selected files in Finder")

            Button(action: { manager.clearSelection() }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text("Clear")
                }
            }
            .buttonStyle(.bordered)
            .disabled(manager.selectedItems.isEmpty && manager.errorMessage == nil)
            .accessibilityLabel("Clear selection button")
            .accessibilityHint("Clears current list of fetched Finder items")

            Spacer()

            HStack(spacing: 8) {
                Text("Timeout:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Picker("AppleScript Timeout", selection: $manager.timeoutSeconds) {
                    Text("1.5s").tag(1.5)
                    Text("3.0s").tag(3.0)
                    Text("5.0s").tag(5.0)
                    Text("10.0s").tag(10.0)
                }
                .pickerStyle(.menu)
                .frame(width: 90)
                .accessibilityLabel("AppleScript selection timeout")
                .accessibilityHint("Select maximum allowed execution time for Finder AppleScript query in seconds")
                .accessibilityValue("\(String(format: "%.1f", manager.timeoutSeconds)) seconds")
            }
        }
    }

    // MARK: - Placeholders
    private var fetchingPlaceholder: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Fetching items from Finder...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Fetching items from Finder")
        .accessibilityAddTraits(.isHeader)
    }

    private func errorPlaceholder(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("Failed to Fetch Finder Selection")
                .font(.headline)
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retry") {
                manager.fetchFinderSelection()
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Retry fetching Finder selection")
            .accessibilityHint("Retries AppleScript query to get selection from Finder")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No Finder Items Selected")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Select one or more files/folders in Finder and click 'Fetch Selection'.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No Finder items selected. Select items in Finder and click Fetch Selection.")
    }

    // MARK: - List
    private var itemsList: some View {
        List(manager.selectedItems) { item in
            HStack(spacing: 12) {
                Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                    .foregroundColor(item.isDirectory ? .accentColor : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body.weight(.medium))
                    Text(item.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                if !item.isDirectory {
                    Text(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(action: {
                    NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                }) {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(.borderless)
                .help("Reveal in Finder")
                .accessibilityLabel("Reveal \(item.name) in Finder")
                .accessibilityHint("Opens Finder window highlighting \(item.name)")
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(item.isDirectory ? "Folder" : "File"): \(item.name)")
            .accessibilityValue(item.isDirectory ? item.path : "\(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file)), \(item.path)")
        }
        .listStyle(.inset)
        .accessibilityLabel("List of selected Finder items")
    }

    // MARK: - Status Bar
    private var statusBar: some View {
        HStack {
            Text(manager.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if let lastFetch = manager.lastFetchTime {
                Text("Last updated: \(lastFetch, formatter: Self.timeFormatter)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Finder Selection Status")
        .accessibilityValue(manager.statusMessage)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()
}

typealias FinderSelectionView = finderselectionview
