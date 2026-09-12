import Foundation
import VGMBoyCUADE

public struct VGMBoyAmigaTrackInspection: Codable, Sendable {
    public let index: Int
    public let title: String
    public let system: String
    public let player: String
    public let format: String
    public let lengthMs: Int

    public init(index: Int, title: String, system: String, player: String, format: String, lengthMs: Int) {
        self.index = index
        self.title = title
        self.system = system
        self.player = player
        self.format = format
        self.lengthMs = lengthMs
    }
}

public struct VGMBoyAmigaInspection: Codable, Sendable {
    public let trackCount: Int
    public let tracks: [VGMBoyAmigaTrackInspection]

    public init(path: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard let handle = path.withCString({
            vgmboy_uade_create($0, 44_100, &error)
        }) else {
            throw VGMBoyAmigaInspectionError.open(Self.takeError(&error))
        }
        defer { vgmboy_uade_destroy(handle) }

        let initialInfo = try Self.readInfo(handle: handle)
        guard initialInfo.minimum >= 0,
              initialInfo.maximum >= initialInfo.minimum,
              initialInfo.maximum - initialInfo.minimum <= 10_000 else {
            throw VGMBoyAmigaInspectionError.invalidSubsongRange
        }

        let count = Int(initialInfo.maximum - initialInfo.minimum + 1)
        var inspectedTracks: [VGMBoyAmigaTrackInspection] = []
        inspectedTracks.reserveCapacity(count)
        for index in 0..<count {
            let subsong = initialInfo.minimum + Int32(index)
            var selectError: UnsafeMutablePointer<CChar>?
            guard vgmboy_uade_select_subsong(handle, subsong, &selectError) == 0 else {
                throw VGMBoyAmigaInspectionError.select(Self.takeError(&selectError))
            }

            let info = try Self.readInfo(handle: handle)
            let moduleName = info.moduleName.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = moduleName.isEmpty || moduleName.hasPrefix("<no ")
                ? URL(fileURLWithPath: path).lastPathComponent
                : moduleName
            inspectedTracks.append(.init(
                index: index,
                title: title,
                system: "Commodore Amiga",
                player: info.playerName,
                format: info.formatName,
                lengthMs: info.durationMs
            ))
        }

        trackCount = inspectedTracks.count
        tracks = inspectedTracks
    }

    private struct Info {
        let moduleName: String
        let formatName: String
        let playerName: String
        let minimum: Int32
        let maximum: Int32
        let durationMs: Int
    }

    private static func readInfo(handle: vgmboy_uade_handle_t) throws -> Info {
        var moduleName = [CChar](repeating: 0, count: 1024)
        var formatName = [CChar](repeating: 0, count: 1024)
        var playerName = [CChar](repeating: 0, count: 1024)
        var minimum: Int32 = 0
        var defaultSubsong: Int32 = 0
        var maximum: Int32 = 0
        var durationMs: Int32 = 0
        var error: UnsafeMutablePointer<CChar>?
        let result = moduleName.withUnsafeMutableBufferPointer { moduleBuffer in
            formatName.withUnsafeMutableBufferPointer { formatBuffer in
                playerName.withUnsafeMutableBufferPointer { playerBuffer in
                    vgmboy_uade_read_metadata(
                        handle,
                        moduleBuffer.baseAddress,
                        moduleBuffer.count,
                        formatBuffer.baseAddress,
                        formatBuffer.count,
                        playerBuffer.baseAddress,
                        playerBuffer.count,
                        &minimum,
                        &defaultSubsong,
                        &maximum,
                        &durationMs,
                        &error
                    )
                }
            }
        }
        guard result == 0 else {
            throw VGMBoyAmigaInspectionError.metadata(Self.takeError(&error))
        }
        return Info(
            moduleName: Self.string(moduleName),
            formatName: Self.string(formatName),
            playerName: Self.string(playerName),
            minimum: minimum,
            maximum: maximum,
            durationMs: max(0, Int(durationMs))
        )
    }

    private static func string(_ buffer: [CChar]) -> String {
        String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private static func takeError(_ error: inout UnsafeMutablePointer<CChar>?) -> String {
        let message = error.map { String(cString: $0) } ?? "Unknown UADE error."
        if let pointer = error {
            vgmboy_uade_error_message_free(pointer)
            error = nil
        }
        return message
    }
}

public enum VGMBoyAmigaInspectionError: LocalizedError {
    case open(String)
    case metadata(String)
    case select(String)
    case invalidSubsongRange

    public var errorDescription: String? {
        switch self {
        case .open(let message):
            "UADE could not open the Amiga module: \(message)"
        case .metadata(let message):
            "UADE could not read Amiga module metadata: \(message)"
        case .select(let message):
            "UADE could not select the Amiga subsong: \(message)"
        case .invalidSubsongRange:
            "UADE returned an invalid subsong range."
        }
    }
}
