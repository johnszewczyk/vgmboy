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
    createImageData(width, height) {
      return { width, height, data: new Uint8ClampedArray(width * height * 4) };
    },
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
let closeWindowRequests = 0;
const groupStateCalls = [];
const savedPreferences = [];
const savedPlaylistTabs = [];
let frontendSettingsChanged;
let catalogReloaded;
let archiveCache = {
  enabled: true,
  limitBytes: 2 * 1024 ** 3,
  fileCount: 3,
  byteCount: 24 * 1024 ** 2,
};
let archiveCacheConfigurationCalls = [];
let archiveCacheClearCount = 0;
let archiveCacheFinderCalls = 0;
let databaseFinderCalls = 0;
let historyRecords = [];
let historyRecordCalls = [];
let favoriteTracks = [];
let favoriteToggleCalls = [];
let pathFileCalls = [];
let pathFolderCalls = [];
let databaseReloadCount = 0;
const pathTrack = {
  playlistId: 'path-track', path: '/music/sub/path.spc', filename: 'path.spc',
  title: 'Path Track', game: 'Path Sample', system: 'SNES',
};
const pathTree = [{
  kind: 'folder', path: 'catalog-root:1:/music', name: 'music',
  catalogFolder: { rootId: 1, rootPath: '/music', folderPath: '' },
  children: [{
    kind: 'folder', path: 'catalog-folder:1:/music/sub', name: 'SUB',
    catalogFolder: { rootId: 1, rootPath: '/music', folderPath: 'sub' },
    children: [{
      kind: 'file', path: 'catalog-file:1:/music/sub/path.spc', name: 'path.spc',
      catalogFile: { rootId: 1, rootPath: '/music', folderPath: 'sub', path: '/music/sub/path.spc' },
      children: [],
    }],
  }],
}];
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
  closeMainWindow: async () => { closeWindowRequests += 1; },
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
  databaseLocation: async () => ({
    path: '/tmp/ViewBoy.sqlite', catalog: { schemaVersion: 24, trackCount: 99 },
  }),
  reloadDatabaseLibrary: async () => {
    databaseReloadCount += 1;
    return { path: '/tmp/ViewBoy.sqlite', catalog: { schemaVersion: 24, trackCount: 99 }, reloaded: true };
  },
  databaseFileTree: async () => structuredClone(pathTree),
  databaseFileTracks: async (files) => { pathFileCalls.push(files); return [pathTrack]; },
  databaseFolderTracks: async (folders) => { pathFolderCalls.push(folders); return [pathTrack]; },
  choosePath: async () => ({ rootPath: '/tmp/hotkey-playlist', playlist: [{
    playlistId: 'hotkey-track', path: '/tmp/hotkey-playlist/track.spc',
    filename: 'track.spc', title: 'Hotkey Track', system: 'SNES',
  }] }),
  archiveCacheLocation: async () => '/tmp/ViewBoy/ArchiveCache',
  archiveCacheSummary: async () => ({ ...archiveCache }),
  configureArchiveCache: async (settings) => {
    archiveCacheConfigurationCalls.push({ ...settings });
    archiveCache = { ...archiveCache, ...settings };
    return { ...settings, summary: { ...archiveCache } };
  },
  clearArchiveCache: async () => {
    archiveCacheClearCount += 1;
    archiveCache = { ...archiveCache, fileCount: 0, byteCount: 0 };
    return true;
  },
  showArchiveCacheInFinder: async () => { archiveCacheFinderCalls += 1; return true; },
  showInFinder: async () => { databaseFinderCalls += 1; return true; },
  favoritesList: async () => structuredClone(favoriteTracks),
  favoritesToggle: async (incoming) => {
    favoriteToggleCalls.push(structuredClone(incoming));
    for (const track of incoming) {
      const identity = track.favoriteId || track.playlistId || track.path;
      const index = favoriteTracks.findIndex((favorite) =>
        (favorite.favoriteId || favorite.playlistId || favorite.path) === identity);
      if (index >= 0) favoriteTracks.splice(index, 1);
      else favoriteTracks.push({ ...track });
    }
    return structuredClone(favoriteTracks);
  },
  playbackHistoryList: async () => structuredClone(historyRecords),
  playbackHistoryRecord: async (track, timestampMilliseconds) => {
    historyRecordCalls.push({ track: { ...track }, timestampMilliseconds });
    const record = {
      id: `history-${historyRecords.length + 1}`,
      timestampMilliseconds,
      snapshot: {
        identity: {
          sourcePath: track.archivePath || track.path,
          archiveEntry: track.archiveEntry || null,
          trackIndex: track.trackIndex || 0,
          trackCount: track.trackCount || 1,
        },
        filename: track.filename || '',
        title: track.title || '',
        game: track.game || '',
        author: track.artist || '',
        system: track.system || '',
        playLengthMilliseconds: track.playLengthMs || 0,
      },
    };
    historyRecords.unshift(record);
    return record;
  },
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
function pixelChecksumForBox(box) {
  const scale = 3;
  const image = canvas.image;
  let hash = 2166136261;
  for (let y = box.y * scale; y < (box.y + box.height) * scale; y += 1) {
    for (let x = box.x * scale; x < (box.x + box.width) * scale; x += 1) {
      const offset = (y * image.width + x) * 4;
      for (let channel = 0; channel < 4; channel += 1) {
        hash = Math.imul(hash ^ image.data[offset + channel], 16777619);
      }
    }
  }
  return hash >>> 0;
}

test('canvas renders adaptive columns, grouped options, and native playback', async () => {
  const {
    animationFrameIsDue,
    bitmapFontSnapshot,
    hitTargetSnapshot,
    screenTransitionSnapshot,
  } = await import('../Sources/ViewBoy/Resources/yoga-app.js');
  const standardFont = bitmapFontSnapshot('STANDARD');
  for (const character of 'abcdefghijklmnopqrstuvwxyz') {
    const glyph = standardFont.glyphs[character];
    assert.equal(glyph?.length, 7, `Standard 5x7 includes a seven-row lowercase ${character}`);
    assert.ok(glyph.every((row) => /^[01]{5}$/.test(row)),
      `lowercase ${character} is authored as five LCD dots per row`);
  }
  assert.notDeepEqual(standardFont.glyphs.a, standardFont.glyphs.A,
    'Standard font preserves lowercase forms instead of mapping them to uppercase');
  const clickTargetBox = (target) => {
    const rect = canvas.getBoundingClientRect();
    const logicalWidth = canvas.width / 3;
    const logicalHeight = canvas.height / 3;
    canvas.listeners.get('click')({
      clientX: rect.width * (target.box.x + target.box.width / 2) / logicalWidth,
      clientY: rect.height * (target.box.y + target.box.height / 2) / logicalHeight,
      detail: 1,
    });
  };
  const selectTabWithCommandNumber = (number) => canvas.listeners.get('keydown')({
    key: String(number),
    code: `Digit${number}`,
    metaKey: true,
    ctrlKey: false,
    altKey: true,
    shiftKey: false,
    preventDefault() {},
  });
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
  for (const refreshRate of [60, 90, 120, 144]) {
    const gate = {};
    let frames = 0;
    for (let frame = 0; frame <= refreshRate; frame += 1) {
      if (animationFrameIsDue(gate, frame * 1000 / refreshRate)) frames += 1;
    }
    assert.ok(frames >= 60 && frames <= 61,
      `${refreshRate} Hz display timestamps retain a 60 Hz animation cadence (${frames} updates)`);
  }
  await tick();
  await tick();
  assert.match(status.textContent, /FIRST/i);
  globalThis.ViewBoy.dispatch('newPlaylistTab');
  await tick();
  const tabCountBeforeCommandClose = savedPlaylistTabs.at(-1).tabs.length;
  assert.equal(tabCountBeforeCommandClose, 2, 'a second playlist tab is open for the close shortcut check');
  const closeWindowEvent = {
    key: 'w', code: 'KeyW', metaKey: true, ctrlKey: false, altKey: false, shiftKey: false,
    preventDefault() { this.defaultPrevented = true; },
    stopPropagation() { this.propagationStopped = true; },
  };
  canvas.listeners.get('keydown')(closeWindowEvent);
  await tick();
  assert.equal(closeWindowRequests, 0, 'Command-W does not request a native window close');
  assert.equal(closeWindowEvent.defaultPrevented, true,
    'Command-W cannot fall through to WebKit keyboard handling');
  assert.equal(savedPlaylistTabs.at(-1).tabs.length, tabCountBeforeCommandClose - 1,
    'Command-W closes the active playlist tab and saves the remaining tab set');
  const toolbarTargets = hitTargetSnapshot();
  const footerReadouts = toolbarTargets.filter((target) => target.statusReadout)
    .sort((first, second) => first.box.x - second.box.x);
  assert.equal(footerReadouts.length, 4,
    'the sidebar and playlist each end in two outlined status readout buttons');
  assert.ok(footerReadouts.every((target) => target.box.y === footerReadouts[0].box.y
    && target.box.height === footerReadouts[0].box.height),
  'both pane footers align on one shared standard button row');
  for (const [left, right] of [[footerReadouts[0], footerReadouts[1]], [footerReadouts[2], footerReadouts[3]]]) {
    assert.ok(Math.abs(left.box.width - right.box.width) <= 1,
      'each footer splits its available width evenly between two readouts');
    assert.equal(left.textAlign, 'left', 'the first footer readout aligns to the left');
    assert.equal(right.textAlign, 'right', 'the second footer readout aligns to the right');
    assert.equal(left.textInset, 4, 'footer labels use the shared standard text padding');
    assert.equal(right.textInset, 4, 'both footer buttons use the same text padding');
  }
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
  assert.ok(toolbarTargets.some((target) => target.name === 'HISTORY'),
    'the sidebar exposes the shared Playback History view alongside Library and Queue');
  const defaultHeader = toolbarTargets.find((target) => target.columnHeader && target.name === '#');
  assert.ok(defaultHeader, 'the numbered playlist heading is visible');
  const firstPlaylistBody = toolbarTargets.find((target) => target.trackIndex === 0
    && target.box.x >= defaultHeader.box.x && target.box.y > defaultHeader.box.y);
  assert.ok(firstPlaylistBody, 'the playlist heading and its first content row are visible');
  assert.equal(firstPlaylistBody.box.y - (defaultHeader.box.y + defaultHeader.box.height), 4,
    'the playlist table applies the standard four-dot UI Gap between its headings and rows');
  const rowTops = new Map(toolbarTargets.filter((target) => Number.isInteger(target.trackIndex))
    .map((target) => [target.trackIndex, target.box.y]));
  const rowHeights = new Map(toolbarTargets.filter((target) => Number.isInteger(target.trackIndex))
    .map((target) => [target.trackIndex, target.box.height]));
  assert.equal(rowTops.get(1) - (rowTops.get(0) + rowHeights.get(0)), 4,
    'the playlist uses the standard UI Gap between track rows as well as below its headings');
  assert.ok(groupStateCalls.some(([action, system]) => action === 'toggle' && system === 'SNES'));
  assert.ok(groupStateCalls.some(([action, system, gameID]) =>
    action === 'selectGame' && system === 'SNES' && gameID === '1:SNES:Sample'));
  assert.ok(canvas.image.data.some((value) => value !== 0));
  assert.deepEqual(Array.from(canvas.image.data.slice(0, 4)), [155, 188, 15, 255],
    'packed framebuffer presentation preserves the four-tone LCD substrate color');
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

  globalThis.ViewBoy.dispatch('playlistRandom');
  await tick();
  globalThis.ViewBoy.dispatch('library');
  const sidebarLayout = () => {
    const targets = hitTargetSnapshot();
    const search = targets.find((target) => target.name === 'SEARCH LIBRARY');
    const firstColumn = targets.find((target) => target.columnHeader && target.name === '#');
    assert.ok(search && firstColumn, 'the sidebar and playlist layout anchors remain visible');
    return { sidebarWidth: search.box.width, playlistX: firstColumn.box.x };
  };
  let otherSystem = hitTargetSnapshot().find((target) => target.name.endsWith('ZZZ'));
  assert.ok(otherSystem, 'the other catalog system is available to expand');
  if (otherSystem.disclosureProgress > 0) {
    clickTargetBox(otherSystem);
    await tick();
    await tick();
    otherSystem = hitTargetSnapshot().find((target) => target.name.endsWith('ZZZ'));
  }
  assert.equal(otherSystem?.disclosureProgress, 0, 'the system is collapsed before the sizing check');
  const closedSidebarLayout = sidebarLayout();
  nextFrameAdvanceMs = 30;
  clickTargetBox(otherSystem);
  await tick();
  assert.deepEqual(sidebarLayout(), closedSidebarLayout,
    'the pane and playlist keep their geometry during an in-progress dropdown');
  await tick();
  await tick();
  assert.equal(hitTargetSnapshot().find((target) => target.name.endsWith('ZZZ')).disclosureProgress, 1,
    'the disclosure chevron reaches its fully rotated expanded position');
  assert.deepEqual(sidebarLayout(), closedSidebarLayout,
    'the pane and playlist keep their geometry after a system dropdown settles');
  const otherGame = hitTargetSnapshot().find((target) => target.name === 'Other');
  assert.ok(otherGame, 'the second playlist can be opened while the first is playing');
  const originalTabIDs = new Set(hitTargetSnapshot()
    .filter((target) => target.playlistTabTitle).map((target) => target.playlistTabId));
  clickTargetBox(otherGame);
  await tick();
  await tick();
  await tick();
  const otherPlaylistTab = hitTargetSnapshot().find((target) => target.playlistTabTitle
    && !originalTabIDs.has(target.playlistTabId));
  assert.ok(otherPlaylistTab, 'browsing another game opens a separate playlist tab');
  selectTabWithCommandNumber(1);
  selectTabWithCommandNumber(2);
  clickTargetBox(otherPlaylistTab);
  globalThis.ViewBoy.dispatch('next');
  await tick();
  await tick();
  assert.equal(calls.filter(([name]) => name === 'start').at(-1)[1].path, '/music/a.spc',
    'Next stays in the playback queue after another playlist tab becomes selected');
  await ended({ transport_state: 'ended', generation, status_sequence: generation + 1 });
  await tick();
  await tick();
  assert.deepEqual(calls.filter(([name]) => name === 'retire').at(-1)[1].playlistIds, ['a', 'b', 'c'],
    'natural completion retires against the playing playlist after another tab is selected');
  assert.equal(calls.filter(([name]) => name === 'start').at(-1)[1].path, '/music/b.spc',
    'natural completion advances within the playing playlist');
  const otherTabClose = hitTargetSnapshot().find((target) => target.playlistTabClose
    && target.playlistTabId === otherPlaylistTab.playlistTabId);
  assert.ok(otherTabClose, 'the test playlist tab retains its close control');
  clickTargetBox(otherTabClose);
  await tick();

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
  assert.equal(calls.filter(([name]) => name === 'start').at(-1)[1].path, '/music/b.spc',
    'Library Random history starts from the playing track after browsing another playlist');
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
  nextFrameAdvanceMs = 100;
  globalThis.ViewBoy.dispatch('settings');
  assert.match(status.textContent, /SETTINGS/);
  await tick();
  const rollingOptionsPixels = pixelChecksum(canvas.image.data);
  assert.notEqual(rollingOptionsPixels, libraryPixels,
    'Options rolls down over the source screen instead of swapping immediately');
  await tick();
  assert.notEqual(pixelChecksum(canvas.image.data), rollingOptionsPixels,
    'the roll-down reaches the fully settled Options screen');
  const gameBoyPixels = pixelChecksum(canvas.image.data);
  const clickScreen = (x, y, detail = 1) => {
    const rect = canvas.getBoundingClientRect();
    canvas.listeners.get('click')({ clientX: rect.width * x, clientY: rect.height * y, detail });
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
  const clickTarget = (name, occurrence = 0, xFraction = 0.5, yFraction = 0.5, detail = 1) => {
    const target = hitTargetSnapshot().filter((entry) => entry.name === name)[occurrence];
    assert.ok(target, `the ${name} control is present in the current screen; found ${hitTargetSnapshot().map((entry) => entry.name).join(', ')}`);
    const logicalWidth = canvas.width / 3;
    const logicalHeight = canvas.height / 3;
    clickScreen(
      (target.box.x + target.box.width * xFraction) / logicalWidth,
      (target.box.y + target.box.height * yFraction) / logicalHeight,
      detail,
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
  const pages = ['AUDIO', 'DATABASE', 'DISPLAY', 'INTERFACE', 'LIBRARY', 'METHODS', 'PLAYBACK', 'THEME', 'TRANSPORT'];
  const clickPage = (page) => clickTarget(page);
  globalThis.ViewBoy.dispatch('library');
  await tick();
  assert.ok(hitTargetSnapshot().some((target) => target.searchField && target.name === 'SEARCH LIBRARY'),
    'the sidebar begins with a pixel-rendered search field');
  const idleSearchPixels = pixelChecksum(canvas.image.data);
  clickTarget('SEARCH LIBRARY');
  const highlightedCursor = pixelChecksum(canvas.image.data);
  assert.notEqual(highlightedCursor, idleSearchPixels,
    'focusing Search highlights the field and paints its bitmap cursor');
  await new Promise((resolve) => setTimeout(resolve, 550));
  assert.notEqual(pixelChecksum(canvas.image.data), highlightedCursor,
    'the focused Search cursor blinks without removing the field highlight');
  for (const character of 'sample') typeSearchKey(character);
  const filteredSidebar = hitTargetSnapshot();
  const searchTargets = filteredSidebar.map((target) => target.name);
  assert.ok(searchTargets.includes('Sample'), 'typing filters the sidebar tree to matching catalog games');
  assert.equal(searchTargets.includes('Other'), false, 'nonmatching games are hidden by the sidebar search');
  const parentSystemRow = filteredSidebar.find((target) => target.name.endsWith('SNES'));
  const childGameRow = filteredSidebar.find((target) => target.name === 'Sample');
  assert.ok(parentSystemRow && childGameRow, 'the filtered system disclosure and game row are both visible');
  assert.equal(childGameRow.textInset, parentSystemRow.textInset,
    'sidebar game labels align with the title column after the parent chevron');
  assert.equal(childGameRow.box.y - (parentSystemRow.box.y + parentSystemRow.box.height), 4,
    'the sidebar tree applies the standard four-dot UI Gap between a system header and its games');
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
    assert.ok(titles.length >= 2, 'playlist tabs expose clipped title regions');
    assert.equal(closes.length, titles.length, 'each playlist tab exposes its unframed close glyph');
    return titles[1].box.x - (closes[0].box.x + closes[0].box.width);
  };
  const defaultTabGap = tabGap();
  clickTarget('OPTIONS');
  await tick();
  clickPage('INTERFACE');
  clickTarget('UI GAP +');
  await tick();
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).uiGapDots, 5,
    'the renamed UI Gap setting persists under its current name');
  globalThis.ViewBoy.dispatch('library');
  await tick();
  assert.ok(tabGap() > defaultTabGap, 'playlist tabs respond to UI Gap while retaining independent column spacing');
  clickTarget('X', 1);
  clickTarget('OPTIONS');
  await tick();
  clickPage('INTERFACE');
  clickTarget('UI GAP -');
  await tick();
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).uiGapDots, 4,
    'the UI Gap returns to its original value');
  clickTarget('BACK');
  await tick();
  globalThis.ViewBoy.dispatch('settings');
  await tick();
  const commandKey = (key, modifiers = {}) => canvas.listeners.get('keydown')({
    key,
    code: key === ',' ? 'Comma' : `Digit${key}`,
    metaKey: true,
    ctrlKey: false,
    altKey: modifiers.altKey === true,
    shiftKey: modifiers.shiftKey === true,
    preventDefault() {},
  });
  clickPage('THEME');
  clickTarget('THEME NIGHTBOY');
  const nightBoyPixels = pixelChecksum(canvas.image.data);
  assert.notEqual(nightBoyPixels, gameBoyPixels, 'NightBoy repaints the same four-tone pixel screen with its dark-purple palette');
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).theme, 'NIGHTBOY');
  assert.equal(document.documentElement.dataset.theme, 'NIGHTBOY',
    'the selected LCD theme also updates the surrounding shell');
  clickTarget('INK BRIGHT');
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).contrast, 'HIGH_CONTRAST',
    'the ink control persists the brighter silver high-contrast setting');
  clickPage('PLAYBACK');
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
  clickPage('AUDIO');
  globalThis.ViewBoy.dispatch('optionsPage:AUDIO');
  const equalizerBands = hitTargetSnapshot().filter((target) => /^EQ \d/.test(target.name)
    && !/[+-]$/.test(target.name));
  const volumeControls = ['VOLUME -', 'VOLUME +', 'VOLUME GAUGE']
    .map((name) => hitTargetSnapshot().find((target) => target.name === name));
  assert.ok(volumeControls.every((target) => target && target.box.y === volumeControls[0].box.y),
    'Volume buttons and gauge share one aligned row');
  assert.ok(volumeControls[0].box.x < volumeControls[1].box.x
    && volumeControls[1].box.x < volumeControls[2].box.x,
  'Volume decrease and increase stay together before the gauge');
  const firstBandControls = ['EQ 31 HZ -', 'EQ 31 HZ +', 'EQ 31 HZ']
    .map((name) => hitTargetSnapshot().find((target) => target.name === name));
  assert.ok(firstBandControls.every((target) => target && target.box.y === firstBandControls[0].box.y),
    'EQ buttons and gauge share one aligned row');
  assert.ok(firstBandControls[0].box.x < firstBandControls[1].box.x
    && firstBandControls[1].box.x < firstBandControls[2].box.x,
  'EQ decrease and increase stay together before the gauge');
  assert.equal(equalizerBands.length, 10, 'Audio renders ten independently adjustable EQ bands');
  assert.equal(new Set(equalizerBands.map((target) => target.box.x)).size, 1,
    'all equalizer sliders share the same left edge');
  assert.equal(new Set(equalizerBands.map((target) => target.box.width)).size, 1,
    'all equalizer sliders have identical widths');
  assert.equal(new Set(equalizerBands.map((target) => target.box.height)).size, 1,
    'all equalizer sliders have identical heights');
  assert.equal(new Set(equalizerBands.map((target) => target.equalizerValueBox?.x)).size, 1,
    'all equalizer value readouts share the same right-column alignment');
  assert.equal(new Set(equalizerBands.map((target) => target.equalizerValueBox?.width)).size, 1,
    'all equalizer value readouts have identical widths');
  assert.equal(new Set(equalizerBands.map((target) =>
    target.equalizerLabelBox?.width)).size, 1,
  'all equalizer label columns have identical widths');
  assert.ok(equalizerBands.every((target) => target.equalizerValueBox?.y === target.box.y
    && target.equalizerValueBox?.height === target.box.height),
  'each gain readout aligns vertically with its slider');
  assert.ok(equalizerBands.every((target) => target.equalizerLabelBox?.y === target.box.y
    && target.equalizerLabelBox?.height === target.box.height),
  'each frequency label aligns vertically with its slider');
  const equalizerAdjusters = equalizerBands.map((target) => ({
    band: target,
    minus: hitTargetSnapshot().find((entry) => entry.name === `${target.name} -`),
    plus: hitTargetSnapshot().find((entry) => entry.name === `${target.name} +`),
  }));
  assert.ok(equalizerAdjusters.every(({ band, minus, plus }) => minus && plus
    && minus.box.x - (band.equalizerLabelBox.x + band.equalizerLabelBox.width) === 4
    && plus.box.x - (minus.box.x + minus.box.width) === 4
    && band.box.x - (plus.box.x + plus.box.width) === 4),
  'EQ adjustment pairs keep the standard gap between label, buttons, and gauge');
  assert.equal(new Set(equalizerBands.map((target) =>
    target.equalizerValueBox.x - (target.box.x + target.box.width))).size, 1,
  'all EQ rows retain the same gap between fill bars and gain readouts');
  assert.ok(equalizerBands.every((target) => target.equalizerTickXs.length === 25),
    'every EQ bar has the same 25 gain ticks');
  assert.ok(equalizerBands.every((target) => new Set(target.equalizerTickXs.slice(1)
    .map((tick, index) => tick - target.equalizerTickXs[index])).size === 1),
  'EQ tick fins have exactly even spacing across each life-gauge bar');
  const defaultEqualizerWidth = equalizerBands[0].box.width;
  assert.equal(new Set(equalizerBands.map((target) =>
    target.equalizerValueBox.x - target.box.x)).size, 1,
  'all equalizer bands keep the same slider-to-value spacing');
  const equalizerRowSteps = equalizerBands.slice(1).map((target, index) =>
    target.box.y - equalizerBands[index].box.y);
  assert.equal(new Set(equalizerRowSteps).size, 1,
    'equalizer sliders use a uniform vertical rhythm');
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
  const equalizerStartPixels = pixelChecksum(canvas.image.data);
  const equalizerStartValuePixels = pixelChecksumForBox(equalizerBands[0].equalizerValueBox);
  nextFrameAdvanceMs = 40;
  clickTarget('EQ 31 HZ', 0, 0.99);
  await tick();
  const equalizerInFlightPixels = pixelChecksum(canvas.image.data);
  const equalizerInFlightValuePixels = pixelChecksumForBox(equalizerBands[0].equalizerValueBox);
  assert.notEqual(equalizerInFlightPixels, equalizerStartPixels,
    'the equalizer fill begins moving before its snapped target is reached');
  assert.notEqual(equalizerInFlightValuePixels, equalizerStartValuePixels,
    'the numeric equalizer readout moves with the animated fill');
  await tick();
  await tick();
  assert.notEqual(pixelChecksum(canvas.image.data), equalizerInFlightPixels,
    'the equalizer fill and numeric readout continue to the clicked snap point using shared slide timing');
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
  clickPage('PLAYBACK');
  globalThis.ViewBoy.dispatch('optionsPage:PLAYBACK');
  clickTarget('LONG PLAY TIME +');
  await tick();
  assert.equal(savedPreferences.at(-1).manualPlayTimeSeconds, 210,
    'the Long Play duration adjuster increases in 30-second steps');
  assert.equal(reconfigureCalls.at(-1).manualPlayMilliseconds, 210_000,
    'Long Play duration changes reconfigure the active native track');
  const timeControls = hitTargetSnapshot();
  const timeMinus = timeControls.find((target) => target.name === 'LONG PLAY TIME -');
  const timePlus = timeControls.find((target) => target.name === 'LONG PLAY TIME +');
  const timeInput = timeControls.find((target) => target.name === 'manualPlayTimeSeconds TIME');
  assert.ok(timeMinus && timePlus && timeInput
    && timeMinus.box.x < timePlus.box.x && timePlus.box.x < timeInput.box.x,
  'the duration field follows an adjacent decrease/increase pair');
  clickTarget('manualPlayTimeSeconds TIME');
  for (const key of ['3', ':', '4', '5', 'Enter']) typeSearchKey(key);
  await tick();
  assert.equal(savedPreferences.at(-1).manualPlayTimeSeconds, 225,
    'the Long Play time field accepts a typed minutes:seconds value');
  globalThis.ViewBoy.dispatch('newPlaylistTab');
  await tick();
  assert.equal(savedPlaylistTabs.at(-1)?.tabs.length, 2,
    'the plus tab control duplicates the current list and persists it through the native bridge');
  const [firstPlaylistID, secondPlaylistID] = savedPlaylistTabs.at(-1).tabs.map((tab) => tab.id);
  commandKey('1', { altKey: true });
  await tick();
  assert.equal(savedPlaylistTabs.at(-1)?.activeID, firstPlaylistID,
    'Command-Option-1 selects the first playlist tab');
  commandKey('2', { altKey: true });
  await tick();
  assert.equal(savedPlaylistTabs.at(-1)?.activeID, secondPlaylistID,
    'Command-Option-2 selects the second playlist tab');
  commandKey(',');
  assert.equal(screenTransitionSnapshot()?.direction, 'down',
    'Command-comma opens Options from above using the shared screen roll');
  assert.match(status.textContent, /SETTINGS/,
    'Command-comma opens the Options screen');
  await tick();
  const openOptionsPixels = pixelChecksum(canvas.image.data);
  nextFrameAdvanceMs = 100;
  clickTarget('BACK');
  assert.equal(screenTransitionSnapshot()?.direction, 'up',
    'the Back action dismisses Options upward');
  await tick();
  const rollingBackPixels = pixelChecksum(canvas.image.data);
  assert.notEqual(rollingBackPixels, openOptionsPixels,
    'Back rolls the Options screen upward as the prior view returns');
  await tick();
  assert.notEqual(pixelChecksum(canvas.image.data), rollingBackPixels,
    'the reverse roll settles on the full playlist screen');
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
  assert.equal(screenTransitionSnapshot()?.direction, 'down',
    'the settings command enters Options from above');
  await tick();
  commandKey(',');
  assert.equal(screenTransitionSnapshot()?.direction, 'up',
    'Command-comma toggles the Options view off with the reverse roll');
  await tick();
  commandKey(',');
  assert.equal(screenTransitionSnapshot()?.direction, 'down',
    'Command-comma toggles Options back on');
  await tick();
  clickPage('INTERFACE');
  globalThis.ViewBoy.dispatch('optionsPage:INTERFACE');
  clickTarget('AUTO-SIZE COLUMNS');
  await tick();
  assert.equal(savedPreferences.at(-1).columnAutoSize, false,
    'the Interface page checkbox updates the saved column behavior');
  assert.equal(hitTargetSnapshot().some((target) => target.name === 'PREVIOUS'), false,
    'transport controls are kept off the Options screen');
  const paddingBefore = hitTargetSnapshot().find((target) => target.name === 'BACK').box.height;
  clickTarget('CONTROL PADDING +');
  await tick();
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).controlPaddingDots, 5,
    'control padding is adjustable and persists in display preferences');
  assert.ok(hitTargetSnapshot().find((target) => target.name === 'BACK').box.height > paddingBefore,
    'control padding changes the shared button row height');
  clickTarget('CONTROL PADDING -');
  await tick();
  clickTarget('UI GAP +');
  await tick();
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).uiGapDots, 5,
    'the shared interface gap has an independent persisted setting');
  globalThis.ViewBoy.dispatch('settings');
  assert.equal(screenTransitionSnapshot()?.direction, 'up',
    'the UI Gap check returns to the playlist view through the shared screen roll');
  await tick();
  const fiveDotHeader = hitTargetSnapshot().find((target) => target.columnHeader && target.name === '#');
  const fiveDotBody = hitTargetSnapshot().filter((target) => !target.columnHeader
    && target.box.y > fiveDotHeader.box.y).sort((first, second) => first.box.y - second.box.y)[0];
  assert.ok(fiveDotBody, 'the playlist body remains laid out below its header at the larger UI Gap');
  assert.equal(fiveDotBody.box.y - (fiveDotHeader.box.y + fiveDotHeader.box.height), 5,
    'playlist header-to-body spacing follows the adjusted UI Gap');
  clickTarget('SEARCH LIBRARY');
  for (const character of 'sample') typeSearchKey(character);
  const fiveDotSidebar = hitTargetSnapshot();
  const fiveDotParent = fiveDotSidebar.find((target) => target.name.endsWith('SNES'));
  const fiveDotChild = fiveDotSidebar.find((target) => target.name === 'Sample');
  assert.ok(fiveDotParent && fiveDotChild, 'filtered sidebar retains its matching parent and child');
  assert.equal(fiveDotChild.box.y - (fiveDotParent.box.y + fiveDotParent.box.height), 5,
    'sidebar parent, child, and sibling line spacing follows the adjusted UI Gap');
  typeSearchKey('Escape');
  typeSearchKey('Escape');
  globalThis.ViewBoy.dispatch('settings');
  assert.equal(screenTransitionSnapshot()?.direction, 'down',
    'the UI Gap check can return to Options');
  await tick();
  clickPage('AUDIO');
  const expandedGapBands = hitTargetSnapshot().filter((target) => /^EQ \d/.test(target.name)
    && !/[+-]$/.test(target.name));
  assert.ok(expandedGapBands.every((target) => {
    const minus = hitTargetSnapshot().find((entry) => entry.name === `${target.name} -`);
    const plus = hitTargetSnapshot().find((entry) => entry.name === `${target.name} +`);
    return minus && plus
      && minus.box.x - (target.equalizerLabelBox.x + target.equalizerLabelBox.width) === 5
      && plus.box.x - (minus.box.x + minus.box.width) === 5
      && target.box.x - (plus.box.x + plus.box.width) === 5
      && target.equalizerValueBox.x - (target.box.x + target.box.width) === 5;
  }), 'increasing UI Gap preserves all button and gauge spacing on every EQ row');
  assert.ok(expandedGapBands[0].box.width < defaultEqualizerWidth,
    'the EQ bar gives available width to the larger UI gaps instead of consuming their padding');
  clickPage('INTERFACE');
  clickTarget('UI GAP -');
  await tick();
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).uiGapDots, 4,
    'the UI Gap returns to its original value');
  clickTarget('PLAYLIST GAP +');
  await tick();
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).playlistGapDots, 5,
    'playlist column and tab spacing has an independent persisted setting');
  clickTarget('PLAYLIST GAP -');
  await tick();
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).controlPaddingDots, 4);
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).uiGapDots, 4);
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).playlistGapDots, 4);
  clickPage('LIBRARY');
  globalThis.ViewBoy.dispatch('optionsPage:LIBRARY');
  clickTarget('FILE');
  await tick();
  assert.equal(savedPreferences.at(-1).columnVisibility.filename, false,
    'the Library page checkbox persists field visibility');
  clickPage('INTERFACE');
  globalThis.ViewBoy.dispatch('optionsPage:INTERFACE');
  clickTarget('AUTO-SIZE COLUMNS');
  await tick();
  assert.equal(savedPreferences.at(-1).columnAutoSize, true,
    'the Interface page checkbox can restore automatic sizing');
  clickPage('THEME');
  clickTarget('THEME GAMEBOY');
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).theme, 'GAMEBOY',
    'the palette selector returns to the authentic Game Boy theme');
  clickTarget('INK LCD GREEN');
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).contrast, 'STANDARD');
  clickPage('TRANSPORT');
  clickTarget('BUTTONS SYMBOLS');
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).transportSymbols, true,
    'the Transport page persists its Words/Symbols control setting');
  globalThis.ViewBoy.dispatch('library');
  await tick();
  const symbolTransportPixels = pixelChecksum(canvas.image.data);
  globalThis.ViewBoy.dispatch('settings');
  await tick();
  clickPage('TRANSPORT');
  clickTarget('BUTTONS WORDS');
  assert.equal(JSON.parse(localStorage.getItem('ViewBoy.displayOptions')).transportSymbols, false);
  globalThis.ViewBoy.dispatch('library');
  await tick();
  assert.notEqual(pixelChecksum(canvas.image.data), symbolTransportPixels,
    'symbol mode replaces word labels while keeping equal-width toolbar controls');
  globalThis.ViewBoy.dispatch('settings');
  await tick();
  clickPage('METHODS');
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
  await tick();
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

  screenWidth = 1400;
  windowListeners.get('resize')();
  await tick();
  await tick();
  const sendPointer = (name, x, y) => canvas.listeners.get(name)({
    clientX: canvas.getBoundingClientRect().width * x,
    clientY: canvas.getBoundingClientRect().height * y,
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
  const titleRightSide = (titleHeader.box.x + titleHeader.box.width * 0.525) / (canvas.width / 3);
  sendPointer('pointerdown', fileHeader.x, fileHeader.y);
  nextFrameAdvanceMs = 16;
  sendPointer('pointermove', titleRightSide, titleHeader.y);
  await tick();
  const pushedTitleHeader = headerCenter('TITLE');
  assert.ok(Math.abs(pushedTitleHeader.box.x - fileHeader.box.x) < 1,
    'the neighboring heading immediately takes the dragged column’s slot on the first frame');
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
  nextFrameAdvanceMs = 16;
  sendPointer('pointermove', (destinationTab.box.x + destinationTab.box.width * 0.85) / (canvas.width / 3),
    (destinationTab.box.y + destinationTab.box.height / 2) / (canvas.height / 3));
  await tick();
  const shiftedNeighborAfter = tabTitles().find((target) => target.playlistTabId === shiftedNeighborID);
  assert.ok(Math.abs(shiftedNeighborAfter.box.x - sourceTitle.box.x) < 1,
    'a neighboring tab takes the dragged tab’s slot immediately instead of easing there');
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
  assert.equal(scrollGameNext.box.y - (scrollGameBefore.box.y + scrollGameBefore.box.height), 4,
    'expanded sibling rows have the same standard line spacing as their parent group');
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

  globalThis.ViewBoy.dispatch('settings');
  await tick();
  const visibleOptionPages = () => hitTargetSnapshot()
    .map((target) => target.name).filter((name) => pages.includes(name));
  assert.deepEqual(visibleOptionPages(), pages,
    'the Options table of contents stays alphabetized');
  clickPage('DATABASE');
  await tick();
  await tick();
  const databaseTargets = hitTargetSnapshot();
  assert.ok(databaseTargets.some((target) => target.name === 'DATABASE LOCATION'),
    'Database options expose the catalog location');
  assert.ok(databaseTargets.some((target) => target.name === 'ARCHIVE CACHE LOCATION'),
    'Database options expose the archive cache path');
  assert.ok(databaseTargets.some((target) => target.name === 'CACHE ENABLED')
    && databaseTargets.some((target) => target.name === 'CLEAR CACHE')
    && databaseTargets.some((target) => target.name === 'SHOW CACHE FOLDER'),
  'Database options expose cache enable, clear, and Finder actions');
  clickTarget('CACHE ENABLED');
  await tick();
  assert.equal(archiveCacheConfigurationCalls.at(-1).enabled, false,
    'the cache checkbox updates the native cache policy');
  clickTarget('LIMIT 4G');
  await tick();
  assert.equal(archiveCacheConfigurationCalls.at(-1).limitBytes, 4 * 1024 ** 3,
    'the cache-limit choices update the native cache policy');
  clickTarget('CLEAR CACHE');
  await tick();
  assert.equal(archiveCacheClearCount, 1, 'Clear Cache invokes the native cache purge');
  assert.equal(archiveCache.fileCount, 0, 'cache usage refreshes after a purge');
  clickTarget('DATABASE LOCATION');
  clickTarget('ARCHIVE CACHE LOCATION');
  await tick();
  assert.equal(databaseFinderCalls, 1, 'the database path opens its location in Finder');
  assert.equal(archiveCacheFinderCalls, 1, 'the archive-cache path opens its location in Finder');
  clickTarget('RELOAD LIBRARY');
  await tick();
  await tick();
  assert.equal(databaseReloadCount, 1, 'Reload Library requests a fresh native catalog projection');

  commandKey('1');
  await tick();
  await tick();
  assert.ok(hitTargetSnapshot().some((target) => target.name === 'SUB'),
    'Command-1 switches the sidebar to its catalog Path view');
  const musicRow = hitTargetSnapshot().find((target) => target.name === 'music');
  const subRow = hitTargetSnapshot().find((target) => target.name === 'SUB');
  assert.ok(musicRow && subRow, 'the Path root and its first folder are visible');
  assert.equal(subRow.box.y - (musicRow.box.y + musicRow.box.height), 4,
    'Path roots and child folders use the shared sidebar line gap');
  clickTarget('SUB');
  await tick();
  const pathRows = hitTargetSnapshot();
  const expandedSubRow = pathRows.find((target) => target.name === 'SUB');
  const pathFileRow = pathRows.find((target) => target.name === 'path.spc');
  assert.ok(pathFileRow,
    'the Path tree expands folders to show indexed files');
  assert.equal(pathFileRow.box.y - (expandedSubRow.box.y + expandedSubRow.box.height), 4,
    'expanded Path folders and files keep the same sidebar line gap');
  clickTarget('SUB', 0, 0.5, 0.5, 2);
  await tick();
  assert.equal(pathFolderCalls.length, 1, 'double-clicking a catalog folder loads its indexed tracks');
  clickTarget('path.spc');
  await tick();
  assert.equal(pathFileCalls.length, 1, 'selecting a catalog file loads its indexed tracks');
  assert.equal(pathFileCalls[0][0].path, '/music/sub/path.spc');

  commandKey('2');
  await tick();
  assert.ok(hitTargetSnapshot().some((target) => target.name === 'Scroll Game 00'),
    'Command-2 restores the shared Console view');
  commandKey('3');
  await tick();
  await tick();
  assert.match(status.textContent, /HOTKEY TRACK/i,
    'Command-3 opens the shared local Path picker and loads the selected playlist');
  const tabCountBeforeCommandT = savedPlaylistTabs.at(-1).tabs.length;
  commandKey('t');
  await tick();
  assert.equal(savedPlaylistTabs.at(-1).tabs.length, tabCountBeforeCommandT + 1,
    'Command-T duplicates the current playlist in a new tab');
  commandKey('d');
  await tick();
  assert.ok(favoriteToggleCalls.length > 0, 'Command-D toggles the selected track in shared Favorites');
  commandKey('d', { shiftKey: true });
  await tick();
  assert.match(status.textContent, /FAVORITES/i, 'Command-Shift-D opens the Favorites playlist');
  commandKey('h', { shiftKey: true });
  await tick();
  await tick();
  assert.ok(historyRecordCalls.length > 0, 'successful playback is recorded through shared PlaybackHistory');
  assert.ok(hitTargetSnapshot().some((target) => target.name.startsWith('DATE/TIME')),
    'Command-Shift-H opens History with its timestamp column');
});
