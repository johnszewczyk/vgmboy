// Exercise Gallery navigation from the shipped player without a browser/account.
const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { test } = require('node:test');

const source = readFileSync(`${__dirname}/../static/accounts/spcboy.js`, 'utf8');

function viewFixture(desktop) {
  const calls = [];
  const library = { insertBefore: node => { node.parentElement = library; calls.push('move-workspace-to-library'); } };
  const stage = { prepend: node => { node.parentElement = stage; calls.push('move-workspace-to-stage'); } };
  const tree = { append: node => { node.parentElement = tree; calls.push('move-console-filter-to-sidebar'); } };
  const galleryToolbar = { prepend: node => { node.parentElement = galleryToolbar; calls.push('move-console-filter-to-gallery-toolbar'); } };
  const workspaceToolbar = { parentElement: desktop ? stage : library };
  const galleryConsoles = {
    parentElement: desktop ? galleryToolbar : tree,
    setAttribute: (name, value) => calls.push([name, value]),
  };
  const context = vm.createContext({
    view: 'gallery',
    tabs: [],
    library,
    trackList: { hidden: false },
    galleryConsoles,
    syncWorkspaceHeading() {},
    window: { matchMedia: query => ({ matches: query === '(min-width: 781px)' ? desktop : !desktop }) },
    document: { querySelector: selector => ({
      '.sbonline-playlist-heading': workspaceToolbar,
      '#spcboy-stage': stage,
      '.spcboy-tree': tree,
      '.spcboy-gallery-toolbar': galleryToolbar,
    })[selector] },
  });
  const fn = source.slice(source.indexOf('  function syncViewButtons()'), source.indexOf('  let selectedGameKey = null;'));
  vm.runInContext(fn, context);
  return { context, calls, tree, galleryToolbar, galleryConsoles };
}

test('desktop Gallery moves its console filter into the sidebar', () => {
  const { context, calls, tree, galleryConsoles } = viewFixture(true);
  context.syncViewButtons();
  assert.equal(galleryConsoles.parentElement, tree);
  assert.equal(context.trackList.hidden, true);
  assert.ok(calls.includes('move-console-filter-to-sidebar'));
  assert.ok(calls.some(call => Array.isArray(call) && call[0] === 'aria-orientation' && call[1] === 'vertical'));
  const playerCss = readFileSync(`${__dirname}/../static/accounts/spcboy.css`, 'utf8');
  assert.doesNotMatch(playerCss, /spcboy-library\.is-gallery \.spcboy-tree \{ display: none;/);
});

test('mobile Gallery keeps its dropdown filter in the Gallery toolbar', () => {
  const { context, calls, galleryToolbar, galleryConsoles } = viewFixture(false);
  context.syncViewButtons();
  assert.equal(galleryConsoles.parentElement, galleryToolbar);
  assert.equal(context.trackList.hidden, false);
  assert.ok(calls.includes('move-console-filter-to-gallery-toolbar'));
  const onlineCss = readFileSync(`${__dirname}/../static/accounts/sbonline.css`, 'utf8');
  const mobileCss = readFileSync(`${__dirname}/../static/accounts/sb-mobile.css`, 'utf8');
  assert.match(onlineCss, /spcboy-gallery-console-picker \{ display: none;/);
  assert.match(mobileCss, /spcboy-gallery-console-picker \{ display:grid;/);
});

test('opening a Gallery album switches to the normal selected album view', () => {
  const calls = [];
  const context = vm.createContext({
    view: 'gallery',
    search: { value: 'console filter' },
    headerSearch: { value: 'console filter' },
    pendingHeaderSearch: { query: 'console filter' },
    selectedGameKey: null,
    storage: { set: (...args) => calls.push(['storage', ...args]) },
    releaseGalleryCards: () => calls.push('release-gallery-cards'),
    syncViewButtons: () => calls.push('sync-views'),
    scheduleCatalogSearch: () => calls.push('clear-search-filter'),
    selectGame: key => calls.push(['select-game', key]),
    scheduleSelectionIndicators() { calls.push('selection-indicators'); },
  });
  const fn = source.slice(source.indexOf('  function openGalleryAlbum(entry)'), source.indexOf('  function syncTrackContainers()'));
  vm.runInContext(fn, context);
  const entry = { key: 'console:album', details: { scrollIntoView: options => calls.push(['scroll', options.block]) } };
  context.openGalleryAlbum(entry);
  assert.equal(context.view, 'all');
  assert.equal(context.search.value, '');
  assert.equal(context.headerSearch.value, '');
  assert.equal(context.pendingHeaderSearch, null);
  assert.equal(context.selectedGameKey, 'console:album');
  assert.deepEqual(calls.filter(call => Array.isArray(call) && call[0] === 'select-game'), [['select-game', 'console:album']]);
  assert.ok(calls.includes('release-gallery-cards'));
});
