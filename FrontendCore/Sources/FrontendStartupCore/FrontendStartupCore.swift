import Foundation

public enum FrontendStartupStage: Int, CaseIterable, Codable, Equatable, Sendable {
    case restoreWorkspace
    case connectLibrary
    case prepareSidebar
    case restorePlaylists

    public var id: String {
        switch self {
        case .restoreWorkspace: "restoreWorkspace"
        case .connectLibrary: "connectLibrary"
        case .prepareSidebar: "prepareSidebar"
        case .restorePlaylists: "restorePlaylists"
        }
    }

    public var label: String {
        switch self {
        case .restoreWorkspace: "Restore workspace"
        case .connectLibrary: "Connect library"
        case .prepareSidebar: "Prepare sidebar"
        case .restorePlaylists: "Restore playlists"
        }
    }

    public var heading: String {
        switch self {
        case .restoreWorkspace: "Restoring your workspace"
        case .connectLibrary: "Connecting to the library"
        case .prepareSidebar: "Preparing the sidebar"
        case .restorePlaylists: "Restoring playlists"
        }
    }

    public var detail: String {
        switch self {
        case .restoreWorkspace: "Applying saved interface settings and reopening your last session."
        case .connectLibrary: "Opening the shared ScanSong catalog read-only."
        case .prepareSidebar: "Preparing the library browser and its search results."
        case .restorePlaylists: "Reopening saved playlists and preparing playback controls."
        }
    }

    public var manifest: [String: String] {
        ["id": id, "label": label, "heading": heading, "detail": detail]
    }
}

public enum FrontendStartupPhase: String, Codable, Equatable, Sendable {
    case idle
    case starting
    case ready
    case failed
}

public enum FrontendStartupStepState: String, Codable, Equatable, Sendable {
    case pending
    case active
    case complete
    case failed
}

/// UI-neutral startup progress shared by the native and WebKit frontends.
public struct FrontendStartupProgress: Equatable, Sendable {
    public private(set) var phase: FrontendStartupPhase = .idle
    public private(set) var currentStage: FrontendStartupStage = .restoreWorkspace
    public private(set) var currentDetail = FrontendStartupStage.restoreWorkspace.detail
    public private(set) var failureMessage: String?
    private var startedAt: Date?

    public init() {}

    public mutating func begin(at date: Date = .now) {
        phase = .starting
        currentStage = .restoreWorkspace
        currentDetail = currentStage.detail
        failureMessage = nil
        startedAt = date
    }

    public mutating func advance(to stage: FrontendStartupStage, detail: String? = nil) {
        guard phase == .starting, stage.rawValue >= currentStage.rawValue else { return }
        currentStage = stage
        currentDetail = detail?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? stage.detail
    }

    public mutating func finish() {
        guard phase == .starting else { return }
        phase = .ready
        failureMessage = nil
    }

    public mutating func fail(_ message: String) {
        guard phase == .starting else { return }
        phase = .failed
        failureMessage = message.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? "The application could not finish starting."
    }

    public func state(for stage: FrontendStartupStage) -> FrontendStartupStepState {
        switch phase {
        case .idle:
            return .pending
        case .starting:
            if stage.rawValue < currentStage.rawValue { return .complete }
            return stage == currentStage ? .active : .pending
        case .ready:
            return .complete
        case .failed:
            if stage.rawValue < currentStage.rawValue { return .complete }
            return stage == currentStage ? .failed : .pending
        }
    }

    public func elapsedSeconds(at date: Date = .now) -> Int {
        guard let startedAt else { return 0 }
        return max(0, Int(date.timeIntervalSince(startedAt)))
    }
}

public enum FrontendStartupTiming {
    public static let revealDelayMilliseconds = 350
    public static let readyConfirmationMilliseconds = 650
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
