import Foundation

public enum ArchiveCacheMode: String, CaseIterable, Sendable {
    case enabled
    case disabled
}

/// Persistent limits for archive playback materialization. Scan scratch is
/// intentionally outside this policy: it is disposable work owned by a scan.
public struct ArchiveCachePolicy: Sendable, Equatable {
    public static let supportedLimits: [Int64] = [2, 4, 8, 16].map { Int64($0) * 1_024 * 1_024 * 1_024 }
    public static let defaultLimitBytes: Int64 = 2_048 * 1_024 * 1_024
    public static let disposableLimitBytes: Int64 = 2_048 * 1_024 * 1_024
    public static let requiredFreeBytes: Int64 = 1_024 * 1_024 * 1_024

    public let mode: ArchiveCacheMode
    public let maximumBytes: Int64

    public init(mode: ArchiveCacheMode, maximumBytes: Int64) {
        self.mode = mode
        self.maximumBytes = maximumBytes
    }

    public static func load(
        defaults: UserDefaults = .standard,
        keys: ArchiveCachePreferenceKeys
    ) -> ArchiveCachePolicy {
        let mode = ArchiveCacheMode(rawValue: defaults.string(forKey: keys.modeKey) ?? "enabled") ?? .enabled
        let requested = Int64(defaults.object(forKey: keys.limitKey) as? Int ?? Int(defaultLimitBytes))
        let maximumBytes = supportedLimits.min(by: { abs($0 - requested) < abs($1 - requested) }) ?? defaultLimitBytes
        return ArchiveCachePolicy(mode: mode, maximumBytes: maximumBytes)
    }

    public func save(
        defaults: UserDefaults = .standard,
        keys: ArchiveCachePreferenceKeys
    ) {
        defaults.set(mode.rawValue, forKey: keys.modeKey)
        defaults.set(Int(maximumBytes), forKey: keys.limitKey)
    }

    public var isEnabled: Bool { mode == .enabled }
    public var activeLimitBytes: Int64 { isEnabled ? maximumBytes : Self.disposableLimitBytes }

    public static func displayLimit(_ bytes: Int64) -> String {
        let gibibyte: Int64 = 1_024 * 1_024 * 1_024
        return "\(max(1, bytes / gibibyte)) GB"
    }
}

/// Frontend-owned UserDefaults names for the shared cache policy.
public struct ArchiveCachePreferenceKeys: Sendable, Equatable {
    public let modeKey: String
    public let limitKey: String

    public init(modeKey: String, limitKey: String) {
        self.modeKey = modeKey
        self.limitKey = limitKey
    }
}
