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
  let pendingPlaybackIntent = null, deferredNativeEnds = [];
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

const intentGateSource = section('let pendingPlaybackIntent = null;', '\nfunction clearPlaybackError()');
const makeIntentGate = new Function('state', 'finalize', `
  let playbackGeneration = 7;
  const activeTrackInfo = () => state.currentTrackId ? { id: state.currentTrackId } : null;
  const applyNativePlaybackSnapshot = (_, event) => !state.nativePlayback.statusSequence
    || (Number(event.status_sequence) || 0) >= state.nativePlayback.statusSequence;
  const finalizePlaybackEnded = finalize;
  ${intentGateSource}
  ${endedSource}
  return { beginPlaybackIntent, finishPlaybackIntent, cancelPlaybackIntent, handleNativePlaybackEnded };
`);

test('old end waits for a pending replacement and resumes after failure', async () => {
  const state = { currentTrackId: 'old', nativePlayback: { generation: 12 } };
  let claims = 0;
  const gate = makeIntentGate(state, async () => { claims++; });
  const intent = gate.beginPlaybackIntent();
  await gate.handleNativePlaybackEnded({ generation: 12, transport_state: 'ended' });
  assert.equal(claims, 0);
  await gate.finishPlaybackIntent(intent);
  assert.equal(claims, 1);
});

test('accepted replacement discards deferred old completion', async () => {
  const state = { currentTrackId: 'old', nativePlayback: { generation: 12 } };
  let claims = 0;
  const gate = makeIntentGate(state, async () => { claims++; });
  const intent = gate.beginPlaybackIntent();
  await gate.handleNativePlaybackEnded({ generation: 12, transport_state: 'ended' });
  state.currentTrackId = 'new'; state.nativePlayback.generation = 13;
  await gate.finishPlaybackIntent(intent);
  assert.equal(claims, 0);
});

test('a new session that ends before its start reply is completed once', async () => {
  const state = { currentTrackId: 'old', nativePlayback: { generation: 12 } };
  let claims = 0;
  const gate = makeIntentGate(state, async () => { claims++; });
  const intent = gate.beginPlaybackIntent('new');
  await gate.handleNativePlaybackEnded({ generation: 12, transport_state: 'ended' });
  await gate.handleNativePlaybackEnded({ generation: 13, transport_state: 'ended' });
  state.currentTrackId = 'new'; state.nativePlayback.generation = 13;
  await gate.finishPlaybackIntent(intent);
  assert.equal(claims, 1);
});

test('an initial session ending before its start reply is not lost', async () => {
  const state = { currentTrackId: null, nativePlayback: { generation: 0 } };
  let claims = 0;
  const gate = makeIntentGate(state, async () => { claims++; });
  const intent = gate.beginPlaybackIntent('new');
  await gate.handleNativePlaybackEnded({ generation: 13, transport_state: 'ended' });
  state.currentTrackId = 'new'; state.nativePlayback.generation = 13;
  await gate.finishPlaybackIntent(intent);
  assert.equal(claims, 1);
});

test('an ended start reply can be newer than its deferred end event', async () => {
  const state = { currentTrackId: null, nativePlayback: { generation: 0 } };
  let claims = 0;
  const gate = makeIntentGate(state, async () => { claims++; });
  const intent = gate.beginPlaybackIntent('new');
  await gate.handleNativePlaybackEnded({ generation: 13, status_sequence: 19, transport_state: 'ended' });
  state.currentTrackId = 'new';
  state.nativePlayback = { generation: 13, statusSequence: 20, transportState: 'ended' };
  await gate.finishPlaybackIntent(intent);
  assert.equal(claims, 1);
});

test('a newer playing status still rejects a deferred stale end', async () => {
  const state = { currentTrackId: 'old', nativePlayback: { generation: 12 } };
  let claims = 0;
  const gate = makeIntentGate(state, async () => { claims++; });
  const intent = gate.beginPlaybackIntent('new');
  await gate.handleNativePlaybackEnded({ generation: 12, status_sequence: 19, transport_state: 'ended' });
  state.nativePlayback = { generation: 12, statusSequence: 20, transportState: 'playing' };
  await gate.finishPlaybackIntent(intent);
  assert.equal(claims, 0);
});

test('superseded intent leaves completion to the newest intent and stop cancels it', async () => {
  const state = { currentTrackId: 'old', nativePlayback: { generation: 12 } };
  let claims = 0;
  const gate = makeIntentGate(state, async () => { claims++; });
  const first = gate.beginPlaybackIntent();
  await gate.handleNativePlaybackEnded({ generation: 12, transport_state: 'ended' });
  const second = gate.beginPlaybackIntent();
  await gate.finishPlaybackIntent(first);
  assert.equal(claims, 0);
  gate.cancelPlaybackIntent();
  await gate.finishPlaybackIntent(second);
  assert.equal(claims, 0);
});
