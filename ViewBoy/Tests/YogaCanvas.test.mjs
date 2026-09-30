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
const screen = { getBoundingClientRect() { return { width: screenWidth, height: 800 }; } };
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
let nextFrameAdvanceMs = 250;
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
globalThis.requestAnimationFrame = (callback) => setImmediate(() => {
  const advance = nextFrameAdvanceMs;
  nextFrameAdvanceMs = 250;
  callback(performance.now() + advance);
});
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
  const { animationFrameIsDue, hitTargetSnapshot } = await import('../Sources/ViewBoy/Resources/yoga-app.js');
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
  const toolbarTargets = hitTargetSnapshot();
  const transportTargets = ['PREVIOUS', 'PLAY', 'NEXT', 'STOP']
    .map((name) => toolbarTargets.find((target) => target.name === name));
  const modeTargets = ['LONG PLAY', 'REPEAT ONE', 'PLAYLIST RANDOM', 'LIBRARY RANDOM']
    .map((name) => toolbarTargets.find((target) => target.name === name));
  assert.ok(transportTargets.every((target) => target && target.box.y === transportTargets[0].box.y),
    'core transport buttons share one toolbar row');
  assert.ok(modeTargets.every((target) => target && target.box.y === modeTargets[0].box.y),
    'playback methods share a second toolbar row');
  assert.ok(Math.max(...transportTargets.map((target) => target.box.width))
    - Math.min(...transportTargets.map((target) => target.box.width)) <= 1,
  'core transport buttons share their toolbar width evenly');
  assert.ok(Math.max(...modeTargets.map((target) => target.box.width))
    - Math.min(...modeTargets.map((target) => target.box.width)) <= 1,
    'playback methods share their toolbar width evenly');
  assert.ok(Math.abs(transportTargets[0].box.x - modeTargets[0].box.x) <= 1,
    'the centered half-width wrapper aligns both toolbar rows');
  assert.ok(toolbarTargets.some((target) => target.name === 'OPTIONS'),
    'Options remains reachable from the sidebar controls');
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
  const clickEntry = (target) => {
    const rect = canvas.getBoundingClientRect();
    const logicalWidth = canvas.width / 3;
    const logicalHeight = canvas.height / 3;
    canvas.listeners.get('click')({
      clientX: rect.width * (target.box.x + target.box.width / 2) / logicalWidth,
      clientY: rect.height * (target.box.y + target.box.height / 2) / logicalHeight,
      detail: 1,
    });
  };
  const clickTarget = (name, occurrence = 0, xFraction = 0.5, yFraction = 0.5) => {
    const target = hitTargetSnapshot().filter((entry) => entry.name === name)[occurrence];
    assert.ok(target, `the ${name} control is present in the current screen; found ${hitTargetSnapshot().map((entry) => entry.name).join(', ')}`);
    const logicalWidth = canvas.width / 3;
    const logicalHeight = canvas.height / 3;
    clickScreen(
      (target.box.x + target.box.width * xFraction) / logicalWidth,
      (target.box.y + target.box.height * yFraction) / logicalHeight,
    );
  };
  const typeSearchKey = (key) => canvas.listeners.get('keydown')({
    key,
    code: key === 'Backspace' ? 'Backspace' : key === 'Escape' ? 'Escape' : `Key${key.toUpperCase()}`,
    metaKey: false,
    ctrlKey: false,
    altKey: false,
    shiftKey: false,
    preventDefault() {},
  });
  const pages = ['DISPLAY', 'THEME', 'TRANSPORT', 'PLAYBACK', 'METHODS', 'AUDIO', 'INTERFACE', 'LIBRARY'];
  const clickPage = (index) => clickTarget(pages[index]);
  globalThis.ViewBoy.dispatch('library');
  assert.ok(hitTargetSnapshot().some((target) => target.searchField && target.name === 'SEARCH LIBRARY'),
    'the sidebar begins with a pixel-rendered search field');
  clickTarget('SEARCH LIBRARY');
  for (const character of 'sample') typeSearchKey(character);
  const filteredSidebar = hitTargetSnapshot();
  const searchTargets = filteredSidebar.map((target) => target.name);
  assert.ok(searchTargets.includes('Sample'), 'typing filters the sidebar tree to matching catalog games');
  assert.equal(searchTargets.includes('Other'), false, 'nonmatching games are hidden by the sidebar search');
  const parentSystemRow = filteredSidebar.find((target) => target.name.endsWith('SNES'));
  const childGameRow = filteredSidebar.find((target) => target.name === 'Sample');
  assert.ok(parentSystemRow && childGameRow, 'the filtered system disclosure and game row are both visible');
  assert.equal(childGameRow.textInset - parentSystemRow.textInset, 2 * childGameRow.glyphAdvance,
    'sidebar game labels align exactly two glyph advances after their parent disclosure marker');
  typeSearchKey('Escape');
  assert.ok(hitTargetSnapshot().some((target) => target.name.includes('ZZZ')),
    'Escape clears the search and restores the complete sidebar tree');
  typeSearchKey('Escape');
  const tabFrames = () => hitTargetSnapshot().filter((target) => target.reorderKind === 'tab');
  const tabTitles = () => hitTargetSnapshot().filter((target) => target.playlistTabTitle);
  const oldTabFrames = tabFrames();
  const oldTabIDs = new Set(oldTabFrames.map((target) => target.reorderKey));
  nextFrameAdvanceMs = 125;
  globalThis.ViewBoy.dispatch('newPlaylistTab');
  await tick();
  const openingFrames = tabFrames();
  const openingTab = openingFrames.find((target) => !oldTabIDs.has(target.reorderKey));
  const neighboringTab = openingFrames.find((target) => oldTabIDs.has(target.reorderKey));
  assert.ok(openingTab && neighboringTab && openingTab.box.width > 0
    && openingTab.box.width < neighboringTab.box.width,
  'a new tab slides open with the shared eased width animation');
  await tick();
  const settledTabWidths = tabFrames().map((target) => target.box.width);
  assert.ok(Math.max(...settledTabWidths) - Math.min(...settledTabWidths) <= 1,
    'the opening tab reaches its equal-share resting width');
  const tabGap = () => {
    const titles = tabTitles();
    const closes = hitTargetSnapshot().filter((target) => target.playlistTabClose);
    assert.equal(titles.length, 2, 'both playlist tabs expose a clipped title region');
    assert.equal(closes.length, 2, 'each playlist tab exposes its unframed close glyph');
    return titles[1].box.x - (closes[0].box.x + closes[0].box.width);
  };
  const defaultTabGap = tabGap();
  clickTarget('OPTIONS');
  clickPage(6);
  clickTarget('UI GAP +');
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).uiGapDots, 5,
    'the renamed UI Gap setting persists under its current name');
  globalThis.ViewBoy.dispatch('library');
  assert.ok(tabGap() > defaultTabGap, 'playlist tabs respond to UI Gap while retaining independent column spacing');
  clickTarget('X', 1);
  clickTarget('OPTIONS');
  clickPage(6);
  clickTarget('UI GAP -');
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).uiGapDots, 4,
    'the UI Gap returns to its original value');
  clickTarget('BACK');
  globalThis.ViewBoy.dispatch('settings');
  const commandKey = (key) => canvas.listeners.get('keydown')({
    key,
    code: key === ',' ? 'Comma' : `Digit${key}`,
    metaKey: true,
    ctrlKey: false,
    shiftKey: false,
    preventDefault() {},
  });
  clickPage(1);
  clickTarget('THEME NIGHTBOY');
  const nightBoyPixels = pixelChecksum(canvas.image.data);
  assert.notEqual(nightBoyPixels, gameBoyPixels, 'NightBoy repaints the same four-tone pixel screen with its dark-purple palette');
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).theme, 'NIGHTBOY');
  assert.equal(document.documentElement.dataset.theme, 'NIGHTBOY',
    'the selected LCD theme also updates the surrounding shell');
  clickTarget('INK BRIGHT');
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).contrast, 'HIGH_CONTRAST',
    'the ink control persists the brighter silver high-contrast setting');
  clickPage(3);
  assert.notEqual(pixelChecksum(canvas.image.data), nightBoyPixels, 'Options sub-pages navigate inside the LCD');
  globalThis.ViewBoy.dispatch('optionsPage:PLAYBACK');
  clickTarget('REPEAT ONE');
  await tick();
  assert.equal(savedPreferences.at(-1).repeatMode, 'one',
    'the Playback page repeat buttons save their selected mode');
  clickTarget('RANDOM OFF');
  await tick();
  assert.equal(savedPreferences.at(-1).randomMode, 'off',
    'the Playback page random buttons save their selected mode');
  const checkedRowPixels = pixelChecksum(canvas.image.data);
  clickTarget('LONG PLAY');
  await tick();
  assert.equal(savedPreferences.at(-1).longPlayEnabled, false,
    'the Playback page checkbox updates the native playback preferences');
  assert.notEqual(pixelChecksum(canvas.image.data), checkedRowPixels,
    'the bitmap checkbox marker visibly changes with the saved value');
  clickPage(5);
  globalThis.ViewBoy.dispatch('optionsPage:AUDIO');
  clickTarget('MONO OUTPUT');
  await tick();
  assert.equal(savedPreferences.at(-1).monoEnabled, true,
    'the Audio page output checkbox saves and applies mono output');
  clickTarget('VOLUME -');
  await tick();
  assert.equal(savedPreferences.at(-1).appVolume, 0.9,
    'the Audio page volume button updates native audio preferences');
  clickTarget('EQUALIZER');
  await tick();
  assert.equal(savedPreferences.at(-1).equalizerEnabled, true,
    'the Audio page equalizer checkbox updates native audio preferences');
  assert.equal(audioConfigCalls.at(-1)[1], true,
    'the equalizer toggle is applied to the native audio path');
  clickTarget('EQ 31 HZ', 0, 0.99);
  await tick();
  const changedBandGain = savedPreferences.at(-1).equalizerBandGains[0];
  assert.equal(changedBandGain, 12,
    'the right edge of a full-width equalizer bar selects the +12 dB boost limit');
  assert.equal(Number.isInteger(changedBandGain * 2), true,
    'equalizer bars quantize to the supported half-decibel granularity');
  assert.equal(audioConfigCalls.at(-1)[2][0], changedBandGain,
    'equalizer bar edits are applied to the native audio path');
  clickTarget('EQ 31 HZ', 0, 0.01);
  await tick();
  assert.equal(savedPreferences.at(-1).equalizerBandGains[0], 0,
    'the left edge of a full-width equalizer bar returns the band to flat');
  clickPage(3);
  globalThis.ViewBoy.dispatch('optionsPage:PLAYBACK');
  clickTarget('LONG PLAY +');
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
  clickTarget('BACK');
  assert.equal(hitTargetSnapshot().filter((target) => target.name === 'X').length, 2,
    'each visible playlist tab uses the compact X close control');
  clickTarget('X', 1);
  await tick();
  assert.equal(savedPlaylistTabs.at(-1)?.tabs.length, 1,
    'closing the active tab selects the remaining playlist and saves the tab set');
  clickTarget('X');
  await tick();
  assert.equal(savedPlaylistTabs.at(-1)?.tabs.length, 1,
    'closing the final tab leaves one reusable empty playlist tab');
  assert.equal(savedPlaylistTabs.at(-1)?.tabs[0]?.playlist.length, 0,
    'closing the final tab saves it empty even while audio continues playing');
  globalThis.ViewBoy.dispatch('settings');
  clickPage(6);
  globalThis.ViewBoy.dispatch('optionsPage:INTERFACE');
  clickTarget('AUTO-SIZE COLUMNS');
  await tick();
  assert.equal(savedPreferences.at(-1).columnAutoSize, false,
    'the Interface page checkbox updates the saved column behavior');
  assert.equal(hitTargetSnapshot().some((target) => target.name === 'PREVIOUS'), false,
    'transport controls are kept off the Options screen');
  const paddingBefore = hitTargetSnapshot().find((target) => target.name === 'BACK').box.height;
  clickTarget('CONTROL PADDING +');
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).controlPaddingDots, 5,
    'control padding is adjustable and persists in display preferences');
  assert.ok(hitTargetSnapshot().find((target) => target.name === 'BACK').box.height > paddingBefore,
    'control padding changes the shared button row height');
  clickTarget('UI GAP +');
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).uiGapDots, 5,
    'the shared interface gap has an independent persisted setting');
  clickTarget('PLAYLIST GAP +');
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).playlistGapDots, 5,
    'playlist column and tab spacing has an independent persisted setting');
  clickTarget('CONTROL PADDING -');
  clickTarget('UI GAP -');
  clickTarget('PLAYLIST GAP -');
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).controlPaddingDots, 4);
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).uiGapDots, 4);
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).playlistGapDots, 4);
  clickPage(7);
  globalThis.ViewBoy.dispatch('optionsPage:LIBRARY');
  clickTarget('FILE');
  await tick();
  assert.equal(savedPreferences.at(-1).columnVisibility.filename, false,
    'the Library page checkbox persists field visibility');
  clickPage(6);
  globalThis.ViewBoy.dispatch('optionsPage:INTERFACE');
  clickTarget('AUTO-SIZE COLUMNS');
  await tick();
  assert.equal(savedPreferences.at(-1).columnAutoSize, true,
    'the Interface page checkbox can restore automatic sizing');
  clickPage(1);
  clickTarget('THEME GAMEBOY');
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).theme, 'GAMEBOY',
    'the palette selector returns to the authentic Game Boy theme');
  clickTarget('INK LCD GREEN');
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).contrast, 'STANDARD');
  clickPage(2);
  clickTarget('BUTTONS SYMBOLS');
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).transportSymbols, true,
    'the Transport page persists its Words/Symbols control setting');
  globalThis.ViewBoy.dispatch('library');
  const symbolTransportPixels = pixelChecksum(canvas.image.data);
  globalThis.ViewBoy.dispatch('settings');
  clickPage(2);
  clickTarget('BUTTONS WORDS');
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).transportSymbols, false);
  globalThis.ViewBoy.dispatch('library');
  assert.notEqual(pixelChecksum(canvas.image.data), symbolTransportPixels,
    'symbol mode replaces word labels while keeping equal-width toolbar controls');
  globalThis.ViewBoy.dispatch('settings');
  clickPage(4);
  clickTarget('LIBGME SPEED');
  await tick();
  assert.equal(savedPreferences.at(-1).playbackSpeedEnabled, true,
    'the Playback page enables libgme tempo through the shared preferences');
  clickTarget('LIBGME RATE +');
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
  const contextFileHeader = hitTargetSnapshot().find((target) => target.name === 'FILE');
  assert.ok(contextFileHeader, 'the current playlist exposes its File heading');
  const logicalWidth = canvas.width / 3;
  const logicalHeight = canvas.height / 3;
  canvas.listeners.get('contextmenu')({
    clientX: rect.width * (contextFileHeader.box.x + contextFileHeader.box.width / 2) / logicalWidth,
    clientY: rect.height * (contextFileHeader.box.y + contextFileHeader.box.height / 2) / logicalHeight,
    preventDefault() { contextMenuPrevented = true; },
  });
  assert.ok(contextMenuPrevented, 'right-clicking a column heading opens its visibility menu');
  assert.notEqual(pixelChecksum(canvas.image.data), beforeColumnMenu,
    'the column menu is painted into the LCD framebuffer');
  const initialFileToggle = hitTargetSnapshot().find((target) => target.name === 'FILE' && target.columnMenuItem);
  assert.ok(initialFileToggle, 'the open menu exposes the File checkbox as a hit target');
  const savesBeforeHide = savedPreferences.length;
  clickEntry(initialFileToggle);
  await tick();
  assert.equal(savedPreferences.length, savesBeforeHide + 1,
    'the context-menu checkbox persists its column visibility change');
  assert.equal(savedPreferences.at(-1).columnVisibility.filename, false,
    'the column menu hides the selected field through the native preference bridge');
  const reopenHeader = hitTargetSnapshot().find((target) => target.name.startsWith('TITLE'));
  let reopenMenuPrevented = false;
  canvas.listeners.get('contextmenu')({
    clientX: rect.width * (reopenHeader.box.x + reopenHeader.box.width / 2) / logicalWidth,
    clientY: rect.height * (reopenHeader.box.y + reopenHeader.box.height / 2) / logicalHeight,
    preventDefault() { reopenMenuPrevented = true; },
  });
  assert.ok(reopenMenuPrevented, 'the column menu can reopen from the still-visible Title heading');
  assert.ok(hitTargetSnapshot().some((target) => target.name === 'FILE'),
    'the reopened menu includes the hidden File column toggle');
  const visibleFileToggle = hitTargetSnapshot().filter((target) => target.name === 'FILE')
    .find((target) => target.columnMenuItem);
  assert.ok(visibleFileToggle, 'the File hit target belongs to the open visibility menu');
  const savesBeforeRestore = savedPreferences.length;
  clickEntry(visibleFileToggle);
  await tick();
  assert.equal(savedPreferences.length, savesBeforeRestore + 1,
    'selecting a menu checkbox submits a native preference update');
  assert.equal(savedPreferences.at(-1).columnVisibility.filename, true,
    `the same column menu restores the selected field; recent saves ${JSON.stringify(savedPreferences.slice(-3).map((entry) => entry.columnVisibility?.filename))}`);
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
  const headerCenter = (name) => {
    const target = hitTargetSnapshot().find((entry) => entry.name === name);
    assert.ok(target, `the ${name} playlist heading is visible`);
    return {
      x: (target.box.x + target.box.width / 2) / (canvas.width / 3),
      y: (target.box.y + target.box.height / 2) / (canvas.height / 3),
      box: target.box,
    };
  };
  const fileHeader = headerCenter('FILE');
  const titleHeader = headerCenter('TITLE');
  const titleRightSide = (titleHeader.box.x + titleHeader.box.width * 0.75) / (canvas.width / 3);
  sendPointer('pointerdown', fileHeader.x, fileHeader.y);
  sendPointer('pointermove', titleRightSide, titleHeader.y);
  await tick();
  const pushedTitleHeader = headerCenter('TITLE');
  assert.ok(pushedTitleHeader.box.x < titleHeader.box.x,
    'neighboring headings push aside during the drag using the shared easing duration');
  sendPointer('pointerup', titleRightSide, titleHeader.y);
  const savedColumnOrder = JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).columnOrder;
  assert.ok(savedColumnOrder.indexOf('filename') > savedColumnOrder.indexOf('title'),
    `dragging a header reorders columns and keeps the order in display preferences: ${savedColumnOrder.join(',')}`);
  assert.ok(!savedColumnOrder.includes('index'), 'the numbered column is pinned outside the movable order');
  const headerOrder = [...savedColumnOrder];
  const titleHeaderAfter = headerCenter('TITLE');
  const indexHeader = headerCenter('#');
  sendPointer('pointerdown', titleHeaderAfter.x, titleHeaderAfter.y);
  sendPointer('pointermove', indexHeader.x, indexHeader.y);
  sendPointer('pointerup', indexHeader.x, indexHeader.y);
  assert.deepEqual(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).columnOrder, headerOrder,
    'dragging other headers across # cannot move the numbered column');

  globalThis.ViewBoy.dispatch('newPlaylistTab');
  await tick();
  assert.ok(tabTitles().every((target) => target.textAlign === 'left'),
    'playlist tab labels remain left-aligned');
  const tabsBeforeDrag = tabFrames().sort((first, second) => first.box.x - second.box.x);
  assert.ok(tabsBeforeDrag.length >= 2, 'at least two playlist tabs can be rearranged');
  const tabIDsBeforeDrag = tabsBeforeDrag.map((target) => target.reorderKey);
  const shiftedNeighborID = tabIDsBeforeDrag[1];
  const shiftedNeighborBefore = tabTitles().find((target) => target.playlistTabId === shiftedNeighborID);
  const sourceTab = tabsBeforeDrag[0];
  const destinationTab = tabsBeforeDrag.at(-1);
  const sourceTitle = tabTitles().find((target) => target.playlistTabId === sourceTab.reorderKey);
  sendPointer('pointerdown', (sourceTitle.box.x + Math.min(3, sourceTitle.box.width / 3)) / (canvas.width / 3),
    (sourceTitle.box.y + sourceTitle.box.height / 2) / (canvas.height / 3));
  sendPointer('pointermove', (destinationTab.box.x + destinationTab.box.width * 0.85) / (canvas.width / 3),
    (destinationTab.box.y + destinationTab.box.height / 2) / (canvas.height / 3));
  await tick();
  const shiftedNeighborAfter = tabTitles().find((target) => target.playlistTabId === shiftedNeighborID);
  assert.ok(shiftedNeighborAfter.box.x < shiftedNeighborBefore.box.x,
    'neighboring tabs push aside during the drag');
  sendPointer('pointerup', (destinationTab.box.x + destinationTab.box.width * 0.85) / (canvas.width / 3),
    (destinationTab.box.y + destinationTab.box.height / 2) / (canvas.height / 3));
  clickScreen((destinationTab.box.x + destinationTab.box.width * 0.85) / (canvas.width / 3),
    (destinationTab.box.y + destinationTab.box.height / 2) / (canvas.height / 3));
  await tick();
  await tick();
  const savedTabOrder = savedPlaylistTabs.at(-1).tabs.map((tab) => tab.id);
  assert.deepEqual(savedTabOrder, [...tabIDsBeforeDrag.slice(1), tabIDsBeforeDrag[0]],
    'dropping a tab commits its pushed position to the native playlist snapshot');
  const closingTabID = savedTabOrder[0];
  const closeControl = hitTargetSnapshot().find((target) =>
    target.playlistTabClose && target.playlistTabId === closingTabID);
  assert.ok(closeControl, 'the reordered tab exposes its own close control');
  nextFrameAdvanceMs = 125;
  clickScreen((closeControl.box.x + closeControl.box.width / 2) / (canvas.width / 3),
    (closeControl.box.y + closeControl.box.height / 2) / (canvas.height / 3));
  await tick();
  const closingFrame = tabFrames().find((target) => target.reorderKey === closingTabID);
  const remainingFrame = tabFrames().find((target) => target.reorderKey !== closingTabID);
  assert.ok(closingFrame && remainingFrame && closingFrame.box.width > 0
    && closingFrame.box.width < remainingFrame.box.width,
  'a closing tab slides shut as its neighbor expands');
  await tick();
  assert.equal(tabFrames().some((target) => target.reorderKey === closingTabID), false,
    'the closed tab leaves the strip when its width animation finishes');

  bridge.databaseGames = async () => Array.from({ length: 80 }, (_, index) => ({
    rootId: 1000 + index,
    name: `Scroll Game ${String(index).padStart(2, '0')}`,
    displayName: `Scroll Game ${String(index).padStart(2, '0')}`,
    system: 'SCROLL',
    trackCount: 1,
  }));
  await catalogReloaded();
  const sidebarGames = () => hitTargetSnapshot().filter((target) => target.name.startsWith('Scroll Game '));
  const scrollGameBefore = sidebarGames().find((target) => target.name === 'Scroll Game 00');
  const scrollGameNext = sidebarGames().find((target) => target.name === 'Scroll Game 01');
  assert.ok(scrollGameBefore && scrollGameNext, 'the overflowing sidebar exposes its first game rows');
  const sidebarRowHeight = scrollGameNext.box.y - scrollGameBefore.box.y;
  canvas.listeners.get('wheel')({
    clientX: rect.width * 0.2,
    clientY: rect.height * 0.5,
    deltaX: 0,
    deltaY: 3,
    deltaMode: 0,
    shiftKey: false,
    preventDefault() {},
  });
  await tick();
  const scrollGameAfter = sidebarGames().find((target) => target.name === 'Scroll Game 00');
  const sidebarPixelMovement = scrollGameBefore.box.y - scrollGameAfter.box.y;
  assert.ok(sidebarPixelMovement > 0 && sidebarPixelMovement < sidebarRowHeight,
    `the sidebar advances by LCD pixels rather than whole rows (${sidebarPixelMovement}/${sidebarRowHeight})`);
});
