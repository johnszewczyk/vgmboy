import Foundation
import Testing
@testable import MetaManCore

@Test("Standard audio is registered for the file types already routed by ScanSong")
func standardAudioFormatsMatchScannerRoutes() throws {
    let descriptor = try #require(
        MetaManCore.supportedFormats.first { $0.identifier == "standard-audio" }
    )
    #expect(Set(descriptor.fileExtensions) == StandardAudioMetadataReader.supportedExtensions)
    #expect(descriptor.fileExtensions.sorted() == ["aif", "aiff", "flac", "m4a", "mp3", "ogg", "wav"])
}

@Test("File-URL standard audio reader preserves decoded frame duration")
func standardAudioFileURLReaderReportsDurationAndOneTrack() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("metaman-standard-audio-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appendingPathComponent("one-second.WAV")
    try makePCM16Wave(sampleRate: 44_100, frameCount: 44_100).write(to: fileURL)

    let document = try MetaManCore.read(fileURL: fileURL)
    #expect(document.format == "standard-audio")
    #expect(document.fields.system == "Standard audio")
    #expect(document.timing?.introLengthMs == 0)
    #expect(document.timing?.loopLengthMs == 0)
    #expect(document.timing?.playLengthMs == 1_000)
    #expect(document.timing?.fadeLengthMs == 0)
    #expect(document.technicalFacts["durationSource"] == "AVAudioFile decoded frame count")
    #expect(document.technicalFacts["decodedFrames"] == "44100")

    let result = try MetaManCore.readResult(fileURL: fileURL)
    #expect(result.tracks.count == 1)
    #expect(result.tracks[0].sourceTrackIndex == nil)
    #expect(result.tracks[0].document == document)
}

@Test("FLAC Vorbis comments retain order, duplicate keys, unknown values, and spacing")
func standardAudioFLACCommentParserRetainsEveryComment() throws {
    let sourceComments = [
        "TITLE=First title",
        "ARTIST=Earlier artist",
        "artist= Final artist ",
        "X-CUSTOM=keep=this=too",
        "COMMENT="
    ]
    let block = makeVorbisCommentBlock(vendor: "MetaMan test", comments: sourceComments)

    let tags = try #require(StandardAudioMetadataReader.parseVorbisCommentBlock(block))
    #expect(tags.map(\.name) == ["TITLE", "ARTIST", "artist", "X-CUSTOM", "COMMENT"])
    #expect(tags.map(\.value) == [
        "First title",
        "Earlier artist",
        " Final artist ",
        "keep=this=too",
        ""
    ])
    #expect(tags[1].normalizedName == tags[2].normalizedName)
}

@Test("Malformed Vorbis comment lengths are rejected without out-of-bounds reads")
func standardAudioFLACCommentParserRejectsTruncation() {
    var block = Data()
    appendUInt32LE(1, to: &block)
    block.append(0x41)
    appendUInt32LE(1, to: &block)
    appendUInt32LE(20, to: &block)
    block.append(contentsOf: [0x54, 0x49, 0x54, 0x4C, 0x45])

    #expect(StandardAudioMetadataReader.parseVorbisCommentBlock(block) == nil)
}

private func makePCM16Wave(sampleRate: UInt32, frameCount: UInt32) -> Data {
    let channels: UInt16 = 1
    let bitsPerSample: UInt16 = 16
    let bytesPerFrame = UInt32(channels) * UInt32(bitsPerSample / 8)
    let audioBytes = frameCount * bytesPerFrame

    var data = Data("RIFF".utf8)
    appendUInt32LE(36 + audioBytes, to: &data)
    data.append(contentsOf: Data("WAVEfmt ".utf8))
    appendUInt32LE(16, to: &data)
    appendUInt16LE(1, to: &data)
    appendUInt16LE(channels, to: &data)
    appendUInt32LE(sampleRate, to: &data)
    appendUInt32LE(sampleRate * bytesPerFrame, to: &data)
    appendUInt16LE(UInt16(bytesPerFrame), to: &data)
    appendUInt16LE(bitsPerSample, to: &data)
    data.append(contentsOf: Data("data".utf8))
    appendUInt32LE(audioBytes, to: &data)
    data.append(Data(repeating: 0, count: Int(audioBytes)))
    return data
}

private func makeVorbisCommentBlock(vendor: String, comments: [String]) -> Data {
    var block = Data()
    let vendorBytes = Data(vendor.utf8)
    appendUInt32LE(UInt32(vendorBytes.count), to: &block)
    block.append(vendorBytes)
    appendUInt32LE(UInt32(comments.count), to: &block)
    for comment in comments {
        let commentBytes = Data(comment.utf8)
        appendUInt32LE(UInt32(commentBytes.count), to: &block)
        block.append(commentBytes)
    }
    return block
}

private func appendUInt16LE(_ value: UInt16, to data: inout Data) {
    data.append(UInt8(truncatingIfNeeded: value))
    data.append(UInt8(truncatingIfNeeded: value >> 8))
}

private func appendUInt32LE(_ value: UInt32, to data: inout Data) {
    for shift in stride(from: 0, through: 24, by: 8) {
        data.append(UInt8(truncatingIfNeeded: value >> shift))
    }
}
