(() => {
  "use strict";
  const canvas = document.getElementById("deck-spectrum-canvas");
  if (!canvas) return;
  const context = canvas.getContext("2d", { alpha: true });
  if (!context) return;
  const width = canvas.width;
  const height = canvas.height;
  const levels = { left: Array(10).fill(0), right: Array(10).fill(0) };
  const peaks = { left: Array(10).fill(0), right: Array(10).fill(0) };
  const holds = { left: Array(10).fill(0), right: Array(10).fill(0) };
  let timer = 0;
  let pending = false;
  const tones = ["#d2dd91", "#a9bc73", "#627c55", "#263e38"];

  function heightFor(amplitude) {
    if (!Number.isFinite(amplitude) || amplitude <= 0.002) return 0;
    return Math.max(0, Math.min(10, Math.round((20 * Math.log10(amplitude) + 55) / 5.5)));
  }

  function draw() {
    context.clearRect(0, 0, width, height);
    context.fillStyle = tones[1];
    context.fillRect(0, 28, width, 1);
    for (let band = 0; band < 10; band += 1) {
      const x = 4 + band * 16;
      for (const side of ["left", "right"]) {
        const upper = side === "left";
        for (let step = 0; step < 10; step += 1) {
          const y = upper ? 25 - step * 2.4 : 32 + step * 2.4;
          context.fillStyle = step < levels[side][band] ? tones[3] : tones[1];
          context.fillRect(x, Math.round(y), 11, 1.8);
        }
        if (peaks[side][band] > 0) {
          const y = upper ? 25 - (peaks[side][band] - 1) * 2.4 : 32 + (peaks[side][band] - 1) * 2.4;
          context.fillStyle = tones[2];
          context.fillRect(x, Math.round(y), 11, 1.8);
        }
      }
    }
  }

  async function tick() {
    if (pending || document.hidden) return;
    pending = true;
    try {
      const spectrum = await window.spcBoyWK?.nativePlaybackSpectrum?.();
      for (const side of ["left", "right"]) {
        for (let band = 0; band < 10; band += 1) {
          const next = heightFor(Number(spectrum?.[side]?.[band]));
          levels[side][band] = next >= levels[side][band] ? next : Math.max(next, levels[side][band] - 1);
          if (next >= peaks[side][band]) {
            peaks[side][band] = next;
            holds[side][band] = 3;
          } else if (holds[side][band] > 0) {
            holds[side][band] -= 1;
          } else {
            peaks[side][band] = Math.max(next, peaks[side][band] - 1);
          }
        }
      }
      draw();
    } catch {
      // Static browser previews have no native PCM endpoint.
    } finally {
      pending = false;
    }
  }

  function refresh() {
    const playing = document.querySelector(".player-deck")?.classList.contains("is-playing");
    if (playing && !timer) {
      timer = window.setInterval(tick, 100);
      void tick();
    } else if (!playing && timer) {
      window.clearInterval(timer);
      timer = 0;
      for (const side of ["left", "right"]) {
        levels[side].fill(0);
        peaks[side].fill(0);
      }
      draw();
    }
  }
  new MutationObserver(refresh).observe(document.querySelector(".player-deck"), { attributes: true, attributeFilter: ["class"] });
  draw();
  refresh();
})();
