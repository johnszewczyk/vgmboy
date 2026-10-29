import Foundation
import PlaybackQueueCore
import PlaybackTransportCore
import VGMBoyKit

/// CocoaSpice's playlist-facing wrapper around the bundled VGMBoyKit core.
/// Queue ownership remains here; decoded audio, timing, EQ, and transport do not.
final class PlaybackEngine: @unchecked Sendable {
    private let transport = PlaybackTransportCoordinator(label: "CocoaSpice.vgmboy-playback")
    private let exportQueue = DispatchQueue(label: "CocoaSpice.vgmboy-export", qos: .utility)
    private let adapterState = PlaybackAdapterState()
    @MainActor private var playbackStateHandler: (@MainActor @Sendable (PlaybackStatusSnapshot) -> Void)?
    @MainActor private var playbackNaturalEndHandler: (@MainActor @Sendable (PlaybackStatusSnapshot) -> Void)?
    @MainActor private var latestDeliveredStatusSequence: UInt64 = 0

    /// This is a lock-backed snapshot because the adapter's async playback
    /// methods resume on a cooperative executor while transport callbacks are
    /// delivered on the main queue. It must not expose a TrackItem across
    /// those queues as an ordinary mutable stored property.
    private(set) var currentTrack: TrackItem? {
        get { adapterState.currentTrack }
        set { adapterState.currentTrack = newValue }
    }

    init() {
        // Transport status arrives on its own serial queue. TrackItem is UI
        // state and is replaced on the main queue; reading it here raced
        // replacement and produced a bad Swift URL/String access on Atari ST
        // activation. Keep this adapter's presentation handoff on main.
        transport.setStatusHandler { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Re-read after the queue handoff: an older queued status must
                // not overwrite a replacement session's presentation.
                let current = await self.transport.status()
                guard current.statusSequence >= self.latestDeliveredStatusSequence else { return }
                self.latestDeliveredStatusSequence = current.statusSequence
                self.publish(status: current)
            }
        }
        transport.setNaturalEndHandler { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                var current = await self.transport.status()
                // A newer ordinary status may reach the UI first. Refresh
                // rather than dropping the one-shot completion event.
                while current.statusSequence < self.latestDeliveredStatusSequence {
                    current = await self.transport.status()
                }
                guard Self.acceptsNaturalEnd(status, current: current) else { return }
                self.latestDeliveredStatusSequence = current.statusSequence
                self.playbackNaturalEndHandler?(PlaybackStatusSnapshot(status: current))
            }
        }
    }

    func setAppVolume(_ volume: Float) { transport.setAppVolume(AudioOutputVolume.clamped(volume)) }

    func setMonoEnabled(_ enabled: Bool) { transport.setMonoEnabled(enabled) }

    func setEqualizer(enabled: Bool, bandGains: [Float]) {
        transport.setEqualizer(enabled: enabled, bandGains: bandGains)
    }

    @MainActor func setPlaybackStateHandler(_ handler: (@MainActor @Sendable (PlaybackStatusSnapshot) -> Void)?) {
        playbackStateHandler = handler
    }

    @MainActor func setPlaybackNaturalEndHandler(_ handler: (@MainActor @Sendable (PlaybackStatusSnapshot) -> Void)?) {
        playbackNaturalEndHandler = handler
    }

    func reservePlaybackRequest() -> Int {
        transport.reservePlaybackRequest()
    }

    func play(track: TrackItem, plan: PlaybackPlan, tempo: PlaybackTempo, requestID: Int) async throws {
        // A replacement begins by retiring the previous native session. Archive
        // materialization can fail or take time; leaving the old session alive
        // made its elapsed clock continue beneath the newly selected row and
        // falsely looked like the new track had loaded. A failed request must
        // therefore be visibly stopped and surface its materialization error.
        guard await transport.stopForPlaybackRequest(requestID),
              transport.isCurrentPlaybackRequest(requestID) else { throw CancellationError() }
        currentTrack = nil
        let playableTrack = try transportTrack(for: track)
        try await transport.play(
            track: playableTrack,
            plan: plan,
            tempo: tempo,
            requestID: requestID
        )
        currentTrack = track
    }

    func reconfigureCurrentTrack(plan: PlaybackPlan, tempo: PlaybackTempo) async throws {
        try await transport.reconfigureCurrentTrack(plan: plan, tempo: tempo)
    }

    func setPlaying(_ shouldPlay: Bool) async -> Bool {
        await transport.setPlaying(shouldPlay)
    }

    func restoreOutputGain() async {
        await transport.restoreOutputGain()
    }

    func stopPlayback() async {
        await transport.stop()
        currentTrack = nil
    }

    func stop() async { await stopPlayback() }
    func beginFadedSkip(duration: TimeInterval) async -> Int? {
        await transport.beginFadedSkip(duration: duration)
    }

    func retireCompletedPlayback(
        state: PlaybackQueueState,
        playlistIDs: [String],
        repeatMode: PlaybackRepeatMode
    ) -> PlaybackContinuationDecision? {
        guard let decision = transport.retireCompletedPlayback(
            state: state,
            playlistIDs: playlistIDs,
            repeatMode: repeatMode
        ) else { return nil }
        currentTrack = nil
        return decision
    }

    func continueAfterCompletion(
        state: PlaybackQueueState,
        playlistIDs: [String],
        repeatMode: PlaybackRepeatMode,
        track: TrackItem,
        plan: PlaybackPlan,
        tempo: PlaybackTempo,
        requestID: Int
    ) async throws -> PlaybackContinuationDecision? {
        guard transport.isCurrentPlaybackRequest(requestID) else {
            throw CancellationError()
        }
        guard let decision = transport.retireCompletedPlayback(
            state: state,
            playlistIDs: playlistIDs,
            repeatMode: repeatMode
        ) else { return nil }

        // The core retires its previous source lease before replacement.
        currentTrack = nil
        guard case let .play(targetID) = decision.action, targetID == track.id else {
            return decision
        }

        let playableTrack = try transportTrack(for: track)
        let start = PlaybackContinuationStart(
            track: playableTrack,
            payload: PlaybackControlPayload(
                path: playableTrack.archivePath ?? playableTrack.path,
                archiveEntry: playableTrack.archiveEntry,
                trackIndex: track.trackIndex,
                tempo: tempo.multiplier,
                playbackMode: plan.isLongPlay ? .longPlay : .fileDefault,
                playMilliseconds: plan.isLongPlay ? plan.preFadeSeconds * 1_000 : nil,
                fadeMilliseconds: plan.fadeSeconds * 1_000,
                unknownDurationMilliseconds: plan.unknownDurationSeconds * 1_000,
                loop: playableTrack.loop
            ),
            requestID: requestID
        )
        try await transport.startContinuation(start)
        currentTrack = track
        return decision
    }

    private func transportTrack(for track: TrackItem) throws -> PlaybackTransportTrack {
        let loop = try ZipArchiveSupport.loopMetadata(for: track)
        let archiveEntry = track.archiveEntryPath
        return PlaybackTransportTrack(
            id: track.id,
            path: track.url.path,
            trackIndex: track.trackIndex,
            loop: loop,
            archivePath: archiveEntry == nil ? nil : track.url.path,
            archiveEntry: archiveEntry
        )
    }

    func isCurrentGeneration(_ generation: Int) async -> Bool {
        await transport.isCurrentGeneration(generation)
    }

    func statusSnapshot() async -> PlaybackStatusSnapshot {
        let status = await transport.status()
        return PlaybackStatusSnapshot(
            currentTrackID: status.currentTrackID,
            isPlaying: status.isPlaying,
            elapsedSeconds: status.elapsedSeconds,
            reachedEnd: status.reachedEnd
        )
    }

    func diagnosticsSnapshot() -> PlaybackDiagnosticsSnapshot {
        let diagnostics = transport.diagnostics()
        return PlaybackDiagnosticsSnapshot(
            decoderFamily: diagnostics.decoderFamily,
            decoderSampleRate: diagnostics.decoderSampleRate,
            decodedFrames: diagnostics.decodedFrames,
            audiblePositionFrames: diagnostics.audiblePositionFrames,
            tempo: diagnostics.tempo,
            bufferedFrames: diagnostics.bufferedFrames,
            ringBufferFrames: diagnostics.ringBufferFrames,
            underrunCount: diagnostics.underrunCount,
            clippedSampleCount: 0,
            sampleRate: diagnostics.sampleRate,
            outputHealth: diagnostics.outputIsRunning ? .running : .inactive
        )
    }
    func currentTrackID() async -> TrackItem.ID? { await transport.currentTrackID() }

    func seek(to seconds: TimeInterval) async throws {
        try await transport.seek(to: seconds)
    }

    /// CocoaSpice supplies archive/member identity and timing; VGMBoy prepares
    /// the source, decodes it, and writes the finite AAC output.
    func exportAAC(
        track: TrackItem,
        plan: PlaybackPlan,
        outputDirectory: URL,
        filenameStem: String,
        cancellation: AACExportCancellation,
        progress: @escaping @Sendable (AACExportProgress) -> Void
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            exportQueue.async {
                do {
                    let outputURL = try self.transport.exportAAC(
                        AACExportRequest(
                            sourcePath: track.url.path,
                            archiveEntry: track.archiveEntryPath,
                            trackIndex: track.trackIndex,
                            outputDirectory: outputDirectory,
                            filenameStem: filenameStem,
                            playMilliseconds: plan.preFadeSeconds * 1_000,
                            fadeMilliseconds: plan.fadeSeconds * 1_000
                        ),
                        cancellation: cancellation,
                        progress: progress
                    )
                    continuation.resume(returning: outputURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @MainActor private func publish(status: PlaybackTransportStatus) {
        playbackStateHandler?(PlaybackStatusSnapshot(status: status))
    }

    static func acceptsNaturalEnd(_ event: PlaybackTransportStatus, current: PlaybackTransportStatus) -> Bool {
        event.generation != 0 && event.generation == current.generation
            && event.currentTrackID != nil && event.currentTrackID == current.currentTrackID
            && current.trackLoaded && current.reachedEnd
    }
}

/// Thread-safe presentation identity retained only by CocoaSpice's adapter.
/// The shared transport already owns its own queue-confined string identity;
/// this protects the frontend-specific TrackItem snapshot from crossing the
/// async playback and callback queues unsafely.
final class PlaybackAdapterState: @unchecked Sendable {
    private let lock = NSLock()
    private var storedTrack: TrackItem?

    var currentTrack: TrackItem? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedTrack
        }
        set {
            lock.lock()
            storedTrack = newValue
            lock.unlock()
        }
    }
}

struct PlaybackStatusSnapshot: Sendable {
    let currentTrackID: TrackItem.ID?
    let isPlaying: Bool
    let elapsedSeconds: TimeInterval
    let reachedEnd: Bool

    init(currentTrackID: TrackItem.ID?, isPlaying: Bool, elapsedSeconds: TimeInterval, reachedEnd: Bool) {
        self.currentTrackID = currentTrackID
        self.isPlaying = isPlaying
        self.elapsedSeconds = elapsedSeconds
        self.reachedEnd = reachedEnd
    }

    init(status: PlaybackTransportStatus) {
        self.init(currentTrackID: status.currentTrackID, isPlaying: status.isPlaying,
                  elapsedSeconds: status.elapsedSeconds, reachedEnd: status.reachedEnd)
    }
}

/// Presentation constants for the unchanged CocoaSpice controls. Equalizer
/// processing itself is owned by VGMBoyKit.
enum AudioEqualizer {
    static let bandFrequencies = EqualizerConfiguration.bandFrequencies
    static let gainRange = EqualizerConfiguration.gainRange
    static func clampedGain(_ value: Float) -> Float { PlaybackPreferences.clampedEqualizerGain(value) }
}

enum AudioOutputVolume {
    static let range = PlaybackPreferences.volumeRange
    static func clamped(_ value: Float) -> Float { PlaybackPreferences.clampedVolume(value) }
}
