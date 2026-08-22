import Foundation
import VGMBoyKit

struct Inspection: Codable {
    let title: String
    let game: String
    let system: String
    let artist: String
    let comment: String
    let introLengthMs: Int
    let loopLengthMs: Int
    let playLengthMs: Int
    let fadeLengthMs: Int
    let trackCount: Int
}

@main
struct VGMBoyHighlyCompleteInspect {
    static func main() {
        guard CommandLine.arguments.count == 2 else { fail("usage: vgmboy-highly-complete-inspect <file>") }
        do {
            let metadata = try VGMBoyHighlyCompleteInspector.inspect(path: CommandLine.arguments[1])
            let data = try JSONEncoder().encode(metadata)
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        } catch {
            fail(error.localizedDescription)
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("vgmboy-highly-complete-inspect: \(message)\n".utf8))
        exit(1)
    }
}
