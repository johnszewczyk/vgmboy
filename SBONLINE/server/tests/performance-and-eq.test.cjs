const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { test } = require('node:test');

const serverDir = `${__dirname}/..`;
const sitePlayerJs = readFileSync(`${serverDir}/static/accounts/site-player.js`, 'utf8');
const spcboyJs = readFileSync(`${serverDir}/static/accounts/spcboy.js`, 'utf8');
const sitePreferencesJs = readFileSync(`${serverDir}/static/accounts/site-preferences.js`, 'utf8');

test('desktop EQ toolbar is wired cleanly with gesture support and immediate preset/filter updates', () => {
  assert.match(sitePreferencesJs, /"selectedEqualizerPresetIndex"/);
  assert.match(sitePlayerJs, /'\[data-sbonline-command="equalizer"\]'/);
  assert.match(sitePlayerJs, /'\[data-sbonline-command="volume"\]'/);
  assert.match(sitePlayerJs, /if \(command === "equalizer"\) \{\s*setEqualizerEnabled\(!equalizerEnabled\);/);
  assert.match(sitePlayerJs, /void applyEqualizerPreset\(index\);/);
  assert.match(sitePlayerJs, /if \(equalizerGraphReady && audioContext && audioContext\.state === "suspended"\)/);
});

test('spcboy.js uses lazy console DOM rendering and O(1) album lookup without startup rAF blocking', () => {
  assert.match(spcboyJs, /function ensureConsoleContentRendered\(systemRecord\)/);
  assert.match(spcboyJs, /function setupTrackListDelegation\(\)/);
  assert.match(spcboyJs, /function ensureEntryPlaylistDom\(entry\)/);
  assert.doesNotMatch(spcboyJs, /if \(renderedGames % 32 === 0 && isDesktop\(\)\)/);
  assert.match(spcboyJs, /const entry = selectedAlbumId \? gameGroupsByAlbumId\.get\(selectedAlbumId\) : null;/);
  assert.match(spcboyJs, /const entry = albumId \? gameGroupsByAlbumId\.get\(albumId\) : null;/);
});

test('server-only EQ enforces supportsClientAudioGraph() === false across desktop/Safari/iOS and boots without AudioContext', () => {
  let audioContextCalls = 0;
  let createMediaElementSourceCalls = 0;
  for (const ua of [
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.2 Safari/605.1.15',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1',
  ]) {
    const mseUrls = [];
    const audioEl = {
      playbackRate: 1, volume: 1, paused: false, ended: false, error: null, src: '', currentTime: 18,
      addEventListener() {}, removeEventListener() {}, dispatchEvent() { return true; },
      removeAttribute() {}, load() {}, pause() {}, play: async () => {},
    };
    const stubEl = () => ({
      hidden: false, disabled: false, textContent: '', innerHTML: '', value: '', checked: false,
      dataset: {}, style: { setProperty() {} }, parentNode: { insertBefore() {} }, nextSibling: null,
      classList: { toggle() {}, add() {}, remove() {}, contains: () => false },
      setAttribute() {}, getAttribute: () => null, removeAttribute() {}, hasAttribute: () => false,
      addEventListener() {}, removeEventListener() {}, dispatchEvent() { return true; },
      append() {}, prepend() {}, remove() {}, replaceChildren() {}, closest: () => null,
      querySelectorAll: () => [], querySelector: () => stubEl(),
      getBoundingClientRect: () => ({ left: 0, width: 100 }), getClientRects: () => [1],
    });
    const dockEl = Object.assign(stubEl(), {
      dataset: {
        libraryUrl: '/spcboy/', nowPlayingUrl: '/spcboy/now-playing.json',
        favoritesUrl: '/spcboy/favorites.json', audioUrl: '/audio/spcboy/TRACK_ID.aac',
        pageLoadToken: 'tok-1', playbackSessionLimit: '43200',
      },
      contains: () => false,
    });
    const byId = new Map([
      ['site-player', dockEl],
      ['spcboy-audio', audioEl],
      ['site-player-volume', Object.assign(stubEl(), { value: '20' })],
      ['spcboy-volume', Object.assign(stubEl(), { value: '20' })],
    ]);
    const cacheEls = new Map();
    const getStub = (sel) => {
      if (sel.startsWith('#') && byId.has(sel.slice(1))) return byId.get(sel.slice(1));
      if (!cacheEls.has(sel)) cacheEls.set(sel, stubEl());
      return cacheEls.get(sel);
    };
    const fakeWindow = {
      AudioContext: class {
        constructor() { audioContextCalls += 1; }
        createMediaElementSource() { createMediaElementSourceCalls += 1; }
      },
      MediaSource: function MediaSource() {},
      addEventListener() {}, dispatchEvent() { return true; },
      matchMedia: () => ({ matches: false, addEventListener() {} }),
      setTimeout: (fn, ms) => { const h = setTimeout(fn, ms); h?.unref?.(); return h; },
      clearTimeout, setInterval: () => 0, clearInterval() {},
      requestAnimationFrame: (fn) => { const h = setTimeout(fn, 0); h?.unref?.(); return h; },
    };
    fakeWindow.window = fakeWindow;
    fakeWindow.SBAACStream = { attach: () => ({ supported: true, load(u) { mseUrls.push(String(u)); }, cancel() {} }) };
    const ctx = vm.createContext({
      window: fakeWindow,
      navigator: { userAgent: ua, platform: 'MacIntel', maxTouchPoints: 0, onLine: true },
      document: {
        baseURI: 'https://admin.pre-calc.com/spcboy/',
        body: stubEl(),
        currentScript: null,
        getElementById: (id) => getStub(`#${id}`),
        querySelector: getStub,
        querySelectorAll: () => [],
        createElement: () => Object.assign(stubEl(), { volume: 1 }),
        addEventListener() {}, dispatchEvent() { return true; },
      },
      URL, URLSearchParams, CustomEvent: class CustomEvent { constructor(t, d) { this.type = t; this.detail = d?.detail; } },
      Event: class Event { constructor(t) { this.type = t; } },
      Array, Math, Number, Boolean, String, JSON, Date, Promise, Error, Set, Map,
      crypto: { randomUUID: () => 'uuid-1' },
      setTimeout: fakeWindow.setTimeout, clearTimeout, setInterval: () => 0, clearInterval() {},
    });
    vm.runInContext(sitePlayerJs, ctx);
    const player = fakeWindow.SitePlayer;
    player.play({ id: 'chrono-1', title: 'Chrono', game: 'Chrono Trigger', durationSeconds: 120 });
    player.setEqualizerBandGain(1, 5.5);
    player.setEqualizerEnabled(true);
    const lastUrl = mseUrls.at(-1);
    assert.ok(lastUrl.includes('eq=0.0%2C5.5'), `Expected ?eq= in ${lastUrl}`);
    assert.equal(lastUrl.includes('start=18000'), true, 'Server EQ restart must preserve active playback offset');
    player.setVolume(10);
    assert.equal(audioEl.volume, 0.5);
  }
  assert.equal(audioContextCalls, 0);
  assert.equal(createMediaElementSourceCalls, 0);
});

test('server-only EQ debounces slider drags with deferRestart and preserves position across rapid restarts', () => {
  let restarts = [];
  const timeouts = [];
  const context = vm.createContext({
    equalizerEnabled: false,
    equalizerBandGains: Array(10).fill(0),
    equalizerFrequencies: [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000],
    equalizerError: { textContent: '' },
    eqRestartTimer: null,
    currentTrack: { id: 'guile' },
    window: {
      setTimeout(fn, ms) { const id = timeouts.length + 1; timeouts.push({ id, fn, ms, cleared: false }); return id; },
      clearTimeout(id) { const item = timeouts.find((t) => t.id === id); if (item) item.cleared = true; },
      dispatchEvent() {},
    },
    CustomEvent: class CustomEvent { constructor(t, d) { this.type = t; this.detail = d?.detail; } },
    storage: { set() {} },
    updateEqualizerToggle() {},
    ensureEqualizerGraph: () => false,
    updateEqualizerGraph() {},
    syncEqualizerControls() {},
    syncOnlineControls() {},
    sourcePositionSeconds: () => 42,
    restartCurrentStream(pos) { restarts.push(pos); },
  });
  const blockStart = sitePlayerJs.indexOf('  function scheduleEqualizerRestart(');
  const blockEnd = sitePlayerJs.indexOf('  function updateLongPlayToggle(');
  vm.runInContext(sitePlayerJs.slice(blockStart, blockEnd), context);

  context.setEqualizerEnabled(true, { deferRestart: true });
  assert.equal(restarts.length, 0);
  context.scheduleEqualizerRestart(300);
  context.scheduleEqualizerRestart(300);
  const pending = timeouts.filter((t) => !t.cleared);
  assert.equal(pending.length, 1);
  pending[0].fn();
  assert.deepEqual(restarts, [42]);
});

test('EQ presets automatically save when bands change or reset without a save button', async () => {
  const baseHtml = readFileSync(`${serverDir}/templates/accounts/base.html`, 'utf8');
  const mobileHtml = readFileSync(`${serverDir}/templates/accounts/partials/spcboy_mobile_shell.html`, 'utf8');
  assert.doesNotMatch(baseHtml, /data-equalizer-mobile-save|Save to Preset/);
  assert.doesNotMatch(mobileHtml, /spcboy-mobile-save-preset|Save to Preset/);

  const stored = new Map();
  const loadedUrls = [];
  const audioEl = {
    playbackRate: 1, volume: 1, paused: false, ended: false, error: null, src: '', currentTime: 12,
    addEventListener() {}, removeEventListener() {}, dispatchEvent() { return true; },
    removeAttribute() {}, load() {}, pause() {}, play: async () => {},
  };
  const stubEl = () => ({
    hidden: false, disabled: false, textContent: '', innerHTML: '', value: '', checked: false,
    dataset: {}, style: { setProperty() {} }, parentNode: { insertBefore() {} }, nextSibling: null,
    classList: { toggle() {}, add() {}, remove() {}, contains: () => false },
    setAttribute() {}, getAttribute: () => null, removeAttribute() {}, hasAttribute: () => false,
    addEventListener() {}, removeEventListener() {}, dispatchEvent() { return true; },
    append() {}, prepend() {}, remove() {}, replaceChildren() {}, closest: () => null,
    querySelectorAll: () => [], querySelector: () => stubEl(),
    getBoundingClientRect: () => ({ left: 0, width: 100 }), getClientRects: () => [1],
  });
  const cacheEls = new Map();
  const byId = new Map([
    ['site-player', Object.assign(stubEl(), {
      dataset: {
        libraryUrl: '/spcboy/', nowPlayingUrl: '/spcboy/now-playing.json',
        favoritesUrl: '/spcboy/favorites.json', audioUrl: '/audio/spcboy/TRACK_ID.aac',
        pageLoadToken: 'tok-1', playbackSessionLimit: '43200',
      },
      contains: () => false,
    })],
    ['spcboy-audio', audioEl],
  ]);
  const getStub = (sel) => {
    if (sel.startsWith('#') && byId.has(sel.slice(1))) return byId.get(sel.slice(1));
    if (!cacheEls.has(sel)) cacheEls.set(sel, stubEl());
    return cacheEls.get(sel);
  };
  const fakeWindow = {
    SBOProfileStorage: {
      set(_scope, key, value) { stored.set(key, JSON.parse(JSON.stringify(value))); },
      get(_scope, key, fallback) { return stored.has(key) ? JSON.parse(JSON.stringify(stored.get(key))) : fallback; },
      remove(_scope, key) { stored.delete(key); },
    },
    SBAACStream: { attach: () => ({ supported: true, load(u) { loadedUrls.push(String(u)); }, cancel() {} }) },
    MediaSource: function MediaSource() {},
    addEventListener() {}, dispatchEvent() { return true; },
    matchMedia: () => ({ matches: false, addEventListener() {} }),
    setTimeout: (fn, ms) => { const h = setTimeout(fn, ms); h?.unref?.(); return h; },
    clearTimeout, setInterval: () => 0, clearInterval() {},
    requestAnimationFrame: (fn) => { const h = setTimeout(fn, 0); h?.unref?.(); return h; },
  };
  fakeWindow.window = fakeWindow;
  const ctx = vm.createContext({
    window: fakeWindow,
    navigator: { userAgent: 'Mozilla/5.0', platform: 'MacIntel', maxTouchPoints: 0, onLine: true },
    document: {
      baseURI: 'https://admin.pre-calc.com/spcboy/',
      body: stubEl(),
      currentScript: null,
      getElementById: (id) => getStub(`#${id}`),
      querySelector: getStub,
      querySelectorAll: () => [],
      createElement: () => Object.assign(stubEl(), { volume: 1 }),
      addEventListener() {}, dispatchEvent() { return true; },
    },
    URL, URLSearchParams, CustomEvent: class CustomEvent { constructor(t, d) { this.type = t; this.detail = d?.detail; } },
    Event: class Event { constructor(t) { this.type = t; } },
    Array, Math, Number, Boolean, String, JSON, Date, Promise, Error, Set, Map,
    crypto: { randomUUID: () => 'uuid-1' },
    setTimeout: fakeWindow.setTimeout, clearTimeout, setInterval: () => 0, clearInterval() {},
  });
  vm.runInContext(sitePlayerJs, ctx);
  const player = fakeWindow.SitePlayer;

  await player.play({ id: 'chrono-1', title: 'Chrono', game: 'Chrono Trigger', durationSeconds: 120 });
  assert.equal(loadedUrls.length, 1);
  assert.equal(player.isEqualizerEnabled(), false);

  // Adjusting presets and bands while EQ is OFF does not enable EQ or restart playback.
  await player.applyEqualizerPreset(1);
  player.setEqualizerBandGain(3, 6.5);
  assert.equal(player.isEqualizerEnabled(), false);
  assert.equal(loadedUrls.length, 1);
  assert.equal(player.getEqualizerPresets()[1].saved, true);
  assert.equal(player.getEqualizerPresets()[1].gains[3], 6.5);

  await player.applyEqualizerPreset(0);
  assert.equal(player.getEqualizerBands()[3], 0);
  await player.applyEqualizerPreset(1);
  assert.equal(player.getEqualizerBands()[3], 6.5);
  assert.equal(loadedUrls.length, 1);

  // Toggling EQ ON sends preset curve to server; toggling OFF drops ?eq= without flattening sliders.
  await player.setEqualizerEnabled(true);
  assert.equal(loadedUrls.at(-1).includes('eq='), true);
  await player.setEqualizerEnabled(false);
  assert.equal(loadedUrls.at(-1).includes('eq='), false);
  assert.equal(player.getEqualizerBands()[3], 6.5);

  player.resetEqualizer();
  assert.equal(player.getEqualizerPresets()[1].gains[3], 0);
});
