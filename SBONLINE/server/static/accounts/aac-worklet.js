/* AudioWorklet ring-buffer processor for streaming decoded PCM with zero-GC process(). */
class SBOPcmRingProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.capacity = 44100 * 24;
    this.ringL = new Float32Array(this.capacity);
    this.ringR = new Float32Array(this.capacity);
    this.readIdx = 0;
    this.writeIdx = 0;
    this.available = 0;
    this.sourceRate = 44100;
    this.phase = 0;
    this.paused = true;
    this.eos = false;
    this.generation = 0;
    this.playedSourceFrames = 0;
    this.lastProgressAt = 0;
    this.port.onmessage = (event) => this.handleMessage(event.data);
  }

  handleMessage(msg) {
    if (!msg || typeof msg !== "object") return;
    if (msg.type === "clear") {
      this.generation = Number(msg.generation) || 0;
      this.readIdx = 0;
      this.writeIdx = 0;
      this.available = 0;
      this.phase = 0;
      this.playedSourceFrames = 0;
      this.lastProgressAt = 0;
      this.eos = false;
      this.paused = msg.paused !== undefined ? Boolean(msg.paused) : true;
      return;
    }
    if (msg.generation !== undefined && msg.generation !== this.generation) return;
    if (msg.type === "pause") {
      this.paused = Boolean(msg.paused);
      return;
    }
    if (msg.type === "eos") {
      this.eos = true;
      if (this.available === 0 && !this.paused) {
        this.emitEnded();
      }
      return;
    }
    if (msg.type === "frames") {
      const left = msg.left;
      const right = msg.right || msg.left;
      if (!left || !left.length) return;
      if (msg.sampleRate && Number.isFinite(msg.sampleRate) && msg.sampleRate > 0) {
        this.sourceRate = msg.sampleRate;
      }
      const incoming = Math.min(left.length, this.capacity - this.available);
      if (incoming <= 0) return;
      const first = Math.min(incoming, this.capacity - this.writeIdx);
      this.ringL.set(left.subarray(0, first), this.writeIdx);
      this.ringR.set(right.subarray(0, first), this.writeIdx);
      if (incoming > first) {
        const rest = incoming - first;
        this.ringL.set(left.subarray(first, incoming), 0);
        this.ringR.set(right.subarray(first, incoming), 0);
      }
      this.writeIdx = (this.writeIdx + incoming) % this.capacity;
      this.available += incoming;
    }
  }

  emitEnded() {
    this.eos = false;
    this.paused = true;
    this.port.postMessage({
      type: "ended",
      generation: this.generation,
      currentTime: this.playedSourceFrames / this.sourceRate,
    });
  }

  process(_inputs, outputs) {
    const out = outputs[0];
    if (!out || !out.length) return true;
    const outL = out[0];
    const outR = out[1] || out[0];
    const len = outL.length;

    if (this.paused || this.available === 0) {
      outL.fill(0);
      if (outR !== outL) outR.fill(0);
      if (this.eos && !this.paused && this.available === 0) {
        this.emitEnded();
      }
      return true;
    }

    if (this.sourceRate === sampleRate) {
      const toRead = Math.min(len, this.available);
      const first = Math.min(toRead, this.capacity - this.readIdx);
      outL.set(this.ringL.subarray(this.readIdx, this.readIdx + first), 0);
      if (outR !== outL) outR.set(this.ringR.subarray(this.readIdx, this.readIdx + first), 0);
      if (toRead > first) {
        const rest = toRead - first;
        outL.set(this.ringL.subarray(0, rest), first);
        if (outR !== outL) outR.set(this.ringR.subarray(0, rest), first);
      }
      if (toRead < len) {
        outL.fill(0, toRead);
        if (outR !== outL) outR.fill(0, toRead);
      }
      this.readIdx = (this.readIdx + toRead) % this.capacity;
      this.available -= toRead;
      this.playedSourceFrames += toRead;
    } else {
      const step = this.sourceRate / sampleRate;
      let i = 0;
      for (; i < len && this.available > 1; i += 1) {
        const idx0 = this.readIdx;
        const idx1 = (idx0 + 1) % this.capacity;
        const frac = this.phase;
        const l = this.ringL[idx0] + (this.ringL[idx1] - this.ringL[idx0]) * frac;
        const r = this.ringR[idx0] + (this.ringR[idx1] - this.ringR[idx0]) * frac;
        outL[i] = l;
        if (outR !== outL) outR[i] = r;
        this.phase += step;
        const advance = Math.floor(this.phase);
        if (advance > 0) {
          this.phase -= advance;
          const consumed = Math.min(advance, this.available);
          this.readIdx = (this.readIdx + consumed) % this.capacity;
          this.available -= consumed;
          this.playedSourceFrames += consumed;
        }
      }
      if (i < len) {
        outL.fill(0, i);
        if (outR !== outL) outR.fill(0, i);
      }
    }

    if (currentFrame - this.lastProgressAt >= 4096) {
      this.lastProgressAt = currentFrame;
      this.port.postMessage({
        type: "progress",
        generation: this.generation,
        currentTime: this.playedSourceFrames / this.sourceRate,
        bufferedSeconds: this.available / this.sourceRate,
      });
    }

    if (this.eos && this.available === 0) {
      this.emitEnded();
    }
    return true;
  }
}

registerProcessor("sbo-pcm-ring-processor", SBOPcmRingProcessor);
