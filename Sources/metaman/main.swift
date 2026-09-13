import Foundation
import Darwin
import MetaManCore

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 2, arguments[0] == "read" else {
    fputs("Usage: metaman read <file>\n", stderr)
    exit(EXIT_FAILURE)
}

do {
    let document = try MetaManCore.read(fileURL: URL(fileURLWithPath: arguments[1]))
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    var output = try encoder.encode(document)
    output.append(0x0A)
    FileHandle.standardOutput.write(output)
} catch {
    fputs("metaman: \(error.localizedDescription)\n", stderr)
    exit(EXIT_FAILURE)
}
