import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const source = await readFile(new URL('../Sources/SB2/Resources/app-playback.js', import.meta.url), 'utf8');
const start = source.indexOf('function currentTotalSeconds(');
const end = source.indexOf('\nasync function resolveTimingPlan(', start);
assert.ok(start >= 0 && end > start);
const makeTiming = new Function('state', 'playbackBackends', 'currentFadeSeconds', `
  const timingPlans = new Map();
  let playbackWindow = null;
  ${source.slice(start, end)}
  return { currentTotalSeconds, currentOutputBasePlaybackSeconds, requestedPlaybackSpeed, timingPlans };
`);
function harness() {
  const state = { unknownDurationSeconds: 150, playbackSpeedEnabled: true, playbackSpeed: { numerator: 2, denominator: 1 } };
  const playbackBackends = { forPath: () => ({ playbackSpeedMode: 'native-tempo', playbackSpeedExtensions: ['spc'] }), extensionForPath: () => 'spc', normalizeExtension: value => value };
  return makeTiming(state, playbackBackends, () => 6);
}

test('shared preview is already output time and must not be tempo-scaled twice', () => {
  const run = harness();
  const track = { id: 'one', path: 'one.spc', basePlaybackSeconds: 90 };
  run.timingPlans.set('one', { pre_fade_seconds: 45, fade_seconds: 6, total_seconds: 51, is_long_play: true });
  assert.equal(run.currentOutputBasePlaybackSeconds(track), 45);
  assert.equal(run.currentTotalSeconds(track), 51);
});

test('an unresolved preview uses the temporary catalog-duration fallback', () => {
  const run = harness();
  const track = { id: 'one', path: 'one.spc', basePlaybackSeconds: 90 };
  assert.equal(run.currentOutputBasePlaybackSeconds(track), 45);
});

test('unbounded shared long play remains unbounded', () => {
  const run = harness();
  const track = { id: 'one', path: 'one.spc' };
  run.timingPlans.set('one', { pre_fade_seconds: 0, fade_seconds: 6, total_seconds: 0, is_long_play: true });
  assert.equal(run.currentTotalSeconds(track), 0);
});

test('transport receives the user tempo while only the temporary estimate uses local limits', () => {
  const state = { unknownDurationSeconds: 150, playbackSpeedEnabled: true, playbackSpeed: { numerator: 8, denominator: 1 } };
  const backends = { forPath: () => ({ playbackSpeedMode: 'native-tempo', playbackSpeedExtensions: ['spc'], tempoMaximum: 4 }), extensionForPath: () => 'spc', normalizeExtension: value => value };
  const run = makeTiming(state, backends, () => 0);
  assert.deepEqual(run.requestedPlaybackSpeed(), { numerator: 8, denominator: 1 });
  assert.equal(run.currentOutputBasePlaybackSeconds({ id: 'one', path: 'one.spc', basePlaybackSeconds: 80 }), 20);
  state.playbackSpeedEnabled = false;
  assert.deepEqual(run.requestedPlaybackSpeed(), { numerator: 1, denominator: 1 });
});
