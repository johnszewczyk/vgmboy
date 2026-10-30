import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const source = await readFile(new URL('../Sources/SB2/Resources/app-playback.js', import.meta.url), 'utf8');
function section(startMarker, endMarker) {
  const start = source.indexOf(startMarker), end = source.indexOf(endMarker, start);
  assert.ok(start >= 0 && end > start);
  return source.slice(start, end);
}
const cancel = section('async function cancelQueuedSkip(', '\nasync function playTrackNow(');
const seek = section('async function restartAt(', '\nasync function refreshPlaybackForTimingChange(');
function harness({ skipGeneration = 42, currentGeneration = 42, restore = async () => {} } = {}) {
  const state = { currentTrackId: 'one', elapsedSeconds: 0, totalSeconds: 20,
    nativePlayback: { generation: currentGeneration, trackLoaded: true } };
  const ramps = [], seeks = [];
  const run = new Function('state', 'restore', 'ramps', 'seeks', `
    let queuedSkipRequest = { nativeGeneration: ${skipGeneration} }, playbackGeneration = 0;
    let nativePlaybackInitialized = true;
    const TRANSPORT_DECLICK_MS = 10, activeTrackInfo = () => ({ id: 'one' });
    const clearQueuedSkipTimer = () => {}, updatePlaybackReadout = () => {}, updateNativeDiagnostics = () => {};
    const applyNativePlaybackSnapshot = () => {}, currentNativeGeneration = () => state.nativePlayback.generation;
    const window = { spcBoySB2: { nativePlaybackRampGain: async value => { ramps.push(value); await restore(); },
      nativePlaybackSeek: async value => { seeks.push(value); return {}; } } };
    ${cancel}
    ${seek}
    return { restartAt };
  `)(state, restore, ramps, seeks);
  return { ...run, ramps, seeks };
}

test('a failed fade restore does not block a current-session seek', async () => {
  const run = harness({ restore: async () => { throw new Error('stale ramp'); } });
  await run.restartAt(5);
  assert.deepEqual(run.seeks, [{ positionMilliseconds: 5000, expectedGeneration: 42 }]);
  assert.equal(run.ramps.length, 1);
});

test('canceling an old-generation fade skips its obsolete gain request', async () => {
  const run = harness({ skipGeneration: 41, currentGeneration: 42 });
  await run.restartAt(5);
  assert.deepEqual(run.ramps, []);
  assert.deepEqual(run.seeks, [{ positionMilliseconds: 5000, expectedGeneration: 42 }]);
});
