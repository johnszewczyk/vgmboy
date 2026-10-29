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
