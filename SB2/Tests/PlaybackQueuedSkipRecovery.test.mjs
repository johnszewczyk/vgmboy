import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const source = await readFile(new URL('../Sources/SB2/Resources/app-playback.js', import.meta.url), 'utf8');
const start = source.indexOf('async function completeQueuedSkip()');
const end = source.indexOf('\nasync function playTrackWithFadedSkip(', start);
assert.ok(start >= 0 && end > start);

function harness(stateRequest) {
  const initial = { generation: 7, nativeGeneration: 42 };
  const events = [];
  const run = new Function('stateRequest', 'events', `
    let playbackGeneration = 7, queuedSkipRequest = { generation: 7, nativeGeneration: 42 }, queuedSkipTimer = 1;
    const window = { spcBoySB2: { nativePlaybackState: stateRequest } };
    const cancelQueuedSkip = async options => { events.push(['cancel', queuedSkipRequest, options]); queuedSkipRequest = null; };
    const finalizePlaybackEnded = async () => { events.push(['finalize']); };
    ${source.slice(start, end)}
    return { completeQueuedSkip, replace: request => { queuedSkipRequest = request; }, getRequest: () => queuedSkipRequest };
  `)(stateRequest, events);
  return { ...run, events, initial };
}

test('status failure cancels the skip and restores the retained session', async () => {
  const run = harness(async () => { throw new Error('status failed'); });
  await assert.rejects(run.completeQueuedSkip(), /status failed/);
  assert.deepEqual(run.events, [['cancel', run.initial, { restoreOutput: true }]]);
  assert.equal(run.getRequest(), null);
});

test('late status failure does not cancel a newer skip', async () => {
  let reject;
  const run = harness(() => new Promise((_, fail) => { reject = fail; }));
  const pending = run.completeQueuedSkip();
  const newer = { generation: 8, nativeGeneration: 43 };
  run.replace(newer);
  reject(new Error('status failed'));
  await assert.rejects(pending, /status failed/);
  assert.deepEqual(run.events, []);
  assert.equal(run.getRequest(), newer);
});

test('matching status completes once and mismatched status restores the old generation', async () => {
  const matching = harness(async () => ({ generation: 42 }));
  await matching.completeQueuedSkip();
  assert.deepEqual(matching.events, [['finalize']]);
  const stale = harness(async () => ({ generation: 43 }));
  await stale.completeQueuedSkip();
  assert.deepEqual(stale.events, [['cancel', stale.initial, { restoreOutput: true }]]);
});
