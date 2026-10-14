import assert from 'node:assert/strict';
import test from 'node:test';
import { STN_APERTURE_RATIO, cellCoverage, contrastInk, deviceCell, stnPalette }
  from '../Sources/ViewBoy/Resources/lcd-panel.js';

const luminance = (color) => [1, 3, 5].map((offset) => {
  const channel = parseInt(color.slice(offset, offset + 2), 16) / 255;
  return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4;
}).reduce((sum, value, index) => sum + value * [0.2126, 0.7152, 0.0722][index], 0);

test('component aperture preserves its area at every supported dot size', () => {
  for (const size of [2, 3, 4, 5, 6]) {
    const mask = cellCoverage(size);
    assert.equal(mask.length, size * size);
    assert.ok(Math.abs(mask.reduce((sum, area) => sum + area, 0) / mask.length
      - STN_APERTURE_RATIO ** 2) < 1e-12);
    assert.ok(mask.every((area) => area > 0 && area <= 1));
    assert.ok(mask.some((area) => area < 1), 'matrix edges remain visible');
  }
  assert.equal(cellCoverage(3, true, 'CLASSIC').reduce((sum, area) => sum + area, 0), 4);
});

test('dark ink is no longer washed out by rounding the aperture at 3x', () => {
  const background = '#9BBC0F';
  const panel = deviceCell('#000000', background, cellCoverage(3));
  const classic = deviceCell('#000000', background, cellCoverage(3, true, 'CLASSIC'));
  const mean = (colors) => colors.reduce((sum, color) => sum + luminance(color), 0) / colors.length;
  assert.ok(mean(panel) < mean(classic) * 0.4);
  assert.ok(panel.includes('#000000'), 'center electrode can be exactly black');
  assert.ok(panel.some((color) => color !== '#000000'), 'matrix is still present');
  assert.ok(Math.abs(mean(panel) / luminance(background) - (1 - STN_APERTURE_RATIO ** 2)) < 0.005);
});

test('Contrast Boost changes ink and edge density without changing the matrix mask', () => {
  for (const [ink, background, direction] of [
    ['#333333', '#9BBC0F', -1], ['#BBBBBB', '#111111', 1],
  ]) {
    const mask = cellCoverage(3);
    const boosted = contrastInk(ink, background, 100);
    assert.ok((luminance(boosted) - luminance(ink)) * direction > 0);
    const before = deviceCell(ink, background, mask);
    const after = deviceCell(boosted, background, mask, 100);
    assert.ok(after.some((color, index) => (luminance(color) - luminance(before[index])) * direction > 0));
    assert.ok(after.some((color) => color !== boosted), 'boost retains visible grid edges');
    assert.deepEqual(mask, cellCoverage(3));
  }
});

test('four LCD tones retain hue, endpoints, and ordering in either polarity', () => {
  for (const [ink, background] of [['#000000', '#9BBC0F'], ['#EEEEEE', '#112211']]) {
    const palette = stnPalette(ink, background);
    assert.equal(new Set(palette).size, 4);
    assert.equal(palette[0], ink);
    assert.equal(palette[3], background);
    const tones = palette.map(luminance);
    const direction = Math.sign(tones[3] - tones[0]);
    assert.ok(tones.slice(1).every((tone, index) => (tone - tones[index]) * direction > 0));
  }
});

test('background and exact gapless endpoints survive Contrast Boost', () => {
  for (const size of [2, 3, 4, 5, 6]) {
    assert.ok(deviceCell('#000000', '#9BBC0F', cellCoverage(size, false)).every((color) => color === '#000000'));
    assert.ok(deviceCell('#9BBC0F', '#9BBC0F', cellCoverage(size), 100).every((color) => color === '#9BBC0F'));
  }
});
