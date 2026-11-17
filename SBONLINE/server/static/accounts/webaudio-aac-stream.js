/* Streaming WebCodecs AudioDecoder + AudioWorklet engine for ADTS AAC -> Web Audio EQ graph. */
(() => {
  const ADTS_SAMPLE_RATES = [
    96000, 88200, 64000, 48000, 44100, 32000,
    24000, 22050, 16000, 12000, 11025, 8000, 7350,
  ];
  const workletUrl = typeof document !== "undefined" && document.currentScript?.src
    ? new URL("./aac-worklet.js?v=20261117-eq-worklet-1", document.currentScript.src).href
    : "/static/accounts/aac-worklet.js?v=20261117-eq-worklet-1";

  function parseAdtsHeader(bytes, offset = 0) {
    if (!bytes || offset + 7 > bytes.length) return null;
    if (bytes[offset] !== 0xFF || (bytes[offset + 1] & 0xF6) !== 0xF0) return null;
    const headerLength = (bytes[offset + 1] & 1) ? 7 : 9;
    const frameLength =
      ((bytes[offset + 3] & 0x03) << 11)
      | (bytes[offset + 4] << 3)
      | (bytes[offset + 5] >> 5);
    if (frameLength < headerLength) return null;
    const profile = ((bytes[offset + 2] & 0xC0) >> 6) + 1;
    const freqIndex = (bytes[offset + 2] & 0x3C) >> 2;
    const sampleRate = ADTS_SAMPLE_RATES[freqIndex] || 44100;
    const channels = ((bytes[offset + 2] & 0x01) << 2) | ((bytes[offset + 3] & 0xC0) >> 6) || 2;
    return { headerLength, frameLength, profile, freqIndex, sampleRate, channels };
  }

  function buildAudioSpecificConfig(profile, freqIndex, channels) {
    const aot = profile || 2;
    const byte1 = ((aot & 0x1F) << 3) | ((freqIndex & 0x0E) >> 1);
    const byte2 = ((freqIndex & 0x01) << 7) | ((channels & 0x0F) << 3);
    return new Uint8Array([byte1, byte2]);
  }

  function extractStereoPlanar(audioData) {
    const frames = audioData.numberOfFrames;
    const channels = Math.max(1, audioData.numberOfChannels);
    const left = new Float32Array(frames);
    let right;
    const fmt = audioData.format || "";
    if (fmt === "f32-planar") {
      audioData.copyTo(left, { planeIndex: 0 });
      right = new Float32Array(frames);
      audioData.copyTo(right, { planeIndex: channels > 1 ? 1 : 0 });
      return { left, right };
    }
    try {
      audioData.copyTo(left, { planeIndex: 0, format: "f32-planar" });
      right = new Float32Array(frames);
      audioData.copyTo(right, { planeIndex: channels > 1 ? 1 : 0, format: "f32-planar" });
      return { left, right };
    } catch {
      const interleaved = new Float32Array(frames * channels);
      if (fmt === "s16") {
        const s16 = new Int16Array(frames * channels);
        audioData.copyTo(s16, { planeIndex: 0 });
        for (let i = 0; i < s16.length; i += 1) interleaved[i] = s16[i] / 32768;
      } else {
        audioData.copyTo(interleaved, { planeIndex: 0 });
      }
      right = new Float32Array(frames);
      for (let i = 0; i < frames; i += 1) {
        left[i] = interleaved[i * channels];
        right[i] = channels > 1 ? interleaved[i * channels + 1] : left[i];
      }
      return { left, right };
    }
  }

  function supported() {
    return typeof window !== "undefined"
      && typeof window.AudioDecoder === "function"
      && typeof window.EncodedAudioChunk === "function"
      && typeof window.AudioWorkletNode === "function";
  }

  function attach(audio, failed, timing, options = {}) {
    let active = null;
    let generation = 0;
    let workletNode = null;
    let workletContext = null;
    let workletLoadPromise = null;
    let workletTarget = null;
    let currentTime = 0;
    let bufferedSeconds = 0;
    let paused = true;
    let ended = false;
    let errorState = null;
    let lastWaiting = false;

    function dispatchAudioEvent(type) {
      try {
        audio?.dispatchEvent?.(new Event(type));
      } catch { /* Non-DOM test contexts may omit Event constructor. */ }
    }

    async function ensureWorkletNode() {
      options.ensureGraph?.();
      const ctx = options.getAudioContext?.();
      const target = options.getFilterInput?.();
      if (!ctx || !target) throw new Error("Web Audio filter chain is not ready.");
      if (workletNode && workletContext === ctx) {
        if (workletTarget !== target) {
          try { workletNode.disconnect(); } catch {}
          workletNode.connect(target);
          workletTarget = target;
        }
        return { ctx, node: workletNode };
      }
      if (workletContext !== ctx) {
        workletContext = ctx;
        workletNode = null;
        workletLoadPromise = ctx.audioWorklet.addModule(workletUrl);
      }
      await workletLoadPromise;
      if (!workletNode) {
        workletNode = new window.AudioWorkletNode(ctx, "sbo-pcm-ring-processor", {
          numberOfInputs: 0,
          numberOfOutputs: 1,
          outputChannelCount: [2],
        });
        workletNode.connect(target);
        workletTarget = target;
        workletNode.port.onmessage = (event) => {
          const msg = event.data;
          if (!msg || !active || msg.generation !== active.gen) return;
          if (msg.type === "progress") {
            currentTime = msg.currentTime;
            bufferedSeconds = msg.bufferedSeconds;
            dispatchAudioEvent("timeupdate");
          } else if (msg.type === "ended") {
            currentTime = msg.currentTime;
            bufferedSeconds = 0;
            paused = true;
            ended = true;
            active.ended = true;
            dispatchAudioEvent("ended");
          }
        };
      }
      return { ctx, node: workletNode };
    }

    function cancel() {
      if (!active) return;
      active.abort.abort();
      clearTimeout(active.timer);
      try {
        if (active.decoder && active.decoder.state !== "closed") active.decoder.close();
      } catch {}
      generation += 1;
      workletNode?.port.postMessage({ type: "clear", generation });
      active = null;
      bufferedSeconds = 0;
      currentTime = 0;
      paused = true;
      ended = false;
      lastWaiting = false;
    }

    function pause() {
      paused = true;
      workletNode?.port.postMessage({ type: "pause", generation: active?.gen ?? generation, paused: true });
      dispatchAudioEvent("pause");
    }

    async function play() {
      if (!active) return false;
      ended = false;
      paused = false;
      errorState = null;
      if (workletContext && workletContext.state !== "running") {
        workletContext.resume().catch(() => {});
      }
      const { ctx, node } = await ensureWorkletNode();
      if (!active || paused) return false;
      if (ctx.state !== "running") {
        ctx.resume().catch(() => {});
      }
      node.port.postMessage({ type: "pause", generation: active.gen, paused: false });
      if (active.sentFirstFrames) {
        dispatchAudioEvent("playing");
      }
      return true;
    }

    function load(url) {
      cancel();
      const abort = new AbortController();
      const gen = generation;
      const run = active = { abort, gen, timer: null, decoder: null, ended: false, url, sentFirstFrames: false };
      errorState = null;
      ended = false;
      currentTime = 0;
      bufferedSeconds = 0;
      dispatchAudioEvent("loadstart");

      const report = (error) => {
        if (active !== run || abort.signal.aborted) return;
        abort.abort();
        clearTimeout(run.timer);
        errorState = error;
        try {
          if (run.decoder && run.decoder.state !== "closed") run.decoder.close();
        } catch {}
        failed(error);
      };

      async function networkRead(action) {
        let timer;
        try {
          return await Promise.race([
            action(),
            new Promise((_, reject) => {
              timer = setTimeout(() => reject(new Error("AAC network timed out")), 45000);
            }),
          ]);
        } finally {
          clearTimeout(timer);
        }
      }

      (async () => {
        try {
          const { node } = await ensureWorkletNode();
          node.port.postMessage({ type: "clear", generation: gen, paused: Boolean(paused) });

          const response = await networkRead(() => fetch(url, { credentials: "same-origin", cache: "no-store", signal: abort.signal }));
          if (!response.ok || !response.headers.get("content-type")?.startsWith("audio/aac")) {
            const error = new Error(`AAC response ${response.status}`);
            error.status = response.redirected ? 401 : response.status;
            throw error;
          }
          timing?.(Number(response.headers.get("X-Audio-Duration")));

          let decoder = null;
          let stripAdtsHeader = false;
          let retriedRawAac = false;
          let firstHeader = null;
          let timestampUs = 0;
          let pending = new Uint8Array(0);
          let hasOutput = false;
          let initialPackets = [];

          const openDecoder = (config) => {
            const dec = new window.AudioDecoder({
              output: (audioData) => {
                if (active !== run || abort.signal.aborted) {
                  audioData.close();
                  return;
                }
                hasOutput = true;
                initialPackets = [];
                const { left, right } = extractStereoPlanar(audioData);
                const sr = audioData.sampleRate || 44100;
                audioData.close();
                bufferedSeconds += left.length / sr;
                node.port.postMessage(
                  { type: "frames", generation: gen, left, right, sampleRate: sr },
                  [left.buffer, right.buffer],
                );
                if (!run.sentFirstFrames) {
                  run.sentFirstFrames = true;
                  dispatchAudioEvent("canplay");
                  if (!paused) dispatchAudioEvent("playing");
                }
              },
              error: (err) => {
                if (active !== run || abort.signal.aborted) return;
                if (!hasOutput && !retriedRawAac && firstHeader) {
                  retriedRawAac = true;
                  stripAdtsHeader = true;
                  try { if (dec.state !== "closed") dec.close(); } catch {}
                  const rawConfig = {
                    codec: "mp4a.40.2",
                    sampleRate: firstHeader.sampleRate,
                    numberOfChannels: firstHeader.channels,
                    description: buildAudioSpecificConfig(
                      firstHeader.profile,
                      firstHeader.freqIndex,
                      firstHeader.channels,
                    ),
                  };
                  const fallbackDec = openDecoder(rawConfig);
                  decoder = fallbackDec;
                  run.decoder = fallbackDec;
                  for (const pkt of initialPackets) {
                    fallbackDec.decode(new window.EncodedAudioChunk({
                      type: "key",
                      timestamp: pkt.timestampUs,
                      duration: pkt.durationUs,
                      data: pkt.rawPayload,
                    }));
                  }
                  return;
                }
                report(err instanceof Error ? err : new Error("AAC WebCodecs decode failed"));
              },
            });
            dec.configure(config);
            return dec;
          };

          const startDecoder = async (header) => {
            firstHeader = header;
            const adtsConfig = {
              codec: "mp4a.40.2",
              sampleRate: header.sampleRate,
              numberOfChannels: header.channels,
            };
            const adtsSupport = await window.AudioDecoder.isConfigSupported(adtsConfig);
            let config = adtsConfig;
            stripAdtsHeader = false;
            if (!adtsSupport.supported) {
              retriedRawAac = true;
              config = {
                ...adtsConfig,
                description: buildAudioSpecificConfig(header.profile, header.freqIndex, header.channels),
              };
              const rawSupport = await window.AudioDecoder.isConfigSupported(config);
              if (!rawSupport.supported) {
                throw new Error("AudioDecoder AAC-LC configuration is unsupported.");
              }
              stripAdtsHeader = true;
            }
            const dec = openDecoder(config);
            decoder = dec;
            run.decoder = dec;
          };

          const reader = response.body.getReader();
          while (!abort.signal.aborted) {
            while (!abort.signal.aborted && (bufferedSeconds > 12 || (decoder && decoder.decodeQueueSize > 32))) {
              if (!lastWaiting && paused === false && bufferedSeconds < 0.05) {
                lastWaiting = true;
                dispatchAudioEvent("waiting");
              }
              await new Promise((resolve) => setTimeout(resolve, 120));
            }
            if (abort.signal.aborted) break;

            const { value, done } = await networkRead(() => reader.read());
            if (value && value.byteLength) {
              const combined = new Uint8Array(pending.length + value.byteLength);
              combined.set(pending, 0);
              combined.set(value, pending.length);
              pending = combined;
            }

            let offset = 0;
            while (!abort.signal.aborted && offset + 7 <= pending.length) {
              if (pending[offset] !== 0xFF || (pending[offset + 1] & 0xF6) !== 0xF0) {
                offset += 1;
                continue;
              }
              const header = parseAdtsHeader(pending, offset);
              if (!header) {
                offset += 1;
                continue;
              }
              if (offset + header.frameLength > pending.length) break;
              if (!decoder) {
                await startDecoder(header);
                if (abort.signal.aborted) break;
              }
              const rawPayload = pending.slice(offset + header.headerLength, offset + header.frameLength);
              const fullFrame = pending.slice(offset, offset + header.frameLength);
              const chunkBytes = stripAdtsHeader ? rawPayload : fullFrame;
              const durationUs = Math.round((1024 / header.sampleRate) * 1_000_000);
              if (!hasOutput && initialPackets.length < 32) {
                initialPackets.push({ timestampUs, durationUs, rawPayload });
              }
              decoder.decode(new window.EncodedAudioChunk({
                type: "key",
                timestamp: timestampUs,
                duration: durationUs,
                data: chunkBytes,
              }));
              timestampUs += durationUs;
              offset += header.frameLength;
            }
            if (offset > 0) {
              pending = pending.subarray(offset);
            }

            if (done) {
              if (decoder && decoder.state === "configured") {
                await decoder.flush();
                if (decoder.state !== "closed") decoder.close();
              }
              if (active === run && !abort.signal.aborted) {
                node.port.postMessage({ type: "eos", generation: gen });
              }
              break;
            }
          }
        } catch (error) {
          report(error);
        }
      })();
    }

    return {
      isWebAudio: true,
      supported: supported(),
      load,
      play,
      pause,
      cancel,
      get currentTime() { return currentTime; },
      get paused() { return paused; },
      get ended() { return ended; },
      get streamEnded() { return Boolean(active?.ended || ended); },
      get error() { return errorState; },
      get interrupted() {
        return Boolean(active && active.abort.signal.aborted && !active.ended);
      },
      get src() { return active?.url || ""; },
      get url() { return active?.url || ""; },
    };
  }

  window.SBWebAudioAACStream = {
    supported,
    attach,
    parseAdtsHeader,
    buildAudioSpecificConfig,
  };
})();
