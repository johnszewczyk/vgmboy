import Foundation
import VGMBoyKit

@main
struct VGMBoyCommand {
    static func main() {
        let arguments = CommandLine.arguments
        guard arguments.count >= 3, arguments[1] == "play" else {
            printUsage()
            exit(2)
        }
        let path = arguments[2]
        play(path: path, options: Array(arguments.dropFirst(3)))
    }

    private static func printUsage() {
        print("""
        vgmboy — game music audio core

        Usage:
          vgmboy-cli play <path> [options]            Play a file through the audio core.

        Play options:
          --track <n>       Zero-based track index (default 0).
          --long-play       Use a manual play window instead of the tagged length.
          --play-ms <n>     Long-play window in milliseconds (default 60000).
          --fade-ms <n>     Fade length in milliseconds (default 6000).
          --tempo <t>       Tempo multiplier, e.g. 0.5 or 2.0 (default 1.0).
        """)
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

        guard track >= 0 else { fail("--track must be non-negative") }
        let mode: PlaybackMode = longPlay && family.supportsLongPlay ? .longPlay : .fileDefault
        let controller = PlaybackController()
        let done = DispatchSemaphore(value: 0)
        _ = controller.subscribe { event in
            guard event.kind == .ended else { return }
            done.signal()
        }
        let loaded = controller.perform(.init(command: .load, payload: .init(
            path: path, trackIndex: track, tempo: tempo, playbackMode: mode,
            playMilliseconds: playMs, fadeMilliseconds: fadeMs
        )))
        if loaded.kind == .error { fail("playback failed: \(loaded.message ?? "unknown error")") }
        let started = controller.perform(.init(command: .play))
        if started.kind == .error { fail("playback failed: \(started.message ?? "unknown error")") }
        print("VGMBoy playback — track \(track + 1), \(mode == .longPlay ? "Long Play" : "file default")")

        // Keep the main run loop spinning so the completion dispatch on the
        // main queue can fire; the direct AudioUnit renders on its own thread.
        while done.wait(timeout: .now()) == .timedOut {
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
        _ = controller.perform(.init(command: .stop))
        print("Ended.")
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write("vgmboy: \(message)\n".data(using: .utf8)!)
        exit(1)
    }
}
