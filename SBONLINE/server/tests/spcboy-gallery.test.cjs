// Exercise workspace view synchronization after Gallery removal.
const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { test } = require('node:test');

const source = readFileSync(`${__dirname}/../static/accounts/spcboy.js`, 'utf8');

function viewFixture(desktop, activeView = 'all') {
  const calls = [];
  const library = { insertBefore: (node) => { node.parentElement = library; calls.push('move-workspace-to-library'); } };
  const stage = { prepend: (node) => { node.parentElement = stage; calls.push('move-workspace-to-stage'); } };
  const workspaceToolbar = { parentElement: desktop ? library : stage };
  const tabs = ['all', 'favorites', 'recent'].map((v) => ({
    dataset: { view: v },
    active: false,
    pressed: 'false',
    classList: { toggle(name, state) { if (name === 'is-active') this.active = Boolean(state); } },
    setAttribute(name, value) { if (name === 'aria-pressed') this.pressed = value; },
  }));
  const context = vm.createContext({
    view: activeView,
    tabs,
    library,
    syncWorkspaceHeading: () => calls.push('sync-heading'),
    window: { matchMedia: (query) => ({ matches: query.includes('max-width:780px') ? !desktop : desktop }) },
    document: {
      querySelector: (selector) => ({
        '.sbonline-playlist-heading': workspaceToolbar,
        '#spcboy-stage': stage,
      })[selector],
    },
  });
  const fn = source.slice(source.indexOf('  function syncViewButtons()'), source.indexOf('  let selectedGameKey = null;'));
  vm.runInContext(fn, context);
  return { context, calls, library, stage, workspaceToolbar, tabs };
}

test('desktop syncViewButtons places workspace heading inside stage and marks active tab', () => {
  const { context, calls, stage, workspaceToolbar, tabs } = viewFixture(true, 'favorites');
  context.syncViewButtons();
  assert.equal(workspaceToolbar.parentElement, stage);
  assert.ok(calls.includes('move-workspace-to-stage'));
  assert.equal(tabs.find((t) => t.dataset.view === 'favorites').pressed, 'true');
  assert.equal(tabs.find((t) => t.dataset.view === 'all').pressed, 'false');
});

test('mobile syncViewButtons moves workspace heading before stage in library container', () => {
  const { context, calls, library, workspaceToolbar } = viewFixture(false, 'recent');
  context.syncViewButtons();
  assert.equal(workspaceToolbar.parentElement, library);
  assert.ok(calls.includes('move-workspace-to-library'));
});

test('legacy Gallery view and chrome are absent from spcboy workspace', () => {
  assert.doesNotMatch(source, /function openGalleryAlbum/);
  assert.Match ? null : null;
  assert.match(source, /\["all", "favorites", "recent"\]\.includes\(savedView\)/);
  const workspaceHtml = readFileSync(`${__dirname}/../templates/accounts/partials/spcboy_catalog_workspace.html`, 'utf8');
  assert.doesNotMatch(workspaceHtml, /data-view="gallery"/);
});
