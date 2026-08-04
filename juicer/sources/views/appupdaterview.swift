import SwiftUI
import AppKit

@MainActor
struct appupdaterview: View {
    @StateObject private var manager = AppUpdateManager.shared
    @State private var filterType: SoftwareUpdateItem.UpdateType?
    @State private var showAdoptAlert = false
    @State private var selectedItemForAdoption: SoftwareUpdateItem?
    @State private var alertMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            headerSection()
            Divider()
            filterBar()
            Divider()

            if manager.isChecking {
                let clampedProgress = min(1.0, max(0.0, manager.checkProgress))
                VStack(spacing: 12) {
                    ProgressView(value: clampedProgress, total: 1.0) {
                        Text("Checking for software updates…")
                            .font(.headline)
                    }
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 320)

                    Text("\(Int(clampedProgress * 100))% — Scanning Homebrew repositories and App Store listings…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Checking for software updates")
                .accessibilityValue("\(Int(clampedProgress * 100)) percent completed")
            } else if manager.updates.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                    Text("All Software is Up to Date")
                        .font(.headline)
                    Text("No outdated Homebrew casks, formulae, or App Store items were found.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Scan Again") {
                        manager.checkForUpdates()
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
                    .accessibilityLabel("Scan Again")
                    .accessibilityHint("Re-scans systems for available software updates")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .contain)
            } else {
                updatesList()
            }

            Divider()
            logConsole()
            Divider()
            actionBar()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            manager.checkForUpdates()
        }
        .alert("Homebrew Cask Adoption", isPresented: $showAdoptAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Adopt", role: .destructive) {
                if let item = selectedItemForAdoption {
                    manager.adoptViaHomebrewCask(item) { _, msg in
                        alertMessage = msg
                    }
                }
            }
        } message: {
            if let item = selectedItemForAdoption {
                Text("This will reinstall '\(item.name)' via Homebrew Cask to replace your standalone copy. This allows future updates to be managed in a unified way via Juicer.\n\nProceed?")
            }
        }
    }

    // MARK: - Header
    @ViewBuilder
    private func headerSection() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Software Updates Desk")
                    .font(.title2).bold()
                Text("Unified dashboard for upgrading Homebrew, App Store, and Sparkle app packages. Migrate standalone apps to Cask management.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()

            Button(action: { manager.checkForUpdates() }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(manager.isChecking || manager.isUpdating)
            .accessibilityLabel("Check for Updates")
            .accessibilityHint("Scans for outdated Homebrew casks, formulae, and Mac App Store packages")
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
    }

    // MARK: - Filter Bar
    @ViewBuilder
    private func filterBar() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button(action: { filterType = nil }) {
                    Text("All").font(.caption).bold()
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(filterType == nil ? Color.accentColor : Color.secondary.opacity(0.1))
                        .foregroundStyle(filterType == nil ? .white : .primary)
                        .cornerRadius(20)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Filter by All Updates")
                .accessibilityHint("Shows all available software updates")

                ForEach(SoftwareUpdateItem.UpdateType.allCases, id: \.self) { type in
                    Button(action: { filterType = type }) {
                        Text(type.rawValue).font(.caption).bold()
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(filterType == type ? Color.accentColor : Color.secondary.opacity(0.1))
                            .foregroundStyle(filterType == type ? .white : .primary)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Filter by \(type.rawValue)")
                    .accessibilityHint("Shows only \(type.rawValue) updates")
                }
            }
            .padding(.horizontal).padding(.vertical, 8)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.2))
        .accessibilityLabel("Update categories filter bar")
    }

    // MARK: - Updates List
    @ViewBuilder
    private func updatesList() -> some View {
        let filtered = filterType == nil ? manager.updates : manager.updates.filter { $0.type == filterType }

        List {
            ForEach(filtered) { item in
                HStack(spacing: 12) {
                    Toggle("", isOn: Binding(
                        get: { item.isSelected },
                        set: { val in
                            if let idx = manager.updates.firstIndex(where: { $0.id == item.id }) {
                                manager.updates[idx].isSelected = val
                            }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .disabled(manager.isUpdating)
                    .accessibilityLabel("Select \(item.name) update")
                    .accessibilityHint("Toggles selection of \(item.name) for upgrade")

                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(typeColor(item.type).opacity(0.12))
                            .frame(width: 30, height: 30)
                        Image(systemName: typeIcon(item.type))
                            .font(.caption).foregroundColor(typeColor(item.type))
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(item.name).font(.headline)
                            Text(item.type.rawValue.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(typeColor(item.type).opacity(0.15))
                                .foregroundStyle(typeColor(item.type)).cornerRadius(3)
                        }
                        Text("Current: \(item.currentVersion) ➔ Latest: \(item.latestVersion)")
                            .font(.subheadline).foregroundColor(.secondary)
                    }

                    Spacer()

                    if item.type == .sparkle {
                        Button("Adopt via Cask") {
                            selectedItemForAdoption = item
                            showAdoptAlert = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .accessibilityLabel("Adopt \(item.name) via Homebrew Cask")
                        .accessibilityHint("Reinstalls \(item.name) as a Homebrew Cask for unified package management")
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("\(item.name), \(item.type.rawValue), current version \(item.currentVersion), latest version \(item.latestVersion)")
            }
        }
        .listStyle(.inset)
        .accessibilityLabel("Software updates list")
    }

    // MARK: - Log Console
    @ViewBuilder
    private func logConsole() -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Upgrade Execution Console").font(.caption).bold().foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal).padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.2))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if manager.updateLog.isEmpty {
                        Text("Console idle. Trigger upgrade to see execution stream.")
                            .font(.system(.caption, design: .monospaced)).foregroundColor(.secondary)
                    } else {
                        ForEach(manager.updateLog, id: \.self) { line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(line.hasPrefix("❌") ? .red : line.hasPrefix("✅") ? .green : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding()
            }
            .frame(height: 100)
            .background(Color(NSColor.underPageBackgroundColor).opacity(0.3))
        }
        .accessibilityLabel("Upgrade Execution Console")
        .accessibilityHint("Displays live execution logs for software package upgrades")
    }

    // MARK: - Action Bar
    @ViewBuilder
    private func actionBar() -> some View {
        HStack {
            let selectedCount = manager.updates.filter { $0.isSelected }.count
            Text("\(selectedCount) updates selected")
                .font(.subheadline).foregroundStyle(.secondary)
                .accessibilityLabel("\(selectedCount) updates selected")
            Spacer()

            Button("Select All") {
                for i in manager.updates.indices { manager.updates[i].isSelected = true }
            }
            .buttonStyle(.bordered)
            .disabled(manager.isUpdating)
            .accessibilityLabel("Select All Updates")
            .accessibilityHint("Selects all available software updates for upgrade")

            Button("Select None") {
                for i in manager.updates.indices { manager.updates[i].isSelected = false }
            }
            .buttonStyle(.bordered)
            .disabled(manager.isUpdating)
            .accessibilityLabel("Deselect All Updates")
            .accessibilityHint("Deselects all software updates")

            let clampedUpdateProgress = min(1.0, max(0.0, manager.updateProgress))
            Button(action: {
                manager.updateSelected { _ in }
            }) {
                HStack {
                    if manager.isUpdating {
                        ProgressView(value: clampedUpdateProgress, total: 1.0)
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    }
                    Text(manager.isUpdating ? "Upgrading (\(Int(clampedUpdateProgress * 100))%)…" : "Upgrade Selected Packages")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedCount == 0 || manager.isUpdating || manager.isChecking)
            .accessibilityLabel(manager.isUpdating ? "Upgrading selected packages, \(Int(clampedUpdateProgress * 100)) percent completed" : "Upgrade Selected Packages")
            .accessibilityHint("Upgrades the \(selectedCount) selected software packages")
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
    }

    // MARK: - Helpers
    private func typeColor(_ type: SoftwareUpdateItem.UpdateType) -> Color {
        switch type {
        case .cask: return .orange
        case .formula: return .teal
        case .appStore: return .blue
        case .sparkle: return .purple
        }
    }

    private func typeIcon(_ type: SoftwareUpdateItem.UpdateType) -> String {
        switch type {
        case .cask: return "shippingbox.fill"
        case .formula: return "hammer.fill"
        case .appStore: return "square.grid.3x3.fill"
        case .sparkle: return "sparkles"
        }
    }
}
