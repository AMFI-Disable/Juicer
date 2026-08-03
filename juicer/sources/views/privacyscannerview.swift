import SwiftUI
import AppKit

struct privacyscannerview: View {
    @StateObject private var manager = PrivacyScannerManager.shared

    var body: some View {
        VStack(spacing: 0) {
            headerSection()
            Divider()
            filterAndSearchBar()
            Divider()

            scanStatusView()
            Divider()

            recordsListView()
            Divider()
            footerBar()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if case .idle = manager.state {
                manager.startScan()
            }
        }
    }

    // MARK: - Header
    @ViewBuilder
    private func headerSection() -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("Privacy Scanner")
                        .font(.title2).bold()
                    Text("READ-ONLY AUDIT")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(Color.blue)
                        .cornerRadius(4)
                }
                Text("Audit installed applications for sensitive macOS permissions (Camera, Microphone, Disk Access, Location, Screen Recording).")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()

            if case .scanning = manager.state {
                Button("Cancel Scan") {
                    manager.cancelScan()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                Button(action: { manager.startScan() }) {
                    Label("Start Scan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
    }

    // MARK: - Filter & Search Bar
    @ViewBuilder
    private func filterAndSearchBar() -> some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Filter apps or bundle IDs…", text: $manager.searchQuery)
                    .textFieldStyle(.plain)
                if !manager.searchQuery.isEmpty {
                    Button(action: { manager.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .frame(maxWidth: 260)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button(action: { manager.filterCategory = nil }) {
                        Text("All Categories")
                            .font(.caption).bold()
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(manager.filterCategory == nil ? Color.accentColor : Color.secondary.opacity(0.1))
                            .foregroundStyle(manager.filterCategory == nil ? .white : .primary)
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)

                    ForEach(PermissionCategory.allCases) { cat in
                        Button(action: { manager.filterCategory = cat }) {
                            HStack(spacing: 4) {
                                Image(systemName: cat.iconName)
                                Text(cat.rawValue)
                            }
                            .font(.caption).bold()
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(manager.filterCategory == cat ? Color.accentColor : Color.secondary.opacity(0.1))
                            .foregroundStyle(manager.filterCategory == cat ? .white : .primary)
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(.horizontal)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }

    // MARK: - Status Bar
    @ViewBuilder
    private func scanStatusView() -> some View {
        switch manager.state {
        case .idle:
            EmptyView()
        case .scanning(let progress, let currentApp):
            VStack(spacing: 6) {
                HStack {
                    Text("Scanning: \(currentApp)")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption).bold()
                }
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            }
            .padding(.horizontal).padding(.vertical, 8)
            .background(Color.blue.opacity(0.05))
        case .completed(let appsScanned, let recordsCount):
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Scan Complete: \(appsScanned) apps analyzed, \(recordsCount) permission records discovered.")
                    .font(.caption).bold()
                Spacer()
            }
            .padding(.horizontal).padding(.vertical, 8)
            .background(Color.green.opacity(0.08))
        case .cancelled:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Scan Cancelled by User. Displaying partial records.")
                    .font(.caption).bold()
                Spacer()
            }
            .padding(.horizontal).padding(.vertical, 8)
            .background(Color.orange.opacity(0.08))
        case .failed(let error):
            HStack(spacing: 8) {
                Image(systemName: "xmark.octagon.fill")
                    .foregroundColor(.red)
                Text("Scan Failed: \(error)")
                    .font(.caption).bold()
                Spacer()
            }
            .padding(.horizontal).padding(.vertical, 8)
            .background(Color.red.opacity(0.08))
        }
    }

    // MARK: - Records List
    @ViewBuilder
    private func recordsListView() -> some View {
        let items = manager.filteredRecords

        if items.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "shield.slash")
                    .font(.largeTitle).foregroundColor(.secondary)
                Text("No matching permission records found")
                    .font(.headline)
                Text("Try adjusting your search query or selected category filter.")
                    .font(.caption).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(items) { item in
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(categoryColor(item.category).opacity(0.12))
                            .frame(width: 34, height: 34)
                        Image(systemName: item.category.iconName)
                            .font(.system(size: 14))
                            .foregroundColor(categoryColor(item.category))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(item.appName).font(.headline)
                            Text(item.category.rawValue.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(categoryColor(item.category).opacity(0.15))
                                .foregroundStyle(categoryColor(item.category))
                                .cornerRadius(3)
                        }
                        Text(item.bundleID).font(.caption2).foregroundColor(.secondary)
                        if let date = item.lastModified {
                            Text("Last Modified: \(formatDate(date))")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(item.grantState.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(grantColor(item.grantState).opacity(0.15))
                            .foregroundStyle(grantColor(item.grantState))
                            .cornerRadius(4)

                        HStack(spacing: 4) {
                            Text("Source: \(item.source.rawValue)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }

                        Text("Confidence: \(item.confidence.rawValue)")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.inset)
        }
    }

    // MARK: - Footer
    @ViewBuilder
    private func footerBar() -> some View {
        HStack {
            Text("Total Records: \(manager.filteredRecords.count) of \(manager.records.count)")
                .font(.caption).foregroundColor(.secondary)
            Spacer()
            Button("Open System Privacy Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .frame(height: 44)
    }

    // MARK: - Helpers
    private func categoryColor(_ cat: PermissionCategory) -> Color {
        switch cat {
        case .microphone: return .pink
        case .camera: return .purple
        case .screenCapture: return .orange
        case .fullDiskAccess: return .blue
        case .accessibility: return .green
        case .location: return .mint
        }
    }

    private func grantColor(_ state: PermissionGrantState) -> Color {
        switch state {
        case .granted: return .green
        case .denied: return .red
        case .unknown: return .orange
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
