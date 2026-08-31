import ArchiveCacheCore
import Testing

@Test
func playbackLeaseReplacesAndClearsTheProtectedPath() {
    let lease = ArchivePlaybackLease()

    #expect(lease.path == nil)
    lease.replace(with: "/tmp/first-cache-root")
    #expect(lease.path == "/tmp/first-cache-root")
    lease.replace(with: "/tmp/second-cache-root")
    #expect(lease.path == "/tmp/second-cache-root")
    lease.clear()
    #expect(lease.path == nil)
}
