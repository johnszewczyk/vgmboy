import Foundation
import Testing
import UACWrapperCore

@Test func seekTableChecksumMatchesXXH64LowWordVectors() {
    #expect(UACWrapperCore.UACSeekableFrameChecksum.value(for: Data()) == 0x51D8E999)
    #expect(UACWrapperCore.UACSeekableFrameChecksum.value(for: Data("a".utf8)) == 0xA98C6E5B)
    #expect(!UACWrapperCore.UACSeekableFrameChecksum.matches(Data("a".utf8), checksum: 0))
}
