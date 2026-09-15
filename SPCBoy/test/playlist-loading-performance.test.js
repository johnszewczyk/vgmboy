const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(path.join(__dirname, "..", "web", "app-ui.js"), "utf8");

function functionBody(name, nextName) {
  const start = source.indexOf(`function ${name}`);
  const end = source.indexOf(`function ${nextName}`, start);
  assert.ok(start >= 0, `missing ${name}`);
  assert.ok(end > start, `missing ${nextName} after ${name}`);
  return source.slice(start, end);
}

test("database playlist activation stays catalog-only and avoids the full shell render", () => {
  const activation = functionBody("loadDatabaseGamesIntoPlaylist", "activateDatabaseSelection");
  assert.doesNotMatch(activation, /renderAll\(/);
  assert.match(activation, /renderPlaylist\(\)/);
  assert.match(activation, /renderDatabaseGames\(\)/);
});

test("catalog playlist rows cannot enter the disk metadata hydration workers", () => {
  const hydration = functionBody("hydratePlaylistMetadata", "applyTrackInspection");
  assert.match(hydration, /!track\.catalogRow/);
  assert.match(source, /catalogRow: true/);
});

test("large playlists use bounded DOM windows with scroll spacers", () => {
  assert.match(source, /PLAYLIST_VIRTUALIZATION_THRESHOLD/);
  assert.match(source, /makePlaylistVirtualSpacer/);
  assert.match(source, /playlist-virtual-spacer/);
  assert.match(source, /renderPlaylist\(\{ sort: false \}\)/);
});
