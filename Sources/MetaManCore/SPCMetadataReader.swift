import Foundation

/// Reads SPC ID666 and xID6 metadata directly from the file; no playback
/// emulator or decoder is created.
public enum SPCMetadataReader {
    private static let minimumFileSize = 0x10200
    private static let extendedTagOffset = 0x10200
    private static let headerMagic = Array("SNES-SPC700 Sound File Data".utf8)
    private static let maximumID666PlaySeconds = 0x1FFF
    private static let maximumID666FadeMilliseconds = 999_999
    private static let maximumXID6Ticks = 383_999_999
    private static let defaultPlayLengthMs = 150_000

    public static func matches(_ data: Data) -> Bool {
        data.count >= headerMagic.count && data.prefix(headerMagic.count).elementsEqual(headerMagic)
    }

    public static func read(fileURL: URL) throws -> MetadataDocument {
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        return try read(data: data, displayName: fileURL.lastPathComponent)
    }

    public static func read(data: Data, displayName: String = "SPC") throws -> MetadataDocument {
        guard data.count >= minimumFileSize, matches(data) else {
            throw MetadataReadError.malformedFile("Not an SPC file with a valid header: \(displayName)")
        }

        let legacy = legacyMetadata(in: data)
        let extendedResult = extendedMetadata(in: data)
        let extended: SPCExtendedMetadata
        let extendedRawBlock: Data?
        var diagnostics = legacy.diagnostics
        switch extendedResult {
        case .absent:
            extended = SPCExtendedMetadata()
            extendedRawBlock = nil
        case .valid(let metadata, let rawBlock):
            extended = metadata
            extendedRawBlock = rawBlock
        case .invalid(let rawBlock, let message):
            extended = SPCExtendedMetadata()
            extendedRawBlock = rawBlock
            diagnostics.append(message)
        }

        let hasMetadataTags = legacy.hasTag || extended.hasTag
        let introLengthMs = extended.introLengthMs ?? (hasMetadataTags ? 0 : -1)
        let loopLengthMs = extended.loopLengthMs ?? (hasMetadataTags ? 0 : -1)
        let hasExtendedPlaybackTiming = extended.introLengthMs != nil
            || extended.loopLengthMs != nil
            || extended.endLengthMs != nil
        let playLengthMs = legacy.playLengthMs > 0
            ? legacy.playLengthMs
            : hasExtendedPlaybackTiming ? effectiveExtendedPlayLength(
                introLengthMs: introLengthMs,
                loopLengthMs: loopLengthMs,
                endLengthMs: extended.endLengthMs,
                loopCount: extended.loopCount
            ) : defaultPlayLengthMs

        let id666RawBlock = legacy.rawTagBlock
        var rawBlocks: [String: Data] = [:]
        if let id666RawBlock { rawBlocks["id666"] = id666RawBlock }
        if let extendedRawBlock { rawBlocks["xid6"] = extendedRawBlock }

        var facts = legacy.technicalFacts
        facts["format"] = "SPC"
        facts["hasID666"] = String(legacy.hasTag)
        facts["hasID666Data"] = String(legacy.hasTag || legacy.hasRecoveredData)
        facts["hasXID6"] = String(extended.hasTag)
        for (key, value) in extended.technicalFacts { facts[key] = value }
        if let id666RawBlock { facts["id666BlockBytes"] = String(id666RawBlock.count) }
        if let extendedRawBlock { facts["xid6BlockBytes"] = String(extendedRawBlock.count) }

        let allTags = legacy.tags + extended.tags
        return MetadataDocument(
            format: "spc",
            fields: MetadataFields(
                title: extended.song ?? legacy.song,
                game: extended.game ?? legacy.game,
                system: "Super Nintendo",
                artist: extended.artist ?? legacy.artist,
                album: extended.soundtrackTitle,
                date: extended.date ?? legacy.date,
                year: extended.copyrightYear ?? legacy.copyrightYear,
                genre: nil,
                comment: extended.comment ?? legacy.comment,
                copyright: nil,
                encodedBy: extended.dumper ?? legacy.dumper
            ),
            tags: allTags,
            rawTagBlock: extendedRawBlock ?? id666RawBlock,
            rawMetadataBlocks: rawBlocks.isEmpty ? nil : rawBlocks,
            sourceEncoding: rawBlocks.isEmpty ? nil : "Windows-1252",
            timing: MetadataTiming(
                introLengthMs: introLengthMs,
                loopLengthMs: loopLengthMs,
                playLengthMs: playLengthMs,
                fadeLengthMs: extended.fadeLengthMs ?? legacy.fadeLengthMs
            ),
            technicalFacts: facts,
            diagnostics: diagnostics
        )
    }

    private static func legacyMetadata(in data: Data) -> SPCLegacyMetadata {
        let headerFlag = data[0x23]
        let flagDeclaresTags = headerFlag == 0x1A
        let layout = detectID666Layout(in: data)
        let authorRange = layout == .binary ? 0xB0..<0xD0 : 0xB1..<0xD1
        let playSeconds: Int
        let fadeLengthMs: Int
        let rawPlay: String?
        let rawFade: String?
        let playTimingLayout: String
        let fadeTimingLayout: String

        let textPlay = decimal(data[0xA9..<0xAC], maximum: maximumID666PlaySeconds)
        let binaryPlay = Int(littleEndianUInt16(data, at: 0xA9) ?? 0)
        let textFade = decimal(data[0xAC..<0xB1], maximum: maximumID666FadeMilliseconds)
        let binaryFade = littleEndianUInt24(data, at: 0xAC) ?? 0

        switch layout {
        case .text:
            if let textPlay {
                playSeconds = textPlay
                rawPlay = text(data[0xA9..<0xAC])
                playTimingLayout = "text"
            } else if binaryPlay <= maximumID666PlaySeconds {
                playSeconds = binaryPlay
                rawPlay = String(binaryPlay)
                playTimingLayout = "binary-fallback"
            } else {
                playSeconds = 0
                rawPlay = nil
                playTimingLayout = "unavailable"
            }
            if let textFade {
                fadeLengthMs = textFade
                rawFade = text(data[0xAC..<0xB1])
                fadeTimingLayout = "text"
            } else if binaryFade <= maximumID666FadeMilliseconds {
                fadeLengthMs = binaryFade
                rawFade = String(binaryFade)
                fadeTimingLayout = "binary-fallback"
            } else {
                fadeLengthMs = 0
                rawFade = nil
                fadeTimingLayout = "unavailable"
            }
        case .binary:
            if binaryPlay <= maximumID666PlaySeconds {
                playSeconds = binaryPlay
                rawPlay = String(binaryPlay)
                playTimingLayout = "binary"
            } else if let textPlay {
                playSeconds = textPlay
                rawPlay = text(data[0xA9..<0xAC])
                playTimingLayout = "text-fallback"
            } else {
                playSeconds = 0
                rawPlay = nil
                playTimingLayout = "unavailable"
            }
            if binaryFade <= maximumID666FadeMilliseconds {
                fadeLengthMs = binaryFade
                rawFade = String(binaryFade)
                fadeTimingLayout = "binary"
            } else if let textFade {
                fadeLengthMs = textFade
                rawFade = text(data[0xAC..<0xB1])
                fadeTimingLayout = "text-fallback"
            } else {
                fadeLengthMs = 0
                rawFade = nil
                fadeTimingLayout = "unavailable"
            }
        }

        let song = nonEmptyText(data[0x2E..<0x4E])
        let game = nonEmptyText(data[0x4E..<0x6E])
        let dumper = nonEmptyText(data[0x6E..<0x7E])
        let comment = nonEmptyText(data[0x7E..<0x9E])
        let date = layout == .text
            ? nonEmptyText(data[0x9E..<0xA9])
            : binaryDate(data[0x9E..<0xA2])
        let authorStart = authorRange.lowerBound
        let authorFirstByte = data[authorStart]
        let gmeAuthorOffset = layout == .binary
            && (authorFirstByte < 0x20 || (0x30...0x39).contains(authorFirstByte)) ? 1 : 0
        let artist = nonEmptyText(data[(authorStart + gmeAuthorOffset)..<authorRange.upperBound])
        let mutedOffset = layout == .binary ? 0xD0 : 0xD1
        let emulatorOffset = layout == .binary ? 0xD1 : 0xD2
        let mutedVoices = data[mutedOffset]
        let emulator = data[emulatorOffset]

        let populatedTextFields = [song, game, dumper, comment, artist].compactMap { $0 }.count
        let coherentIdentity = (song != nil && game != nil)
            || (song != nil && artist != nil)
            || (game != nil && artist != nil)
        let recoveredWithoutFlag = !flagDeclaresTags
            && headerFlag == 0x1B
            && populatedTextFields >= 2
            && (coherentIdentity || playSeconds > 0 || fadeLengthMs > 0 || date != nil)
        guard flagDeclaresTags || recoveredWithoutFlag else {
            return SPCLegacyMetadata(technicalFacts: [
                "id666Flag": String(format: "0x%02X", headerFlag),
                "id666Flagged": String(flagDeclaresTags)
            ])
        }

        var tags: [MetadataTag] = []
        appendTag("Song", song, to: &tags)
        appendTag("Game", game, to: &tags)
        appendTag("Dumper", dumper, to: &tags)
        appendTag("Comment", comment, to: &tags)
        appendTag("Date", date, to: &tags)
        appendTag("Length (seconds)", rawPlay, to: &tags)
        appendTag("Fade (milliseconds)", rawFade, to: &tags)
        appendTag("Artist", artist, to: &tags)

        return SPCLegacyMetadata(
            hasTag: flagDeclaresTags,
            hasRecoveredData: recoveredWithoutFlag,
            layout: layout,
            song: song,
            game: game,
            dumper: dumper,
            comment: comment,
            date: date,
            artist: artist,
            copyrightYear: nil,
            playLengthMs: playSeconds * 1_000,
            fadeLengthMs: fadeLengthMs,
            tags: tags,
            rawTagBlock: Data(data[0x2E..<0xD2]),
            diagnostics: recoveredWithoutFlag
                ? ["ID666 flag is 0x1B (tag absent), but coherent fixed-slot metadata was present; recovered the readable fields and timings."]
                : [],
            technicalFacts: [
                "id666Layout": layout.description,
                "id666PlayTimingLayout": playTimingLayout,
                "id666FadeTimingLayout": fadeTimingLayout,
                "id666Flag": String(format: "0x%02X", headerFlag),
                "id666Flagged": String(flagDeclaresTags),
                "recoveredID666WithoutFlag": String(recoveredWithoutFlag),
                "mutedVoices": String(format: "0x%02X", mutedVoices),
                "emulatorCode": String(emulator),
                "emulator": emulatorName(emulator)
            ]
        )
    }

    private static func detectID666Layout(in data: Data) -> SPCID666Layout {
        let date = data[0x9E..<0xA9]
        let textPlay = decimal(data[0xA9..<0xAC], maximum: maximumID666PlaySeconds)
        let textFade = decimal(data[0xAC..<0xB1], maximum: maximumID666FadeMilliseconds)
        let binaryPlay = Int(littleEndianUInt16(data, at: 0xA9) ?? 0)
        let binaryFade = littleEndianUInt24(data, at: 0xAC) ?? 0
        let binaryReservedBytesAreClear = data[0xAB] == 0 && data[0xAF] == 0
        let binaryValuesArePlausible = binaryPlay <= maximumID666PlaySeconds
            && binaryFade <= maximumID666FadeMilliseconds

        if date.contains(where: { !isTextDateByte($0) }) { return .binary }
        let dateHasText = date.contains(where: { (0x30...0x39).contains($0) || $0 == 0x2F })
        if dateHasText { return .text }
        if data[0xB0] == 0 && !text(data[0xB1..<0xD1]).isEmpty { return .text }

        if binaryReservedBytesAreClear && binaryValuesArePlausible {
            if textPlay == nil && textFade == nil { return .binary }
            if textFade == nil && binaryPlay > 0 && binaryPlay < 0x100 { return .binary }
            if textPlay == nil || binaryPlay <= maximumID666PlaySeconds { return .binary }
        }
        if textPlay != nil || textFade != nil { return .text }
        return .binary
    }

    private static func extendedMetadata(in data: Data) -> SPCXID6Result {
        guard data.count > extendedTagOffset,
              data[extendedTagOffset...].starts(with: Data("xid6".utf8)) else { return .absent }
        guard data.count >= extendedTagOffset + 8,
              let length = littleEndianUInt32(data, at: extendedTagOffset + 4),
              Int(length) <= data.count - (extendedTagOffset + 8) else {
            return .invalid(
                rawBlock: Data(data[extendedTagOffset...]),
                message: "xID6 signature is present but its chunk header or declared payload is truncated; ID666 values were used where available."
            )
        }

        let chunkEnd = extendedTagOffset + 8 + Int(length)
        let rawBlock = Data(data[extendedTagOffset..<chunkEnd])
        var metadata = SPCExtendedMetadata(hasTag: true)
        var offset = extendedTagOffset + 8
        var itemCount = 0

        while offset < chunkEnd {
            let remaining = chunkEnd - offset
            if remaining < 4 {
                guard data[offset..<chunkEnd].allSatisfy({ $0 == 0 }) else {
                    return .invalid(rawBlock: rawBlock, message: "xID6 chunk ends with an incomplete non-padding item; ID666 values were used where available.")
                }
                break
            }

            let item = data[offset]
            let type = data[offset + 1]
            let length = Int(littleEndianUInt16(data, at: offset + 2) ?? 0)
            offset += 4
            itemCount += 1

            if type == 0 {
                apply(item: item, type: type, rawValue: UInt32(length), payload: nil, to: &metadata)
                continue
            }

            guard length <= chunkEnd - offset else {
                return .invalid(rawBlock: rawBlock, message: "xID6 item payload exceeds its chunk boundary; ID666 values were used where available.")
            }
            let payloadEnd = offset + length
            let payload = Data(data[offset..<payloadEnd])
            apply(item: item, type: type, rawValue: nil, payload: payload, to: &metadata)

            let paddedEnd = offset + ((length + 3) & ~3)
            if paddedEnd <= chunkEnd && data[payloadEnd..<paddedEnd].allSatisfy({ $0 == 0 }) {
                offset = paddedEnd
            } else {
                offset = payloadEnd
            }
        }

        metadata.technicalFacts["xid6ItemCount"] = String(itemCount)
        return .valid(metadata: metadata, rawBlock: rawBlock)
    }

    private static func apply(
        item: UInt8,
        type: UInt8,
        rawValue: UInt32?,
        payload: Data?,
        to metadata: inout SPCExtendedMetadata
    ) {
        let value = rawValue.map(Int.init)
        let string = payload.flatMap(nonEmptyText)
        switch (item, type) {
        case (0x01, 1): metadata.song = string; appendTag("Song", string, to: &metadata.tags)
        case (0x02, 1): metadata.game = string; appendTag("Game", string, to: &metadata.tags)
        case (0x03, 1): metadata.artist = string; appendTag("Artist", string, to: &metadata.tags)
        case (0x04, 1): metadata.dumper = string; appendTag("Dumper", string, to: &metadata.tags)
        case (0x05, 4):
            let date = payload.flatMap(binaryDate)
            metadata.date = date
            appendTag("Date", date, to: &metadata.tags)
        case (0x06, 0):
            let emulator = value.map { UInt8(truncatingIfNeeded: $0) }
            if let emulator { metadata.technicalFacts["emulatorCode"] = String(emulator); metadata.technicalFacts["emulator"] = emulatorName(emulator) }
            appendTag("Emulator", emulator.map(emulatorName), to: &metadata.tags)
        case (0x07, 1): metadata.comment = string; appendTag("Comment", string, to: &metadata.tags)
        case (0x10, 1): metadata.soundtrackTitle = string; appendTag("OST Title", string, to: &metadata.tags)
        case (0x11, 0): metadata.technicalFacts["soundtrackDisc"] = value.map(String.init); appendTag("OST Disc", value.map(String.init), to: &metadata.tags)
        case (0x12, 0):
            let trackValue = value.map { $0 & 0xFFFF }
            metadata.technicalFacts["soundtrackTrack"] = trackValue.map { String(format: "%04X", $0) }
            appendTag("OST Track", trackValue.map { String(format: "%04X", $0) }, to: &metadata.tags)
        case (0x13, 1): metadata.publisher = string; appendTag("Publisher", string, to: &metadata.tags)
        case (0x14, 0):
            metadata.copyrightYear = value.map(String.init)
            appendTag("Copyright Year", metadata.copyrightYear, to: &metadata.tags)
        case (0x30, 4): metadata.introLengthMs = ticksToMilliseconds(payload); appendTimingTag("Intro Length (ms)", metadata.introLengthMs, to: &metadata.tags)
        case (0x31, 4): metadata.loopLengthMs = ticksToMilliseconds(payload); appendTimingTag("Loop Length (ms)", metadata.loopLengthMs, to: &metadata.tags)
        case (0x32, 4): metadata.endLengthMs = ticksToMilliseconds(payload); appendTimingTag("End Length (ms)", metadata.endLengthMs, to: &metadata.tags)
        case (0x33, 4): metadata.fadeLengthMs = ticksToMilliseconds(payload); appendTimingTag("Fade Length (ms)", metadata.fadeLengthMs, to: &metadata.tags)
        case (0x34, 0):
            if let value { metadata.technicalFacts["mutedVoices"] = String(format: "0x%02X", value & 0xFF) }
            appendTag("Muted Voices", value.map { String(format: "0x%02X", $0 & 0xFF) }, to: &metadata.tags)
        case (0x35, 0):
            let loopCount = Int(value ?? 0) & 0xFF
            metadata.loopCount = loopCount
            appendTag("Loop Count", String(loopCount), to: &metadata.tags)
        case (0x36, 0):
            if let value { metadata.technicalFacts["mixingLevel"] = String(value & 0xFF) }
            appendTag("Mixing Level", value.map { String($0 & 0xFF) }, to: &metadata.tags)
        default:
            break
        }
    }

    private static func appendTimingTag(_ name: String, _ milliseconds: Int?, to tags: inout [MetadataTag]) {
        appendTag(name, milliseconds.map(String.init), to: &tags)
    }

    private static func appendTag(_ name: String, _ value: String?, to tags: inout [MetadataTag]) {
        guard let value else { return }
        tags.append(MetadataTag(name: name, value: value))
    }

    private static func effectiveExtendedPlayLength(
        introLengthMs: Int,
        loopLengthMs: Int,
        endLengthMs: Int?,
        loopCount: Int?
    ) -> Int {
        let end = max(0, endLengthMs ?? 0)
        guard introLengthMs > 0 || loopLengthMs > 0 || end > 0 else { return 0 }
        let repetitions = max(0, loopCount ?? 1)
        return introLengthMs + loopLengthMs * repetitions + end
    }

    private static func ticksToMilliseconds(_ payload: Data?) -> Int? {
        guard let payload, payload.count == 4,
              let raw = littleEndianUInt32(payload) else { return nil }
        let ticks = Int64(Int32(bitPattern: raw))
        guard ticks >= 0, ticks <= Int64(maximumXID6Ticks) else { return nil }
        return Int(ticks * 1_000 / 64_000)
    }

    private static func binaryDate(_ bytes: Data) -> String? {
        guard let raw = littleEndianUInt32(bytes), raw >= 10_000_101, raw <= 99_991_231 else { return nil }
        let value = String(format: "%08u", raw)
        let year = Int(value.prefix(4)) ?? 0
        let monthStart = value.index(value.startIndex, offsetBy: 4)
        let dayStart = value.index(value.startIndex, offsetBy: 6)
        let month = Int(value[monthStart..<dayStart]) ?? 0
        let day = Int(value[dayStart...]) ?? 0
        guard (1...12).contains(month), (1...31).contains(day), year > 0 else { return nil }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func emulatorName(_ value: UInt8) -> String {
        switch value {
        case 0: "Unknown"
        case 1: "ZSNES"
        case 2: "Snes9x"
        default: String(format: "Unknown (0x%02X)", value)
        }
    }

    private static func nonEmptyText(_ bytes: Data) -> String? {
        let value = text(bytes)
        return value.isEmpty ? nil : value
    }

    private static func text(_ bytes: some Collection<UInt8>) -> String {
        let bytes = Data(bytes.prefix { $0 != 0 })
        return (String(data: bytes, encoding: .windowsCP1252) ?? String(decoding: bytes, as: UTF8.self))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decimal(_ bytes: some Collection<UInt8>, maximum: Int) -> Int? {
        var value = 0
        var sawDigit = false
        for byte in bytes {
            if byte == 0 { break }
            if byte == 0x20 || byte == 0x09 { continue }
            guard (0x30...0x39).contains(byte) else { return nil }
            sawDigit = true
            value = value * 10 + Int(byte - 0x30)
            if value > maximum { return nil }
        }
        return sawDigit ? value : nil
    }

    private static func isTextDateByte(_ byte: UInt8) -> Bool {
        byte == 0 || byte == 0x20 || byte == 0x2D || byte == 0x2F || (0x30...0x39).contains(byte)
    }

    private static func littleEndianUInt16(_ data: Data, at offset: Int) -> UInt16? {
        guard offset + 2 <= data.count else { return nil }
        return UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func littleEndianUInt24(_ data: Data, at offset: Int) -> Int? {
        guard offset + 3 <= data.count else { return nil }
        return Int(data[offset]) | Int(data[offset + 1]) << 8 | Int(data[offset + 2]) << 16
    }

    private static func littleEndianUInt32(_ data: Data, at offset: Int) -> UInt32? {
        guard offset + 4 <= data.count else { return nil }
        return UInt32(data[offset]) | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24
    }

    private static func littleEndianUInt32(_ data: Data) -> UInt32? {
        guard data.count == 4 else { return nil }
        return UInt32(data[data.startIndex]) | UInt32(data[data.startIndex + 1]) << 8
            | UInt32(data[data.startIndex + 2]) << 16 | UInt32(data[data.startIndex + 3]) << 24
    }
}

private enum SPCID666Layout: Equatable, CustomStringConvertible {
    case text
    case binary

    var description: String { self == .binary ? "binary" : "text" }
}

private enum SPCXID6Result {
    case absent
    case valid(metadata: SPCExtendedMetadata, rawBlock: Data)
    case invalid(rawBlock: Data, message: String)
}

private struct SPCLegacyMetadata {
    var hasTag = false
    var hasRecoveredData = false
    var layout: SPCID666Layout?
    var song: String?
    var game: String?
    var dumper: String?
    var comment: String?
    var date: String?
    var artist: String?
    var copyrightYear: String?
    var playLengthMs = 0
    var fadeLengthMs = 0
    var tags: [MetadataTag] = []
    var rawTagBlock: Data?
    var diagnostics: [String] = []
    var technicalFacts: [String: String] = [:]
}

private struct SPCExtendedMetadata {
    var hasTag = false
    var song: String?
    var game: String?
    var artist: String?
    var dumper: String?
    var comment: String?
    var date: String?
    var soundtrackTitle: String?
    var publisher: String?
    var copyrightYear: String?
    var introLengthMs: Int?
    var loopLengthMs: Int?
    var endLengthMs: Int?
    var fadeLengthMs: Int?
    var loopCount: Int?
    var tags: [MetadataTag] = []
    var technicalFacts: [String: String] = [:]
}
