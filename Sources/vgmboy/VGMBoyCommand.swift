import Foundation
import VGMBoyKit

@main
struct VGMBoyCommand {
    static func main() {
        let arguments = CommandLine.arguments
        guard arguments.count >= 3 else {
            printUsage()
            exit(2)
        }
        let command = arguments[1]
        let path = arguments[2]
        switch command {
        case "inspect":
            inspect(path: path)
        case "play":
            play(path: path, options: Array(arguments.dropFirst(3)))
        default:
            FileHandle.standardError.write("Unknown command: \(command)\n".data(using: .utf8)!)
            printUsage()
            exit(2)
        }
    }

    private static func printUsage() {
        print("""
        vgmboy — game music audio core

        Usage:
          vgmboy inspect <path>                     Inspect routing, system, and per-track timing (JSON).
          vgmboy play <path> [options]              Play a file through the audio core.

        Play options:
          --track <n>       Zero-based track index (default 0).
          --long-play       Use a manual play window instead of the tagged length.
          --play-ms <n>     Long-play window in milliseconds (default 60000).
          --fade-ms <n>     Fade length in milliseconds (default 6000).
          --tempo <t>       Tempo multiplier, e.g. 0.5 or 2.0 (default 1.0).
        """)
    }

    private static func inspect(path: String) {
        do {
            let result = try AudioInspector.inspect(path: path)
            let family = FormatRegistry.family(for: path)
            struct Payload: Codable {
                var path: String
                var family: String?
                var supportsLongPlay: Bool?
                var supportsTempo: Bool?
                var system: String
                var trackCount: Int
                var tracks: [TrackMetadata]
            }
            let payload = Payload(
                path: path,
                family: family?.id,
                supportsLongPlay: family?.supportsLongPlay,
                supportsTempo: family?.supportsTempo,
                system: result.system,
                trackCount: result.trackCount,
                tracks: result.tracks
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write("\n".data(using: .utf8)!)
        } catch {
            FileHandle.standardError.write("inspect failed: \(error.localizedDescription)\n".data(using: .utf8)!)
            exit(1)
        }
    }

    private static func play(path: String, options: [String]) {
        var track = 0
        var longPlay = false
        var playMs = 60_000
        var fadeMs = 6_000
        var tempo = 1.0

        var index = 0
        while index < options.count {
            switch options[index] {
            case "--track":
                index += 1
                guard index < options.count, let value = Int(options[index]) else { fail("--track needs an integer") }
                track = value
            case "--long-play":
                longPlay = true
            case "--play-ms":
                index += 1
                guard index < options.count, let value = Int(options[index]) else { fail("--play-ms needs an integer") }
                playMs = value
            case "--fade-ms":
                index += 1
                guard index < options.count, let value = Int(options[index]) else { fail("--fade-ms needs an integer") }
                fadeMs = value
            case "--tempo":
                index += 1
                guard index < options.count, let value = Double(options[index]) else { fail("--tempo needs a number") }
                tempo = value
            default:
                fail("Unknown option: \(options[index])")
            }
            index += 1
        }

        guard let family = FormatRegistry.family(for: path) else {
            fail("Unsupported format: \(path)")
        }

        let inspection: TrackInspection
        do {
            inspection = try AudioInspector.inspect(path: path)
        } catch {
            fail("inspect failed: \(error.localizedDescription)")
        }
        guard track >= 0, track < inspection.trackCount else {
            fail("Track \(track) is out of range (0...\(inspection.trackCount - 1)).")
        }
        let metadata = inspection.tracks[track]
        let plan = TimingPolicy.plan(
            supportsLongPlay: family.supportsLongPlay,
            metadata: metadata,
            longPlayEnabled: longPlay,
            manualSeconds: max(1, playMs / 1000),
            fadeSeconds: max(0, fadeMs / 1000)
        )

        print("VGMBoy — \(inspection.system)")
        print("\(metadata.song.isEmpty ? "(untitled)" : metadata.song) by \(metadata.author.isEmpty ? "(unknown)" : metadata.author)")
        print("Track \(track + 1)/\(inspection.trackCount) — \(plan.preFadeSeconds)s + \(plan.fadeSeconds)s fade — \(plan.isLongPlay ? "Long Play" : (plan.usesNativeEnding ? "native ending" : "timed"))")

        let session = PlaybackSession()
        let done = DispatchSemaphore(value: 0)
        session.setCompletionHandler {
            done.signal()
        }
        do {
            _ = try session.load(path: path, trackIndex: track, plan: plan, tempo: tempo)
            try session.play()
        } catch {
            fail("playback failed: \(error.localizedDescription)")
        }

        // Keep the main run loop spinning so the completion dispatch on the
        // main queue can fire; AVAudioEngine renders on its own threads.
        while done.wait(timeout: .now()) == .timedOut {
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
        session.stop()
        print("Ended.")
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write("vgmboy: \(message)\n".data(using: .utf8)!)
        exit(1)
    }
}