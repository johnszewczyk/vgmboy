const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const playbackSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/app-playback.js"),
  "utf8"
);
const appCoreSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/app-core.js"),
  "utf8"
);
const uiSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/app-ui.js"),
  "utf8"
);
const playlistTableSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/playlist-table-utils.js"),
  "utf8"
);
const databaseViewSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/database-view-utils.js"),
  "utf8"
);
const playlistColumnsSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/playlist-columns.js"),
  "utf8"
);
const playlistRowsSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/playlist-rows.js"),
  "utf8"
);
const appearanceViewSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/appearance-view.js"),
  "utf8"
);
const indexSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/index.html"),
  "utf8"
);
const stylesSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/styles.css"),
  "utf8"
);
const nativeBridgeSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/WKNativeBridge.swift"),
  "utf8"
);
const playbackBridgeSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/WKPlaybackBridge.swift"),
  "utf8"
);
const statusPayloadSource = fs.readFileSync(
  path.resolve(__dirname, "../../FrontendCore/Sources/PlaybackTransportCore/PlaybackTransportStatusPayload.swift"),
  "utf8"
);
const appDelegateSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/main.swift"),
  "utf8"
);

function element() {
  return {
    className: "",
    classList: { add() {}, remove() {} },
    style: { setProperty() {} },
    textContent: "",
    value: "",
    querySelector() { return { setAttribute() {} }; }
  };
}

function snapshot(generation, transportState = "playing") {
  return {
    transport_state: transportState,
    output_state: transportState === "playing" ? "running" : "idle",
    generation,
    status_sequence: 0,
    track_loaded: true,
    decode_error: false,
    reached_end: false,
    buffered_frames: 1024,
    ring_buffer_frames: 88200,
    underrun_count: 0,
    frames_requested: 2048,
    frames_supplied: 2048,
    decoder_family: "standard-audio",
    decoder_sample_rate: 44100,
    output_sample_rate: 44100,
    decoded_frames: 2048,
    audible_position_frames: 1024,
    tempo: 1,
    position_ms: 1000,
    error: null
  };
}

function makeHarness() {
  const track = {
    id: "track-a",
    title: "Fixture",
    path: "/tmp/fixture.flac",
    sourceFilename: "fixture.flac",
    basePlaybackSeconds: 4
  };
  const state = {
    appVolume: 1,
    equalizerEnabled: false,
    equalizerBandGains: [],
    longPlayEnabled: false,
    manualPlayTimeSeconds: 180,
    unknownDurationSeconds: 150,
    spcFadeSeconds: 6,
    fadeEnabled: true,
    queuedSkipsEnabled: true,
    playlist: [track],
    currentTrackId: null,
    currentTrackInfo: null,
    selectedTrackId: null,
    isPlaying: false,
    elapsedSeconds: 0,
    totalSeconds: 0,
    repeatMode: "off",
    nativePlayback: {
      transportState: "stopped",
      outputState: "idle",
      generation: 0,
      statusSequence: 0,
      trackLoaded: false,
      decodeError: false,
      reachedEnd: false,
      bufferedFrames: 0,
      ringBufferFrames: 0,
      underrunCount: 0,
      framesRequested: 0,
      framesSupplied: 0,
      decoderFamily: "",
      decoderSampleRate: 0,
      outputSampleRate: 0,
      decodedFrames: 0,
      audiblePositionFrames: 0,
      tempo: 1,
      positionMs: 0
    }
  };
  const refs = {
    elapsedLabel: element(),
    songLengthLabel: element(),
    playlistTotalLabel: element(),
    progressSlider: element(),
    progressSliderShell: element(),
    playButton: element(),
    spcLengthInput: element(),
    spcUnknownDurationInput: element(),
    spcFadeInput: element(),
    uiItemSpacingInput: element(),
    spcForceLengthCheckbox: element(),
    queuedSkipsCheckbox: element(),
    spcFadeCheckbox: element(),
    sidebarFontSizeInput: element(),
    playlistFontSizeInput: element(),
    sidebarWidthInput: element(),
    nativeTransportLabel: element(),
    nativeTrackLabel: element(),
    nativeOutputLabel: element(),
    nativePositionLabel: element(),
    nativeBufferLabel: element(),
    nativeBufferFillLabel: element(),
    nativeUnderrunLabel: element(),
    nativeFramesLabel: element(),
    nativeDecoderLabel: element(),
    nativeRatesLabel: element(),
    nativeDecodedLabel: element(),
    nativeTempoLabel: element(),
    nativeDecodeLabel: element()
  };
  const gainCalls = [];
  const startRequests = [];
  const reconfigureRequests = [];
  const queueTransitionRequests = [];
  let timerID = 0;
  let clockNow = 1000;
  let animationFrameID = 0;
  const animationFrames = new Map();
  const window = {
    setTimeout(callback, duration) {
      const id = ++timerID;
      if (duration <= 100) queueMicrotask(callback);
      return id;
    },
    clearTimeout() {},
    performance: { now: () => clockNow },
    requestAnimationFrame(callback) {
      const id = ++animationFrameID;
      animationFrames.set(id, callback);
      return id;
    },
    cancelAnimationFrame(id) {
      animationFrames.delete(id);
    },
    SPCBoyApp: null,
    SPCBoyPlaybackBackends: { forPath() { return { supportsLongPlay: false }; } },
    spcBoyWK: {
      nativePlaybackInit: async () => snapshot(0, "stopped"),
      nativePlaybackAudioConfig: async () => snapshot(0, "stopped"),
      nativePlaybackTiming: async (request) => ({
        pre_fade_seconds: request.longPlayEnabled ? request.manualPlayMilliseconds / 1000 : 4,
        fade_seconds: request.fadeMilliseconds / 1000,
        total_seconds: request.longPlayEnabled
          ? request.manualPlayMilliseconds / 1000 + request.fadeMilliseconds / 1000
          : 4 + request.fadeMilliseconds / 1000,
        is_long_play: Boolean(request.longPlayEnabled),
        uses_native_ending: !request.longPlayEnabled
      }),
      nativePlaybackStart: async (request) => {
        startRequests.push(request);
        return snapshot(7);
      },
      nativePlaybackReconfigure: async (request) => {
        reconfigureRequests.push(request);
        return snapshot(8);
      },
      nativePlaybackState: async () => snapshot(state.nativePlayback.generation || 7),
      nativePlaybackUnload: async () => snapshot(state.nativePlayback.generation, "stopped"),
      nativePlaybackRampGain: async (gain) => { gainCalls.push(gain); return snapshot(7); },
      playbackQueueTransition: async (request) => {
        queueTransitionRequests.push(request);
        return null;
      },
      playbackCompletionRetire: async () => ({ action: "stop" }),
      playbackFadeDuration: async () => 6_000,
      setPlaybackPowerSaveBlocker: async () => {},
    }
  };
  const app = {
    state,
    refs,
    formatTime: (seconds) => String(Math.round(seconds)),
    currentFadeSeconds: () => state.fadeEnabled ? state.spcFadeSeconds : 0,
    targetPlaybackSeconds: () => state.unknownDurationSeconds,
    currentTrack: () => track,
    selectedTrack: () => track,
    activeTrackInfo: () => state.currentTrackInfo,
    normalizeAppVolume: (value) => Number(value) || 1,
    normalizeEqualizerGain: (value) => Number(value) || 0,
    scalePlaybackMilliseconds: (value) => value,
    ui: { refreshPlaylistPlaybackState() {} }
  };
  window.SPCBoyApp = app;
  const context = {
    console,
    navigator: {},
    document: {},
    window,
    setTimeout: window.setTimeout,
    clearTimeout: window.clearTimeout,
    queueMicrotask
  };
  vm.runInNewContext(playbackSource, context, { filename: "app-playback.js" });
  return {
    app,
    gainCalls,
    startRequests,
    reconfigureRequests,
    queueTransitionRequests,
    window,
    flushAnimationFrame(elapsedMilliseconds = 500) {
      clockNow += elapsedMilliseconds;
      const pending = [...animationFrames.entries()];
      animationFrames.clear();
      pending.forEach(([, callback]) => callback(clockNow));
    }
  };
}

function loadPlaylistTable() {
  const window = {};
  vm.runInNewContext(playlistTableSource, { window }, { filename: "playlist-table-utils.js" });
  return window.SPCBoyPlaylistTable;
}

function loadDatabaseView() {
  const window = {};
  vm.runInNewContext(databaseViewSource, { window }, { filename: "database-view-utils.js" });
  return window.SPCBoyDatabaseView;
}

function loadAppearanceView() {
  const window = { SPCBoyPlaybackBackends: { conflicts: [] } };
  vm.runInNewContext(appearanceViewSource, { window }, { filename: "appearance-view.js" });
  return window.SPCBoyAppearanceView;
}

test("SPCBoyWK ignores stale native generations", () => {
  const { app } = makeHarness();
  const { state } = app;
  state.currentTrackId = "track-a";
  state.currentTrackInfo = state.playlist[0];
  state.selectedTrackId = "track-a";
  state.isPlaying = true;
  state.totalSeconds = 10;
  state.nativePlayback = {
    ...state.nativePlayback,
    ...{
      generation: 7,
      trackLoaded: true,
      transportState: "playing",
      outputState: "running"
    }
  };

  app.playback.handleNativePlaybackState(snapshot(8, "ended"));

  assert.equal(state.nativePlayback.generation, 7);
  assert.equal(state.currentTrackId, "track-a");
  assert.equal(state.isPlaying, true);
});

test("SPCBoyWK restores output when an adjacent fade is cancelled", async () => {
  const { app, gainCalls } = makeHarness();
  const { state } = app;
  await app.playback.playTrack("track-a");
  gainCalls.length = 0;

  await app.playback.playAdjacent(1);
  await app.playback.cancelQueuedSkip({ restoreOutput: true });

  assert.deepEqual(gainCalls, [0, 1]);
});

test("SPCBoyWK uses the native CocoaSpice timing plan for Long Play", async () => {
  const { app, startRequests } = makeHarness();
  app.state.longPlayEnabled = true;

  await app.playback.playTrack("track-a");

  assert.equal(app.state.totalSeconds, 186);
  assert.equal(startRequests.length, 1);
  assert.equal(startRequests[0].longPlayEnabled, true);
  assert.equal(startRequests[0].playMilliseconds, 180000);
});

test("SPCBoyWK reapplies Long Play to the loaded session", async () => {
  const { app, reconfigureRequests } = makeHarness();
  await app.playback.playTrack("track-a");
  app.state.longPlayEnabled = true;

  await app.playback.refreshPlaybackForTimingChange();

  assert.equal(reconfigureRequests.length, 1);
  assert.equal(reconfigureRequests[0].longPlayEnabled, true);
  assert.equal(reconfigureRequests[0].manualPlayMilliseconds, 180000);
  assert.equal(app.state.totalSeconds, 186);
});

test("SPCBoyWK drops a stale natural-end finalizer after replacement", async () => {
  const { app, window } = makeHarness();
  const { state } = app;
  state.playlist.push({
    id: "track-b",
    title: "Replacement",
    path: "/tmp/replacement.flac",
    sourceFilename: "replacement.flac",
    basePlaybackSeconds: 4
  });
  state.currentTrackId = "track-a";
  state.currentTrackInfo = state.playlist[0];
  state.selectedTrackId = "track-a";
  state.isPlaying = true;
  state.nativePlayback = { ...state.nativePlayback, generation: 7, trackLoaded: true };

  let releaseCompletionTarget;
  app.state.repeatMode = "off";
  // The production finalizer must validate its captured generation after the
  // queue lookup; the harness replaces the bridge method for that await.
  const completionTarget = new Promise((resolve) => { releaseCompletionTarget = resolve; });
  window.spcBoyWK.playbackCompletionRetire = async () => completionTarget;
  const finalizer = app.playback.finalizePlaybackEnded();
  state.currentTrackId = "track-b";
  state.currentTrackInfo = state.playlist[1];
  state.isPlaying = true;
  await app.playback.playTrack("track-b");
  releaseCompletionTarget(null);
  await finalizer;

  assert.equal(state.currentTrackId, "track-b");
  assert.equal(state.isPlaying, true);
});

test("SPCBoyWK advances after the completed session is retired", async () => {
  const { app, startRequests, window } = makeHarness();
  const { state } = app;
  state.playlist.push({
    id: "track-b",
    title: "Next Track",
    path: "/tmp/next.flac",
    sourceFilename: "next.flac",
    basePlaybackSeconds: 4
  });
  state.currentTrackId = "track-a";
  state.currentTrackInfo = state.playlist[0];
  state.selectedTrackId = "track-a";
  state.isPlaying = true;
  state.nativePlayback = { ...state.nativePlayback, generation: 7, trackLoaded: true };
  window.spcBoyWK.playbackCompletionRetire = async () => ({ action: "play", trackId: "track-b" });

  await app.playback.finalizePlaybackEnded();

  assert.equal(state.currentTrackId, "track-b");
  assert.equal(state.currentTrackInfo.id, "track-b");
  assert.equal(state.isPlaying, true);
  assert.equal(startRequests.length, 1);
  assert.equal(startRequests[0].path, "/tmp/next.flac");
});

test("SPCBoyWK sends typed queue state and adjacent intent to native", async () => {
  const { app, queueTransitionRequests, window } = makeHarness();
  app.state.playlist.push({
    id: "track-b",
    title: "Next Track",
    path: "/tmp/next.flac",
    sourceFilename: "next.flac",
    basePlaybackSeconds: 4
  });
  app.state.selectedTrackId = "track-a";
  window.spcBoyWK.playbackQueueTransition = async (request) => {
    queueTransitionRequests.push(request);
    return "track-b";
  };

  await app.playback.playAdjacent(1);

  assert.deepEqual(JSON.parse(JSON.stringify(queueTransitionRequests[0])), {
    state: {
      currentTrackId: null,
      selectedTrackId: "track-a",
      pendingTrackId: null
    },
    playlistIds: ["track-a", "track-b"],
    intent: { kind: "adjacent", direction: "next", wraps: true }
  });
});

test("SPCBoyWK finalizes from a matching native ended event", async () => {
  const { app, window } = makeHarness();
  const { state } = app;
  state.currentTrackId = "track-a";
  state.currentTrackInfo = state.playlist[0];
  state.selectedTrackId = "track-a";
  state.isPlaying = true;
  state.nativePlayback = { ...state.nativePlayback, generation: 7, trackLoaded: true };

  await app.playback.handleNativePlaybackEnded(snapshot(7, "ended"));

  assert.equal(state.currentTrackId, null);
  assert.equal(state.isPlaying, false);
});

test("SPCBoyWK renders native status events without a polling loop", () => {
  assert.doesNotMatch(playbackSource, /scheduleNativePlaybackStatePoll/);
  assert.doesNotMatch(playbackSource, /nativeStatePollTimer/);
  assert.match(playbackSource, /function handleNativePlaybackState\(snapshot\)/);
  assert.match(playbackSource, /function handleNativePlaybackEnded\(event\)/);
});

test("SPCBoyWK advances the visible clock between authoritative native events", () => {
  const { app, flushAnimationFrame } = makeHarness();
  const { state } = app;
  state.currentTrackId = "track-a";
  state.currentTrackInfo = state.playlist[0];
  state.totalSeconds = 10;
  state.nativePlayback = { ...state.nativePlayback, generation: 7, trackLoaded: true };

  app.playback.handleNativePlaybackState(snapshot(7, "playing"));
  assert.equal(state.elapsedSeconds, 1);
  flushAnimationFrame(500);

  assert.ok(state.elapsedSeconds > 1);
  assert.ok(state.elapsedSeconds <= 10);
});

test("SPCBoyWK does not roll the visible clock back on a low native snapshot", () => {
  const { app, flushAnimationFrame } = makeHarness();
  const { state } = app;
  state.currentTrackId = "track-a";
  state.currentTrackInfo = state.playlist[0];
  state.totalSeconds = 10;
  state.nativePlayback = { ...state.nativePlayback, generation: 7, trackLoaded: true };

  app.playback.handleNativePlaybackState(snapshot(7, "playing"));
  flushAnimationFrame(2_000);
  const beforeLowSnapshot = state.elapsedSeconds;

  const lowSnapshot = snapshot(7, "playing");
  lowSnapshot.position_ms = 0;
  app.playback.handleNativePlaybackState(lowSnapshot);

  assert.equal(state.elapsedSeconds, beforeLowSnapshot);
  flushAnimationFrame(500);
  assert.ok(state.elapsedSeconds > beforeLowSnapshot);
});

test("SPCBoyWK preserves an explicit zero Long Play duration as unbounded", async () => {
  const { app, startRequests } = makeHarness();
  app.state.longPlayEnabled = true;
  app.state.manualPlayTimeSeconds = 0;

  await app.playback.playTrack("track-a");

  assert.equal(app.state.totalSeconds, 0);
  assert.equal(startRequests[0].playMilliseconds, 0);
  assert.equal(app.state.isPlaying, true);
});

test("SPCBoyWK ignores delayed native status events", () => {
  const { app } = makeHarness();
  const { state } = app;
  state.currentTrackId = "track-a";
  state.currentTrackInfo = state.playlist[0];
  state.isPlaying = true;
  state.totalSeconds = 10;
  state.nativePlayback = {
    ...state.nativePlayback,
    generation: 7,
    statusSequence: 20,
    trackLoaded: true,
    transportState: "playing",
    outputState: "running"
  };

  const delayedPause = snapshot(7, "paused");
  delayedPause.status_sequence = 19;
  app.playback.handleNativePlaybackState(delayedPause);

  assert.equal(state.isPlaying, true);
  assert.equal(state.nativePlayback.statusSequence, 20);
});

test("SPCBoyWK uses one accent selection capsule for sidebar and playlist", () => {
  assert.match(stylesSource, /\.list-selection-indicator[\s\S]*?background: var\(--accent\)/);
  assert.match(stylesSource, /button:is\(\.tree-node, \.database-game-row, \.database-console-row\)\.is-selected[\s\S]*?background: transparent/);
  assert.match(stylesSource, /\.tree-node[\s\S]*?transition: color var\(--selection-animation-duration\)/);
  assert.match(stylesSource, /\.playlist-table td[\s\S]*?transition: width[\s\S]*?color var\(--selection-animation-duration\)/);
  assert.doesNotMatch(stylesSource, /button:not\([^\n]*\):is\([^\n]*\.is-selected/);
});

test("SPCBoyWK broadcasts complete native status to both windows", () => {
  assert.match(statusPayloadSource, /"status_sequence": statusSequence/);
  assert.match(statusPayloadSource, /"buffered_frames": bufferedFrames/);
  assert.match(statusPayloadSource, /"frames_requested": framesRequested/);
  assert.match(statusPayloadSource, /"decoder_family": decoderFamily/);
  assert.match(nativeBridgeSource, /PlaybackTransportStatusPayload\(/);
  assert.match(playbackBridgeSource, /PlaybackTransportStatusPayload\(/);
  assert.match(nativeBridgeSource, /if let onPlaybackEvent\s*\{\s*onPlaybackEvent\(name, payload\)/);
  assert.match(appDelegateSource, /broadcastPlaybackEvent\(name: name, payload: payload\)/);
  assert.match(appDelegateSource, /optionsWebView\?\.evaluateJavaScript\(script, completionHandler: nil\)/);
});

test("SPCBoyWK delegates completion retirement to the shared transport", () => {
  assert.doesNotMatch(nativeBridgeSource, /private let playbackContinuationCoordinator/);
  assert.match(nativeBridgeSource, /PlaybackContinuationRequest\(/);
  assert.match(nativeBridgeSource, /WKPlaybackBridge\.shared\.retireCompletedPlayback\(/);
  assert.match(playbackBridgeSource, /transport\.retireCompletedPlayback\(/);
  assert.match(playbackSource, /continueAfterPlaybackRetirement\(/);
  assert.match(nativeBridgeSource, /SPCArchiveMaterialization\.release\(\)/);
  assert.doesNotMatch(nativeBridgeSource, /releaseMaterializedTrack/);
  assert.doesNotMatch(playbackSource, /releaseMaterializedTrack/);
  assert.match(playbackBridgeSource, /nativePlaybackStop[\s\S]*defer \{ SPCArchiveMaterialization\.release\(\) \}/);
});

test("SPCBoyWK uses native in-place tempo and AAC cancellation events", () => {
  assert.match(playbackSource, /nativePlaybackSetTempo\(\{\s*tempo: playbackSpeedForTrack\(track\)/);
  assert.doesNotMatch(playbackSource, /async function refreshPlaybackForSpeedChange[\s\S]*refreshPlaybackForTimingChange\(\)/);
  assert.match(playbackSource, /function handleAACExportEvent\(event\)/);
  assert.match(playbackSource, /nativeCancelAACExport/);
  assert.match(nativeBridgeSource, /onNativeAACExport/);
  assert.match(nativeBridgeSource, /nativeExportAACCancel/);
  assert.match(playlistRowsSource, /\[\["Export AAC"/);
  assert.match(indexSource, /id="aac-export-directory-path"/);
  assert.match(indexSource, /id="aac-export-cancel-button"/);
  assert.match(indexSource, /id="aac-export-choose-button" class="tool-button glyph-button"[\s\S]*icon-folder-tree/);
});

test("SPCBoyWK keeps Audio and Playback option panels structurally separated", () => {
  const audioStart = indexSource.indexOf('id="options-audio-section"');
  const playbackStart = indexSource.indexOf('id="options-playback-section"');
  const diagnosticsStart = indexSource.indexOf('id="options-diagnostics-section"');
  const audioSource = indexSource.slice(audioStart, playbackStart);
  const playbackSource = indexSource.slice(playbackStart, diagnosticsStart);

  assert.ok(audioStart >= 0 && playbackStart > audioStart && diagnosticsStart > playbackStart);
  assert.match(audioSource, /AAC Export[\s\S]*Equalizer[\s\S]*Mono[\s\S]*Volume/);
  assert.doesNotMatch(audioSource, /End Fade|Play Time|Play Speed/);
  assert.match(playbackSource, /End Fade[\s\S]*Play Time[\s\S]*Play Speed/);
  assert.doesNotMatch(playbackSource, /AAC Export|Equalizer|Mono|options-page-title[^]*Volume/);
  assert.doesNotMatch(uiSource, /organizeOptionsPages/);
  assert.match(stylesSource, /\.options-page-audio,\s*\.options-windows-page,\s*\.options-routing-page\s*\{[\s\S]*padding:\s*0;[\s\S]*background:\s*transparent;/);
});

test("SPCBoyWK allows every playlist column to be hidden except an empty table", () => {
  assert.doesNotMatch(playlistColumnsSource, /checkbox\.disabled\s*=\s*column\.id\s*===\s*"filename"/);
  assert.match(playlistColumnsSource, /state\.columnVisibility\[column\.id\]\s*=\s*true/);
  assert.match(appCoreSource, /visibility\[DEFAULT_COLUMN_ORDER\[0\]\]\s*=\s*true/);
});

test("SPCBoyWK keeps playlist column state and DOM ownership in the column module", () => {
  assert.match(indexSource, /app-playback\.js[\s\S]*database-view-utils\.js[\s\S]*playlist-table-utils\.js[\s\S]*playlist-columns\.js[\s\S]*playlist-rows\.js[\s\S]*app-ui\.js/);
  assert.match(playlistColumnsSource, /function create\(\{/);
  assert.match(playlistColumnsSource, /function renderHeader\(\)/);
  assert.match(playlistColumnsSource, /function beginColumnResize\(/);
  assert.doesNotMatch(uiSource, /function beginColumnResize\(/);
});

test("SPCBoyWK keeps playlist row and virtualization state in the row module", () => {
  assert.match(playlistRowsSource, /function selectPlaylistTrack\(/);
  assert.match(playlistRowsSource, /function renderPlaylist\(/);
  assert.match(playlistRowsSource, /PLAYLIST_VIRTUALIZATION_THRESHOLD = 200/);
  assert.match(playlistRowsSource, /function schedulePlaylistViewportRender\(/);
  assert.match(uiSource, /return playlistRows\.renderPlaylist\(\{ sort \}\)/);
  assert.doesNotMatch(uiSource, /function appendPlaylistRowsInBatches\(/);
});

test("SPCBoyWK keeps appearance and routing presentation in its view module", () => {
  assert.match(indexSource, /playlist-rows\.js[\s\S]*appearance-view\.js[\s\S]*app-ui\.js/);
  assert.match(appearanceViewSource, /function applyUISettings\(/);
  assert.match(appearanceViewSource, /function appearanceSettings\(/);
  assert.match(appearanceViewSource, /function renderRoutingConflicts\(/);
  assert.match(uiSource, /return appearanceView\.applyUISettings\(\)/);
  assert.match(uiSource, /return appearanceView\.renderRoutingConflicts\(\)/);
  assert.doesNotMatch(uiSource, /rootStyle\.setProperty\("--ui-font-size-pt"/);

  const view = loadAppearanceView().create({
    state: {
      uiItemSpacingRem: 0.4,
      sidebarWidthPercent: 28,
      sidebarFontSizePt: 11,
      sidebarTextColor: "#111111",
      sidebarMonospace: true,
      sidebarPathCounts: false,
      playlistFontSizePt: 12,
      playlistTextColor: "#222222",
      playlistMonospace: false,
      applicationMonospace: true,
      playlistHeaderBold: true,
      accentColor: "#333333",
      archiveCacheLimitBytes: 2 * 1024 * 1024 * 1024
    },
    refs: {},
    escapeHtml: (value) => String(value),
    onSetRoutingPreference() {}
  });

  assert.equal(view.appearanceSettings().accentColor, "#333333");
  assert.equal(view.appearanceSettings().sidebarPathCounts, false);
  assert.equal(
    view.formatArchiveCacheSummary({ byteCount: 3 * 1024 * 1024, fileCount: 4, partialCount: 1 }),
    "3.0 MB • 4 files • 2 GB limit • 1 partial"
  );
});

test("SPCBoyWK exposes the catalog Dumper column", () => {
  assert.match(appCoreSource, /id: "dumper", label: "Dumper"/);
  assert.match(playlistTableSource, /track\.dumper \|\| "—"/);
  assert.match(playlistTableSource, /column\.id === "dumper"/);
});

test("SPCBoyWK playlist table utilities preserve Dumper, archive path, and length sort values", () => {
  const table = loadPlaylistTable();
  const track = {
    path: "/Volumes/Music/Library/Game.zip#song.spc",
    rootPath: "/Volumes/Music/Library",
    dumper: "Stored Dumper",
    basePlaybackSeconds: 42
  };

  assert.equal(table.valueForColumn(track, { id: "dumper" }), "Stored Dumper");
  assert.equal(table.valueForColumn({ ...track, dumper: "" }, { id: "dumper" }), "—");
  assert.equal(table.valueForColumn(track, { id: "path" }), "Library/Game.zip#song.spc");
  assert.equal(table.valueForColumn(track, { id: "index" }, 2), 3);
  assert.equal(table.sortValue(track, { id: "lengthLabel" }), 42);
});

test("SPCBoyWK filters database search locally without a debounce", () => {
  assert.match(uiSource, /function rebuildDatabaseGameSearchIndex\(games = state\.databaseGames\)/);
  assert.match(databaseViewSource, /terms\.every\(\(term\) => searchText\.includes\(term\)\)/);
  assert.match(uiSource, /state\.sidebarView = Object\.freeze\(sidebarView\(state\.sidebarMode, state\.sidebarQuery\)\)/);
  assert.doesNotMatch(uiSource, /sidebarSearchTimer/);
  assert.doesNotMatch(uiSource, /databaseSearchGames\(requestedQuery\)/);
  assert.doesNotMatch(uiSource, /databaseSearchGeneration/);
});

test("SPCBoyWK database view utilities preserve search and temporary-view semantics", () => {
  const view = loadDatabaseView();
  const games = [
    { name: "Silent Hill", system: "PSP", rootName: "JoshW" },
    { name: "Kirby", system: "SNES", rootName: "Local" }
  ];

  const records = view.searchRecords(games);
  assert.equal(view.filterSearchRecords(records, "silent psp", games)[0].name, "Silent Hill");
  assert.strictEqual(view.filterSearchRecords(records, "", games), games);
  assert.equal(view.sidebarView("paths", "").contentMode, "tree");
  assert.equal(view.sidebarView("consoles", "silent").view, "search");
  assert.equal(view.sidebarView("consoles", "silent").isTemporary, true);
});

test("SPCBoyWK catalog roots are foldable in Path View", () => {
  assert.doesNotMatch(nativeBridgeSource, /"alwaysExpanded": isRoot/);
});

test("SPCBoyWK Enter activates the focused playlist row without a selection fallback", () => {
  assert.match(
    uiSource,
    /const track = selectPlaylistTrack\(playlistRow\.dataset\.trackId, \{ focus: true \}\);/
  );
  assert.doesNotMatch(
    uiSource,
    /selectedTrack\(\)\s*\|\|\s*selectPlaylistTrack\(playlistRow\.dataset\.trackId\)/
  );
});
