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
  assert.match(mobileCss, /body\.sbonline-site #spcboy-mobile-app \.spcboy-gallery-console-picker\s*\{\s*display:grid;/);
  assert.match(mobileCss, /#spcboy-mobile-app \.spcboy-mobile-console-toggle\[aria-expanded="true"\]/);
  assert.match(mobileCss, /#spcboy-mobile-app \.spcboy-mobile-album-toggle\[aria-expanded="true"\]/);
  assert.match(mobileCss, /#spcboy-mobile-app \.spcboy-mobile-eq-btn\.is-active/);
  assert.match(mobileCss, /#spcboy-mobile-app \.spcboy-mobile-switch\[aria-checked="true"\]/);
  assert.match(mobileCss, /\.spcboy-mobile-load-more\s*\{/);
  assert.match(mobileCss, /\.spcboy-mobile-progress-fill[\s\S]*transform:\s*scaleX\(0\)/);
  assert.doesNotMatch(mobileCss, /\.spcboy-mobile-progress-fill[\s\S]*transition:\s*width/);
});

test('mobile player JS avoids duplicate nav binding, full tracklist re-renders on timeupdate, and linear album lookup', () => {
  assert.equal(spcboyJs.includes('document.querySelectorAll("[data-mobile-app-page]").forEach'), false);
  assert.match(spcboyJs, /audio\?\.addEventListener\("timeupdate",\s*\(\)\s*=>\s*\{\s*if\s*\(!isDesktop\(\)\)\s*updateMobilePlaybackProgress\(\);/s);
  assert.match(spcboyJs, /const gameGroupsByAlbumId = new Map\(\);/);
  assert.match(spcboyJs, /gameGroupsByAlbumId\.get\(albumId\)/);
  assert.match(spcboyJs, /#spcboy-mobile-gallery-more"\)\?\.addEventListener\("click"/);
  assert.match(spcboyJs, /if\s*\(!isDesktop\(\)\)\s*\{\s*openMobileAlbumDetail\(entry,\s*"gallery"\);\s*return true;\s*\}/s);
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
  assert.match(viewsPy, /pre_roll_ms = 100 if start_ms == 0 else 0/);
  assert.match(viewsPy, /adelay=\{pre_roll_ms\}\|\{pre_roll_ms\}/);
});
