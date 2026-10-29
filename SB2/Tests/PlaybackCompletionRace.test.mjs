import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const source = await readFile(new URL('../Sources/SB2/Resources/app-playback.js', import.meta.url), 'utf8');
function section(startMarker, endMarker) {
  const start = source.indexOf(startMarker);
  const end = source.indexOf(endMarker, start);
  assert.ok(start >= 0 && end > start, `${startMarker} is present`);
  return source.slice(start, end);
}
const finalizeSource = section('async function finalizePlaybackEnded() {', '\nasync function continueAfterPlaybackRetirement(');
const makeFinalizer = new Function('state', 'window', 'playbackPlaylist', 'continueAfterPlaybackRetirement', `
  let playbackGeneration = 7;
  let queuedSkipRequest = null;
  ${finalizeSource}
  return { finalizePlaybackEnded, setGeneration: value => { playbackGeneration = value; } };
`);

function deferred() {
  let resolve;
  const promise = new Promise((complete) => { resolve = complete; });
  return { promise, resolve };
}
function harness() {
  const state = { currentTrackId: 'a', selectedTrackId: 'a', repeatMode: 'off', nativePlayback: { generation: 12 } };
  const pending = deferred();
  const requests = [], continued = [];
  const bridge = { spcBoySB2: { playbackCompletionRetire: request => { requests.push(request); return pending.promise; } } };
  const handler = makeFinalizer(state, bridge, () => [{ id: 'a' }, { id: 'b' }], async decision => { continued.push(decision); });
  return { state, pending, requests, continued, ...handler };
}

test('a current native retirement continues the intended queue', async () => {
  const run = harness();
  const completion = run.finalizePlaybackEnded();
  assert.deepEqual(run.requests[0].playlistIds, ['a', 'b']);
  assert.equal(run.requests[0].generation, 12);
  run.pending.resolve({ action: 'play', trackId: 'b' });
  await completion;
  assert.equal(run.continued[0].retirementDecision.trackId, 'b');
});

test('rejected retirement never advances playback', async () => {
  const run = harness();
  const completion = run.finalizePlaybackEnded();
  run.pending.resolve(null);
  await completion;
  assert.deepEqual(run.continued, []);
});

test('delayed retirement cannot advance after track, frontend or native generation changes', async () => {
  for (const change of ['track', 'frontend', 'native']) {
    const run = harness();
    const completion = run.finalizePlaybackEnded();
    if (change === 'track') run.state.currentTrackId = 'b';
    if (change === 'frontend') run.setGeneration(8);
    if (change === 'native') run.state.nativePlayback.generation = 13;
    run.pending.resolve({ action: 'play', trackId: 'b' });
    await completion;
    assert.deepEqual(run.continued, [], change);
  }
});

const statusSource = section('function applyNativePlaybackSnapshot(', '\nasync function finalizePlaybackEnded()');
const endedSource = section('async function handleNativePlaybackEnded(event) {', '\nasync function setPlaybackPowerSaveBlocker(');
const makeEndedHandler = new Function('state', 'activeTrackInfo', 'effectiveTotalSeconds', 'finalizePlaybackEnded', `
  let playbackGeneration = 7;
  ${statusSource}
  ${endedSource}
  return handleNativePlaybackEnded;
`);

test('older same-generation end status cannot claim retirement', async () => {
  const state = { currentTrackId: 'a', nativePlayback: { generation: 12, statusSequence: 30 } };
  let finalized = 0;
  const handle = makeEndedHandler(state, () => ({ id: 'a' }), () => 20, async () => { finalized += 1; });
  await handle({ generation: 12, status_sequence: 29, transport_state: 'ended' });
  assert.equal(finalized, 0);
  assert.equal(state.currentTrackId, 'a');
});
