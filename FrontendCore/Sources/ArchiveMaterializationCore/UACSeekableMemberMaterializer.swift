import Foundation
import UACWrapperCore

/// Stages one manifest-selected UAC member without expanding sibling members.
enum UACSeekableMemberMaterializer {
    static func write(_ memberFile: UACSeekableMemberFile, to outputURL: URL) throws {
        guard memberFile.size > 0 else { throw ArchiveMaterializationError.emptyOutput }
        guard FileManager.default.createFile(
            atPath: outputURL.path,
            contents: nil,
            attributes: [.posixPermissions: 0o600]
        ) else {
            throw ArchiveMaterializationError.extractFailed("Could not create the selected UAC member file.")
        }
        let output = try FileHandle(forWritingTo: outputURL)
        defer { try? output.close() }

        let chunkSize: UInt64 = 1024 * 1024
        var offset: UInt64 = 0
        while offset < memberFile.size {
            let byteCount = Int(min(chunkSize, memberFile.size - offset))
            let chunk = try memberFile.read(at: offset, byteCount: byteCount)
            guard !chunk.isEmpty else {
                throw ArchiveMaterializationError.extractFailed("The selected UAC member ended before its declared size.")
            }
            try output.write(contentsOf: chunk)
            offset += UInt64(chunk.count)
        }
    }
}
