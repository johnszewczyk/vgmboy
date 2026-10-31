import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
const source = await readFile(new URL('../Sources/SB2/Resources/app-playback.js', import.meta.url), 'utf8');
const start = source.indexOf('function playTrack('), end = source.indexOf('\nasync function completeQueuedSkip()', start);
assert.ok(start >= 0 && end > start);
function deferred() { let resolve, reject; const promise = new Promise((a, b) => { resolve = a; reject = b; }); return { promise, resolve, reject }; }
function harness(startTrack, queued = true, ramp = async () => {}) {
  const state = { currentTrackId: 'old', isPlaying: true, nativePlayback: { generation: 42, trackLoaded: true },
    playingPlaylist: [{ id: 'new' }], playlist: [{ id: 'new' }] }, ramps = [], errors = [];
  const run = new Function('state', 'startTrack', 'ramps', 'errors', 'queued', 'ramp', `
    let playbackGeneration = 7, pendingPlaybackIntent = null;
    let queuedSkipRequest = queued ? { nativeGeneration: 42 } : null;
    const invalidateQueuedSkip = () => { queuedSkipRequest = null; };
    const TRANSPORT_DECLICK_MS = 10;
    const window = { spcBoySB2: { nativePlaybackRestoreQueuedSkipGain: async r => { ramps.push(r); await ramp(); } } };
    const beginPlaybackIntent = () => (pendingPlaybackIntent = {});
    const finishPlaybackIntent = async intent => { if (pendingPlaybackIntent === intent) pendingPlaybackIntent = null; };
    const clearPlaybackError = () => {}, clearQueuedSkipTimer = () => {}, showPlaybackError = error => errors.push(error.message);
    const playTrackNow = () => { playbackGeneration++; return startTrack(); };
    const playTrackWithFadedSkip = playTrackNow;
    ${source.slice(start, end)}
    return { playTrack, replan: () => { playbackGeneration++; }, supersede: () => { pendingPlaybackIntent = {}; } };
  `)(state, startTrack, ramps, errors, queued, ramp);
  return { ...run, ramps, errors };
}

test('selection replacing a queued fade restores the retained session on failure', async () => {
  const run = harness(async () => { throw new Error('missing source'); });
  await assert.rejects(run.playTrack('new'), /missing source/);
  assert.deepEqual(run.ramps, [{ rampMilliseconds: 10, expectedGeneration: 42 }]);
  assert.deepEqual(run.errors, ['missing source']);
});

test('timing replanning within the same intent still restores on failure', async () => {
  const pending = deferred(), run = harness(() => pending.promise);
  const playing = run.playTrack('new'); run.replan(); pending.reject(new Error('missing source'));
  await assert.rejects(playing, /missing source/);
  assert.equal(run.ramps[0].expectedGeneration, 42);
});

test('superseded replacement does not restore the older intent', async () => {
  const pending = deferred(), run = harness(() => pending.promise, false);
  const playing = run.playTrack('new', 0, true, null, 42); run.supersede(); pending.reject(new Error('superseded'));
  await assert.rejects(playing, /superseded/);
  assert.deepEqual(run.ramps, []);
  assert.deepEqual(run.errors, []);
});

test('a newer intent during gain restoration suppresses the old error', async () => {
  const restore = deferred(), run = harness(async () => { throw new Error('missing source'); }, true, () => restore.promise);
  const playing = run.playTrack('new');
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(run.ramps.length, 1);
  run.supersede(); restore.resolve();
  await assert.rejects(playing, /missing source/);
  assert.deepEqual(run.errors, []);
});
