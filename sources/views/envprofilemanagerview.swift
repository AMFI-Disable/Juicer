import SwiftUI
import AppKit
import UniformTypeIdentifiers

typealias EnvProfileManagerView = envprofilemanagerview

@MainActor
struct envprofilemanagerview: View {
    @StateObject private var manager = EnvProfileManager()
    @State private var maskSecrets = true
    @State private var searchText = ""
    @State private var newProfileName = ""
    @State private var newProjectPath = ""
    @State private var showAddProfileSheet = false
    @State private var editProjectPath = ""
    @State private var showEditPathSheet = false
    @State private var newKey = ""
    @State private var newValue = ""
    @State private var isNewSecret = false
    @State private var noticeMessage = ""
    @State private var isNoticeError = false

    private static let maxPathLength = 2048
    private static let maxProfileNameLength = 128

    var filteredProfiles: [EnvProfile] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return manager.profiles
        }
        return manager.profiles.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.projectPath.localizedCaseInsensitiveContains(searchText)
        }
    }

    var selectedProfile: EnvProfile? {
        manager.profiles.first(where: { $0.id == manager.selectedProfileID })
    }

    private var isKeyValid: Bool {
        let trimmed = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= EnvProfileManager.maxKeyLength else { return false }
        let validKeyChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_.-"))
        return trimmed.unicodeScalars.allSatisfy({ validKeyChars.contains($0) })
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $manager.selectedProfileID) {
                    Section("Profiles") {
                        ForEach(filteredProfiles) { profile in
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundStyle(Color.accentColor)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name)
                                        .font(.headline)
                                    Text("\(profile.variables.count) variables")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(profile.name), \(profile.variables.count) variables")
                            .accessibilityHint("Selects this environment profile")
                            .tag(profile.id)
                        }
                        .onDelete { indexSet in
                            let idsToDelete = indexSet.compactMap { idx in
                                idx < manager.profiles.count ? manager.profiles[idx].id : nil
                            }
                            for id in idsToDelete {
                                manager.deleteProfile(id: id)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .searchable(text: $searchText, prompt: "Search Profiles")
                .accessibilityLabel("Environment Profiles List")
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        Button(action: importEnvFileModal) {
                            Label("Import", systemImage: "square.and.arrow.down")
                        }
                        .help("Import .env File")
                        .accessibilityLabel("Import .env File")
                        .accessibilityHint("Opens file picker to import an environment profile from a .env file")

                        Button(action: { showAddProfileSheet = true }) {
                            Image(systemName: "plus")
                        }
                        .help("Create New Env Profile")
                        .accessibilityLabel("Add New Profile")
                        .accessibilityHint("Opens dialog to create a new environment profile")
                    }
                }
            }
        } detail: {
            if var profile = selectedProfile {
                VStack(spacing: 0) {
                    // Header Bar
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name)
                                .font(.title2)
                                .bold()
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityLabel("Profile: \(profile.name)")

                            HStack(spacing: 4) {
                                if profile.projectPath.isEmpty {
                                    Text("No project path set")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .accessibilityLabel("No project path set")
                                } else {
                                    Text(profile.projectPath)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .accessibilityLabel("Project path: \(profile.projectPath)")
                                }
                                Button(action: {
                                    editProjectPath = profile.projectPath
                                    showEditPathSheet = true
                                }) {
                                    Image(systemName: "pencil.circle")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .help("Edit Project Path")
                                .accessibilityLabel("Edit Project Path")
                                .accessibilityHint("Opens dialog to edit project path for this profile")
                            }
                        }

                        Spacer()

                        Toggle("Mask Secrets", isOn: $maskSecrets)
                            .toggleStyle(.switch)
                            .accessibilityLabel("Mask Secrets")
                            .accessibilityHint("Toggles visibility of secret variable values")

                        Button(action: {
                            exportToEnvFileModal(for: profile)
                        }) {
                            Label("Save .env", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .help("Save atomically to .env file")
                        .accessibilityLabel("Save to .env file")
                        .accessibilityHint("Saves profile variables atomically to .env file at project path")

                        Button(action: {
                            let str = manager.exportAsEnvString(profile: profile)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(str, forType: .string)
                            showNotice("Copied .env format!", isError: false)
                        }) {
                            Label("Copy .env", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Copy .env format")
                        .accessibilityHint("Copies variables formatted for .env to clipboard")

                        Button(action: {
                            let str = manager.exportAsShellExport(profile: profile)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(str, forType: .string)
                            showNotice("Copied export commands!", isError: false)
                        }) {
                            Label("Copy export", systemImage: "terminal")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Copy export commands")
                        .accessibilityHint("Copies shell export commands to clipboard")
                    }
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

                    if !noticeMessage.isEmpty {
                        HStack {
                            Spacer()
                            Text(noticeMessage)
                                .font(.caption)
                                .bold()
                                .foregroundStyle(isNoticeError ? .red : .green)
                                .padding(6)
                            Spacer()
                        }
                        .background(isNoticeError ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                        .accessibilityLabel("Notice: \(noticeMessage)")
                        .accessibilityAddTraits(.isStaticText)
                    }

                    Divider()

                    // Add Variable Row
                    HStack(spacing: 10) {
                        TextField("KEY_NAME", text: $newKey)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("New Variable Key Name")
                            .accessibilityHint("Enter upper case variable key name")

                        TextField("Value", text: $newValue)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("New Variable Value")
                            .accessibilityHint("Enter environment variable value")

                        Toggle("Secret", isOn: $isNewSecret)
                            .toggleStyle(.checkbox)
                            .accessibilityLabel("Mark as Secret")
                            .accessibilityHint("Hides variable value when secrets are masked")

                        Button("Add Variable") {
                            let trimmedKey = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard isKeyValid else { return }
                            let trimmedVal = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard trimmedVal.count <= EnvProfileManager.maxValueLength else {
                                showNotice("Value exceeds maximum allowed length (\(EnvProfileManager.maxValueLength) chars).", isError: true)
                                return
                            }

                            var updatedVars = profile.variables
                            if let idx = updatedVars.firstIndex(where: { $0.key == trimmedKey }) {
                                updatedVars[idx].value = trimmedVal
                                updatedVars[idx].isSecret = isNewSecret
                            } else {
                                updatedVars.append(EnvVariable(key: trimmedKey, value: trimmedVal, isSecret: isNewSecret))
                            }
                            profile.variables = updatedVars
                            manager.updateProfile(profile)
                            newKey = ""
                            newValue = ""
                            isNewSecret = false
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isKeyValid)
                        .accessibilityLabel("Add Variable")
                        .accessibilityHint("Adds or updates variable in the selected profile")
                    }
                    .padding()

                    Divider()

                    // Variables Table
                    List {
                        ForEach(profile.variables) { item in
                            HStack {
                                Text(item.key)
                                    .font(.system(.body, design: .monospaced))
                                    .bold()
                                    .frame(width: 200, alignment: .leading)
                                    .accessibilityLabel("Key: \(item.key)")

                                Spacer()

                                Text(maskSecrets && item.isSecret ? "••••••••••••••••" : item.value)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(item.isSecret ? Color.orange : Color.primary)
                                    .accessibilityLabel(maskSecrets && item.isSecret ? "Value: Hidden Secret" : "Value: \(item.value)")

                                Spacer()

                                if item.isSecret {
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .accessibilityLabel("Secret Variable")
                                }

                                Button(action: {
                                    var updatedVars = profile.variables
                                    updatedVars.removeAll { $0.id == item.id }
                                    profile.variables = updatedVars
                                    manager.updateProfile(profile)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete variable \(item.key)")
                                .accessibilityHint("Removes \(item.key) from current profile")
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.inset)
                    .accessibilityLabel("Variables list for \(profile.name)")
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("Select or Create an Environment Profile")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isHeader)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showAddProfileSheet) {
            VStack(spacing: 16) {
                Text("New Environment Profile")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                TextField("Profile Name (e.g. Staging Local)", text: $newProfileName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 340)
                    .accessibilityLabel("Profile Name")

                HStack {
                    TextField("Project Path (e.g. ~/Projects/MyApp)", text: $newProjectPath)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Project Path")
                    Button("Browse...") {
                        selectDirectory { path in
                            newProjectPath = path
                        }
                    }
                    .accessibilityLabel("Browse Directory")
                    .accessibilityHint("Opens folder picker to select project path")
                }
                .frame(width: 340)

                HStack {
                    Button("Cancel") {
                        showAddProfileSheet = false
                        newProfileName = ""
                        newProjectPath = ""
                    }
                    .accessibilityLabel("Cancel profile creation")

                    Button("Create") {
                        let trimmedName = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedName.isEmpty, trimmedName.count <= Self.maxProfileNameLength else {
                            showNotice("Profile name must be between 1 and \(Self.maxProfileNameLength) characters.", isError: true)
                            return
                        }

                        let trimmedPath = newProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedPath.isEmpty {
                            guard trimmedPath.count <= Self.maxPathLength else {
                                showNotice("Project path exceeds maximum allowed length (\(Self.maxPathLength) chars).", isError: true)
                                return
                            }
                            if case .failure(let error) = EnvProfileManager.normalizeAndValidatePath(trimmedPath) {
                                showNotice("Invalid project path: \(error.localizedDescription)", isError: true)
                                return
                            }
                        }

                        manager.addProfile(name: trimmedName, projectPath: trimmedPath)
                        newProfileName = ""
                        newProjectPath = ""
                        showAddProfileSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Create Profile")
                    .accessibilityHint("Creates profile with specified name and path")
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showEditPathSheet) {
            if var profile = selectedProfile {
                VStack(spacing: 16) {
                    Text("Edit Project Path")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)

                    HStack {
                        TextField("Project Path", text: $editProjectPath)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Project Path")
                        Button("Browse...") {
                            selectDirectory { path in
                                editProjectPath = path
                            }
                        }
                        .accessibilityLabel("Browse Directory")
                        .accessibilityHint("Opens folder picker to select project path")
                    }
                    .frame(width: 360)

                    HStack {
                        Button("Cancel") { showEditPathSheet = false }
                            .accessibilityLabel("Cancel editing project path")

                        Button("Save") {
                            let trimmedPath = editProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmedPath.isEmpty {
                                guard trimmedPath.count <= Self.maxPathLength else {
                                    showNotice("Project path exceeds maximum allowed length (\(Self.maxPathLength) chars).", isError: true)
                                    return
                                }
                                if case .failure(let error) = EnvProfileManager.normalizeAndValidatePath(trimmedPath) {
                                    showNotice("Invalid project path: \(error.localizedDescription)", isError: true)
                                    return
                                }
                            }
                            profile.projectPath = trimmedPath
                            manager.updateProfile(profile)
                            showEditPathSheet = false
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Save Project Path")
                        .accessibilityHint("Saves updated project path to current profile")
                    }
                }
                .padding(24)
            }
        }
    }

    private func showNotice(_ msg: String, isError: Bool) {
        noticeMessage = msg
        isNoticeError = isError
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if noticeMessage == msg {
                noticeMessage = ""
            }
        }
    }

    private func selectDirectory(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            if path.count <= Self.maxPathLength, case .success = EnvProfileManager.normalizeAndValidatePath(path) {
                completion(path)
            } else {
                showNotice("Selected directory path is invalid or too long.", isError: true)
            }
        }
    }

    private func importEnvFileModal() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            guard path.count <= Self.maxPathLength else {
                showNotice("Import failed: file path exceeds maximum length.", isError: true)
                return
            }
            do {
                let imported = try manager.importProfileFromEnvFile(at: path)
                showNotice("Imported profile '\(imported.name)' safely!", isError: false)
            } catch {
                showNotice("Import failed: \(error.localizedDescription)", isError: true)
            }
        }
    }

    private func exportToEnvFileModal(for profile: EnvProfile) {
        var targetFilePath = ""
        if !profile.projectPath.isEmpty {
            switch EnvProfileManager.normalizeAndValidatePath(profile.projectPath) {
            case .success(let url):
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue {
                    targetFilePath = (url.path as NSString).appendingPathComponent(".env")
                } else {
                    targetFilePath = url.path
                }
            case .failure(let error):
                showNotice("Export failed: invalid project path - \(error.localizedDescription)", isError: true)
                return
            }
        }

        if targetFilePath.isEmpty {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = ".env"
            panel.showsHiddenFiles = true
            if panel.runModal() == .OK, let url = panel.url {
                targetFilePath = url.path
            } else {
                return
            }
        }

        guard targetFilePath.count <= Self.maxPathLength else {
            showNotice("Export failed: target path exceeds maximum allowed length.", isError: true)
            return
        }

        do {
            try manager.exportProfileToEnvFile(profile: profile, to: targetFilePath)
            showNotice("Saved profile atomically to \(targetFilePath)", isError: false)
        } catch {
            showNotice("Save failed: \(error.localizedDescription)", isError: true)
        }
    }
}
