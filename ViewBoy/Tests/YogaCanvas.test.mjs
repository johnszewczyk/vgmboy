import assert from 'node:assert/strict';
import test from 'node:test';

const canvas = {
  style: {},
  frames: 0,
  listeners: new Map(),
  addEventListener(name, callback) { canvas.listeners.set(name, callback); },
  focus() {},
  getBoundingClientRect() {
    return {
      left: 0,
      top: 0,
      width: Number.parseFloat(canvas.style.width),
      height: Number.parseFloat(canvas.style.height),
    };
  },
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
const audioConfigCalls = [];
const reconfigureCalls = [];
const groupStateCalls = [];
const savedPreferences = [];
const savedPlaylistTabs = [];
let frontendSettingsChanged;
let catalogReloaded;
const originalRandom = Math.random;
let rows = [
  { playlistId: 'a', path: '/music/a.spc', filename: 'INITIAL_FILENAME.SPC', title: 'First', game: 'Sample', system: 'SNES' },
  { playlistId: 'b', path: '/music/b.spc', filename: 'INITIAL_FILENAME.SPC', title: 'Second', game: 'Sample', system: 'SNES' },
  { playlistId: 'c', path: '/music/c.spc', filename: 'INITIAL_FILENAME.SPC', title: 'Third', game: 'Sample', system: 'SNES' },
];
const otherRow = { playlistId: 'other', path: '/music/other.spc', title: 'Other Track', game: 'Other', system: 'ZZZ' };
let ended;
let generation = 0;
const bridge = {
  playbackBackends: [{ id: 'libgme', supportsTempo: true, extensions: ['spc'] }],
  frontendSettingsLoad: async () => ({ appVolume: 1, repeatMode: 'off' }),
  frontendSettingsSave: async (settings) => { savedPreferences.push({ ...settings }); },
  playlistTabsLoad: async () => null,
  playlistTabsSave: async (settings) => { savedPlaylistTabs.push(structuredClone(settings)); },
  nativePlaybackAudioConfig: async (...args) => { audioConfigCalls.push(args); },
  databaseGames: async () => [
    { rootId: 1, name: 'Sample', displayName: 'Sample', system: 'SNES', trackCount: 3 },
    { rootId: 2, name: 'Other', displayName: 'Other', system: 'ZZZ', trackCount: 1 },
  ],
  databaseGameTracks: async (games) => games[0]?.name === 'Other' ? [otherRow] : rows,
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
  nativePlaybackReconfigure: async (request) => {
    reconfigureCalls.push(request);
    return { transport_state: 'playing', generation };
  },
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
  onFrontendSettingsChanged(callback) { frontendSettingsChanged = callback; },
  onCatalogReloaded(callback) { catalogReloaded = callback; },
  onLibrarySnapshot() {},
};
globalThis.window = globalThis;
globalThis.innerWidth = 420;
globalThis.innerHeight = 300;
globalThis.devicePixelRatio = 2;
globalThis.addEventListener = (name, callback) => windowListeners.set(name, callback);
globalThis.requestAnimationFrame = (callback) => setImmediate(() => callback(performance.now() + 250));
globalThis.cancelAnimationFrame = (frame) => clearImmediate(frame);
globalThis.document = { documentElement: { dataset: {} }, querySelector(selector) {
  if (selector === '#lcd') return canvas;
  if (selector === '#screen-window') return screen;
  return status;
} };
globalThis.viewBoy = bridge;
const displayOptionsStore = new Map();
globalThis.localStorage = {
  getItem(key) { return displayOptionsStore.get(key) ?? null; },
  setItem(key, value) { displayOptionsStore.set(key, value); },
};
const tick = () => new Promise((resolve) => setImmediate(resolve));
function pixelChecksum(data) {
  let hash = 2166136261;
  for (const value of data) hash = Math.imul(hash ^ value, 16777619);
  return hash >>> 0;
}

test('canvas renders adaptive columns, grouped options, and native playback', async () => {
  const { animationFrameIsDue } = await import('../Sources/ViewBoy/Resources/yoga-app.js');
  const animationGate = {};
  assert.equal(animationFrameIsDue(animationGate, 0), true, 'the first animation frame paints immediately');
  assert.equal(animationFrameIsDue(animationGate, 1000 / 120), false,
    '120 Hz displays skip alternate updates to preserve the 60 Hz cap');
  assert.equal(animationFrameIsDue(animationGate, 1000 / 60), true,
    'the next update paints at 60 Hz');
  assert.equal(animationFrameIsDue(animationGate, 1000 / 40), false,
    'faster-than-target display frames remain gated');
  assert.equal(animationFrameIsDue(animationGate, 1000 / 30), true,
    '60 Hz spaced updates are accepted');
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
  assert.ok(canvas.frames >= firstLayoutFrameCount + 1,
    'resizing repaints the table viewport while preserving the complete column strip');
  globalThis.ViewBoy.dispatch('playPause');
  await tick();
  assert.equal(calls.find(([name]) => name === 'start')[1].path, '/music/a.spc');
  await ended({ transport_state: 'ended', generation, status_sequence: generation + 1 });
  assert.deepEqual(calls.find(([name]) => name === 'retire')[1].playlistIds, ['a', 'b', 'c']);
  await tick();
  await tick();
  assert.equal(calls.filter(([name]) => name === 'start').at(-1)[1].path, '/music/b.spc');

  globalThis.ViewBoy.dispatch('longPlay');
  globalThis.ViewBoy.dispatch('repeatOne');
  await tick();
  assert.equal(savedPreferences.at(-1).longPlayEnabled, true);
  assert.equal(savedPreferences.at(-1).repeatMode, 'one');
  await ended({ transport_state: 'ended', generation, status_sequence: generation + 1 });
  assert.equal(calls.filter(([name]) => name === 'start').at(-1)[1].path, '/music/b.spc',
    'Repeat One restarts the current track when playback completes');
  assert.equal(calls.filter(([name]) => name === 'start').at(-1)[1].longPlayEnabled, true,
    'Long Play is included in the native playback request');
  globalThis.ViewBoy.dispatch('repeatOne');
  globalThis.ViewBoy.dispatch('playlistRandom');
  await tick();
  globalThis.Math.random = () => 0;
  globalThis.ViewBoy.dispatch('next');
  await tick();
  await tick();
  const firstShuffleTrack = calls.filter(([name]) => name === 'start').at(-1)[1].path;
  assert.ok(['/music/a.spc', '/music/c.spc'].includes(firstShuffleTrack));
  globalThis.ViewBoy.dispatch('next');
  await tick();
  await tick();
  assert.notEqual(calls.filter(([name]) => name === 'start').at(-1)[1].path, firstShuffleTrack,
    'playlist random plays every queue item once per cycle');
  const shuffledStartCount = calls.filter(([name]) => name === 'start').length;
  globalThis.ViewBoy.dispatch('next');
  await tick();
  assert.equal(calls.filter(([name]) => name === 'start').length, shuffledStartCount,
    'playlist random does not repeat until the next cycle');
  globalThis.ViewBoy.dispatch('previous');
  await tick();
  assert.equal(calls.filter(([name]) => name === 'start').at(-1)[1].path, firstShuffleTrack,
    'Previous follows the random playback history');
  globalThis.ViewBoy.dispatch('next');
  await tick();
  assert.equal(calls.filter(([name]) => name === 'start').at(-1)[1].path, '/music/c.spc');

  globalThis.Math.random = () => 0.999999;
  globalThis.ViewBoy.dispatch('libraryRandom');
  await tick();
  globalThis.ViewBoy.dispatch('next');
  await tick();
  await tick();
  assert.equal(calls.filter(([name]) => name === 'start').at(-1)[1].path, '/music/other.spc',
    'Library Random weights game groups by track count and loads only the selected game');
  globalThis.ViewBoy.dispatch('previous');
  await tick();
  assert.equal(calls.filter(([name]) => name === 'start').at(-1)[1].path, '/music/c.spc');
  globalThis.ViewBoy.dispatch('next');
  await tick();
  await tick();
  assert.equal(calls.filter(([name]) => name === 'start').at(-1)[1].path, '/music/other.spc');
  const beforeLibraryEnd = calls.filter(([name]) => name === 'start').length;
  await ended({ transport_state: 'ended', generation, status_sequence: generation + 1 });
  assert.equal(calls.filter(([name]) => name === 'start').length, beforeLibraryEnd + 1,
    'Library Random advances on natural completion');
  assert.notEqual(calls.filter(([name]) => name === 'start').at(-1)[1].path, '/music/other.spc');
  globalThis.Math.random = originalRandom;
  const libraryPixels = pixelChecksum(canvas.image.data);
  globalThis.ViewBoy.dispatch('settings');
  assert.match(status.textContent, /SETTINGS/);
  assert.notEqual(pixelChecksum(canvas.image.data), libraryPixels, 'Options paints a distinct grouped screen');
  const gameBoyPixels = pixelChecksum(canvas.image.data);
  const clickScreen = (x, y) => {
    const rect = canvas.getBoundingClientRect();
    canvas.listeners.get('click')({ clientX: rect.width * x, clientY: rect.height * y, detail: 1 });
  };
  const pageY = [0.155, 0.195, 0.235, 0.275, 0.315];
  const clickPage = (index) => clickScreen(0.08, pageY[index]);
  const commandKey = (key) => canvas.listeners.get('keydown')({
    key,
    code: key === ',' ? 'Comma' : `Digit${key}`,
    metaKey: true,
    ctrlKey: false,
    shiftKey: false,
    preventDefault() {},
  });
  clickScreen(0.80, 0.247);
  const nightBoyPixels = pixelChecksum(canvas.image.data);
  assert.notEqual(nightBoyPixels, gameBoyPixels, 'NightBoy repaints the same four-tone pixel screen with its dark-purple palette');
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).theme, 'NIGHTBOY');
  assert.equal(document.documentElement.dataset.theme, 'NIGHTBOY',
    'the selected LCD theme also updates the surrounding shell');
  clickScreen(0.80, 0.287);
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).contrast, 'HIGH_CONTRAST',
    'the ink control persists the brighter silver high-contrast setting');
  clickPage(1);
  assert.notEqual(pixelChecksum(canvas.image.data), nightBoyPixels, 'Options sub-pages navigate inside the LCD');
  globalThis.ViewBoy.dispatch('optionsPage:PLAYBACK');
  clickScreen(0.84, 0.287);
  await tick();
  assert.equal(savedPreferences.at(-1).repeatMode, 'one',
    'the Playback page repeat buttons save their selected mode');
  clickScreen(0.47, 0.327);
  await tick();
  assert.equal(savedPreferences.at(-1).randomMode, 'off',
    'the Playback page random buttons save their selected mode');
  const checkedRowPixels = pixelChecksum(canvas.image.data);
  clickScreen(0.50, 0.207);
  await tick();
  assert.equal(savedPreferences.at(-1).longPlayEnabled, false,
    'the Playback page checkbox updates the native playback preferences');
  assert.notEqual(pixelChecksum(canvas.image.data), checkedRowPixels,
    'the bitmap checkbox marker visibly changes with the saved value');
  clickPage(2);
  globalThis.ViewBoy.dispatch('optionsPage:AUDIO');
  clickScreen(0.50, 0.207);
  await tick();
  assert.equal(savedPreferences.at(-1).monoEnabled, true,
    'the Audio page output checkbox saves and applies mono output');
  clickScreen(0.35, 0.247);
  await tick();
  assert.equal(savedPreferences.at(-1).appVolume, 0.9,
    'the Audio page volume button updates native audio preferences');
  clickScreen(0.50, 0.364);
  await tick();
  assert.equal(savedPreferences.at(-1).equalizerEnabled, true,
    'the Audio page equalizer checkbox updates native audio preferences');
  assert.equal(audioConfigCalls.at(-1)[1], true,
    'the equalizer toggle is applied to the native audio path');
  clickScreen(0.63, 0.412);
  await tick();
  const changedBandGain = savedPreferences.at(-1).equalizerBandGains[0];
  assert.notEqual(changedBandGain, 0,
    'clicking a full-width equalizer bar changes its gain');
  assert.equal(Number.isInteger(changedBandGain * 2), true,
    'equalizer bars quantize to the supported half-decibel granularity');
  assert.equal(audioConfigCalls.at(-1)[2][0], changedBandGain,
    'equalizer bar edits are applied to the native audio path');
  clickPage(1);
  globalThis.ViewBoy.dispatch('optionsPage:PLAYBACK');
  clickScreen(0.92, 0.443);
  await tick();
  assert.equal(savedPreferences.at(-1).manualPlayTimeSeconds, 210,
    'the Long Play duration adjuster increases in 30-second steps');
  assert.equal(reconfigureCalls.at(-1).manualPlayMilliseconds, 210_000,
    'Long Play duration changes reconfigure the active native track');
  globalThis.ViewBoy.dispatch('newPlaylistTab');
  await tick();
  assert.equal(savedPlaylistTabs.at(-1)?.tabs.length, 2,
    'the plus tab control duplicates the current list and persists it through the native bridge');
  const [firstPlaylistID, secondPlaylistID] = savedPlaylistTabs.at(-1).tabs.map((tab) => tab.id);
  commandKey('1');
  await tick();
  assert.equal(savedPlaylistTabs.at(-1)?.activeID, firstPlaylistID,
    'Command-1 selects the first playlist tab');
  commandKey('2');
  await tick();
  assert.equal(savedPlaylistTabs.at(-1)?.activeID, secondPlaylistID,
    'Command-2 selects the second playlist tab');
  commandKey(',');
  assert.match(status.textContent, /SETTINGS/,
    'Command-comma opens the Options screen');
  globalThis.ViewBoy.dispatch('closePlaylistTab');
  await tick();
  assert.equal(savedPlaylistTabs.at(-1)?.tabs.length, 1,
    'closing the active tab selects the remaining playlist and saves the tab set');
  globalThis.ViewBoy.dispatch('closePlaylistTab');
  await tick();
  assert.equal(savedPlaylistTabs.at(-1)?.tabs.length, 1,
    'closing the final tab leaves one reusable empty playlist tab');
  assert.equal(savedPlaylistTabs.at(-1)?.tabs[0]?.playlist.length, 0,
    'closing the final tab saves it empty even while audio continues playing');
  globalThis.ViewBoy.dispatch('settings');
  clickPage(3);
  globalThis.ViewBoy.dispatch('optionsPage:INTERFACE');
  clickScreen(0.50, 0.207);
  await tick();
  assert.equal(savedPreferences.at(-1).columnAutoSize, false,
    'the Interface page checkbox updates the saved column behavior');
  clickPage(4);
  globalThis.ViewBoy.dispatch('optionsPage:LIBRARY');
  clickScreen(0.50, 0.207);
  await tick();
  assert.equal(savedPreferences.at(-1).columnVisibility.filename, false,
    'the Library page checkbox persists field visibility');
  clickPage(3);
  globalThis.ViewBoy.dispatch('optionsPage:INTERFACE');
  clickScreen(0.50, 0.207);
  await tick();
  assert.equal(savedPreferences.at(-1).columnAutoSize, true,
    'the Interface page checkbox can restore automatic sizing');
  clickPage(0);
  clickScreen(0.45, 0.247);
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).theme, 'GAMEBOY',
    'the palette selector returns to the authentic Game Boy theme');
  clickScreen(0.45, 0.287);
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).contrast, 'STANDARD');
  clickPage(1);
  clickScreen(0.50, 0.646);
  await tick();
  assert.equal(savedPreferences.at(-1).playbackSpeedEnabled, true,
    'the Playback page enables libgme tempo through the shared preferences');
  clickScreen(0.92, 0.686);
  await tick();
  assert.equal(savedPreferences.at(-1).playbackSpeed.numerator, 33,
    'the libgme speed adjuster advances in 1/32 steps');
  assert.equal(reconfigureCalls.at(-1).tempo, 33 / 32,
    'a speed change updates the active native decoder immediately');
  globalThis.ViewBoy.dispatch('library');
  screenWidth = 1400;
  windowListeners.get('resize')();
  await tick();
  await tick();
  const defaultColumnsPixels = pixelChecksum(canvas.image.data);
  frontendSettingsChanged({ appVolume: 1, longPlayEnabled: true, repeatMode: 'off', randomMode: 'library', columnVisibility: { game: false, filename: false } });
  await tick();
  assert.notEqual(pixelChecksum(canvas.image.data), defaultColumnsPixels, 'saved column visibility changes the playlist layout');
  const hiddenColumnsPixels = pixelChecksum(canvas.image.data);
  frontendSettingsChanged({ appVolume: 1, longPlayEnabled: true, repeatMode: 'off', randomMode: 'library', columnVisibility: { game: true, filename: false } });
  await tick();
  assert.notEqual(pixelChecksum(canvas.image.data), hiddenColumnsPixels,
    'restoring column visibility repaints the playlist columns');
  frontendSettingsChanged({ appVolume: 1, longPlayEnabled: true, repeatMode: 'off', randomMode: 'library', columnVisibility: { game: false, filename: true } });
  await tick();
  await tick();
  const shortFilenamePixels = pixelChecksum(canvas.image.data);
  rows = rows.map((track, index) => index === 0 ? {
    ...track,
    filename: 'INITIAL_FILENAME.SPC-WITH-A-LONG-TAIL-THAT-MUST-FIT-THE-COLUMN.SPC',
  } : track);
  await catalogReloaded();
  await tick();
  await tick();
  assert.notEqual(pixelChecksum(canvas.image.data), shortFilenamePixels,
    'the File column expands beyond its default width to fit the longest catalog value');

  rows = rows.map((track) => ({ ...track, filename: 'INITIAL_FILENAME.SPC' }));
  await catalogReloaded();
  screenWidth = 620;
  windowListeners.get('resize')();
  await tick();
  await tick();
  const narrowLayoutPixels = pixelChecksum(canvas.image.data);
  const rect = canvas.getBoundingClientRect();
  let contextMenuPrevented = false;
  const beforeColumnMenu = pixelChecksum(canvas.image.data);
  canvas.listeners.get('contextmenu')({
    clientX: rect.width * 0.60,
    clientY: rect.height * 0.13,
    preventDefault() { contextMenuPrevented = true; },
  });
  assert.ok(contextMenuPrevented, 'right-clicking a column heading opens its visibility menu');
  assert.notEqual(pixelChecksum(canvas.image.data), beforeColumnMenu,
    'the column menu is painted into the LCD framebuffer');
  clickScreen(0.62, 0.19);
  await tick();
  assert.equal(savedPreferences.at(-1).columnVisibility.filename, false,
    'the column menu hides the selected field through the native preference bridge');
  clickScreen(0.62, 0.19);
  await tick();
  assert.equal(savedPreferences.at(-1).columnVisibility.filename, true,
    'the same column menu restores the selected field');
  canvas.listeners.get('keydown')({ code: 'Escape', preventDefault() {} });
  canvas.listeners.get('wheel')({
    clientX: rect.width * 0.72,
    clientY: rect.height * 0.34,
    deltaX: 120,
    deltaY: 0,
    shiftKey: false,
    preventDefault() {},
  });
  assert.notEqual(pixelChecksum(canvas.image.data), narrowLayoutPixels,
    'the complete table scrolls horizontally inside its clipped viewport');

  const sendPointer = (name, x, y) => canvas.listeners.get(name)({
    clientX: rect.width * x,
    clientY: rect.height * y,
    pointerId: 1,
    preventDefault() {},
  });
  canvas.listeners.get('wheel')({
    clientX: rect.width * 0.72,
    clientY: rect.height * 0.34,
    deltaX: -500,
    deltaY: 0,
    shiftKey: false,
    preventDefault() {},
  });
  sendPointer('pointerdown', 0.60, 0.13);
  sendPointer('pointermove', 0.88, 0.13);
  sendPointer('pointerup', 0.88, 0.13);
  const savedColumnOrder = JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).columnOrder;
  assert.ok(savedColumnOrder.indexOf('filename') > savedColumnOrder.indexOf('title'),
    `dragging a header reorders columns and keeps the order in display preferences: ${savedColumnOrder.join(',')}`);
  assert.ok(!savedColumnOrder.includes('index'), 'the numbered column is pinned outside the movable order');
  const headerOrder = [...savedColumnOrder];
  sendPointer('pointerdown', 0.43, 0.13);
  sendPointer('pointermove', 0.80, 0.13);
  sendPointer('pointerup', 0.80, 0.13);
  assert.deepEqual(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).columnOrder, headerOrder,
    'dragging other headers across # cannot move the numbered column');
});
