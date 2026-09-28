import assert from 'node:assert/strict';
import test from 'node:test';

const canvas = {
  style: {},
  addEventListener() {},
  focus() {},
  getContext() { return {
    createImageData(width, height) { return { data: new Uint8ClampedArray(width * height * 4) }; },
    putImageData(image) { canvas.image = image; },
  }; },
};
const status = { textContent: '' };
const calls = [];
const rows = [
  { playlistId: 'a', path: '/music/a.spc', title: 'First', game: 'Sample', system: 'SNES' },
  { playlistId: 'b', path: '/music/b.spc', title: 'Second', game: 'Sample', system: 'SNES' },
];
let ended;
let generation = 0;
const bridge = {
  frontendSettingsLoad: async () => ({ appVolume: 1, repeatMode: 'off' }),
  nativePlaybackAudioConfig: async () => {},
  databaseGames: async () => [{ rootId: 1, name: 'Sample', displayName: 'Sample', system: 'SNES' }],
  databaseGameTracks: async () => rows,
  nativePlaybackInit: async () => {},
  nativePlaybackState: async () => ({ transport_state: generation ? 'playing' : 'stopped', generation }),
  nativePlaybackStart: async (request) => {
    calls.push(['start', request]);
    return { transport_state: 'playing', generation: ++generation, status_sequence: generation };
  },
  playbackCompletionRetire: async (request) => {
    calls.push(['retire', request]);
    return { action: 'play', trackId: 'b' };
  },
  onNativePlaybackState() {},
  onNativePlaybackEnded(callback) { ended = callback; },
  onFrontendSettingsChanged() {},
  onCatalogReloaded() {},
  onLibrarySnapshot() {},
};
globalThis.window = globalThis;
globalThis.innerWidth = 420;
globalThis.innerHeight = 300;
globalThis.devicePixelRatio = 2;
globalThis.addEventListener = () => {};
globalThis.document = { querySelector(selector) { return selector === '#lcd' ? canvas : status; } };
globalThis.spcBoyWK = bridge;
const tick = () => new Promise((resolve) => setImmediate(resolve));

test('canvas renders live rows and uses native playback and queue retirement', async () => {
  await import('../Sources/ViewBoy/Resources/yoga-app.js');
  await tick();
  await tick();
  assert.match(status.textContent, /FIRST/i);
  assert.ok(canvas.image.data.some((value) => value !== 0));
  globalThis.SPCBoyWK.dispatch('playPause');
  await tick();
  assert.equal(calls.find(([name]) => name === 'start')[1].path, '/music/a.spc');
  await ended({ transport_state: 'ended', generation, status_sequence: generation + 1 });
  assert.deepEqual(calls.find(([name]) => name === 'retire')[1].playlistIds, ['a', 'b']);
  assert.equal(calls.filter(([name]) => name === 'start').at(-1)[1].path, '/music/b.spc');
  globalThis.SPCBoyWK.dispatch('settings');
  assert.match(status.textContent, /SETTINGS/);
});
