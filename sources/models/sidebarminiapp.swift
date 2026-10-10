import SwiftUI

enum sidebarminiappid: String, Identifiable {
    case systemHealth, powerEnergy, processesStartup, systemDiagnostics
    case networkInspector, networkControls, deviceConnections
    case privacyCenter, protectionEncryption, securityDiagnostics
    case storageManager, cleanupManager, fileTools
    case developerToolbox, developerUtilities
    case gitWorkbench
    case containerWorkbench, containerStorage, composeStacks
    case aiWorkbench, aiPrompts, aiCredentials
    case databaseWorkbench, databaseInspect, databaseBackups
    case apiWorkbench, apiPerformance, apiHistory
    case universalConverter
    case appMaintenance, systemConfiguration, fileConfiguration
    case desktopControls, clipboardText, documentHelpers
    case creatorDiscovery

    var id: String { rawValue }
}

struct sidebarminiapp: Identifiable, Equatable {
    let id: sidebarminiappid
    let title: String
    let subtitle: String
    let icon: String
    let workspace: JuicerWorkspace
    let items: [NavigationItem]

    var primary: NavigationItem { items[0] }

    static func all(for workspace: JuicerWorkspace) -> [sidebarminiapp] {
        switch workspace {
        case .system:
            return [
                .init(id: .systemHealth, title: "System Health", subtitle: "Live hardware and usage", icon: "waveform.path.ecg", workspace: .system, items: [.statusMonitor, .cpuMemoryMonitor, .gpuMonitor, .diskIOMonitor, .thermalMonitor]),
                .init(id: .powerEnergy, title: "Power & Energy", subtitle: "Battery, cooling, and memory", icon: "battery.100", workspace: .system, items: [.batteryHealth, .batterySaver, .powerSchedule, .fanController, .memoryPurge, .swapManager]),
                .init(id: .processesStartup, title: "Processes & Startup", subtitle: "Processes, services, and logs", icon: "gearshape.2", workspace: .system, items: [.processKiller, .startupItems, .loginItemDelays, .systemServices, .systemLogs, .kextManager]),
                .init(id: .systemDiagnostics, title: "System Diagnostics", subtitle: "Checks and safe cleanup", icon: "checkmark.shield", workspace: .system, items: [.workflowCenter, .memoryPressureOptimizer, .pathSecurityAuditor, .duplicateSanitizer])
            ]
        case .network:
            return [
                .init(id: .networkInspector, title: "Network Inspector", subtitle: "Traffic, speed, ports, and DNS", icon: "network", workspace: .network, items: [.speedTest, .networkTraffic, .publicIP, .wifiSurvey, .lanDiscovery, .portScanner, .portListener, .dnsDiagnostics]),
                .init(id: .networkControls, title: "Network Controls", subtitle: "VPN, firewall, profiles, and limits", icon: "network.badge.shield.half.filled", workspace: .network, items: [.firewall, .vpnProfiles, .vpnAutoConnect, .networkLocations, .networkProfileSwitcher, .hostsFile, .blocklistUpdater, .networkLimiter]),
                .init(id: .deviceConnections, title: "Device Connections", subtitle: "Bluetooth, AirDrop, and nearby devices", icon: "dot.radiowaves.left.and.right", workspace: .network, items: [.bluetoothDevices, .airDropQuickSend])
            ]
        case .security:
            return [
                .init(id: .privacyCenter, title: "Privacy Center", subtitle: "Permissions, sensors, and access", icon: "lock.shield", workspace: .security, items: [.tccViewer, .privacyScanner, .locationServices, .clipboardAccess, .microphoneCamera, .screenRecording, .permissionCenter]),
                .init(id: .protectionEncryption, title: "Protection & Encryption", subtitle: "Vaults, app protection, and deletion", icon: "lock.doc", workspace: .security, items: [.fileVault, .fileVaultAutoLock, .appLocker, .secureNotes, .passwordAudit, .secureDelete, .quarantinedFiles, .sandboxInspector]),
                .init(id: .securityDiagnostics, title: "Security Diagnostics", subtitle: "Integrity and exposure checks", icon: "checkmark.shield", workspace: .security, items: [.antiKeylogger, .zeroDayTCCAudit, .kextOrphanDetector, .dylibOrphanDetector, .networkExposure, .usbDeviceGuard])
            ]
        case .disk:
            return [
                .init(id: .storageManager, title: "Storage Manager", subtitle: "Explore, measure, and verify disks", icon: "internaldrive", workspace: .disk, items: [.diskExplorer, .diskVisualizer, .largeFiles, .diskSpacePredictor, .storageSnapshots, .diskVerification]),
                .init(id: .cleanupManager, title: "Cleanup Manager", subtitle: "Find and reclaim space safely", icon: "trash.fill", workspace: .disk, items: [.cacheCleaner, .devCaches, .duplicateFiles, .emptyFolders, .downloadOrganizer, .undoHistory]),
                .init(id: .fileTools, title: "File Tools", subtitle: "Archives, images, metadata, and links", icon: "folder.badge.gearshape", workspace: .disk, items: [.archiveUtility, .diskImages, .diskImageMounter, .fileTypeConverter, .symbolicLinks, .extendedAttributes, .metadataEditor, .backupTrigger])
            ]
        case .developer:
            return [
                .init(id: .developerToolbox, title: "Developer Toolbox", subtitle: "Runtimes, environments, scripts, and servers", icon: "terminal", workspace: .developer, items: [.sdkSwitcher, .envProfiles, .scriptConsole, .scriptPlugins, .codeSnippets, .localWebServer]),
                .init(id: .developerUtilities, title: "Developer Utilities", subtitle: "Logs, OCR, commands, and assets", icon: "hammer", workspace: .developer, items: [.logStream, .ocrScreenGrabber, .nlToCommand, .imageConverter, .appLanguageStripper])
            ]
        case .git:
            return [.init(id: .gitWorkbench, title: "Git Workbench", subtitle: "Repositories, history, and analytics", icon: "arrow.triangle.pull", workspace: .git, items: [.juicerGit, .gitExtras, .developerAccounts])]
        case .containers:
            return [
                .init(id: .containerWorkbench, title: "Container Workbench", subtitle: "Containers and logs", icon: "cube.fill", workspace: .containers, items: [.dockerDashboard, .dockerLogs]),
                .init(id: .containerStorage, title: "Container Storage", subtitle: "Purge images and build cache", icon: "trash.circle.fill", workspace: .containers, items: [.dockerPurge, .dockerBuildCachePurge]),
                .init(id: .composeStacks, title: "Compose Stacks", subtitle: "Launch and manage app stacks", icon: "square.stack.3d.up", workspace: .containers, items: [.dockerCompose])
            ]
        case .ai:
            return [
                .init(id: .aiWorkbench, title: "AI Workbench", subtitle: "Local models and benchmarks", icon: "cpu", workspace: .ai, items: [.aiWorkbench, .localLLMBenchmark]),
                .init(id: .aiPrompts, title: "Prompts & Chat", subtitle: "Prompt vault and assistant", icon: "sparkles", workspace: .ai, items: [.aiPromptVault, .aiChat]),
                .init(id: .aiCredentials, title: "AI Credentials", subtitle: "Provider keys and profiles", icon: "key.fill", workspace: .ai, items: [.aiKeyManager])
            ]
        case .database:
            return [
                .init(id: .databaseWorkbench, title: "Database Workbench", subtitle: "Daemons, ports, and connections", icon: "externaldrive", workspace: .database, items: [.dbDaemonMonitor]),
                .init(id: .databaseInspect, title: "Data Inspector", subtitle: "SQLite, schemas, and Redis", icon: "tablecells", workspace: .database, items: [.sqliteInspector, .sqliteSchemaInspector, .redisViewer]),
                .init(id: .databaseBackups, title: "Database Backups", subtitle: "SQL dumps and restores", icon: "externaldrive.badge.timemachine", workspace: .database, items: [.dbBackupTool])
            ]
        case .api:
            return [
                .init(id: .apiWorkbench, title: "API Workbench", subtitle: "Requests, cURL, and authentication", icon: "paperplane.fill", workspace: .api, items: [.apiWorkbench, .apiAuthManager]),
                .init(id: .apiPerformance, title: "API Performance", subtitle: "Latency and load testing", icon: "stopwatch.fill", workspace: .api, items: [.apiBenchmark, .apiLoadTester]),
                .init(id: .apiHistory, title: "API History", subtitle: "Presets and previous requests", icon: "clock.arrow.circlepath", workspace: .api, items: [.apiHistory])
            ]
        case .converter:
            return [.init(id: .universalConverter, title: "Universal Converter", subtitle: "Documents, images, schemas, and archives", icon: "arrow.triangle.2.circlepath", workspace: .converter, items: [.docConverter, .imageConverterStudio, .codeSchemaConverter, .archiveConverter])]
        case .configs:
            return [
                .init(id: .appMaintenance, title: "App Maintenance", subtitle: "Uninstall, repair, and optimize apps", icon: "trash.fill", workspace: .configs, items: [.appUninstaller, .orphanScanner, .brewGhost, .appLipo, .systemOptimizer]),
                .init(id: .systemConfiguration, title: "System Configuration", subtitle: "Services, tweaks, and launch behavior", icon: "slider.horizontal.3", workspace: .configs, items: [.serviceManager, .systemTweaks, .launchServices, .autoUpdateChecker, .logRotator]),
                .init(id: .fileConfiguration, title: "File Configuration", subtitle: "Permissions, metadata, and quarantine", icon: "lock.doc", workspace: .configs, items: [.permissionRepair, .extendedAttributes, .metadataEditor, .quarantineStripper, .dnsEditor])
            ]
        case .utilities:
            return [
                .init(id: .desktopControls, title: "Desktop & Windows", subtitle: "Windows, displays, and menu bar", icon: "macwindow", workspace: .utilities, items: [.windowSnapping, .menuBarCustomizer, .desktopIcons, .hotCorners, .keyboardShortcuts, .displayProfiles, .nightShift, .keyboardBacklight, .trackpadGestures]),
                .init(id: .clipboardText, title: "Clipboard & Text", subtitle: "Clipboard, snippets, and characters", icon: "doc.on.clipboard.fill", workspace: .utilities, items: [.clipboardManager, .snippetExpander, .textCaseConverter, .characterCounter, .japaneseKana, .emojiPicker, .unicodeInspector]),
                .init(id: .documentHelpers, title: "Documents & Helpers", subtitle: "Capture, convert, and system helpers", icon: "doc.richtext", workspace: .utilities, items: [.qrCode, .colorPicker, .screenRuler, .screenLoupe, .screenshotAnnotation, .printerQueue, .pdfToolbox, .markdownPreviewer, .shortcutRunner, .systemInfoExporter, .softwareInventory, .snapshots, .soundVolumeMixer])
            ]
        case .creator:
            return [.init(id: .creatorDiscovery, title: "Creator Discovery", subtitle: "Explore projects and developer resources", icon: "star.square.on.square.fill", workspace: .creator, items: [.creatorRepos])]
        default:
            return []
        }
    }
}
