import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const source = await readFile(new URL('../Sources/SB2/WKNativeBridge.swift', import.meta.url), 'utf8');
const start = source.indexOf('    nonisolated private static func json(_ value: Any) -> String {');
const end = source.indexOf('\n    }', start);
assert.ok(start >= 0 && end > start);
const fn = source.slice(start, end + '\n    }'.length).replace('nonisolated private static func', 'func');

test('native bridge serializes scalar and object replies as valid JSON', () => {
  const script = `import Foundation\n${fn}\n` + String.raw`
    let values: [Any] = [6000.0, 7, true, NSNull(), "line\n\"quoted\"", ["value": 2], Double.nan]
    for value in values { print(json(value)) }
  `;
  const output = execFileSync('swift', ['-'], { input: script, encoding: 'utf8', timeout: 30000 });
  const lines = output.trim().split('\n').map(line => JSON.parse(line));
  assert.deepEqual(lines, [6000, 7, true, null, 'line\n"quoted"', { value: 2 }, null]);
});
