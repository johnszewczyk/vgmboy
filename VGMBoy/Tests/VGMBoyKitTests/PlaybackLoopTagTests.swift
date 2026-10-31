import Foundation
import Testing
@testable import VGMBoyKit

private func taggedFLAC(_ comments: [String]) -> Data {
    var body = Data()
    func append32(_ value: UInt32) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { body.append(contentsOf: $0) }
    }
    append32(0)
    append32(UInt32(comments.count))
    for comment in comments {
        let bytes = Array(comment.utf8)
        append32(UInt32(bytes.count))
        body.append(contentsOf: bytes)
    }
    let length = body.count
    var file = Data("fLaC".utf8)
    file.append(contentsOf: [0x84, UInt8((length >> 16) & 0xff), UInt8((length >> 8) & 0xff), UInt8(length & 0xff)])
    file.append(body)
    return file
}

@Test func loopTagReaderOnlyOpensSupportedTagFormats() throws {
    var loads = 0
    let data = taggedFLAC(["LOOP_START=100", "LOOP_LENGTH=200", "LOOP_SAMPLE_RATE=44100"])
    let loader: (URL) -> Data? = { _ in loads += 1; return data }
    #expect(PlaybackLoopTagReader.read(path: "/music/example.spc", loadData: loader) == nil)
    #expect(PlaybackLoopTagReader.read(path: "/music/example.wav", loadData: loader) == nil)
    #expect(loads == 0)
    let loop = try #require(PlaybackLoopTagReader.read(path: "/music/example.FLAC", loadData: loader))
    #expect(loads == 1)
    #expect(loop.startSample == 100)
    #expect(loop.endSample == 300)
    #expect(loop.sampleRateHz == 44_100)
    #expect(PlaybackLoopTagReader.read(path: "/music/example.ape", loadData: loader) == nil)
    #expect(loads == 2)
}

@Test func overflowingLoopLengthIsRejected() {
    let data = taggedFLAC(["LOOP_START=9223372036854775800", "LOOP_LENGTH=100"])
    #expect(PlaybackLoopTagReader.read(data: data, extensionName: "flac") == nil)
}

@Test func decodedLoopValuesRejectNegativeFieldsAndSaturateLength() throws {
    let extreme = Data("""
        {"startSample":-9223372036854775808,"endSample":9223372036854775807,
         "sampleRateHz":44100,"mode":"forward","repeatCount":1}
        """.utf8)
    let value = try JSONDecoder().decode(PlaybackLoopMetadata.self, from: extreme)
    #expect(!value.isValid)
    #expect(value.lengthSamples == Int64.max)
    let negativeRepeats = PlaybackLoopMetadata(startSample: 0, endSample: 1, sampleRateHz: 44_100, repeatCount: -1)
    #expect(!negativeRepeats.isValid)
}
