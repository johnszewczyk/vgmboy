import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const source = await readFile(new URL('../Sources/SB2/Resources/app-playback.js', import.meta.url), 'utf8');
const start = source.indexOf('async function togglePlayback()');
const end = source.indexOf('\nasync function restartAt(', start);
assert.ok(start >= 0 && end > start);
function deferred() { let reject; const promise = new Promise((_, fail) => { reject = fail; }); return { promise, reject }; }
function harness(pause, ramp = async () => {}) {
  const state = { currentTrackId: 'one', isPlaying: true, nativePlayback: { generation: 42, trackLoaded: true, transportState: 'playing' } };
  const requests = [];
  const run = new Function('state', 'pause', 'ramp', 'requests', `
    let playbackGeneration = 0, queuedSkipRequest = null, nativePlaybackInitialized = true;
    const TRANSPORT_DECLICK_MS = 10, activeTrackInfo = () => ({ id: 'one' });
    const currentNativeGeneration = () => 42, fadeActiveOutput = async () => {};
    const clearQueuedSkipTimer = () => {}, setPlaybackPowerSaveBlocker = async () => {};
    const applyNativePlaybackSnapshot = () => {}, updatePlaybackReadout = () => {};
    const window = { spcBoySB2: { nativePlaybackPause: pause,
      nativePlaybackRampGain: async request => { requests.push(request); await ramp(); } } };
    ${source.slice(start, end)}
    return { togglePlayback, supersede: () => { playbackGeneration++; } };
  `)(state, pause, ramp, requests);
  return { ...run, requests };
}

test('failed pause restores the original session gain', async () => {
  const run = harness(async () => { throw new Error('pause failed'); });
  await assert.rejects(run.togglePlayback(), /pause failed/);
  assert.deepEqual(run.requests, [{ outputGain: 1, rampMilliseconds: 10, expectedGeneration: 42 }]);
});

test('a superseded pause does not restore gain on the new intent', async () => {
  const pending = deferred(), run = harness(() => pending.promise);
  const pausing = run.togglePlayback();
  await new Promise(resolve => setImmediate(resolve));
  run.supersede(); pending.reject(new Error('pause failed'));
  await assert.rejects(pausing, /pause failed/);
  assert.deepEqual(run.requests, []);
});

test('failed gain recovery preserves the original pause error', async () => {
  const run = harness(async () => { throw new Error('pause failed'); }, async () => { throw new Error('ramp failed'); });
  await assert.rejects(run.togglePlayback(), /pause failed/);
});
