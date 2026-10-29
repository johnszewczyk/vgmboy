import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

// Exercise the renderer's actual completion handler with controllable bridge
// replies, without initializing the LCD canvas or a native audio device.
const source = await readFile(new URL('../Sources/ViewBoy/Resources/yoga-app.js', import.meta.url), 'utf8');
const start = source.indexOf('async function handleNativeEnded(snapshot) {');
const end = source.indexOf('\nasync function openLocalPath()', start);
assert.ok(start >= 0 && end > start, 'renderer completion handler is available');
const makeHandler = new Function(
  'state', 'bridge', 'applyNativeStatus', 'trackID', 'pickPlaylistRandom',
  'pickLibraryRandom', 'visibleTracks', 'selectTrack', 'startTrack', 'render',
  `return (${source.slice(start, end)});`,
);

function deferred() {
  let resolve;
  const promise = new Promise((complete) => { resolve = complete; });
  return { promise, resolve };
}

function harness({ retirement, library = async () => null, randomMode = 'off' }) {
  const first = { id: 'a' };
  const second = { id: 'b' };
  const state = {
    currentTrackId: 'a', playbackGeneration: 1, retiredGeneration: 0, playbackToken: 1,
    playbackQueue: [first, second], activeQueue: [first, second],
    preferences: { repeatMode: 'off', randomMode }, status: 'PLAYING',
  };
  const starts = [];
  const handle = makeHandler(state, { playbackCompletionRetire: retirement },
    () => {}, (track) => track.id, () => second, library, () => [], () => {},
    async (track) => { starts.push(track.id); }, () => {});
  return { state, starts, handle, second };
}

const ended = { generation: 1, transport_state: 'ended' };

test('current completion advances after a successful native retirement', async () => {
  const run = harness({ retirement: async () => ({ action: 'play', trackId: 'b' }) });
  await run.handle(ended);
  assert.deepEqual(run.starts, ['b']);
});

test('a rejected native retirement cannot advance a random queue', async () => {
  const run = harness({ retirement: async () => null, randomMode: 'playlist' });
  await run.handle(ended);
  assert.deepEqual(run.starts, []);
  assert.equal(run.state.currentTrackId, 'a');
});

test('late retirement cannot advance a reconfigured or restarted track', async () => {
  for (const ownershipChange of ['generation', 'token']) {
    const pending = deferred();
    const run = harness({ retirement: () => pending.promise });
    const completion = run.handle(ended);
    if (ownershipChange === 'generation') run.state.playbackGeneration = 2;
    else run.state.playbackToken = 2;
    pending.resolve({ action: 'play', trackId: 'b' });
    await completion;
    assert.deepEqual(run.starts, [], ownershipChange);
    assert.equal(run.state.currentTrackId, 'a');
  }
});

test('late random-library selection cannot replace a newer generation', async () => {
  const pending = deferred();
  const run = harness({ retirement: async () => ({ action: 'stop' }),
    library: () => pending.promise, randomMode: 'library' });
  const completion = run.handle(ended);
  await Promise.resolve();
  run.state.playbackGeneration = 2;
  pending.resolve({ track: run.second, queue: [run.second] });
  await completion;
  assert.deepEqual(run.starts, []);
  assert.equal(run.state.currentTrackId, 'a');
});
