import Foundation

/// Walks MDX's timed MML commands without synthesizing audio or invoking a
/// player. Durations are sequence-tick estimates using the default three-loop
/// stop policy for F1 loops and the format driver's default fade cadence.
enum MDXSequenceTimingReader {
    private static let maximumTicks = 5_000_000
    private static let maximumEventsPerTick = 65_536
    private static let maximumRepeatDepth = 1_024
    private static let maximumDurationMicroseconds: UInt64 = 1_200_000_000
    private static let defaultLoopLimit = 3
    private static let defaultLoopFadeTicks = 5

    struct Result {
        let timing: MetadataTiming?
        let tickCount: UInt64?
        let status: String
        let reason: String?
    }

    private struct RepeatFrame {
        var remaining: Int
    }

    private struct Track {
        let start: Int
        let end: Int
        var programCounter: Int
        var ticksRemaining = 1
        var repeatStack: [RepeatFrame] = []
        var infiniteLoopCount = 0
        var waitingForSync = false
        var ended = false
    }

    private enum AnalysisError: Error {
        case unavailable(String)
    }

    static func analyze(data: Data, headerOffset: Int) -> Result {
        let bytes = data
        guard headerOffset >= 0, headerOffset <= bytes.count - 4 else {
            return unavailable("the binary offset table is truncated")
        }
        if looksLikeLZXBody(bytes, offset: headerOffset) {
            return unavailable("the MML body is X68000 LZX-compressed and MetaMan does not expand that codec")
        }

        do {
            let timing = try measure(bytes: bytes, headerOffset: headerOffset)
            return Result(
                timing: timing.timing,
                tickCount: timing.tickCount,
                status: "available",
                reason: nil
            )
        } catch AnalysisError.unavailable(let reason) {
            return unavailable(reason)
        } catch {
            return unavailable("the sequence could not be interpreted safely")
        }
    }

    private static func measure(bytes: Data, headerOffset: Int) throws -> (timing: MetadataTiming, tickCount: UInt64) {
        let voiceOffset = Int(readBigEndianUInt16(bytes, at: headerOffset))
        let firstSequenceOffset = Int(readBigEndianUInt16(bytes, at: headerOffset + 2))
        let firstSequence = headerOffset + firstSequenceOffset
        guard firstSequence >= headerOffset, firstSequence < bytes.count else {
            throw AnalysisError.unavailable("the first MML offset points outside the file")
        }

        let trackCount = bytes[firstSequence] == 0xE8 ? 16 : 9
        let offsetTableLength = 2 + trackCount * 2
        guard headerOffset <= bytes.count - offsetTableLength else {
            throw AnalysisError.unavailable("the MML offset table is truncated")
        }
        let voiceData = headerOffset + voiceOffset
        guard voiceData >= headerOffset + offsetTableLength,
              voiceData <= bytes.count - 27 else {
            throw AnalysisError.unavailable("the voice-data offset is outside the MDX body")
        }

        var sequenceOffsets: [Int] = []
        sequenceOffsets.reserveCapacity(trackCount)
        for index in 0..<trackCount {
            let relativeOffset = Int(readBigEndianUInt16(bytes, at: headerOffset + 2 + index * 2))
            let absoluteOffset = headerOffset + relativeOffset
            guard absoluteOffset >= headerOffset + offsetTableLength,
                  absoluteOffset < bytes.count else {
                throw AnalysisError.unavailable("MML track \(index) points outside the sequence body")
            }
            sequenceOffsets.append(absoluteOffset)
        }

        var tracks: [Track] = []
        tracks.reserveCapacity(trackCount)
        for offset in sequenceOffsets {
            let upperBound = sequenceOffsets.filter { $0 > offset }.min() ?? bytes.count
            guard upperBound > offset else {
                throw AnalysisError.unavailable("an MML track has an empty byte range")
            }
            tracks.append(Track(start: offset, end: upperBound, programCounter: offset))
        }

        var tempo = 200
        var elapsedMicroseconds: UInt64 = 0
        var fadeSpeed = 0
        var fadeWait = 0
        var masterVolume = 127
        var tickCount: UInt64 = 0
        var finished = false

        for _ in 0..<maximumTicks {
            if fadeSpeed > 0 {
                if fadeWait == 0 { fadeWait = fadeSpeed }
                fadeWait -= 1
                if fadeWait == 0 { masterVolume -= 1 }
                if masterVolume <= 0 {
                    finished = true
                    break
                }
            }

            var anyTrackRan = false
            var minimumInfiniteLoops = Int.max
            for trackIndex in tracks.indices {
                if tracks[trackIndex].waitingForSync || tracks[trackIndex].ended { continue }
                anyTrackRan = true
                let result = try advance(
                    trackIndex: trackIndex,
                    tracks: &tracks,
                    bytes: bytes,
                    tempo: &tempo,
                    fadeSpeed: &fadeSpeed
                )
                if !result.ended, !result.waiting {
                    minimumInfiniteLoops = min(minimumInfiniteLoops, tracks[trackIndex].infiniteLoopCount)
                }
            }

            guard anyTrackRan else {
                finished = true
                break
            }
            guard tracks.contains(where: { !$0.ended && !$0.waitingForSync }) else {
                finished = true
                break
            }
            if minimumInfiniteLoops >= defaultLoopLimit {
                fadeSpeed = defaultLoopFadeTicks
            }

            let tickMicroseconds = UInt64(256 * (256 - tempo))
            guard tickMicroseconds > 0,
                  elapsedMicroseconds <= maximumDurationMicroseconds - tickMicroseconds else {
                throw AnalysisError.unavailable("sequence exceeds the 1,200-second timing bound")
            }
            elapsedMicroseconds += tickMicroseconds
            tickCount += 1
        }

        guard finished else {
            throw AnalysisError.unavailable("sequence exceeds the bounded timing walk")
        }
        guard tickCount > 0 else {
            throw AnalysisError.unavailable("the MML tracks do not contain measurable timed events")
        }
        guard elapsedMicroseconds < maximumDurationMicroseconds else {
            throw AnalysisError.unavailable("sequence exceeds the 1,200-second timing bound")
        }

        let milliseconds = Int((elapsedMicroseconds + 500) / 1_000)
        return (
            MetadataTiming(
                introLengthMs: milliseconds,
                loopLengthMs: 0,
                playLengthMs: milliseconds,
                fadeLengthMs: 0
            ),
            tickCount
        )
    }

    private static func advance(
        trackIndex: Int,
        tracks: inout [Track],
        bytes: Data,
        tempo: inout Int,
        fadeSpeed: inout Int
    ) throws -> (ended: Bool, waiting: Bool) {
        var ticks = tracks[trackIndex].ticksRemaining - 1
        var eventCount = 0
        while ticks == 0 {
            eventCount += 1
            guard eventCount <= maximumEventsPerTick else {
                throw AnalysisError.unavailable("track \(trackIndex) has an unbounded zero-time command loop")
            }
            let track = tracks[trackIndex]
            let commandOffset = track.programCounter
            guard commandOffset >= track.start, commandOffset < track.end else {
                throw AnalysisError.unavailable("track \(trackIndex) leaves its bounded MML range")
            }
            let command = bytes[commandOffset]

            if command <= 0x7F {
                ticks = Int(command) + 1
                tracks[trackIndex].programCounter += 1
            } else if command <= 0xDF {
                try requireBytes(2, at: commandOffset, track: tracks[trackIndex])
                ticks = Int(bytes[commandOffset + 1]) + 1
                tracks[trackIndex].programCounter += 2
            } else {
                let operandCount = try operandCount(
                    for: command,
                    at: commandOffset,
                    trackIndex: trackIndex,
                    track: tracks[trackIndex],
                    bytes: bytes
                )
                try requireBytes(1 + operandCount, at: commandOffset, track: tracks[trackIndex])
                let first = operandCount > 0 ? Int(bytes[commandOffset + 1]) : 0
                let second = operandCount > 1 ? Int(bytes[commandOffset + 2]) : 0

                switch command {
                case 0xFF: // Set tempo.
                    if first >= 2 { tempo = first }
                    tracks[trackIndex].programCounter += 2
                case 0xFE: // OPM register write; register 0x12 also sets tempo.
                    if first == 0x12, second >= 2 { tempo = second }
                    tracks[trackIndex].programCounter += 3
                case 0xF6: // Begin counted repeat.
                    guard first > 0 else {
                        throw AnalysisError.unavailable("track \(trackIndex) uses a zero-count repeat")
                    }
                    guard tracks[trackIndex].repeatStack.count < maximumRepeatDepth else {
                        throw AnalysisError.unavailable("track \(trackIndex) exceeds the repeat nesting bound")
                    }
                    tracks[trackIndex].repeatStack.append(RepeatFrame(remaining: first))
                    tracks[trackIndex].programCounter += 3
                case 0xF5: // End counted repeat.
                    guard !tracks[trackIndex].repeatStack.isEmpty else {
                        throw AnalysisError.unavailable("track \(trackIndex) ends a repeat that was never opened")
                    }
                    let remaining = tracks[trackIndex].repeatStack[tracks[trackIndex].repeatStack.count - 1].remaining - 1
                    if remaining == 0 {
                        tracks[trackIndex].repeatStack.removeLast()
                        tracks[trackIndex].programCounter += 3
                    } else {
                        tracks[trackIndex].repeatStack[tracks[trackIndex].repeatStack.count - 1].remaining = remaining
                        tracks[trackIndex].programCounter = try relativeTarget(
                            commandOffset: commandOffset,
                            rawOffset: first << 8 | second,
                            extra: 3,
                            track: tracks[trackIndex]
                        )
                    }
                case 0xF4: // Break out of the current repeat on its final pass.
                    guard !tracks[trackIndex].repeatStack.isEmpty else {
                        throw AnalysisError.unavailable("track \(trackIndex) breaks a repeat that was never opened")
                    }
                    if tracks[trackIndex].repeatStack.last?.remaining == 1 {
                        tracks[trackIndex].repeatStack.removeLast()
                        tracks[trackIndex].programCounter = try relativeTarget(
                            commandOffset: commandOffset,
                            rawOffset: first << 8 | second,
                            extra: 5,
                            track: tracks[trackIndex]
                        )
                    } else {
                        tracks[trackIndex].programCounter += 3
                    }
                case 0xF1: // End a track or branch to its F1 loop point.
                    if first == 0, second == 0 {
                        tracks[trackIndex].ended = true
                        tracks[trackIndex].ticksRemaining = -1
                        return (true, false)
                    }
                    tracks[trackIndex].infiniteLoopCount += 1
                    tracks[trackIndex].programCounter = try relativeTarget(
                        commandOffset: commandOffset,
                        rawOffset: first << 8 | second,
                        extra: 3,
                        track: tracks[trackIndex]
                    )
                case 0xEF: // Release a track waiting on this sync index.
                    guard first < tracks.count else {
                        throw AnalysisError.unavailable("track \(trackIndex) sends sync to missing track \(first)")
                    }
                    tracks[first].waitingForSync = false
                    tracks[trackIndex].programCounter += 2
                case 0xEE: // Wait for another track's sync event.
                    tracks[trackIndex].waitingForSync = true
                    tracks[trackIndex].ticksRemaining = 1
                    return (false, true)
                case 0xE7: // Native fade command. It changes amplitude, not score timing.
                    fadeSpeed = first == 0 ? 6 : second + 1
                    tracks[trackIndex].programCounter += 1 + operandCount
                case 0xFD, 0xFC, 0xFB, 0xFA, 0xF9, 0xF8, 0xF7,
                     0xF3, 0xF2, 0xF0, 0xED, 0xEC, 0xEB, 0xEA, 0xE9, 0xE8:
                    tracks[trackIndex].programCounter += 1 + operandCount
                default:
                    throw AnalysisError.unavailable(String(format: "track %d contains unsupported MML command 0x%02X", trackIndex, command))
                }
            }
        }

        tracks[trackIndex].ticksRemaining = ticks
        return (tracks[trackIndex].ended, tracks[trackIndex].waitingForSync)
    }

    private static func operandCount(
        for command: UInt8,
        at offset: Int,
        trackIndex: Int,
        track: Track,
        bytes: Data
    ) throws -> Int {
        switch command {
        case 0xFF, 0xFD, 0xFC, 0xFB, 0xF8, 0xF0, 0xEF, 0xED, 0xE9:
            return 1
        case 0xFE, 0xF6, 0xF5, 0xF4, 0xF3, 0xF2, 0xF1:
            return 2
        case 0xFA, 0xF9, 0xF7, 0xEE, 0xE8:
            return 0
        case 0xEC, 0xEB, 0xEA:
            guard offset + 1 < track.end else {
                throw AnalysisError.unavailable("track MML command is truncated")
            }
            return bytes[offset + 1] == 0x80 || bytes[offset + 1] == 0x81 ? 1 : 5
        case 0xE7:
            guard offset + 1 < track.end else {
                throw AnalysisError.unavailable("track MML fade command is truncated")
            }
            return bytes[offset + 1] == 0 ? 1 : 2
        default:
            throw AnalysisError.unavailable(String(format: "track %d contains unsupported MML command 0x%02X", trackIndex, command))
        }
    }

    private static func requireBytes(_ count: Int, at offset: Int, track: Track) throws {
        guard count > 0, offset >= track.start, offset <= track.end - count else {
            throw AnalysisError.unavailable("track MML command is truncated or crosses its track boundary")
        }
    }

    private static func relativeTarget(commandOffset: Int, rawOffset: Int, extra: Int, track: Track) throws -> Int {
        let signedOffset = Int(Int16(bitPattern: UInt16(rawOffset)))
        let target = commandOffset + signedOffset + extra
        guard target >= track.start, target < track.end else {
            throw AnalysisError.unavailable("track loop target leaves its bounded MML range")
        }
        return target
    }

    private static func readBigEndianUInt16(_ bytes: Data, at offset: Int) -> UInt16 {
        UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
    }

    private static func looksLikeLZXBody(_ bytes: Data, offset: Int) -> Bool {
        guard offset >= 0, offset <= bytes.count - 12 else { return false }
        return bytes[offset] == 0x60
            && bytes[offset + 1] == 0x26
            && bytes[offset + 2] == 0x60
            && (bytes[offset + 3] == 0x32 || bytes[offset + 3] == 0x4A)
            && bytes[offset + 4] == 0x4C
            && bytes[offset + 5] == 0x5A
            && bytes[offset + 6] == 0x58
            && bytes[offset + 7] == 0x20
            && bytes[offset + 8] == 0x30
            && bytes[offset + 9] == 0x2E
            && (bytes[offset + 10] == 0x33 || bytes[offset + 10] == 0x34)
            && (0x30...0x39).contains(bytes[offset + 11])
    }

    private static func unavailable(_ reason: String) -> Result {
        Result(timing: nil, tickCount: nil, status: "unavailable", reason: reason)
    }
}
