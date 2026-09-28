import assert from 'node:assert/strict';
import test from 'node:test';

const canvas = {
  style: {},
  frames: 0,
  addEventListener() {},
  focus() {},
  getContext() { return {
    createImageData(width, height) { return { data: new Uint8ClampedArray(width * height * 4) }; },
    putImageData(image) { canvas.image = image; canvas.frames += 1; },
  }; },
};
const status = { textContent: '' };
let screenWidth = 800;
const screen = { getBoundingClientRect() { return { width: screenWidth, height: 500 }; } };
const windowListeners = new Map();
const calls = [];
const groupStateCalls = [];
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
  databaseGroupState: async (current, action, groupName, gameID) => {
    groupStateCalls.push([action, groupName, gameID]);
    const expanded = new Set(current.expandedGroupNames);
    if (action === 'toggle') expanded.has(groupName) ? expanded.delete(groupName) : expanded.add(groupName);
    return {
      expandedGroupNames: [...expanded],
      selectedGroupName: action === 'selectGame' ? groupName : current.selectedGroupName,
      selectedGameID: action === 'selectGame' ? gameID : current.selectedGameID,
    };
  },
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
globalThis.addEventListener = (name, callback) => windowListeners.set(name, callback);
globalThis.requestAnimationFrame = (callback) => setImmediate(() => callback(performance.now() + 250));
globalThis.cancelAnimationFrame = (frame) => clearImmediate(frame);
globalThis.document = { querySelector(selector) {
  if (selector === '#lcd') return canvas;
  if (selector === '#screen-window') return screen;
  return status;
} };
globalThis.viewBoy = bridge;
const tick = () => new Promise((resolve) => setImmediate(resolve));

test('canvas renders adaptive columns, grouped options, and native playback', async () => {
  await import('../Sources/ViewBoy/Resources/yoga-app.js');
  await tick();
  await tick();
  assert.match(status.textContent, /FIRST/i);
  assert.ok(groupStateCalls.some(([action, system]) => action === 'toggle' && system === 'SNES'));
  assert.ok(groupStateCalls.some(([action, system, gameID]) =>
    action === 'selectGame' && system === 'SNES' && gameID === '1:SNES:Sample'));
  assert.ok(canvas.image.data.some((value) => value !== 0));
  const firstLayoutFrameCount = canvas.frames;
  screenWidth = 620;
  windowListeners.get('resize')();
  await tick();
  assert.ok(canvas.frames >= firstLayoutFrameCount + 2, 'auto-sized columns repaint through the shared resize transition');
  globalThis.ViewBoy.dispatch('playPause');
  await tick();
  assert.equal(calls.find(([name]) => name === 'start')[1].path, '/music/a.spc');
  await ended({ transport_state: 'ended', generation, status_sequence: generation + 1 });
  assert.deepEqual(calls.find(([name]) => name === 'retire')[1].playlistIds, ['a', 'b']);
  await tick();
  await tick();
  assert.equal(calls.filter(([name]) => name === 'start').at(-1)[1].path, '/music/b.spc');
  const libraryPixels = new Uint8Array(canvas.image.data);
  globalThis.ViewBoy.dispatch('settings');
  assert.match(status.textContent, /SETTINGS/);
  assert.notDeepEqual(canvas.image.data, libraryPixels, 'Options paints a distinct grouped screen');
});
