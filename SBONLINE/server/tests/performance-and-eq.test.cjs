const { readFileSync } = require('node:fs');
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
  assert.match(sitePlayerJs, /if \(command === "equalizer"\) \{[\s\S]*activePreset\?\.gains[\s\S]*setEqualizerEnabled\(!equalizerEnabled\)/);
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
