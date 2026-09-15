import Foundation
import Darwin
import MetaManCore

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 2, ["read", "read-tracks"].contains(arguments[0]) else {
    fputs("Usage: metaman read <file> | metaman read-tracks <file>\n", stderr)
    exit(EXIT_FAILURE)
}

do {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    var output: Data
    if arguments[0] == "read-tracks" {
        output = try encoder.encode(MetaManCore.readResult(fileURL: URL(fileURLWithPath: arguments[1])))
    } else {
        output = try encoder.encode(MetaManCore.read(fileURL: URL(fileURLWithPath: arguments[1])))
    }
    output.append(0x0A)
    FileHandle.standardOutput.write(output)
} catch {
    fputs("metaman: \(error.localizedDescription)\n", stderr)
    exit(EXIT_FAILURE)
}
