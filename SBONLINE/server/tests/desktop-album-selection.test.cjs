const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { test } = require('node:test');

const serverDir = `${__dirname}/..`;
const siteComponentsJs = readFileSync(`${serverDir}/static/accounts/site-components.js`, 'utf8');
const sbInterfaceJs = readFileSync(`${serverDir}/static/accounts/sb-interface.js`, 'utf8');
const spcboyJs = readFileSync(`${serverDir}/static/accounts/spcboy.js`, 'utf8');

test('SiteCommands records user actions, tracks responsiveness duration, and caps history', () => {
  const sandbox = {
    window: {},
    document: {
      addEventListener() {},
      dispatchEvent() {},
    },
    performance: { now: () => 1000 },
    Date: { now: () => 1700000000000 },
    Intl: global.Intl,
  };
  vm.createContext(sandbox);
  vm.runInContext(siteComponentsJs, sandbox);

  assert.ok(sandbox.window.SiteCommands, 'SiteCommands is defined on window');
  const { SiteCommands } = sandbox.window;

  // Test recording a command
  const cmd = SiteCommands.record('album-select', { albumId: 'test-album', name: 'Mega Man 2' });
  assert.equal(typeof cmd.complete, 'function');
  assert.equal(SiteCommands.history().length, 1);
  assert.equal(SiteCommands.history()[0].type, 'album-select');
  assert.equal(SiteCommands.history()[0].status, 'pending');

  // Advance clock and complete command
  sandbox.performance.now = () => 1042;
  const entry = cmd.complete('hydrated', { trackCount: 26 });
  assert.equal(entry.status, 'hydrated');
  assert.equal(entry.durationMs, 42);
  assert.equal(entry.details.trackCount, 26);

  // Test summary calculations
  const summary = SiteCommands.summary();
  assert.equal(summary.total, 1);
  assert.equal(summary.averageMs, 42);
  assert.equal(summary.maxMs, 42);

  // Test history bounding
  for (let i = 0; i < 150; i++) {
    SiteCommands.record('action', { i }).complete('done');
  }
  assert.equal(SiteCommands.history().length, 120);

  SiteCommands.clear();
  assert.equal(SiteCommands.history().length, 0);
});

test('spcboy desktop sidebar selection and playlist hydration support search results and rapid clicks', () => {
  // 1. selectGame always triggers renderDesktopPlaylist without being suppressed by search.value
  assert.match(spcboyJs, /if \(isDesktop\(\)\) renderDesktopPlaylist\(\);/);
  assert.doesNotMatch(spcboyJs, /\(view === "all" && !search\.value\.trim\(\)\)/);

  // 2. ensureAlbumTracks immediately renders desktop playlist on cached hit for active game
  assert.match(spcboyJs, /if \(isDesktop\(\) && selectedGameKey === entry\.key\) \{\s*for \(const row of entry\.list\?\.querySelectorAll/);

  // 3. renderDesktopPlaylist candidate selection includes selectedFallback even when search query is active
  assert.match(spcboyJs, /selectedFallback \? \[selectedFallback\] : \[\]/);

  // 4. applyFilters preserves visibility for the selected game rows
  assert.match(spcboyJs, /\(track\?\.gameKey === selectedGameKey\)/);

  // 5. Sidebar click delegation matches game row and game details, not just summary
  assert.match(spcboyJs, /target\.closest\("\.spcboy-game-row, \.spcboy-game"\)/);

  // 6. SiteCommands logging is integrated for album selection
  assert.match(spcboyJs, /window\.SiteCommands\?\.record\("album-select"/);
});
