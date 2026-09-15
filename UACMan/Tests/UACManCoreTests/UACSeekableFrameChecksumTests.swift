import Foundation
import Testing
@testable import UACManCore

@Test func seekTableChecksumMatchesXXH64LowWordVectors() {
    #expect(UACSeekableFrameChecksum.value(for: Data()) == 0x51D8E999)
    #expect(UACSeekableFrameChecksum.value(for: Data("a".utf8)) == 0xA98C6E5B)
    #expect(!UACSeekableFrameChecksum.matches(Data("a".utf8), checksum: 0))
}
