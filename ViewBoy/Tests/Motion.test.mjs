import assert from 'node:assert/strict';
import test from 'node:test';
import { snappyEase } from '../Sources/ViewBoy/Resources/motion.js';

test('SB2 Bezier timing is inverted in time, bounded and monotonic', () => {
  assert.equal(snappyEase(-1), 0);
  assert.equal(snappyEase(0), 0);
  assert.equal(snappyEase(1), 1);
  assert.equal(snappyEase(2), 1);
  let previous = 0;
  for (let i = 1; i <= 1000; i++) {
    const value = snappyEase(i / 1000);
    assert.ok(value >= previous && value <= 1);
    previous = value;
  }
  for (const [time, position] of [[0.1, 0.15625], [0.25, 0.607220362], [0.5, 0.877833605], [0.75, 0.975480068]]) {
    assert.ok(Math.abs(snappyEase(time) - position) < 1e-7);
  }
  assert.ok(snappyEase(0.25) > 0.6, 'fast travel instead of the old 12.5% position');
});
