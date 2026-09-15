import Foundation

/// Reads NES/Game Boy music identity and track structure from NSF, GBS, and
/// NSFE source bytes. No CPU/emulator core is loaded. Multi-track order is
/// returned through `MetadataReadResult`; NSFE playlist repetitions remain
/// distinct documents with their original source indices.
enum GameMusicMetadataReader {
    private static let nsfSignature = Data([0x4E, 0x45, 0x53, 0x4D, 0x1A])
    private static let defaultPlayLengthMs = 150_000

    static func hasSupportedHint(_ hint: String?) -> Bool {
        guard let hint else { return false }
        return ["nsf", "gbs", "nsfe"].contains(normalize(hint))
    }

    static func matches(_ data: Data) -> Bool {
        data.starts(with: nsfSignature)
            || data.starts(with: Data("GBS".utf8))
            || data.starts(with: Data("NSFE".utf8))
    }

    static func readResult(
        data: Data,
        formatHint: String?,
        displayName: String?
    ) throws -> MetadataReadResult {
        let hint = formatHint.map(normalize)
        let name = displayName ?? hint?.uppercased() ?? "game-music source"
        switch hint {
        case "nsf": return try readFixedHeader(data, kind: .nsf, displayName: name)
        case "gbs": return try readFixedHeader(data, kind: .gbs, displayName: name)
        case "nsfe": return try readNSFE(data, displayName: name)
        case nil:
            if data.starts(with: nsfSignature) { return try readFixedHeader(data, kind: .nsf, displayName: name) }
            if data.starts(with: Data("GBS".utf8)) { return try readFixedHeader(data, kind: .gbs, displayName: name) }
            if data.starts(with: Data("NSFE".utf8)) { return try readNSFE(data, displayName: name) }
            throw MetadataReadError.unsupportedFormat("unknown game-music content")
        default:
            throw MetadataReadError.unsupportedFormat(hint ?? "unknown game-music content")
        }
    }

    private enum FixedKind {
        case nsf
        case gbs

        var format: String { self == .nsf ? "nsf" : "gbs" }
        var system: String { self == .nsf ? "Nintendo NES" : "Nintendo Game Boy" }
    }

    private static func readFixedHeader(
        _ data: Data,
        kind: FixedKind,
        displayName: String
    ) throws -> MetadataReadResult {
        let headerSize = kind == .nsf ? 0x80 : 0x70
        let signatureMatches = kind == .nsf ? data.starts(with: nsfSignature) : data.starts(with: Data("GBS".utf8))
        guard data.count >= headerSize, signatureMatches else {
            throw malformed("Not a \(kind.format.uppercased()) file with a valid header: \(displayName)")
        }

        let versionOffset = kind == .nsf ? 0x05 : 0x03
        let countOffset = kind == .nsf ? 0x06 : 0x04
        let firstTrackOffset = kind == .nsf ? 0x07 : 0x05
        let version = Int(data[versionOffset])
        let trackCount = Int(data[countOffset])
        guard version > 0, trackCount > 0 else {
            throw malformed("\(kind.format.uppercased()) has no usable version or tracks: \(displayName)")
        }

        let identityOffset = kind == .nsf ? 0x0E : 0x10
        let game = fixedText(data, at: identityOffset, length: 0x20)
        let artist = fixedText(data, at: identityOffset + 0x20, length: 0x20)
        let comment = fixedText(data, at: identityOffset + 0x40, length: 0x20)
        var facts: [String: String] = [
            "version": String(version),
            "trackCount": String(trackCount),
            "firstTrack": String(data[firstTrackOffset]),
            "loadAddress": hex(littleEndianUInt16(data, at: kind == .nsf ? 0x08 : 0x06), width: 4),
            "initAddress": hex(littleEndianUInt16(data, at: kind == .nsf ? 0x0A : 0x08), width: 4),
            "playAddress": hex(littleEndianUInt16(data, at: kind == .nsf ? 0x0C : 0x0A), width: 4)
        ]

        if kind == .nsf {
            facts["ntscSpeedMicroseconds"] = String(littleEndianUInt16(data, at: 0x6E))
            facts["palSpeedMicroseconds"] = String(littleEndianUInt16(data, at: 0x78))
            facts["playbackFlags"] = hex(data[0x7A], width: 2)
            facts["expansionAudio"] = hex(data[0x7B], width: 2)
            facts["banks"] = data[0x70..<0x78].map { hex($0, width: 2) }.joined(separator: " ")
        } else {
            facts["stackAddress"] = hex(littleEndianUInt16(data, at: 0x0C), width: 4)
            facts["timerModulo"] = hex(data[0x0E], width: 2)
            facts["timerControl"] = hex(data[0x0F], width: 2)
        }

        let document = MetadataDocument(
            format: kind.format,
            fields: MetadataFields(
                game: game.isEmpty ? nil : game,
                system: kind.system,
                artist: artist.isEmpty ? nil : artist,
                comment: comment.isEmpty ? nil : comment
            ),
            tags: [
                MetadataTag(name: "game", value: game),
                MetadataTag(name: "artist", value: artist),
                MetadataTag(name: "comment", value: comment)
            ],
            rawMetadataBlocks: ["fixed-header": Data(data.prefix(headerSize))],
            timing: MetadataTiming(
                introLengthMs: -1,
                loopLengthMs: -1,
                playLengthMs: defaultPlayLengthMs,
                fadeLengthMs: -1
            ),
            technicalFacts: facts
        )
        return MetadataReadResult(tracks: (0..<trackCount).map {
            MetadataTrack(sourceTrackIndex: $0, document: document)
        })
    }

    private struct NSFEInfo {
        let loadAddress: UInt16
        let initAddress: UInt16
        let playAddress: UInt16
        let regionFlags: UInt8
        let expansionChipFlags: UInt8
        let trackCount: Int
        let firstTrack: Int
    }

    private static func readNSFE(_ data: Data, displayName: String) throws -> MetadataReadResult {
        guard data.starts(with: Data("NSFE".utf8)) else {
            throw malformed("Not an NSFE file with a valid header: \(displayName)")
        }

        var offset = 4
        var info: NSFEInfo?
        var dataByteCount: Int?
        var sawNEND = false
        var auth: [String] = []
        var labels: [String] = []
        var authors: [String] = []
        var times: [Int32] = []
        var fades: [Int32] = []
        var playlist: [Int] = []
        var soundEffects: [Int] = []
        var banks = [UInt8](repeating: 0, count: 8)
        var ntscRate: UInt16?
        var palRate: UInt16?
        var dendyRate: UInt16?
        var regionOverride: UInt8?
        var preferredRegion: UInt8?
        var nsf2Flags: UInt8?
        var vrc7Variant: UInt8?
        var vrc7PatchSet = Data()
        var notes = ""
        var metadataBytes = Data(data.prefix(4))
        var diagnostics: [String] = []

        while offset < data.count {
            guard data.count - offset >= 8 else {
                throw malformed("NSFE has a truncated chunk header: \(displayName)")
            }
            let payloadLength64 = UInt64(readUInt32(data, at: offset))
            let payloadStart = offset + 8
            guard payloadLength64 <= UInt64(data.count - payloadStart) else {
                throw malformed("NSFE chunk exceeds the file boundary: \(displayName)")
            }
            let payloadLength = Int(payloadLength64)
            let payloadEnd = payloadStart + payloadLength
            let payloadRange = payloadStart..<payloadEnd
            let identifier = String(decoding: data[(offset + 4)..<(offset + 8)], as: UTF8.self)
            let chunkStart = offset
            offset = payloadEnd

            // Retain the source-order framing and all non-audio metadata bytes.
            // DATA is validated and counted, but not copied into every track's
            // metadata document.
            if identifier != "DATA" {
                metadataBytes.append(contentsOf: data[chunkStart..<payloadEnd])
            }

            switch identifier {
            case "INFO":
                guard info == nil, dataByteCount == nil else {
                    throw malformed("NSFE INFO chunk is duplicated or appears after DATA: \(displayName)")
                }
                info = try parseInfo(Data(data[payloadRange]), displayName: displayName)
            case "DATA":
                guard info != nil, dataByteCount == nil else {
                    throw malformed("NSFE DATA chunk is out of order or duplicated: \(displayName)")
                }
                dataByteCount = payloadLength
            case "NEND":
                guard info != nil, dataByteCount != nil else {
                    throw malformed("NSFE NEND appears before INFO/DATA: \(displayName)")
                }
                sawNEND = true
                offset = data.count
            case "BANK":
                for index in 0..<min(payloadLength, banks.count) { banks[index] = data[payloadStart + index] }
            case "auth": auth = strings(in: data, range: payloadRange)
            case "time":
                times = signedMilliseconds(in: data, range: payloadRange)
                if payloadLength % 4 != 0 { diagnostics.append("Ignored \(payloadLength % 4) trailing byte(s) in the NSFE time chunk.") }
            case "fade":
                fades = signedMilliseconds(in: data, range: payloadRange)
                if payloadLength % 4 != 0 { diagnostics.append("Ignored \(payloadLength % 4) trailing byte(s) in the NSFE fade chunk.") }
            case "tlbl": labels = strings(in: data, range: payloadRange)
            case "taut": authors = strings(in: data, range: payloadRange)
            case "plst": playlist = data[payloadRange].map(Int.init)
            case "psfx": soundEffects = data[payloadRange].map(Int.init)
            case "text": notes = strings(in: data, range: payloadRange).first ?? ""
            case "RATE": (ntscRate, palRate, dendyRate) = parseRates(data, range: payloadRange)
            case "regn":
                regionOverride = payloadLength > 0 ? data[payloadStart] : nil
                preferredRegion = payloadLength > 1 ? data[payloadStart + 1] : nil
            case "NSF2":
                guard payloadLength > 0 else { throw malformed("NSFE NSF2 chunk is empty: \(displayName)") }
                nsf2Flags = data[payloadStart]
            case "VRC7":
                guard payloadLength > 0 else { throw malformed("NSFE VRC7 chunk is empty: \(displayName)") }
                vrc7Variant = data[payloadStart]
                vrc7PatchSet = Data(data[(payloadStart + 1)..<payloadEnd])
            default:
                guard identifier.utf8.first.map({ !isUppercaseASCII($0) }) == true else {
                    throw malformed("Unsupported mandatory NSFE chunk \(identifier): \(displayName)")
                }
            }
        }

        guard let info, let dataByteCount, sawNEND else {
            throw malformed("NSFE is missing a required INFO, DATA, or NEND chunk: \(displayName)")
        }
        let actualPlaylist = playlist.isEmpty ? Array(0..<info.trackCount) : playlist
        try validateTrackReferences(actualPlaylist, trackCount: info.trackCount, name: "PLST", displayName: displayName)
        try validateTrackReferences(soundEffects, trackCount: info.trackCount, name: "PSFX", displayName: displayName)

        let game = auth[safe: 0] ?? ""
        let artist = auth[safe: 1] ?? ""
        let copyright = auth[safe: 2] ?? ""
        let ripper = auth[safe: 3] ?? ""
        let comment = [
            copyright.isEmpty ? nil : "Copyright: \(copyright)",
            ripper.isEmpty ? nil : "Ripped by: \(ripper)",
            notes.isEmpty ? nil : notes
        ].compactMap { $0 }.joined(separator: "\n")

        var sharedFacts: [String: String] = [
            "loadAddress": hex(info.loadAddress, width: 4),
            "initAddress": hex(info.initAddress, width: 4),
            "playAddress": hex(info.playAddress, width: 4),
            "regionFlags": hex(info.regionFlags, width: 2),
            "expansionChipFlags": hex(info.expansionChipFlags, width: 2),
            "trackCount": String(info.trackCount),
            "firstTrack": String(info.firstTrack),
            "banks": banks.map { hex($0, width: 2) }.joined(separator: " "),
            "dataByteCount": String(dataByteCount),
            "playlistSourceTrackIndices": actualPlaylist.map(String.init).joined(separator: ","),
            "soundEffectSourceTrackIndices": soundEffects.map(String.init).joined(separator: ",")
        ]
        if let ntscRate { sharedFacts["ntscSpeedMicroseconds"] = String(ntscRate) }
        if let palRate { sharedFacts["palSpeedMicroseconds"] = String(palRate) }
        if let dendyRate { sharedFacts["dendySpeedMicroseconds"] = String(dendyRate) }
        if let regionOverride { sharedFacts["regionOverrideFlags"] = hex(regionOverride, width: 2) }
        if let preferredRegion { sharedFacts["preferredRegion"] = hex(preferredRegion, width: 2) }
        if let nsf2Flags { sharedFacts["nsf2Flags"] = hex(nsf2Flags, width: 2) }
        if let vrc7Variant { sharedFacts["vrc7Variant"] = hex(vrc7Variant, width: 2) }
        if !vrc7PatchSet.isEmpty { sharedFacts["vrc7PatchSetByteCount"] = String(vrc7PatchSet.count) }

        let rawBlocks = ["non-audio-chunks": metadataBytes]
        let tracks = actualPlaylist.enumerated().map { visibleIndex, sourceIndex in
            let title = labels[safe: sourceIndex] ?? ""
            let trackAuthor = authors[safe: sourceIndex] ?? ""
            let time = times[safe: sourceIndex]
            let fade = fades[safe: sourceIndex]
            var facts = sharedFacts
            facts["visibleTrackIndex"] = String(visibleIndex)
            facts["sourceTrackIndex"] = String(sourceIndex)
            facts["timeMilliseconds"] = time.map(String.init) ?? "default"
            facts["fadeMilliseconds"] = fade.map(String.init) ?? "default"
            let document = MetadataDocument(
                format: "nsfe",
                fields: MetadataFields(
                    title: title.isEmpty ? nil : title,
                    game: game.isEmpty ? nil : game,
                    system: "Nintendo NES",
                    artist: (trackAuthor.isEmpty ? artist : trackAuthor).isEmpty
                        ? nil
                        : (trackAuthor.isEmpty ? artist : trackAuthor),
                    comment: comment.isEmpty ? nil : comment,
                    copyright: copyright.isEmpty ? nil : copyright,
                    encodedBy: ripper.isEmpty ? nil : ripper
                ),
                tags: [
                    MetadataTag(name: "game", value: game),
                    MetadataTag(name: "artist", value: artist),
                    MetadataTag(name: "copyright", value: copyright),
                    MetadataTag(name: "ripper", value: ripper),
                    MetadataTag(name: "notes", value: notes),
                    MetadataTag(name: "title", value: title),
                    MetadataTag(name: "track-author", value: trackAuthor),
                    MetadataTag(name: "time-ms", value: time.map(String.init) ?? ""),
                    MetadataTag(name: "fade-ms", value: fade.map(String.init) ?? "")
                ],
                rawMetadataBlocks: rawBlocks,
                timing: MetadataTiming(
                    introLengthMs: -1,
                    loopLengthMs: -1,
                    playLengthMs: (time ?? 0) > 0 ? Int(time!) : defaultPlayLengthMs,
                    fadeLengthMs: (fade ?? -1) >= 0 ? Int(fade!) : -1
                ),
                technicalFacts: facts,
                diagnostics: diagnostics
            )
            return MetadataTrack(sourceTrackIndex: sourceIndex, document: document)
        }
        return MetadataReadResult(tracks: tracks)
    }

    private static func parseInfo(_ payload: Data, displayName: String) throws -> NSFEInfo {
        guard payload.count >= 8 else { throw malformed("NSFE INFO chunk is too short: \(displayName)") }
        let trackCount = payload.count >= 9 ? Int(payload[8]) : 1
        let firstTrack = payload.count >= 10 ? Int(payload[9]) : 0
        guard trackCount > 0 else { throw malformed("NSFE INFO chunk declares no tracks: \(displayName)") }
        return NSFEInfo(
            loadAddress: littleEndianUInt16(payload, at: 0),
            initAddress: littleEndianUInt16(payload, at: 2),
            playAddress: littleEndianUInt16(payload, at: 4),
            regionFlags: payload[6],
            expansionChipFlags: payload[7],
            trackCount: trackCount,
            firstTrack: firstTrack
        )
    }

    private static func parseRates(_ data: Data, range: Range<Int>) -> (UInt16?, UInt16?, UInt16?) {
        let length = range.count
        return (
            length >= 2 ? littleEndianUInt16(data, at: range.lowerBound) : nil,
            length >= 4 ? littleEndianUInt16(data, at: range.lowerBound + 2) : nil,
            length >= 6 ? littleEndianUInt16(data, at: range.lowerBound + 4) : nil
        )
    }

    private static func signedMilliseconds(in data: Data, range: Range<Int>) -> [Int32] {
        stride(from: range.lowerBound, through: range.upperBound - 4, by: 4).map {
            Int32(bitPattern: readUInt32(data, at: $0))
        }
    }

    private static func strings(in data: Data, range: Range<Int>) -> [String] {
        guard !range.isEmpty else { return [] }
        var result: [String] = []
        var start = range.lowerBound
        for index in range where data[index] == 0 {
            result.append(decodeText(data[start..<index]))
            start = index + 1
        }
        if start < range.upperBound { result.append(decodeText(data[start..<range.upperBound])) }
        return result
    }

    private static func decodeText<S: Collection>(_ bytes: S) -> String where S.Element == UInt8 {
        let data = Data(bytes)
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .windowsCP1252)
            ?? ""
    }

    private static func fixedText(_ data: Data, at offset: Int, length: Int) -> String {
        let bytes = Data(data[offset..<(offset + length)].prefix { $0 != 0 })
        return (String(data: bytes, encoding: .windowsCP1252) ?? String(decoding: bytes, as: UTF8.self))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func validateTrackReferences(
        _ references: [Int],
        trackCount: Int,
        name: String,
        displayName: String
    ) throws {
        guard references.allSatisfy({ $0 >= 0 && $0 < trackCount }) else {
            throw malformed("NSFE \(name) references a track outside INFO: \(displayName)")
        }
    }

    private static func littleEndianUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }

    private static func hex<T: BinaryInteger>(_ value: T, width: Int) -> String {
        String(format: "0x%0*X", width, Int(value))
    }

    private static func malformed(_ message: String) -> MetadataReadError {
        .malformedFile(message)
    }

    private static func normalize(_ format: String) -> String {
        format.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).lowercased()
    }

    private static func isUppercaseASCII(_ byte: UInt8) -> Bool { (0x41...0x5A).contains(byte) }
}

private extension Array {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
