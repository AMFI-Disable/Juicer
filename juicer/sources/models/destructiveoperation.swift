import Foundation

struct DestructiveOperationIdentity: Codable, Equatable, Sendable {
    let id: UUID
    let title: String

    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }
}

enum DestructiveTargetKind: String, Codable, CaseIterable, Sendable {
    case cache
    case orphanedPackage
    case log
    case temporaryFile
    case other
}

struct DestructiveOperationPreviewItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let displayName: String
    let path: String
    let kind: DestructiveTargetKind
    let byteCount: Int64?
    var isSelected: Bool

    init(
        id: UUID = UUID(),
        displayName: String,
        path: String,
        kind: DestructiveTargetKind,
        byteCount: Int64? = nil,
        isSelected: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.path = path
        self.kind = kind
        self.byteCount = byteCount
        self.isSelected = isSelected
    }
}

struct DestructiveOperationImpact: Codable, Equatable, Sendable {
    let itemCount: Int
    let knownByteCount: Int64
    let unknownByteCountItems: Int

    var hasCompleteByteEstimate: Bool { unknownByteCountItems == 0 }

    static func aggregate(_ items: [DestructiveOperationPreviewItem]) -> Self {
        let selected = items.filter(\.isSelected)
        return Self(
            itemCount: selected.count,
            knownByteCount: selected.compactMap(\.byteCount).reduce(0) { $0 + max(0, $1) },
            unknownByteCountItems: selected.filter { $0.byteCount == nil }.count
        )
    }
}

enum DestructiveConfirmationState: String, Codable, Sendable {
    case notRequested
    case awaitingExplicitConfirmation
    case confirmed
    case declined
}

enum DestructiveOperationState: String, Codable, Sendable {
    case preview
    case awaitingConfirmation
    case ready
    case running
    case succeeded
    case partiallyFailed
    case failed
    case cancelled

    var isTerminal: Bool {
        switch self {
        case .succeeded, .partiallyFailed, .failed, .cancelled: return true
        default: return false
        }
    }
}

struct DestructiveOperationFailure: Codable, Equatable, Sendable {
    let targetID: UUID?
    let targetDisplayName: String
    let message: String
}

struct DestructiveOperationRecovery: Codable, Equatable, Sendable {
    let summary: String
    let recoveryPath: String?
}

struct DestructiveOperationProgress: Codable, Equatable, Sendable {
    let completedItems: Int
    let totalItems: Int
}

struct DestructiveOperationManifest: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let identity: DestructiveOperationIdentity
    let createdAt: Date
    var updatedAt: Date
    let previewItems: [DestructiveOperationPreviewItem]
    let selectedTargetIDs: [UUID]
    let impact: DestructiveOperationImpact
    var confirmationState: DestructiveConfirmationState
    var state: DestructiveOperationState
    var progress: DestructiveOperationProgress
    var failures: [DestructiveOperationFailure]
    var recovery: DestructiveOperationRecovery?
    var cancellationReason: String?

    var selectedItems: [DestructiveOperationPreviewItem] {
        let selected = Set(selectedTargetIDs)
        return previewItems.filter { selected.contains($0.id) }
    }
}

enum DestructiveOperationFlowError: Error, Equatable, LocalizedError {
    case noSelectedTargets
    case invalidTransition(from: DestructiveOperationState, to: DestructiveOperationState)
    case confirmationPhraseMismatch
    case invalidProgress
    case failureDetailsRequired

    var errorDescription: String? {
        switch self {
        case .noSelectedTargets: return "At least one target must be selected."
        case let .invalidTransition(from, to): return "Cannot transition from \(from.rawValue) to \(to.rawValue)."
        case .confirmationPhraseMismatch: return "The confirmation text did not match the operation impact."
        case .invalidProgress: return "Progress must be within the selected target count and cannot move backwards."
        case .failureDetailsRequired: return "A failed result must include failure details."
        }
    }
}

struct DestructiveOperationFlow: Sendable {
    private(set) var manifest: DestructiveOperationManifest

    init(identity: DestructiveOperationIdentity, items: [DestructiveOperationPreviewItem], now: Date = Date()) throws {
        let selectedIDs = items.filter(\.isSelected).map(\.id)
        guard !selectedIDs.isEmpty else { throw DestructiveOperationFlowError.noSelectedTargets }
        let impact = DestructiveOperationImpact.aggregate(items)
        manifest = DestructiveOperationManifest(
            id: identity.id,
            identity: identity,
            createdAt: now,
            updatedAt: now,
            previewItems: items,
            selectedTargetIDs: selectedIDs,
            impact: impact,
            confirmationState: .notRequested,
            state: .preview,
            progress: .init(completedItems: 0, totalItems: impact.itemCount),
            failures: [],
            recovery: nil,
            cancellationReason: nil
        )
    }

    var requiredConfirmationText: String {
        "Confirm \(manifest.identity.title): \(manifest.impact.itemCount) items, \(manifest.impact.knownByteCount) bytes"
    }

    mutating func requestConfirmation(now: Date = Date()) throws {
        try requireTransition(from: .preview, to: .awaitingConfirmation)
        manifest.confirmationState = .awaitingExplicitConfirmation
        update(state: .awaitingConfirmation, now: now)
    }

    mutating func confirm(phrase: String, now: Date = Date()) throws {
        try requireTransition(from: .awaitingConfirmation, to: .ready)
        guard phrase == requiredConfirmationText else {
            throw DestructiveOperationFlowError.confirmationPhraseMismatch
        }
        manifest.confirmationState = .confirmed
        update(state: .ready, now: now)
    }

    mutating func decline(now: Date = Date()) throws {
        try requireTransition(from: .awaitingConfirmation, to: .cancelled)
        manifest.confirmationState = .declined
        manifest.cancellationReason = "Confirmation declined."
        update(state: .cancelled, now: now)
    }

    mutating func start(now: Date = Date()) throws {
        try requireTransition(from: .ready, to: .running)
        update(state: .running, now: now)
    }

    mutating func recordProgress(completedItems: Int, now: Date = Date()) throws {
        guard manifest.state == .running else {
            throw DestructiveOperationFlowError.invalidTransition(from: manifest.state, to: .running)
        }
        guard completedItems >= manifest.progress.completedItems,
              completedItems <= manifest.progress.totalItems else {
            throw DestructiveOperationFlowError.invalidProgress
        }
        manifest.progress = .init(completedItems: completedItems, totalItems: manifest.progress.totalItems)
        manifest.updatedAt = now
    }

    mutating func finish(
        failures: [DestructiveOperationFailure] = [],
        recovery: DestructiveOperationRecovery? = nil,
        now: Date = Date()
    ) throws {
        guard manifest.state == .running else {
            throw DestructiveOperationFlowError.invalidTransition(from: manifest.state, to: .succeeded)
        }
        let completed = manifest.progress.completedItems
        let total = manifest.progress.totalItems
        if completed < total && failures.isEmpty {
            throw DestructiveOperationFlowError.failureDetailsRequired
        }
        manifest.failures = failures
        manifest.recovery = recovery
        let result: DestructiveOperationState
        if failures.isEmpty && completed == total {
            result = .succeeded
        } else if completed == 0 {
            result = .failed
        } else {
            result = .partiallyFailed
        }
        update(state: result, now: now)
    }

    mutating func cancel(reason: String? = nil, recovery: DestructiveOperationRecovery? = nil, now: Date = Date()) throws {
        guard !manifest.state.isTerminal else {
            throw DestructiveOperationFlowError.invalidTransition(from: manifest.state, to: .cancelled)
        }
        manifest.cancellationReason = reason
        manifest.recovery = recovery
        update(state: .cancelled, now: now)
    }

    private func requireTransition(from: DestructiveOperationState, to: DestructiveOperationState) throws {
        guard manifest.state == from else {
            throw DestructiveOperationFlowError.invalidTransition(from: manifest.state, to: to)
        }
    }

    private mutating func update(state: DestructiveOperationState, now: Date) {
        manifest.state = state
        manifest.updatedAt = now
    }
}

enum DestructivePathValidationError: Error, Equatable, LocalizedError {
    case emptyPath
    case pathMustBeAbsolute(String)
    case unsafeProtectedPath(String)
    case outsideAllowedScope(String)

    var errorDescription: String? {
        switch self {
        case .emptyPath: return "The target path is empty."
        case let .pathMustBeAbsolute(path): return "The target path must be absolute: \(path)"
        case let .unsafeProtectedPath(path): return "The target path is protected: \(path)"
        case let .outsideAllowedScope(path): return "The target path is outside the authorized scope: \(path)"
        }
    }
}

struct DestructivePathValidator: Sendable {
    let homeDirectory: URL
    let workspaceRoot: URL?
    let allowedRoots: [URL]
    let explicitlyAuthorizedPaths: Set<String>

    init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        workspaceRoot: URL? = nil,
        allowedRoots: [URL] = [],
        explicitlyAuthorizedPaths: Set<String> = []
    ) {
        self.homeDirectory = homeDirectory
        self.workspaceRoot = workspaceRoot
        self.allowedRoots = allowedRoots
        self.explicitlyAuthorizedPaths = Set(explicitlyAuthorizedPaths.map(Self.canonicalPath))
    }

    func validate(_ path: String) throws -> URL {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DestructivePathValidationError.emptyPath }
        guard (trimmed as NSString).isAbsolutePath else {
            throw DestructivePathValidationError.pathMustBeAbsolute(trimmed)
        }

        let canonical = Self.canonicalPath(trimmed)
        if !explicitlyAuthorizedPaths.contains(canonical) {
            let protected = ["/", Self.canonicalPath(homeDirectory.path), workspaceRoot.map { Self.canonicalPath($0.path) }]
                .compactMap { $0 }
            guard !protected.contains(canonical) else {
                throw DestructivePathValidationError.unsafeProtectedPath(canonical)
            }
        }

        if !allowedRoots.isEmpty && !explicitlyAuthorizedPaths.contains(canonical) {
            let isAllowed = allowedRoots.map { Self.canonicalPath($0.path) }.contains {
                canonical == $0 || canonical.hasPrefix($0 + "/")
            }
            guard isAllowed else { throw DestructivePathValidationError.outsideAllowedScope(canonical) }
        }
        return URL(fileURLWithPath: canonical)
    }

    private static func canonicalPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
    }
}
