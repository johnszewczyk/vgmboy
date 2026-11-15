// Exercise the shipped player functions without a browser or production account.
const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { test } = require('node:test');
const source = readFileSync(`${__dirname}/../static/accounts/site-player.js`, 'utf8');
const playback = source.slice(source.indexOf('  async function startAudioPlayback()'), source.indexOf('  function selectSettingsPage('));
const ended = source.slice(source.indexOf('  audio.addEventListener("ended",'), source.indexOf('  audio.addEventListener("error",'));

function fixture(overrides = {}) {
  const calls = [];
  const context = vm.createContext({
    audio: { src: 'track', currentTime: 0, play() { calls.push('play'); return Promise.resolve(); } },
    playbackSessionExpired: () => false, currentTrack: { id: 'track' },
    playbackWanted: false, cancelStreamRecovery() {}, recoverStream() { calls.push('recover'); },
    equalizerEnabled: false, audioContext: null, streamOffsetSeconds: 0,
    AudioContextClass: null, equalizerGraphFailed: false, aacTransport: {supported:true}, streamNeedsRetry:false,
    audioURL: (_, offset) => `track?start=${offset}`, applyPlaybackRate() {},
    setPlayerStatus: message => calls.push(message), updateControls() {},
    setAudioSource(url) { context.audio.src = url; },
    sourcePositionSeconds() { return context.streamOffsetSeconds + (Number(context.audio.currentTime) || 0); },
    ...overrides,
  });
  vm.runInContext(playback, context);
  return { context, calls };
}

test('Play starts before a pending AudioContext resume completes', async () => {
  let resume;
  const { context, calls } = fixture({ audioContext: { state: 'suspended', resume: () => new Promise(resolve => { resume = resolve; }) } });
  const result = context.startAudioPlayback();
  assert.deepEqual(calls, ['play']);
  resume();
  assert.equal(await result, true);
});

test('Retry reloads a failed resource at its absolute playback position', async () => {
  const { context } = fixture({ streamOffsetSeconds: 12 });
  Object.assign(context.audio, { error: { code: 2 }, currentTime: 4 });
  assert.equal(await context.startAudioPlayback(), true);
  assert.equal(context.audio.src, 'track?start=16');
});

test('Replay reloads an ended resource from the beginning', async () => {
  const { context } = fixture({ streamOffsetSeconds: 12 });
  Object.assign(context.audio, { ended: true, currentTime: 4 });
  await context.startAudioPlayback();
  assert.equal(context.audio.src, 'track?start=0');
});

test('A track switch abort does not overwrite the new track status', async () => {
  const { context, calls } = fixture();
  context.audio.play = () => Promise.reject({ name: 'AbortError' });
  assert.equal(await context.startAudioPlayback(), false);
  assert.deepEqual(calls, []);
});

test('An expired page does not request playback', async () => {
  const { context, calls } = fixture({ playbackSessionExpired: () => true });
  assert.equal(await context.startAudioPlayback(), false);
  assert.deepEqual(calls, []);
});

test('Volume gain applies the selected level without dropping volume on EQ boost', () => {
  const gains = [];
  const context = vm.createContext({
    equalizerGraphReady: true, equalizerEnabled: true, equalizerBandGains: [6, -3],
    equalizerFilters: [], volumeStep: 5, audioContext: { currentTime: 0 },
    equalizerOutput: { gain: { setTargetAtTime: value => gains.push(value) } },
  });
  vm.runInContext(source.slice(source.indexOf('  function updateEqualizerGraph()'), source.indexOf('  function ensureEqualizerGraph()')), context);
  context.updateEqualizerGraph();
  assert.ok(Math.abs(gains[0] - .25) < 1e-9);
});

test('Equalizer builds one filter chain and applies the selected band curve', () => {
  const connections = [];
  const parameters = [];
  const filters = [];
  let gainCount = 0;
  const destination = {};
  class AudioContextMock {
    constructor() { this.currentTime = 2; this.sampleRate = 44100; this.destination = destination; }
    createMediaElementSource() {
      return { connect: node => connections.push(['source', node]), disconnect() {} };
    }
    createBiquadFilter() {
      const index = filters.length;
      const filter = {
        gain: { setTargetAtTime: (...args) => parameters.push([index, ...args]) },
        frequency: { value: 0 }, Q: { value: 0 },
        connect: node => connections.push([index, node]),
      };
      filters.push(filter);
      return filter;
    }
    createGain() {
      const index = gainCount++ === 0 ? 'output' : 'fade';
      return { gain: { value: 1, setTargetAtTime: (...args) => parameters.push([index, ...args]) },
        connect: node => connections.push([index, node]) };
    }
  }
  const context = vm.createContext({
    AudioContextClass: AudioContextMock, audio: {}, audioContext: null,
    equalizerGraphReady: false, equalizerGraphFailed: false, equalizerSource: null,
    equalizerFilters: [], equalizerOutput: null, transportFadeOutput: null,
    equalizerEnabled: true, equalizerBandGains: Array(10).fill(0), volumeStep: 10,
    equalizerFrequencies: [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000],
    storage: { set() {} }, equalizerError: { textContent: '' }, syncEqualizerControls() {},
  });
  context.equalizerBandGains[0] = 6;
  context.equalizerBandGains[9] = -3;
  vm.runInContext(source.slice(source.indexOf('  function updateEqualizerGraph()'), source.indexOf('  function currentTransportFadeGain(')), context);

  assert.equal(context.ensureEqualizerGraph(), true);
  assert.equal(filters.length, 10);
  assert.equal(filters[0].type, 'peaking');
  assert.equal(filters[0].frequency.value, 31);
  assert.equal(filters[9].frequency.value, 16000);
  assert.deepEqual(connections[0], ['source', filters[0]]);
  for (let index = 0; index < filters.length - 1; index += 1) {
    assert.deepEqual(connections[index + 1], [index, filters[index + 1]]);
  }
  assert.deepEqual(connections.slice(-3), [
    [9, context.equalizerOutput],
    ['output', context.transportFadeOutput],
    ['fade', destination],
  ]);
  assert.equal(parameters.filter(([key]) => typeof key === 'number').length, 10);
  const outputTarget = parameters.find(([key]) => key === 'output');
  assert.ok(Math.abs(outputTarget[1] - .5) < 1e-9);
});

test('Equalizer saves and reapplies all three browser presets', async () => {
  const buttons = (attribute, count) => Array.from({ length: count }, (_, index) => ({
    dataset: { [attribute]: String(index) },
    listeners: {},
    addEventListener(name, handler) { this.listeners[name] = handler; },
    setAttribute() {},
    textContent: `Preset ${index + 1}`,
  }));
  const applyButtons = buttons('equalizerPresetApply', 3);
  const saveButtons = buttons('equalizerPresetSave', 3);
  const stored = new Map();
  const savedCurves = [];
  const context = vm.createContext({
    equalizerPresetApplyButtons: applyButtons, equalizerPresetSaveButtons: saveButtons,
    equalizerPresets: [null, null, null], equalizerBandGains: Array(10).fill(0),
    equalizerEnabled: false, equalizerPresetStatus: { textContent: '' },
    storage: { set: (key, value) => stored.set(key, JSON.parse(JSON.stringify(value))) },
    syncEqualizerPresetControls() {},
    saveEqualizerGains: () => savedCurves.push(Array.from(context.equalizerBandGains)),
    setEqualizerEnabled: async enabled => { context.equalizerEnabled = enabled; return enabled; },
  });
  const applyStart = source.indexOf('  async function applyEqualizerPreset');
  vm.runInContext(source.slice(applyStart !== -1 ? applyStart : source.lastIndexOf('  equalizerPresetApplyButtons.forEach'), source.indexOf('  queueToggle.addEventListener(')), context);

  for (let index = 0; index < 3; index += 1) {
    context.equalizerBandGains = Array.from({ length: 10 }, (_, band) => index * 2 + band / 2);
    saveButtons[index].listeners.click();
  }
  assert.equal(context.equalizerPresets.length, 3);
  assert.deepEqual(stored.get('equalizerPresets'), JSON.parse(JSON.stringify(context.equalizerPresets)));

  for (let index = 0; index < 3; index += 1) {
    context.equalizerBandGains = Array(10).fill(-12);
    context.equalizerEnabled = false;
    await applyButtons[index].listeners.click();
    assert.deepEqual(Array.from(context.equalizerBandGains), Array.from(context.equalizerPresets[index].gains));
    assert.equal(context.equalizerEnabled, true);
  }
  assert.equal(savedCurves.length, 3);
  assert.equal(context.equalizerPresetStatus.textContent, 'Preset 3 applied.');
});

test('A volume adjustment updates gain without restarting the stream', () => {
  const calls = [];
  const context = vm.createContext({
    volumeInput: { value: '3', addEventListener: (_, handler) => { context.onVolume = handler; } },
    storage: { set() {} }, applyVolumeStep() {}, volumeRestartTimer: null,
    window: { clearTimeout() {}, setTimeout() { throw new Error('Stream restart scheduled'); } },
    ensureEqualizerGraph: () => true, updateEqualizerGraph: () => calls.push('gain'),
    audioContext: { state: 'running' }, currentTrack: { id: 'guile' }, volumeStep: 20,
  });
  vm.runInContext(source.slice(source.indexOf('  volumeInput.addEventListener("input",'), source.indexOf('  settingsClose.addEventListener(')), context);
  context.onVolume();
  assert.equal(context.volumeStep, 3);
  assert.deepEqual(calls, ['gain']);
});

test('An early stream end stays on the track with an actionable retry', async () => {
  const { context, calls } = fixture({
    streamOffsetSeconds: 10, effectiveDuration: () => 60,
    hasReachedStreamQuota: async () => false, moveTrack: () => calls.push('next'),
  });
  Object.assign(context.audio, { ended: true, currentTime: 20, addEventListener: (_, handler) => { context.onEnded = handler; } });
  vm.runInContext(ended, context);
  await context.onEnded();
  assert.deepEqual(calls, ['recover']);
});

test('A normal end after an offset advances to the next track', async () => {
  const { context, calls } = fixture({
    streamOffsetSeconds: 40, effectiveDuration: () => 60,
    hasReachedStreamQuota: async () => false, moveTrack: () => calls.push('next'),
  });
  Object.assign(context.audio, { ended: true, currentTime: 20, addEventListener: (_, handler) => { context.onEnded = handler; } });
  vm.runInContext(ended, context);
  await context.onEnded();
  assert.deepEqual(calls, ['next']);
});

for (const playing of [false, true]) test(`Reload/login restores position with fresh authorization (playing=${playing})`, () => {
  const entries = new Map();
  let resumed = false;
  const context = vm.createContext({
    userPrefix: 'spcboy:7:',
    window: {
      SBOProfileStorage: {
        set(scope, key, val) { entries.set('playback:session', JSON.stringify(val)); },
        get(scope, key, fallback) { const v = entries.get('playback:session'); return v ? JSON.parse(v) : fallback; },
      },
    },
    currentTrack: { id: 'guile-1', title: 'Guile', game: 'SFII', durationSeconds: 120, sourcePath: 'private', audioUrl: 'expired-token' },
    queue: [{id:'guile-2',title:'Next'}], playlistHistory: [], nowPlayingPlaylist: true,
    audio: { currentTime: 8, paused: !playing, ended: false }, streamOffsetSeconds: 12,
    title: {}, currentPlaybackId: 'old', effectiveDuration: () => 120,
    createPlaybackId: () => 'fresh-playback', audioURL: (_,offset) => `authorized-with-new-page-token?start=${offset}`,
    setAudioSource(url) { context.audio.src = url; },
    applyPlaybackRate() {}, renderQueue() {}, updateControls() {}, setPlayerStatus() {},
    renderCurrentTrack() {},
    sourcePositionSeconds() { return context.streamOffsetSeconds + (Number(context.audio.currentTime) || 0); },
    startAudioPlayback() { resumed = true; },
  });
  const saveStart = source.indexOf('  function albumIdForTrack(');
  vm.runInContext(source.slice(saveStart !== -1 ? saveStart : source.indexOf('  function savedTrack('), source.indexOf('  function effectiveDuration(')), context);
  context.savePlayback();
  const saved = JSON.parse(entries.get('playback:session'));
  assert.equal(saved.position,20);
  assert.equal(saved.track.sourcePath,undefined);
  assert.equal(saved.track.audioUrl,undefined);
  context.currentTrack = null; context.queue = []; context.audio.currentTime = 0;
  context.restorePlayback();
  assert.equal(context.currentTrack.id,'guile-1');
  assert.equal(context.queue[0].id,'guile-2');
  assert.equal(context.currentPlaybackId,'fresh-playback');
  assert.equal(context.audio.src,'authorized-with-new-page-token?start=20');
  assert.equal(resumed,playing);
});

test('AAC interruption resumes at the absolute position even after media EOF', async () => {
  const {context} = fixture({streamOffsetSeconds:120, streamNeedsRetry:true});
  Object.assign(context.audio, {ended:true,currentTime:95});
  await context.startAudioPlayback();
  assert.equal(context.audio.src, 'track?start=215');
});

test('Ordinary pause resumes the existing AAC buffer without replacing its source', async () => {
  const {context} = fixture({streamOffsetSeconds:30});
  Object.assign(context.audio, {paused:true,currentTime:12});
  await context.startAudioPlayback();
  assert.equal(context.audio.src, 'track');
  assert.equal(context.streamOffsetSeconds,30);
});

test('Unsupported AAC produces an explicit error without requesting another codec', async () => {
  const {context,calls} = fixture({aacTransport:{supported:false}});
  assert.equal(await context.startAudioPlayback(),false);
  assert.deepEqual(calls,['AAC streaming requires an up-to-date browser.']);
  assert.equal(context.audio.src,'track');
});

function recoveryFixture() {
  const scheduled = new Map(), delays = [], statuses = [];
  let serial = 0, starts = 0;
  const context = vm.createContext({
    navigator: {onLine:true},
    window: { clearTimeout: id => scheduled.delete(id), setTimeout(fn, delay) {
      delays.push(delay); scheduled.set(++serial, fn); return serial;
    } },
    audio: { pause() {} }, currentPlaybackId: 'same-playback', playbackNeedsLogin: false,
    playbackSessionExpired: () => false, stopPlaybackSession() {},
    startAudioPlayback() { starts++; }, setPlayerStatus: text => statuses.push(text),
    updateControls() {}, savePlayback() {}, showStreamQuotaMessage() { statuses.push('quota'); },
    clearFadedSkip() {},
  });
  vm.runInContext(source.slice(source.indexOf('  let streamNeedsRetry = false;'), source.indexOf('  const aacTransport =')), context);
  vm.runInContext('playbackWanted = true;', context);
  return {context, scheduled, delays, statuses, starts: () => starts,
    fire() { const [id, fn] = scheduled.entries().next().value; scheduled.delete(id); fn(); } };
}

test('Recovery is bounded, deduplicated and exponentially delayed', () => {
  const f = recoveryFixture();
  for (let attempt = 0; attempt < 3; attempt++) {
    f.context.recoverStream(); f.context.recoverStream();
    assert.equal(f.scheduled.size, 1); f.fire();
  }
  f.context.recoverStream();
  assert.deepEqual(f.delays, [1000,2000,4000]);
  assert.equal(f.starts(), 3); assert.equal(f.scheduled.size, 0);
});

test('Explicit pause cancels pending automatic recovery', () => {
  const f = recoveryFixture(); f.context.recoverStream(); f.context.pausePlayback();
  assert.equal(f.scheduled.size, 0);
  f.context.recoverStream(); assert.equal(f.scheduled.size, 0);
});

test('A superseded playback cannot be restarted by a stale retry', () => {
  const f = recoveryFixture(); f.context.recoverStream();
  f.context.currentPlaybackId = 'new-playback'; f.fire();
  assert.equal(f.starts(), 0);
});

for (const status of [401,403,404,410,415,429]) test(`HTTP ${status} does not automatically retry`, () => {
  const f = recoveryFixture(); f.context.recoverStream({status});
  assert.equal(f.scheduled.size, 0);
});

const transportSource = readFileSync(`${__dirname}/../static/accounts/aac-stream.js`, 'utf8');
test('Buffer pressure evicts played data then retries identical rejected bytes', async () => {
  const bytes = new Uint8Array([1,2,3]), appended = [], removed = [];
  const context = vm.createContext({audio: {currentTime: 20}, abort: {signal: {aborted: false}},
    operation: async (_, action) => action()});
  vm.runInContext(transportSource.slice(transportSource.indexOf('      async function append('),transportSource.indexOf('      async function networkRead(')),context);
  let full = true;
  await context.append({buffered: {length:1,start:()=>0},
    appendBuffer(value) { appended.push(value); if (full) { full = false; throw Object.assign(new Error(),{name:'QuotaExceededError'}); } },
    remove(start,end) {removed.push([start,end]);}
  },bytes);
  assert.deepEqual(removed,[[0,15]]);
  assert.equal(appended.length,2);
  assert.equal(appended[0],bytes); assert.equal(appended[1],bytes);
});

test('A buffer with no safely evictable audio fails instead of dropping unplayed data', async () => {
  const context = vm.createContext({audio: {currentTime:0},abort:{signal:{aborted:false}},operation:async(_,action)=>action()});
  vm.runInContext(transportSource.slice(transportSource.indexOf('      async function append('),transportSource.indexOf('      async function networkRead(')),context);
  await assert.rejects(context.append({buffered:{length:1,start:()=>0},
    appendBuffer() {throw Object.assign(new Error(),{name:'QuotaExceededError'});},
    remove() {throw new Error('Must not remove unplayed audio');}
  },new Uint8Array([1])),{name:'QuotaExceededError'});
});

test('Offline recovery preserves intent without consuming retry attempts', () => {
  const f = recoveryFixture(); f.context.navigator.onLine = false;
  f.context.recoverStream(); assert.equal(f.scheduled.size,0);
  f.context.navigator.onLine = true; f.context.recoverStream();
  assert.deepEqual(f.delays,[1000]);
});

test('System controls share transport, preserve paused seeks and use absolute position', () => {
  const actions = {}, sources = [], positions = []; let pauses = 0, plays = 0;
  const context = vm.createContext({
    navigator: {mediaSession: {setActionHandler: (name,handler) => actions[name] = handler,
      setPositionState: value => positions.push(value)}},
    window: {}, currentTrack: {id:'track',title:'Guile',game:'SFII'},
    audio: {currentTime:5,playbackRate:1,paused:true}, streamOffsetSeconds:20,
    playbackWanted:false, effectiveDuration:()=>180, playbackSessionExpired:()=>false,
    pausePlayback() {pauses++;}, startAudioPlayback() {plays++;}, moveTrack() {},
    cancelStreamRecovery() {}, setAudioSource(url) {sources.push(url); context.audio.currentTime=0;},
    audioURL:(_,offset)=>`aac?start=${offset}`, applyPlaybackRate() {}, savePlayback() {},
    effectivePlaybackRate: () => 1,
    sourcePositionSeconds() { return context.streamOffsetSeconds + (Number(context.audio.currentTime) || 0); },
  });
  vm.runInContext(source.slice(source.indexOf('  function syncMediaPosition()'),source.indexOf('  function renderQueue()')),context);
  context.syncMediaPosition(); assert.equal(positions.at(-1).position,25);
  actions.pause(); assert.equal(pauses,1);
  actions.seekforward({seekOffset:10}); assert.equal(sources.at(-1),'aac?start=35');
  assert.equal(plays,0);
  actions.play(); assert.equal(plays,1);
  actions.seekto({seekTime:Infinity}); assert.equal(sources.at(-1),'aac?start=179.9');
});

for (const changing of [false,true]) test(`Device pause cancels recovery except during source replacement (changing=${changing})`, () => {
  let cancelled = false;
  const context = vm.createContext({
    changingAudioSource:changing, playbackWanted:true, nowPlayingTimer:null,
    audio:{ended:false,error:null,addEventListener:(_,handler)=>{context.onPause=handler;}},
    cancelStreamRecovery(){cancelled=true;},syncMediaSession(){},updateControls(){},emitTrack(){},
    clearNowPlaying(){},window:{clearInterval(){}},
    clearFadedSkip(){},
  });
  vm.runInContext(source.slice(source.indexOf('  audio.addEventListener("pause",'),source.indexOf('  audio.addEventListener("waiting",')),context);
  context.onPause();
  assert.equal(cancelled,!changing); assert.equal(context.playbackWanted,changing);
});

test('Speed fraction parser accepts fractional and decimal values from 1/2 to 2', () => {
  const context = vm.createContext({ storage: { remove() {}, get() { return null; } } });
  vm.runInContext(source.slice(source.indexOf('  function parseSpeedFraction('), source.indexOf('  const savedFraction =')), context);
  const one = context.parseSpeedFraction('1/1');
  assert.equal(one?.rate, 1);
  assert.equal(one?.fraction, '1/1');
  const frac = context.parseSpeedFraction('33/32');
  assert.equal(frac?.rate, 33/32);
  assert.equal(frac?.fraction, '33/32');
  const dec = context.parseSpeedFraction('1.5');
  assert.equal(dec?.rate, 1.5);
  assert.equal(dec?.fraction, '3/2');
  const withX = context.parseSpeedFraction('1.25x');
  assert.equal(withX?.rate, 1.25);
  assert.equal(withX?.fraction, '5/4');
  assert.equal(context.parseSpeedFraction('0.1'), null);
  assert.equal(context.parseSpeedFraction('3.0'), null);
});

test('Long play duration parser parses strings, M:SS, and H:MM:SS', () => {
  const context = vm.createContext({ maximumLongPlaySeconds: 86400 });
  vm.runInContext(source.slice(source.indexOf('  function parseLongPlayDuration('), source.indexOf('  let spcFadeSeconds =')), context);
  assert.equal(context.parseLongPlayDuration('180'), 180);
  assert.equal(context.parseLongPlayDuration('3:00'), 180);
  assert.equal(context.parseLongPlayDuration('1:02:03'), 3723);
  assert.equal(context.parseLongPlayDuration('0'), 0);
  assert.equal(context.parseLongPlayDuration('-5'), null);
  assert.equal(context.parseLongPlayDuration('invalid'), null);
});

test('Equalizer toggle applies live without restarting active playback when Web Audio is ready', async () => {
  const calls = [];
  let ctx = null;
  class AudioContextMock {
    constructor() { this.state = 'suspended'; ctx = this; }
    resume() { calls.push('resume'); this.state = 'running'; return Promise.resolve(); }
  }
  const storageValues = new Map();
  const context = vm.createContext({
    equalizerEnabled: false,
    equalizerError: { textContent: '' },
    AudioContextClass: AudioContextMock,
    equalizerGraphFailed: false,
    audioContext: null,
    currentTrack: { id: 'guile' },
    window: { dispatchEvent(event) { calls.push(['event', event.type, event.detail?.equalizerEnabled]); } },
    CustomEvent: class { constructor(type, init = {}) { this.type = type; this.detail = init.detail; } },
    storage: { set(k, v) { storageValues.set(k, v); } },
    updateEqualizerToggle(enabled) { calls.push(['toggle-ui', enabled]); },
    ensureEqualizerGraph() {
      if (!ctx) ctx = new AudioContextMock();
      context.audioContext = ctx;
      calls.push('ensure-graph');
      return true;
    },
    updateEqualizerGraph() { calls.push(['update-graph', context.equalizerEnabled]); },
    syncEqualizerControls() { calls.push('sync-eq'); },
    syncOnlineControls() { calls.push('sync-online'); },
    restartCurrentStream() { throw new Error('Should not restart active stream when Web Audio EQ is live'); },
    sourcePositionSeconds() { return 12; },
  });
  vm.runInContext(source.slice(source.indexOf('  async function setEqualizerEnabled('), source.indexOf('  function updateLongPlayToggle(')), context);
  assert.equal(await context.setEqualizerEnabled(true), true);
  assert.equal(storageValues.get('equalizerEnabled'), true);
  assert.ok(calls.includes('resume'));
  assert.ok(calls.some((entry) => Array.isArray(entry) && entry[0] === 'update-graph' && entry[1] === true));
});

test('audioURL skips server eq and volume params when Web Audio client processing is available', () => {
  const context = vm.createContext({
    URLSearchParams,
    dock: { dataset: { audioUrl: '/audio/spcboy/TRACK_ID/', pageLoadToken: 'tok' } },
    currentPlaybackId: 'pb1',
    playbackSpeedEnabled: false,
    playbackRateFraction: '1/1',
    spcFadeSeconds: 5,
    longPlayEnabled: false,
    longPlaySeconds: 180,
    equalizerEnabled: true,
    equalizerBandGains: [6, 0, 0, 0, 0, 0, 0, 0, 0, -3],
    volumeStep: 10,
    equalizerGraphFailed: false,
    AudioContextClass: function AudioContextMock() {},
  });
  vm.runInContext(source.slice(source.indexOf('  function audioURL('), source.indexOf('  function nativeFormatPlaybackRate(')), context);
  const clientUrl = context.audioURL({ id: 'guile' }, 0);
  assert.equal(clientUrl.includes('eq='), false);
  assert.equal(clientUrl.includes('volume='), false);

  context.AudioContextClass = null;
  const legacyUrl = context.audioURL({ id: 'guile' }, 0);
  assert.equal(legacyUrl.includes('eq=6.0'), true);
  assert.equal(legacyUrl.includes('volume=10'), true);
});

test('playPlaylist never falls back to playlist[0] when an explicit startTrackId is missing', async () => {
  const played = [];
  const context = vm.createContext({
    playbackSessionExpired: () => false,
    normalizeTrack: (t) => (t && t.id ? { ...t } : null),
    libraryById: new Map(),
    queue: [],
    playlistHistory: [],
    nowPlayingPlaylist: false,
    renderQueue() {},
    updateControls() {},
    playTrack: (track) => { played.push(track.id); return true; },
  });
  vm.runInContext(source.slice(source.indexOf('  async function playPlaylist('), source.indexOf('  async function finishFadedSkip(')), context);

  const favList = [{ id: 'doggy-and-magic', title: 'Doggy and Magic' }, { id: 'fav-2', title: 'Fav 2' }];
  const target = { id: 'target-track', title: 'Target Track' };

  const ok = await context.playPlaylist(favList, { startTrackId: 'target-track', startTrack: target });
  assert.equal(ok, true);
  assert.deepEqual(played, ['target-track']);
  assert.equal(context.queue.length, 0);

  played.length = 0;
  const missingResult = await context.playPlaylist(favList, { startTrackId: 'unknown-track' });
  assert.equal(missingResult, false);
  assert.deepEqual(played, []);
});

test('ended listener completes pending faded skip to targetTrack instead of skipping past it', async () => {
  const finished = [];
  const audioListeners = {};
  const req = { playbackId: 'pb-1', targetTrack: { id: 'lib-target', title: 'Target' }, targetOptions: {} };
  const context = vm.createContext({
    queuedSkipRequest: req,
    audio: {
      src: 'blob:prev',
      ended: true,
      addEventListener(eventName, handler) {
        audioListeners[eventName] = handler;
      },
    },
    effectiveDuration: () => 0,
    sourcePositionSeconds: () => 10,
    clearFadedSkip() { context.queuedSkipRequest = null; },
    finishFadedSkip(request, opts) { finished.push({ request, opts }); },
    moveTrackNow(step) { throw new Error(`Should not call moveTrackNow(${step}) during queued skip`); },
  });
  const moveBlock = source.slice(
    source.indexOf('  async function moveTrack('),
    source.indexOf('  async function moveTrackNow('),
  );
  const endedBlock = source.slice(
    source.indexOf('  audio.addEventListener("ended",'),
    source.indexOf('  audio.addEventListener("error",'),
  );
  vm.runInContext(`${moveBlock}\n${endedBlock}`, context);
  await audioListeners.ended();
  assert.equal(finished.length, 1);
  assert.equal(finished[0].request, req);
  assert.equal(finished[0].opts.step, undefined);
});

test('startAudioPlayback resolves immediately when audioContext.resume hangs in WebKit', async () => {
  const pendingResume = new Promise(() => {});
  const { context, calls } = fixture({
    audioContext: { state: 'suspended', resume: () => pendingResume },
  });
  const ok = await context.startAudioPlayback();
  assert.equal(ok, true);
  assert.deepEqual(calls, ['play']);
});

test('iPhone/ManagedMediaSource falls back to server ?eq= and restarts stream across preset changes', async () => {
  const clientGraphStart = source.indexOf('  function supportsClientAudioGraph()');
  const clientGraphEnd = source.indexOf('  function updateEqualizerGraph()');
  const audioUrlBlock = source.slice(source.indexOf('  function audioURL('), source.indexOf('  function nativeFormatPlaybackRate('));
  const iosContext = vm.createContext({
    URLSearchParams,
    dock: { dataset: { audioUrl: '/audio/spcboy/TRACK_ID/', pageLoadToken: 'tok' } },
    currentPlaybackId: 'pb1',
    playbackSpeedEnabled: false,
    playbackRateFraction: '1/1',
    spcFadeSeconds: 5,
    longPlayEnabled: false,
    longPlaySeconds: 180,
    equalizerEnabled: true,
    equalizerBandGains: [6, 0, 0, 0, 0, 0, 0, 0, 0, -3],
    volumeStep: 10,
    equalizerGraphFailed: false,
    AudioContextClass: function AudioContextMock() {},
    window: { ManagedMediaSource: function ManagedMediaSourceMock() {} },
    navigator: { userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X)' },
    document: {},
    testAudioVolumeSupport: () => false,
  });
  vm.runInContext(`${source.slice(clientGraphStart, clientGraphEnd)}\n${audioUrlBlock}`, iosContext);
  assert.equal(iosContext.supportsClientAudioGraph(), false);
  const iosUrl = iosContext.audioURL({ id: 'guile' }, 0);
  assert.equal(iosUrl.includes('eq=6.0'), true);
  assert.equal(iosUrl.includes('volume=10'), true);

  let restarts = 0;
  const presetContext = vm.createContext({
    equalizerPresetApplyButtons: [],
    equalizerPresetSaveButtons: [],
    equalizerPresets: [
      { name: 'Preset 1', gains: Array(10).fill(3) },
      { name: 'Preset 2', gains: Array(10).fill(-2) },
      null,
    ],
    equalizerBandGains: Array(10).fill(3),
    equalizerFrequencies: Array(10).fill(100),
    equalizerEnabled: true,
    selectedEqualizerPresetIndex: 0,
    currentTrack: { id: 'guile' },
    equalizerPresetStatus: { textContent: '' },
    storage: { set() {} },
    saveEqualizerGains() {},
    updateEqualizerGraph() {},
    ensureEqualizerGraph: () => false,
    sourcePositionSeconds: () => 42,
    restartCurrentStream(pos) { restarts += 1; assert.equal(pos, 42); },
    syncEqualizerPresetControls() {},
    setEqualizerEnabled: async () => true,
  });
  const applyStart = source.indexOf('  async function applyEqualizerPreset');
  vm.runInContext(source.slice(applyStart, source.indexOf('  queueToggle.addEventListener(')), presetContext);
  await presetContext.applyEqualizerPreset(1);
  assert.equal(restarts, 1);
  assert.deepEqual(Array.from(presetContext.equalizerBandGains), Array(10).fill(-2));
});

test('Clean stream EOF advances to next track even for Infinite Long Play or early-ending VGM/GME tracks', async () => {
  const { context, calls } = fixture({
    streamOffsetSeconds: 0,
    effectiveDuration: () => Infinity,
    aacTransport: { supported: true, streamEnded: true },
    hasReachedStreamQuota: async () => { throw new Error('Should not check quota on clean stream EOF'); },
    moveTrack: (step) => calls.push(['next', step]),
  });
  Object.assign(context.audio, { ended: true, currentTime: 42, addEventListener: (_, handler) => { context.onEnded = handler; } });
  vm.runInContext(ended, context);
  await context.onEnded();
  assert.deepEqual(calls, [['next', 1]]);

  const aacStreamSource = readFileSync(`${__dirname}/../static/accounts/aac-stream.js`, 'utf8');
  assert.match(aacStreamSource, /if\s*\(!run\.ended\)\s*report\(new Error\('AAC source closed'\)\);/);
  assert.match(aacStreamSource, /get streamEnded\(\)\s*\{\s*return Boolean\(active\?\.ended\);\s*\}/);
});
