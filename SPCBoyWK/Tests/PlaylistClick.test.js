const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const uiSource = fs.readFileSync(
  path.resolve(__dirname, "../Sources/SPCBoyWK/Resources/app-ui.js"),
  "utf8"
);
const rowStart = uiSource.indexOf("function createPlaylistRow(");
const rowEnd = uiSource.indexOf("\nfunction appendPlaylistRowsInBatches(", rowStart);
const rowSource = uiSource.slice(rowStart, rowEnd);

test("SPCBoyWK keeps pointer selection from refocusing and scrolling the playlist row", () => {
  const mouseDownStart = rowSource.indexOf('row.addEventListener("mousedown"');
  const clickStart = rowSource.indexOf('row.addEventListener("click"');
  const keyDownStart = rowSource.indexOf('row.addEventListener("keydown"');

  assert.notEqual(mouseDownStart, -1);
  assert.notEqual(clickStart, -1);
  assert.notEqual(keyDownStart, -1);
  assert.ok(mouseDownStart < clickStart);
  assert.match(rowSource.slice(mouseDownStart, clickStart), /if \(event\.button !== 0\) return;[\s\S]*event\.preventDefault\(\);/);
  const clickHandler = rowSource.slice(clickStart, keyDownStart);
  assert.match(clickHandler, /selectPlaylistTrack\(track\.id, \{[\s\S]*extend: event\.metaKey \|\| event\.ctrlKey,[\s\S]*range: event\.shiftKey/);
  assert.doesNotMatch(clickHandler, /focus:\s*true/);
  assert.match(rowSource.slice(keyDownStart), /selectPlaylistTrack\(track\.id, \{ focus: true \}\)/);
});
