import Foundation
import FrontendPreferencesCore
import Testing

@Test func animationTimingsDefaultToTwoHundredMilliseconds() {
    let timings = FrontendAnimationTimings()
    #expect(timings.autoResizeEnabled)
    #expect(timings.selectionEnabled)
    #expect(timings.autoResizeMilliseconds == 200)
    #expect(timings.selectionMilliseconds == 200)
}

@Test func animationTimingEnableFlagsSurviveLegacyDecoding() throws {
    let data = #"{"autoResizeMilliseconds":450,"selectionMilliseconds":90}"#.data(using: .utf8)!
    let timings = try JSONDecoder().decode(FrontendAnimationTimings.self, from: data)
    #expect(timings.autoResizeEnabled)
    #expect(timings.selectionEnabled)
    #expect(timings.autoResizeMilliseconds == 450)
    #expect(timings.selectionMilliseconds == 90)
}

@Test func columnAutoSizeDefaultsOnAndSurvivesLegacyInterfaceDecoding() throws {
    let data = #"{"animations":{},"windows":{"mainAlwaysOnTop":false,"settingsAlwaysOnTop":false}}"#.data(using: .utf8)!
    let preferences = try JSONDecoder().decode(FrontendInterfacePreferences.self, from: data)
    #expect(preferences.columnAutoSize)
}

@Test func sharedPreferenceStoreRoundTripsTheUnifiedInterfaceState() {
    let suiteName = "FrontendPreferencesCoreTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let keys = FrontendPreferencesKeySet(
        autoResizeEnabledKey: "auto",
        selectionEnabledKey: "selection",
        autoResizeMillisecondsKey: "auto-ms",
        selectionMillisecondsKey: "selection-ms",
        columnAutoSizeKey: "columns",
        mainWindowAlwaysOnTopKey: "main-top",
        settingsWindowAlwaysOnTopKey: "settings-top"
    )
    let store = FrontendPreferencesStore(defaults: defaults, keys: keys)
    let value = FrontendInterfacePreferences(
        animations: .init(autoResizeEnabled: false, selectionEnabled: true, autoResizeMilliseconds: 0, selectionMilliseconds: 850),
        windows: .init(mainAlwaysOnTop: true, settingsAlwaysOnTop: false),
        columnAutoSize: false
    )
    store.save(value)
    #expect(store.load() == value)
}

@Test func optionsManifestKeepsTheSharedAppOrganization() {
    #expect(FrontendOptionsManifest.v1.appSections == [.database, .interface, .windows])
    #expect(FrontendOptionsManifest.v1.animationRange == 0...1_000)
}

@Test func animationTimingsClampUnsafeValues() {
    let timings = FrontendAnimationTimings(autoResizeMilliseconds: -1, selectionMilliseconds: 2_000)
    #expect(timings.autoResizeMilliseconds == 0)
    #expect(timings.selectionMilliseconds == 1_000)
}

@Test func playlistColumnSizingUsesSharedEightPointPadding() throws {
    let sizing = FrontendPlaylistColumnSizing()
    #expect(sizing.horizontalPaddingPerSide == 8)
    #expect(sizing.horizontalPadding == 16)

    let decoded = try JSONDecoder().decode(
        FrontendPlaylistColumnSizing.self,
        from: #"{"horizontalPaddingPerSide":99}"#.data(using: .utf8)!
    )
    #expect(decoded.horizontalPaddingPerSide == 16)
}

@Test func playlistColumnSchemaRepairsStaleOrderAndKeepsFixedColumnsInPlace() {
    let schema = FrontendPlaylistColumnSchema(columns: [
        .init(id: "favorite", isReorderable: false, isSortable: false),
        .init(id: "index", isSortable: false),
        .init(id: "file"),
        .init(id: "title")
    ])

    let layout = schema.normalizedLayout(
        order: ["title", "unknown", "file", "title", "favorite"],
        visibility: nil
    )

    #expect(layout.order == ["favorite", "title", "file", "index"])
    #expect(layout.visibility == ["favorite": true, "index": true, "file": true, "title": true])
}

@Test func playlistColumnSchemaRetainsOneVisibleColumn() {
    let schema = FrontendPlaylistColumnSchema(columns: [
        .init(id: "favorite", isReorderable: false, isSortable: false),
        .init(id: "file"),
        .init(id: "title", isVisibleByDefault: false)
    ])

    let layout = schema.normalizedLayout(
        order: nil,
        visibility: ["favorite": false, "file": false, "title": false, "unknown": true]
    )

    #expect(layout.order == ["favorite", "file", "title"])
    #expect(layout.visibility == ["favorite": true, "file": false, "title": false])
}

@Test func playlistColumnSchemaRequiresAnExplicitValidSort() {
    let schema = FrontendPlaylistColumnSchema(columns: [
        .init(id: "favorite", isReorderable: false, isSortable: false),
        .init(id: "file"),
        .init(id: "title")
    ])

    #expect(schema.normalizedSort(isEnabled: nil, columnID: "title", direction: .descending) == .init(
        isEnabled: false,
        columnID: nil,
        direction: .descending
    ))
    #expect(schema.normalizedSort(isEnabled: true, columnID: "favorite", direction: nil) == .init(
        isEnabled: false,
        columnID: nil,
        direction: .ascending
    ))
    #expect(schema.normalizedSort(isEnabled: true, columnID: "title", direction: .descending) == .init(
        isEnabled: true,
        columnID: "title",
        direction: .descending
    ))
}
