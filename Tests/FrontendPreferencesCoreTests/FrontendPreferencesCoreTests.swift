import FrontendPreferencesCore
import Testing

@Test func animationTimingsDefaultToTwoHundredMilliseconds() {
    let timings = FrontendAnimationTimings()
    #expect(timings.autoResizeMilliseconds == 200)
    #expect(timings.selectionMilliseconds == 200)
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
