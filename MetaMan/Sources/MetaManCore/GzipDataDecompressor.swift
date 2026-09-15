import Foundation
import MetaManZlib

enum GzipDataDecompressor {
    static func matches(_ data: Data) -> Bool {
        data.count >= 2 && data[data.startIndex] == 0x1F && data[data.startIndex + 1] == 0x8B
    }

    static func decompress(_ data: Data, maximumOutputBytes: Int = 256 * 1_024 * 1_024) throws -> Data {
        var output: UnsafeMutablePointer<UInt8>?
        var outputSize = 0
        let status = data.withUnsafeBytes { rawBuffer -> Int32 in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            return Int32(metaman_gzip_decompress(
                bytes.baseAddress,
                bytes.count,
                maximumOutputBytes,
                &output,
                &outputSize
            ))
        }
        defer {
            if let output { metaman_gzip_free(output) }
        }

        switch status {
        case 0:
            guard let output else { return Data() }
            return Data(bytes: output, count: outputSize)
        case 2:
            throw MetadataReadError.malformedFile(
                "Compressed VGM exceeds the MetaMan safety limit of \(maximumOutputBytes) bytes."
            )
        case 3:
            throw MetadataReadError.malformedFile("MetaMan could not allocate memory to decompress the VGM file.")
        default:
            throw MetadataReadError.malformedFile("The compressed VGM is invalid or truncated.")
        }
    }
}
