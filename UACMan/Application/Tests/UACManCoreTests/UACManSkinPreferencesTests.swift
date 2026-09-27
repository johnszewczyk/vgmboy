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
    #expect(defaults.lightColors == UACManSkinPreferences.defaultLightColors)
    #expect(defaults.darkColors == UACManSkinPreferences.defaultDarkColors)
    #expect(defaults.interfaceFontSize == 13)
    #expect(defaults.tableFontSize == 10)
}
