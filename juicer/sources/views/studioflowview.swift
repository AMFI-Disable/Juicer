import SwiftUI
import AppKit

enum studioflowcatalog {
    typealias group = (title: String, subtitle: String, items: [NavigationItem])

    static func groups(for workspace: JuicerWorkspace) -> [group] {
        switch workspace {
        case .network:
            return [
                ("Connection health", "Measure reachability and traffic", [.speedTest, .networkTraffic, .publicIP, .networkLimiter]),
                ("Diagnostics", "Inspect ports, DNS, and local devices", [.wifiSurvey, .lanDiscovery, .portScanner, .portListener, .dnsDiagnostics]),
                ("Network access", "Control profiles, VPN, and exposure", [.firewall, .vpnProfiles, .vpnAutoConnect, .networkExposure, .hostsFile, .blocklistUpdater]),
                ("Nearby devices", "Manage local network conveniences", [.networkLocations, .bluetoothDevices, .airDropQuickSend, .networkProfileSwitcher])
            ]
        case .security:
            return [
                ("Privacy & permissions", "Review access granted to apps and services", [.tccViewer, .privacyScanner, .locationServices, .clipboardAccess, .microphoneCamera, .screenRecording]),
                ("Vault & encryption", "Protect files, apps, and sensitive notes", [.fileVault, .fileVaultAutoLock, .secureNotes, .appLocker, .passwordAudit, .secureDelete]),
                ("System defense", "Inspect quarantine, sandbox, and hardware access", [.antiKeylogger, .quarantinedFiles, .sandboxInspector, .usbDeviceGuard, .permissionCenter]),
                ("Security diagnostics", "Audit deeper system security surfaces", [.zeroDayTCCAudit, .kextOrphanDetector, .dylibOrphanDetector])
            ]
        case .disk:
            return [
                ("Explore & measure", "Understand what is using your storage", [.diskExplorer, .diskVisualizer, .storageSnapshots, .diskVerification, .diskImageMounter]),
                ("Clean safely", "Find reclaimable space before removing anything", [.cacheCleaner, .devCaches, .largeFiles, .duplicateFiles, .emptyFolders]),
                ("File utilities", "Organize, inspect, and protect files", [.undoHistory, .downloadOrganizer, .archiveUtility, .diskImages, .fileTypeConverter, .symbolicLinks, .diskSpacePredictor, .backupTrigger])
            ]
        case .developer:
            return [
                ("Runtimes & scripts", "Set up environments and run repeatable work", [.sdkSwitcher, .scriptPlugins, .scriptConsole, .localWebServer]),
                ("Code & tooling", "Transform, inspect, and reuse developer content", [.codeSnippets, .envProfiles, .ocrScreenGrabber, .logStream, .nlToCommand, .imageConverter, .appLanguageStripper])
            ]
        case .git:
            return [
                ("Repository workbench", "Open, inspect, and operate on repositories", [.juicerGit, .gitExtras, .developerAccounts]),
            ]
        case .containers:
            return [
                ("Container workbench", "Inspect and operate on running containers", [.dockerDashboard, .dockerLogs]),
                ("Storage & cleanup", "Recover local container disk space", [.dockerPurge, .dockerBuildCachePurge]),
                ("Compose", "Launch and manage local application stacks", [.dockerCompose])
            ]
        case .ai:
            return [
                ("Models", "Check local runtimes and benchmark readiness", [.aiWorkbench, .localLLMBenchmark]),
                ("Prompts & chat", "Build, save, and test AI-assisted workflows", [.aiPromptVault, .aiChat]),
                ("Credentials", "Manage local AI provider profiles", [.aiKeyManager])
            ]
        case .database:
            return [
                ("Connections", "Check local database daemons and ports", [.dbDaemonMonitor]),
                ("Inspect data", "Browse SQLite, local databases, and Redis", [.sqliteInspector, .sqliteSchemaInspector, .redisViewer]),
                ("Backups", "Create and manage SQL dumps", [.dbBackupTool])
            ]
        case .api:
            return [
                ("Request workbench", "Build and inspect REST requests", [.apiWorkbench, .apiAuthManager]),
                ("Performance", "Measure endpoint latency and load", [.apiBenchmark, .apiLoadTester]),
                ("History", "Reuse previous requests and presets", [.apiHistory])
            ]
        case .converter:
            return [
                ("Documents", "Convert text and document formats", [.docConverter]),
                ("Images", "Batch convert graphic assets", [.imageConverterStudio]),
                ("Code & schemas", "Transform structured developer data", [.codeSchemaConverter]),
                ("Archives", "Compress and extract packages", [.archiveConverter])
            ]
        case .configs:
            return [
                ("App maintenance", "Remove, inspect, and repair applications", [.appUninstaller, .orphanScanner, .brewGhost, .appLipo, .systemOptimizer]),
                ("Services & tweaks", "Manage launch behavior and system preferences", [.serviceManager, .systemTweaks, .launchServices, .autoUpdateChecker, .logRotator]),
                ("Permissions & attributes", "Review metadata and file-level controls", [.permissionRepair, .extendedAttributes, .metadataEditor, .quarantineStripper, .dnsEditor])
            ]
        case .utilities:
            return [
                ("Desktop & windows", "Shape the way macOS feels and behaves", [.windowSnapping, .menuBarCustomizer, .desktopIcons, .hotCorners, .keyboardShortcuts, .displayProfiles, .nightShift, .keyboardBacklight, .trackpadGestures]),
                ("Text & capture", "Work faster with text, screens, and symbols", [.clipboardManager, .snippetExpander, .textCaseConverter, .characterCounter, .qrCode, .colorPicker, .screenRuler, .screenLoupe, .screenshotAnnotation]),
                ("Documents & helpers", "Handle everyday files and system tasks", [.printerQueue, .pdfToolbox, .markdownPreviewer, .japaneseKana, .emojiPicker, .unicodeInspector, .shortcutRunner, .systemInfoExporter, .softwareInventory, .snapshots, .soundVolumeMixer])
            ]
        case .creator:
            return [
                ("Discover", "Explore open-source projects and their capabilities", [.creatorRepos])
            ]
        default:
            return []
        }
    }

    static func recommended(for workspace: JuicerWorkspace) -> [NavigationItem] {
        switch workspace {
        case .network: return [.speedTest, .dnsDiagnostics, .portListener]
        case .security: return [.tccViewer, .privacyScanner, .fileVault]
        case .disk: return [.diskExplorer, .cacheCleaner, .largeFiles]
        case .developer: return [.sdkSwitcher, .envProfiles, .scriptConsole]
        case .git: return [.juicerGit, .gitExtras, .developerAccounts]
        case .containers: return [.dockerDashboard, .dockerLogs, .dockerCompose]
        case .ai: return [.aiWorkbench, .aiChat, .aiKeyManager]
        case .database: return [.dbDaemonMonitor, .sqliteInspector, .dbBackupTool]
        case .api: return [.apiWorkbench, .apiBenchmark, .apiHistory]
        case .converter: return [.docConverter, .imageConverterStudio, .codeSchemaConverter]
        case .configs: return [.appUninstaller, .orphanScanner, .systemOptimizer]
        case .utilities: return [.clipboardManager, .windowSnapping, .systemInfoExporter]
        case .creator: return [.creatorRepos]
        default: return []
        }
    }
}

struct studioflowview: View {
    let workspace: JuicerWorkspace
    let items: [NavigationItem]
    let favorites: [NavigationItem]
    let recent: [NavigationItem]
    let onSelect: (NavigationItem) -> Void

    private var configuredGroups: [studioflowcatalog.group] {
        let known = Set(studioflowcatalog.groups(for: workspace).flatMap(\.items))
        let remaining = items.filter { !known.contains($0) }
        guard !remaining.isEmpty else { return studioflowcatalog.groups(for: workspace) }
        return studioflowcatalog.groups(for: workspace) + [("More tools", "Additional tools in this workspace", remaining)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if !studioflowcatalog.recommended(for: workspace).isEmpty { flowSection("Suggested path", subtitle: "A practical order for a first check", items: studioflowcatalog.recommended(for: workspace), numbered: true) }
                if !favorites.isEmpty { flowSection("Favorites", subtitle: "Your pinned tools", items: favorites) }
                if !recent.isEmpty { flowSection("Continue", subtitle: "Recently opened tools", items: recent) }
                ForEach(configuredGroups, id: \.title) { group in flowSection(group.title, subtitle: group.subtitle, items: group.items) }
            }
            .padding(32)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(workspace.title, systemImage: workspace.iconName).font(.largeTitle.bold()).foregroundStyle(workspace.themeColor)
            Text(workspace.description).font(.title3).foregroundStyle(.secondary)
            Text("Start with a workflow, then open a focused tool only when you need its deeper controls.").font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func flowSection(_ title: String, subtitle: String, items: [NavigationItem], numbered: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) { Text(title).font(.headline); Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.element) { index, item in
                    Button { onSelect(item) } label: {
                        HStack(spacing: 10) {
                            if numbered { Text("\(index + 1)").font(.caption.bold()).foregroundStyle(workspace.themeColor).frame(width: 18) }
                            Image(systemName: item.iconName).frame(width: 22).foregroundStyle(workspace.themeColor)
                            Text(item.title).font(.subheadline.weight(.medium)).foregroundStyle(.primary).multilineTextAlignment(.leading).lineLimit(2)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
