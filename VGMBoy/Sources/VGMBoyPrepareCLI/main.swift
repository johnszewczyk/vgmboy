import Foundation
import VGMBoyArchiveCore

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

@main
enum VGMBoyPrepareCommand {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.count == 2 else {
            writeDiagnostic("usage: vgmboy-prepare <archive-path> <member-path>\n")
            exit(2)
        }

        let materializer = ArchiveMaterializer()
        do {
            let preparedURL = try materializer.materialize(
                archivePath: arguments[0],
                entry: arguments[1],
                requirement: .selectedEntry
            )
            defer { materializer.release() }

            let input = try FileHandle(forReadingFrom: preparedURL)
            defer { try? input.close() }

            while let bytes = try input.read(upToCount: 1_048_576), !bytes.isEmpty {
                try FileHandle.standardOutput.write(contentsOf: bytes)
            }
        } catch {
            writeDiagnostic("vgmboy-prepare: \(error.localizedDescription)\n")
            exit(1)
        }
    }

    private static func writeDiagnostic(_ message: String) {
        try? FileHandle.standardError.write(contentsOf: Data(message.utf8))
    }
}
