import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const source = await readFile(new URL('../Sources/SB2/Resources/app-playback.js', import.meta.url), 'utf8');
const start = source.indexOf('async function refreshPlaybackForTimingChange() {');
const end = source.indexOf('\nasync function refreshPlaybackForSpeedChange()', start);
assert.ok(start >= 0 && end > start);
const makeRefresh = new Function('state', 'currentTrack', 'activeTrackInfo', 'resolveTimingPlan',
  'updateTimingSummary', 'updatePlaybackReadout', `
    let playbackSettingsGeneration = 0, playbackGeneration = 0;
    const timingPlans = new Map([['one', { pre_fade_seconds: 180 }], ['two', { pre_fade_seconds: 180 }]]);
    ${source.slice(start, end)}
    return { refreshPlaybackForTimingChange, timingPlans };
  `);
function deferred() { let resolve; const promise = new Promise(r => { resolve = r; }); return { promise, resolve }; }

test('stopped timing changes invalidate all old plans and refresh the selected preview', async () => {
  const state = { currentTrackId: null };
  const track = { id: 'one' };
  let updates = 0;
  const run = makeRefresh(state, () => null, () => track, async () => ({ pre_fade_seconds: 3 }), () => { updates += 1; }, () => {});
  await run.refreshPlaybackForTimingChange();
  assert.equal(run.timingPlans.get('one').pre_fade_seconds, 3);
  assert.equal(run.timingPlans.has('two'), false);
  assert.ok(updates > 0);
});

test('a late stopped preview cannot replace a newer selected track', async () => {
  const state = { currentTrackId: null };
  const pending = deferred();
  let track = { id: 'one' };
  const run = makeRefresh(state, () => null, () => track, () => pending.promise, () => {}, () => {});
  const refresh = run.refreshPlaybackForTimingChange();
  track = { id: 'two' };
  pending.resolve({ pre_fade_seconds: 3 });
  await refresh;
  assert.equal(run.timingPlans.has('one'), false);
});

test('live timing changes target the observed native session', async () => {
  const state = { currentTrackId: 'one', nativePlayback: { trackLoaded: true, generation: 42 }, unknownDurationSeconds: 150, elapsedSeconds: 0 };
  const track = { id: 'one' }, requests = [];
  const factory = new Function('state', 'track', 'window', `
    let playbackSettingsGeneration = 0, playbackGeneration = 7, nativePlaybackInitialized = true;
    const timingPlans = new Map();
    const currentTrack = () => track, activeTrackInfo = () => track;
    const resolveTimingPlan = async () => ({ is_long_play: true, pre_fade_seconds: 30, fade_seconds: 1 });
    const matchesCurrentPlaybackSettings = (r, g, id) => r === playbackSettingsGeneration && g === playbackGeneration && state.currentTrackId === id;
    const requestedPlaybackSpeed = () => ({ numerator: 1, denominator: 1 });
    const applyNativePlaybackSnapshot = () => {}, effectiveTotalSeconds = () => 31;
    const updateTimingSummary = () => {}, updatePlaybackReadout = () => {};
    ${source.slice(start, end)}
    return refreshPlaybackForTimingChange;
  `);
  const refresh = factory(state, track, { spcBoySB2: { nativePlaybackReconfigure: async value => { requests.push(value); return {}; } } });
  await refresh();
  assert.equal(requests[0].expectedGeneration, 42);
  state.nativePlayback.generation = 0;
  await assert.rejects(refresh(), /session identity is unavailable/);
  assert.equal(requests.length, 1);
});

test('stopping shows the selected track timing rather than the manual default', async () => {
  const start = source.indexOf('async function stopPlaybackState(');
  const end = source.indexOf('\nasync function cancelQueuedSkip(', start);
  assert.ok(start >= 0 && end > start);
  const state = { currentTrackId: 'one', currentTrackInfo: {}, isPlaying: true, elapsedSeconds: 12 };
  const run = new Function('state', `
    let queuedSkipRequest = {}, playbackGeneration = 0, playbackWindow = {};
    const cancelPlaybackIntent = () => {};
    const clearQueuedSkipTimer = () => {}, stopAllOutput = async () => {};
    const setPlaybackPowerSaveBlocker = async () => {};
    const targetPlaybackSeconds = () => 186, activeTrackInfo = () => ({ id: 'one' });
    const currentTotalSeconds = () => 26;
    const resetNativePlaybackSnapshot = () => {}, updatePlaybackReadout = () => {}, updateNativeDiagnostics = () => {};
    const playbackApp = { ui: { refreshPlaylistPlaybackState: () => {} } };
    ${source.slice(start, end)}
    return stopPlaybackState;
  `)(state);
  await run();
  assert.equal(state.totalSeconds, 26);
  assert.equal(state.elapsedSeconds, 0);
});

test('fade requests retain their origin and skip stale restoration', async () => {
  const fadeStart = source.indexOf('async function fadeActiveOutput(');
  const fadeEnd = source.indexOf('\nfunction clearQueuedSkipTimer(', fadeStart);
  const cancelStart = source.indexOf('async function cancelQueuedSkip(');
  const cancelEnd = source.indexOf('\nasync function playTrackNow(', cancelStart);
  assert.ok(fadeStart >= 0 && fadeEnd > fadeStart && cancelStart >= 0 && cancelEnd > cancelStart);
  const requests = [];
  const window = { spcBoySB2: { nativePlaybackRampGain: async request => requests.push(request) } };
  const run = new Function('window', `
    const state = { nativePlayback: { generation: 42, trackLoaded: true } };
    let queuedSkipRequest = { nativeGeneration: 42 }, nativePlaybackInitialized = true;
    const TRANSPORT_DECLICK_MS = 10, activeTrackInfo = () => ({});
    const clearQueuedSkipTimer = () => {}, waitForAudioEnvelope = async () => {};
    ${source.slice(fadeStart, fadeEnd)}
    ${source.slice(cancelStart, cancelEnd)}
    return { fadeActiveOutput, cancelQueuedSkip, state };
  `)(window);
  await run.fadeActiveOutput(25);
  run.state.nativePlayback.generation = 43;
  await run.cancelQueuedSkip({ restoreOutput: true });
  assert.deepEqual(requests.map(request => request.expectedGeneration), [42]);
});

test('pause, resume and seek carry their observed native session', async () => {
  const identityStart = source.indexOf('function currentNativeGeneration()');
  const identityEnd = source.indexOf('\nfunction fallbackPlaybackSpeedForTrack(', identityStart);
  const start = source.indexOf('async function togglePlayback()');
  const end = source.indexOf('\nasync function refreshPlaybackForTimingChange()', start);
  assert.ok(identityStart >= 0 && identityEnd > identityStart && start >= 0 && end > start);
  const requests = [];
  const window = { spcBoySB2: {
    nativePlaybackPause: async value => { requests.push(['pause', value]); return {}; },
    nativePlaybackResume: async value => { requests.push(['resume', value]); return {}; },
    nativePlaybackSeek: async value => { requests.push(['seek', value]); return {}; }
  } };
  const state = { currentTrackId: 'one', isPlaying: true, elapsedSeconds: 0, totalSeconds: 10,
    nativePlayback: { generation: 42, trackLoaded: true, transportState: 'playing' } };
  const run = new Function('state', 'window', `
    let playbackGeneration = 0, queuedSkipRequest = null, nativePlaybackInitialized = true;
    const TRANSPORT_DECLICK_MS = 10, activeTrackInfo = () => ({ id: 'one' });
    const fadeActiveOutput = async () => {}, clearQueuedSkipTimer = () => {};
    const setPlaybackPowerSaveBlocker = async () => {}, cancelQueuedSkip = async () => {};
    const applyNativePlaybackSnapshot = () => {}, updatePlaybackReadout = () => {}, updateNativeDiagnostics = () => {};
    ${source.slice(identityStart, identityEnd)}
    ${source.slice(start, end)}
    return { togglePlayback, restartAt };
  `)(state, window);
  await run.togglePlayback();
  state.isPlaying = false; state.nativePlayback.transportState = 'paused';
  await run.togglePlayback();
  await run.restartAt(2);
  assert.deepEqual(requests.map(([name, value]) => [name, value.expectedGeneration]),
    [['pause', 42], ['resume', 42], ['seek', 42]]);
});

const resolveStart = source.indexOf('async function resolveTimingPlan(');
const resolveEnd = source.indexOf('\nfunction matchesCurrentPlaybackSettings(', resolveStart);
assert.ok(resolveStart >= 0 && resolveEnd > resolveStart);
const makeResolver = new Function('state', 'window', 'currentFadeSeconds', 'requestedPlaybackSpeed', `
  let playbackSettingsGeneration = 0;
  const timingPlans = new Map();
  ${source.slice(resolveStart, resolveEnd)}
  return { resolveTimingPlan, timingPlans, changeSettings: () => { playbackSettingsGeneration += 1; } };
`);

test('a timing response from old settings cannot repopulate the cache', async () => {
  const pending = deferred();
  const state = { manualPlayTimeSeconds: 180, unknownDurationSeconds: 150, longPlayEnabled: true };
  const run = makeResolver(state, { spcBoySB2: { nativePlaybackTiming: () => pending.promise } }, () => 0, () => ({ numerator: 1, denominator: 1 }));
  const request = run.resolveTimingPlan({ id: 'one', path: '/tmp/one.wav', basePlaybackSeconds: 3 });
  run.changeSettings();
  pending.resolve({ pre_fade_seconds: 180, fade_seconds: 0, total_seconds: 180, is_long_play: true });
  await request;
  assert.equal(run.timingPlans.has('one'), false);
});

test('shared millisecond timing survives the renderer bridge', async () => {
  const state = { manualPlayTimeSeconds: 180, unknownDurationSeconds: 150, longPlayEnabled: false };
  const plan = { pre_fade_seconds: 1, fade_seconds: 0, total_seconds: 1,
    pre_fade_milliseconds: 375, fade_milliseconds: 250, total_milliseconds: 625,
    is_long_play: false };
  const run = makeResolver(state, { spcBoySB2: { nativePlaybackTiming: async () => plan } }, () => 0.25, () => ({ numerator: 2, denominator: 1 }));
  const preview = await run.resolveTimingPlan({ id: 'one', path: '/tmp/one.spc', basePlaybackSeconds: 0.75 });
  assert.equal(preview.pre_fade_seconds, 0.375);
  assert.equal(preview.fade_seconds, 0.25);
  assert.equal(preview.total_seconds, 0.625);
});

test('timing requests forward the selected tempo for shared policy to resolve', async () => {
  const state = { manualPlayTimeSeconds: 180, unknownDurationSeconds: 150, longPlayEnabled: false };
  let request;
  const run = makeResolver(state, { spcBoySB2: { nativePlaybackTiming: async value => {
    request = value;
    return { pre_fade_seconds: 20, fade_seconds: 0, total_seconds: 20, is_long_play: false };
  } } }, () => 0, () => ({ numerator: 8, denominator: 1 }));
  await run.resolveTimingPlan({ id: 'one', path: '/tmp/one.spc', basePlaybackSeconds: 80 });
  assert.deepEqual(request.tempo, { numerator: 8, denominator: 1 });
});
