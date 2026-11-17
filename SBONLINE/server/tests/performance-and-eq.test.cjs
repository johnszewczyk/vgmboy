const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { test } = require('node:test');

const serverDir = `${__dirname}/..`;
const sitePlayerJs = readFileSync(`${serverDir}/static/accounts/site-player.js`, 'utf8');
const spcboyJs = readFileSync(`${serverDir}/static/accounts/spcboy.js`, 'utf8');
const sitePreferencesJs = readFileSync(`${serverDir}/static/accounts/site-preferences.js`, 'utf8');
const webaudioAacStreamJs = readFileSync(`${serverDir}/static/accounts/webaudio-aac-stream.js`, 'utf8');
const aacWorkletJs = readFileSync(`${serverDir}/static/accounts/aac-worklet.js`, 'utf8');

test('desktop EQ toolbar is wired cleanly with gesture support and immediate preset/filter updates', () => {
  assert.match(sitePreferencesJs, /"selectedEqualizerPresetIndex"/);
  assert.match(sitePlayerJs, /'\[data-sbonline-command="equalizer"\]'/);
  assert.match(sitePlayerJs, /'\[data-sbonline-command="volume"\]'/);
  assert.match(sitePlayerJs, /if \(command === "equalizer"\) \{[\s\S]*activePreset\?\.gains[\s\S]*setEqualizerEnabled\(!equalizerEnabled\)/);
  assert.match(sitePlayerJs, /void applyEqualizerPreset\(index\);/);
  assert.match(sitePlayerJs, /if \(equalizerGraphReady && audioContext && audioContext\.state === "suspended"\)/);
});

test('spcboy.js uses lazy console DOM rendering and O(1) album lookup without startup rAF blocking', () => {
  assert.match(spcboyJs, /function ensureConsoleContentRendered\(systemRecord\)/);
  assert.match(spcboyJs, /function setupTrackListDelegation\(\)/);
  assert.match(spcboyJs, /function ensureEntryPlaylistDom\(entry\)/);
  assert.doesNotMatch(spcboyJs, /if \(renderedGames % 32 === 0 && isDesktop\(\)\)/);
  assert.match(spcboyJs, /const entry = selectedAlbumId \? gameGroupsByAlbumId\.get\(selectedAlbumId\) : null;/);
  assert.match(spcboyJs, /const entry = albumId \? gameGroupsByAlbumId\.get\(albumId\) : null;/);
});

function buildAdtsFrame(payloadSize = 8, crcAbsent = true) {
  const headerLength = crcAbsent ? 7 : 9;
  const frameLength = headerLength + payloadSize;
  const frame = new Uint8Array(frameLength);
  // 0xFFF sync + ID=0 (MPEG-4) + layer=00 + protection_absent
  frame[0] = 0xFF;
  frame[1] = crcAbsent ? 0xF1 : 0xF0;
  // profile=1 (AAC-LC -> AOT 2), freqIndex=4 (44100 Hz), chan high bit=0
  frame[2] = (1 << 6) | (4 << 2);
  // chan low 2 bits = 2 (stereo -> 0b10 << 6), frameLength top 2 bits
  frame[3] = (2 << 6) | ((frameLength >> 11) & 0x03);
  frame[4] = (frameLength >> 3) & 0xFF;
  frame[5] = ((frameLength & 0x07) << 5) | 0x1F;
  frame[6] = 0xFC;
  for (let i = headerLength; i < frameLength; i += 1) frame[i] = i & 0xFF;
  return frame;
}

test('SBWebAudioAACStream parses ADTS headers and builds AudioSpecificConfig cleanly', () => {
  const windowObj = { AudioDecoder() {}, EncodedAudioChunk() {}, AudioWorkletNode() {} };
  const ctx = vm.createContext({ window: windowObj, Uint8Array, Array, Math, Number, Boolean, URL, AbortController, AbortSignal, Event, Error, Promise, setTimeout, clearTimeout });
  vm.runInContext(webaudioAacStreamJs, ctx);
  const { parseAdtsHeader, buildAudioSpecificConfig } = ctx.window.SBWebAudioAACStream;

  const adts = buildAdtsFrame(16, true);
  const parsed = parseAdtsHeader(adts, 0);
  assert.deepEqual({ ...parsed }, {
    headerLength: 7,
    frameLength: 23,
    profile: 2,
    freqIndex: 4,
    sampleRate: 44100,
    channels: 2,
  });

  const crcAdts = buildAdtsFrame(10, false);
  assert.equal(parseAdtsHeader(crcAdts, 0).headerLength, 9);
  assert.equal(parseAdtsHeader(new Uint8Array([0, 1, 2, 3, 4, 5, 6, 7]), 0), null);

  const asc = buildAudioSpecificConfig(parsed.profile, parsed.freqIndex, parsed.channels);
  assert.deepEqual(Array.from(asc), [0x12, 0x10]);
});

test('aac-worklet ring processor streams frames, advances time, and emits ended on EOS', () => {
  let registeredName = null;
  let ProcessorClass = null;
  const posted = [];
  const ctx = vm.createContext({
    Float32Array,
    Math,
    Number,
    Boolean,
    currentFrame: 0,
    sampleRate: 44100,
    AudioWorkletProcessor: class AudioWorkletProcessor {
      constructor() {
        this.port = { onmessage: null, postMessage: (msg) => posted.push(msg) };
      }
    },
    registerProcessor(name, cls) {
      registeredName = name;
      ProcessorClass = cls;
    },
  });
  vm.runInContext(aacWorkletJs, ctx);
  assert.equal(registeredName, 'sbo-pcm-ring-processor');

  const proc = new ProcessorClass();
  proc.port.onmessage({ data: { type: 'clear', generation: 1, paused: false } });
  const left = new Float32Array(256).fill(0.5);
  const right = new Float32Array(256).fill(-0.25);
  proc.port.onmessage({ data: { type: 'frames', generation: 1, left, right, sampleRate: 44100 } });
  proc.port.onmessage({ data: { type: 'eos', generation: 1 } });

  const outL = new Float32Array(128);
  const outR = new Float32Array(128);
  ctx.currentFrame = 4096;
  proc.process([], [[outL, outR]]);
  assert.equal(outL[0], 0.5);
  assert.equal(outR[0], -0.25);
  assert.equal(posted.some((m) => m.type === 'progress'), true);

  proc.process([], [[outL, outR]]);
  assert.equal(posted.some((m) => m.type === 'ended'), true);
});

test('SBWebAudioAACStream retries raw AAC with AudioSpecificConfig when containerless ADTS fails decode', async () => {
  const configuredConfigs = [];
  const decodedChunks = [];
  const workletMessages = [];
  const events = [];
  const audioEl = {
    dispatchEvent(ev) { events.push(ev.type); },
  };
  const filterInput = { id: 'filter-0' };
  const fakeWorkletNode = {
    connectTarget: null,
    connect(t) { this.connectTarget = t; },
    disconnect() { this.connectTarget = null; },
    port: {
      onmessage: null,
      postMessage(msg) { workletMessages.push(msg); },
    },
  };
  const fakeCtx = {
    state: 'running',
    resume: async () => {},
    audioWorklet: { addModule: async () => {} },
  };

  class FakeAudioDecoder {
    constructor({ output, error }) {
      this._output = output;
      this._error = error;
      this.state = 'unconfigured';
      this.decodeQueueSize = 0;
    }
    static async isConfigSupported(cfg) {
      return { supported: true, config: cfg };
    }
    configure(cfg) {
      configuredConfigs.push(cfg);
      this.hasDescription = Boolean(cfg.description);
      this.state = 'configured';
    }
    decode(chunk) {
      decodedChunks.push(chunk.data.length);
      if (!this.hasDescription) {
        this._error(new Error('ADTS without description rejected'));
        return;
      }
      const samples = new Float32Array(1024).fill(0.25);
      this._output({
        numberOfFrames: 1024,
        numberOfChannels: 2,
        sampleRate: 44100,
        format: 'f32-planar',
        copyTo(dest) { dest.set(samples); },
        close() {},
      });
    }
    async flush() {}
    close() { this.state = 'closed'; }
  }

  class FakeEncodedAudioChunk {
    constructor(init) { Object.assign(this, init); }
  }

  const adtsFrame = buildAdtsFrame(12, true);
  let readIndex = 0;
  const fakeFetch = async () => ({
    ok: true,
    status: 200,
    redirected: false,
    headers: {
      get: (k) => ({ 'content-type': 'audio/aac', 'X-Audio-Duration': '12.5' }[k] || null),
    },
    body: {
      getReader: () => ({
        async read() {
          if (readIndex === 0) {
            readIndex += 1;
            return { value: adtsFrame, done: false };
          }
          return { value: undefined, done: true };
        },
      }),
    },
  });

  const windowObj = {
    AudioDecoder: FakeAudioDecoder,
    EncodedAudioChunk: FakeEncodedAudioChunk,
    AudioWorkletNode: function AudioWorkletNode() { return fakeWorkletNode; },
  };
  const ctx = vm.createContext({
    window: windowObj,
    fetch: fakeFetch,
    Uint8Array, Float32Array, Int16Array, Array, Math, Number, Boolean, Promise, Error,
    Event: class Event { constructor(type) { this.type = type; } },
    AbortController, URL, setTimeout, clearTimeout,
  });
  vm.runInContext(webaudioAacStreamJs, ctx);

  let reportedDuration = 0;
  const transport = ctx.window.SBWebAudioAACStream.attach(
    audioEl,
    (err) => assert.fail(`Unexpected failure: ${err?.message}`),
    (dur) => { reportedDuration = dur; },
    { ensureGraph: () => true, getAudioContext: () => fakeCtx, getFilterInput: () => filterInput },
  );

  transport.load('/audio/spcboy/test.aac');
  await transport.play();
  await new Promise((r) => setTimeout(r, 30));

  assert.equal(fakeWorkletNode.connectTarget, filterInput);
  assert.equal(configuredConfigs.length, 2);
  assert.equal(Boolean(configuredConfigs[0].description), false);
  assert.deepEqual(Array.from(configuredConfigs[1].description), [0x12, 0x10]);
  assert.deepEqual(decodedChunks, [19, 12]);
  assert.equal(reportedDuration, 12.5);
  assert.equal(workletMessages.some((m) => m.type === 'frames'), true);
  assert.equal(workletMessages.some((m) => m.type === 'eos'), true);
  assert.equal(events.includes('canplay'), true);
  assert.equal(events.includes('playing'), true);
});

test('Safari Desktop routes audio through WebCodecs + AudioWorklet without MSE bypass or stream restart, while older Safari falls back to ?eq=', async () => {
  function bootSafariContext({ withAudioDecoder }) {
    const fetchUrls = [];
    const filterGains = [];
    const createdNodes = [];
    let outputGainNode = null;
    let createMediaElementSourceCalls = 0;

    function makeGainNode() {
      const node = {
        gain: {
          value: 1,
          setTargetAtTime(v) { node.gain.value = v; },
          setValueAtTime(v) { node.gain.value = v; },
          cancelScheduledValues() {},
          linearRampToValueAtTime(v) { node.gain.value = v; },
        },
        connect() {},
        disconnect() {},
      };
      return node;
    }

    class FakeAudioContext {
      constructor(opts) {
        this.opts = opts;
        this.sampleRate = 44100;
        this.currentTime = 0;
        this.state = 'suspended';
        this.destination = { id: 'dest' };
        this.audioWorklet = { addModule: async () => {} };
      }
      resume() {
        this.state = 'running';
        return Promise.resolve();
      }
      createMediaElementSource() {
        createMediaElementSourceCalls += 1;
        throw new Error('Should not createMediaElementSource in Safari WebAudio mode');
      }
      createBiquadFilter() {
        const f = {
          type: 'peaking',
          frequency: { value: 0 },
          Q: { value: 1 },
          gain: {
            value: 0,
            cancelScheduledValues() {},
            setTargetAtTime(v) { f.gain.value = v; },
          },
          connect() {},
        };
        filterGains.push(f.gain);
        return f;
      }
      createGain() {
        const g = makeGainNode();
        createdNodes.push(g);
        if (!outputGainNode) outputGainNode = g;
        return g;
      }
    }

    const audioEl = {
      playbackRate: 1, volume: 1, paused: true, ended: false, error: null, src: '', currentTime: 0,
      listeners: new Map(),
      addEventListener(t, fn) { if (!this.listeners.has(t)) this.listeners.set(t, []); this.listeners.get(t).push(fn); },
      dispatchEvent(ev) { for (const fn of this.listeners.get(ev.type) || []) fn(ev); return true; },
      removeAttribute() {}, load() {}, pause() { this.paused = true; }, play: async () => {},
    };
    const stubEl = () => ({
      hidden: false, disabled: false, textContent: '', innerHTML: '', value: '', checked: false,
      dataset: {}, style: { setProperty() {} }, parentNode: { insertBefore() {} }, nextSibling: null,
      classList: { toggle() {}, add() {}, remove() {}, contains: () => false },
      setAttribute() {}, getAttribute: () => null, removeAttribute() {}, hasAttribute: () => false,
      addEventListener() {}, removeEventListener() {}, dispatchEvent() { return true; },
      append() {}, prepend() {}, remove() {}, replaceChildren() {}, closest: () => null,
      querySelectorAll: () => [], querySelector: () => stubEl(),
      getBoundingClientRect: () => ({ left: 0, width: 100 }), getClientRects: () => [1],
    });
    const fakeWorklet = {
      connectTarget: null,
      connect(target) { this.connectTarget = target; },
      disconnect() {},
      port: { onmessage: null, postMessage() {} },
    };
    const dockEl = Object.assign(stubEl(), {
      dataset: {
        libraryUrl: '/spcboy/', nowPlayingUrl: '/spcboy/now-playing.json',
        favoritesUrl: '/spcboy/favorites.json', audioUrl: '/audio/spcboy/TRACK_ID.aac',
        pageLoadToken: 'tok-1', playbackSessionLimit: '43200',
      },
      contains: () => false,
    });
    const byId = new Map([
      ['site-player', dockEl],
      ['spcboy-audio', audioEl],
      ['site-player-volume', Object.assign(stubEl(), { value: '20' })],
      ['spcboy-volume', Object.assign(stubEl(), { value: '20' })],
    ]);
    const cacheEls = new Map();
    const getStub = (sel) => {
      if (sel.startsWith('#')) {
        const id = sel.slice(1);
        if (byId.has(id)) return byId.get(id);
      }
      if (!cacheEls.has(sel)) cacheEls.set(sel, stubEl());
      return cacheEls.get(sel);
    };
    const docListeners = new Map();
    const winListeners = new Map();
    const unrefTimeout = (fn, ms, ...args) => {
      const h = setTimeout(fn, ms, ...args);
      if (h && typeof h.unref === 'function') h.unref();
      return h;
    };
    const fakeWindow = {
      AudioContext: FakeAudioContext,
      MediaSource: function MediaSource() {},
      SBWebAudioAACStream: null,
      addEventListener(t, fn) { if (!winListeners.has(t)) winListeners.set(t, []); winListeners.get(t).push(fn); },
      dispatchEvent() { return true; },
      matchMedia: () => ({ matches: false, addEventListener() {} }),
      setTimeout: unrefTimeout, clearTimeout, setInterval: () => 0, clearInterval() {},
      requestAnimationFrame: (fn) => unrefTimeout(fn, 0),
    };
    if (withAudioDecoder) {
      fakeWindow.AudioDecoder = class { static async isConfigSupported(c) { return { supported: true, config: c }; } };
      fakeWindow.EncodedAudioChunk = class {};
      fakeWindow.AudioWorkletNode = function () { return fakeWorklet; };
    }
    const sandbox = vm.createContext({
      window: fakeWindow,
      navigator: {
        userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.2 Safari/605.1.15',
        platform: 'MacIntel',
        maxTouchPoints: 0,
        onLine: true,
      },
      document: {
        baseURI: 'https://admin.pre-calc.com/spcboy/',
        body: stubEl(),
        currentScript: null,
        getElementById: (id) => getStub(`#${id}`),
        querySelector: getStub,
        querySelectorAll: () => [],
        createElement: () => stubEl(),
        addEventListener(t, fn) { if (!docListeners.has(t)) docListeners.set(t, []); docListeners.get(t).push(fn); },
        dispatchEvent() { return true; },
      },
      fetch: async (url) => {
        fetchUrls.push(String(url));
        return {
          ok: true,
          status: 200,
          redirected: false,
          headers: { get: (k) => (k === 'content-type' ? 'audio/aac' : null) },
          body: { getReader: () => ({ async read() { await new Promise((r) => setTimeout(r, 80)); return { value: undefined, done: true }; } }) },
        };
      },
      URL, URLSearchParams, CustomEvent: class CustomEvent { constructor(t, d) { this.type = t; this.detail = d?.detail; } },
      Event: class Event { constructor(t) { this.type = t; } },
      AbortController, Uint8Array, Float32Array, Int16Array, Array, Math, Number, Boolean, String, JSON, Date, Promise, Error, Set, Map,
      crypto: { randomUUID: () => 'uuid-1' },
      setTimeout: unrefTimeout, clearTimeout, setInterval: () => 0, clearInterval() {},
    });
    fakeWindow.window = fakeWindow;
    const mseLoadUrls = [];
    fakeWindow.SBAACStream = { attach() { return { supported: true, load(u) { mseLoadUrls.push(String(u)); }, cancel() {} }; } };
    vm.runInContext(webaudioAacStreamJs, sandbox);
    vm.runInContext(sitePlayerJs, sandbox);
    return { sandbox, fetchUrls, mseLoadUrls, filterGains, getOutputGain: () => outputGainNode, getCreateMediaSourceCalls: () => createMediaElementSourceCalls, fakeWorklet };
  }

  // Modern Safari Desktop (AudioDecoder + AudioWorklet available)
  const modern = bootSafariContext({ withAudioDecoder: true });
  const player = modern.sandbox.window.SitePlayer;
  await player.play({ id: 'chrono-1', title: 'Chrono', game: 'Chrono Trigger', durationSeconds: 60 });
  await new Promise((r) => setTimeout(r, 30));

  assert.equal(modern.getCreateMediaSourceCalls(), 0);
  assert.equal(modern.fetchUrls.length, 1);
  assert.equal(modern.fetchUrls[0].includes('eq='), false);
  assert.equal(modern.fetchUrls[0].includes('volume='), false);
  assert.ok(modern.fakeWorklet.connectTarget);

  await player.setEqualizerEnabled(true);
  player.setEqualizerBandGain(2, 7.5);
  player.setVolume(10);
  assert.equal(modern.filterGains[2].value, 7.5);
  assert.equal(modern.getOutputGain().gain.value, 0.5);
  assert.equal(modern.fetchUrls.length, 1, 'EQ/volume changes must not restart the active Safari stream');

  // Older Safari Desktop (no AudioDecoder -> fallback to server ?eq=)
  const legacy = bootSafariContext({ withAudioDecoder: false });
  const legacyPlayer = legacy.sandbox.window.SitePlayer;
  legacyPlayer.setEqualizerBandGain(0, 6);
  await legacyPlayer.setEqualizerEnabled(true);
  await legacyPlayer.play({ id: 'chrono-1', title: 'Chrono', game: 'Chrono Trigger', durationSeconds: 60 });
  assert.equal(legacy.mseLoadUrls.length, 1);
  assert.equal(legacy.mseLoadUrls[0].includes('eq='), true);
  // Triggered server URL query instead of broken MediaElementAudioSourceNode
  assert.equal(legacy.getCreateMediaSourceCalls(), 0);
});
