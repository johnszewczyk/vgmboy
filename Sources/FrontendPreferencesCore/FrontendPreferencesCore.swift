import Foundation

/// Shared interaction timings for the native and WebKit frontends.
public struct FrontendAnimationTimings: Codable, Equatable, Sendable {
    public static let defaultDurationMilliseconds = 200
    public static let allowedMilliseconds = 0...1_000

    public var autoResizeMilliseconds: Int
    public var selectionMilliseconds: Int

    public init(
        autoResizeMilliseconds: Int = Self.defaultDurationMilliseconds,
        selectionMilliseconds: Int = Self.defaultDurationMilliseconds
    ) {
        self.autoResizeMilliseconds = Self.clamp(autoResizeMilliseconds)
        self.selectionMilliseconds = Self.clamp(selectionMilliseconds)
    }

    public static func clamp(_ value: Int) -> Int {
        min(max(value, allowedMilliseconds.lowerBound), allowedMilliseconds.upperBound)
    }
}

public enum FrontendAppOptionSection: String, CaseIterable, Codable, Sendable {
    case database
    case interface
    case windows
    public var title: String { rawValue.capitalized }
}

public enum FrontendWindowRole: String, CaseIterable, Codable, Sendable {
    case main
    case settings
    case about
}

public struct FrontendWindowPreferences: Codable, Equatable, Sendable {
    public var mainAlwaysOnTop: Bool
    public var settingsAlwaysOnTop: Bool

    public init(mainAlwaysOnTop: Bool = false, settingsAlwaysOnTop: Bool = false) {
        self.mainAlwaysOnTop = mainAlwaysOnTop
        self.settingsAlwaysOnTop = settingsAlwaysOnTop
    }
}

public struct FrontendInterfacePreferences: Codable, Equatable, Sendable {
    public var animations: FrontendAnimationTimings
    public var windows: FrontendWindowPreferences

    public init(animations: FrontendAnimationTimings = .init(), windows: FrontendWindowPreferences = .init()) {
        self.animations = animations
        self.windows = windows
    }
}

public struct FrontendOptionsManifest: Codable, Equatable, Sendable {
    public let version: Int
    public let appSections: [FrontendAppOptionSection]
    public let animationRange: ClosedRange<Int>
    public let defaultAnimationMilliseconds: Int

    public init(version: Int = 1, appSections: [FrontendAppOptionSection] = FrontendAppOptionSection.allCases) {
        self.version = version
        self.appSections = appSections
        self.animationRange = FrontendAnimationTimings.allowedMilliseconds
        self.defaultAnimationMilliseconds = FrontendAnimationTimings.defaultDurationMilliseconds
    }

    public static let v1 = FrontendOptionsManifest()
}
