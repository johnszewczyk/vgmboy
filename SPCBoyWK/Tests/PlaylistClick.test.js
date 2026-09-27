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

test("SPCBoyWK prevents native mouse-down scrolling before focusing a playlist row", () => {
  const mouseDownStart = rowSource.indexOf('row.addEventListener("mousedown"');
  const clickStart = rowSource.indexOf('row.addEventListener("click"');

  assert.notEqual(mouseDownStart, -1);
  assert.notEqual(clickStart, -1);
  assert.ok(mouseDownStart < clickStart);
  assert.match(rowSource.slice(mouseDownStart, clickStart), /if \(event\.button !== 0\) return;[\s\S]*event\.preventDefault\(\);/);
  assert.match(rowSource.slice(clickStart), /selectPlaylistTrack\(track\.id, \{\s*focus: true,/);
});
