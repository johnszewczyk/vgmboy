const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { test } = require('node:test');

const serverDir = `${__dirname}/..`;
const sitePreferencesJs = readFileSync(`${serverDir}/static/accounts/site-preferences.js`, 'utf8');
const webaudioAacStreamJs = readFileSync(`${serverDir}/static/accounts/webaudio-aac-stream.js`, 'utf8');
const sitePlayerJs = readFileSync(`${serverDir}/static/accounts/site-player.js`, 'utf8');
const spcboyJs = readFileSync(`${serverDir}/static/accounts/spcboy.js`, 'utf8');

const baseHtml = readFileSync(`${serverDir}/templates/accounts/base.html`, 'utf8');
const spcboyHtml = readFileSync(`${serverDir}/templates/accounts/spcboy.html`, 'utf8');
const workspaceHtml = readFileSync(`${serverDir}/templates/accounts/partials/spcboy_catalog_workspace.html`, 'utf8');
const mobileHtml = readFileSync(`${serverDir}/templates/accounts/partials/spcboy_mobile_shell.html`, 'utf8');
const allTemplateIds = [...new Set(`${baseHtml}\n${spcboyHtml}\n${workspaceHtml}\n${mobileHtml}`.match(/id="([^"]+)"/g)?.map((m) => m.slice(4, -1)) || [])];

function makeClassList(el) {
  const classes = new Set();
  return {
    add: (...names) => names.forEach((n) => classes.add(n)),
    remove: (...names) => names.forEach((n) => classes.delete(n)),
    toggle: (n, force) => {
      const next = force === undefined ? !classes.has(n) : Boolean(force);
      if (next) classes.add(n);
      else classes.delete(n);
      return next;
    },
    contains: (n) => classes.has(n),
    get list() { return [...classes]; },
  };
}

function makeElement(tagName = 'div', id = '', attrs = {}) {
  const listeners = new Map();
  const attributes = new Map(Object.entries(attrs));
  const styleMap = new Map();
  const children = [];
  const el = {
    tagName: tagName.toUpperCase(),
    id,
    dataset: {},
    hidden: false,
    disabled: false,
    checked: true,
    open: false,
    value: '',
    textContent: '',
    innerHTML: '',
    scrollLeft: 0,
    scrollTop: 0,
    clientWidth: 800,
    parentElement: null,
    parentNode: null,
    nextSibling: null,
    isConnected: true,
    inert: false,
    tabIndex: 0,
    children,
    style: {
      setProperty: (k, v) => styleMap.set(k, v),
      getPropertyValue: (k) => styleMap.get(k) || '',
    },
    classList: null,
    set className(val) {
      el.classList = makeClassList(el);
      String(val || '').split(/\s+/).filter(Boolean).forEach((c) => el.classList.add(c));
    },
    get className() { return el.classList.list.join(' '); },
    addEventListener(type, fn) {
      if (!listeners.has(type)) listeners.set(type, []);
      listeners.get(type).push(fn);
    },
    removeEventListener() {},
    dispatchEvent(event) {
      if (!event.target) event.target = el;
      for (const fn of listeners.get(event.type) || []) fn(event);
      return true;
    },
    click() {
      el.dispatchEvent({ type: 'click', target: el, preventDefault() {}, stopPropagation() {} });
    },
    setAttribute(k, v) { attributes.set(k, String(v)); },
    getAttribute(k) { return attributes.has(k) ? attributes.get(k) : null; },
    removeAttribute(k) { attributes.delete(k); },
    hasAttribute(k) { return attributes.has(k); },
    append(...nodes) {
      for (const n of nodes) {
        if (!n) continue;
        if (n.isFragment && Array.isArray(n.children)) {
          el.append(...n.children);
          continue;
        }
        n.parentElement = el;
        n.parentNode = el;
        children.push(n);
      }
    },
    prepend(...nodes) {
      for (const n of [...nodes].reverse()) {
        if (!n) continue;
        n.parentElement = el;
        n.parentNode = el;
        children.unshift(n);
      }
    },
    insertBefore(n) {
      if (!n) return n;
      n.parentElement = el;
      n.parentNode = el;
      children.push(n);
      return n;
    },
    replaceChildren(...nodes) {
      children.length = 0;
      el.append(...nodes);
    },
    remove() {},
    focus() {},
    blur() {},
    scrollIntoView() {},
    getClientRects: () => [{ left: 0, top: 0, width: 100, height: 20, right: 100, bottom: 20 }],
    getBoundingClientRect: () => ({ left: 0, top: 0, width: 100, height: 20, right: 100, bottom: 20 }),
    closest(sel) {
      let cur = el;
      while (cur) {
        if (sel.includes('#spcboy-mobile-app') && cur.id === 'spcboy-mobile-app') return cur;
        if (sel.includes(cur.tagName.toLowerCase())) return cur;
        cur = cur.parentElement;
      }
      return null;
    },
    querySelector(sel) { return el.querySelectorAll(sel)[0] || null; },
    querySelectorAll(sel) {
      const results = [];
      const walk = (node) => {
        for (const c of node.children || []) {
          if (sel === 'summary' && c.tagName === 'SUMMARY') results.push(c);
          else if (sel.includes('.spcboy-count') && c.classList?.contains('spcboy-count')) results.push(c);
          else if (sel.includes('.spcboy-album-favorite') && c.classList?.contains('spcboy-album-favorite')) results.push(c);
          else if (sel.includes('[name=\'csrfmiddlewaretoken\']') && c.id === 'csrf-token') results.push(c);
          walk(c);
        }
      };
      walk(el);
      return results;
    },
  };
  el.classList = makeClassList(el);
  return el;
}

test('full script boot for site-preferences, site-player, and spcboy throws zero TDZ or runtime errors', async () => {
  const byId = new Map();
  const bySelector = new Map();
  const register = (id, tag = 'div', attrs = {}) => {
    const el = makeElement(tag, id, attrs);
    if (id) byId.set(id, el);
    return el;
  };
  const bodyEl = makeElement('body', '', {});
  bodyEl.classList.add('has-site-player', 'spcboy-body');

  const dock = register('site-player', 'footer');
  dock.dataset = {
    audioUrl: '/audio/spcboy/TRACK_ID/',
    libraryUrl: '/spcboy/',
    nowPlayingUrl: '/spcboy/now-playing.json',
    streamQuotaUrl: '/spcboy/stream-quota.json',
    navigationUrl: '/spcboy/navigation.json',
    favoritesUrl: '/spcboy/favorites.json',
    pageLoadToken: 'tok',
    sessionLimitSeconds: '7200',
    userId: '1',
  };
  const audioEl = register('spcboy-audio', 'audio');
  audioEl.paused = true;
  audioEl.volume = 1;
  register('spcboy-profile-preferences', 'script').textContent = '{}';
  const csrfForm = register('site-player-csrf', 'form');
  const csrfTok = register('csrf-token', 'input');
  csrfTok.value = 'csrf123';
  csrfForm.append(csrfTok);
  register('spcboy-csrf-form', 'form').append(csrfTok);

  const pageEl = makeElement('section');
  pageEl.classList.add('spcboy-page');
  pageEl.dataset = {
    userId: '1',
    catalogUrl: '/spcboy/catalog.json',
    recentsUrl: '/spcboy/recents.json',
    nowPlayingUrl: '/spcboy/now-playing.json',
    favoritesUrl: '/spcboy/favorites.json',
    favoritePlaylistUrl: '/spcboy/favorites/playlist.json',
    albumUrl: '/spcboy/album/ALBUM_ID.json',
    trackUrl: '/spcboy/track/TRACK_ID.json',
    audioUrl: '/audio/spcboy/TRACK_ID/',
  };
  bySelector.set('.spcboy-page', pageEl);

  for (const id of allTemplateIds) {
    if (!byId.has(id)) register(id);
  }
  byId.get('sbonline-context-menu').append(makeElement('button'));
  const eqCmdBtn = makeElement('button');
  eqCmdBtn.dataset.sbonlineCommand = 'equalizer';
  byId.get('sbonline-transport-toolbar')?.append(eqCmdBtn);
  const colHead = makeElement('div');
  colHead.classList.add('spcboy-column-head');
  const colHeadDiv = makeElement('div');
  colHead.append(colHeadDiv);
  bySelector.set('.spcboy-column-head', colHead);
  bySelector.set('.spcboy-column-head > div', colHeadDiv);
  bySelector.set('.spcboy-tree', makeElement('nav'));
  bySelector.set('.sbonline-playlist-heading', makeElement('header'));

  const docListeners = new Map();
  const winListeners = new Map();
  const sampleCatalog = {
    consoles: [{
      name: 'Super Nintendo',
      games: [
        { name: 'Chrono Trigger', albumId: '0'.repeat(32), artworkUrl: '', trackCount: 2 },
        { name: 'Final Fantasy VI', albumId: '1'.repeat(32), artworkUrl: '', trackCount: 3 },
      ],
    }],
  };

  const sandboxWindow = {
    location: { href: 'https://admin.pre-calc.com/spcboy/', pathname: '/spcboy/', search: '' },
    history: { replaceState() {} },
    navigator: { userAgent: 'Mozilla/5.0 (Macintosh)', platform: 'MacIntel', maxTouchPoints: 0, onLine: true },
    matchMedia: (q) => ({ matches: q.includes('min-width: 781px'), addEventListener() {} }),
    setTimeout: (fn, ms) => {
      if ((Number(ms) || 0) > 5000) return 1;
      const t = setTimeout(fn, ms);
      t.unref?.();
      return t;
    },
    clearTimeout,
    setInterval: () => 1,
    clearInterval() {},
    requestAnimationFrame: (fn) => { return 1; },
    cancelAnimationFrame() {},
    MediaSource: function MockMSE() {},
    AudioContext: function MockAudioContext() {
      return {
        sampleRate: 44100,
        currentTime: 0,
        state: 'running',
        destination: {},
        resume: () => Promise.resolve(),
        createMediaElementSource: () => ({ connect() {}, disconnect() {} }),
        createBiquadFilter: () => ({ type: 'peaking', frequency: { value: 0 }, Q: { value: 1 }, gain: { value: 0, cancelScheduledValues() {}, setTargetAtTime() {} }, connect() {} }),
        createGain: () => ({ gain: { value: 1, cancelScheduledValues() {}, setTargetAtTime() {}, setValueAtTime() {}, linearRampToValueAtTime() {} }, connect() {} }),
      };
    },
    addEventListener(type, fn) {
      if (!winListeners.has(type)) winListeners.set(type, []);
      winListeners.get(type).push(fn);
    },
    dispatchEvent(ev) {
      for (const fn of winListeners.get(ev.type) || []) fn(ev);
      return true;
    },
  };
  sandboxWindow.window = sandboxWindow;

  const sandbox = vm.createContext({
    ...sandboxWindow,
    console,
    performance,
    AbortController,
    crypto: { randomUUID: () => 'uuid-' + Math.random().toString(36).slice(2) },
    URL,
    URLSearchParams,
    CustomEvent: class CustomEvent { constructor(type, init = {}) { this.type = type; this.detail = init.detail; } },
    Event: class Event { constructor(type) { this.type = type; } },
    Element: class Element {},
    HTMLAnchorElement: class HTMLAnchorElement {},
    CSS: { escape: (s) => s },
    localStorage: { length: 0, key: () => null, getItem: () => null, removeItem() {} },
    sessionStorage: { length: 0, key: () => null, getItem: () => null, removeItem() {} },
    ResizeObserver: class ResizeObserver { observe() {} },
    MutationObserver: class MutationObserver { observe() {} },
    fetch: async (url) => {
      const target = String(url);
      if (target.includes('/spcboy/catalog.json')) return { ok: true, json: async () => sampleCatalog };
      if (target.includes('/spcboy/favorites.json')) return { ok: true, json: async () => ({ trackIds: [], albumIds: [] }) };
      if (target.includes('/spcboy/album/')) return { ok: true, json: async () => ({ tracks: [{ id: 'ct-1', title: 'Presentiment', game: 'Chrono Trigger', console: 'Super Nintendo', durationSeconds: 90 }] }) };
      return { ok: true, json: async () => ({}) };
    },
    getComputedStyle: () => ({ font: '13px monospace', columnGap: '8', paddingLeft: '4' }),
    document: {
      currentScript: { dataset: { preferencesUrl: '/spcboy/preferences.json' } },
      body: bodyEl,
      fonts: { ready: Promise.resolve() },
      createElement: (tag) => makeElement(tag),
      createDocumentFragment: () => ({ isFragment: true, children: [], append(...n) { this.children.push(...n); } }),
      getElementById: (id) => byId.get(id) || null,
      querySelector(sel) {
        if (sel.startsWith('#') && !sel.includes(' ')) return byId.get(sel.slice(1)) || null;
        return bySelector.get(sel) || null;
      },
      querySelectorAll(sel) {
        if (sel === '[data-equalizer-band]') return [];
        return [];
      },
      addEventListener(type, fn) {
        if (!docListeners.has(type)) docListeners.set(type, []);
        docListeners.get(type).push(fn);
      },
      dispatchEvent(ev) {
        for (const fn of docListeners.get(ev.type) || []) fn(ev);
        return true;
      },
    },
  });

  vm.runInContext(sitePreferencesJs, sandbox);
  vm.runInContext(webaudioAacStreamJs, sandbox);
  vm.runInContext(sitePlayerJs, sandbox);
  assert.ok(sandbox.window.SitePlayer, 'SitePlayer must initialize without throwing');
  vm.runInContext(spcboyJs, sandbox);
  await new Promise((r) => setTimeout(r, 30));

  assert.equal(byId.get('spcboy-library-loading').hidden, true);
  assert.equal(byId.get('spcboy-library-tracks').children.length, 2); // 1 system + empty placeholder
  const sysEl = byId.get('spcboy-library-tracks').children[0];
  assert.equal(sysEl.classList.contains('spcboy-system'), true);
  // First system opens lazily on toggle
  sysEl.open = true;
  byId.get('spcboy-library-tracks').dispatchEvent({ type: 'toggle', target: sysEl, isTrusted: true });
  assert.equal(sysEl.querySelector('.spcboy-album-favorite') !== null || sysEl.children[1].children.length === 2, true);
  // Test search filtering
  byId.get('spcboy-search').value = 'Chrono';
  byId.get('spcboy-search').dispatchEvent({ type: 'input', target: byId.get('spcboy-search') });
  byId.get('spcboy-search').value = '';
  byId.get('spcboy-search').dispatchEvent({ type: 'input', target: byId.get('spcboy-search') });
  // Test Desktop EQ toggle & API
  assert.ok(sandbox.window.SitePlayer.setEqualizerEnabled);
  sandbox.window.SitePlayer.setEqualizerBandGain(0, 4.5);
  assert.equal(sandbox.window.SitePlayer.getEqualizerBands()[0], 4.5);
  await sandbox.window.SitePlayer.setEqualizerEnabled(true);
  assert.equal(sandbox.window.SitePlayer.isEqualizerEnabled(), true);
});
