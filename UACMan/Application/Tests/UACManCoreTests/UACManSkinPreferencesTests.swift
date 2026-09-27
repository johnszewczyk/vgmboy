import Foundation
import Testing
@testable import UACManCore

@Test func skinColorInputAcceptsShortAndFullNakedHex() {
    #expect(UACManSkinPreferences.normalizedColorInput("abc") == "#AABBCC")
    #expect(UACManSkinPreferences.normalizedColorInput("#1aF") == "#11AAFF")
    #expect(UACManSkinPreferences.normalizedColorInput("12abEF") == "#12ABEF")
    #expect(UACManSkinPreferences.normalizedColorInput("#12abef") == "#12ABEF")
}

@Test func skinColorInputAcceptsSpaceSeparatedAndWrappedRGB() {
    #expect(UACManSkinPreferences.normalizedColorInput("255 128 0") == "#FF8000")
    #expect(UACManSkinPreferences.normalizedColorInput("0, 12, 255") == "#000CFF")
    #expect(UACManSkinPreferences.normalizedColorInput("rgb(4 5 6)") == "#040506")
    #expect(UACManSkinPreferences.normalizedColorInput("256 0 0") == nil)
}

@Test func skinColorInputAcceptsCSSNamedColorsAndRejectsUnknownNames() {
    #expect(UACManSkinPreferences.normalizedColorInput("RebeccaPurple") == "rebeccapurple")
    #expect(UACManSkinPreferences.normalizedColorInput("darkslategrey") == "darkslategrey")
    #expect(UACManSkinPreferences.normalizedColorInput("transparent") == "transparent")
    #expect(UACManSkinPreferences.normalizedColorInput("not-a-color") == nil)
}

@Test func skinDefaultsMatchBothWorkspacePalettes() {
    let defaults = UACManSkinPreferences()
    #expect(defaults.appearanceMode == .system)
    #expect(defaults.lightColors == UACManSkinPreferences.defaultLightColors)
    #expect(defaults.darkColors == UACManSkinPreferences.defaultDarkColors)
    #expect(defaults.lightColors["table-title-bg"] == "#f7f8fa")
    #expect(defaults.darkColors["table-title-bg"] == "#292e35")
    #expect(defaults.interfaceFontSize == 13)
    #expect(defaults.tableFontSize == 10)
}

@Test func skinAppearanceModeSelectsTheActivePalette() {
    #expect(UACManSkinPreferences(appearanceMode: .system).usesDarkPalette(systemIsDark: true))
    #expect(!UACManSkinPreferences(appearanceMode: .system).usesDarkPalette(systemIsDark: false))
    #expect(UACManSkinPreferences(appearanceMode: .dark).usesDarkPalette(systemIsDark: false))
    #expect(!UACManSkinPreferences(appearanceMode: .light).usesDarkPalette(systemIsDark: true))
}

@Test func skinPreferencesDecodeBeforeAppearanceModeAndTitleColorWereAdded() throws {
    let json = Data(#"{"lightColors":{"accent":"red"},"darkColors":{"accent":"blue"},"interfaceFontSize":14,"tableFontSize":11,"tableSurfaceRadius":5,"tableCellRadius":1}"#.utf8)
    let restored = try JSONDecoder().decode(UACManSkinPreferences.self, from: json)

    #expect(restored.appearanceMode == .system)
    #expect(restored.lightColors["accent"] == "red")
    #expect(restored.darkColors["accent"] == "blue")
    #expect(restored.lightColors["table-title-bg"] == "#f7f8fa")
    #expect(restored.darkColors["table-title-bg"] == "#292e35")
    #expect(restored.interfaceFontSize == 14)
}
