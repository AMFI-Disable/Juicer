import SwiftUI
import AppKit

struct networkexposureview: View {
    @StateObject private var manager = NetworkExposureManager.shared

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
                manager.scanSockets()
            }
        }
    }

    // MARK: - Header
    @ViewBuilder
    private func headerSection() -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("Network Exposure Monitor")
                        .font(.title2).bold()
                    Text("READ-ONLY SOCKET AUDIT")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(Color.blue)
                        .cornerRadius(4)
                }
                Text("Inspect active TCP listening sockets, process owners, bound interface addresses, and exposure classifications.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()

            Button(action: { manager.scanSockets() }) {
                Label("Scan Sockets", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(manager.state == .scanning)
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
                TextField("Filter process, PID, port, or IP…", text: $manager.searchQuery)
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
            .frame(maxWidth: 280)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button(action: { manager.filterClassification = nil }) {
                        Text("All Exposures")
                            .font(.caption).bold()
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(manager.filterClassification == nil ? Color.accentColor : Color.secondary.opacity(0.1))
                            .foregroundStyle(manager.filterClassification == nil ? .white : .primary)
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)

                    ForEach(ExposureClassification.allCases) { cls in
                        Button(action: { manager.filterClassification = cls }) {
                            HStack(spacing: 4) {
                                Image(systemName: classificationIcon(cls))
                                Text(cls.rawValue)
                            }
                            .font(.caption).bold()
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(manager.filterClassification == cls ? Color.accentColor : Color.secondary.opacity(0.1))
                            .foregroundStyle(manager.filterClassification == cls ? .white : .primary)
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

    // MARK: - Status View
    @ViewBuilder
    private func scanStatusView() -> some View {
        switch manager.state {
        case .idle:
            EmptyView()
        case .scanning:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Executing socket inspection (`/usr/sbin/lsof -nP -iTCP -sTCP:LISTEN`)…")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal).padding(.vertical, 8)
            .background(Color.blue.opacity(0.05))
        case .completed(let count):
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Inspection Complete: \(count) active listening socket(s) detected.")
                    .font(.caption).bold()
                Spacer()
            }
            .padding(.horizontal).padding(.vertical, 8)
            .background(Color.green.opacity(0.08))
        case .failed(let error):
            HStack(spacing: 8) {
                Image(systemName: "xmark.octagon.fill")
                    .foregroundColor(.red)
                Text("Inspection Failed: \(error)")
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
                Image(systemName: "network.slash")
                    .font(.largeTitle).foregroundColor(.secondary)
                Text("No listening sockets matching filters")
                    .font(.headline)
                Text("Try clearing search queries or switching exposure classification filters.")
                    .font(.caption).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(items) { item in
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(classificationColor(item.classification).opacity(0.12))
                            .frame(width: 34, height: 34)
                        Image(systemName: classificationIcon(item.classification))
                            .font(.system(size: 14))
                            .foregroundColor(classificationColor(item.classification))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(item.processName).font(.headline)
                            Text("PID \(item.pid)")
                                .font(.caption2).bold()
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(3)
                            Text("User: \(item.user)").font(.caption2).foregroundColor(.secondary)
                        }
                        HStack(spacing: 6) {
                            Text("Bind: \(item.bindAddress):\(item.port)")
                                .font(.system(.caption2, design: .monospaced)).bold()
                            Text("(\(item.interface))")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(item.classification.rawValue.uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(classificationColor(item.classification).opacity(0.15))
                            .foregroundStyle(classificationColor(item.classification))
                            .cornerRadius(4)

                        Text("Protocol: \(item.protocolType)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.inset)
        }
    }

    // MARK: - Footer Bar
    @ViewBuilder
    private func footerBar() -> some View {
        HStack {
            Text("Displayed Sockets: \(manager.filteredRecords.count) of \(manager.records.count)")
                .font(.caption).foregroundColor(.secondary)
            Spacer()
            Text("Read-Only Inspection • System Terminal Verification Enabled")
                .font(.caption2).foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .frame(height: 44)
    }

    // MARK: - Helpers
    private func classificationIcon(_ cls: ExposureClassification) -> String {
        switch cls {
        case .localLoopback: return "lock.shield.fill"
        case .wildcardPublic: return "exclamationmark.shield.fill"
        case .specificIP: return "network"
        }
    }

    private func classificationColor(_ cls: ExposureClassification) -> Color {
        switch cls {
        case .localLoopback: return .green
        case .wildcardPublic: return .orange
        case .specificIP: return .blue
        }
    }
}
