import SwiftUI
import AppKit

struct tccviewerview: View {
    @StateObject private var manager = TCCViewerManager.shared
    @State private var filterService: String?
    @State private var selectedItem: TCCPermissionItem?
    @State private var showConfirmReset = false
    @State private var showConfirmResetAll = false
    @State private var resultMessage: String = ""
    @State private var showResult = false

    var body: some View {
        VStack(spacing: 0) {
            headerSection()
            Divider()
            filterBar()
            Divider()

            if manager.isScanning {
                VStack(spacing: 12) {
                    ProgressView("Querying TCC permissions database…").progressViewStyle(.circular)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                permissionsList()
            }

            Divider()
            footerDetailsBar()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            manager.scanPermissions()
        }
        .alert("Revoke Permission?", isPresented: $showConfirmReset) {
            Button("Cancel", role: .cancel) {}
            Button("Revoke", role: .destructive) {
                if let item = selectedItem {
                    guard !item.isSampleData else {
                        resultMessage = "Cannot revoke permissions for sample data."
                        showResult = true
                        selectedItem = nil
                        return
                    }
                    guard !item.client.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        resultMessage = "Invalid bundle identifier."
                        showResult = true
                        selectedItem = nil
                        return
                    }
                    manager.resetPermission(for: item) { _, msg in
                        resultMessage = msg
                        showResult = true
                        selectedItem = nil
                    }
                }
            }
        } message: {
            if let item = selectedItem {
                Text("Are you sure you want to revoke \(formatService(item.service)) permission for '\(item.appName)'? The app will need to be restarted.")
            }
        }
        .alert("Revoke All Permissions?", isPresented: $showConfirmResetAll) {
            Button("Cancel", role: .cancel) {}
            Button("Revoke All", role: .destructive) {
                if let item = selectedItem {
                    guard !item.isSampleData else {
                        resultMessage = "Cannot revoke permissions for sample data."
                        showResult = true
                        selectedItem = nil
                        return
                    }
                    guard !item.client.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        resultMessage = "Invalid bundle identifier."
                        showResult = true
                        selectedItem = nil
                        return
                    }
                    manager.resetAllPermissions(forBundle: item.client) { _, msg in
                        resultMessage = msg
                        showResult = true
                        selectedItem = nil
                    }
                }
            }
        } message: {
            if let item = selectedItem {
                Text("Are you sure you want to revoke ALL TCC privacy permissions for '\(item.appName)'? This will reset all system permissions recorded for this bundle identifier.")
            }
        }
        .alert("Operation Result", isPresented: $showResult) {
            Button("OK") {}
        } message: {
            Text(resultMessage)
        }
    }

    // MARK: - Header
    @ViewBuilder
    private func headerSection() -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("Privacy Permissions Cabinet")
                        .font(.title2).bold()
                    Text(manager.scanSource == .liveSystemDB ? "LIVE SYSTEM DB" : "SAMPLE DATA (SANDBOXED)")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(manager.scanSource == .liveSystemDB ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15))
                        .foregroundStyle(manager.scanSource == .liveSystemDB ? Color.blue : Color.orange)
                        .cornerRadius(4)
                }
                Text(manager.scanSource == .liveSystemDB ? "Inspect and manage active macOS system privacy permissions." : "Displaying sample TCC permission records. Full Disk Access is required to query live system TCC.db directly.")
                    .font(.subheadline).foregroundStyle(.secondary)

                if let scanErr = manager.lastScanError, !scanErr.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(scanErr)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 2)
                }
            }
            Spacer()

            Button(action: { manager.scanPermissions() }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(manager.isScanning)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
    }

    // MARK: - Filter Bar
    @ViewBuilder
    private func filterBar() -> some View {
        let services = Array(Set(manager.permissions.map { $0.service })).sorted()

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button(action: { filterService = nil }) {
                    Text("All Services").font(.caption).bold()
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(filterService == nil ? Color.accentColor : Color.secondary.opacity(0.1))
                        .foregroundStyle(filterService == nil ? .white : .primary)
                        .cornerRadius(20)
                }
                .buttonStyle(.plain)

                ForEach(services, id: \.self) { svc in
                    Button(action: { filterService = svc }) {
                        Text(formatService(svc)).font(.caption).bold()
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(filterService == svc ? Color.accentColor : Color.secondary.opacity(0.1))
                            .foregroundStyle(filterService == svc ? .white : .primary)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal).padding(.vertical, 8)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.2))
    }

    // MARK: - List
    @ViewBuilder
    private func permissionsList() -> some View {
        let filtered = filterService == nil ? manager.permissions : manager.permissions.filter { $0.service == filterService }

        if filtered.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "shield.slash")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text("No Privacy Permission Records")
                    .font(.headline)
                Text(filterService == nil ? "No permissions detected." : "No permissions found for \(formatService(filterService!)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(filtered) { item in
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(serviceColor(item.service).opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: serviceIcon(item.service))
                            .font(.caption).foregroundColor(serviceColor(item.service))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(item.appName).font(.headline)
                            if item.isSampleData {
                                Text("SAMPLE")
                                    .font(.system(size: 7, weight: .bold))
                                    .padding(.horizontal, 4).padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.15))
                                    .foregroundStyle(Color.secondary)
                                    .cornerRadius(3)
                            }
                        }
                        Text(item.client).font(.caption2).foregroundColor(.secondary)
                        Text("Modified: \(formatDate(item.lastModified))")
                            .font(.caption2).foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(formatService(item.service).uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(serviceColor(item.service).opacity(0.15))
                                .foregroundStyle(serviceColor(item.service)).cornerRadius(3)

                            Text(item.isAllowed ? "ALLOWED" : "DENIED")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(item.isAllowed ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                .foregroundStyle(item.isAllowed ? Color.green : Color.red).cornerRadius(3)
                        }
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedItem = item
                }
            }
            .listStyle(.inset)
        }
    }

    // MARK: - Footer
    @ViewBuilder
    private func footerDetailsBar() -> some View {
        HStack {
            if let item = selectedItem {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Selected App: \(item.appName)").bold().font(.subheadline)
                        if item.isSampleData {
                            Text("(Sample Mode - Revocation Disabled)")
                                .font(.caption2).foregroundColor(.orange)
                        }
                    }
                    Text("Bundle ID: \(item.client)").font(.caption2).foregroundColor(.secondary)
                }
                Spacer()

                Button("Revoke Selected") {
                    if !item.isSampleData && !item.client.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        showConfirmReset = true
                    }
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(item.isSampleData || item.client.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Revoke All Permissions") {
                    if !item.isSampleData && !item.client.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        showConfirmResetAll = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(item.isSampleData || item.client.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                Text(manager.scanSource == .liveSystemDB ? "Select an application permission record to trigger revocation settings." : "Select an application record. Revocation requires live Full Disk Access permissions.")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        .frame(height: 48)
    }

    // MARK: - Helpers
    private func formatService(_ service: String) -> String {
        let clean = service.replacingOccurrences(of: "kTCCService", with: "")
        if clean == "SystemPolicyAllFiles" { return "Full Disk Access" }
        if clean == "ScreenCapture" { return "Screen Recording" }
        return clean
    }

    private func serviceIcon(_ service: String) -> String {
        let clean = service.replacingOccurrences(of: "kTCCService", with: "")
        switch clean {
        case "Microphone": return "mic.fill"
        case "Camera": return "camera.fill"
        case "SystemPolicyAllFiles": return "folder.fill"
        case "ScreenCapture": return "desktopcomputer"
        case "Location": return "location.fill"
        default: return "shield.fill"
        }
    }

    private func serviceColor(_ service: String) -> Color {
        let clean = service.replacingOccurrences(of: "kTCCService", with: "")
        switch clean {
        case "Microphone": return .pink
        case "Camera": return .purple
        case "SystemPolicyAllFiles": return .blue
        case "ScreenCapture": return .orange
        case "Location": return .green
        default: return .secondary
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
