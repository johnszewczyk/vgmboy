import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const source = await readFile(new URL('../Sources/SB2/Resources/app-playback.js', import.meta.url), 'utf8');
function section(startMarker, endMarker) {
  const start = source.indexOf(startMarker), end = source.indexOf(endMarker, start);
  assert.ok(start >= 0 && end > start);
  return source.slice(start, end);
}
const completion = section('async function completeQueuedSkip()', '\nasync function playTrackWithFadedSkip(');
const navigation = section('async function playAdjacentNow(', '\nasync function togglePlayback(');
function deferred() { let resolve, reject; const promise = new Promise((a, b) => { resolve = a; reject = b; }); return { promise, resolve, reject }; }
function harness({ fade = async () => {}, start = async () => {}, navigate = async () => ({ trackId: 'next' }) } = {}) {
  const events = [];
  const state = { currentTrackId: 'old', selectedTrackId: 'selected', nativePlayback: { generation: 42, trackLoaded: true } };
  const run = new Function('state', 'events', 'fade', 'start', 'navigate', `
    let playbackGeneration = 7, queuedSkipRequest = { generation: 7, nativeGeneration: 42, delta: 1 };
    const TRANSPORT_DECLICK_MS = 10;
    const playbackPlaylist = () => [{ id: 'old' }, { id: 'next' }];
    const window = { spcBoySB2: { nativePlaybackQueuedSkipDecision: request => {
      events.push(['navigate', request.navigation]); return navigate(request.navigation); },
      nativePlaybackRampGain: async request => events.push(['ramp', request]) } };
    const clearQueuedSkipTimer = () => events.push(['clear']);
    const fadeActiveOutput = (ms, options) => { events.push(['fade', ms, options]); return fade(); };
    const beginPlaybackIntent = () => ({}), finishPlaybackIntent = async () => {};
    const cancelQueuedSkip = async value => { events.push(['cancel', value]); queuedSkipRequest = null; };
    const playTrack = (...args) => { playbackGeneration++; events.push(['start', ...args]); return start(); };
    const advanceToAdjacent = async () => { events.push(['unexpected advance']); };
    const stopPlaybackState = async () => { events.push(['unexpected stop']); };
    ${completion}
    ${navigation}
    return { playAdjacentNow, supersede: () => { playbackGeneration++; }, getRequest: () => queuedSkipRequest };
  `)(state, events, fade, start, navigate);
  return { ...run, events, state };
}

test('repeated navigation keeps the session and uses the shared queue decision', async () => {
  const run = harness();
  await run.playAdjacentNow(-1);
  const navigation = run.events.find(event => event[0] === 'navigate')[1];
  assert.equal(navigation.direction, 'previous');
  assert.equal(navigation.state.currentTrackId, 'old');
  assert.deepEqual(run.events.find(event => event[0] === 'start'), ['start', 'next', 0, true, null, 42]);
  assert.equal(run.events.some(event => event[0].startsWith('unexpected')), false);
});

test('a failed replacement receives the original generation for recovery', async () => {
  const run = harness({ start: async () => { throw new Error('missing source'); } });
  await assert.rejects(run.playAdjacentNow(1), /missing source/);
  assert.deepEqual(run.events.find(event => event[0] === 'start'), ['start', 'next', 0, true, null, 42]);
  assert.equal(run.state.currentTrackId, 'old');
});

test('a newer intent during the short fade cancels the older navigation', async () => {
  const fade = deferred(), run = harness({ fade: () => fade.promise });
  const old = run.playAdjacentNow(1);
  run.supersede(); fade.resolve(); await old;
  assert.equal(run.events.some(event => event[0] === 'navigate' || event[0] === 'start'), false);
});

test('repeated navigation fades only the queued native session', async () => {
  const run = harness();
  run.state.nativePlayback.generation = 43;
  await run.playAdjacentNow(1);
  assert.deepEqual(run.events.find(event => event[0] === 'fade'),
    ['fade', 10, { expectedGeneration: 42 }]);
});
