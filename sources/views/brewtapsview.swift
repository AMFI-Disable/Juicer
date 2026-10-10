import SwiftUI

@MainActor
struct brewtapsview: View {
    @StateObject private var manager = BrewTapsManager.shared
    @State private var searchText = ""
    @State private var newTapName = ""
    @State private var statusMessage = ""
    @State private var showStatusAlert = false
    @State private var isTapping = false

    private static let maxTapNameLength = 256
    private static let minTapNameLength = 3
    private static let disallowedCharacters = CharacterSet(charactersIn: ";&|$`\"'<>\\")

    var filteredTaps: [BrewTap] {
        if searchText.isEmpty {
            return manager.taps
        }
        return manager.taps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header panel
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Homebrew Taps Manager")
                        .font(.title2)
                        .bold()
                        .accessibilityAddTraits(.isHeader)
                    Text("Register additional software repositories and audit sources health.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()

                if manager.isCheckingHealth {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Auditing GitHub health...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Auditing GitHub health")
                    .accessibilityValue("In progress")
                } else {
                    Button(action: { manager.checkTapsHealth() }) {
                        Label("Validate Health", systemImage: "shield.checkerboard")
                    }
                    .buttonStyle(.bordered)
                    .help("Runs GitHub API repository verification checks")
                    .accessibilityLabel("Validate Health")
                    .accessibilityHint("Runs GitHub API repository verification checks on all registered taps")
                }

                if manager.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Loading taps list")
                        .accessibilityValue("In progress")
                } else {
                    Button(action: { manager.loadTaps() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .help("Refresh Taps list")
                    .accessibilityLabel("Refresh Taps List")
                    .accessibilityHint("Reloads the list of Homebrew taps")
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

            Divider()

            if manager.isCheckingHealth || manager.lastHealthUpdate != nil || manager.healthError != nil {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Image(systemName: manager.healthError == nil ? "shield.checkered" : "exclamationmark.triangle.fill")
                            .foregroundStyle(manager.healthError == nil ? .blue : .orange)
                            .accessibilityHidden(true)
                        Text(manager.healthStatusMessage).font(.caption)
                        Spacer()
                        if let lastHealthUpdate = manager.lastHealthUpdate {
                            Text("Updated \(lastHealthUpdate.formatted(date: .omitted, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if manager.isCheckingHealth {
                        ProgressView(value: manager.healthProgress)
                            .progressViewStyle(.linear)
                            .accessibilityLabel("Health audit progress")
                            .accessibilityValue("\(Int(manager.healthProgress * 100)) percent")
                    }
                    if let healthError = manager.healthError {
                        Text(healthError).font(.caption2).foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.05))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Tap Health Summary: \(manager.healthStatusMessage)")
                Divider()
            }

            // Add Tap Section
            HStack(spacing: 12) {
                TextField("Enter repository to tap (e.g. homebrew/cask-fonts or full URL)...", text: $newTapName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Repository name or URL to tap")
                    .accessibilityHint("Enter a tap name such as homebrew/cask-fonts or a GitHub repository URL")
                    .onChange(of: newTapName) { newValue in
                        if newValue.count > Self.maxTapNameLength {
                            newTapName = String(newValue.prefix(Self.maxTapNameLength))
                        }
                    }

                if isTapping {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Tapping repository")
                        .accessibilityValue("In progress")
                } else {
                    Button("Tap Repository") {
                        tapRepository()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isTapping || newTapName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Tap Repository")
                    .accessibilityHint("Adds the specified repository tap to Homebrew")
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.2))

            Divider()

            // Search toolbar
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                    TextField("Search taps...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                        .accessibilityLabel("Search Taps")
                        .accessibilityHint("Filters the displayed list of taps by name")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // List of taps
            if filteredTaps.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "shippingbox.and.arrow.backward")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                    Text("No Repository Taps Registered")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("No Repository Taps Registered")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredTaps) { tap in
                            tapRow(tap)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            manager.loadTaps()
        }
        .alert("Taps Operation", isPresented: $showStatusAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(statusMessage)
        }
    }

    // Row Builder
    @ViewBuilder
    private func tapRow(_ tap: BrewTap) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Text(tap.name)
                        .font(.headline)
                        .bold()
                        .accessibilityAddTraits(.isHeader)

                    // Health status badge
                    if let health = tap.healthStatus {
                        healthBadge(health)
                    }
                }

                if !tap.remote.isEmpty {
                    Text(tap.remote)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Remote URL: \(tap.remote)")
                }
            }

            Spacer()

            // Untap Button
            Button("Untap", role: .destructive) {
                removeTap(tap)
            }
            .buttonStyle(.bordered)
            .disabled(tap.name == "homebrew/core" || tap.name == "homebrew/cask") // Safeguard core taps
            .help((tap.name == "homebrew/core" || tap.name == "homebrew/cask") ? "Core taps cannot be unregistered." : "Remove tap repository.")
            .accessibilityLabel("Untap \(tap.name)")
            .accessibilityHint((tap.name == "homebrew/core" || tap.name == "homebrew/cask") ? "Core taps cannot be unregistered." : "Unregisters \(tap.name) tap repository from Homebrew.")
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    // Health Badge builder
    @ViewBuilder
    private func healthBadge(_ health: TapHealthStatus) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(healthBadgeColor(health.status))
                .frame(width: 6, height: 6)

            Text(health.status.rawValue)
                .font(.system(size: 10, weight: .bold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundColor(healthBadgeColor(health.status))
        .background(healthBadgeColor(health.status).opacity(0.15))
        .cornerRadius(4)
        .help(healthTooltip(health))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Health status: \(health.status.rawValue)")
        .accessibilityHint(healthTooltip(health))
    }

    private func healthBadgeColor(_ status: TapHealthStatus.Status) -> Color {
        switch status {
        case .active: return .green
        case .stale: return .orange
        case .archived: return .gray
        case .redirected: return .teal
        case .missing: return .red
        case .unknown: return .primary
        }
    }

    private func healthTooltip(_ health: TapHealthStatus) -> String {
        switch health.status {
        case .active: return "Repository is active on GitHub. Checked on \(formatDate(health.lastChecked))."
        case .stale: return "Checked more than 24 hours ago. Please run Validate Health again."
        case .archived: return "WARNING: This repository is archived (read-only) on GitHub. No future package updates will be pushed."
        case .redirected: return "This repository has moved. Suggested location: \(health.movedTo ?? "unknown")."
        case .missing: return "CRITICAL ERROR: This repository returned 404. It has been deleted or made private."
        case .unknown: return "Health not validated yet."
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // Validation & Action methods
    private func validateTapInput(_ input: String) -> String? {
        if input.count > Self.maxTapNameLength {
            return "Repository name or URL exceeds maximum length of \(Self.maxTapNameLength) characters."
        }
        if input.count < Self.minTapNameLength {
            return "Repository name or URL is too short (minimum \(Self.minTapNameLength) characters)."
        }
        if input.hasPrefix("-") {
            return "Tap name cannot start with a hyphen."
        }
        if input.rangeOfCharacter(from: .newlines) != nil || input.rangeOfCharacter(from: .controlCharacters) != nil {
            return "Tap name cannot contain line breaks or control characters."
        }
        if input.rangeOfCharacter(from: Self.disallowedCharacters) != nil {
            return "Tap name contains forbidden special characters."
        }

        let isURL = input.hasPrefix("https://") || input.hasPrefix("http://") || input.hasPrefix("git@")
        if isURL {
            guard URL(string: input) != nil else {
                return "Invalid repository URL format."
            }
        } else {
            let components = input.split(separator: "/", omittingEmptySubsequences: false)
            guard components.count >= 2, components.allSatisfy({ !$0.isEmpty }) else {
                return "Tap repository must be in 'user/repo' format or a valid repository URL."
            }
            let allowedInName = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
            for comp in components {
                if comp.unicodeScalars.contains(where: { !allowedInName.contains($0) }) {
                    return "Tap repository name contains invalid characters."
                }
            }
        }

        let lower = input.lowercased()
        if manager.taps.contains(where: { $0.name.lowercased() == lower || $0.remote.lowercased() == lower }) {
            return "Repository '\(input)' is already tapped."
        }

        return nil
    }

    private func tapRepository() {
        guard !isTapping else { return }
        let cleaned = newTapName.trimmingCharacters(in: .whitespacesAndNewlines)

        if let validationError = validateTapInput(cleaned) {
            statusMessage = validationError
            showStatusAlert = true
            return
        }

        isTapping = true
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .drawCompleted)

        manager.addTap(name: cleaned) { success in
            isTapping = false
            if success {
                newTapName = ""
                statusMessage = "Successfully tapped \(cleaned)!"
            } else {
                statusMessage = "Failed to tap \(cleaned). Verify name and internet connection."
            }
            showStatusAlert = true
        }
    }

    private func removeTap(_ tap: BrewTap) {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .drawCompleted)
        manager.removeTap(tap) { success in
            if success {
                statusMessage = "Successfully untapped \(tap.name)!"
            } else {
                statusMessage = "Failed to unregister \(tap.name)."
            }
            showStatusAlert = true
        }
    }
}
