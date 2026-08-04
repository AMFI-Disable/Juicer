import SwiftUI
import AppKit
import UniformTypeIdentifiers

typealias EnvProfileManagerView = envprofilemanagerview

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
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name)
                                        .font(.headline)
                                    Text("\(profile.variables.count) variables")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
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
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        Button(action: importEnvFileModal) {
                            Label("Import", systemImage: "square.and.arrow.down")
                        }
                        .help("Import .env File")

                        Button(action: { showAddProfileSheet = true }) {
                            Image(systemName: "plus")
                        }
                        .help("Create New Env Profile")
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
                            HStack(spacing: 4) {
                                if profile.projectPath.isEmpty {
                                    Text("No project path set")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                } else {
                                    Text(profile.projectPath)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
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
                            }
                        }

                        Spacer()

                        Toggle("Mask Secrets", isOn: $maskSecrets)
                            .toggleStyle(.switch)

                        Button(action: {
                            exportToEnvFileModal(for: profile)
                        }) {
                            Label("Save .env", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .help("Save atomically to .env file")

                        Button(action: {
                            let str = manager.exportAsEnvString(profile: profile)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(str, forType: .string)
                            showNotice("Copied .env format!", isError: false)
                        }) {
                            Label("Copy .env", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)

                        Button(action: {
                            let str = manager.exportAsShellExport(profile: profile)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(str, forType: .string)
                            showNotice("Copied export commands!", isError: false)
                        }) {
                            Label("Copy export", systemImage: "terminal")
                        }
                        .buttonStyle(.bordered)
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
                    }

                    Divider()

                    // Add Variable Row
                    HStack(spacing: 10) {
                        TextField("KEY_NAME", text: $newKey)
                            .textFieldStyle(.roundedBorder)
                        TextField("Value", text: $newValue)
                            .textFieldStyle(.roundedBorder)
                        Toggle("Secret", isOn: $isNewSecret)
                            .toggleStyle(.checkbox)

                        Button("Add Variable") {
                            let trimmedKey = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard isKeyValid else { return }
                            let trimmedVal = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

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

                                Spacer()

                                Text(maskSecrets && item.isSecret ? "••••••••••••••••" : item.value)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(item.isSecret ? Color.orange : Color.primary)

                                Spacer()

                                if item.isSecret {
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
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
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.inset)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Select or Create an Environment Profile")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showAddProfileSheet) {
            VStack(spacing: 16) {
                Text("New Environment Profile")
                    .font(.headline)

                TextField("Profile Name (e.g. Staging Local)", text: $newProfileName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 340)

                HStack {
                    TextField("Project Path (e.g. ~/Projects/MyApp)", text: $newProjectPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse...") {
                        selectDirectory { path in
                            newProjectPath = path
                        }
                    }
                }
                .frame(width: 340)

                HStack {
                    Button("Cancel") {
                        showAddProfileSheet = false
                        newProfileName = ""
                        newProjectPath = ""
                    }
                    Button("Create") {
                        if !newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            manager.addProfile(name: newProfileName, projectPath: newProjectPath)
                            newProfileName = ""
                            newProjectPath = ""
                            showAddProfileSheet = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showEditPathSheet) {
            if var profile = selectedProfile {
                VStack(spacing: 16) {
                    Text("Edit Project Path")
                        .font(.headline)

                    HStack {
                        TextField("Project Path", text: $editProjectPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse...") {
                            selectDirectory { path in
                                editProjectPath = path
                            }
                        }
                    }
                    .frame(width: 360)

                    HStack {
                        Button("Cancel") { showEditPathSheet = false }
                        Button("Save") {
                            profile.projectPath = editProjectPath
                            manager.updateProfile(profile)
                            showEditPathSheet = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(24)
            }
        }
    }

    private func showNotice(_ msg: String, isError: Bool) {
        noticeMessage = msg
        isNoticeError = isError
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
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
            completion(url.path)
        }
    }

    private func importEnvFileModal() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let imported = try manager.importProfileFromEnvFile(at: url.path)
                showNotice("Imported profile '\(imported.name)' safely!", isError: false)
            } catch {
                showNotice("Import failed: \(error.localizedDescription)", isError: true)
            }
        }
    }

    private func exportToEnvFileModal(for profile: EnvProfile) {
        var targetFilePath = ""
        if !profile.projectPath.isEmpty {
            let expanded = (profile.projectPath as NSString).expandingTildeInPath
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir) && isDir.boolValue {
                targetFilePath = (expanded as NSString).appendingPathComponent(".env")
            } else {
                targetFilePath = expanded
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

        do {
            try manager.exportProfileToEnvFile(profile: profile, to: targetFilePath)
            showNotice("Saved profile atomically to \(targetFilePath)", isError: false)
        } catch {
            showNotice("Save failed: \(error.localizedDescription)", isError: true)
        }
    }
}

