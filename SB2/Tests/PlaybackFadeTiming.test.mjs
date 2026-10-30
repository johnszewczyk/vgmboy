import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const source = await readFile(new URL('../Sources/SB2/Resources/app-playback.js', import.meta.url), 'utf8');
function section(startMarker, endMarker) {
  const start = source.indexOf(startMarker), end = source.indexOf(endMarker, start);
  assert.ok(start >= 0 && end > start);
  return source.slice(start, end);
}
const fade = section('async function fadeActiveOutput(', '\nfunction clearQueuedSkipTimer(');
const clear = section('function clearQueuedSkipTimer(', '\nfunction scheduleQueuedSkipFade(');
const schedule = section('function scheduleQueuedSkipFade(', '\nfunction monotonicNow(');
function deferred() { let resolve, reject; const promise = new Promise((a, b) => { resolve = a; reject = b; }); return { promise, resolve, reject }; }
function harness(ramp, currentGeneration = 42, schedulerStart = async () => {}) {
  const timers = [], completions = [], calls = [];
  const run = new Function('ramp', 'timers', 'completions', 'calls', 'currentGeneration', 'schedulerStart', `
    let playbackGeneration = 7, queuedSkipTimer = 0, queuedSkipToken = null, queuedSkipSerial = 0, nativePlaybackInitialized = true;
    const queuedSkipSession = 'test';
    let queuedSkipRequest = { generation: 7, nativeGeneration: 42 };
    const TRANSPORT_DECLICK_MS = 10, state = { nativePlayback: { generation: currentGeneration } };
    const activeTrackInfo = () => ({ id: 'one' }), waitForAudioEnvelope = async () => {};
    const window = { spcBoySB2: { nativePlaybackRampGain: ramp,
      queuedFadeStart: value => { calls.push(['start', value]); return schedulerStart(); },
      queuedFadeRampReady: async value => { calls.push(['ready', value]); },
      queuedFadeCancel: async value => { calls.push(['cancel', value]); } },
      setTimeout: (callback, duration) => { timers.push({ callback, duration, canceled: false }); return timers.length; },
      clearTimeout: id => { timers[id - 1].canceled = true; } };
    const completeQueuedSkip = async () => { queuedSkipRequest.completing = true; completions.push(true); };
    ${fade}
    ${clear}
    ${schedule}
    return { start: () => scheduleQueuedSkipFade(queuedSkipRequest, { durationMilliseconds: 6000, fallbackMilliseconds: 8000 }, 'failed'),
      event: token => handleQueuedFadeReady({ token }),
      cancel: () => { queuedSkipRequest = null; clearQueuedSkipTimer(); }, supersede: () => { playbackGeneration++; clearQueuedSkipTimer(); } };
  `)(ramp, timers, completions, calls, currentGeneration, schedulerStart);
  return { ...run, timers, completions, calls };
}
const tick = () => new Promise(resolve => setImmediate(resolve));

test('shared scheduler starts its full interval after the native ramp reply', async () => {
  const pending = deferred(), run = harness(() => pending.promise);
  run.start(); await tick();
  assert.equal(run.timers[0].duration, 8000);
  assert.equal(run.timers[0].canceled, true);
  pending.resolve(); await tick();
  assert.equal(run.timers.at(-1).duration, 8000);
  assert.deepEqual(run.calls.filter(c => c[0] === 'ready'), [['ready', { token: 'test-1' }]]);
  run.event('stale'); assert.equal(run.completions.length, 0);
  run.event('test-1'); run.event('test-1'); await tick();
  assert.equal(run.completions.length, 1);
});

test('queued fade addresses its captured generation even if the snapshot changes', async () => {
  const requests = [], run = harness(async request => { requests.push(request); }, 43);
  run.start(); await tick();
  assert.equal(requests[0].expectedGeneration, 42);
});

test('cancellation and supersession discard delayed ramp replies and events', async () => {
  for (const action of ['cancel', 'supersede']) {
    const pending = deferred(), run = harness(() => pending.promise);
    run.start(); run[action](); pending.resolve(); await tick(); run.event('test-1');
    assert.equal(run.timers[0].canceled, true, action);
    assert.equal(run.calls.some(c => c[0] === 'ready'), false, action);
    assert.equal(run.completions.length, 0, action);
  }
});

test('an unavailable ramp still confirms the shared deadline', async () => {
  const run = harness(async () => { throw new Error('ramp unavailable'); });
  run.start(); await tick();
  assert.equal(run.calls.some(c => c[0] === 'ready'), true);
});

test('a hung scheduler start retains the local fallback and ignores later events', async () => {
  const start = deferred(), ramp = deferred(), run = harness(() => ramp.promise, 42, () => start.promise);
  run.start(); assert.equal(run.timers[0].duration, 8000);
  run.timers[0].callback(); await tick();
  assert.equal(run.completions.length, 1);
  start.resolve(); ramp.resolve(); await tick(); run.event('test-1');
  assert.equal(run.completions.length, 1);
});

test('a ramp reply while scheduler start is pending rearms the local fallback', async () => {
  const start = deferred(), run = harness(async () => {}, 42, () => start.promise);
  run.start(); await tick();
  assert.equal(run.timers[0].canceled, true);
  assert.equal(run.timers[1].duration, 6000);
  start.resolve(); await tick();
  assert.equal(run.timers[1].canceled, true);
  assert.equal(run.timers.at(-1).duration, 8000);
});

test('a lost native event still reaches the local fallback once', async () => {
  const run = harness(async () => {});
  run.start(); await tick();
  const fallback = run.timers.at(-1);
  assert.equal(fallback.duration, 8000);
  fallback.callback(); await tick();
  run.event('test-1');
  assert.equal(run.completions.length, 1);
});
