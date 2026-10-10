import SwiftUI
import Combine

struct ContextPayload: Equatable {
    var pid: Int?
    var processName: String?
    var urlString: String?
    var folderURL: URL?
    var port: Int?
    var searchQuery: String?
    var sourceStudio: JuicerWorkspace?

    init(
        pid: Int? = nil,
        processName: String? = nil,
        urlString: String? = nil,
        folderURL: URL? = nil,
        port: Int? = nil,
        searchQuery: String? = nil,
        sourceStudio: JuicerWorkspace? = nil
    ) {
        self.pid = pid
        self.processName = processName
        self.urlString = urlString
        self.folderURL = folderURL
        self.port = port
        self.searchQuery = searchQuery
        self.sourceStudio = sourceStudio
    }
}

final class StudioContextBridgeManager: ObservableObject {
    static let shared = StudioContextBridgeManager()

    @Published var pendingPayload: ContextPayload?
    @Published var pendingTarget: NavigationItem?

    static let bridgeNotification = Notification.Name("juicer.studio.contextBridge")

    private init() {}

    /// Navigates to a target studio tool with a contextual payload.
    func navigate(to target: NavigationItem, payload: ContextPayload? = nil) {
        DispatchQueue.main.async {
            self.pendingPayload = payload
            self.pendingTarget = target

            var userInfo: [AnyHashable: Any] = ["target": target]
            if let payload {
                userInfo["payload"] = payload
            }

            NotificationCenter.default.post(
                name: Self.bridgeNotification,
                object: target,
                userInfo: userInfo
            )
        }
    }

    /// Convenience 1-click contextual action: Inspect PID in System Studio.
    func inspectPIDInSystemStudio(pid: Int, processName: String? = nil, sourceStudio: JuicerWorkspace? = nil) {
        let payload = ContextPayload(pid: pid, processName: processName, searchQuery: "\(pid)", sourceStudio: sourceStudio)
        navigate(to: .portListener, payload: payload)
    }

    /// Convenience 1-click contextual action: Test Endpoint in API Studio.
    func testEndpointInAPIStudio(urlString: String, sourceStudio: JuicerWorkspace? = nil) {
        let payload = ContextPayload(urlString: urlString, sourceStudio: sourceStudio)
        navigate(to: .apiWorkbench, payload: payload)
    }

    /// Convenience 1-click contextual action: Serve Folder in Developer Studio.
    func serveFolderInDeveloperStudio(url: URL, sourceStudio: JuicerWorkspace? = nil) {
        let payload = ContextPayload(folderURL: url, sourceStudio: sourceStudio)
        navigate(to: .localWebServer, payload: payload)
    }

    /// Convenience 1-click contextual action: Inspect Sockets in Network Studio.
    func inspectSocketsInNetworkStudio(query: String, sourceStudio: JuicerWorkspace? = nil) {
        let payload = ContextPayload(searchQuery: query, sourceStudio: sourceStudio)
        navigate(to: .networkExposure, payload: payload)
    }

    /// Convenience 1-click contextual action: Inspect Caches in Disk Studio.
    func inspectFolderInDiskStudio(url: URL, sourceStudio: JuicerWorkspace? = nil) {
        let payload = ContextPayload(folderURL: url, sourceStudio: sourceStudio)
        navigate(to: .diskExplorer, payload: payload)
    }

    /// Clear consumed payload
    func clearPayload() {
        self.pendingPayload = nil
        self.pendingTarget = nil
    }
}
