import SwiftUI
import Charts

@MainActor
struct diskexplorerview: View {
    @StateObject private var manager = DiskExplorerManager()
    @State private var pathInput: String = ""
    @State private var selectedEntry: DiskEntry?
    @State private var viewMode: ViewMode = .treemap
    @State private var selectedVolume: DiskVolume?

    enum ViewMode: String, CaseIterable {
        case treemap = "Bar Map"
        case list    = "File List"
    }

    private var isAtRootOrEmpty: Bool {
        let current = manager.currentPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty || current == "/" { return true }
        let standardized = URL(fileURLWithPath: current).standardized.path
        return standardized == "/" || standardized.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection()
            Divider()
            volumeBar()
            Divider()
            if isAtRootOrEmpty || manager.currentPath == FileManager.default.homeDirectoryForCurrentUser.path {
                storageForecastSection()
                Divider()
            }
            navigationBar()
            Divider()

            HStack(spacing: 8) {
                Image(systemName: manager.scanState == .completed ? "checkmark.circle" : "externaldrive")
                Text(scanSummary)
                Spacer()
                if let metadata = manager.scanMetadata { Text("Visited (metadata.entriesVisited) entries • source (metadata.sourcePath)").font(.caption2).foregroundStyle(.secondary) }
            }
            .font(.caption)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.05))

            if manager.isScanning {
                scanningPlaceholder()
            } else if manager.entries.isEmpty && manager.errorMessage == nil {
                emptyStatePlaceholder()
            } else {
                contentView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            manager.loadVolumes()
            let activeDir = WorkspaceDirectoryManager.shared.currentDirectory
            pathInput = (activeDir as NSString).standardizingPath
            manager.scanDirectory(path: activeDir)
        }
        .onReceive(WorkspaceDirectoryManager.shared.$currentDirectory) { newDir in
            guard !newDir.isEmpty else { return }
            let safeDir = (newDir as NSString).standardizingPath
            if manager.currentPath != safeDir {
                pathInput = safeDir
                manager.scanDirectory(path: safeDir)
            }
        }
    }

    private var scanSummary: String {
        switch manager.scanState {
        case .idle: return "No disk scan has run."
        case .scanning(let progress): return "Scanning (Int(progress * 100))% — read-only analysis"
        case .completed: return "Scan complete — (manager.entries.count) entries analyzed."
        case .cancelled: return "Scan cancelled. Retry to refresh results."
        case .failed(let error): return "Scan failed: (error)"
        case .timedOut: return "Scan timed out. Choose a smaller folder and retry."
        }
    }

    // MARK: - Header
    @ViewBuilder
    private func headerSection() -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Disk Explorer")
                    .font(.title2).bold()
                Text("Visualize disk usage across volumes and folders. Select a volume or browse any path.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()

            Picker("View Mode", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            .accessibilityLabel("View mode selector")
            .accessibilityHint("Switch between Bar Map and File List visualization modes")

            Button(action: { manager.scanDirectory(path: manager.currentPath) }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(manager.isScanning)
            .help("Rescan current path")
            .accessibilityLabel("Rescan current directory")
            .accessibilityHint("Rescans the active directory for disk usage changes")
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
    }

    // MARK: - Volume Bar (all mounted disks including external)
    @ViewBuilder
    private func volumeBar() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(manager.volumes) { vol in
                    volumeCard(volume: vol)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.2))
        .frame(height: 84)
        .accessibilityLabel("Mounted Disks and Volumes")
    }

    @ViewBuilder
    private func volumeCard(volume: DiskVolume) -> some View {
        let isSelected = selectedVolume?.id == volume.id
        Button(action: {
            selectedVolume = volume
            let safeMount = (volume.mountPoint as NSString).standardizingPath
            pathInput = safeMount
            manager.scanVolume(volume)
        }) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: volume.icon)
                        .font(.caption).foregroundStyle(isSelected ? .white : .accentColor)
                        .accessibilityHidden(true)
                    Text(volume.name)
                        .font(.caption).bold().lineLimit(1)
                        .foregroundStyle(isSelected ? .white : .primary)
                    if volume.isRemovable {
                        Image(systemName: "eject.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                            .accessibilityHidden(true)
                    }
                }

                // Mini usage bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isSelected ? Color.white.opacity(0.25) : Color.secondary.opacity(0.2))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isSelected ? Color.white : volumeUsageColor(volume.usagePercent))
                            .frame(width: max(0, min(geo.size.width * volume.usagePercent, geo.size.width)))
                    }
                }
                .frame(height: 5)

                HStack {
                    Text(formatBytes(volume.usedBytes))
                        .font(.caption2)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                    Spacer()
                    Text(formatBytes(volume.totalBytes))
                        .font(.caption2)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.65) : Color.secondary.opacity(0.7))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(width: 160)
            .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), lineWidth: 1))
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(volume.name) volume\(volume.isRemovable ? ", removable" : "")")
        .accessibilityValue("\(formatBytes(volume.usedBytes)) used of \(formatBytes(volume.totalBytes)), \(Int(volume.usagePercent * 100)) percent full")
        .accessibilityHint(isSelected ? "Currently selected volume" : "Double-tap to select and scan this volume")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }

    // MARK: - Navigation Bar
    @ViewBuilder
    private func navigationBar() -> some View {
        HStack(spacing: 8) {
            // Back button
            Button(action: goUp) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.bordered)
            .disabled(isAtRootOrEmpty || manager.isScanning)
            .help("Go up one level")
            .accessibilityLabel("Go to parent directory")
            .accessibilityHint("Navigates up one level in the directory tree")

            // Home
            Button(action: {
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                navigateToPath(home)
            }) {
                Image(systemName: "house.fill")
            }
            .buttonStyle(.bordered)
            .help("Go to Home directory")
            .accessibilityLabel("Go to Home directory")
            .accessibilityHint("Navigates directly to your user home folder")

            // Breadcrumb path field
            Image(systemName: "folder.fill").foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Enter path or pick a folder…", text: $pathInput, onCommit: {
                navigateToPath(pathInput)
            })
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("Directory Path Input")
            .accessibilityHint("Type a file system path to explore")

            // Browse button — shows folder AND disk picker
            Button("Browse…") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                panel.showsHiddenFiles = false
                // Allow navigation to volumes
                let startPath = manager.currentPath.isEmpty ?
                    FileManager.default.homeDirectoryForCurrentUser.path : manager.currentPath
                panel.directoryURL = URL(fileURLWithPath: (startPath as NSString).standardizingPath)
                panel.prompt = "Scan This Folder"
                panel.message = "Select a folder or navigate to a volume to scan:"
                if panel.runModal() == .OK, let url = panel.url {
                    navigateToPath(url.path)
                }
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Browse Directory")
            .accessibilityHint("Opens a file picker dialog to choose a folder for disk analysis")

            // Go button
            Button("Go") {
                navigateToPath(pathInput)
            }
            .buttonStyle(.borderedProminent)
            .disabled(pathInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manager.isScanning)
            .accessibilityLabel("Navigate to entered path")
            .accessibilityHint("Scans the directory specified in the path input field")
        }
        .padding(.horizontal).padding(.vertical, 7)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.15))
    }

    // MARK: - Content
    @ViewBuilder
    private func contentView() -> some View {
        if let err = manager.errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36)).foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text(err).font(.headline).foregroundStyle(.secondary)
                    .accessibilityLabel("Error message: \(err)")
                Button("Go Home") {
                    let home = FileManager.default.homeDirectoryForCurrentUser.path
                    navigateToPath(home)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Go Home")
                .accessibilityHint("Resets current path to home directory and rescans")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HSplitView {
                // Left: main content
                VStack(spacing: 0) {
                    if viewMode == .treemap {
                        treemapView()
                    } else {
                        fileListView()
                    }
                }
                .frame(minWidth: 380)

                // Right: detail panel
                if let selected = selectedEntry {
                    detailPanel(entry: selected)
                        .frame(width: 220)
                }
            }
        }
    }

    @ViewBuilder
    private func treemapView() -> some View {
        VStack(spacing: 0) {
            // Proportional Block Treemap Grid (Top 8 items)
            let topEntries = Array(manager.entries.prefix(8))
            let totalBytes = manager.entries.reduce(0) { $0 + max(0, $1.sizeBytes) }

            if totalBytes > 0 && !topEntries.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Visual Disk Distribution (Treemap Grid)").font(.headline)
                        .accessibilityAddTraits(.isHeader)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(Array(topEntries.enumerated()), id: \.element.id) { idx, entry in
                            let rawFraction = Double(entry.sizeBytes) / Double(totalBytes)
                            let fraction = min(max(rawFraction, 0.0), 1.0)
                            let colors: [Color] = [.blue, .purple, .teal, .orange, .pink, .indigo, .cyan, .mint]
                            let color = colors[idx % colors.count]

                            Button(action: {
                                selectedEntry = entry
                                if entry.isDirectory {
                                    navigateToPath(entry.path)
                                }
                            }) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                                            .accessibilityHidden(true)
                                        Text(entry.name)
                                            .font(.subheadline).bold()
                                            .lineLimit(1)
                                        Spacer()
                                        Text(String(format: "%.1f%%", fraction * 100))
                                            .font(.caption2).bold()
                                    }

                                    Spacer()

                                    HStack {
                                        Text(formatBytes(entry.sizeBytes))
                                            .font(.caption)
                                        Spacer()
                                        if entry.isDirectory {
                                            Text("Drill Down →").font(.caption2).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding()
                                .frame(height: CGFloat(min(max(140 * fraction + 50, 70), 300)))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(color.opacity(0.12))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.3), lineWidth: 1.5))
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(entry.name), \(entry.isDirectory ? "Folder" : "File")")
                            .accessibilityValue("\(formatBytes(entry.sizeBytes)), \(String(format: "%.1f", fraction * 100)) percent of total disk usage")
                            .accessibilityHint(entry.isDirectory ? "Double-tap to navigate into this directory" : "Double-tap to view details")
                        }
                    }
                    .padding(.bottom, 15)
                }
                .padding()
            }

            Divider()

            // Bar Map list below
            HStack {
                Text("Folder Size Breakdown")
                    .font(.headline).padding()
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(manager.entries.count) items")
                    .font(.caption).foregroundStyle(.secondary).padding()
            }
            Divider()
            ScrollView {
                VStack(spacing: 6) {
                    let total = totalBytes > 0 ? totalBytes : 1
                    let listEntries = Array(manager.entries.prefix(40))
                    ForEach(Array(listEntries.enumerated()), id: \.element.id) { idx, entry in
                        treemapRow(entry: entry, total: total, index: idx)
                    }
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private func treemapRow(entry: DiskEntry, total: Int64, index: Int) -> some View {
        let rawFraction = total > 0 ? Double(entry.sizeBytes) / Double(total) : 0
        let fraction = min(max(rawFraction, 0.0), 1.0)
        let colors: [Color] = [.blue, .purple, .teal, .orange, .pink, .indigo, .cyan, .mint]
        let color = colors[index % colors.count]

        Button(action: {
            selectedEntry = entry
            if entry.isDirectory {
                navigateToPath(entry.path)
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                    .foregroundStyle(entry.isDirectory ? color : .secondary)
                    .frame(width: 18)
                    .accessibilityHidden(true)

                Text(entry.name)
                    .font(.subheadline)
                    .lineLimit(1)
                    .frame(maxWidth: 180, alignment: .leading)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.opacity(0.1))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.opacity(0.75))
                            .frame(width: max(2, min(geo.size.width * fraction, geo.size.width)))
                    }
                }
                .frame(height: 16)

                Text(String(format: "%.1f%%", fraction * 100))
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .trailing)

                Text(formatBytes(entry.sizeBytes))
                    .font(.caption).bold()
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(selectedEntry?.id == entry.id ? color.opacity(0.12) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedEntry?.id == entry.id ? color.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.name), \(entry.isDirectory ? "Folder" : "File")")
        .accessibilityValue("\(formatBytes(entry.sizeBytes)), \(String(format: "%.1f", fraction * 100)) percent")
        .accessibilityHint(entry.isDirectory ? "Double-tap to explore folder" : "Double-tap to select")
    }

    @ViewBuilder
    private func fileListView() -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Name").frame(maxWidth: .infinity, alignment: .leading)
                Text("Type").frame(width: 70)
                Text("Size").frame(width: 90, alignment: .trailing)
            }
            .font(.caption2).bold().foregroundStyle(.secondary)
            .padding(.horizontal).padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.2))

            Divider()

            List(selection: Binding(get: { selectedEntry?.id },
                                    set: { id in selectedEntry = manager.entries.first { $0.id == id } })) {
                ForEach(manager.entries) { entry in
                    HStack {
                        Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                            .foregroundStyle(entry.isDirectory ? .blue : .secondary)
                            .frame(width: 18)
                            .accessibilityHidden(true)
                        Text(entry.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        Text(entry.isDirectory ? "Folder" : fileExtension(entry.name))
                            .font(.caption).foregroundStyle(.secondary).frame(width: 70)
                        Text(formatBytes(entry.sizeBytes))
                            .font(.caption).bold().frame(width: 90, alignment: .trailing)
                    }
                    .tag(entry.id)
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(entry.name), \(entry.isDirectory ? "Folder" : fileExtension(entry.name) + " file")")
                    .accessibilityValue(formatBytes(entry.sizeBytes))
                    .accessibilityHint(entry.isDirectory ? "Double-click to open directory" : "Click to select")
                    .onTapGesture(count: 2) {
                        if entry.isDirectory {
                            navigateToPath(entry.path)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    @ViewBuilder
    private func detailPanel(entry: DiskEntry) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(entry.isDirectory ? .blue : .secondary)
                    .accessibilityHidden(true)
                Text(entry.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity)
            .padding(.top)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                detailRow("Size", formatBytes(entry.sizeBytes))
                detailRow("Type", entry.isDirectory ? "Folder" : fileExtension(entry.name))
                detailRow("Path", entry.path)
            }
            .padding(.horizontal)

            Divider()

            VStack(spacing: 8) {
                if entry.isDirectory {
                    Button("Open in Finder") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: entry.path))
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Open folder in Finder")
                    .accessibilityHint("Opens \(entry.name) in macOS Finder")

                    Button("Explore Folder") {
                        navigateToPath(entry.path)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Explore folder contents")
                    .accessibilityHint("Navigates into \(entry.name) in Disk Explorer")
                } else {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.selectFile(entry.path, inFileViewerRootedAtPath: "")
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Reveal file in Finder")
                    .accessibilityHint("Highlights \(entry.name) inside its containing folder in Finder")
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption).lineLimit(3).truncationMode(.middle)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    @ViewBuilder
    private func scanningPlaceholder() -> some View {
        VStack(spacing: 16) {
            ProgressView(value: manager.scanProgress).frame(width: 240)
                .accessibilityLabel("Directory scan progress")
                .accessibilityValue("\(Int(manager.scanProgress * 100)) percent complete")
            Text("Scanning \(manager.currentPath.isEmpty ? "Home" : manager.currentPath)…")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func emptyStatePlaceholder() -> some View {
        VStack(spacing: 12) {
            Image(systemName: "internaldrive").font(.system(size: 40)).foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Nothing to show").font(.headline).foregroundStyle(.secondary)
            Text("Select a volume above or browse to a directory.").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nothing to show. Select a volume above or browse to a directory.")
    }

    // MARK: - Helpers
    private func goUp() {
        let current = manager.currentPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !current.isEmpty else { return }
        let url = URL(fileURLWithPath: current).standardized
        guard url.path != "/" else { return }
        let parent = url.deletingLastPathComponent().path
        guard !parent.isEmpty && parent != url.path else { return }
        let safeParent = (parent as NSString).standardizingPath
        WorkspaceDirectoryManager.shared.currentDirectory = safeParent
    }

    private func navigateToPath(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let standardized = (trimmed as NSString).standardizingPath
        pathInput = standardized
        WorkspaceDirectoryManager.shared.currentDirectory = standardized
    }

    private func formatBytes(_ bytes: Int64) -> String {
        guard bytes >= 0 else { return "—" }
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }

    private func fileExtension(_ name: String) -> String {
        let ext = (name as NSString).pathExtension
        return ext.isEmpty ? "File" : ext.uppercased()
    }

    private func volumeUsageColor(_ pct: Double) -> Color {
        pct > 0.9 ? .red : pct > 0.75 ? .orange : .accentColor
    }

    // MARK: - Storage Depletion Prediction View
    @ViewBuilder
    private func storageForecastSection() -> some View {
        VStack(spacing: 0) {
            if let days = manager.predictedDaysUntilFull {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: days <= 30 ? "exclamationmark.triangle.fill" : "info.circle.fill")
                            .foregroundColor(days <= 30 ? .red : .orange)
                            .font(.headline)
                            .accessibilityHidden(true)
                        Text("Storage Exhaustion Forecast")
                            .font(.headline)
                        Spacer()
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(days <= 7 ? "⚠️ Disk Full in ~\(days) Days!" : "Disk Full in ~\(days) Days")
                                .font(.title3).bold()
                                .foregroundColor(days <= 30 ? .red : .primary)
                            Text("Based on your daily growth rate of \(formatBytes(manager.dailyGrowthRate)).")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    if manager.storageHistory.count >= 2 {
                        Chart {
                            ForEach(manager.storageHistory) { snap in
                                LineMark(
                                    x: .value("Date", snap.timestamp, unit: .day),
                                    y: .value("Used Space (GB)", Double(snap.usedBytes) / 1_000_000_000.0)
                                )
                                .foregroundStyle(Color.accentColor)
                                .interpolationMethod(.catmullRom)

                                AreaMark(
                                    x: .value("Date", snap.timestamp, unit: .day),
                                    y: .value("Used Space (GB)", Double(snap.usedBytes) / 1_000_000_000.0)
                                )
                                .foregroundStyle(LinearGradient(colors: [Color.accentColor.opacity(0.15), Color.clear], startPoint: .top, endPoint: .bottom))
                                .interpolationMethod(.catmullRom)
                            }
                        }
                        .frame(height: 80)
                        .chartYScale(domain: Double(manager.storageHistory.map { $0.usedBytes }.min() ?? 0) / 1_000_000_000.0 - 5 ... Double(manager.storageHistory.map { $0.usedBytes }.max() ?? 0) / 1_000_000_000.0 + 5)
                        .padding(.top, 4)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Storage History Chart")
                        .accessibilityValue("Historical usage over \(manager.storageHistory.count) snapshots")
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
                .cornerRadius(12)
                .padding([.horizontal, .vertical])
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Storage Exhaustion Forecast")
                .accessibilityValue("Disk full predicted in approximately \(days) days at \(formatBytes(manager.dailyGrowthRate)) daily growth")
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        .accessibilityHidden(true)
                    Text("Disk Usage Trend: Stable. Extrapolated storage depletion is low.")
                        .font(.subheadline).foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.2))
                .cornerRadius(12)
                .padding([.horizontal, .vertical])
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Disk Usage Trend")
                .accessibilityValue("Stable. Extrapolated storage depletion is low.")
            }
        }
    }
}
