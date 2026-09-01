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
const catalogTrackMapperSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/catalog-track-mapper.js"),
  "utf8"
);
const catalogActionsSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/catalog-actions.js"),
  "utf8"
);
const playlistSelectionSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/playlist-selection-actions.js"),
  "utf8"
);
const playbackSettingsSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/playback-settings-actions.js"),
  "utf8"
);
const audioSettingsSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/audio-settings-actions.js"),
  "utf8"
);
const playbackSpeedActionsSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/playback-speed-actions.js"),
  "utf8"
);
const appearanceActionsSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/appearance-actions.js"),
  "utf8"
);
const archiveCacheActionsSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/archive-cache-actions.js"),
  "utf8"
);
const routingActionsSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/routing-actions.js"),
  "utf8"
);
const favoriteActionsSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/favorite-actions.js"),
  "utf8"
);
const playlistMutationActionsSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/playlist-mutation-actions.js"),
  "utf8"
);
const navigationActionsSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/navigation-actions.js"),
  "utf8"
);
const sidebarCollapseActionsSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/sidebar-collapse-actions.js"),
  "utf8"
);
const librarySelectionActionsSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/library-selection-actions.js"),
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
const sidebarTreeSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/sidebar-tree-view.js"),
  "utf8"
);
const databaseSidebarSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/database-sidebar-view.js"),
  "utf8"
);
const browserActionsSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/browser-actions.js"),
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

function loadCatalogTrackMapper() {
  const window = {};
  vm.runInNewContext(catalogTrackMapperSource, { window }, { filename: "catalog-track-mapper.js" });
  return window.SPCBoyCatalogTrackMapper;
}

function loadCatalogActions() {
  const window = {};
  vm.runInNewContext(catalogActionsSource, { window }, { filename: "catalog-actions.js" });
  return window.SPCBoyCatalogActions;
}

function loadPlaylistSelection() {
  const window = {};
  vm.runInNewContext(playlistSelectionSource, { window }, { filename: "playlist-selection-actions.js" });
  return window.SPCBoyPlaylistSelectionActions;
}

function loadPlaybackSettings() {
  const window = {};
  vm.runInNewContext(playbackSettingsSource, { window }, { filename: "playback-settings-actions.js" });
  return window.SPCBoyPlaybackSettingsActions;
}

function loadAudioSettings() {
  const window = {};
  vm.runInNewContext(audioSettingsSource, { window }, { filename: "audio-settings-actions.js" });
  return window.SPCBoyAudioSettingsActions;
}

function loadPlaybackSpeedActions() {
  const window = {};
  vm.runInNewContext(playbackSpeedActionsSource, { window }, { filename: "playback-speed-actions.js" });
  return window.SPCBoyPlaybackSpeedActions;
}

function loadAppearanceActions() {
  const window = {};
  vm.runInNewContext(appearanceActionsSource, { window }, { filename: "appearance-actions.js" });
  return window.SPCBoyAppearanceActions;
}

function loadArchiveCacheActions() {
  const window = {};
  vm.runInNewContext(archiveCacheActionsSource, { window }, { filename: "archive-cache-actions.js" });
  return window.SPCBoyArchiveCacheActions;
}

function loadRoutingActions() {
  const window = {};
  vm.runInNewContext(routingActionsSource, { window }, { filename: "routing-actions.js" });
  return window.SPCBoyRoutingActions;
}

function loadFavoriteActions() {
  const window = {};
  vm.runInNewContext(favoriteActionsSource, { window }, { filename: "favorite-actions.js" });
  return window.SPCBoyFavoriteActions;
}

function loadPlaylistMutationActions() {
  const window = {};
  vm.runInNewContext(playlistMutationActionsSource, { window }, { filename: "playlist-mutation-actions.js" });
  return window.SPCBoyPlaylistMutationActions;
}

function loadNavigationActions() {
  const window = {};
  vm.runInNewContext(navigationActionsSource, { window, document: { activeElement: null } }, { filename: "navigation-actions.js" });
  return window.SPCBoyNavigationActions;
}

function loadSidebarCollapseActions() {
  const window = {};
  vm.runInNewContext(sidebarCollapseActionsSource, { window }, { filename: "sidebar-collapse-actions.js" });
  return window.SPCBoySidebarCollapseActions;
}

function loadLibrarySelectionActions() {
  const window = {};
  vm.runInNewContext(librarySelectionActionsSource, { window }, { filename: "library-selection-actions.js" });
  return window.SPCBoyLibrarySelectionActions;
}

function loadAppearanceView() {
  const window = { SPCBoyPlaybackBackends: { conflicts: [] } };
  vm.runInNewContext(appearanceViewSource, { window }, { filename: "appearance-view.js" });
  return window.SPCBoyAppearanceView;
}

function loadSidebarTree() {
  const window = {};
  vm.runInNewContext(sidebarTreeSource, { window }, { filename: "sidebar-tree-view.js" });
  return window.SPCBoySidebarTree;
}

function loadDatabaseSidebar() {
  const window = {};
  vm.runInNewContext(databaseSidebarSource, { window }, { filename: "database-sidebar-view.js" });
  return window.SPCBoyDatabaseSidebar;
}

function loadBrowserActions() {
  const window = {};
  vm.runInNewContext(browserActionsSource, { window }, { filename: "browser-actions.js" });
  return window.SPCBoyBrowserActions;
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

test("SPCBoyWK keeps filesystem tree filtering and rendering in the sidebar tree module", () => {
  assert.match(indexSource, /playlist-rows\.js[\s\S]*appearance-view\.js[\s\S]*sidebar-tree-view\.js[\s\S]*app-ui\.js/);
  assert.match(sidebarTreeSource, /function filteredTree\(\)/);
  assert.match(sidebarTreeSource, /function renderTreeNode\(/);
  assert.match(sidebarTreeSource, /function renderTree\(\)/);
  assert.match(uiSource, /return sidebarTree\.renderTree\(\)/);
  assert.doesNotMatch(uiSource, /function renderTreeNode\(/);

  const leaf = { path: "/root/leaf.spc", name: "Leaf SPC", kind: "file", children: [] };
  const tree = [{ path: "/root", name: "Root", kind: "folder", children: [leaf] }];
  const state = {
    rootPath: "/root",
    selectedBrowserPath: "/root/leaf.spc",
    sidebarQuery: "leaf",
    tree,
    databaseFileTree: []
  };
  const view = loadSidebarTree().create({
    state,
    refs: {},
    expandedFolders: new Set(),
    currentSidebarView: () => ({ view: "diskPath" }),
    escapeHtml: (value) => String(value),
    resetSidebarContent() {},
    scheduleSelectionIndicators() {},
    selectBrowserNode() {},
    handleBrowserPrimaryClick() {},
    handleBrowserGesture() {},
    showSidebarContextMenu() {},
    moveBrowserSelection() {},
    setSelectedBrowserButton() {}
  });

  assert.equal(view.findBrowserNode(tree, leaf.path), leaf);
  assert.equal(view.filteredTree()[0].path, "/root");
  assert.equal(view.filteredTree()[0].children[0].path, leaf.path);
});

test("SPCBoyWK keeps database console grouping and rendering in the database sidebar module", () => {
  assert.match(indexSource, /sidebar-tree-view\.js[\s\S]*database-sidebar-view\.js[\s\S]*app-ui\.js/);
  assert.match(databaseSidebarSource, /function groupedGamesByConsole\(/);
  assert.match(databaseSidebarSource, /function makeDatabaseGameButton\(/);
  assert.match(databaseSidebarSource, /function renderDatabaseGames\(/);
  assert.match(uiSource, /return databaseSidebarView\.renderDatabaseGames\(\)/);
  assert.match(uiSource, /collapsedDatabaseConsoles\.clear\(\)[\s\S]*collapsedDatabaseConsoles\.add\(name\)/);
  assert.doesNotMatch(uiSource, /function makeDatabaseGameButton\(/);

  const view = loadDatabaseSidebar().create({
    state: {},
    refs: {},
    sidebarNaturalCollator: { compare: (left, right) => left.localeCompare(right) },
    collapsedDatabaseConsoles: new Set(),
    databaseGameKey: (game) => game.name,
    databaseConsoleName: (game) => game.system || "Unknown Console",
    escapeHtml: (value) => String(value),
    persistSettings() {},
    resetSidebarContent() {},
    positionSelectionIndicator() {},
    scheduleSelectionIndicators() {},
    applySharedDatabaseGroupAction() {},
    reportDatabaseSidebarError() {},
    showContextMenu() {},
    loadDatabaseGame() {},
    databaseLoadedSelectionID() {},
    playVisibleTrack() {},
    activateDatabaseSelection() {},
    appendPlaylistTracks() {},
    databaseRowsToPlaylistTracks() {}
  });
  const groups = view.groupedGamesByConsole([
    { name: "First", system: "SNES" },
    { name: "Second", system: "PSP" },
    { name: "Third", system: "SNES" }
  ]);

  assert.equal([...groups.keys()].join(","), "SNES,PSP");
  assert.equal(groups.get("SNES").length, 2);
});

test("SPCBoyWK keeps local browser actions and stale-selection guards in their action module", () => {
  assert.match(indexSource, /database-sidebar-view\.js[\s\S]*browser-actions\.js[\s\S]*app-ui\.js/);
  assert.match(browserActionsSource, /async function activateBrowserNode\(/);
  assert.match(browserActionsSource, /async function previewBrowserLeaf\(/);
  assert.match(browserActionsSource, /function selectBrowserNode\(/);
  assert.match(browserActionsSource, /async function toggleBrowserNode\(/);
  assert.match(browserActionsSource, /generation !== browserSelectionGeneration/);
  assert.match(uiSource, /return browserActions\.activateBrowserNode\(node, \{ playNow \}\)/);
  assert.doesNotMatch(uiSource, /browserSelectionGeneration/);

  const state = { selectedBrowserPath: "/root/file.spc" };
  const view = loadBrowserActions().create({
    state,
    refs: {},
    expandedFolders: new Set(),
    persistSettings() {},
    databaseRowsToPlaylistTracks: (rows) => rows,
    applyFolderSelection() {},
    playVisibleTrack() {},
    renderTree() {},
    syncTreeSelection() {},
    filteredTree() { return []; },
    findBrowserNode() {},
    appendPlaylistTracks() {}
  });
  const selection = view.catalogPlaylistSelection([{ id: "track-a" }], "/root");

  assert.equal(selection.selectedFolderPath, "/root");
  assert.equal(selection.selectedBrowserPath, "/root/file.spc");
  assert.equal(selection.playlist[0].id, "track-a");
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

test("SPCBoyWK catalog track mapping preserves indexed metadata and multi-track labels", () => {
  assert.match(indexSource, /database-view-utils\.js[\s\S]*catalog-track-mapper\.js[\s\S]*playlist-table-utils\.js/);
  assert.match(catalogTrackMapperSource, /function databaseRowsToPlaylistTracks\(/);
  assert.match(uiSource, /return catalogTrackMapper\.databaseRowsToPlaylistTracks\(rows, games\)/);
  assert.doesNotMatch(uiSource, /const fallbackGame = games\[0\] \|\| \{\}/);

  const mapper = loadCatalogTrackMapper().create({
    state: { rootPath: "/library" },
    formatTime: (seconds) => `${seconds}s`
  });
  const track = mapper.databaseRowsToPlaylistTracks([{
    playlistId: "track-a",
    path: "/library/game.spc",
    filename: "game.spc",
    trackIndex: 1,
    trackCount: 2,
    dumper: "Stored Dumper",
    playLengthMs: 42000
  }], [{ name: "Game", system: "SNES", rootPath: "/library" }])[0];

  assert.equal(track.filename, "game.spc [2]");
  assert.equal(track.displayName, "game [2]");
  assert.equal(track.dumper, "Stored Dumper");
  assert.equal(track.lengthLabel, "42s");
  assert.equal(track.catalogRow, true);
});

test("SPCBoyWK filters database search locally without a debounce", () => {
  assert.match(uiSource, /function rebuildDatabaseGameSearchIndex\(games = state\.databaseGames\)/);
  assert.match(catalogActionsSource, /state\.sidebarView = Object\.freeze\(sidebarView\(state\.sidebarMode, state\.sidebarQuery\)\)/);
  assert.match(uiSource, /return catalogActions\.updateSidebarSearch\(query\)/);
  assert.match(databaseViewSource, /terms\.every\(\(term\) => searchText\.includes\(term\)\)/);
  assert.doesNotMatch(uiSource, /sidebarSearchTimer/);
  assert.doesNotMatch(uiSource, /databaseSearchGames\(requestedQuery\)/);
  assert.doesNotMatch(uiSource, /databaseSearchGeneration/);
});

test("SPCBoyWK catalog actions keep local search indexing separate from the host UI", () => {
  assert.match(indexSource, /catalog-track-mapper\.js[\s\S]*catalog-actions\.js[\s\S]*app-ui\.js/);
  assert.match(catalogActionsSource, /async function loadDatabaseGames\(/);
  assert.match(catalogActionsSource, /async function loadDatabaseFiles\(/);
  assert.match(catalogActionsSource, /async function setSidebarMode\(/);
  assert.match(catalogActionsSource, /async function loadDatabaseGamesIntoPlaylist\(/);
  assert.match(catalogActionsSource, /async function activateDatabaseSelection\(/);
  assert.doesNotMatch(uiSource, /function loadDatabaseGamesIntoPlaylist\(/);

  const state = {
    databaseGames: [
      { name: "Silent Hill", system: "PSP" },
      { name: "Kirby", system: "SNES" }
    ]
  };
  const actions = loadCatalogActions().create({
    state,
    refs: {},
    sidebarView: () => ({}),
    searchRecords: (games) => games.map((game) => ({ game, searchText: `${game.name} ${game.system}`.toLowerCase() })),
    filterSearchRecords: (records, query) => records.filter((record) => record.searchText.includes(query.toLowerCase())).map((record) => record.game),
    resolveSidebarState: async () => ({}),
    persistSettings() {},
    invalidatePlaylistCatalogSession: async () => {},
    renderAll() {},
    renderSidebar() {},
    renderPlaylist() {},
    syncTreeSelection() {},
    refreshFavorites: async () => {},
    resolveSelectedTrackId() {},
    targetPlaybackSeconds() {},
    databaseGameKey: (game) => game.name,
    databaseConsoleName: (game) => game.system,
    databaseRowsToPlaylistTracks: (rows) => rows,
    databaseLoadedSelectionID() {},
    playVisibleTrack() {},
    reportDatabaseSidebarError() {},
    playback: {}
  });
  actions.rebuildDatabaseGameSearchIndex();

  assert.equal(actions.localDatabaseSearch("silent")[0].name, "Silent Hill");
});

test("SPCBoyWK keeps playlist selection and keyboard actions in a selection module", () => {
  assert.match(indexSource, /catalog-actions\.js[\s\S]*playlist-selection-actions\.js[\s\S]*app-ui\.js/);
  assert.match(playlistSelectionSource, /function moveSelection\(/);
  assert.match(playlistSelectionSource, /function selectAllPlaylistTracks\(/);
  assert.match(playlistSelectionSource, /function playSelectedTrack\(/);
  assert.match(uiSource, /return playlistSelectionActions\.moveSelection\(delta, \{ range, extend \}\)/);
  assert.match(uiSource, /return playlistSelectionActions\.playSelectedTrack\(\)/);
  assert.doesNotMatch(uiSource, /const currentIndex = selectedTrackIndex\(\)/);

  const state = {
    playlist: [{ id: "track-a" }, { id: "track-b" }],
    selectedTrackId: "track-b"
  };
  const actions = loadPlaylistSelection().create({
    state,
    refs: { playlistBody: { querySelector: () => null } },
    persistSettings() {},
    selectPlaylistTrack() {},
    refreshPlaylistPlaybackState() {},
    renderPlaylist() {},
    playlistRows: {
      playlistUsesVirtualRows: () => false,
      hasRow: () => true,
      playlistVirtualRowHeight: () => 32
    },
    updateTimingSummary() {},
    getSelectedTrack: () => state.playlist[1],
    playVisibleTrack: async () => {}
  });

  assert.equal(actions.selectedTrackIndex(), 1);
});

test("SPCBoyWK keeps playback timing preferences in a playback settings module", async () => {
  assert.match(indexSource, /playlist-selection-actions\.js[\s\S]*playback-settings-actions\.js[\s\S]*app-ui\.js/);
  assert.match(playbackSettingsSource, /function setPlayTime\(/);
  assert.match(playbackSettingsSource, /function cycleRepeatMode\(/);
  assert.match(playbackSettingsSource, /function commitSpcLengthInput\(/);
  assert.match(uiSource, /return playbackSettingsActions\.setPlayTime\(nextSeconds\)/);
  assert.match(uiSource, /return playbackSettingsActions\.commitUnknownDurationInput\(rawValue\)/);
  assert.doesNotMatch(uiSource, /state\.manualPlayTimeSeconds = uiApp\.normalizeLongPlayTime\(nextSeconds\)/);

  const calls = [];
  const state = {
    manualPlayTimeSeconds: 120,
    longPlayEnabled: false,
    repeatMode: "off",
    spcFadeSeconds: 5,
    fadeEnabled: false,
    queuedSkipsEnabled: false,
    unknownDurationSeconds: 90
  };
  const actions = loadPlaybackSettings().create({
    state,
    persistSettings: () => calls.push("persist"),
    renderAll: () => calls.push("render"),
    refreshPlaybackForTimingChange: async () => calls.push("refresh"),
    normalizeLongPlayTime: (value) => Number(value) || 0,
    normalizeFadeTime: (value) => Number(value) || 0,
    normalizePlayTime: (value) => Number(value) || 0,
    parseDurationSeconds: (value) => Number(value)
  });

  actions.setPlayTime(180);
  actions.cycleRepeatMode();
  actions.commitUnknownDurationInput("240");
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(state.manualPlayTimeSeconds, 180);
  assert.equal(state.repeatMode, "all");
  assert.equal(state.unknownDurationSeconds, 240);
  assert.deepEqual(calls, ["persist", "render", "refresh", "persist", "render", "persist", "refresh"]);
});

test("SPCBoyWK keeps audio settings and native audio updates in an audio module", () => {
  assert.match(indexSource, /playback-settings-actions\.js[\s\S]*audio-settings-actions\.js[\s\S]*app-ui\.js/);
  assert.match(audioSettingsSource, /function audioSettingsPayload\(/);
  assert.match(audioSettingsSource, /function setEqualizerBandGain\(/);
  assert.match(audioSettingsSource, /function adjustAppVolume\(/);
  assert.match(uiSource, /return audioSettingsActions\.setEqualizerEnabled\(enabled\)/);
  assert.match(uiSource, /return audioSettingsActions\.adjustAppVolume\(delta\)/);
  assert.doesNotMatch(uiSource, /function audioSettingsPayload\(/);

  const calls = [];
  const state = {
    equalizerEnabled: false,
    equalizerBandGains: [0, 1.5],
    appVolume: 0.5,
    monoEnabled: false
  };
  const actions = loadAudioSettings().create({
    state,
    persistSettings: () => calls.push("persist"),
    nativePlaybackAudioConfig: (...args) => calls.push(["native", ...args]),
    setAudioSettings: (settings) => calls.push(["playback", settings]),
    normalizeEqualizerGain: (value) => Number(value),
    normalizeAppVolume: (value) => Math.max(0, Math.min(1, Number(value))),
    renderAll: () => calls.push("render")
  });

  actions.setEqualizerBandGain(0, 3);
  actions.adjustAppVolume(0.25);
  const payload = actions.audioSettingsPayload();

  assert.equal(state.equalizerBandGains[0], 3);
  assert.equal(state.appVolume, 0.75);
  assert.deepEqual(JSON.parse(JSON.stringify(payload)), {
    equalizerEnabled: false,
    equalizerBandGains: [3, 1.5],
    appVolume: 0.75,
    monoEnabled: false
  });
  assert.deepEqual(JSON.parse(JSON.stringify(calls)), [
    "persist",
    ["native", 0.5, false, [3, 1.5], false],
    ["playback", { equalizerEnabled: false, equalizerBandGains: [3, 1.5], appVolume: 0.5, monoEnabled: false }],
    "render",
    "persist",
    ["native", 0.75, false, [3, 1.5], false],
    ["playback", { equalizerEnabled: false, equalizerBandGains: [3, 1.5], appVolume: 0.75, monoEnabled: false }],
    "render"
  ]);
});

test("SPCBoyWK keeps playback speed input and enablement actions in a speed module", async () => {
  assert.match(indexSource, /audio-settings-actions\.js[\s\S]*playback-speed-actions\.js[\s\S]*app-ui\.js/);
  assert.match(playbackSpeedActionsSource, /function commitPlaybackSpeedInput\(/);
  assert.match(playbackSpeedActionsSource, /function setPlaybackSpeedEnabled\(/);
  assert.match(uiSource, /return playbackSpeedActions\.commitPlaybackSpeedInput\(backendId, rawValue\)/);
  assert.doesNotMatch(uiSource, /const parsedSpeed = uiApp\.parsePlaybackSpeed\(rawValue\)/);

  const calls = [];
  const state = {
    playbackSpeed: { numerator: 1, denominator: 1 },
    playbackSpeedEnabled: true,
    libvgmPlaybackSpeed: { numerator: 1, denominator: 1 },
    libvgmPlaybackSpeedEnabled: false
  };
  const refs = {
    playbackSpeedInput: { value: "" },
    libvgmPlaybackSpeedInput: { value: "" }
  };
  const actions = loadPlaybackSpeedActions().create({
    state,
    refs,
    persistSettings: () => calls.push("persist"),
    parsePlaybackSpeed: (value) => value === "bad" ? null : ({ numerator: 2, denominator: 1 }),
    formatPlaybackSpeed: (value) => `${value.numerator}/${value.denominator}`,
    refreshPlaybackForSpeedChange: async (backendId) => calls.push(["refresh", backendId]),
    renderAll: () => calls.push("render")
  });

  actions.commitPlaybackSpeedInput("vgm", "2");
  actions.commitPlaybackSpeedInput("vgm", "bad");
  actions.setPlaybackSpeedEnabled("libvgm", true);
  await new Promise((resolve) => setImmediate(resolve));

  assert.deepEqual(state.playbackSpeed, { numerator: 2, denominator: 1 });
  assert.equal(refs.playbackSpeedInput.value, "2/1");
  assert.equal(state.libvgmPlaybackSpeedEnabled, true);
  assert.deepEqual(calls, ["persist", ["refresh", "vgm"], "render", "persist", ["refresh", "libvgm"], "render"]);
});

test("SPCBoyWK keeps appearance preference mutations in an appearance action module", () => {
  assert.match(indexSource, /playback-speed-actions\.js[\s\S]*appearance-actions\.js[\s\S]*app-ui\.js/);
  assert.match(appearanceActionsSource, /function setFontSize\(/);
  assert.match(appearanceActionsSource, /function setAnimationTiming\(/);
  assert.match(appearanceActionsSource, /function applyAppearanceSettings\(/);
  assert.match(uiSource, /return appearanceActions\.setFontSize\(nextSize\)/);
  assert.match(uiSource, /return appearanceActions\.applyAppearanceSettings\(settings\)/);
  assert.doesNotMatch(uiSource, /const interfaceFontSize = settings\.uiFontSizePt/);

  const calls = [];
  const state = {
    uiItemSpacingRem: 0.4,
    sidebarWidthPercent: 25,
    uiFontSizePt: 12,
    sidebarFontSizePt: 12,
    playlistFontSizePt: 12,
    sidebarTextColor: "#111111",
    playlistTextColor: "#111111",
    applicationMonospace: false,
    sidebarMonospace: false,
    playlistMonospace: false,
    sidebarPathCounts: false,
    playlistHeaderBold: false,
    accentColor: "#000000",
    selectionAnimationMilliseconds: 100,
    mainWindowAlwaysOnTop: false
  };
  const actions = loadAppearanceActions().create({
    state,
    persistSettings: () => calls.push("persist"),
    broadcastAppearanceSettings: () => calls.push("broadcast"),
    renderAll: () => calls.push("render"),
    renderPlaylist: () => calls.push("playlist"),
    renderSidebar: () => calls.push("sidebar"),
    invalidateDatabaseSidebar: () => calls.push("invalidate"),
    normalizeItemSpacing: Number,
    normalizeFontSize: Number,
    normalizeSidebarWidth: Number,
    normalizeFontColor: (value) => String(value).toLowerCase(),
    normalizeAccentColor: (value) => String(value).toLowerCase(),
    normalizeAnimationMilliseconds: (value) => Number(value),
    parseNumericInput: (value) => Number(value),
    setAnimation: (key, value, normalize) => { state[key] = normalize(value); },
    setWindowLevel: (key, enabled) => { state[key] = Boolean(enabled); }
  });

  actions.setFontSize(14);
  actions.setAnimationTiming("selectionAnimationMilliseconds", 240);
  actions.setWindowAlwaysOnTop("mainWindowAlwaysOnTop", true);
  actions.applyAppearanceSettings({
    uiItemSpacingRem: 0.6,
    sidebarWidthPercent: 30,
    uiFontSizePt: 15,
    sidebarTextColor: "#ABCDEF",
    applicationMonospace: true,
    sidebarPathCounts: true,
    playlistHeaderBold: true,
    accentColor: "#FEDCBA"
  });

  assert.equal(state.uiFontSizePt, 15);
  assert.equal(state.sidebarFontSizePt, 15);
  assert.equal(state.playlistFontSizePt, 15);
  assert.equal(state.sidebarWidthPercent, 30);
  assert.equal(state.sidebarTextColor, "#abcdef");
  assert.equal(state.playlistTextColor, "#abcdef");
  assert.equal(state.applicationMonospace, true);
  assert.equal(state.sidebarMonospace, true);
  assert.equal(state.playlistMonospace, true);
  assert.equal(state.selectionAnimationMilliseconds, 240);
  assert.equal(state.mainWindowAlwaysOnTop, true);
  assert.equal(state.accentColor, "#fedcba");
  assert.deepEqual(calls, [
    "persist", "broadcast", "render",
    "persist", "render",
    "persist", "render",
    "persist", "render"
  ]);
});

test("SPCBoyWK keeps archive cache configuration actions in an archive cache module", async () => {
  assert.match(indexSource, /appearance-actions\.js[\s\S]*archive-cache-actions\.js[\s\S]*app-ui\.js/);
  assert.match(archiveCacheActionsSource, /async function applyArchiveCacheSettings\(/);
  assert.match(archiveCacheActionsSource, /function setArchiveCacheEnabled\(/);
  assert.match(uiSource, /return archiveCacheActions\.setArchiveCacheLimit\(value\)/);
  assert.doesNotMatch(uiSource, /const configured = await window\.spcBoyWK\?\.configureArchiveCache/);

  const calls = [];
  const state = {
    archiveCacheEnabled: false,
    archiveCacheLimitBytes: 100,
    archiveCacheSummary: null
  };
  const actions = loadArchiveCacheActions().create({
    state,
    persistSettings: () => calls.push("persist"),
    configureArchiveCache: async (settings) => {
      calls.push(["configure", settings]);
      return { enabled: settings.enabled, limitBytes: settings.limitBytes, summary: { files: 2 } };
    },
    normalizeArchiveCacheLimit: (value) => Number(value) * 10,
    renderAll: () => calls.push("render")
  });

  actions.setArchiveCacheEnabled(true);
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(state.archiveCacheEnabled, true);
  assert.deepEqual(JSON.parse(JSON.stringify(state.archiveCacheSummary)), { files: 2, enabled: true, limitBytes: 100 });
  assert.deepEqual(JSON.parse(JSON.stringify(calls)), [
    "persist",
    ["configure", { enabled: true, limitBytes: 100 }],
    "render",
    "render"
  ]);

  calls.length = 0;
  actions.setArchiveCacheLimit("25");
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(state.archiveCacheLimitBytes, 250);
});

test("SPCBoyWK keeps backend routing preference actions in a routing module", async () => {
  assert.match(indexSource, /archive-cache-actions\.js[\s\S]*routing-actions\.js[\s\S]*app-ui\.js/);
  assert.match(routingActionsSource, /function setRoutingPreference\(/);
  assert.match(routingActionsSource, /function applyRoutingPreferences\(/);
  assert.match(uiSource, /return routingActions\.setRoutingPreference\(extension, backendId\)/);
  assert.doesNotMatch(uiSource, /const nextPreferences = \{ \.\.\.state\.routingPreferences \}/);

  const calls = [];
  const state = { routingPreferences: {} };
  const actions = loadRoutingActions().create({
    state,
    persistSettings: () => calls.push("persist"),
    candidatesForPath: () => [{ id: "default" }, { id: "alternate" }],
    setRoutingPreferences: async (preferences) => {
      calls.push(["native", preferences]);
      return { ...preferences, normalized: true };
    },
    renderAll: () => calls.push("render")
  });

  actions.setRoutingPreference(".vgz", "alternate");
  await new Promise((resolve) => setImmediate(resolve));
  assert.deepEqual(JSON.parse(JSON.stringify(state.routingPreferences)), { ".vgz": "alternate", normalized: true });
  assert.deepEqual(JSON.parse(JSON.stringify(calls)), [
    "persist",
    ["native", { ".vgz": "alternate" }],
    "render",
    "persist",
    "render"
  ]);

  actions.applyRoutingPreferences(null);
  assert.deepEqual(JSON.parse(JSON.stringify(state.routingPreferences)), {});
});

test("SPCBoyWK keeps favorite snapshots and selection toggles in a favorite action module", async () => {
  assert.match(indexSource, /routing-actions\.js[\s\S]*favorite-actions\.js[\s\S]*app-ui\.js/);
  assert.match(favoriteActionsSource, /function applyFavoriteSnapshot\(/);
  assert.match(favoriteActionsSource, /async function toggleSelectedFavorites\(/);
  assert.match(uiSource, /return favoriteActions\.refreshFavorites\(\)/);
  assert.match(uiSource, /return favoriteActions\.toggleSelectedFavorites\(\)/);
  assert.doesNotMatch(uiSource, /window\.spcBoyWK\.favoritesList\(state\.favoriteSortOrder\)/);

  const calls = [];
  const state = {
    favoriteSortOrder: "historical",
    favorites: [],
    favoriteIds: [],
    playlist: [{ id: "track-a", favoriteId: "fav-a" }],
    selectedTrackIds: ["track-a"],
    selectedDatabaseGameKey: null,
    selectedDatabaseConsoleName: null
  };
  const actions = loadFavoriteActions().create({
    state,
    listFavorites: async (sortOrder) => {
      calls.push(["list", sortOrder]);
      return [{ favoriteId: "fav-a", name: "Track A" }];
    },
    toggleFavoriteTracks: async (tracks, sortOrder) => {
      calls.push(["toggle", tracks, sortOrder]);
      return tracks.map((track) => ({ ...track, favoriteId: track.favoriteId || "fav-a" }));
    },
    renderSidebar: () => calls.push("sidebar"),
    renderPlaylist: () => calls.push("playlist"),
    isSidebarFocused: () => false,
    visibleDatabaseGames: () => [],
    databaseGameKey: () => "",
    databaseConsoleName: () => "",
    databaseGameTracks: async () => [],
    databaseRowsToPlaylistTracks: (rows) => rows
  });

  await actions.refreshFavorites();
  await actions.toggleSelectedFavorites();

  assert.equal(actions.isFavoritePresentation({ favoriteId: "fav-a" }), true);
  assert.equal(actions.isFavoritePresentation({ favoriteId: "fav-missing" }), false);
  assert.deepEqual(JSON.parse(JSON.stringify(state.favorites)), [{ id: "track-a", favoriteId: "fav-a" }]);
  assert.deepEqual(JSON.parse(JSON.stringify(calls)), [
    ["list", "historical"],
    ["toggle", [{ id: "track-a", favoriteId: "fav-a" }], "historical"],
    "sidebar",
    "playlist"
  ]);
});

test("SPCBoyWK keeps shared playlist append mutation in a playlist mutation module", () => {
  assert.match(indexSource, /favorite-actions\.js[\s\S]*playlist-mutation-actions\.js[\s\S]*app-ui\.js/);
  assert.match(playlistMutationActionsSource, /function appendPlaylistTracks\(/);
  assert.match(uiSource, /return playlistMutationActions\.appendPlaylistTracks\(additions, selectedBrowserPath\)/);
  assert.doesNotMatch(uiSource, /const existingIds = new Set\(state\.playlist\.map/);

  const calls = [];
  const state = {
    selectedBrowserPath: "old-path",
    playlist: [{ id: "existing" }],
    selectedTrackId: "existing",
    lastSelectedTrackId: "existing"
  };
  const actions = loadPlaylistMutationActions().create({
    state,
    persistSettings: () => calls.push("persist"),
    renderTree: () => calls.push("tree"),
    syncTreeSelection: () => calls.push("selection"),
    renderPlaylist: () => calls.push("playlist"),
    updateTimingSummary: () => calls.push("timing")
  });

  actions.appendPlaylistTracks([{ id: "existing" }, { id: "new-a" }, { id: "new-b" }], "new-path");
  actions.appendPlaylistTracks([{ id: "new-a" }], "ignored-path");

  assert.deepEqual(JSON.parse(JSON.stringify(state)), {
    selectedBrowserPath: "new-path",
    playlist: [{ id: "existing" }, { id: "new-a" }, { id: "new-b" }],
    selectedTrackId: "new-a",
    lastSelectedTrackId: "new-a"
  });
  assert.deepEqual(calls, ["persist", "tree", "selection", "playlist", "timing"]);
});

test("SPCBoyWK keeps edge navigation in a navigation action module", () => {
  assert.match(indexSource, /playlist-mutation-actions\.js[\s\S]*navigation-actions\.js[\s\S]*app-ui\.js/);
  assert.match(navigationActionsSource, /function scrollSelectedBrowserItemIntoView\(/);
  assert.match(navigationActionsSource, /function jumpFocusedListToEdge\(/);
  assert.match(uiSource, /return navigationActions\.jumpFocusedListToEdge\(toEnd, focused\)/);
  assert.doesNotMatch(uiSource, /const games = \[\.\.\.refs\.treeRoot\.querySelectorAll\("\.database-console-games/);

  const calls = [];
  const treeRoot = {
    contains: (value) => value === "tree-focus",
    querySelectorAll: () => []
  };
  const playlistBody = { contains: (value) => value === "playlist-focus" };
  const state = { selectedBrowserPath: "folder/a", playlist: [{ id: "track-a" }, { id: "track-b" }] };
  const actions = loadNavigationActions().create({
    state,
    refs: {
      treeRoot,
      playlistBody: { ...playlistBody, querySelector: () => null }
    },
    currentSidebarView: () => ({ contentMode: "tree" }),
    visibleBrowserNodes: () => [{ path: "first" }, { path: "last" }],
    selectBrowserNode: (node, options) => calls.push(["browser", node.path, options]),
    selectPlaylistTrack: (trackId, options) => calls.push(["playlist", trackId, options]),
    updateTimingSummary: () => calls.push("timing")
  });

  assert.equal(actions.jumpFocusedListToEdge(true, "tree-focus"), true);
  assert.equal(actions.jumpFocusedListToEdge(false, "playlist-focus"), true);
  assert.equal(actions.jumpFocusedListToEdge(false, "other-focus"), false);
  assert.deepEqual(JSON.parse(JSON.stringify(calls)), [
    ["browser", "last", { focus: true }],
    ["playlist", "track-a", { focus: true }],
    "timing"
  ]);
});

test("SPCBoyWK keeps shared sidebar disclosure transitions in a collapse action module", async () => {
  assert.match(indexSource, /navigation-actions\.js[\s\S]*sidebar-collapse-actions\.js[\s\S]*app-ui\.js/);
  assert.match(sidebarCollapseActionsSource, /async function applySharedDatabaseGroupAction\(/);
  assert.match(sidebarCollapseActionsSource, /async function setAllSidebarNodesCollapsed\(/);
  assert.match(uiSource, /return sidebarCollapseActions\.setAllSidebarNodesCollapsed\(collapsed\)/);
  assert.doesNotMatch(uiSource, /let databaseGroupTransitionGeneration/);

  const calls = [];
  const collapsedDatabaseConsoles = new Set(["SNES"]);
  const expandedFolders = new Set(["old-folder"]);
  const state = {
    selectedDatabaseConsoleName: "SNES",
    selectedDatabaseGameKey: "game",
    collapsedConsoleNames: [],
    sidebarView: { contentMode: "tree", view: "paths" },
    databaseFileTree: [{ path: "catalog-root" }],
    rootPath: "/library",
    selectedBrowserPath: "old-path",
    tree: []
  };
  const actions = loadSidebarCollapseActions().create({
    state,
    collapsedDatabaseConsoles,
    expandedFolders,
    databaseConsoleNames: () => ["SNES", "PSP"],
    databaseGroupState: async (snapshot, action, groupName, gameID) => {
      calls.push([snapshot, action, groupName, gameID]);
      return { expandedGroupNames: ["PSP"], selectedGroupName: "PSP", selectedGameID: "new-game" };
    },
    persistSettings: () => calls.push("persist"),
    currentSidebarView: () => state.sidebarView,
    loadBrowserChildren: async () => {},
    renderDatabaseGames: () => calls.push("database"),
    renderTree: () => calls.push("tree"),
    syncTreeSelection: () => calls.push("selection"),
    reportDatabaseSidebarError: () => calls.push("error")
  });

  await actions.setAllDatabaseConsolesCollapsed(true);
  assert.equal(collapsedDatabaseConsoles.has("SNES"), true);
  assert.equal(collapsedDatabaseConsoles.has("PSP"), false);
  assert.equal(state.selectedDatabaseConsoleName, "PSP");
  assert.equal(state.selectedDatabaseGameKey, "new-game");
  assert.deepEqual(JSON.parse(JSON.stringify(calls.at(-1))), "database");

  await actions.setAllSidebarNodesCollapsed(true);
  assert.equal(expandedFolders.size, 0);
  assert.equal(state.selectedBrowserPath, "catalog-root");
  assert.deepEqual(calls.slice(-3), ["persist", "tree", "selection"]);
});

test("SPCBoyWK keeps library and folder selection state transitions in a library module", () => {
  assert.match(indexSource, /sidebar-collapse-actions\.js[\s\S]*library-selection-actions\.js[\s\S]*app-ui\.js/);
  assert.match(librarySelectionActionsSource, /function applyLibrarySnapshot\(/);
  assert.match(librarySelectionActionsSource, /function applyFolderSelection\(/);
  assert.match(uiSource, /return librarySelectionActions\.applyFolderSelection\(selection\)/);
  assert.doesNotMatch(uiSource, /state\.localBrowserEnabled = true/);

  const calls = [];
  const state = {
    currentTrackId: null,
    selectedBrowserPath: "folder/a",
    selectedFolderPath: null,
    playlist: [],
    selectedTrackId: null,
    lastSelectedTrackId: null,
    totalSeconds: 0,
    databaseGames: [],
    localBrowserEnabled: false,
    sidebarMode: "consoles",
    sidebarQuery: "old",
    selectedDatabaseGameKey: "game"
  };
  const refs = {
    sidebarSearchInput: { value: "old" },
    treeRoot: { querySelector: () => null }
  };
  const actions = loadLibrarySelectionActions().create({
    state,
    refs,
    rebuildDatabaseGameSearchIndex: (games) => calls.push(["index", games]),
    resolveSelectedTrackId: (playlist) => playlist[0]?.id || null,
    targetPlaybackSeconds: () => 42,
    persistSettings: () => calls.push("persist"),
    renderAll: () => calls.push("all"),
    syncTreeSelection: () => calls.push("selection"),
    scrollSelectedTrackIntoView: () => calls.push("scroll"),
    renderTree: () => calls.push("tree"),
    renderPlaylist: () => calls.push("playlist"),
    updateTimingSummary: () => calls.push("timing"),
    updatePlaybackReadout: () => calls.push("readout"),
    isBrowserFocused: () => true,
    focusSelectedBrowserNode: (path) => calls.push(["focus", path])
  });

  actions.applyFolderSelection({ selectedFolderPath: "folder", playlist: [{ id: "track-a" }] });
  assert.equal(state.selectedFolderPath, "folder");
  assert.equal(state.selectedTrackId, "track-a");
  assert.equal(state.totalSeconds, 42);
  assert.deepEqual(calls, ["persist", "tree", "selection", ["focus", "folder/a"], "playlist", "timing", "readout", "scroll"]);

  calls.length = 0;
  actions.applyLibrarySnapshot({
    rootPath: "/new-library",
    databaseGames: [{ name: "Game" }],
    playlist: [{ id: "track-b" }]
  });
  assert.equal(state.localBrowserEnabled, true);
  assert.equal(state.sidebarMode, "diskPath");
  assert.equal(state.sidebarQuery, "");
  assert.equal(state.selectedDatabaseGameKey, null);
  assert.equal(refs.sidebarSearchInput.value, "");
  assert.deepEqual(calls, [["index", [{ name: "Game" }]], "persist", "all", "selection", "scroll"]);
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
