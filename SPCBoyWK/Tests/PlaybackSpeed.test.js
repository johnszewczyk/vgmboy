const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

function speedApi() {
  const source = fs.readFileSync(path.join(__dirname, "..", "Sources", "SPCBoyWK", "Resources", "playback-speed.js"), "utf8");
  const window = {};
  vm.runInNewContext(source, { window });
  return window.SPCBoyPlaybackSpeed;
}

test("SPCBoyWK displays clean playback rates as reduced fractions", () => {
  const speed = speedApi();
  assert.equal(speed.format(speed.parse("1.25")), "5/4");
  assert.equal(speed.format(speed.parse(".5")), "1/2");
  assert.equal(speed.format(speed.parse("5/4")), "5/4");
  assert.equal(speed.format(speed.parse("1.01")), "1.01");
  assert.equal(speed.format(speed.parse("1/3")), "1/3");
});
