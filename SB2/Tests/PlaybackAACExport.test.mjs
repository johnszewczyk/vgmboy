import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const source = await readFile(new URL('../Sources/SB2/Resources/app-playback.js', import.meta.url), 'utf8');
const start = source.indexOf('async function exportTrackAsAAC(');
const end = source.indexOf('\nfunction handleAACExportEvent(', start);
assert.ok(start >= 0 && end > start);

test('AAC export uses the same captured speed for timing and rendering', async () => {
  let resolvePlan, options, request;
  const state = { aacExportDirectory: '/tmp/exports', aacExportInProgress: false,
    playbackSpeedEnabled: true, playbackSpeed: { numerator: 2, denominator: 1 } };
  const run = new Function('state', 'bridge', 'resolvePlan', 'onOptions', `
    const window = { spcBoySB2: bridge };
    const playbackApp = { ui: { renderAll() {} } };
    const requestedPlaybackSpeed = () => state.playbackSpeedEnabled ? state.playbackSpeed : { numerator: 1, denominator: 1 };
    const resolveTimingPlan = (_, options) => { onOptions(options); return resolvePlan(); };
    ${source.slice(start, end)}
    return exportTrackAsAAC;
  `)(state, { nativeExportAAC: async value => { request = value; return { path: '/tmp/exports/one.aac' }; } },
     () => new Promise(resolve => { resolvePlan = resolve; }), value => { options = value; });
  const exporting = run({ path: '/tmp/one.spc', title: 'one' });
  await new Promise(resolve => setImmediate(resolve));
  state.playbackSpeed = { numerator: 3, denominator: 1 };
  resolvePlan({ pre_fade_seconds: 5, fade_seconds: 1 });
  await exporting;
  assert.deepEqual(options.tempo, { numerator: 2, denominator: 1 });
  assert.deepEqual(request.tempo, options.tempo);
  assert.equal(request.playMilliseconds, 5000);
});
