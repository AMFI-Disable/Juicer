import SwiftUI
import AppKit

@MainActor
struct applanguagestripperview: View {
    @StateObject private var manager = AppLanguageStripperManager()
    @State private var searchText = ""
    @State private var showConfirmAlert = false

    var filteredBundles: [AppLanguageBundle] {
        if searchText.isEmpty { return manager.foundBundles }
        return manager.foundBundles.filter {
            $0.appName.localizedCaseInsensitiveContains(searchText) ||
            $0.languageCode.localizedCaseInsensitiveContains(searchText)
        }
    }

    var selectedSize: Int64 {
        let selectedBundles = manager.foundBundles.filter { $0.isSelected }
        var total: Int64 = 0
        for bundle in selectedBundles {
            let (result, overflow) = total.reportingOverflowingAdd(bundle.size)
            total = overflow ? Int64.max : max(0, result)
        }
        return total
    }

    private var allFilteredSelected: Bool {
        !filteredBundles.isEmpty && filteredBundles.allSatisfy { $0.isSelected }
    }

    private func updateSelection(for bundle: AppLanguageBundle, isSelected: Bool) {
        guard !manager.foundBundles.isEmpty else { return }
        if let origIdx = manager.foundBundles.firstIndex(where: { $0.id == bundle.id }),
           manager.foundBundles.indices.contains(origIdx) {
            manager.foundBundles[origIdx].isSelected = isSelected
        }
    }

    private func toggleSelectAllFiltered() {
        guard !manager.foundBundles.isEmpty else { return }
        let targetState = !allFilteredSelected
        let filteredIDs = Set(filteredBundles.map { $0.id })
        for idx in manager.foundBundles.indices {
            if manager.foundBundles.indices.contains(idx) && filteredIDs.contains(manager.foundBundles[idx].id) {
                manager.foundBundles[idx].isSelected = targetState
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("App Language Asset Stripper")
                        .font(.title2)
                        .bold()
                        .accessibilityAddTraits(.isHeader)
                    Text("Strip unused localization files (.lproj) from installed applications to reclaim disk space.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if manager.isScanning {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Scanning applications for language files")
                } else {
                    Button(action: { manager.scanAppLanguages() }) {
                        Label("Scan Apps", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(manager.isStripping)
                    .accessibilityLabel("Scan Applications")
                    .accessibilityHint("Scans installed applications for unused localization language files")
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

            Divider()

            // Search & Action Toolbar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Search App Name or Language...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                    .accessibilityLabel("Search application name or language code")
                    .accessibilityHint("Filters the list of unused language files by app name or language code")

                if !filteredBundles.isEmpty {
                    Button(action: toggleSelectAllFiltered) {
                        Text(allFilteredSelected ? "Deselect All" : "Select All")
                    }
                    .buttonStyle(.bordered)
                    .disabled(manager.isScanning || manager.isStripping)
                    .accessibilityLabel(allFilteredSelected ? "Deselect all visible items" : "Select all visible items")
                    .accessibilityHint("Toggles selection state for all visible language asset items")
                }

                Spacer()

                Text("Selected: \(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file))")
                    .font(.callout)
                    .bold()
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Selected size: \(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file))")

                Button(action: { showConfirmAlert = true }) {
                    Label("Strip Selected", systemImage: "scissors")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedSize == 0 || manager.isStripping || manager.isScanning)
                .accessibilityLabel("Strip Selected Language Files")
                .accessibilityHint("Permanently removes selected localization directories from disk")
            }
            .padding()

            Divider()

            // Results List
            if manager.isScanning {
                VStack(spacing: 12) {
                    ProgressView("Scanning Applications for unused language files...")
                        .accessibilityLabel("Scanning applications for unused language files")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if manager.foundBundles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                    Text("No unused language assets found!")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("No unused language assets found")
            } else {
                List {
                    ForEach(filteredBundles) { bundle in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { bundle.isSelected },
                                set: { val in
                                    updateSelection(for: bundle, isSelected: val)
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bundle.appName)
                                        .font(.headline)
                                    Text("Language: \(bundle.languageCode).lproj")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(manager.isStripping)
                            .accessibilityLabel("\(bundle.appName), \(bundle.languageCode) localization package")
                            .accessibilityValue(bundle.isSelected ? "Selected for removal" : "Not selected")
                            .accessibilityHint("Double tap to toggle selection of \(bundle.appName) \(bundle.languageCode) package for removal")

                            Spacer()

                            Text(ByteCountFormatter.string(fromByteCount: bundle.size, countStyle: .file))
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Size: \(ByteCountFormatter.string(fromByteCount: bundle.size, countStyle: .file))")
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
                .accessibilityLabel("Unused language assets list")
            }
        }
        .onAppear {
            manager.scanAppLanguages()
        }
        .alert("Strip Selected Language Files?", isPresented: $showConfirmAlert) {
            Button("Strip Language Files", role: .destructive) {
                manager.stripSelectedLanguages { _ in }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the selected .lproj localization directories from your applications. Are you sure you want to proceed?")
        }
    }
}

