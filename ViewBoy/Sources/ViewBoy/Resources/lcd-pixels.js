/* A small, fixed LCD alphabet. Each row is five on/off cells; WebKit keeps the
   original text underneath the canvas for accessibility and Unicode fallback. */
(() => {
  "use strict";

  const GLYPHS = Object.freeze({
    " ": [0, 0, 0, 0, 0, 0, 0],
    A: [14, 17, 17, 31, 17, 17, 17], B: [30, 17, 17, 30, 17, 17, 30],
    C: [14, 17, 16, 16, 16, 17, 14], D: [30, 17, 17, 17, 17, 17, 30],
    E: [31, 16, 16, 30, 16, 16, 31], F: [31, 16, 16, 30, 16, 16, 16],
    G: [14, 17, 16, 23, 17, 17, 14], H: [17, 17, 17, 31, 17, 17, 17],
    I: [14, 4, 4, 4, 4, 4, 14], J: [7, 2, 2, 2, 18, 18, 12],
    K: [17, 18, 20, 24, 20, 18, 17], L: [16, 16, 16, 16, 16, 16, 31],
    M: [17, 27, 21, 21, 17, 17, 17], N: [17, 25, 21, 19, 17, 17, 17],
    O: [14, 17, 17, 17, 17, 17, 14], P: [30, 17, 17, 30, 16, 16, 16],
    Q: [14, 17, 17, 17, 21, 18, 13], R: [30, 17, 17, 30, 20, 18, 17],
    S: [15, 16, 16, 14, 1, 1, 30], T: [31, 4, 4, 4, 4, 4, 4],
    U: [17, 17, 17, 17, 17, 17, 14], V: [17, 17, 17, 17, 17, 10, 4],
    W: [17, 17, 17, 21, 21, 21, 10], X: [17, 17, 10, 4, 10, 17, 17],
    Y: [17, 17, 10, 4, 4, 4, 4], Z: [31, 1, 2, 4, 8, 16, 31],
    0: [14, 17, 19, 21, 25, 17, 14], 1: [4, 12, 4, 4, 4, 4, 14],
    2: [14, 17, 1, 2, 4, 8, 31], 3: [30, 1, 1, 14, 1, 1, 30],
    4: [2, 6, 10, 18, 31, 2, 2], 5: [31, 16, 16, 30, 1, 1, 30],
    6: [14, 16, 16, 30, 17, 17, 14], 7: [31, 1, 2, 4, 8, 8, 8],
    8: [14, 17, 17, 14, 17, 17, 14], 9: [14, 17, 17, 15, 1, 1, 14],
    ".": [0, 0, 0, 0, 0, 12, 12], ",": [0, 0, 0, 0, 4, 4, 8],
    ":": [0, 4, 4, 0, 4, 4, 0], ";": [0, 4, 4, 0, 4, 4, 8],
    "-": [0, 0, 0, 31, 0, 0, 0], "_": [0, 0, 0, 0, 0, 0, 31],
    "/": [1, 1, 2, 4, 8, 16, 16], "\\": [16, 16, 8, 4, 2, 1, 1],
    "'": [4, 4, 8, 0, 0, 0, 0], '"': [10, 10, 0, 0, 0, 0, 0],
    "(": [2, 4, 8, 8, 8, 4, 2], ")": [8, 4, 2, 2, 2, 4, 8],
    "[": [14, 8, 8, 8, 8, 8, 14], "]": [14, 2, 2, 2, 2, 2, 14],
    "!": [4, 4, 4, 4, 4, 0, 4], "?": [14, 17, 1, 2, 4, 0, 4],
    "+": [0, 4, 4, 31, 4, 4, 0], "=": [0, 0, 31, 0, 31, 0, 0],
    "&": [12, 18, 20, 8, 21, 18, 13], "#": [10, 10, 31, 10, 31, 10, 10],
    "%": [25, 25, 2, 4, 8, 19, 19], "*": [0, 21, 14, 31, 14, 21, 0],
    "·": [0, 0, 0, 4, 0, 0, 0], "∞": [0, 0, 10, 21, 21, 10, 0]
  });

  function translatedCells(text) {
    const visual = String(text).toUpperCase()
      .replace(/[‘’]/g, "'")
      .replace(/[–—]/g, "-")
      .replace(/…/g, "...");
    const cells = Array.from(visual);
    return cells.every((character) => Object.hasOwn(GLYPHS, character)) ? cells : null;
  }

  if (typeof module !== "undefined" && module.exports) {
    module.exports = { translatedCells, GLYPHS };
  }
  if (typeof document === "undefined") return;

  const selectors = [
    ".deck-brand-name", ".deck-brand-divider", "#deck-state", "#deck-index",
    "#deck-title", "#deck-meta", ".deck-time-row > span",
    "#elapsed-label", "#song-length-label", "#playlist-total-label",
    ".deck-time-row .time-separator"
  ];
  const entries = selectors.flatMap((selector) =>
    Array.from(document.querySelectorAll(selector), (element) => {
      const canvas = document.createElement("canvas");
      canvas.className = "lcd-pixel-canvas";
      canvas.setAttribute("aria-hidden", "true");
      return { element, canvas, isBlock: element.id === "deck-title" || element.id === "deck-meta" };
    }));
  if (!entries.length) return;

  const screen = document.querySelector(".deck-screen");
  const queued = new Set();
  let frame = 0;

  function queue(entry) {
    queued.add(entry);
    if (!frame) frame = requestAnimationFrame(() => {
      frame = 0;
      for (const item of queued) draw(item);
      queued.clear();
    });
  }

  function pitch() {
    const rootSize = parseFloat(getComputedStyle(document.documentElement).fontSize) || 15;
    return Math.max(2, Math.min(3, Math.round(rootSize / 7.5)));
  }

  function draw(entry) {
    const { element, canvas, isBlock } = entry;
    const text = element.textContent || "";
    const cells = translatedCells(text);
    if (!cells) {
      element.classList.remove("lcd-pixels-active");
      element.style.removeProperty("width");
      canvas.remove();
      return;
    }

    const baseSize = pitch();
    const cellSize = element.id === "deck-title" ? Math.min(3.5, baseSize + 0.5) : baseSize;
    if (screen?.style.getPropertyValue("--lcd-cell-pitch") !== `${baseSize}px`) {
      screen?.style.setProperty("--lcd-cell-pitch", `${baseSize}px`);
    }
    element.style.setProperty("--lcd-cell-pitch", `${cellSize}px`);
    if (!isBlock) element.style.width = `${Math.max(1, cells.length) * cellSize * 6}px`;
    element.classList.add("lcd-pixels-active");
    if (canvas.parentElement !== element) element.append(canvas);
    const bounds = element.getBoundingClientRect();
    if (!bounds.width || !bounds.height) return;
    const ratio = window.devicePixelRatio || 1;
    canvas.width = Math.max(1, Math.ceil(bounds.width * ratio));
    canvas.height = Math.max(1, Math.ceil(bounds.height * ratio));
    const context = canvas.getContext("2d", { alpha: true });
    if (!context) return;
    context.setTransform(ratio, 0, 0, ratio, 0, 0);
    context.clearRect(0, 0, bounds.width, bounds.height);
    const ink = getComputedStyle(element).getPropertyValue("--lcd-pixel-ink").trim() || "#293429";
    const y = Math.max(0, Math.floor((bounds.height - 7 * cellSize) / 2));
    const maxChars = Math.floor(bounds.width / (6 * cellSize));
    const shown = cells.length > maxChars && maxChars > 3
      ? [...cells.slice(0, maxChars - 3), ".", ".", "."]
      : cells.slice(0, maxChars);
    context.fillStyle = ink;
    context.shadowColor = "rgba(22, 39, 28, 0.36)";
    context.shadowBlur = 0.7;
    context.shadowOffsetX = 0.35;
    context.shadowOffsetY = 0.65;
    for (let index = 0; index < shown.length; index += 1) {
      const rows = GLYPHS[shown[index]];
      for (let row = 0; row < 7; row += 1) {
        for (let column = 0; column < 5; column += 1) {
          if (rows[row] & (1 << (4 - column))) {
            const dotSize = cellSize === 2 ? 2 : cellSize - 0.5;
            context.fillRect((index * 6 + column) * cellSize,
              y + row * cellSize, dotSize, dotSize);
          }
        }
      }
    }
  }

  const mutations = new MutationObserver((records) => {
    for (const record of records) {
      const entry = entries.find((item) => item.element === record.target || item.element.contains(record.target));
      if (entry) queue(entry);
    }
  });
  const sizes = new ResizeObserver((records) => {
    for (const record of records) {
      if (record.target === screen) {
        entries.forEach(queue);
        continue;
      }
      const entry = entries.find((item) => item.element === record.target);
      if (entry) queue(entry);
    }
  });
  for (const entry of entries) {
    mutations.observe(entry.element, { childList: true, characterData: true, subtree: true });
    sizes.observe(entry.element);
    queue(entry);
  }
  if (screen) sizes.observe(screen);
  window.addEventListener("resize", () => entries.forEach(queue), { passive: true });
  document.fonts?.ready.then(() => entries.forEach(queue));
})();
