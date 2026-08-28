import Foundation
import VGMBoyCPSGPlay

public struct SNDHTrackMetadata: Sendable, Equatable {
    public let index: Int
    public let title: String
    public let composer: String
    public let year: String
    public let subtuneName: String
    public let durationMilliseconds: Int

    public init(
        index: Int,
        title: String,
        composer: String,
        year: String,
        subtuneName: String,
        durationMilliseconds: Int
    ) {
        self.index = index
        self.title = title
        self.composer = composer
        self.year = year
        self.subtuneName = subtuneName
        self.durationMilliseconds = durationMilliseconds
    }
}

public struct SNDHMetadata: Sendable, Equatable {
    public let title: String
    public let composer: String
    public let year: String
    public let defaultTrack: Int
    public let tracks: [SNDHTrackMetadata]

    public init(
        title: String,
        composer: String,
        year: String,
        defaultTrack: Int,
        tracks: [SNDHTrackMetadata]
    ) {
        self.title = title
        self.composer = composer
        self.year = year
        self.defaultTrack = defaultTrack
        self.tracks = tracks
    }
}

public enum SNDHMetadataError: LocalizedError, Equatable {
    case readFailed(String)
    case invalidTrackCount

    public var errorDescription: String? {
        switch self {
        case .readFailed(let message):
            "SNDH metadata could not be read. \(message)"
        case .invalidTrackCount:
            "SNDH metadata declared an invalid subtune count."
        }
    }
}

public enum SNDHMetadataReader {
    private static let textCapacity = 1_024

    public static func read(fileURL: URL) throws -> SNDHMetadata {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        } catch {
            throw SNDHMetadataError.readFailed(error.localizedDescription)
        }
        return try read(data: data)
    }

    public static func read(data: Data) throws -> SNDHMetadata {
        var title = [CChar](repeating: 0, count: textCapacity)
        var composer = [CChar](repeating: 0, count: textCapacity)
        var year = [CChar](repeating: 0, count: textCapacity)
        var subtuneName = [CChar](repeating: 0, count: textCapacity)
        var trackCount: Int32 = 0
        var defaultTrack: Int32 = 0
        var durationMilliseconds: Int32 = 0
        var error: UnsafeMutablePointer<CChar>?

        let result = data.withUnsafeBytes { rawBuffer in
            title.withUnsafeMutableBufferPointer { titleBuffer in
                composer.withUnsafeMutableBufferPointer { composerBuffer in
                    year.withUnsafeMutableBufferPointer { yearBuffer in
                        subtuneName.withUnsafeMutableBufferPointer { subtuneNameBuffer in
                            vgmboy_psgplay_read_metadata(
                                rawBuffer.baseAddress,
                                data.count,
                                1,
                                titleBuffer.baseAddress,
                                titleBuffer.count,
                                composerBuffer.baseAddress,
                                composerBuffer.count,
                                yearBuffer.baseAddress,
                                yearBuffer.count,
                                subtuneNameBuffer.baseAddress,
                                subtuneNameBuffer.count,
                                &trackCount,
                                &defaultTrack,
                                &durationMilliseconds,
                                &error
                            )
                        }
                    }
                }
            }
        }
        if result != 0 {
            throw makeError(error)
        }

        let count = Int(trackCount)
        guard (1...10_000).contains(count) else {
            throw SNDHMetadataError.invalidTrackCount
        }
        let tracks = try (0..<count).map { index in
            try readTrack(
                data: data,
                index: index,
                title: string(title),
                composer: string(composer),
                year: string(year)
            )
        }
        return SNDHMetadata(
            title: string(title),
            composer: string(composer),
            year: string(year),
            defaultTrack: max(0, Int(defaultTrack) - 1),
            tracks: tracks
        )
    }

    private static func readTrack(
        data: Data,
        index: Int,
        title: String,
        composer: String,
        year: String
    ) throws -> SNDHTrackMetadata {
        var ignoredTitle = [CChar](repeating: 0, count: textCapacity)
        var ignoredComposer = [CChar](repeating: 0, count: textCapacity)
        var ignoredYear = [CChar](repeating: 0, count: textCapacity)
        var subtuneName = [CChar](repeating: 0, count: textCapacity)
        var trackCount: Int32 = 0
        var defaultTrack: Int32 = 0
        var durationMilliseconds: Int32 = 0
        var error: UnsafeMutablePointer<CChar>?
        let result = data.withUnsafeBytes { rawBuffer in
            ignoredTitle.withUnsafeMutableBufferPointer { titleBuffer in
                ignoredComposer.withUnsafeMutableBufferPointer { composerBuffer in
                    ignoredYear.withUnsafeMutableBufferPointer { yearBuffer in
                        subtuneName.withUnsafeMutableBufferPointer { subtuneNameBuffer in
                            vgmboy_psgplay_read_metadata(
                                rawBuffer.baseAddress,
                                data.count,
                                Int32(index + 1),
                                titleBuffer.baseAddress,
                                titleBuffer.count,
                                composerBuffer.baseAddress,
                                composerBuffer.count,
                                yearBuffer.baseAddress,
                                yearBuffer.count,
                                subtuneNameBuffer.baseAddress,
                                subtuneNameBuffer.count,
                                &trackCount,
                                &defaultTrack,
                                &durationMilliseconds,
                                &error
                            )
                        }
                    }
                }
            }
        }
        if result != 0 {
            throw makeError(error)
        }
        return SNDHTrackMetadata(
            index: index,
            title: title,
            composer: composer,
            year: year,
            subtuneName: string(subtuneName),
            durationMilliseconds: max(0, Int(durationMilliseconds))
        )
    }

    private static func makeError(_ pointer: UnsafeMutablePointer<CChar>?) -> SNDHMetadataError {
        defer { if let pointer { vgmboy_psgplay_error_message_free(pointer) } }
        let message = pointer.map { string($0) } ?? "Unknown PSG play error."
        return .readFailed(message)
    }

    private static func string(_ buffer: [CChar]) -> String {
        String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private static func string(_ pointer: UnsafeMutablePointer<CChar>) -> String {
        var bytes: [UInt8] = []
        var index = 0
        while pointer[index] != 0 {
            bytes.append(UInt8(bitPattern: pointer[index]))
            index += 1
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
