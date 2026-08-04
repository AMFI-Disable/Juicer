import SwiftUI

@MainActor
struct brewghostview: View {
    @StateObject private var manager = BrewGhostManager.shared
    @State private var selectedTab = 0
    @State private var targetExorciseGhost: BrewGhostPackage?
    @State private var showingExorciseAllConfirm = false
    @State private var showingClearHistoryConfirm = false

    var totalReclaimableBytes: Int64 {
        manager.ghosts.reduce(0) { $0 + $1.size }
    }

    var formattedReclaimableSpace: String {
        ByteCountFormatter.string(fromByteCount: totalReclaimableBytes, countStyle: .file)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Banner
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 48, height: 48)
                    Image(systemName: "ghost.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Brew-Ghost Companion")
                            .font(.title2).bold()

                        Text("🌟 CREATOR ORIGINAL")
                            .font(.system(size: 9, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.18), in: Capsule())
                            .foregroundColor(.purple)
                            .accessibilityHidden(true)

                        Text("TOP BREW TOOL")
                            .font(.system(size: 9, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.18), in: Capsule())
                            .foregroundColor(.orange)
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Brew-Ghost Companion, Creator Original, Top Brew Tool")

                    HStack(spacing: 8) {
                        Text("Automated ghost package & orphan formula cleanup utility")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button(action: {
                            if let url = URL(string: "https://github.com/amfi-disable/Brew-Ghost") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right.square.fill")
                                    .accessibilityHidden(true)
                                Text("amfi-disable/Brew-Ghost")
                            }
                            .font(.caption.bold())
                            .foregroundColor(.purple)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open amfi-disable Brew-Ghost repository on GitHub")
                        .accessibilityHint("Opens github.com/amfi-disable/Brew-Ghost in default browser")
                    }
                }

                Spacer()

                Button(action: {
                    manager.fetchGhosts()
                    manager.fetchHistory()
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .accessibilityLabel("Refresh ghost packages and history")
                .accessibilityHint("Scans Homebrew Cellar for idle ghost formulas and reloads exorcism history")
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Picker tab bar
            HStack {
                Picker("Navigation", selection: $selectedTab) {
                    Text("Cellar Ghosts (\(manager.ghosts.count))").tag(0)
                    Text("Exorcism History (\(manager.historyItems.count))").tag(1)
                    Text("Settings").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 400)
                .accessibilityLabel("Navigation sections")

                Spacer()

                if selectedTab == 0 && !manager.ghosts.isEmpty {
                    HStack(spacing: 8) {
                        Text("Reclaimable: \(formattedReclaimableSpace)")
                            .font(.subheadline).bold()
                            .foregroundColor(.green)
                            .accessibilityLabel("Total reclaimable space: \(formattedReclaimableSpace)")

                        Button("Exorcise All", role: .destructive) {
                            guard !manager.ghosts.isEmpty else { return }
                            showingExorciseAllConfirm = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.small)
                        .accessibilityLabel("Exorcise all \(manager.ghosts.count) ghost packages")
                        .accessibilityHint("Uninstalls all idle ghost packages from Homebrew Cellar")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // Main content body
            if manager.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(manager.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Loading status: \(manager.statusMessage)")
            } else {
                switch selectedTab {
                case 0:
                    ghostsListView()
                case 1:
                    historyListView()
                default:
                    settingsView()
                }
            }
        }
        .onAppear {
            manager.fetchGhosts()
            manager.fetchHistory()
        }
        .alert(item: $targetExorciseGhost) { ghost in
            Alert(
                title: Text("Exorcise Package"),
                message: Text("Are you sure you want to uninstall '\(ghost.name)' (\(ghost.formattedSize))? This action will remove the package from your Homebrew Cellar."),
                primaryButton: .destructive(Text("Uninstall")) {
                    guard !ghost.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                          manager.ghosts.contains(where: { $0.id == ghost.id }) else {
                        targetExorciseGhost = nil
                        return
                    }
                    manager.exorcise(package: ghost.name)
                    targetExorciseGhost = nil
                },
                secondaryButton: .cancel {
                    targetExorciseGhost = nil
                }
            )
        }
        .alert("Exorcise All Ghosts", isPresented: $showingExorciseAllConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Uninstall All (\(manager.ghosts.count))", role: .destructive) {
                guard !manager.ghosts.isEmpty else { return }
                manager.exorciseAll()
            }
        } message: {
            Text("Are you sure you want to uninstall all \(manager.ghosts.count) idle ghost packages (\(formattedReclaimableSpace)) from your Homebrew Cellar?")
        }
        .alert("Clear Exorcism History", isPresented: $showingClearHistoryConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clear History", role: .destructive) {
                guard !manager.historyItems.isEmpty else { return }
                manager.clearHistory()
            }
        } message: {
            Text("Are you sure you want to delete all \(manager.historyItems.count) history logs? This action cannot be undone.")
        }
    }

    // MARK: - Ghosts List View
    @ViewBuilder
    private func ghostsListView() -> some View {
        if manager.ghosts.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                    .accessibilityHidden(true)
                Text("Cellar is Clean!")
                    .font(.title3).bold()
                Text("No Homebrew packages detected with inactivity >= \(manager.daysThreshold) days.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Cellar is Clean. No Homebrew packages detected with inactivity greater than or equal to \(manager.daysThreshold) days.")
        } else {
            List {
                ForEach(manager.ghosts) { ghost in
                    HStack(spacing: 16) {
                        Image(systemName: "shippingbox.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(ghost.name)
                                .font(.headline)
                            Text("Idle for \(ghost.daysIdle) days")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(ghost.name), idle for \(ghost.daysIdle) days")

                        Spacer()

                        Text(ghost.formattedSize)
                            .font(.callout).bold()
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Size \(ghost.formattedSize)")

                        Button("Exorcise") {
                            guard !ghost.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                  manager.ghosts.contains(where: { $0.id == ghost.id }) else { return }
                            targetExorciseGhost = ghost
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.small)
                        .accessibilityLabel("Exorcise \(ghost.name)")
                        .accessibilityHint("Uninstalls \(ghost.name) reclaiming \(ghost.formattedSize)")
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)
        }
    }

    // MARK: - History List View
    @ViewBuilder
    private func historyListView() -> some View {
        if manager.historyItems.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                Text("No History Logs")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Package uninstallations performed via Brew-Ghost CLI or Juicer will log here.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("No History Logs. Package uninstallations performed will log here.")
        } else {
            VStack(spacing: 0) {
                HStack {
                    Text("Recorded Exorcisms")
                        .font(.headline)
                        .accessibilityLabel("Recorded Exorcisms count: \(manager.historyItems.count)")
                    Spacer()
                    Button("Clear History", role: .destructive) {
                        guard !manager.historyItems.isEmpty else { return }
                        showingClearHistoryConfirm = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Clear History")
                    .accessibilityHint("Deletes all \(manager.historyItems.count) history logs")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                Divider()

                List {
                    ForEach(manager.historyItems) { item in
                        HStack(spacing: 16) {
                            Image(systemName: "trash.circle.fill")
                                .font(.title3)
                                .foregroundColor(.purple)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.package)
                                    .font(.headline)
                                Text("Exorcised on \(item.formattedDate)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(item.formattedSize)
                                    .font(.subheadline).bold()
                                Text("Was idle \(item.daysIdle) days")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Package \(item.package), exorcised on \(item.formattedDate), size \(item.formattedSize), idle for \(item.daysIdle) days")
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Settings View
    @ViewBuilder
    private func settingsView() -> some View {
        Form {
            Section("Ghost Detection Settings") {
                Picker("Inactivity Threshold:", selection: Binding(
                    get: { manager.daysThreshold },
                    set: { manager.setDaysThreshold($0) }
                )) {
                    Text("10 Days").tag(10)
                    Text("30 Days").tag(30)
                    Text("60 Days").tag(60)
                    Text("90 Days (Default)").tag(90)
                    Text("120 Days").tag(120)
                    Text("180 Days").tag(180)
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Inactivity Threshold")
                .accessibilityHint("Select inactivity duration before packages are flagged as ghost formulas")

                Text("Packages unused for longer than this threshold will be flagged as freeloaders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("CLI Integration Status") {
                HStack {
                    Text("brew-ghost Path:")
                    Spacer()
                    Text(BrewGhostManager.brewGhostPath ?? "Not Found")
                        .font(.footnote)
                        .foregroundColor(BrewGhostManager.brewGhostPath != nil ? .green : .red)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("brew-ghost Path: \(BrewGhostManager.brewGhostPath ?? "Not Found")")

                HStack {
                    Text("Config Location:")
                    Spacer()
                    Text(manager.configPath)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Config Location: \(manager.configPath)")

                HStack {
                    Text("History Location:")
                    Spacer()
                    Text(manager.historyPath)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("History Location: \(manager.historyPath)")
            }
        }
        .formStyle(.grouped)
    }
}
