import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
const source = html.match(/function rasterCellMetrics\(targetCellHeight\) \{[\s\S]*?\n    \}/)[0];
const metrics = vm.runInNewContext(`(${source})`);

test('raster glyph columns and beam pitches land on whole device pixels', () => {
  for (const profileRows of [15, 24, 30, 37, 48]) {
    for (const ratio of [1, 1.25, 1.5, 2, 3, 4]) {
      const target = 240 * Math.max(1, Math.floor(480 * ratio / 240)) / profileRows;
      const grid = metrics(target);
      assert.ok(Number.isInteger(8 * grid.deviceScale), '8px glyph advance stays on device pixels');
      assert.ok(Number.isInteger(16 * grid.deviceScale), '16px row advance stays on device pixels');
      assert.equal(grid.cellHeight % grid.scanPitch, 0, 'scanlines divide rows evenly');
      assert.ok(grid.scanPitch >= 3);
    }
  }
  assert.equal(metrics(26).cellHeight, 24, 'the former 27px row no longer creates 13.5px columns');
});
