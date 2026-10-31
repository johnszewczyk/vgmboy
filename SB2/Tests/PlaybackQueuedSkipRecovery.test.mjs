import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const source = await readFile(new URL('../Sources/SB2/Resources/app-playback.js', import.meta.url), 'utf8');
const start = source.indexOf('async function completeQueuedSkip()');
const end = source.indexOf('\nasync function playTrackWithFadedSkip(', start);
assert.ok(start >= 0 && end > start);
function deferred() { let resolve, reject; const promise = new Promise((a, b) => { resolve = a; reject = b; }); return { promise, resolve, reject }; }
function harness({ status = async () => ({ generation: 42 }), navigate = async () => ({ trackId: 'new' }), startTrack = async () => {}, claim = async () => true, request = {} } = {}) {
  const events = [], state = { currentTrackId: 'old', selectedTrackId: 'old', nativePlayback: { generation: 42, trackLoaded: true } };
  const run = new Function('state', 'status', 'navigate', 'startTrack', 'events', 'request', 'claim', `
    let playbackGeneration = 7, queuedSkipRequest = { generation: 7, nativeGeneration: 42, claimId: 'claim', ...request }, queuedSkipTimer = 1;
    let queuedSkipActiveToken = 'claim';
    const invalidateQueuedSkip = () => { queuedSkipRequest = null; queuedSkipActiveToken = null; };
    const window = { spcBoySB2: { queuedSkipClaim: claim, nativePlaybackQueuedSkipDecision: async value => {
      const snapshot = await status();
      if (value.expectedGeneration && snapshot.generation !== value.expectedGeneration) return null;
      return value.targetTrackId ? { trackId: value.targetTrackId } : navigate(value.navigation);
    },
      nativePlaybackRampGain: async value => { events.push(['ramp', value]); } } };
    const TRANSPORT_DECLICK_MS = 10, playbackPlaylist = () => [{ id: 'old' }, { id: 'new' }];
    const beginPlaybackIntent = id => { events.push(['begin', id]); return {}; };
    const finishPlaybackIntent = async () => { events.push(['finish']); };
    const clearQueuedSkipTimer = () => { queuedSkipTimer = 0; };
    const cancelQueuedSkip = async options => { events.push(['cancel', options]); queuedSkipRequest = null; };
    const playTrack = (...args) => { playbackGeneration++; events.push(['start', ...args]); return startTrack(); };
    ${source.slice(start, end)}
    return { completeQueuedSkip, replace: value => { queuedSkipRequest = value; queuedSkipActiveToken = 'newer'; },
      supersede: () => { playbackGeneration++; }, getRequest: () => queuedSkipRequest };
  `)(state, status, navigate, startTrack, events, request, claim);
  return { ...run, events, state };
}

test('supersession while a shared claim reply is pending does not start the old target', async () => {
  const pending = deferred(), run = harness({ claim: () => pending.promise, request: { targetTrackId: 'old-target' } });
  const completion = run.completeQueuedSkip();
  const newer = { generation: 8, nativeGeneration: 42 };
  run.replace(newer); run.supersede(); pending.resolve(true);
  await completion;
  assert.equal(run.getRequest(), newer);
  assert.equal(run.events.some(event => event[0] === 'start'), false);
});

test('a lost shared claim reply falls back to a token-guarded start', async () => {
  const run = harness({ claim: () => new Promise(() => {}), request: { targetTrackId: 'new' } });
  await run.completeQueuedSkip();
  assert.deepEqual(run.events.find(event => event[0] === 'start'), ['start', 'new', 0, true, { queuedSkipToken: 'claim' }, 42]);
});

test('status failure cancels the skip and requests restore', async () => {
  const run = harness({ status: async () => { throw new Error('status failed'); } });
  await assert.rejects(run.completeQueuedSkip(), /status failed/);
  assert.deepEqual(run.events, [['begin', null], ['cancel', { restoreOutput: true }], ['finish']]);
});

test('late status failure does not cancel a newer skip', async () => {
  const pending = deferred(), run = harness({ status: () => pending.promise });
  const completion = run.completeQueuedSkip(), newer = { generation: 8, nativeGeneration: 43 };
  await new Promise(resolve => setImmediate(resolve));
  run.replace(newer); run.supersede(); pending.reject(new Error('status failed'));
  await assert.rejects(completion, /status failed/);
  assert.equal(run.getRequest(), newer);
  assert.equal(run.events.some(event => event[0] === 'cancel'), false);
});

test('matching status starts the shared replacement without retirement', async () => {
  const run = harness({ request: { targetTrackId: 'new', startSeconds: 2 } });
  await run.completeQueuedSkip();
  assert.deepEqual(run.events, [['begin', 'new'], ['start', 'new', 2, true, { queuedSkipToken: 'claim' }, 42], ['finish']]);
  assert.equal(run.getRequest(), null);
});

test('replacement receives the original generation for failure recovery', async () => {
  const run = harness({ request: { targetTrackId: 'new' }, startTrack: async () => { throw new Error('missing archive'); } });
  await assert.rejects(run.completeQueuedSkip(), /missing archive/);
  assert.deepEqual(run.events.find(event => event[0] === 'start'), ['start', 'new', 0, true, { queuedSkipToken: 'claim' }, 42]);
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
