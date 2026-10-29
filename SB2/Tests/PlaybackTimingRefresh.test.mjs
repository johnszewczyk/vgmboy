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

const resolveStart = source.indexOf('async function resolveTimingPlan(');
const resolveEnd = source.indexOf('\nfunction matchesCurrentPlaybackSettings(', resolveStart);
assert.ok(resolveStart >= 0 && resolveEnd > resolveStart);
const makeResolver = new Function('state', 'window', 'currentFadeSeconds', 'playbackSpeedForTrack', `
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
