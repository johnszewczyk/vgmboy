const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const playbackSource = fs.readFileSync(
  process.env.SPCBOY_TEST_PLAYBACK_SOURCE || path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/app-playback.js"),
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
const preferencesSnapshotSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/SPCBoyPreferencesSnapshot.swift"),
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
// Consume CocoaSpice's canonical fixture directly; do not maintain a WK copy.
const activationContract = JSON.parse(fs.readFileSync(
  path.resolve(__dirname, "../../CocoaSpice/Tests/CocoaSpiceTests/cross-app-playlist-activation-v1.json"),
  "utf8"
));

function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((accept, fail) => { resolve = accept; reject = fail; });
  return { promise, resolve, reject };
}

function deferFirstBridgeReply(bridge, method, matches = () => true) {
  const entered = deferred();
  const release = deferred();
  const original = bridge[method];
  const calls = [];
  let blocked = false;
  bridge[method] = async (...args) => {
    calls.push(args);
    const result = await original(...args);
    if (!blocked && matches(...args)) {
      blocked = true;
      entered.resolve();
      await release.promise;
    }
    return result;
  };
  return { entered: entered.promise, release: release.resolve, calls };
}

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
  const timers = new Map();
  const window = {
    setTimeout(callback, duration) {
      const id = ++timerID;
      if (duration <= 100) queueMicrotask(callback);
      else timers.set(id, callback);
      return id;
    },
    clearTimeout(id) { timers.delete(id); },
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
      nativePlaybackSetTempo: async (request) => ({
        ...snapshot(7),
        tempo: Number(request?.tempo?.numerator) / Number(request?.tempo?.denominator)
      }),
      nativePlaybackState: async () => snapshot(state.nativePlayback.generation || 7),
      nativePlaybackPause: async () => snapshot(7, "paused"),
      nativePlaybackResume: async () => snapshot(7),
      nativePlaybackSeek: async (request) => ({ ...snapshot(7), position_ms: request.positionMilliseconds }),
      nativePlaybackUnload: async () => snapshot(state.nativePlayback.generation, "stopped"),
      nativePlaybackStop: async () => snapshot(state.nativePlayback.generation, "stopped"),
      nativePlaybackClose: async () => snapshot(state.nativePlayback.generation, "stopped"),
      nativePlaybackRampGain: async (request) => { gainCalls.push(request.outputGain); return snapshot(7); },
      playbackQueueAdjacent: async (request) => {
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
    currentTrack: () => state.currentTrackInfo,
    selectedTrack: () => state.playlist.find((entry) => entry.id === state.selectedTrackId),
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
    document: { addEventListener() {} },
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
    fireFirstTimer() {
      const [id, callback] = timers.entries().next().value;
      timers.delete(id);
      return callback();
    },
    loadUI() {
      app.persistSettings = () => {};
      state.selectedTrackIds = state.selectedTrackId ? [state.selectedTrackId] : [];
      vm.runInNewContext(fs.readFileSync(
        path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/playlist-controller.js"), "utf8"
      ), context, { filename: "playlist-controller.js" });
      vm.runInNewContext(uiSource, context, { filename: "app-ui.js" });
    },
    flushAnimationFrame(elapsedMilliseconds = 500) {
      clockNow += elapsedMilliseconds;
      const pending = [...animationFrames.entries()];
      animationFrames.clear();
      pending.forEach(([, callback]) => callback(clockNow));
    }
  };
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

test("SPCBoyWK ignores an older timing reply after a newer setting", async () => {
  const { app, window, reconfigureRequests } = makeHarness();
  await app.playback.playTrack("track-a");
  app.state.longPlayEnabled = true;
  const pending = deferFirstBridgeReply(window.spcBoyWK, "nativePlaybackTiming");

  const oldTiming = app.playback.refreshPlaybackForTimingChange();
  await pending.entered;
  app.state.manualPlayTimeSeconds = 240;
  await app.playback.refreshPlaybackForTimingChange();
  pending.release();
  await oldTiming;

  assert.equal(reconfigureRequests.length, 1);
  assert.equal(reconfigureRequests[0].manualPlayMilliseconds, 240_000);
  assert.equal(app.state.totalSeconds, 246);
});

test("SPCBoyWK drops a stale tempo reply after replacement", async () => {
  const { app, window } = makeHarness();
  app.state.playlist[0].path = "/tmp/fixture.spc";
  app.state.playlist[0].sourceFilename = "fixture.spc";
  app.state.playbackSpeedEnabled = true;
  app.state.playbackSpeed = { numerator: 3, denominator: 2 };
  window.SPCBoyPlaybackBackends.forPath = () => (
    { id: "libgme", playbackSpeedMode: "native-tempo", playbackSpeedExtensions: [".spc"] }
  );
  await app.playback.playTrack("track-a");
  app.state.playlist.push({ ...app.state.playlist[0], id: "track-b", path: "/tmp/replacement.flac" });
  const pending = deferFirstBridgeReply(window.spcBoyWK, "nativePlaybackSetTempo");

  const oldTempo = app.playback.refreshPlaybackForSpeedChange("libgme");
  await pending.entered;
  await app.playback.playTrack("track-b", 0, false, { replaceQueue: true });
  pending.release();
  await oldTempo;

  assert.equal(app.state.currentTrackId, "track-b");
  assert.equal(app.state.nativePlayback.generation, 7);
  assert.equal(app.state.nativePlayback.tempo, 1);
});

test("SPCBoyWK keeps only the newest tempo reply for the current track", async () => {
  const { app, window } = makeHarness();
  app.state.playlist[0].path = "/tmp/fixture.spc";
  app.state.playlist[0].sourceFilename = "fixture.spc";
  app.state.playbackSpeedEnabled = true;
  app.state.playbackSpeed = { numerator: 3, denominator: 2 };
  window.SPCBoyPlaybackBackends.forPath = () => (
    { id: "libgme", playbackSpeedMode: "native-tempo", playbackSpeedExtensions: [".spc"] }
  );
  await app.playback.playTrack("track-a");
  const pending = deferFirstBridgeReply(window.spcBoyWK, "nativePlaybackSetTempo");

  const oldTempo = app.playback.refreshPlaybackForSpeedChange("libgme");
  await pending.entered;
  app.state.playbackSpeed = { numerator: 2, denominator: 1 };
  await app.playback.refreshPlaybackForSpeedChange("libgme");
  pending.release();
  await oldTempo;

  assert.equal(app.state.nativePlayback.tempo, 2);
});

test("SPCBoyWK drops a stale natural-end finalizer after replacement", async () => {
  const { app, window, startRequests } = makeHarness();
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
  await app.playback.playTrack("track-b");
  releaseCompletionTarget({ action: "play", trackId: "track-a" });
  await finalizer;

  assert.equal(state.currentTrackId, "track-b");
  assert.equal(state.isPlaying, true);
  assert.deepEqual(startRequests.map((request) => request.path), ["/tmp/replacement.flac"]);
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

test("SPCBoyWK sends typed adjacent-navigation state to native", async () => {
  const { app, queueTransitionRequests, window } = makeHarness();
  app.state.playlist.push({
    id: "track-b",
    title: "Next Track",
    path: "/tmp/next.flac",
    sourceFilename: "next.flac",
    basePlaybackSeconds: 4
  });
  app.state.selectedTrackId = "track-a";
  window.spcBoyWK.playbackQueueAdjacent = async (request) => {
    queueTransitionRequests.push(request);
    return { trackId: "track-b" };
  };

  await app.playback.playAdjacent(1);

  assert.deepEqual(JSON.parse(JSON.stringify(queueTransitionRequests[0])), {
    state: {
      currentTrackId: null,
      selectedTrackId: "track-a",
      pendingTrackId: null
    },
    playlistIds: ["track-a", "track-b"],
    direction: "next",
    wraps: true
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

test("SPCBoyWK uses one accent selection capsule without recoloring selected text", () => {
  assert.match(stylesSource, /\.list-selection-indicator[\s\S]*?background: var\(--accent\)/);
  assert.match(stylesSource, /\.list-selection-indicator\.is-hidden\s*\{\s*transition: none;/);
  assert.match(stylesSource, /button:is\(\.tree-node, \.database-game-row, \.database-console-row\)\.is-selected\s*\{[^}]*background: transparent;[^}]*box-shadow: none;/);
  assert.doesNotMatch(stylesSource, /\.database-game-row\s*\{[^}]*transition:\s*color/);
  assert.doesNotMatch(stylesSource, /\.database-console-row\s*\{[^}]*transition:\s*color/);
  assert.doesNotMatch(stylesSource, /\.tree-node\s*\{[^}]*transition:\s*color/);
  assert.doesNotMatch(stylesSource, /\.playlist-table th,\s*\.playlist-table td\s*\{[^}]*transition:[^}]*color/);
  assert.doesNotMatch(stylesSource, /\.playlist-row\.is-selected > td[\s\S]*?\{[^}]*color:/);
  assert.doesNotMatch(stylesSource, /button:is\(\.tree-node, \.database-game-row, \.database-console-row\)\.is-selected\s*\{[^}]*color:/);
  assert.doesNotMatch(stylesSource, /button:not\([^\n]*\):is\([^\n]*\.is-selected/);
});

test("SPCBoyWK clears playlist selection when a sidebar source replaces the visible list", () => {
  assert.doesNotMatch(uiSource, /function resolveSelectedTrackId\(/);
  assert.doesNotMatch(appCoreSource, /lastSelectedTrackId/);
  assert.doesNotMatch(uiSource, /lastSelectedTrackId/);
  assert.doesNotMatch(preferencesSnapshotSource, /lastSelectedTrackId/);
  assert.match(uiSource, /function clearPlaylistSelection\(\)\s*\{[\s\S]*state\.selectedTrackId = null;[\s\S]*state\.selectedTrackIds = \[\];[\s\S]*state\.playlistSelectionAnchorId = null;[\s\S]*selectedPlaylistRow = null;/);
  assert.match(uiSource, /function positionSelectionIndicator\([\s\S]*?!target[\s\S]*?indicator\.classList\.add\("is-hidden"\)/);
  assert.match(uiSource, /async function showFavoritesPlaylist\(\)\s*\{[\s\S]*state\.playlist = \[\.\.\.state\.favorites\];[\s\S]*?clearPlaylistSelection\(\);/);
  assert.match(uiSource, /async function loadDatabaseGamesIntoPlaylist\(games\)\s*\{[\s\S]*state\.playlist = databaseRowsToPlaylistTracks\(rows\);[\s\S]*clearPlaylistSelection\(\);/);
  assert.match(uiSource, /function applyLibrarySnapshot\(snapshot\)\s*\{[\s\S]*clearPlaylistSelection\(\);/);
  assert.match(uiSource, /async function applyFolderSelection\(selection\)\s*\{[\s\S]*state\.playlist = selection\.playlist;[\s\S]*?clearPlaylistSelection\(\);/);
});

test("SPCBoyWK preserves shared catalog order until a user explicitly sorts", () => {
  assert.match(appCoreSource, /playlistSortEnabled: false/);
  assert.match(appCoreSource, /parsed\.playlistSortEnabled === true && savedSortColumn !== null/);
  assert.match(appCoreSource, /playlistSortEnabled: state\.playlistSortEnabled/);
  assert.doesNotMatch(uiSource, /function sortPlaylist\(/);
  assert.doesNotMatch(uiSource, /function playlistSortValue\(/);
  assert.match(uiSource, /async function applyCatalogPlaylistSort\(\)[\s\S]*window\.spcBoyWK\.databasePlaylistSort/);
  assert.match(uiSource, /async function applyProjectionPlaylistSort\(\)[\s\S]*window\.spcBoyWK\.playlistProjectionSort/);
  assert.match(uiSource, /function playlistSortRecords\(\)/);
  assert.match(uiSource, /const generation = \+\+catalogPlaylistSortGeneration;/);
  assert.match(uiSource, /const generation = \+\+projectionPlaylistSortGeneration;/);
  assert.match(uiSource, /generation !== catalogPlaylistSortGeneration/);
  assert.match(uiSource, /sessionId: state\.catalogPlaylistSortSessionId,[\s\S]*ids: originalIDs/);
  assert.doesNotMatch(uiSource, /function catalogPlaylistSortRecords\(/);
  assert.match(uiSource, /async function applyExplicitPlaylistSort\(\)[\s\S]*applyCatalogPlaylistSort\(\)/);
  assert.match(nativeBridgeSource, /databasePlaylistSort: \(\.\.\.args\) => request\("databasePlaylistSort", args\)/);
  assert.match(nativeBridgeSource, /playlistProjectionSort: \(\.\.\.args\) => request\("playlistProjectionSort", args\)/);
  assert.match(nativeBridgeSource, /case "databasePlaylistSort":[\s\S]*playlistSortedIDs\(args\.first\)/);
  assert.match(nativeBridgeSource, /case "playlistProjectionSort":[\s\S]*projectionPlaylistSortedIDs\(args\.first\)/);
  assert.match(nativeBridgeSource, /private final class CatalogPlaylistSortStore/);
  assert.doesNotMatch(nativeBridgeSource, /request\["records"\]/);
  assert.match(nativeBridgeSource, /CatalogPlaylistSortRequest\.self/);
  assert.match(nativeBridgeSource, /CatalogPlaylistSorting\.orderedIDs/);
  assert.match(uiSource, /state\.playlistSortEnabled = true;\s*state\.sortColumn = column\.id;/);
  assert.doesNotMatch(appCoreSource, /sortColumn: "filename"/);
  assert.match(preferencesSnapshotSource, /FrontendPlaylistColumnSchema/);
  assert.match(preferencesSnapshotSource, /normalizeForPersistence\(\)/);
  assert.doesNotMatch(appCoreSource, /function normalizeSortColumn\(/);
});

test("SPCBoyWK renders the shared catalog playlist presentation projection", () => {
  assert.match(nativeBridgeSource, /import CatalogPlaylistPresentationCore/);
  assert.match(nativeBridgeSource, /CatalogPlaylistPresentation\.project\([\s\S]*CatalogPlaylistReader\.tracksForGames/);
  assert.match(nativeBridgeSource, /CatalogPlaylistPresentation\.project\(tracks: tracks\)/);
  assert.equal((nativeBridgeSource.match(/private static func playlistTrackResponse\(/g) || []).length, 1);
  assert.match(nativeBridgeSource, /"columnContentHints": columnContentHintResponse\(projection\.columnContentHints\)/);
  assert.match(nativeBridgeSource, /"fileText": track\.display\.fileText/);
  assert.match(nativeBridgeSource, /"titleText": track\.display\.titleText/);
  assert.match(uiSource, /const rows = response\.rows;/);
  assert.match(uiSource, /state\.catalogPlaylistColumnContentHints = response\.columnContentHints;/);
  assert.match(uiSource, /const sharedHint = state\.catalogPlaylistColumnContentHints\?\.\[columnId\];/);
  assert.match(uiSource, /filename: row\.fileText,/);
  assert.match(uiSource, /title: row\.titleText,/);
  assert.match(uiSource, /lengthLabel: row\.lengthText,/);
  assert.match(nativeBridgeSource, /"sortSessionId": sortSessionID/);
  assert.match(uiSource, /state\.catalogPlaylistSortSessionId = response\.sortSessionId \|\| null;/);
  assert.doesNotMatch(uiSource, /function databaseRowsToPlaylistTracks\(rows\)[\s\S]*?row\.title \|\|/);
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
  assert.match(nativeBridgeSource, /JSONDecoder\(\)\.decode\(PlaybackContinuationRequest\.self, from: data\)/);
  assert.match(nativeBridgeSource, /PlaybackContinuationResponse\(decision: decision\)/);
  assert.match(nativeBridgeSource, /WKPlaybackBridge\.shared\.retireCompletedPlayback\(/);
  assert.match(playbackBridgeSource, /transport\.retireCompletedPlayback\(/);
  assert.match(playbackSource, /continueAfterPlaybackRetirement\(/);
  assert.match(nativeBridgeSource, /SPCArchiveMaterialization\.release\(\)/);
  assert.doesNotMatch(nativeBridgeSource, /releaseMaterializedTrack/);
  assert.doesNotMatch(playbackSource, /releaseMaterializedTrack/);
  assert.match(playbackBridgeSource, /nativePlaybackStop[\s\S]*defer \{ SPCArchiveMaterialization\.release\(\) \}/);
});

test("SPCBoyWK decodes typed completion and adjacent-navigation payloads", () => {
  assert.match(nativeBridgeSource, /completionRetirementResponse[\s\S]*?JSONDecoder\(\)\.decode\(PlaybackContinuationRequest\.self, from: data\)/);
  assert.match(nativeBridgeSource, /case "playbackQueueAdjacent"[\s\S]*?JSONDecoder\(\)\.decode\([\s\S]*?PlaybackQueueAdjacentRequest\.self/);
  assert.match(nativeBridgeSource, /Self\.object\(request\.response\)/);
  assert.doesNotMatch(nativeBridgeSource, /playbackQueueState\(/);
  assert.match(playbackSource, /playlistIds: playbackPlaylist\(\)\.map\(\(track\) => track\.id\),[\s\S]*?repeatMode: state\.repeatMode === "all"/);
  assert.doesNotMatch(playbackSource, /intent: \{ kind: "completion"/);
});

test("SPCBoyWK submits the shared typed queued-fade request", () => {
  const fadeCase = nativeBridgeSource.match(/case "playbackFadeDuration"[\s\S]*?(?=case "databaseFileTracks")/)?.[0] || "";

  assert.match(fadeCase, /JSONDecoder\(\)\.decode\([\s\S]*?PlaybackQueuedSkipFadeRequest\.self/);
  assert.match(fadeCase, /request\.durationMilliseconds/);
  assert.doesNotMatch(fadeCase, /args\.dropFirst|PlaybackFadePolicy/);
  assert.match(playbackSource, /playbackFadeDuration\(\{[\s\S]*?enabled: state\.queuedSkipsEnabled,[\s\S]*?totalSeconds: currentTotalSeconds\(track\)/);
});

test("SPCBoyWK delegates typed playback start to the shared transport", () => {
  assert.match(playbackBridgeSource, /case "nativePlaybackStart"[\s\S]*?let request: PlaybackTransportStartRequest = try bridgeRequest\(/);
  assert.match(playbackBridgeSource, /transport\.start\(try request\.continuationStart\(/);
  assert.doesNotMatch(playbackBridgeSource.match(/case "nativePlaybackStart"[\s\S]*?(?=case "nativePlaybackResume")/)?.[0] || "", /request\["trackIndex"\]|request\["playMilliseconds"\]|PlaybackControlPayload\(/);
  assert.match(playbackSource, /nativePlaybackStart\(\{[\s\S]*?trackId: track\.id,/);
});

test("SPCBoyWK delegates timing, reconfiguration, and tempo contracts to FrontendCore", () => {
  const timingCase = playbackBridgeSource.match(/case "nativePlaybackTiming"[\s\S]*?(?=case "nativePlaybackReconfigure")/)?.[0] || "";
  const reconfigureCase = playbackBridgeSource.match(/case "nativePlaybackReconfigure"[\s\S]*?(?=case "nativePlaybackSetTempo")/)?.[0] || "";
  const tempoCase = playbackBridgeSource.match(/case "nativePlaybackSetTempo"[\s\S]*?(?=case "nativePlaybackStart")/)?.[0] || "";

  assert.match(timingCase, /PlaybackTimingPreviewRequest = try bridgeRequest\(/);
  assert.match(timingCase, /bridgeResponse\(request\.preview\(\)\)/);
  assert.doesNotMatch(timingCase, /request\[|PlaybackTimingPolicy|PlaybackTimingPreferences|tempoMultiplier/);
  assert.match(reconfigureCase, /PlaybackTransportReconfigurationRequest = try bridgeRequest\(/);
  assert.match(reconfigureCase, /request\.playbackModePayload/);
  assert.doesNotMatch(reconfigureCase, /request\[|PlaybackControlPayload\(/);
  assert.match(tempoCase, /PlaybackTransportTempoRequest = try bridgeRequest\(/);
  assert.doesNotMatch(tempoCase, /request\[|tempoMultiplier/);
});

test("SPCBoyWK sends one typed audio-output snapshot to the shared transport", () => {
  const audioCase = playbackBridgeSource.match(/case "nativePlaybackAudioConfig"[\s\S]*?(?=case "nativePlaybackTiming")/)?.[0] || "";

  assert.match(audioCase, /PlaybackTransportAudioConfigurationRequest = try bridgeRequest\(/);
  assert.match(audioCase, /transport\.configureAudio\(request\)/);
  assert.doesNotMatch(audioCase, /args\[|PlaybackPreferences\(|setOutputVolume|setEqualizer|setMonoEnabled/);
  assert.match(playbackSource, /nativePlaybackAudioConfig\(\{[\s\S]*?appVolume: state\.appVolume,[\s\S]*?monoEnabled: state\.monoEnabled/);
  assert.match(uiSource, /const settings = audioSettingsPayload\(\);[\s\S]*?nativePlaybackAudioConfig\?\.\(settings\)/);
});

test("SPCBoyWK uses native in-place tempo and AAC cancellation events", () => {
  assert.match(playbackSource, /const tempo = playbackSpeedForTrack\(track\);[\s\S]*nativePlaybackSetTempo\(\{ tempo \}\)/);
  assert.doesNotMatch(playbackSource, /async function refreshPlaybackForSpeedChange[\s\S]*refreshPlaybackForTimingChange\(\)/);
  assert.match(playbackSource, /function handleAACExportEvent\(event\)/);
  assert.match(playbackSource, /nativeCancelAACExport/);
  assert.match(nativeBridgeSource, /onNativeAACExport/);
  assert.match(nativeBridgeSource, /nativeExportAACCancel/);
  assert.match(uiSource, /\[\["Export AAC"/);
  assert.match(indexSource, /id="aac-export-directory-path"/);
  assert.match(indexSource, /id="aac-export-cancel-button"/);
  assert.match(indexSource, /id="aac-export-choose-button" class="tool-button glyph-button"[\s\S]*icon-folder-tree/);
});

test("SPCBoyWK delegates AAC request and cancellation codecs to FrontendCore", () => {
  const exportCase = playbackBridgeSource.match(/case "nativeExportAAC"[\s\S]*?(?=case "nativeExportAACCancel")/)?.[0] || "";
  const cancelCase = playbackBridgeSource.match(/case "nativeExportAACCancel"[\s\S]*?(?=case "setPlaybackPowerSaveBlocker")/)?.[0] || "";
  const exportFunction = playbackBridgeSource.match(/private func exportAAC\([\s\S]*?(?=    private func cancelAACExport)/)?.[0] || "";

  assert.match(exportCase, /PlaybackTransportAACExportRequest = try bridgeRequest\(/);
  assert.match(exportCase, /bridgeResponse\(try exportAAC\(request\)\)/);
  assert.match(cancelCase, /PlaybackTransportAACExportCancellationRequest = try bridgeRequest\(/);
  assert.match(exportFunction, /request\.exportRequest\(resolvedPath: playbackPath\)/);
  assert.doesNotMatch(exportFunction, /request\[|AACExportRequest\(/);
});

test("SPCBoyWK sends named seek and output-ramp values to shared transport", () => {
  const seekCase = playbackBridgeSource.match(/case "nativePlaybackSeek"[\s\S]*?(?=case "nativePlaybackRampGain")/)?.[0] || "";
  const rampCase = playbackBridgeSource.match(/case "nativePlaybackRampGain"[\s\S]*?(?=case "nativeExportAAC")/)?.[0] || "";

  assert.match(seekCase, /PlaybackTransportSeekRequest = try bridgeRequest\(/);
  assert.match(seekCase, /payload: request\.payload/);
  assert.match(rampCase, /PlaybackTransportRampGainRequest = try bridgeRequest\(/);
  assert.match(rampCase, /payload: request\.payload/);
  assert.doesNotMatch(seekCase + rampCase, /args\[|int\(|number\(/);
  assert.match(playbackSource, /nativePlaybackRampGain\?\.\(\{ outputGain: 0, rampMilliseconds: durationMs \}\)/);
  assert.match(playbackSource, /nativePlaybackSeek\(\{ positionMilliseconds: requestedMilliseconds \}\)/);
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
  assert.doesNotMatch(uiSource, /checkbox\.disabled\s*=\s*column\.id\s*===\s*"filename"/);
  assert.match(uiSource, /state\.columnVisibility\[column\.id\]\s*=\s*true/);
  assert.match(preferencesSnapshotSource, /normalizedLayout\(/);
  assert.doesNotMatch(appCoreSource, /function normalizeColumnVisibility\(/);
});

test("SPCBoyWK consumes the shared header sizing setting", () => {
  assert.match(preferencesSnapshotSource, /playlistColumnSizing: FrontendPlaylistColumnSizing\?/);
  assert.match(preferencesSnapshotSource, /playlistColumnSizing = FrontendPlaylistColumnSizing\(\)/);
  assert.match(appCoreSource, /state\.playlistColumnSizing = normalizePlaylistColumnSizing/);
  assert.match(appCoreSource, /playlistColumnSizing: \{ horizontalPaddingPerSide: 8 \}/);
  assert.match(appCoreSource, /: 8\s*\n\s*\}/);
  assert.match(uiSource, /function columnMinimumWidthPercent\(columnId, tableWidth\)/);
  assert.match(uiSource, /playlistColumnHorizontalPadding\(\)/);
  assert.doesNotMatch(uiSource, /\+ 24/);
  assert.doesNotMatch(appCoreSource, /Math\.max\(4, Math\.min\(80, numeric\)\)/);
});

test("SPCBoyWK filters database search locally without a debounce", () => {
  assert.match(uiSource, /function rebuildDatabaseGameSearchIndex\(games = state\.databaseGames\)/);
  assert.match(uiSource, /searchText: String\(game\.searchText \|\| ""\)/);
  assert.doesNotMatch(uiSource, /\$\{game\.name \|\| ""\} \$\{game\.system/);
  assert.match(nativeBridgeSource, /"searchText": game\.searchText/);
  assert.match(uiSource, /terms\.every\(\(term\) => searchText\.includes\(term\)\)/);
  assert.match(uiSource, /state\.sidebarView = Object\.freeze\(localSidebarView\(state\.sidebarMode, state\.sidebarQuery\)\)/);
  assert.doesNotMatch(uiSource, /sidebarSearchTimer/);
  assert.doesNotMatch(uiSource, /databaseSearchGames\(requestedQuery\)/);
  assert.doesNotMatch(uiSource, /databaseSearchGeneration/);
});

test("SPCBoyWK renders the native catalog console-group projection without a second sort", () => {
  assert.match(nativeBridgeSource, /CatalogBrowserProjection\.groups\(from: projected\)/);
  assert.match(nativeBridgeSource, /"gameIDs": group\.games\.map\(\\\.id\)/);
  assert.match(nativeBridgeSource, /"consoleGroupName": game\.consoleGroupName/);
  assert.match(nativeBridgeSource, /case "databaseGroupState"[\s\S]*?JSONDecoder\(\)\.decode\([\s\S]*?CatalogBrowserGroupStateRequest\.self/);
  assert.match(nativeBridgeSource, /Self\.object\(request\.response\)/);
  assert.doesNotMatch(nativeBridgeSource, /private static func databaseGroupState/);
  assert.match(uiSource, /function visibleDatabaseGameGroups\(\)/);
  assert.match(uiSource, /function databaseConsoleName\(game\)[\s\S]*?game\.consoleGroupName/);
  assert.match(uiSource, /state\.databaseGameGroups/);
  assert.match(uiSource, /databaseGroupState\([\s\S]*?state: databaseGroupStateSnapshot\(\),[\s\S]*?kind: action/);
  assert.doesNotMatch(uiSource, /sidebarNaturalCollator|Intl\.Collator/);
  assert.doesNotMatch(uiSource, /groupedGames\.keys\(\)\.sort/);
});

test("SPCBoyWK catalog roots are foldable in Path View", () => {
  assert.doesNotMatch(nativeBridgeSource, /"alwaysExpanded": isRoot/);
});

test("SPCBoyWK focused activation preserves the CocoaSpice playable identity contract", async () => {
  assert.equal(activationContract.contract, "cocoaspice-spcboy-playlist-activation");
  assert.equal(activationContract.version, 1);
  assert.ok(activationContract.cases.length > 0);
  for (const fixture of activationContract.cases) {
    const { app, startRequests, loadUI } = makeHarness();
    // The native projection supplies canonical IDs. This exercises their
    // preservation and activation in WK, not native identity generation.
    app.state.playlist = fixture.expectedTrackIDs.map((id, trackIndex) => ({
      id,
      title: fixture.metadataBefore[trackIndex],
      path: fixture.sourcePath,
      archivePath: fixture.archiveEntry ? fixture.sourcePath : null,
      archiveEntry: fixture.archiveEntry,
      sourceFilename: (fixture.archiveEntry || fixture.sourcePath).split("/").at(-1),
      trackIndex,
      trackCount: fixture.trackCount,
      basePlaybackSeconds: 4
    }));
    app.state.selectedTrackId = fixture.expectedTrackIDs[0];
    loadUI();
    for (let trackIndex = fixture.trackCount - 1; trackIndex >= 0; trackIndex--) {
      const id = fixture.expectedTrackIDs[trackIndex];
      app.state.playlist[trackIndex].title = fixture.metadataAfter[trackIndex];
      const row = {
        dataset: { trackId: id },
        closest(selector) { return selector.includes(".playlist-row") ? this : null; }
      };
      assert.equal(await app.ui.activateFocusedItem(row), true, fixture.id);
      assert.equal(app.state.currentTrackId, id, fixture.id);
      assert.equal(app.state.selectedTrackId, id, fixture.id);
      assert.deepEqual(Array.from(app.state.selectedTrackIds), [id], fixture.id);
      const request = startRequests.at(-1);
      assert.equal(request.path, fixture.sourcePath, fixture.id);
      assert.equal(request.archivePath, fixture.archiveEntry ? fixture.sourcePath : null, fixture.id);
      assert.equal(request.archiveEntry, fixture.archiveEntry, fixture.id);
      assert.equal(request.trackIndex, trackIndex, fixture.id);
      assert.equal(request.startMilliseconds, 0, fixture.id);
    }
    assert.equal(startRequests.length, fixture.trackCount, fixture.id);
    const removedRow = {
      dataset: { trackId: "removed-row" },
      closest() { return this; }
    };
    assert.equal(await app.ui.activateFocusedItem(removedRow), false);
    assert.equal(startRequests.length, fixture.trackCount, "removed focus must not activate a fallback");
  }
});

for (const outcome of ["resolve", "reject"]) {
  test(`SPCBoyWK ignores a stale native start ${outcome} after replacement`, async () => {
    const { app, window, startRequests } = makeHarness();
    const oldStart = deferred();
    const enteredStart = deferred();
    let closeCalls = 0;
    window.spcBoyWK.nativePlaybackClose = async () => { closeCalls++; };
    window.spcBoyWK.nativePlaybackStart = async (request) => {
      startRequests.push(request);
      if (request.path === "/tmp/fixture.flac") {
        enteredStart.resolve();
        return oldStart.promise;
      }
      return snapshot(8);
    };
    app.state.playlist.push({ ...app.state.playlist[0], id: "track-b", path: "/tmp/replacement.flac" });
    const oldPlayback = app.playback.playTrack("track-a");
    await enteredStart.promise;
    await app.playback.playTrack("track-b");
    if (outcome === "resolve") oldStart.resolve(snapshot(7));
    else oldStart.reject(new Error("old load failed"));
    await oldPlayback;
    assert.equal(app.state.currentTrackId, "track-b");
    assert.equal(app.state.nativePlayback.generation, 8);
    assert.equal(app.state.isPlaying, true);
    assert.equal(closeCalls, 0, "old failure must not close the replacement");
    assert.equal(startRequests.length, 2);
  });
}

test("SPCBoyWK drops an older start after its pending unload completes", async () => {
  const { app, window, startRequests } = makeHarness();
  await app.playback.playTrack("track-a");
  app.state.playlist.push({ ...app.state.playlist[0], id: "track-b", path: "/tmp/replacement.flac" });
  const oldUnload = deferred();
  const enteredUnload = deferred();
  let unloadCalls = 0;
  window.spcBoyWK.nativePlaybackUnload = async () => {
    if (++unloadCalls === 1) {
      enteredUnload.resolve();
      return oldUnload.promise;
    }
    return snapshot(8, "stopped");
  };
  startRequests.length = 0;
  const oldPlayback = app.playback.playTrack("track-a");
  await enteredUnload.promise;
  await app.playback.playTrack("track-b", 0, false, { replaceQueue: true });
  oldUnload.resolve(snapshot(7, "stopped"));
  await oldPlayback;
  assert.deepEqual(startRequests.map((request) => request.path), ["/tmp/replacement.flac"]);
  assert.equal(app.state.currentTrackId, "track-b");
  assert.equal(app.state.isPlaying, true);
});

for (const method of ["setPlaybackPowerSaveBlocker", "nativePlaybackInit", "nativePlaybackAudioConfig"]) {
  for (const interrupt of ["replacement", "stop"]) {
    test(`SPCBoyWK abandons start awaiting ${method} after ${interrupt}`, async () => {
      const { app, window, startRequests } = makeHarness();
      app.state.playlist.push({ ...app.state.playlist[0], id: "track-b", path: "/tmp/replacement.flac" });
      const pending = deferFirstBridgeReply(window.spcBoyWK, method);
      const configCalls = [];
      if (method === "nativePlaybackInit") {
        window.spcBoyWK.nativePlaybackAudioConfig = async (...args) => { configCalls.push(args); };
      }
      const oldPlayback = app.playback.playTrack("track-a");
      await pending.entered;
      if (interrupt === "replacement") await app.playback.playTrack("track-b");
      else await app.playback.stopPlaybackState({ declick: false });
      pending.release();
      await oldPlayback;
      assert.deepEqual(startRequests.map((request) => request.path),
        interrupt === "replacement" ? ["/tmp/replacement.flac"] : []);
      assert.equal(app.state.currentTrackId, interrupt === "replacement" ? "track-b" : null);
      assert.equal(app.state.isPlaying, interrupt === "replacement");
      if (method === "nativePlaybackInit") {
        assert.equal(configCalls.length, interrupt === "replacement" ? 1 : 0,
          "obsolete initialization must not reconfigure the output");
      }
    });
  }
}

for (const method of ["nativePlaybackRampGain", "nativePlaybackStop", "setPlaybackPowerSaveBlocker"]) {
  test(`SPCBoyWK abandons stop awaiting ${method} after replacement`, async () => {
    const { app, window, startRequests } = makeHarness();
    app.state.playlist.push({ ...app.state.playlist[0], id: "track-b", path: "/tmp/replacement.flac" });
    await app.playback.playTrack("track-a");
    let stopCalls = 0;
    window.spcBoyWK.nativePlaybackStop = async () => { stopCalls++; return snapshot(7, "stopped"); };
    const pending = deferFirstBridgeReply(window.spcBoyWK, method);
    const oldStop = app.playback.stopPlaybackState({ declick: method === "nativePlaybackRampGain" });
    await pending.entered;
    await app.playback.playTrack("track-b");
    pending.release();
    await oldStop;
    assert.equal(stopCalls, method === "nativePlaybackRampGain" ? 0 : 1,
      "an obsolete fade must not send a new stop to the replacement");
    assert.equal(app.state.currentTrackId, "track-b");
    assert.equal(app.state.isPlaying, true);
    assert.equal(startRequests.length, 2);
  });
}

test("SPCBoyWK abandons failed-start cleanup awaiting power-save release after replacement", async () => {
  const { app, window } = makeHarness();
  app.state.playlist.push({ ...app.state.playlist[0], id: "track-b", path: "/tmp/replacement.flac" });
  window.spcBoyWK.nativePlaybackStart = async (request) => {
    if (request.path === "/tmp/fixture.flac") throw new Error("failed old start");
    return snapshot(8);
  };
  let closeCalls = 0;
  window.spcBoyWK.nativePlaybackClose = async () => { closeCalls++; };
  const pending = deferFirstBridgeReply(window.spcBoyWK, "setPlaybackPowerSaveBlocker", (enabled) => !enabled);
  const oldPlayback = app.playback.playTrack("track-a");
  // Capture the result immediately: a current failure must still be surfaced,
  // while cleanup superseded by replacement must leave the replacement intact.
  const oldResult = oldPlayback.then(() => null, (error) => error);
  await pending.entered;
  await app.playback.playTrack("track-b");
  pending.release();
  assert.equal(await oldResult, null);
  assert.equal(closeCalls, 0);
  assert.equal(app.state.currentTrackId, "track-b");
  assert.equal(app.state.isPlaying, true);
  assert.equal(app.state.nativePlayback.generation, 8);
});

test("SPCBoyWK still closes and reports a current failed start", async () => {
  const { app, window } = makeHarness();
  const failure = new Error("current load failed");
  let closeCalls = 0;
  window.spcBoyWK.nativePlaybackStart = async () => { throw failure; };
  window.spcBoyWK.nativePlaybackClose = async () => { closeCalls++; };
  await assert.rejects(app.playback.playTrack("track-a"), (error) => error === failure);
  assert.equal(closeCalls, 1);
  assert.equal(app.state.isPlaying, false);
  assert.equal(app.state.nativePlayback.trackLoaded, false);
});

test("SPCBoyWK ignores an old close reply without resetting replacement initialization", async () => {
  const { app, window } = makeHarness();
  app.state.playlist.push({ ...app.state.playlist[0], id: "track-b", path: "/tmp/replacement.flac" });
  let initCalls = 0;
  window.spcBoyWK.nativePlaybackInit = async () => { initCalls++; };
  window.spcBoyWK.nativePlaybackStart = async (request) => {
    if (request.path === "/tmp/fixture.flac") throw new Error("failed old start");
    return snapshot(8);
  };
  const pending = deferFirstBridgeReply(window.spcBoyWK, "nativePlaybackClose");
  const oldResult = app.playback.playTrack("track-a").then(() => null, (error) => error);
  await pending.entered;
  await app.playback.playTrack("track-b");
  pending.release();
  assert.equal(await oldResult, null);
  assert.equal(app.state.currentTrackId, "track-b");
  assert.equal(app.state.isPlaying, true);
  await app.playback.playTrack("track-b");
  assert.equal(initCalls, 1, "obsolete close reply must not reset the initialized flag");
});

for (const action of ["pause", "resume", "seek"]) {
  test(`SPCBoyWK drops ${action} preparation after replacement`, async () => {
    const { app, window } = makeHarness();
    app.state.playlist.push({ ...app.state.playlist[0], id: "track-b", path: "/tmp/replacement.flac" });
    await app.playback.playTrack("track-a");
    if (action === "resume") app.state.isPlaying = false;
    if (action === "seek") await app.playback.playAdjacent(1);
    const method = action === "resume" ? "setPlaybackPowerSaveBlocker" : "nativePlaybackRampGain";
    const pending = deferFirstBridgeReply(window.spcBoyWK, method);
    let commandCalls = 0;
    const command = { pause: "nativePlaybackPause", resume: "nativePlaybackResume", seek: "nativePlaybackSeek" }[action];
    window.spcBoyWK[command] = async () => { commandCalls++; return snapshot(7); };
    const operation = action === "seek" ? app.playback.restartAt(2) : app.playback.togglePlayback();
    await pending.entered;
    await app.playback.playTrack("track-b");
    pending.release();
    await operation;
    assert.equal(commandCalls, 0, `old ${action} must not reach the replacement`);
    assert.equal(app.state.currentTrackId, "track-b");
    assert.equal(app.state.isPlaying, true);
  });
}

test("SPCBoyWK ignores an older seek reply on the same track", async () => {
  const { app, window } = makeHarness();
  await app.playback.playTrack("track-a");
  const pending = deferFirstBridgeReply(window.spcBoyWK, "nativePlaybackSeek");
  const first = app.playback.restartAt(2);
  await pending.entered;
  await app.playback.restartAt(3);
  pending.release();
  await first;
  assert.equal(app.state.elapsedSeconds, 3);
});

for (const method of ["playbackFadeDuration", "playbackQueueAdjacent"]) {
  test(`SPCBoyWK ignores ${method} after replacement`, async () => {
    const { app, window, gainCalls, startRequests } = makeHarness();
    app.state.playlist.push({ ...app.state.playlist[0], id: "track-b", path: "/tmp/replacement.flac" });
    await app.playback.playTrack("track-a");
    if (method === "playbackQueueAdjacent") window.spcBoyWK.playbackFadeDuration = async () => 0;
    window.spcBoyWK.playbackQueueAdjacent = async () => ({ trackId: "track-a" });
    const pending = deferFirstBridgeReply(window.spcBoyWK, method);
    const skip = app.playback.playAdjacent(1);
    await pending.entered;
    await app.playback.playTrack("track-b");
    const priorGains = gainCalls.length;
    pending.release();
    await skip;
    assert.equal(gainCalls.length, priorGains, "obsolete skip must not fade replacement");
    assert.deepEqual(startRequests.map((request) => request.path), ["/tmp/fixture.flac", "/tmp/replacement.flac"]);
    assert.equal(app.state.currentTrackId, "track-b");
  });
}

test("SPCBoyWK abandons a second skip waiting on its fade after replacement", async () => {
  const { app, window } = makeHarness();
  app.state.playlist.push({ ...app.state.playlist[0], id: "track-b", path: "/tmp/replacement.flac" });
  await app.playback.playTrack("track-a");
  await app.playback.playAdjacent(1);
  const pending = deferFirstBridgeReply(window.spcBoyWK, "nativePlaybackRampGain");
  let stopCalls = 0;
  window.spcBoyWK.nativePlaybackStop = async () => { stopCalls++; return snapshot(7, "stopped"); };
  const skip = app.playback.playAdjacent(1);
  await pending.entered;
  await app.playback.playTrack("track-b");
  pending.release();
  await skip;
  await new Promise(setImmediate); // Drain the prior fire-and-forget continuation too.
  assert.equal(stopCalls, 0);
  assert.equal(app.state.currentTrackId, "track-b");
  assert.equal(app.state.isPlaying, true);
});

test("SPCBoyWK drops a queued fade status reply after replacement", async () => {
  const { app, window, fireFirstTimer } = makeHarness();
  app.state.playlist.push({ ...app.state.playlist[0], id: "track-b", path: "/tmp/replacement.flac" });
  await app.playback.playTrack("track-a");
  await app.playback.playAdjacent(1);
  let retireCalls = 0;
  window.spcBoyWK.playbackCompletionRetire = async () => { retireCalls++; return { action: "stop" }; };
  const pending = deferFirstBridgeReply(window.spcBoyWK, "nativePlaybackState");
  fireFirstTimer();
  await pending.entered;
  await app.playback.playTrack("track-b");
  pending.release();
  await new Promise(setImmediate);
  assert.equal(retireCalls, 0);
  assert.equal(app.state.currentTrackId, "track-b");
  assert.equal(app.state.isPlaying, true);
});

test("SPCBoyWK pause, resume, and seek keep the loaded session", async () => {
  const { app, startRequests } = makeHarness();
  await app.playback.playTrack("track-a");
  await app.playback.togglePlayback();
  assert.equal(app.state.isPlaying, false);
  assert.equal(app.state.nativePlayback.transportState, "paused");
  await app.playback.togglePlayback();
  assert.equal(app.state.isPlaying, true);
  await app.playback.restartAt(2);
  assert.equal(app.state.elapsedSeconds, 2);
  assert.equal(startRequests.length, 1);
});

for (const method of ["nativePlaybackPause", "setPlaybackPowerSaveBlocker"]) {
  test(`SPCBoyWK drops a pause awaiting ${method} reply after replacement`, async () => {
    const { app, window } = makeHarness();
    app.state.playlist.push({ ...app.state.playlist[0], id: "track-b", path: "/tmp/replacement.flac" });
    await app.playback.playTrack("track-a");
    const pending = deferFirstBridgeReply(window.spcBoyWK, method, (enabled) => !enabled);
    const pause = app.playback.togglePlayback();
    await pending.entered;
    await app.playback.playTrack("track-b");
    pending.release();
    await pause;
    assert.equal(app.state.currentTrackId, "track-b");
    assert.equal(app.state.isPlaying, true);
    assert.equal(app.state.nativePlayback.transportState, "playing");
  });
}

test("SPCBoyWK second skip completes one native-selected transition", async () => {
  const { app, window, startRequests, queueTransitionRequests } = makeHarness();
  app.state.playlist.push({ ...app.state.playlist[0], id: "track-b", path: "/tmp/replacement.flac" });
  await app.playback.playTrack("track-a");
  window.spcBoyWK.playbackQueueAdjacent = async (request) => {
    queueTransitionRequests.push(request);
    return { trackId: "track-b" };
  };
  await app.playback.playAdjacent(1);
  await app.playback.playAdjacent(1);
  assert.equal(app.state.currentTrackId, "track-b");
  assert.equal(app.state.isPlaying, true);
  assert.equal(queueTransitionRequests.length, 1);
  assert.deepEqual(startRequests.map((request) => request.path), ["/tmp/fixture.flac", "/tmp/replacement.flac"]);
});
