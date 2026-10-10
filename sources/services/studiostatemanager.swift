import Foundation
import Combine
import SwiftUI

/// Central coordinator for lazy loading and memory footprint optimization of studio state managers.
final class StudioStateManager: ObservableObject {
    static let shared = StudioStateManager()

    @Published private(set) var activeWorkspace: JuicerWorkspace?
    @Published private(set) var activeStudioManagerNames: Set<String> = []

    private init() {}

    /// On-demand lazy loader triggered when a studio workspace is selected.
    func activateWorkspace(_ workspace: JuicerWorkspace) {
        guard activeWorkspace != workspace else { return }
        let previousWorkspace = activeWorkspace
        activeWorkspace = workspace

        switch workspace {
        case .ai:
            AIManager.shared.ensureInitialized()
            activeStudioManagerNames.insert("AIManager")
        case .database:
            DatabaseManager.shared.ensureInitialized()
            activeStudioManagerNames.insert("DatabaseManager")
        case .containers:
            DockerManager.shared.ensureInitialized()
            activeStudioManagerNames.insert("DockerManager")
        case .api:
            APIManager.shared.ensureInitialized()
            activeStudioManagerNames.insert("APIManager")
        case .converter:
            ConverterManager.shared.ensureInitialized()
            activeStudioManagerNames.insert("ConverterManager")
        default:
            break
        }

        if let prev = previousWorkspace, prev != workspace {
            purgeInactiveMemory(for: prev)
        }
    }

    /// Purges transient buffers & non-essential cached memory when a studio workspace becomes inactive.
    private func purgeInactiveMemory(for workspace: JuicerWorkspace) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, self.activeWorkspace != workspace else { return }
            switch workspace {
            case .ai:
                AIManager.shared.purgeMemory()
                self.activeStudioManagerNames.remove("AIManager")
            case .database:
                DatabaseManager.shared.purgeMemory()
                self.activeStudioManagerNames.remove("DatabaseManager")
            case .containers:
                DockerManager.shared.purgeMemory()
                self.activeStudioManagerNames.remove("DockerManager")
            case .api:
                APIManager.shared.purgeMemory()
                self.activeStudioManagerNames.remove("APIManager")
            case .converter:
                ConverterManager.shared.purgeMemory()
                self.activeStudioManagerNames.remove("ConverterManager")
            default:
                break
            }
        }
    }

    func reset() {
        activeWorkspace = nil
        activeStudioManagerNames.removeAll()
    }
}
