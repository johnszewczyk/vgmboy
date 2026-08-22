import Testing
@testable import VGMBoyEndpointCore

@Suite("VGMBoy endpoint surface")
struct VGMBoyEndpointTests {
    @Test("v1 advertises the shared playback and audio routes")
    func v1SurfaceIsStable() {
        #expect(VGMBoyEndpointSurface.v1.version == 1)
        #expect(VGMBoyEndpointSurface.v1.supports(.playback, .load))
        #expect(VGMBoyEndpointSurface.v1.supports(.playback, .setPlaybackMode))
        #expect(VGMBoyEndpointSurface.v1.supports(.audio, .setEqualizer))
        #expect(VGMBoyEndpointSurface.v1.supports(.audio, .setOutputVolume))
        #expect(VGMBoyEndpointSurface.v1.supports(.diagnostics, .subscribe))
        #expect(VGMBoyEndpointSurface.v1.supports(.export, .exportAAC))
    }
}
