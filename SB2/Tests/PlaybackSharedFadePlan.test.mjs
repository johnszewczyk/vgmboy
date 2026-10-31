import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const source = await readFile(new URL('../Sources/SB2/Resources/app-playback.js', import.meta.url), 'utf8');
function section(startMarker, endMarker) {
  const start = source.indexOf(startMarker), end = source.indexOf(endMarker, start);
  assert.ok(start >= 0 && end > start);
  return source.slice(start, end);
}
const activation = section('async function playTrackWithFadedSkip(', '\nasync function advanceToAdjacent(');
const adjacent = section('async function playAdjacentNow(', '\nasync function togglePlayback(');
function harness(plan) {
  const state = { currentTrackId: 'one', isPlaying: true, elapsedSeconds: 2, queuedSkipsEnabled: true,
    nativePlayback: { generation: 42 } }, requests = [], scheduled = [], immediate = [];
  const run = new Function('state', 'plan', 'requests', 'scheduled', 'immediate', `
    let playbackGeneration = 0, queuedSkipRequest = null;
    let queuedSkipSerial = 0, queuedSkipActiveToken = null; const queuedSkipSession = 'test';
    const invalidateQueuedSkip = () => { queuedSkipRequest = null; queuedSkipActiveToken = null; };
    const beginQueuedSkip = request => { queuedSkipRequest = request; };
    const TRANSPORT_DECLICK_MS = 10, playbackPlaylist = () => [{ id: 'one' }, { id: 'two' }];
    const currentTrack = () => ({ id: 'one' }), currentOutputBasePlaybackSeconds = () => 30;
    const currentFadeSeconds = () => 6, currentTotalSeconds = () => 36;
    const window = { spcBoySB2: { playbackFadePlan: async request => { requests.push(request); return plan; } } };
    const scheduleQueuedSkipFade = (request, value) => scheduled.push({ request, plan: value });
    const playTrackNow = async id => immediate.push(['track', id]);
    const advanceToAdjacent = async delta => immediate.push(['adjacent', delta]);
    const clearQueuedSkipTimer = () => {}, fadeActiveOutput = async () => {}, completeQueuedSkip = async () => {};
    ${activation}
    ${adjacent}
    return { playTrackWithFadedSkip, playAdjacentNow };
  `)(state, plan, requests, scheduled, immediate);
  return { ...run, requests, scheduled, immediate };
}

test('playlist activation and navigation use the shared fade schedule', async () => {
  const plan = { durationMilliseconds: 6000, fallbackMilliseconds: 8000 };
  for (const route of ['activation', 'adjacent']) {
    const run = harness(plan);
    if (route === 'activation') await run.playTrackWithFadedSkip('two');
    else await run.playAdjacentNow(1);
    assert.equal(run.requests[0].hasCurrentTrack, true, route);
    assert.deepEqual(run.scheduled[0].plan, plan, route);
    assert.equal(run.scheduled[0].request.nativeGeneration, 42, route);
    assert.deepEqual(run.immediate, [], route);
  }
});

test('no shared fade schedule preserves immediate replacement', async () => {
  for (const route of ['activation', 'adjacent']) {
    const run = harness(null);
    if (route === 'activation') await run.playTrackWithFadedSkip('two');
    else await run.playAdjacentNow(1);
    assert.equal(run.scheduled.length, 0, route);
    assert.equal(run.immediate.length, 1, route);
  }
});
