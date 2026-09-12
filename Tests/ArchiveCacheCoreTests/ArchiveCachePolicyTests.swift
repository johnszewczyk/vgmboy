import ArchiveCacheCore
import Foundation
import Testing

@Test
func policyPersistsModeAndSnapsLimitToSupportedValues() {
    let suiteName = "ArchiveCacheCoreTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let keys = ArchiveCachePreferenceKeys(modeKey: "mode", limitKey: "limit")
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let policy = ArchiveCachePolicy(mode: .disabled, maximumBytes: 8 * 1_024 * 1_024 * 1_024)
    policy.save(defaults: defaults, keys: keys)
    let loaded = ArchiveCachePolicy.load(defaults: defaults, keys: keys)

    #expect(loaded == policy)
    #expect(loaded.activeLimitBytes == ArchiveCachePolicy.disposableLimitBytes)
}

@Test
func policyUsesTheNearestSupportedLimit() {
    let suiteName = "ArchiveCacheCoreTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    let keys = ArchiveCachePreferenceKeys(modeKey: "mode", limitKey: "limit")
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(Int(6 * 1_024 * 1_024 * 1_024), forKey: keys.limitKey)

    let loaded = ArchiveCachePolicy.load(defaults: defaults, keys: keys)

    #expect(loaded.maximumBytes == 4 * 1_024 * 1_024 * 1_024)
}
