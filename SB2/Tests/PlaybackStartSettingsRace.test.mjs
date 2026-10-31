import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const source = await readFile(new URL('../Sources/SB2/Resources/app-playback.js', import.meta.url), 'utf8');
const start = source.indexOf('async function playTrackNow(');
const end = source.indexOf('\nfunction playTrack(', start);
assert.ok(start >= 0 && end > start);
const makePlayer = new Function('env', `
  const { state, playbackPlaylist, resolveTimingPlan, stopAllOutput,
    setPlaybackPowerSaveBlocker, ensureNativePlaybackInitialized, window,
    applyNativePlaybackSnapshot, refreshPlaybackForTimingChange } = env;
  let playbackGeneration = 0, playbackSettingsGeneration = 0, playbackWindow = null;
  let nativePlaybackInitialized = true;
  const playbackApp = { ui: { refreshPlaylistPlaybackState() {} } };
  const currentTotalSeconds = () => 10, currentOutputBasePlaybackSeconds = () => 10;
  const currentFadeSeconds = () => 0, requestedPlaybackSpeed = () => ({ numerator: 1, denominator: 1 });
  const resetNativePlaybackSnapshot = () => {}, updatePlaybackReadout = () => {}, updateNativeDiagnostics = () => {};
  ${source.slice(start, end)}
  return { playTrackNow, changeSettings: () => { playbackSettingsGeneration++; },
    replaceTrack: () => { playbackGeneration++; } };
`);
function deferred() { let resolve; const promise = new Promise(r => { resolve = r; }); return { promise, resolve }; }
function harness({ timing, startNative, initialize } = {}) {
  const track = { id: 'one', path: '/tmp/one.wav' };
  const calls = [], refreshes = [];
  const env = {
    state: { unknownDurationSeconds: 150 }, playbackPlaylist: () => [track],
    resolveTimingPlan: timing ?? (async () => ({ is_long_play: false })),
    stopAllOutput: async () => {}, setPlaybackPowerSaveBlocker: async () => {},
    ensureNativePlaybackInitialized: initialize ?? (async () => {}),
    window: { spcBoySB2: { nativePlaybackStart: request => { calls.push(request); return startNative ? startNative() : Promise.resolve({}); } } },
    applyNativePlaybackSnapshot: () => {}, refreshPlaybackForTimingChange: async () => { refreshes.push(true); }
  };
  return { ...makePlayer(env), calls, refreshes };
}

test('a timing change during planning starts with a fresh plan', async () => {
  const pending = deferred();
  let calls = 0;
  const run = harness({ timing: () => ++calls === 1 ? pending.promise : Promise.resolve({ is_long_play: false }) });
  const playing = run.playTrackNow('one');
  run.changeSettings();
  pending.resolve({ is_long_play: true });
  await playing;
  assert.equal(calls, 2);
  assert.equal(run.calls.length, 1);
  assert.equal(run.calls[0].longPlayEnabled, false);
});

test('a timing change during initialization replaces the prepared start', async () => {
  const pending = deferred();
  let initializations = 0, plans = 0;
  const run = harness({
    timing: async () => ({ is_long_play: ++plans === 1 }),
    initialize: () => ++initializations === 1 ? pending.promise : Promise.resolve()
  });
  const playing = run.playTrackNow('one');
  while (!initializations) await new Promise(resolve => setImmediate(resolve));
  run.changeSettings();
  pending.resolve();
  await playing;
  assert.equal(plans, 2);
  assert.equal(run.calls.length, 1);
  assert.equal(run.calls[0].longPlayEnabled, false);
});

test('a timing change during native start is applied to the started session', async () => {
  const pending = deferred();
  const run = harness({ startNative: () => pending.promise });
  const playing = run.playTrackNow('one');
  while (!run.calls.length) await new Promise(resolve => setImmediate(resolve));
  run.changeSettings();
  pending.resolve({});
  await playing;
  assert.equal(run.refreshes.length, 1);
});

test('a replaced pending start cannot apply settings to the newer session', async () => {
  const pending = deferred();
  const run = harness({ startNative: () => pending.promise });
  const playing = run.playTrackNow('one');
  while (!run.calls.length) await new Promise(resolve => setImmediate(resolve));
  run.changeSettings();
  run.replaceTrack();
  pending.resolve({});
  await playing;
  assert.equal(run.refreshes.length, 0);
});

function replacementHarness({ startNative, nativeState }) {
  const old = { id: 'old', path: '/tmp/old.wav' };
  const next = { id: 'new', path: '/tmp/new.zip', archivePath: '/tmp/new.zip', archiveEntry: 'song.spc' };
  const state = { currentTrackId: old.id, currentTrackInfo: old, isPlaying: true,
    nativePlayback: { generation: 12, trackLoaded: true }, unknownDurationSeconds: 150 };
  let stops = 0, closes = 0;
  const env = {
    state, playbackPlaylist: () => [old, next], resolveTimingPlan: async () => ({ is_long_play: false }),
    stopAllOutput: async () => { stops++; }, setPlaybackPowerSaveBlocker: async () => {},
    ensureNativePlaybackInitialized: async () => {},
    window: { spcBoySB2: { nativePlaybackStart: startNative,
      nativePlaybackState: nativeState, nativePlaybackClose: async () => { closes++; } } },
    applyNativePlaybackSnapshot: () => {}, refreshPlaybackForTimingChange: async () => {}
  };
  const run = makePlayer(env);
  return { ...run, state, get stops() { return stops; }, get closes() { return closes; } };
}

test('preparation failure retains the playing session without unloading it', async () => {
  const failure = new Error('missing archive');
  const run = replacementHarness({ startNative: async () => { throw failure; },
    nativeState: async () => ({ track_loaded: true, generation: 12, transport_state: 'playing' }) });
  await assert.rejects(run.playTrackNow('new'), /missing archive/);
  assert.equal(run.stops, 0);
  assert.equal(run.closes, 0);
  assert.equal(run.state.currentTrackId, 'old');
  assert.equal(run.state.isPlaying, true);
});

test('an unavailable status reply does not close a possibly retained session', async () => {
  const run = replacementHarness({ startNative: async () => { throw new Error('prepare failed'); },
    nativeState: async () => { throw new Error('status unavailable'); } });
  await assert.rejects(run.playTrackNow('new'), /prepare failed/);
  assert.equal(run.closes, 0);
  assert.equal(run.state.currentTrackId, 'old');
});

test('a failure cannot close a different loaded native session', async () => {
  const run = replacementHarness({ startNative: async () => { throw new Error('prepare failed'); },
    nativeState: async () => ({ track_loaded: true, generation: 13 }) });
  await assert.rejects(run.playTrackNow('new'), /prepare failed/);
  assert.equal(run.closes, 0);
});

test('replacement publishes its identity only after native start succeeds', async () => {
  const pending = deferred();
  const run = replacementHarness({ startNative: () => pending.promise, nativeState: async () => ({}) });
  const oldQueue = [{ id: 'old' }], newQueue = [{ id: 'new', path: '/tmp/new.zip', archivePath: '/tmp/new.zip', archiveEntry: 'song.spc' }];
  run.state.playingPlaylist = oldQueue;
  run.state.playbackTabId = 'old-tab';
  const playing = run.playTrackNow('new', 0, { pendingQueue: newQueue, pendingTabId: 'new-tab' });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(run.state.currentTrackId, 'old');
  assert.equal(run.state.playingPlaylist, oldQueue);
  assert.equal(run.state.playbackTabId, 'old-tab');
  pending.resolve({ generation: 13, track_loaded: true });
  await playing;
  assert.equal(run.state.currentTrackId, 'new');
  assert.equal(run.state.playingPlaylist, newQueue);
  assert.equal(run.state.playbackTabId, 'new-tab');
  assert.equal(run.stops, 0);
});

test('failure after native replacement clears the failed session', async () => {
  const run = replacementHarness({ startNative: async () => { throw new Error('decoder failed'); },
    nativeState: async () => ({ track_loaded: false, generation: 13 }) });
  await assert.rejects(run.playTrackNow('new'), /decoder failed/);
  assert.equal(run.state.isPlaying, false);
  assert.equal(run.closes, 1);
});

test('superseded replacement failure cannot close the newer session', async () => {
  let reject;
  const pending = new Promise((_, fail) => { reject = fail; });
  const run = replacementHarness({ startNative: () => pending, nativeState: async () => ({ track_loaded: false }) });
  const playing = run.playTrackNow('new');
  await new Promise(resolve => setImmediate(resolve));
  run.replaceTrack();
  reject(new Error('superseded'));
  await playing;
  assert.equal(run.closes, 0);
  assert.equal(run.state.currentTrackId, 'old');
});

test('a cross-tab start stages the new queue until the handoff', async () => {
  const wrapperStart = source.indexOf('function playTrack(');
  const wrapperEnd = source.indexOf('\nasync function playTrackWithFadedSkip(', wrapperStart);
  assert.ok(wrapperStart >= 0 && wrapperEnd > wrapperStart);
  const oldQueue = [{ id: 'old' }], newQueue = [{ id: 'new' }];
  const state = { playingPlaylist: oldQueue, playlist: newQueue, playbackTabId: 'old-tab',
    activePlaylistTabId: 'new-tab', currentTrackId: 'old', isPlaying: true };
  let options;
  const run = new Function('state', 'receive', `
    let queuedSkipRequest = null, pendingPlaybackIntent = null;
    const beginPlaybackIntent = () => (pendingPlaybackIntent = {}), finishPlaybackIntent = async () => {};
    const clearPlaybackError = () => {}, clearQueuedSkipTimer = () => {}, showPlaybackError = () => {};
    const playTrackWithFadedSkip = async (_, __, value) => receive(value);
    const playTrackNow = playTrackWithFadedSkip;
    ${source.slice(wrapperStart, wrapperEnd)}
    return playTrack;
  `)(state, value => { options = value; });
  await run('new');
  assert.equal(state.playingPlaylist, oldQueue);
  assert.equal(state.playbackTabId, 'old-tab');
  assert.deepEqual(options.pendingQueue, newQueue);
  assert.equal(options.pendingTabId, 'new-tab');
});

test('queued handoff passes its original native generation through start options', async () => {
  const wrapperStart = source.indexOf('function playTrack(');
  const wrapperEnd = source.indexOf('\nasync function completeQueuedSkip()', wrapperStart);
  const state = { playingPlaylist: [{ id: 'new' }], playlist: [{ id: 'new' }], currentTrackId: 'old', isPlaying: true };
  let options;
  const run = new Function('state', 'receive', `
    let queuedSkipRequest = null, pendingPlaybackIntent = null;
    const beginPlaybackIntent = () => (pendingPlaybackIntent = {}), finishPlaybackIntent = async () => {};
    const clearPlaybackError = () => {}, clearQueuedSkipTimer = () => {}, showPlaybackError = () => {};
    const playTrackNow = async (_, __, value) => receive(value), playTrackWithFadedSkip = playTrackNow;
    ${source.slice(wrapperStart, wrapperEnd)}
    return playTrack;
  `)(state, value => { options = value; });
  await run('new', 0, true, null, 42);
  assert.equal(options.expectedPreviousGeneration, 42);
});

test('queued handoff sends the captured native generation to the bridge', async () => {
  const run = harness();
  await run.playTrackNow('one', 0, { expectedPreviousGeneration: 42 });
  assert.equal(run.calls[0].expectedPreviousGeneration, 42);
});
