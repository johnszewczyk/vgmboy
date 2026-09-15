import Foundation

enum KSSMetadataReader {
    private static let baseHeaderSize = 0x10
    private static let extendedHeaderSize = 0x10
    private static let compatibilityTrackCount = 256

    static func matches(_ data: Data) -> Bool {
        data.count >= 4
            && (data.starts(with: Data("KSCC".utf8)) || data.starts(with: Data("KSSX".utf8)))
    }

    static func readResult(data: Data, displayName: String?) throws -> MetadataReadResult {
        guard data.count >= baseHeaderSize, matches(data) else {
            throw malformed("Invalid or truncated KSS header in \(displayName ?? "KSS source").")
        }

        let signature = String(decoding: data.prefix(4), as: UTF8.self)
        let extraHeaderSize = Int(data[0x0E])
        let deviceFlags = data[0x0F]
        let hasExtendedHeader = signature == "KSSX" && extraHeaderSize == extendedHeaderSize
        if hasExtendedHeader, data.count < baseHeaderSize + extendedHeaderSize {
            throw malformed("Truncated KSSX extended header in \(displayName ?? "KSS source").")
        }

        guard let loadAddress = uint16LE(data, at: 0x04),
              let loadSize = uint16LE(data, at: 0x06),
              let initAddress = uint16LE(data, at: 0x08),
              let playAddress = uint16LE(data, at: 0x0A) else {
            throw malformed("Truncated KSS base header in \(displayName ?? "KSS source").")
        }
        let dataOffset = hasExtendedHeader ? baseHeaderSize + extendedHeaderSize : baseHeaderSize
        let extendedHeaderFacts: (dataSize: UInt32, firstTrack: UInt16, lastTrack: UInt16)?
        if hasExtendedHeader {
            guard let dataSize = uint32LE(data, at: 0x10),
                  let first = uint16LE(data, at: 0x18),
                  let last = uint16LE(data, at: 0x1A) else {
                throw malformed("Truncated KSSX extended header in \(displayName ?? "KSS source").")
            }
            extendedHeaderFacts = (dataSize, first, last)
        } else {
            extendedHeaderFacts = nil
        }
        let trackCount = compatibilityTrackCount

        var facts = [
            "signature": signature,
            "loadAddress": String(loadAddress),
            "loadSize": String(loadSize),
            "initAddress": String(initAddress),
            "playAddress": String(playAddress),
            "firstBank": String(data[0x0C]),
            "bankMode": String(data[0x0D]),
            "extraHeaderSize": String(extraHeaderSize),
            "deviceFlags": String(deviceFlags),
            "dataOffset": String(dataOffset),
            "payloadByteCount": String(max(0, data.count - dataOffset)),
            "trackCount": String(trackCount),
            "trackCountSource": "256-slot compatibility listing",
            "system": systemName(for: deviceFlags)
        ]

        var rawBlocks = ["baseHeader": Data(data.prefix(baseHeaderSize))]
        if let extendedHeaderFacts {
            rawBlocks["kssxExtendedHeader"] = Data(data[baseHeaderSize..<(baseHeaderSize + extendedHeaderSize)])
            facts["declaredPayloadSize"] = String(extendedHeaderFacts.dataSize)
            facts["declaredFirstTrack"] = String(extendedHeaderFacts.firstTrack)
            facts["declaredLastTrack"] = String(extendedHeaderFacts.lastTrack)
            facts["declaredTrackCount"] = String(Int(extendedHeaderFacts.lastTrack) + 1)
            facts["psgVolume"] = String(data[0x1C])
            facts["sccVolume"] = String(data[0x1D])
            facts["msxMusicVolume"] = String(data[0x1E])
            facts["msxAudioVolume"] = String(data[0x1F])
        }

        var diagnostics: [String] = []
        if signature == "KSCC", extraHeaderSize != 0 {
            diagnostics.append("KSCC extra-header-size byte is ignored by the KSS compatibility reader.")
        } else if signature == "KSSX", extraHeaderSize != 0 && !hasExtendedHeader {
            diagnostics.append("Unsupported KSSX extra-header size; the reader uses the 256-slot compatibility default.")
        }

        let document = MetadataDocument(
            format: "kss",
            fields: MetadataFields(system: systemName(for: deviceFlags)),
            rawMetadataBlocks: rawBlocks,
            timing: MetadataTiming(introLengthMs: -1, loopLengthMs: -1, playLengthMs: 150_000, fadeLengthMs: -1),
            technicalFacts: facts,
            diagnostics: diagnostics
        )
        return MetadataReadResult(tracks: (0..<trackCount).map { index in
            MetadataTrack(sourceTrackIndex: index, document: document)
        })
    }

    /// Preserves ScanSong's established catalog labels for KSS device flags.
    private static func systemName(for flags: UInt8) -> String {
        guard flags & 0x02 != 0 else { return "MSX" }
        var system = "Sega Master System"
        if flags & 0x04 != 0 { system = "Game Gear" }
        if flags & 0x01 != 0 { system = "Sega Mega Drive" }
        return system
    }

    private static func uint16LE(_ data: Data, at offset: Int) -> UInt16? {
        guard offset >= 0, offset <= data.count - 2 else { return nil }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func uint32LE(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, offset <= data.count - 4 else { return nil }
        return UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }

    private static func malformed(_ message: String) -> MetadataReadError {
        .malformedFile(message)
    }
}
