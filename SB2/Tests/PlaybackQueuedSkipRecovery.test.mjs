import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const source = await readFile(new URL('../Sources/SB2/Resources/app-playback.js', import.meta.url), 'utf8');
const start = source.indexOf('async function completeQueuedSkip()');
const end = source.indexOf('\nasync function playTrackWithFadedSkip(', start);
assert.ok(start >= 0 && end > start);
function deferred() { let resolve, reject; const promise = new Promise((a, b) => { resolve = a; reject = b; }); return { promise, resolve, reject }; }
function harness({ status = async () => ({ generation: 42 }), navigate = async () => ({ trackId: 'new' }), startTrack = async () => {}, request = {} } = {}) {
  const events = [], state = { currentTrackId: 'old', selectedTrackId: 'old', nativePlayback: { generation: 42, trackLoaded: true } };
  const run = new Function('state', 'status', 'navigate', 'startTrack', 'events', 'request', `
    let playbackGeneration = 7, queuedSkipRequest = { generation: 7, nativeGeneration: 42, ...request }, queuedSkipTimer = 1;
    const window = { spcBoySB2: { nativePlaybackState: status, playbackQueueAdjacent: navigate,
      nativePlaybackRampGain: async value => { events.push(['ramp', value]); } } };
    const TRANSPORT_DECLICK_MS = 10, playbackPlaylist = () => [{ id: 'old' }, { id: 'new' }];
    const beginPlaybackIntent = id => { events.push(['begin', id]); return {}; };
    const finishPlaybackIntent = async () => { events.push(['finish']); };
    const clearQueuedSkipTimer = () => { queuedSkipTimer = 0; };
    const cancelQueuedSkip = async options => { events.push(['cancel', options]); queuedSkipRequest = null; };
    const playTrack = (...args) => { playbackGeneration++; events.push(['start', ...args]); return startTrack(); };
    ${source.slice(start, end)}
    return { completeQueuedSkip, replace: value => { queuedSkipRequest = value; },
      supersede: () => { playbackGeneration++; }, getRequest: () => queuedSkipRequest };
  `)(state, status, navigate, startTrack, events, request);
  return { ...run, events, state };
}

test('status failure cancels the skip and requests restore', async () => {
  const run = harness({ status: async () => { throw new Error('status failed'); } });
  await assert.rejects(run.completeQueuedSkip(), /status failed/);
  assert.deepEqual(run.events, [['begin', null], ['cancel', { restoreOutput: true }], ['finish']]);
});

test('late status failure does not cancel a newer skip', async () => {
  const pending = deferred(), run = harness({ status: () => pending.promise });
  const completion = run.completeQueuedSkip(), newer = { generation: 8, nativeGeneration: 43 };
  run.replace(newer); run.supersede(); pending.reject(new Error('status failed'));
  await assert.rejects(completion, /status failed/);
  assert.equal(run.getRequest(), newer);
  assert.equal(run.events.some(event => event[0] === 'cancel'), false);
});

test('matching status starts the shared replacement without retirement', async () => {
  const run = harness({ request: { targetTrackId: 'new', startSeconds: 2 } });
  await run.completeQueuedSkip();
  assert.deepEqual(run.events, [['begin', 'new'], ['start', 'new', 2, true, null, 42], ['finish']]);
  assert.equal(run.getRequest(), null);
});

test('replacement receives the original generation for failure recovery', async () => {
  const run = harness({ request: { targetTrackId: 'new' }, startTrack: async () => { throw new Error('missing archive'); } });
  await assert.rejects(run.completeQueuedSkip(), /missing archive/);
  assert.deepEqual(run.events.find(event => event[0] === 'start'), ['start', 'new', 0, true, null, 42]);
});

test('duplicate completion cannot start twice and navigation failure restores', async () => {
  const pending = deferred(), run = harness({ navigate: () => pending.promise, request: { delta: 1 } });
  const completion = run.completeQueuedSkip();
  await new Promise(resolve => setImmediate(resolve));
  await run.completeQueuedSkip();
  pending.reject(new Error('navigation failed'));
  await assert.rejects(completion, /navigation failed/);
  assert.equal(run.events.filter(event => event[0] === 'cancel').length, 1);
});

test('mismatched native generation cancels with a guarded restore', async () => {
  const run = harness({ status: async () => ({ generation: 43 }) });
  await run.completeQueuedSkip();
  assert.deepEqual(run.events, [['begin', null], ['cancel', { restoreOutput: true }], ['finish']]);
});
