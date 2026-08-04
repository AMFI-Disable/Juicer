import SwiftUI

@MainActor
struct brewservicesview: View {
    @StateObject private var manager = BrewServicesManager.shared
    @State private var searchText = ""
    @State private var showingLinkManager: BrewService?
    @State private var statusMessage = ""
    @State private var showStatusAlert = false

    // Custom Link state
    @State private var customLinkLabel = ""
    @State private var customLinkURL = ""

    // In-flight service operation bounds tracking
    @State private var operatingServices: Set<String> = []
    @State private var isBulkOperating = false

    var filteredServices: [BrewService] {
        if searchText.isEmpty {
            return manager.services
        }
        return manager.services.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header panel
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Homebrew Services Manager")
                        .font(.title2)
                        .bold()
                    Text("Manage running databases, web servers, and background daemons.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()

                // Domain Selector
                Picker("Domain", selection: $manager.isSystemDomain) {
                    Text("User Services").tag(false)
                    Text("System Services (Sudo)").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
                .accessibilityLabel("Service domain selection")
                .accessibilityHint("Switch between user services and system services requiring elevated privileges")
                .onChange(of: manager.isSystemDomain) { _ in
                    manager.loadServices()
                }

                if manager.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Loading services")
                } else {
                    Button(action: { manager.loadServices() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .help("Refresh Services")
                    .accessibilityLabel("Refresh Homebrew services")
                    .accessibilityHint("Reloads all services and status information from launchd")
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

            Divider()

            // Bulk controls & Search
            HStack {
                HStack(spacing: 12) {
                    Button(action: { runBulkAction("start") }) {
                        Label("Start All", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.green)
                    .disabled(isBulkOperating || manager.isLoading)
                    .accessibilityLabel("Start all stopped services")
                    .accessibilityHint("Attempts to start all currently stopped Homebrew services")

                    Button(action: { runBulkAction("stop") }) {
                        Label("Stop All", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    .disabled(isBulkOperating || manager.isLoading)
                    .accessibilityLabel("Stop all running services")
                    .accessibilityHint("Attempts to stop all currently running Homebrew services")
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                    TextField("Search service...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                        .accessibilityLabel("Search service by name")
                        .accessibilityHint("Filters the list of displayed Homebrew services")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            // Services List
            if filteredServices.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "cpu.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                    Text(searchText.isEmpty ? "No Homebrew Services Found" : "No Matches Found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    if searchText.isEmpty {
                        Text("Install services via brew (e.g. redis, postgresql, nginx) to manage them here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredServices) { service in
                            serviceRow(service)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            manager.loadServices()
        }
        .alert("Service Operation", isPresented: $showStatusAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(statusMessage)
        }
        .sheet(item: $showingLinkManager) { service in
            linkManagerSheet(service)
        }
    }

    // Row Builder
    @ViewBuilder
    private func serviceRow(_ service: BrewService) -> some View {
        let isOperating = operatingServices.contains(service.name)

        HStack(spacing: 16) {
            // Status bulb
            Circle()
                .fill(statusColor(service.status))
                .frame(width: 10, height: 10)
                .shadow(color: statusColor(service.status).opacity(0.5), radius: 3)
                .accessibilityLabel("Status: \(service.status.rawValue)")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(service.name)
                        .font(.headline)
                        .bold()

                    // Web Interface Quick link icons
                    ForEach(service.customLinks) { link in
                        Button(action: { launchURL(link.urlString) }) {
                            Image(systemName: "safari")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Open \(link.label): \(link.urlString)")
                        .accessibilityLabel("Open \(link.label) for \(service.name)")
                        .accessibilityHint("Opens \(link.urlString) in default web browser")
                    }
                }

                HStack(spacing: 16) {
                    Text(service.status.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor(service.status).opacity(0.15))
                        .cornerRadius(4)
                        .accessibilityLabel("Service status: \(service.status.rawValue)")

                    if let user = service.user {
                        Text("User: \(user)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .accessibilityLabel("Running under user: \(user)")
                    }

                    if !service.ports.isEmpty {
                        Text("Ports: \(service.ports.map(String.init).joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.teal)
                            .bold()
                            .accessibilityLabel("Listening ports: \(service.ports.map(String.init).joined(separator: ", "))")
                    }
                }
            }

            Spacer()

            // Plist Location (compact)
            if let path = service.plistPath, !path.isEmpty {
                Text(URL(fileURLWithPath: path).lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 150, alignment: .trailing)
                    .help(path)
                    .accessibilityLabel("Configuration path: \(path)")
            }

            // Actions
            HStack(spacing: 8) {
                if isOperating {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 32, height: 24)
                        .accessibilityLabel("Service operation in progress for \(service.name)")
                } else {
                    if service.status == .started {
                        Button(action: { stopService(service) }) {
                            Image(systemName: "stop.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.bordered)
                        .help("Stop Service")
                        .disabled(isBulkOperating)
                        .accessibilityLabel("Stop \(service.name)")
                        .accessibilityHint("Stops \(service.name) service via launchd")

                        Button(action: { restartService(service) }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.orange)
                        }
                        .buttonStyle(.bordered)
                        .help("Restart Service")
                        .disabled(isBulkOperating)
                        .accessibilityLabel("Restart \(service.name)")
                        .accessibilityHint("Restarts \(service.name) service via launchd")
                    } else {
                        Button(action: { startService(service) }) {
                            Image(systemName: "play.fill")
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.bordered)
                        .help("Start Service")
                        .disabled(isBulkOperating)
                        .accessibilityLabel("Start \(service.name)")
                        .accessibilityHint("Starts \(service.name) service via launchd")
                    }
                }

                Button(action: { showingLinkManager = service }) {
                    Image(systemName: "link")
                }
                .buttonStyle(.bordered)
                .help("Manage Web Links")
                .disabled(isOperating)
                .accessibilityLabel("Manage web links for \(service.name)")
                .accessibilityHint("Opens sheet to add or remove custom web interface URLs for \(service.name)")
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    // Status colors helper
    private func statusColor(_ status: BrewService.ServiceStatus) -> Color {
        switch status {
        case .started: return .green
        case .stopped: return .gray
        case .error: return .red
        case .unknown: return .orange
        }
    }

    // Actions Execution
    private func startService(_ service: BrewService) {
        let name = service.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !operatingServices.contains(name) else { return }

        operatingServices.insert(name)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .drawCompleted)

        manager.startService(service) { success in
            operatingServices.remove(name)
            if !success {
                statusMessage = "Failed to start service '\(name)'."
                showStatusAlert = true
            }
        }
    }

    private func stopService(_ service: BrewService) {
        let name = service.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !operatingServices.contains(name) else { return }

        operatingServices.insert(name)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .drawCompleted)

        manager.stopService(service) { success in
            operatingServices.remove(name)
            if !success {
                statusMessage = "Failed to stop service '\(name)'."
                showStatusAlert = true
            }
        }
    }

    private func restartService(_ service: BrewService) {
        let name = service.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !operatingServices.contains(name) else { return }

        operatingServices.insert(name)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .drawCompleted)

        manager.restartService(service) { success in
            operatingServices.remove(name)
            if !success {
                statusMessage = "Failed to restart service '\(name)'."
                showStatusAlert = true
            }
        }
    }

    private func runBulkAction(_ action: String) {
        guard action == "start" || action == "stop" else { return }
        guard !isBulkOperating else { return }

        let targets = filteredServices.filter { service in
            let name = service.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !operatingServices.contains(name) else { return false }
            return action == "start" ? (service.status != .started) : (service.status == .started)
        }
        guard !targets.isEmpty else { return }

        isBulkOperating = true
        for service in targets {
            operatingServices.insert(service.name)
        }

        let dispatchGroup = DispatchGroup()
        var failedServices: [String] = []
        let lock = NSLock()

        for service in targets {
            dispatchGroup.enter()
            let name = service.name
            let completionHandler: (Bool) -> Void = { success in
                lock.withLock {
                    if !success {
                        failedServices.append(name)
                    }
                }
                dispatchGroup.leave()
            }

            if action == "start" {
                manager.startService(service, completion: completionHandler)
            } else {
                manager.stopService(service, completion: completionHandler)
            }
        }

        dispatchGroup.notify(queue: .main) {
            for service in targets {
                self.operatingServices.remove(service.name)
            }
            self.isBulkOperating = false

            if !failedServices.isEmpty {
                let namesStr = failedServices.joined(separator: ", ")
                self.statusMessage = "Bulk \(action) finished. Failed to transition \(failedServices.count) service(s): \(namesStr)."
                self.showStatusAlert = true
            }
            self.manager.loadServices()
        }
    }

    // Link Manager Sheet
    @ViewBuilder
    private func linkManagerSheet(_ service: BrewService) -> some View {
        VStack(spacing: 20) {
            Text("Web Interface Links for \(service.name)")
                .font(.headline)
                .bold()

            // Add form
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Custom Link").font(.subheadline).bold()
                HStack {
                    TextField("Label (e.g. Admin UI)", text: $customLinkLabel)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Custom link label")
                        .accessibilityHint("Enter descriptive label such as Admin Console")

                    TextField("URL (e.g. http://localhost:8080)", text: $customLinkURL)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Custom link URL")
                        .accessibilityHint("Enter full web address including http:// or https://")

                    Button("Add") {
                        addCustomLink(for: service)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(customLinkLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || customLinkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Add custom link for \(service.name)")
                    .accessibilityHint("Saves the specified custom link")
                }

                // Suggestions based on ports
                if !service.ports.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Suggested Links:").font(.caption).foregroundColor(.secondary)
                        HStack {
                            ForEach(service.ports, id: \.self) { port in
                                Button("localhost:\(port)") {
                                    customLinkLabel = "Port \(port)"
                                    customLinkURL = "http://localhost:\(port)"
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .accessibilityLabel("Use suggested URL http://localhost:\(port)")
                                .accessibilityHint("Populates label and URL input fields with port \(port)")
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
            .cornerRadius(8)

            // Existing links list
            List {
                if service.customLinks.isEmpty {
                    Text("No custom links configured.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(service.customLinks) { link in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(link.label).bold()
                                Text(link.urlString).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Remove", role: .destructive) {
                                removeCustomLink(link, for: service)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Remove link \(link.label)")
                            .accessibilityHint("Deletes \(link.label) custom link configuration")
                        }
                    }
                }
            }
            .frame(height: 180)

            HStack {
                Spacer()
                Button("Done") {
                    customLinkLabel = ""
                    customLinkURL = ""
                    showingLinkManager = nil
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Close web links sheet")
                .accessibilityHint("Dismisses the web link manager dialog")
            }
        }
        .padding()
        .frame(width: 500, height: 420)
    }

    private func addCustomLink(for service: BrewService) {
        let trimmedLabel = customLinkLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        var trimmedURL = customLinkURL.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedLabel.isEmpty, !trimmedURL.isEmpty else { return }

        if !trimmedURL.lowercased().hasPrefix("http://") && !trimmedURL.lowercased().hasPrefix("https://") {
            trimmedURL = "http://" + trimmedURL
        }

        guard let validURL = URL(string: trimmedURL),
              let scheme = validURL.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return
        }

        var currentLinks = service.customLinks
        let newLink = ServiceLink(label: trimmedLabel, urlString: validURL.absoluteString)
        currentLinks.append(newLink)
        manager.saveCustomLinks(for: service.name, links: currentLinks)
        customLinkLabel = ""
        customLinkURL = ""

        // Update temporary sheet state
        if let idx = manager.services.firstIndex(where: { $0.id == service.id }) {
            showingLinkManager = manager.services[idx]
        }
    }

    private func removeCustomLink(_ link: ServiceLink, for service: BrewService) {
        let updated = service.customLinks.filter { $0.id != link.id }
        manager.saveCustomLinks(for: service.name, links: updated)
        if let idx = manager.services.firstIndex(where: { $0.id == service.id }) {
            showingLinkManager = manager.services[idx]
        }
    }

    private func launchURL(_ urlString: String) {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

