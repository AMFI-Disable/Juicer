import SwiftUI

struct sidebarminiappview: View {
    let app: sidebarminiapp

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                JuicerSymbol(name: app.icon, fallback: "square.grid.2x2")
                    .font(.title2)
                    .foregroundStyle(app.workspace.themeColor)
                    .frame(width: 38, height: 38)
                    .background(app.workspace.themeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.title).font(.title2.bold())
                    Text(app.subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 8)

            tabs
        }
    }

    @ViewBuilder
    private var tabs: some View {
        switch app.id {
        case .systemHealth:
            TabView {
                statusmonitorview().tabItem { tabLabel("Overview", "waveform.path.ecg") }
                cpumemorymonitorview().tabItem { tabLabel("CPU & Memory", "memorychip") }
                gpumonitorview().tabItem { tabLabel("GPU", "display.2") }
                diskiomonitorview().tabItem { tabLabel("Disk", "internaldrive") }
                thermalmonitorview().tabItem { tabLabel("Thermals", "thermometer.medium") }
            }
        case .powerEnergy:
            TabView {
                batteryhealthview().tabItem { tabLabel("Battery", "battery.100") }
                batterysaverview().tabItem { tabLabel("Saver", "battery.50percent") }
                powerscheduleview().tabItem { tabLabel("Schedule", "calendar.badge.clock") }
                fancontrollerview().tabItem { tabLabel("Fans", "fanblades.fill") }
                memorypurgeview().tabItem { tabLabel("Memory", "memorychip") }
                swapmanagerview().tabItem { tabLabel("Swap", "arrow.left.arrow.right") }
            }
        case .processesStartup:
            TabView {
                processkillerview().tabItem { tabLabel("Processes", "xmark.octagon") }
                startupitemview().tabItem { tabLabel("Startup", "arrow.up.forward.app") }
                loginitemdelayview().tabItem { tabLabel("Delays", "timer") }
                systemservicesview().tabItem { tabLabel("Services", "gearshape.2") }
                systemlogview().tabItem { tabLabel("Logs", "doc.text.magnifyingglass") }
                kextmanagerview().tabItem { tabLabel("Extensions", "puzzlepiece.extension") }
            }
        case .systemDiagnostics:
            TabView {
                workflowcenterview().tabItem { tabLabel("Checks", "list.bullet.clipboard") }
                MemoryPressureOptimizerView().tabItem { tabLabel("Memory", "memorychip") }
                PathSecurityAuditorView().tabItem { tabLabel("PATH", "lock.shield") }
                duplicatefileview().tabItem { tabLabel("Duplicates", "doc.on.doc") }
            }
        case .networkInspector:
            TabView {
                speedtestview().tabItem { tabLabel("Speed", "speedometer") }
                networkbandwidthmanagerview().tabItem { tabLabel("Traffic", "network") }
                publicipview().tabItem { tabLabel("Public IP", "globe") }
                wifisurveyview().tabItem { tabLabel("Wi-Fi", "wifi") }
                landiscoveryview().tabItem { tabLabel("LAN", "network") }
                portscannerview().tabItem { tabLabel("Ports", "dot.radiowaves.left.and.right") }
                portlistenerview().tabItem { tabLabel("Listeners", "arrow.right.circle.fill") }
                dnsdiagnosticsview().tabItem { tabLabel("DNS", "network.badge.shield.half.filled") }
            }
        case .networkControls:
            TabView {
                firewallview().tabItem { tabLabel("Firewall", "flame") }
                vpnprofileview().tabItem { tabLabel("VPN", "lock.shield") }
                vpnautoconnectview().tabItem { tabLabel("Auto-connect", "lock.shield") }
                networklocationview().tabItem { tabLabel("Locations", "network") }
                networkprofileswitcherview().tabItem { tabLabel("Profiles", "slider.horizontal.3") }
                hostsfileview().tabItem { tabLabel("Hosts", "list.bullet.rectangle") }
                blocklistupdaterview().tabItem { tabLabel("Blocklists", "shield.checkered") }
                networklimiterview().tabItem { tabLabel("Limits", "gauge.with.dots.needle.33percent") }
            }
        case .deviceConnections:
            TabView {
                bluetoothdeviceview().tabItem { tabLabel("Bluetooth", "dot.radiowaves.left.and.right") }
                airdropquicksendview().tabItem { tabLabel("AirDrop", "airplayaudio") }
            }
        case .privacyCenter:
            TabView {
                tccviewerview().tabItem { tabLabel("Permissions", "lock.shield") }
                privacyscannerview().tabItem { tabLabel("Scanner", "hand.raised.shield") }
                locationservicesview().tabItem { tabLabel("Location", "location.fill") }
                clipboardaccessview().tabItem { tabLabel("Clipboard", "doc.on.clipboard") }
                microphonecameraindicatorview().tabItem { tabLabel("Sensors", "mic.and.signal.meter") }
                screenrecordingdetectorview().tabItem { tabLabel("Recording", "record.circle") }
                permissioncenterview().tabItem { tabLabel("Center", "info.circle") }
            }
        case .protectionEncryption:
            TabView {
                filevaultview().tabItem { tabLabel("FileVault", "lock.shield") }
                filevaultautolockview().tabItem { tabLabel("Auto-lock", "lock.display") }
                applockerview().tabItem { tabLabel("App Lock", "lock.app.dashed") }
                securenotesvaultview().tabItem { tabLabel("Notes", "note.text.badge.lock") }
                passwordauditview().tabItem { tabLabel("Passwords", "key.fill") }
                securedeleteview().tabItem { tabLabel("Secure Delete", "trash.slash") }
                quarantinedfilesview().tabItem { tabLabel("Quarantine", "shield.lefthalf.filled") }
                sandboxinspectorview().tabItem { tabLabel("Sandbox", "shippingbox") }
            }
        case .securityDiagnostics:
            TabView {
                antikeyloggerscannerview().tabItem { tabLabel("Keylogger", "keyboard.badge.ellipsis") }
                ZeroDayTCCAuditView().tabItem { tabLabel("TCC Audit", "lock.shield.fill") }
                KernelExtensionDetectorView().tabItem { tabLabel("KEXT", "puzzlepiece.extension") }
                DylibIntegrityDetectorView().tabItem { tabLabel("Dylib", "link.badge.plus") }
                networkexposureview().tabItem { tabLabel("Exposure", "network.badge.shield.half.filled") }
                usbdeviceguardview().tabItem { tabLabel("USB", "externaldrive.connected.to.line.below") }
            }
        case .storageManager:
            TabView {
                diskexplorerview().tabItem { tabLabel("Explore", "externaldrive") }
                diskvisualizerview().tabItem { tabLabel("Visualize", "chart.bar.fill") }
                largefilesview().tabItem { tabLabel("Large Files", "doc.badge.ellipsis") }
                diskspacepredictorview().tabItem { tabLabel("Predict", "chart.line.uptrend.xyaxis") }
                storagesnapshotview().tabItem { tabLabel("Snapshots", "clock.arrow.circlepath") }
                diskverificationview().tabItem { tabLabel("Verify", "checkmark.shield") }
            }
        case .cleanupManager:
            TabView {
                cachecleanerview().tabItem { tabLabel("Caches", "trash.fill") }
                cacheprunerview().tabItem { tabLabel("Developer", "folder.badge.gearshape") }
                duplicatefileview().tabItem { tabLabel("Duplicates", "doc.on.doc") }
                emptyfolderview().tabItem { tabLabel("Empty Folders", "folder.badge.minus") }
                downloadorganizerview().tabItem { tabLabel("Downloads", "folder.badge.gearshape") }
                deletionhistoryview().tabItem { tabLabel("History", "clock.arrow.circlepath") }
            }
        case .fileTools:
            TabView {
                archiveutilityview().tabItem { tabLabel("Archives", "archivebox") }
                diskimageview().tabItem { tabLabel("Disk Images", "externaldrive.badge.timemachine") }
                diskimagemounterview().tabItem { tabLabel("Mount", "externaldrive.badge.plus") }
                filetypeconverterview().tabItem { tabLabel("Types", "arrow.triangle.2.circlepath") }
                symboliclinkview().tabItem { tabLabel("Links", "link") }
                extendedattributeview().tabItem { tabLabel("Attributes", "tag") }
                metadataeditorview().tabItem { tabLabel("Metadata", "tag.fill") }
                backuptriggerview().tabItem { tabLabel("Backup", "externaldrive.badge.timemachine") }
            }
        case .developerToolbox:
            TabView {
                sdkmanagerview().tabItem { tabLabel("SDKs", "square.stack.3d.down.dotted.line") }
                envprofilemanagerview().tabItem { tabLabel("Environments", "slider.horizontal.3") }
                scriptconsoleview().tabItem { tabLabel("Console", "terminal") }
                scriptpluginsview().tabItem { tabLabel("Plugins", "puzzlepiece.extension") }
                codesnippetsview().tabItem { tabLabel("Snippets", "curlybraces.square") }
                localwebserverview().tabItem { tabLabel("Server", "server.rack") }
            }
        case .developerUtilities:
            TabView {
                logstreamview().tabItem { tabLabel("Logs", "doc.text.magnifyingglass") }
                ocrscreengraberview().tabItem { tabLabel("OCR", "viewfinder") }
                nltocommandview().tabItem { tabLabel("Commands", "text.bubble") }
                imageconverterview().tabItem { tabLabel("Images", "photo") }
                applanguagestripperview().tabItem { tabLabel("Languages", "globe") }
            }
        case .gitWorkbench:
            TabView {
                gitdashboardview().tabItem { tabLabel("Repository", "arrow.triangle.pull") }
                gitextrasview().tabItem { tabLabel("Analytics", "chart.bar.xaxis") }
                developeraccountsview().tabItem { tabLabel("Accounts", "person.badge.key.fill") }
            }
        case .containerWorkbench:
            TabView { dockerstudioview().tabItem { tabLabel("Containers", "cube.fill") } }
        case .containerStorage:
            TabView {
                dockerstudioview().tabItem { tabLabel("Images", "cube.transparent") }
                DockerBuildCachePurgeView().tabItem { tabLabel("Build Cache", "trash.circle.fill") }
            }
        case .composeStacks:
            TabView { dockerstudioview().tabItem { tabLabel("Compose", "square.stack.3d.up") } }
        case .aiWorkbench:
            TabView {
                aistudioview().tabItem { tabLabel("Models", "cpu") }
                LocalLLMBenchmarkView().tabItem { tabLabel("Benchmark", "stopwatch.fill") }
            }
        case .aiPrompts:
            TabView { aistudioview().tabItem { tabLabel("Prompts & Chat", "sparkles") } }
        case .aiCredentials:
            TabView { aistudioview().tabItem { tabLabel("Credentials", "key.fill") } }
        case .databaseWorkbench, .databaseInspect, .databaseBackups:
            TabView { databasestudioview().tabItem { tabLabel("Database", "externaldrive") } }
        case .apiWorkbench, .apiPerformance, .apiHistory:
            TabView {
                apistudioview().tabItem { tabLabel("Workbench", "paperplane.fill") }
                APILoadTesterView().tabItem { tabLabel("Load Test", "stopwatch.fill") }
            }
        case .universalConverter:
            TabView { converterstudioview().tabItem { tabLabel("Convert", "arrow.triangle.2.circlepath") } }
        case .appMaintenance:
            TabView {
                appuninstallerview().tabItem { tabLabel("Uninstall", "trash.fill") }
                orphanscannerview().tabItem { tabLabel("Orphans", "folder.badge.minus") }
                brewghostview().tabItem { tabLabel("Brew Ghost", "sparkles") }
                applipoview().tabItem { tabLabel("Slice", "cpu") }
                systemoptimizerview().tabItem { tabLabel("Optimize", "wand.and.stars") }
            }
        case .systemConfiguration:
            TabView {
                launchdmanagerview().tabItem { tabLabel("Services", "gearshape.2") }
                systemtweakerview().tabItem { tabLabel("Tweaks", "slider.horizontal.3") }
                launchservicesview().tabItem { tabLabel("Associations", "app.dashed") }
                autoupdatecheckerview().tabItem { tabLabel("Updates", "arrow.triangle.2.circlepath") }
                logrotatorview().tabItem { tabLabel("Logs", "doc.zipper") }
            }
        case .fileConfiguration:
            TabView {
                permissionrepairview().tabItem { tabLabel("Permissions", "lock.doc") }
                extendedattributeview().tabItem { tabLabel("Attributes", "tag") }
                metadataeditorview().tabItem { tabLabel("Metadata", "tag.fill") }
                quarantinestripperview().tabItem { tabLabel("Quarantine", "shield.slash.fill") }
                dnseditorview().tabItem { tabLabel("DNS", "network.badge.shield.half.filled") }
            }
        case .desktopControls:
            TabView {
                windowsnappingview().tabItem { tabLabel("Windows", "macwindow") }
                menubarcustomizerview().tabItem { tabLabel("Menu Bar", "menubar.rectangle") }
                desktopiconstoggleview().tabItem { tabLabel("Desktop", "macwindow") }
                hotcornersview().tabItem { tabLabel("Hot Corners", "rectangle.4.connected.lines") }
                keyboardshortcutview().tabItem { tabLabel("Shortcuts", "keyboard") }
                displayprofileview().tabItem { tabLabel("Displays", "display.2") }
                nightshiftschedulerview().tabItem { tabLabel("Night Shift", "sun.horizon") }
                keyboardbacklightview().tabItem { tabLabel("Backlight", "light.min") }
                trackpadgestureview().tabItem { tabLabel("Trackpad", "hand.draw") }
            }
        case .clipboardText:
            TabView {
                clipboardmanagerview().tabItem { tabLabel("Clipboard", "doc.on.clipboard.fill") }
                snippetexpanderview().tabItem { tabLabel("Snippets", "text.badge.plus") }
                textcaseconverterview().tabItem { tabLabel("Case", "textformat") }
                charactercounterview().tabItem { tabLabel("Count", "number") }
                japanesekanahelperview().tabItem { tabLabel("Kana", "character.book.closed") }
                emojipickerview().tabItem { tabLabel("Emoji", "face.smiling") }
                unicodeinspectorview().tabItem { tabLabel("Unicode", "character") }
            }
        case .documentHelpers:
            TabView {
                qrcodeview().tabItem { tabLabel("QR", "qrcode") }
                colorpickerview().tabItem { tabLabel("Color", "eyedropper.halffull") }
                screenrulerview().tabItem { tabLabel("Ruler", "ruler") }
                screenloupeview().tabItem { tabLabel("Loupe", "magnifyingglass") }
                screenshotannotationview().tabItem { tabLabel("Annotate", "pencil.and.outline") }
                printerqueueview().tabItem { tabLabel("Printer", "printer") }
                pdftoolboxview().tabItem { tabLabel("PDF", "doc.richtext") }
                markdownpreviewerview().tabItem { tabLabel("Markdown", "doc.text") }
                shortcutrunnerview().tabItem { tabLabel("Shortcuts", "command") }
                systeminfoexporterview().tabItem { tabLabel("System Info", "doc.badge.gearshape") }
                softwareinventoryview().tabItem { tabLabel("Inventory", "shippingbox") }
                snapshotsview().tabItem { tabLabel("Snapshots", "camera.viewfinder") }
                soundvolumemixerview().tabItem { tabLabel("Sound", "speaker.wave.2") }
            }
        case .creatorDiscovery:
            TabView { creatorecosystemview().tabItem { tabLabel("Discover", "star.square.on.square.fill") } }
        }
    }

    private func tabLabel(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon)
    }
}
