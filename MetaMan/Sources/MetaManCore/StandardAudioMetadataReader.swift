import AVFoundation
import Foundation

/// Reads ordinary audio tags and duration through Apple's file-based media
/// APIs. FLAC Vorbis comments are also parsed directly so the complete ordered
/// comment list and its original bytes are available to clients.
public enum StandardAudioMetadataReader {
    public static let supportedExtensions: Set<String> = ["aif", "aiff", "flac", "m4a", "mp3", "ogg", "wav"]

    public static func read(fileURL: URL) throws -> MetadataDocument {
        let fileExtension = fileURL.pathExtension.lowercased()
        guard supportedExtensions.contains(fileExtension) else {
            throw MetadataReadError.unsupportedFormat(fileExtension)
        }

        let (durationMilliseconds, durationFacts) = try duration(for: fileURL)
        let commonMetadata = AVURLAsset(url: fileURL).commonMetadata
        var commonValues: [String: String] = [:]
        var commonTags: [MetadataTag] = []
        for item in commonMetadata {
            guard let key = item.commonKey?.rawValue,
                  let value = item.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { continue }
            commonValues[key] = value
            commonTags.append(MetadataTag(name: item.identifier?.rawValue ?? key, value: value))
        }

        let flacComments = fileExtension == "flac" ? readFLACComments(fileURL: fileURL) : nil
        let flacTags = flacComments?.tags ?? []
        let flacValues = projectedFLACValues(from: flacTags)
        let commentTags = commonTags + flacTags
        let album = flacValues["ALBUM"] ?? commonValues[AVMetadataKey.commonKeyAlbumName.rawValue]
        let artist = flacValues["ARTIST"]
            ?? flacValues["ALBUMARTIST"]
            ?? flacValues["COMPOSER"]
            ?? commonValues[AVMetadataKey.commonKeyArtist.rawValue]
            ?? commonValues[AVMetadataKey.commonKeyAuthor.rawValue]
        let title = flacValues["TITLE"]
            ?? commonValues[AVMetadataKey.commonKeyTitle.rawValue]
        let comment = flacValues["COMMENT"]
            ?? commonValues[AVMetadataKey.commonKeyDescription.rawValue]

        return MetadataDocument(
            format: "standard-audio",
            fields: MetadataFields(
                title: title,
                game: album,
                system: "Standard audio",
                artist: artist,
                album: album,
                date: flacValues["DATE"],
                year: flacValues["YEAR"],
                genre: flacValues["GENRE"],
                comment: comment,
                copyright: flacValues["COPYRIGHT"],
                encodedBy: flacValues["ENCODED_BY"]
            ),
            tags: commentTags,
            rawTagBlock: flacComments?.rawBlock,
            sourceEncoding: flacComments == nil ? nil : "UTF-8",
            timing: MetadataTiming(
                introLengthMs: 0,
                loopLengthMs: 0,
                playLengthMs: durationMilliseconds,
                fadeLengthMs: 0
            ),
            technicalFacts: [
                "fileExtension": fileExtension,
                "durationSource": durationFacts.source,
                "durationMilliseconds": String(durationMilliseconds)
            ].merging(durationFacts.additionalFacts) { _, new in new }
        )
    }

    /// Decodes a FLAC Vorbis-comment block payload (excluding its four-byte
    /// FLAC metadata-block header). Tag order, spelling, and duplicate keys
    /// are preserved; convenience fields use the last nonempty value to
    /// match ScanSong's former dictionary projection.
    static func parseVorbisCommentBlock(_ block: Data) -> [MetadataTag]? {
        var offset = 0
        guard let vendorLength = littleEndianUInt32(block, offset: &offset),
              Int(vendorLength) <= block.count - offset else { return nil }
        offset += Int(vendorLength)
        guard let commentCount = littleEndianUInt32(block, offset: &offset),
              commentCount <= UInt32(block.count / 4) else { return nil }

        var tags: [MetadataTag] = []
        tags.reserveCapacity(Int(commentCount))
        for _ in 0..<commentCount {
            guard let length = littleEndianUInt32(block, offset: &offset),
                  Int(length) <= block.count - offset else { return nil }
            let end = offset + Int(length)
            let comment = String(decoding: block[offset..<end], as: UTF8.self)
            offset = end
            guard let separator = comment.firstIndex(of: "=") else { continue }
            let name = String(comment[..<separator])
            guard !name.isEmpty else { continue }
            let value = String(comment[comment.index(after: separator)...])
            tags.append(MetadataTag(name: name, value: value))
        }
        return tags
    }

    private static func duration(for fileURL: URL) throws -> (Int, DurationFacts) {
        if let file = try? AVAudioFile(forReading: fileURL),
           file.processingFormat.sampleRate > 0,
           file.length >= 0 {
            let milliseconds = max(
                0,
                Int((Double(file.length) / file.processingFormat.sampleRate * 1_000).rounded())
            )
            return (
                milliseconds,
                DurationFacts(
                    source: "AVAudioFile decoded frame count",
                    additionalFacts: [
                        "decodedFrames": String(file.length),
                        "sampleRateHz": String(file.processingFormat.sampleRate)
                    ]
                )
            )
        }

        let seconds = AVURLAsset(url: fileURL).duration.seconds
        guard seconds.isFinite, seconds >= 0 else {
            throw MetadataReadError.malformedFile(
                "Core Audio could not determine the duration of \(fileURL.lastPathComponent)."
            )
        }
        let milliseconds = max(0, Int((seconds * 1_000).rounded()))
        return (
            milliseconds,
            DurationFacts(source: "AVURLAsset duration", additionalFacts: [:])
        )
    }

    private static func readFLACComments(fileURL: URL) -> FLACComments? {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return nil }
        defer { try? handle.close() }
        guard (try? handle.read(upToCount: 4)) == Data("fLaC".utf8) else { return nil }

        while true {
            guard let header = try? handle.read(upToCount: 4), header.count == 4 else { return nil }
            let isLast = (header[0] & 0x80) != 0
            let blockType = header[0] & 0x7F
            let blockLength = Int(header[1]) << 16 | Int(header[2]) << 8 | Int(header[3])
            guard let block = try? handle.read(upToCount: blockLength), block.count == blockLength else {
                return nil
            }

            if blockType == 4 {
                guard let tags = parseVorbisCommentBlock(block) else { return nil }
                return FLACComments(tags: tags, rawBlock: block)
            }
            if isLast { return nil }
        }
    }

    private static func projectedFLACValues(from tags: [MetadataTag]) -> [String: String] {
        var values: [String: String] = [:]
        for tag in tags {
            let name = tag.normalizedName
            let value = tag.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty, !value.isEmpty { values[name] = value }
        }
        return values
    }

    private static func littleEndianUInt32(_ data: Data, offset: inout Int) -> UInt32? {
        guard offset <= data.count, data.count - offset >= 4 else { return nil }
        let value = UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
        offset += 4
        return value
    }

    private struct FLACComments {
        let tags: [MetadataTag]
        let rawBlock: Data
    }

    private struct DurationFacts {
        let source: String
        let additionalFacts: [String: String]
    }
}
