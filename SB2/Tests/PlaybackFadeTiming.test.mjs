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
const schedule = section('function scheduleQueuedSkipFade(', '\nfunction monotonicNow(');
function deferred() { let resolve, reject; const promise = new Promise((a, b) => { resolve = a; reject = b; }); return { promise, resolve, reject }; }
function harness(ramp) {
  const timers = [], completions = [];
  const run = new Function('ramp', 'timers', 'completions', `
    let playbackGeneration = 7, queuedSkipTimer = 0, nativePlaybackInitialized = true;
    let queuedSkipRequest = { generation: 7, nativeGeneration: 42 };
    const TRANSPORT_DECLICK_MS = 10, state = { nativePlayback: { generation: 42 } };
    const activeTrackInfo = () => ({ id: 'one' }), waitForAudioEnvelope = async () => {};
    const window = { spcBoySB2: { nativePlaybackRampGain: ramp },
      setTimeout: (callback, duration) => { timers.push({ callback, duration, canceled: false }); return timers.length; },
      clearTimeout: id => { timers[id - 1].canceled = true; } };
    const clearQueuedSkipTimer = () => { if (queuedSkipTimer) window.clearTimeout(queuedSkipTimer); queuedSkipTimer = 0; };
    const completeQueuedSkip = async () => { queuedSkipRequest.completing = true; completions.push(true); };
    ${fade}
    ${schedule}
    return { start: () => scheduleQueuedSkipFade(queuedSkipRequest, 6000, 'failed'),
      cancel: () => { queuedSkipRequest = null; clearQueuedSkipTimer(); }, supersede: () => { playbackGeneration++; clearQueuedSkipTimer(); } };
  `)(ramp, timers, completions);
  return { ...run, timers, completions };
}

test('queued fade interval begins after the native ramp reply', async () => {
  const pending = deferred(), run = harness(() => pending.promise);
  run.start();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(run.timers.length, 1);
  assert.equal(run.timers[0].duration, 8000);
  pending.resolve();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(run.timers.length, 2);
  assert.equal(run.timers[0].canceled, true);
  assert.equal(run.timers[1].duration, 6000);
  run.timers[1].callback();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(run.completions.length, 1);
});

test('cancellation and supersession do not arm a delayed fade timer', async () => {
  for (const action of ['cancel', 'supersede']) {
    const pending = deferred(), run = harness(() => pending.promise);
    run.start(); run[action](); pending.resolve();
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(run.timers.length, 1, action);
    assert.equal(run.timers[0].canceled, true, action);
  }
});

test('an unavailable ramp still allows the queued skip to continue', async () => {
  const run = harness(async () => { throw new Error('ramp unavailable'); });
  run.start();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(run.timers.length, 2);
  assert.equal(run.timers[0].canceled, true);
  assert.equal(run.timers[1].duration, 6000);
});

test('a hung ramp has a bounded fallback timer', async () => {
  const pending = deferred(), run = harness(() => pending.promise);
  run.start();
  assert.equal(run.timers[0].duration, 8000);
  run.timers[0].callback();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(run.completions.length, 1);
  pending.resolve();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(run.timers.length, 1);
});
