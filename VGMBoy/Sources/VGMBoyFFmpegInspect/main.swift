import Foundation
import VGMBoyKit

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: vgmboy-ffmpeg-inspect <file>\n".utf8))
    exit(2)
}

do {
    let result = try VGMBoyFFmpegInspection(path: CommandLine.arguments[1])
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    FileHandle.standardOutput.write(try encoder.encode(result))
    FileHandle.standardOutput.write(Data("\n".utf8))
} catch {
    FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
    exit(1)
}
