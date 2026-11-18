// Regression checks for SBONLINE mobile shell CSS specificity, performance guards, and pre-roll.
const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { test } = require('node:test');

const staticDir = `${__dirname}/../static/accounts`;
const mobileCss = readFileSync(`${staticDir}/spcboy-mobile.css`, 'utf8');
const spcboyJs = readFileSync(`${staticDir}/spcboy.js`, 'utf8');
const sbInterfaceJs = readFileSync(`${staticDir}/sb-interface.js`, 'utf8');
const viewsPy = readFileSync(`${__dirname}/../accounts/views.py`, 'utf8');

test('mobile shell CSS defeats shared theme/online specificity clashes and keeps hidden helpers hidden', () => {
  assert.match(mobileCss, /#spcboy-mobile-app \.is-hidden\s*\{\s*display:\s*none\s*!important;/);
  assert.match(mobileCss, /#spcboy-mobile-app \.spcboy-mobile-console-toggle\[aria-expanded="true"\]/);
  assert.match(mobileCss, /#spcboy-mobile-app \.spcboy-mobile-album-toggle\[aria-expanded="true"\]/);
  assert.match(mobileCss, /#spcboy-mobile-app \.spcboy-mobile-eq-btn\.is-active/);
  assert.match(mobileCss, /#spcboy-mobile-app \.spcboy-mobile-switch\[aria-checked="true"\]/);
  assert.match(mobileCss, /\.spcboy-mobile-load-more\s*\{/);
  assert.match(mobileCss, /#spcboy-mobile-dock-progress-fill[\s\S]*transform:\s*scaleX\(0\)/);
  assert.doesNotMatch(mobileCss, /#spcboy-mobile-dock-progress-fill[\s\S]*transition:\s*width/);
  assert.doesNotMatch(mobileCss, /\.spcboy-mobile-progress-wrap\b/);
  const mobileShellHtml = readFileSync(`${__dirname}/../templates/accounts/partials/spcboy_mobile_shell.html`, 'utf8');
  assert.doesNotMatch(mobileShellHtml, /id="spcboy-mobile-progress-wrap"/);
  assert.doesNotMatch(mobileShellHtml, /role="slider"/);
  assert.doesNotMatch(spcboyJs, /handleMobileProgressSeek/);
});

test('mobile player JS avoids duplicate nav binding, full tracklist re-renders on timeupdate, and linear album lookup', () => {
  assert.equal(spcboyJs.includes('document.querySelectorAll("[data-mobile-app-page]").forEach'), false);
  assert.match(spcboyJs, /audio\?\.addEventListener\("timeupdate",\s*\(\)\s*=>\s*\{\s*if\s*\(!isDesktop\(\)\)\s*updateMobilePlaybackProgress\(\);/s);
  assert.match(spcboyJs, /const gameGroupsByAlbumId = new Map\(\);/);
  assert.match(spcboyJs, /gameGroupsByAlbumId\.get\(albumId\)/);
});

test('sb-interface suppresses selection rect layout walks for coarse pointers and mobile shell', () => {
  let getComputedStyleCalls = 0;
  const listeners = {};
  const classSet = new Set();
  const marker = {
    className: '',
    style: {},
    classList: {
      add: (c) => classSet.add(c),
      remove: (c) => classSet.delete(c),
      contains: (c) => classSet.has(c),
      toggle: (c, f) => (f ? classSet.add(c) : classSet.delete(c)),
    },
    setAttribute() {},
  };
  const bodyChildren = [];
  const docEl = {
    closest: (sel) => (sel === '#spcboy-mobile-app' ? {} : null),
    getClientRects: () => [{ left: 0, top: 0, right: 10, bottom: 10 }],
    getBoundingClientRect: () => ({ left: 0, top: 0, right: 10, bottom: 10 }),
    isConnected: true,
    parentElement: null,
  };
  const context = vm.createContext({
    window: { addEventListener() {} },
    matchMedia: (query) => ({ matches: query === '(pointer: coarse)', addEventListener() {} }),
    getComputedStyle: () => { getComputedStyleCalls += 1; return { overflowX: 'visible', overflowY: 'visible', borderRadius: '0px' }; },
    innerWidth: 390,
    innerHeight: 844,
    requestAnimationFrame: (fn) => { fn(); return 1; },
    document: {
      body: { style: { setProperty() {} }, append: (n) => bodyChildren.push(n) },
      createElement: () => marker,
      querySelectorAll: () => [],
      querySelector: () => null,
      addEventListener: (type, handler) => { listeners[type] = handler; },
      dispatchEvent() {},
    },
    Event: class { constructor(type) { this.type = type; } },
  });
  vm.runInContext(sbInterfaceJs, context);
  listeners.focusin?.({ target: { closest: () => docEl } });
  listeners.scroll?.({});
  assert.equal(getComputedStyleCalls, 0);
  assert.equal(classSet.has('is-ready'), false);
});

test('spcboy_audio keeps silent pre-roll when starting from t=0', () => {
  assert.match(viewsPy, /pre_roll_ms = 350 if start_ms == 0 else 0/);
  assert.match(viewsPy, /adelay=\{pre_roll_ms\}\|\{pre_roll_ms\}/);
});

test('mobile library track selection plays the targeted song even when view is favorites', async () => {
  const playCalls = [];
  const favTrack = { id: 'doggy-and-magic', title: 'Doggy and Magic', game: 'Fav Game', console: 'SNES', gameKey: 'SNES\u0000Fav Game' };
  const libTrack1 = { id: 'lib-1', title: 'Track 1', game: 'Target Game', console: 'GB', gameKey: 'GB\u0000Target Game' };
  const libTrack2 = { id: 'lib-2', title: 'Target Song', game: 'Target Game', console: 'GB', gameKey: 'GB\u0000Target Game' };
  const targetGroup = {
    key: 'GB\u0000Target Game',
    gameName: 'Target Game',
    consoleName: 'GB',
    albumId: 'alb1',
    tracks: [libTrack1, libTrack2],
    details: { closest: () => ({ open: false }), open: false },
  };
  const context = vm.createContext({
    playbackSelectionToken: 0,
    pendingSelectionToken: 0,
    lastPlayerTrackId: favTrack.id,
    view: 'favorites',
    search: { value: '' },
    selectedGameKey: null,
    currentTrack: null,
    gameGroupsByKey: new Map([[targetGroup.key, targetGroup]]),
    gameGroupsByConsoleGame: new Map([[targetGroup.key, targetGroup]]),
    cacheTrack: (_, t) => t,
    selectGame() {},
    isDesktop: () => false,
    syncCurrentTrackRows() {},
    applyFilters() {},
    scheduleSelectionIndicators() {},
    collectionTracks: () => [favTrack],
    loadFavoritePlaylist: async () => [favTrack],
    ensureAlbumTracks: async (g) => g.tracks,
    matchesTrackQuery: () => true,
    window: {
      SitePlayer: {
        async playPlaylist(playlist, options) {
          playCalls.push({ ids: playlist.map((t) => t.id), startTrackId: options.startTrackId, startTrack: options.startTrack });
          return true;
        },
        async play(t) {
          playCalls.push({ single: t.id });
          return true;
        },
      },
    },
  });

  const start = spcboyJs.indexOf('  async function selectTrack(');
  const end = spcboyJs.indexOf('  search.addEventListener("input"', start);
  vm.runInContext(spcboyJs.slice(start, end), context);

  await context.selectTrack(libTrack2, true, { source: 'album', group: targetGroup });
  assert.equal(playCalls.length, 1);
  assert.deepEqual(Array.from(playCalls[0].ids), ['lib-1', 'lib-2']);
  assert.equal(playCalls[0].startTrackId, 'lib-2');

  // If an album list does not contain the targeted track, fall back to [track], never unrelated track #1.
  playCalls.length = 0;
  targetGroup.tracks = [favTrack];
  await context.selectTrack(libTrack2, true, { source: 'album', group: targetGroup });
  assert.equal(playCalls.length, 1);
  assert.deepEqual(Array.from(playCalls[0].ids), ['lib-2']);
  assert.equal(playCalls[0].startTrackId, 'lib-2');

  // Verify loaded album tracks trigger playPlaylist synchronously inside click gesture.
  playCalls.length = 0;
  targetGroup.tracks = [libTrack1, libTrack2];
  targetGroup.loaded = true;
  const syncPromise = context.selectTrack(libTrack2, true, { source: 'album', group: targetGroup });
  assert.equal(playCalls.length, 1);
  assert.equal(playCalls[0].startTrackId, 'lib-2');
  await syncPromise;

  // Verify stale siteplayer:track for the previously playing track does not abort an async library selection.
  const listeners = {};
  const staleRaceContext = vm.createContext({
    playbackSelectionToken: 0,
    pendingSelectionToken: 0,
    lastPlayerTrackId: favTrack.id,
    view: 'all',
    search: { value: '' },
    selectedGameKey: null,
    currentTrack: favTrack,
    tracksById: new Map([[favTrack.id, favTrack]]),
    gameGroupsByKey: new Map([[targetGroup.key, targetGroup]]),
    gameGroupsByConsoleGame: new Map([[targetGroup.key, targetGroup]]),
    cacheTrack: (_, t) => t,
    selectGame() {},
    isDesktop: () => false,
    syncCurrentTrackRows() {},
    applyFilters() {},
    scheduleSelectionIndicators() {},
    renderMobileNowPlaying() {},
    renderMobileUpNext() {},
    renderMobileRecents() {},
    renderMobileFavorites() {},
    mobileAppPage: 'playing',
    loadRecents() {},
    ensureAlbumTracks: async () => [libTrack1, libTrack2],
    matchesTrackQuery: () => true,
    recentMore: { addEventListener() {} },
    favoriteMore: null,
    mobileNowArtwork: null,
    mobileDockArt: null,
    audio: null,
    window: {
      addEventListener(name, fn) { listeners[name] = fn; },
      SitePlayer: {
        async playPlaylist(playlist, options) {
          playCalls.push({ ids: playlist.map((t) => t.id), startTrackId: options.startTrackId });
          return true;
        },
      },
    },
  });
  targetGroup.loaded = false;
  playCalls.length = 0;
  vm.runInContext(spcboyJs.slice(start, end), staleRaceContext);
  const trackEventStart = spcboyJs.indexOf('  window.addEventListener("siteplayer:track",');
  const trackEventEnd = spcboyJs.indexOf('  // Tabs are browsing contexts', trackEventStart);
  vm.runInContext(spcboyJs.slice(trackEventStart, trackEventEnd), staleRaceContext);
  const pendingSelection = staleRaceContext.selectTrack(libTrack2, true, { source: 'album', group: targetGroup });
  listeners['siteplayer:track']({ detail: { track: favTrack } });
  await pendingSelection;
  assert.equal(playCalls.length, 1);
  assert.equal(playCalls[0].startTrackId, 'lib-2');

  // Verify mobile & row callers pass explicit playlist sources.
  assert.match(spcboyJs, /selectTrack\(track,\s*true,\s*\{\s*source:\s*"album",\s*group:\s*gameEntry,\s*tracks:\s*gameEntry\.tracks\s*\}\)/);
  assert.match(spcboyJs, /selectTrack\(track,\s*true,\s*\{\s*source:\s*"recent",\s*tracks\s*\}\)/);
  assert.match(spcboyJs, /makeTrackRow\(track,\s*entry\.tracks\.length,\s*\{\s*source:\s*"album",\s*group:\s*entry\s*\}\)/);
  assert.match(spcboyJs, /selectTrack\(track,\s*true,\s*playbackOptions \|\| \{\}\)/);
});

test('mobile shell replaces track length with favorite toggles and renames tempo to Slow Play', () => {
  const mobileShellHtml = readFileSync(`${__dirname}/../templates/accounts/partials/spcboy_mobile_shell.html`, 'utf8');
  assert.match(mobileShellHtml, /<strong>Slow Play<\/strong>/);
  assert.doesNotMatch(mobileShellHtml, /Native Format Speed/);

  assert.doesNotMatch(spcboyJs, /spcboy-mobile-track-len/);
  assert.match(spcboyJs, /function createMobileTrackFavoriteButton\(/);
  assert.match(spcboyJs, /button\.dataset\.favoriteKind = "track"/);
  assert.match(spcboyJs, /use href="#icon-star"/);
  assert.match(spcboyJs, /Could not load tracks · Tap to retry/);
  assert.match(spcboyJs, /hideMobileLoadingIndicator\(\);\s*showMobileToast\("Could not load album tracks\."\);/);

  assert.match(mobileCss, /\.spcboy-mobile-track-item\b/);
  assert.match(mobileCss, /#spcboy-mobile-app \.spcboy-mobile-track-favorite/);
  assert.match(spcboyJs, /finally\s*\{\s*if\s*\(pendingSelectionToken === selectionToken\)\s*pendingSelectionToken = 0;\s*\}/);
});
