import Yoga, {
  Align,
  BoxSizing,
  Direction,
  Edge,
  FlexDirection,
  Gutter,
  Justify,
} from "./yoga-layout.js";

// Each LCD dot occupies three physical display pixels per side. On a Retina
// display (2x), that is a 1.5-CSS-pixel dot with a 2x2 face and a fine edge.
const DEVICE_PIXELS_PER_LCD_DOT = 3;
const LCD_FACE_DEVICE_PIXELS = DEVICE_PIXELS_PER_LCD_DOT - 1;
const BASELINE_LAYOUT_UNIT_CSS_PIXELS = 2.5;
const PALETTES = {
  CURRENT: ["#0C300C", "#285428", "#78940D", "#9BBC0F"],
  HIGH_CONTRAST: ["#041604", "#285428", "#78940D", "#9BBC0F"],
};
function paletteRGB(palette) {
  return palette.map((color) => {
    const value = Number.parseInt(color.slice(1), 16);
    return [(value >> 16) & 255, (value >> 8) & 255, value & 255];
  });
}
let RGB = paletteRGB(PALETTES.CURRENT);
const standardGlyphs = {
  A: ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
  B: ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
  C: ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
  D: ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
  E: ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
  F: ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
  G: ["01111", "10000", "10000", "10111", "10001", "10001", "01111"],
  H: ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
  I: ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
  J: ["00111", "00010", "00010", "00010", "10010", "10010", "01100"],
  K: ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
  L: ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
  M: ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
  N: ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
  O: ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
  P: ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
  Q: ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
  R: ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
  S: ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
  T: ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
  U: ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
  V: ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
  W: ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
  X: ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
  Y: ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
  Z: ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
  0: ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
  1: ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
  2: ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
  3: ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
  4: ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
  5: ["11111", "10000", "10000", "11110", "00001", "00001", "11110"],
  6: ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
  7: ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
  8: ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
  9: ["01110", "10001", "10001", "01111", "00001", "00001", "01110"],
  ":": ["00000", "00100", "00100", "00000", "00100", "00100", "00000"],
  ".": ["00000", "00000", "00000", "00000", "00000", "00110", "00110"],
  ",": ["00000", "00000", "00000", "00000", "00110", "00110", "00100"],
  "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
  "+": ["00000", "00100", "00100", "11111", "00100", "00100", "00000"],
  "/": ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
  "[": ["01110", "01000", "01000", "01000", "01000", "01000", "01110"],
  "]": ["01110", "00010", "00010", "00010", "00010", "00010", "01110"],
  "(": ["00010", "00100", "01000", "01000", "01000", "00100", "00010"],
  ")": ["01000", "00100", "00010", "00010", "00010", "00100", "01000"],
  "<": ["00010", "00100", "01000", "10000", "01000", "00100", "00010"],
  ">": ["01000", "00100", "00010", "00001", "00010", "00100", "01000"],
  "=": ["00000", "11111", "00000", "11111", "00000", "00000", "00000"],
  "#": ["01010", "01010", "11111", "01010", "11111", "01010", "01010"],
  "%": ["11001", "11010", "00100", "01000", "10110", "00110", "00000"],
  "?": ["01110", "10001", "00001", "00010", "00100", "00000", "00100"],
  "!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
  "'": ["00100", "00100", "00010", "00000", "00000", "00000", "00000"],
  "\"": ["01010", "01010", "00100", "00000", "00000", "00000", "00000"],
  "_": ["00000", "00000", "00000", "00000", "00000", "00000", "11111"],
  " ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
};
const microGlyphs = {
  A: ["010", "101", "111", "101", "101"],
  B: ["110", "101", "110", "101", "110"],
  C: ["011", "100", "100", "100", "011"],
  D: ["110", "101", "101", "101", "110"],
  E: ["111", "100", "110", "100", "111"],
  F: ["111", "100", "110", "100", "100"],
  G: ["011", "100", "101", "101", "011"],
  H: ["101", "101", "111", "101", "101"],
  I: ["111", "010", "010", "010", "111"],
  J: ["001", "001", "001", "101", "010"],
  K: ["101", "101", "110", "101", "101"],
  L: ["100", "100", "100", "100", "111"],
  M: ["101", "111", "111", "101", "101"],
  N: ["101", "111", "111", "111", "101"],
  O: ["010", "101", "101", "101", "010"],
  P: ["110", "101", "110", "100", "100"],
  Q: ["010", "101", "101", "011", "001"],
  R: ["110", "101", "110", "101", "101"],
  S: ["011", "100", "010", "001", "110"],
  T: ["111", "010", "010", "010", "010"],
  U: ["101", "101", "101", "101", "111"],
  V: ["101", "101", "101", "101", "010"],
  W: ["101", "101", "111", "111", "101"],
  X: ["101", "101", "010", "101", "101"],
  Y: ["101", "101", "010", "010", "010"],
  Z: ["111", "001", "010", "100", "111"],
  0: ["111", "101", "101", "101", "111"],
  1: ["010", "110", "010", "010", "111"],
  2: ["110", "001", "010", "100", "111"],
  3: ["110", "001", "010", "001", "110"],
  4: ["101", "101", "111", "001", "001"],
  5: ["111", "100", "110", "001", "110"],
  6: ["011", "100", "110", "101", "010"],
  7: ["111", "001", "010", "010", "010"],
  8: ["010", "101", "010", "101", "010"],
  9: ["010", "101", "011", "001", "110"],
  ":": ["000", "010", "000", "010", "000"],
  ".": ["000", "000", "000", "000", "010"],
  ",": ["000", "000", "000", "010", "100"],
  "-": ["000", "000", "111", "000", "000"],
  "+": ["000", "010", "111", "010", "000"],
  "/": ["001", "001", "010", "100", "100"],
  "[": ["110", "100", "100", "100", "110"],
  "]": ["011", "001", "001", "001", "011"],
  "(": ["001", "010", "100", "010", "001"],
  ")": ["100", "010", "001", "010", "100"],
  "<": ["001", "010", "100", "010", "001"],
  ">": ["100", "010", "001", "010", "100"],
  "↑": ["010", "101", "010", "010", "010"],
  "↓": ["010", "010", "010", "101", "010"],
  "=": ["000", "111", "000", "111", "000"],
  "#": ["101", "111", "101", "111", "101"],
  "*": ["010", "101", "111", "101", "010"],
  "%": ["101", "001", "010", "100", "101"],
  "?": ["110", "001", "010", "000", "010"],
  "!": ["010", "010", "010", "000", "010"],
  "'": ["010", "010", "000", "000", "000"],
  "\"": ["101", "101", "000", "000", "000"],
  "_": ["000", "000", "000", "000", "111"],
  " ": ["000", "000", "000", "000", "000"],
};
const FONT_PROFILES = {
  STANDARD: { label: "STANDARD 5 X 7", width: 5, height: 7, advance: 6, glyphs: standardGlyphs },
  MICRO: { label: "MICRO 3 X 5", width: 3, height: 5, advance: 4, glyphs: microGlyphs },
};
const DISPLAY_OPTIONS_KEY = "ViewBoy.displayOptions";
function storedDisplayOptions() {
  try { return JSON.parse(localStorage.getItem(DISPLAY_OPTIONS_KEY) || "{}"); }
  catch { return {}; }
}
function saveDisplayOptions() {
  try { localStorage.setItem(DISPLAY_OPTIONS_KEY, JSON.stringify({ font: state.font, contrast: state.contrast })); }
  catch { /* Display remains usable when browser storage is unavailable. */ }
}

const canvas = document.querySelector("#lcd");
const context = canvas.getContext("2d", { alpha: false });
const status = document.querySelector("#screen-reader-status");
context.imageSmoothingEnabled = false;

// fitCanvas() replaces these bootstrap dimensions before the first render.
let WIDTH = 1;
let HEIGHT = 1;
let DEVICE_PIXEL_RATIO = 1;
let UI_UNIT_CSS_PIXELS = DEVICE_PIXELS_PER_LCD_DOT;
let STYLE_SCALE = 1;
let pixels = new Uint8Array(WIDTH * HEIGHT);
let image = context.createImageData(
  WIDTH * DEVICE_PIXELS_PER_LCD_DOT,
  HEIGHT * DEVICE_PIXELS_PER_LCD_DOT,
);
let widgetTree = null;
let hitTargets = [];
let boxesById = new Map();
let layoutEntries = [];
let selectionRows = [];
let basePixels = new Uint8Array(WIDTH * HEIGHT);
let selectionBand = null;
let selectionAnimation = null;
let selectionAnimationFrame = 0;
let sidebarAnimationFrame = 0;
let paintClip = null;
const state = {
  tab: "LIBRARY",
  selectedTrack: 0,
  playing: false,
  font: storedDisplayOptions().font === "STANDARD" ? "STANDARD" : "MICRO",
  contrast: storedDisplayOptions().contrast === "HIGH_CONTRAST" ? "HIGH_CONTRAST" : "CURRENT",
  transport: "stopped",
  currentTrackId: null,
  activeQueue: [],
  games: [],
  favoriteTracks: [],
  favoriteIDs: new Set(),
  selectedSystem: null,
  selectedGameKey: null,
  sortColumn: null,
  sortDirection: "ASCENDING",
  activeGameKey: null,
  expandedSystems: new Set(),
  sidebarTransition: null,
  libraryScroll: 0,
  queueScroll: 0,
  status: "LOADING CATALOG",
  preferences: {},
  nativeGeneration: 0,
  playbackGeneration: 0,
  statusSequence: 0,
  catalogToken: 0,
  groupTransitionToken: 0,
  playbackToken: 0,
  retiredGeneration: 0,
};
RGB = paletteRGB(PALETTES[state.contrast]);

let tracks = [];

const bridge = window.viewBoy;

function trackID(track) {
  return track?.playlistId || `${track?.path || ""}:${track?.trackIndex || 0}`;
}

function gameKey(game) {
  return `${game.rootId}:${game.system}:${game.name}`;
}

function formatTime(milliseconds) {
  const seconds = Math.max(0, Math.round((Number(milliseconds) || 0) / 1000));
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
}

function activeTracks() {
  if (state.tab === "QUEUE") return state.activeQueue.length ? state.activeQueue : tracks;
  if (state.tab === "FAVORITES") return state.favoriteTracks;
  return tracks;
}

function visibleTracks() {
  const source = activeTracks();
  if (!state.sortColumn) return source;
  const direction = state.sortDirection === "ASCENDING" ? 1 : -1;
  const items = source.map((track, index) => ({ track, index }));
  return items.sort((first, second) => direction * String(tableValue(first.track, state.sortColumn, first.index))
    .localeCompare(String(tableValue(second.track, state.sortColumn, second.index)), undefined,
      { numeric: true, sensitivity: "base" }) || first.index - second.index)
    .map(({ track }) => track);
}

function easeSelection(progress) {
  return progress < 0.5
    ? 2 * progress * progress
    : 1 - Math.pow(-2 * progress + 2, 2) / 2;
}

function selectionYAt(time = performance.now()) {
  if (!selectionAnimation) return selectionBand?.y ?? null;
  const progress = Math.max(0, Math.min(1,
    (time - selectionAnimation.startedAt) / selectionAnimation.duration));
  const eased = easeSelection(progress);
  return selectionAnimation.fromY
    + (selectionAnimation.toY - selectionAnimation.fromY) * eased;
}

function floor(value) {
  return Math.round(value);
}

function fillRect(x, y, width, height, shade) {
  const left = Math.max(0, paintClip?.x ?? 0, floor(x));
  const top = Math.max(0, paintClip?.y ?? 0, floor(y));
  const right = Math.min(WIDTH, paintClip ? paintClip.x + paintClip.width : WIDTH, floor(x + width));
  const bottom = Math.min(HEIGHT, paintClip ? paintClip.y + paintClip.height : HEIGHT, floor(y + height));
  if (right <= left || bottom <= top) return;
  for (let row = top; row < bottom; row += 1) {
    const start = row * WIDTH + left;
    const end = row * WIDTH + right;
    pixels.fill(shade, start, end);
  }
}

function strokeRect(x, y, width, height, shade) {
  fillRect(x, y, width, 1, shade);
  fillRect(x, y + height - 1, width, 1, shade);
  fillRect(x, y, 1, height, shade);
  fillRect(x + width - 1, y, 1, height, shade);
}

function normalizedText(value) {
  return String(value)
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[–—]/g, "-")
    .replace(/[’‘]/g, "'")
    .toUpperCase();
}

function fontProfile() {
  return FONT_PROFILES[state.font] ?? FONT_PROFILES.MICRO;
}

function drawRawText(value, x, y, shade) {
  const font = fontProfile();
  const text = normalizedText(value);
  let cursor = floor(x);
  for (const character of text) {
    const rows = font.glyphs[character] ?? font.glyphs["?"];
    for (let row = 0; row < font.height; row += 1) {
      for (let column = 0; column < font.width; column += 1) {
        if (rows[row][column] === "1") {
          const px = cursor + column;
          const py = floor(y) + row;
          if (px >= 0 && px < WIDTH && py >= 0 && py < HEIGHT
              && (!paintClip || (px >= paintClip.x && px < paintClip.x + paintClip.width
                && py >= paintClip.y && py < paintClip.y + paintClip.height))) {
            const index = py * WIDTH + px;
            pixels[index] = shade;
          }
        }
      }
    }
    cursor += font.advance;
  }
}

function drawText(value, x, y, width, shade = 0, align = "left") {
  const font = fontProfile();
  const maxCharacters = Math.max(0, Math.floor((width + 1) / font.advance));
  if (maxCharacters < 1) return;
  let text = normalizedText(value);
  const chars = Array.from(text);
  if (chars.length > maxCharacters) {
    if (maxCharacters <= 2) {
      text = ".".repeat(maxCharacters);
    } else {
      text = `${chars.slice(0, maxCharacters - 2).join("")}..`;
    }
  }
  const measuredWidth = Math.max(0, Array.from(text).length * font.advance - 1);
  let textX = x;
  if (align === "center") textX += Math.floor((width - measuredWidth) / 2);
  if (align === "right") textX += width - measuredWidth;
  drawRawText(text, textX, y, shade);
}

function line(x1, y1, x2, y2, shade) {
  if (y1 === y2) fillRect(x1, y1, x2 - x1, 1, shade);
  else if (x1 === x2) fillRect(x1, y1, 1, y2 - y1, shade);
}

function present(startY = 0, endY = HEIGHT) {
  const target = image.data;
  const outputWidth = WIDTH * DEVICE_PIXELS_PER_LCD_DOT;
  const firstRow = Math.max(0, Math.floor(startY));
  const lastRow = Math.min(HEIGHT, Math.ceil(endY));
  if (lastRow <= firstRow) return;
  for (let y = firstRow; y < lastRow; y += 1) {
    for (let x = 0; x < WIDTH; x += 1) {
      const baseShade = pixels[y * WIDTH + x];
      for (let subY = 0; subY < DEVICE_PIXELS_PER_LCD_DOT; subY += 1) {
      for (let subX = 0; subX < DEVICE_PIXELS_PER_LCD_DOT; subX += 1) {
        // A 2x2 shaded face leaves a one-device-pixel reflective edge.
        const pixelCore = subX < LCD_FACE_DEVICE_PIXELS
          && subY < LCD_FACE_DEVICE_PIXELS;
        // The seam is the unlit screen substrate. UI color only reaches the
        // LCD face; empty matrix space always shows the background shade.
        const color = pixelCore ? RGB[baseShade] : RGB[3];
        const outputIndex = ((y * DEVICE_PIXELS_PER_LCD_DOT + subY) * outputWidth
          + x * DEVICE_PIXELS_PER_LCD_DOT + subX) * 4;
        target[outputIndex] = color[0];
        target[outputIndex + 1] = color[1];
        target[outputIndex + 2] = color[2];
        target[outputIndex + 3] = 255;
      }
      }
    }
  }
  context.putImageData(image, 0, 0, 0,
    firstRow * DEVICE_PIXELS_PER_LCD_DOT,
    outputWidth,
    (lastRow - firstRow) * DEVICE_PIXELS_PER_LCD_DOT);
}

function makeWidget(parent, style = {}, meta = {}) {
  const yoga = Yoga.Node.create();
  yoga.setBoxSizing(BoxSizing.BorderBox);
  yoga.setFlexDirection(style.direction ?? FlexDirection.Column);
  yoga.setAlignItems(style.alignItems ?? Align.Stretch);
  yoga.setJustifyContent(style.justifyContent ?? Justify.FlexStart);
  yoga.setFlexShrink(style.flexShrink ?? 0);
  if (style.width !== undefined) yoga.setWidth(style.width * STYLE_SCALE);
  if (style.height !== undefined) yoga.setHeight(style.height * STYLE_SCALE);
  if (style.flexGrow !== undefined) yoga.setFlexGrow(style.flexGrow);
  if (style.flexBasis !== undefined) yoga.setFlexBasis(style.flexBasis * STYLE_SCALE);
  if (style.padding !== undefined) yoga.setPadding(Edge.All, style.padding * STYLE_SCALE);
  if (style.paddingHorizontal !== undefined) {
    yoga.setPadding(Edge.Horizontal, style.paddingHorizontal * STYLE_SCALE);
  }
  if (style.paddingVertical !== undefined) {
    yoga.setPadding(Edge.Vertical, style.paddingVertical * STYLE_SCALE);
  }
  if (style.gap !== undefined) yoga.setGap(Gutter.All, style.gap * STYLE_SCALE);
  if (style.overflow !== undefined) yoga.setOverflow(style.overflow);

  const widget = { yoga, children: [], meta, parent };
  if (parent) {
    parent.children.push(widget);
    parent.yoga.insertChild(yoga, parent.children.length - 1);
  }
  return widget;
}

function label(parent, text, style = {}, meta = {}) {
  return makeWidget(parent, style, {
    ...meta,
    text,
    paint(box) {
      const previousClip = paintClip;
      if (meta.clipToBox) paintClip = box;
      if (meta.fill !== undefined) fillRect(box.x, box.y, box.width, box.height, meta.fill);
      if (meta.border !== undefined) strokeRect(box.x, box.y, box.width, box.height, meta.border);
      if (meta.bottomLine !== undefined) {
        line(box.x, box.y + box.height - 1, box.x + box.width, box.y + box.height, meta.bottomLine);
      }
      if (meta.paint) meta.paint(box);
      const textY = meta.revealProgress !== undefined
        ? box.y : box.y + Math.floor((box.height - fontProfile().height) / 2);
      drawText(text, box.x + (meta.inset ?? 2), textY, box.width - (meta.inset ?? 2) * 2,
        meta.textShade ?? 0, meta.align ?? "left");
      paintClip = previousClip;
    },
  });
}

function rowHeight(extraDots = 0) {
  return (fontProfile().height + extraDots) / STYLE_SCALE;
}

function oneDot() {
  return 1 / STYLE_SCALE;
}

function panelTitle(parent, text, suffix = "", suffixWidth = 40) {
  const titleHeight = rowHeight(2);
  const row = makeWidget(parent, {
    direction: FlexDirection.Row,
    height: titleHeight,
    alignItems: Align.Center,
  }, {
    fill: 2,
    paint(box) {
      fillRect(box.x, box.y, box.width, box.height, 2);
    },
  });
  label(row, text, { flexGrow: 1, height: titleHeight }, { textShade: 0, inset: 2 });
  if (suffix) label(row, suffix, { width: suffixWidth, height: titleHeight }, { textShade: 0, align: "right", inset: 2 });
  return row;
}

function pixelButton(parent, text, onClick, style = {}) {
  const font = fontProfile();
  return label(parent, text, {
    direction: FlexDirection.Row,
    alignItems: Align.Center,
    justifyContent: Justify.Center,
    height: style.height ?? rowHeight(6),
    width: style.width,
    flexGrow: style.flexGrow ?? 0,
  }, {
    border: 1,
    textShade: 0,
    inset: Math.max(1, Math.floor((font.advance - 1) / 2)),
    align: "center",
    onClick,
  });
}

function formatSize(bytes) {
  const value = Number(bytes);
  if (!Number.isFinite(value) || value <= 0) return "";
  if (value < 1024 * 1024) return `${Math.round(value / 1024)}K`;
  return `${(value / (1024 * 1024)).toFixed(1)}M`;
}

function tableValue(track, key, rowIndex = 0) {
  switch (key) {
    case "favorite": return state.favoriteIDs.has(trackID(track)) ? "*" : "";
    case "index": return String(rowIndex + 1).padStart(2, "0");
    case "filename": return track.filename || "";
    case "title": return track.title || track.filename || "UNTITLED";
    case "game": return track.game || "";
    case "artist": return track.artist || track.author || "";
    case "system": return track.system || "";
    case "path": return track.archiveEntry
      ? `${track.path || track.archivePath} / ${track.archiveEntry}`
      : track.path || track.archivePath || "";
    case "length": return track.lengthLabel || (Number(track.playLengthMs) > 0
      ? formatTime(track.playLengthMs) : "");
    case "size": return formatSize(track.fileSize);
    default: return track[key] || "";
  }
}

function toggleSort(columnKey) {
  const selectedID = visibleTracks()[state.selectedTrack]
    ? trackID(visibleTracks()[state.selectedTrack]) : null;
  if (state.sortColumn === columnKey) {
    state.sortDirection = state.sortDirection === "ASCENDING" ? "DESCENDING" : "ASCENDING";
  } else {
    state.sortColumn = columnKey;
    state.sortDirection = "ASCENDING";
  }
  const nextIndex = visibleTracks().findIndex((track) => trackID(track) === selectedID);
  if (nextIndex >= 0) state.selectedTrack = nextIndex;
  state.queueScroll = Math.max(0, Math.min(state.queueScroll,
    Math.max(0, visibleTracks().length - visibleRowCount())));
  if (state.selectedTrack < state.queueScroll) state.queueScroll = state.selectedTrack;
  if (state.selectedTrack >= state.queueScroll + visibleRowCount()) {
    state.queueScroll = state.selectedTrack - visibleRowCount() + 1;
  }
  render(true);
}

function tableColumns(items = activeTracks()) {
  const gap = oneDot();
  const sidebarWidth = state.tab === "SETTINGS" ? 0 : (WIDTH < 420 ? 94 : 128);
  const available = Math.max(0, WIDTH / STYLE_SCALE - 16 - sidebarWidth - 12);
  const minimumTitleWidth = (20 * fontProfile().advance) / STYLE_SCALE;
  const columns = [
    { key: "favorite", title: "*", width: 7, align: "center", mandatory: true },
    { key: "index", title: "#", width: 12, align: "right", mandatory: true },
    { key: "filename", title: "FILE", width: 34 },
    { key: "title", title: "TITLE", width: minimumTitleWidth, flexGrow: 1, mandatory: true, align: "center" },
    { key: "game", title: "GAME", width: 40 },
    { key: "artist", title: "ARTIST", width: 40 },
    { key: "system", title: "SYSTEM", width: 28, mandatory: true },
    { key: "path", title: "PATH", width: 58 },
    { key: "length", title: "LENGTH", width: 32, align: "right", mandatory: true },
    { key: "size", title: "SIZE", width: 28 },
  ];
  const chosen = new Set(columns.filter((column) => column.mandatory).map((column) => column.key));
  let used = columns.filter((column) => column.mandatory)
    .reduce((sum, column) => sum + column.width, 0) + (chosen.size - 1) * gap;
  for (const column of columns) {
    if (column.mandatory || !items.slice(0, 256)
      .some((track, index) => String(tableValue(track, column.key, index)).trim())) continue;
    if (used + column.width + gap <= available) {
      chosen.add(column.key);
      used += column.width + gap;
    }
  }
  return columns.filter((column) => chosen.has(column.key));
}

function createTableHeader(parent, columns) {
  const headerHeight = rowHeight(4);
  const header = makeWidget(parent, {
    direction: FlexDirection.Row,
    alignItems: Align.Center,
    height: headerHeight,
    gap: oneDot(),
  }, {
    paint(box) {
      line(box.x, box.y + box.height - 1, box.x + box.width, box.y + box.height, 1);
    },
  });
  columns.forEach((column) => {
    const marker = state.sortColumn === column.key
      ? (state.sortDirection === "ASCENDING" ? "↑" : "↓") : "";
    label(header, column.title + marker, {
      width: column.width,
      flexGrow: column.flexGrow,
      height: headerHeight,
    }, {
      textShade: 0,
      inset: 1,
      border: 1,
      fill: marker ? 2 : undefined,
      align: column.align ?? "center",
      onClick: column.key === "favorite" ? undefined : () => toggleSort(column.key),
    });
  });
  return header;
}

function createQueueRow(parent, index, track, columns) {
  const rowHeightValue = rowHeight(2);
  const row = makeWidget(parent, {
    direction: FlexDirection.Row,
    alignItems: Align.Center,
    height: rowHeightValue,
    gap: oneDot(),
  }, {
    onClick: (event) => {
      selectTrack(index, false);
      if (event.detail >= 2) startTrack(track);
    },
    trackIndex: index,
  });
  columns.forEach((column) => label(row, tableValue(track, column.key, index), {
    width: column.width,
    flexGrow: column.flexGrow,
    height: rowHeightValue,
  }, {
    textShade: 0,
    inset: 0,
    align: column.align ?? "left",
    onClick: column.key === "favorite" ? () => toggleFavorite(track) : undefined,
  }));
  return row;
}

function createLibraryRow(parent, text, options = {}) {
  const selected = options.selected ?? false;
  const rowHeightValue = rowHeight(2);
  const revealProgress = options.revealProgress;
  return label(parent, text, {
    height: rowHeightValue * (revealProgress ?? 1),
    paddingHorizontal: 2,
  }, {
    textShade: 0,
    clipToBox: revealProgress !== undefined,
    revealProgress,
    onClick: options.onClick,
    inset: options.indent ?? 1,
    paint(box) {
      if (selected) fillRect(box.x, box.y, box.width, box.height, 2);
    },
  });
}

function visibleRowCount() {
  return Math.max(1, Math.floor((HEIGHT / STYLE_SCALE - 66) / rowHeight(3)));
}

function libraryRows() {
  const groups = new Map();
  for (const game of state.games) {
    const system = game.system || "OTHER";
    if (!groups.has(system)) groups.set(system, []);
    groups.get(system).push(game);
  }
  const rows = [];
  const transition = state.sidebarTransition;
  for (const system of [...groups.keys()].sort()) {
    rows.push({ text: `${state.expandedSystems.has(system) ? "V" : ">"} ${system}`, system, group: true });
    const isTransitioning = transition?.system === system;
    if (state.expandedSystems.has(system) || (isTransitioning && transition.progress > 0)) {
      for (const game of groups.get(system)) {
        rows.push({
          text: game.displayName || game.name,
          game,
          indent: 7,
          revealProgress: isTransitioning ? transition.progress : undefined,
        });
      }
    }
  }
  return rows;
}

function addLibraryPane(parent) {
  const library = makeWidget(parent, {
    direction: FlexDirection.Column,
    width: WIDTH < 420 ? 94 : 128,
    gap: 0,
    padding: 2,
  }, {
    paint(box) {
      strokeRect(box.x, box.y, box.width, box.height, 1);
    },
  });
  panelTitle(library, "VIEWS", "03");
  [
    ["LIBRARY", "LIBRARY"],
    ["CURRENT QUEUE", "QUEUE"],
    ["FAVORITES", "FAVORITES"],
  ].forEach(([title, view]) => createLibraryRow(library, title, {
    selected: state.tab === view,
    onClick: () => selectSidebarView(view),
  }));
  label(library, "OPEN PATH", { height: rowHeight(2) }, {
    textShade: 0, inset: 1, onClick: () => openLocalPath(),
  });
  panelTitle(library, "SYSTEMS", String(state.games.length));
  const rows = libraryRows();
  const count = Math.max(1, Math.floor((HEIGHT / STYLE_SCALE - 116) / rowHeight(3)));
  state.libraryScroll = Math.max(0, Math.min(state.libraryScroll, Math.max(0, rows.length - count)));
  rows.slice(state.libraryScroll, state.libraryScroll + count).forEach((row) => {
    createLibraryRow(library, row.text, {
      selected: row.game && gameKey(row.game) === state.selectedGameKey,
      indent: row.indent,
      revealProgress: row.revealProgress,
      onClick: row.game ? () => loadGame(row.game) : () => toggleSystem(row.system),
    });
  });
  label(library, `${rows.length ? state.libraryScroll + 1 : 0}-${Math.min(rows.length, state.libraryScroll + count)} / ${rows.length}`, {
    flexGrow: 1, height: rowHeight(2),
  }, { textShade: 0, align: "right", inset: 1 });
  return library;
}

function addCatalogPane(parent, mode) {
  const viewTracks = visibleTracks();
  const panel = makeWidget(parent, {
    direction: FlexDirection.Column,
    flexGrow: 1,
    gap: 0,
    padding: 2,
  }, {
    paint(box) {
      strokeRect(box.x, box.y, box.width, box.height, 1);
    },
  });
  const heading = mode === "QUEUE" ? "PLAY QUEUE"
    : mode === "FAVORITES" ? "FAVORITES" : "TRACK CATALOG";
  panelTitle(panel, heading, `${viewTracks.length} TRACKS`, 60);
  const columns = tableColumns(viewTracks);
  createTableHeader(panel, columns);
  const count = visibleRowCount();
  state.queueScroll = Math.max(0, Math.min(state.queueScroll, Math.max(0, viewTracks.length - count)));
  viewTracks.slice(state.queueScroll, state.queueScroll + count).forEach((track, offset) =>
    createQueueRow(panel, state.queueScroll + offset, track, columns));
  if (!viewTracks.length) label(panel, state.status, { height: rowHeight(4) }, { textShade: 0, inset: 1 });
  label(panel, `${viewTracks.length ? state.queueScroll + 1 : 0}-${Math.min(viewTracks.length, state.queueScroll + count)} / ${viewTracks.length}`, {
    flexGrow: 1,
    height: rowHeight(2),
  }, {
    textShade: 0,
    align: "right",
    inset: 1,
  });
  return panel;
}

function addOptionsContent(parent) {
  const panel = makeWidget(parent, {
    direction: FlexDirection.Column,
    flexGrow: 1,
    gap: 0,
    padding: 2,
  }, {
    paint(box) {
      strokeRect(box.x, box.y, box.width, box.height, 1);
    },
  });
  panelTitle(panel, "OPTIONS", "VIEWBOY", 48);
  const pref = state.preferences;
  const rows = [
    ["FONT GLYPHS", fontProfile().label, () => toggleFont()],
    ["LCD CONTRAST", state.contrast === "CURRENT" ? "CURRENT" : "HIGH", () => toggleContrast()],
    ["LCD DOT", "3 DEVICE PX"],
    ["LONG PLAY", pref.longPlayEnabled ? "ON" : "OFF", () => setPreference("longPlayEnabled", !pref.longPlayEnabled)],
    ["END FADE", pref.fadeEnabled === false ? "OFF" : "ON", () => setPreference("fadeEnabled", pref.fadeEnabled === false)],
    ["REPEAT", String(pref.repeatMode || "off"), () => cycleRepeat()],
    ["MONO", pref.monoEnabled ? "ON" : "OFF", () => setPreference("monoEnabled", !pref.monoEnabled, true)],
    ["VOLUME -", `${Math.round(Number(pref.appVolume ?? 1) * 100)}%`, () => changeVolume(-0.1)],
    ["VOLUME +", `${Math.round(Number(pref.appVolume ?? 1) * 100)}%`, () => changeVolume(0.1)],
    ["RELOAD LIBRARY", "RUN", () => loadCatalog()],
  ];
  rows.forEach(([name, value, onClick]) => {
    const optionHeight = rowHeight(4);
    const row = makeWidget(panel, {
      direction: FlexDirection.Row,
      alignItems: Align.Center,
      height: optionHeight,
      paddingHorizontal: 2,
    }, {
      onClick,
      paint(box) {
        line(box.x, box.y + box.height - 1, box.x + box.width, box.y + box.height, 2);
      },
    });
    label(row, name, { flexGrow: 1, height: optionHeight }, { textShade: 0, inset: 1 });
    label(row, value, { width: 100, height: optionHeight }, {
      textShade: 0,
      align: "right",
      inset: 1,
    });
  });
}

function buildTree() {
  const toolbarHeight = rowHeight(6);
  const root = makeWidget(null, {
    direction: FlexDirection.Column,
    width: WIDTH / STYLE_SCALE,
    height: HEIGHT / STYLE_SCALE,
    padding: 8,
    gap: oneDot(),
    alignItems: Align.Stretch,
  }, {
    paint() {
      fillRect(0, 0, WIDTH, HEIGHT, 3);
    },
  });

  const toolbar = makeWidget(root, {
    direction: FlexDirection.Row,
    height: toolbarHeight,
    gap: oneDot(),
    alignItems: Align.Center,
  });
  label(toolbar, "VIEWBOY", { flexGrow: 1, height: toolbarHeight }, {
    textShade: 0, inset: 0,
  });
  const buttonWidth = (text) => (Array.from(text).length * fontProfile().advance + 6) / STYLE_SCALE;
  pixelButton(toolbar, state.tab === "SETTINGS" ? "BACK" : "OPTIONS", () => {
    state.tab = state.tab === "SETTINGS" ? "LIBRARY" : "SETTINGS";
    render();
  }, { width: buttonWidth(state.tab === "SETTINGS" ? "BACK" : "OPTIONS") });
  pixelButton(toolbar, "PREV", () => selectPrevious(), { width: buttonWidth("PREV") });
  pixelButton(toolbar, state.playing ? "PAUSE" : "PLAY", () => togglePlaying(), {
    width: buttonWidth(state.playing ? "PAUSE" : "PLAY"),
  });
  pixelButton(toolbar, "NEXT", () => selectNext(), { width: buttonWidth("NEXT") });
  pixelButton(toolbar, "STOP", () => stopPlayback(), { width: buttonWidth("STOP") });

  const content = makeWidget(root, {
    direction: FlexDirection.Row,
    flexGrow: 1,
    gap: oneDot() * 2,
    alignItems: Align.Stretch,
  });
  if (state.tab === "SETTINGS") {
    addOptionsContent(content);
  } else {
    addLibraryPane(content);
    addCatalogPane(content, state.tab);
  }

  const bottom = makeWidget(root, {
    direction: FlexDirection.Row,
    alignItems: Align.Center,
    height: rowHeight(4),
  }, {
    paint(box) {
      line(box.x, box.y, box.x + box.width, box.y, 2);
    },
  });
  const current = state.activeQueue.find((track) => trackID(track) === state.currentTrackId);
  const selected = visibleTracks()[state.selectedTrack];
  label(bottom, "NOW / " + (current?.title || current?.filename || selected?.title || selected?.filename || state.status), {
    flexGrow: 1,
    height: rowHeight(2),
  }, {
    textShade: 0,
    inset: 0,
  });
  label(bottom, state.playing ? "PLAYING" : state.transport.toUpperCase(), {
    width: 48,
    height: rowHeight(2),
  }, {
    textShade: 0,
    align: "right",
    inset: 0,
  });

  root.yoga.calculateLayout(WIDTH, HEIGHT, Direction.LTR);
  return root;
}

function collect(widget, parentX = 0, parentY = 0, output = []) {
  const layout = widget.yoga.getComputedLayout();
  const box = {
    x: floor(parentX + layout.left),
    y: floor(parentY + layout.top),
    width: floor(layout.width),
    height: floor(layout.height),
  };
  const entry = { widget, box };
  output.push(entry);
  boxesById.set(widget.meta.id, box);
  if (widget.meta.onClick) hitTargets.push(entry);
  for (const child of widget.children) collect(child, box.x, box.y, output);
  return output;
}

function paintTree(widget, box) {
  if (widget.meta.paint) widget.meta.paint(box);
  for (const child of widget.children) {
    const layout = child.yoga.getComputedLayout();
    paintTree(child, {
      x: floor(box.x + layout.left),
      y: floor(box.y + layout.top),
      width: floor(layout.width),
      height: floor(layout.height),
    });
  }
}

function paintSelectionAt(y, startY = 0, endY = HEIGHT) {
  pixels.set(basePixels);
  if (selectionBand && y !== null) {
    const bandTop = floor(y);
    fillRect(selectionBand.x, bandTop, selectionBand.width, selectionBand.height, 2);
    for (const row of selectionRows) {
      if (row.box.y >= bandTop + selectionBand.height || row.box.y + row.box.height <= bandTop) continue;
      for (const child of row.widget.children) {
        const entry = layoutEntries.find((candidate) => candidate.widget === child);
        if (entry?.widget.meta.paint) entry.widget.meta.paint(entry.box);
      }
    }
  }
  present(startY, endY);
}

function animateSelectionFrame(time) {
  selectionAnimationFrame = 0;
  if (!selectionAnimation) return;
  const priorY = selectionAnimation.lastY;
  const y = selectionYAt(time);
  const extent = selectionBand?.height ?? 0;
  paintSelectionAt(y, Math.min(priorY, y) - 1, Math.max(priorY, y) + extent + 1);
  selectionAnimation.lastY = y;
  if (time - selectionAnimation.startedAt < selectionAnimation.duration) {
    selectionAnimationFrame = requestAnimationFrame(animateSelectionFrame);
  } else {
    selectionBand.y = selectionAnimation.toY;
    selectionAnimation = null;
  }
}

function render(animateSelection = false) {
  if (selectionAnimationFrame) cancelAnimationFrame(selectionAnimationFrame);
  selectionAnimationFrame = 0;
  const priorBand = selectionBand;
  const priorY = selectionYAt();
  if (widgetTree) widgetTree.yoga.freeRecursive();
  boxesById = new Map();
  hitTargets = [];
  pixels.fill(3);
  widgetTree = buildTree();
  layoutEntries = collect(widgetTree);
  paintTree(widgetTree, { x: 0, y: 0, width: WIDTH, height: HEIGHT });
  basePixels = pixels.slice();
  selectionRows = layoutEntries.filter((entry) => Number.isInteger(entry.widget.meta.trackIndex));
  const selectedRow = selectionRows.find((entry) => entry.widget.meta.trackIndex === state.selectedTrack);
  const nextBand = selectedRow ? { ...selectedRow.box } : null;
  const canSlide = animateSelection && priorBand && nextBand
    && priorBand.x === nextBand.x && priorBand.width === nextBand.width
    && priorBand.height === nextBand.height && Math.abs(priorY - nextBand.y) > 0.5;
  selectionBand = nextBand;
  if (canSlide) {
    selectionAnimation = {
      fromY: priorY,
      toY: nextBand.y,
      startedAt: performance.now(),
      duration: 250,
      lastY: priorY,
    };
    paintSelectionAt(priorY);
    selectionAnimationFrame = requestAnimationFrame(animateSelectionFrame);
  } else {
    selectionAnimation = null;
    paintSelectionAt(nextBand?.y ?? null);
  }
  const selected = visibleTracks()[state.selectedTrack];
  status.textContent = `${state.tab}. ${state.status}. ${state.transport}. `
    + (selected ? `Selected track ${state.selectedTrack + 1}: ${selected.title || selected.filename}.` : "No track selected.");
}

function announce(message) {
  status.textContent = message;
}

function toggleFont() {
  state.font = state.font === "MICRO" ? "STANDARD" : "MICRO";
  saveDisplayOptions();
  render();
}

function toggleContrast() {
  state.contrast = state.contrast === "CURRENT" ? "HIGH_CONTRAST" : "CURRENT";
  RGB = paletteRGB(PALETTES[state.contrast]);
  saveDisplayOptions();
  render();
}

async function loadFavorites() {
  if (!bridge?.favoritesList) return;
  try {
    const favorites = await bridge.favoritesList("historical");
    if (!Array.isArray(favorites)) return;
    state.favoriteTracks = favorites;
    state.favoriteIDs = new Set(favorites.map(trackID));
    render();
  } catch (error) {
    state.status = `FAVORITES ERROR: ${error.message}`;
    render();
  }
}

async function toggleFavorite(track) {
  if (!bridge?.favoritesToggle) return;
  try {
    const favorites = await bridge.favoritesToggle([track], "historical");
    if (Array.isArray(favorites)) {
      state.favoriteTracks = favorites;
      state.favoriteIDs = new Set(favorites.map(trackID));
      state.selectedTrack = Math.min(state.selectedTrack, Math.max(0, favorites.length - 1));
      render();
    }
  } catch (error) {
    state.status = `FAVORITE ERROR: ${error.message}`;
    render();
  }
}

function selectSidebarView(view) {
  state.tab = view;
  state.selectedTrack = 0;
  state.queueScroll = 0;
  render();
  if (view === "FAVORITES") loadFavorites();
}

async function reduceDatabaseGroupState(action, system, gameID = null) {
  if (!bridge?.databaseGroupState) return false;
  const token = ++state.groupTransitionToken;
  const next = await bridge.databaseGroupState({
    expandedGroupNames: [...state.expandedSystems],
    selectedGroupName: state.selectedSystem,
    selectedGameID: state.selectedGameKey,
  }, action, system, gameID);
  if (token !== state.groupTransitionToken || !next) return false;
  state.expandedSystems = new Set(Array.isArray(next.expandedGroupNames) ? next.expandedGroupNames : []);
  state.selectedSystem = next.selectedGroupName || null;
  state.selectedGameKey = next.selectedGameID || null;
  return true;
}

function animateSidebarFrame(time) {
  sidebarAnimationFrame = 0;
  const transition = state.sidebarTransition;
  if (!transition) return;
  const progress = Math.max(0, Math.min(1,
    (time - transition.startedAt) / transition.duration));
  transition.progress = transition.fromProgress
    + (transition.toProgress - transition.fromProgress) * easeSelection(progress);
  render();
  if (progress < 1) {
    sidebarAnimationFrame = requestAnimationFrame(animateSidebarFrame);
  } else {
    state.sidebarTransition = null;
    render();
  }
}

async function toggleSystem(system) {
  const wasExpanded = state.expandedSystems.has(system);
  const currentProgress = state.sidebarTransition?.system === system
    ? state.sidebarTransition.progress : (wasExpanded ? 1 : 0);
  const targetProgress = wasExpanded ? 0 : 1;
  if (sidebarAnimationFrame) cancelAnimationFrame(sidebarAnimationFrame);
  sidebarAnimationFrame = 0;
  try {
    if (await reduceDatabaseGroupState("toggle", system)) {
      state.sidebarTransition = {
        system,
        fromProgress: currentProgress,
        toProgress: targetProgress,
        progress: currentProgress,
        startedAt: performance.now(),
        duration: Math.max(1, 250 * Math.abs(targetProgress - currentProgress)),
      };
      render();
      sidebarAnimationFrame = requestAnimationFrame(animateSidebarFrame);
    }
  } catch (error) {
    state.status = `SIDEBAR ERROR: ${error.message}`;
    render();
  }
}

async function loadCatalog() {
  if (!bridge?.databaseGames) {
    state.status = "NATIVE BRIDGE UNAVAILABLE";
    render();
    return;
  }
  state.status = "LOADING CATALOG";
  const token = ++state.catalogToken;
  render();
  try {
    const games = await bridge.databaseGames();
    if (token !== state.catalogToken || games?.stale) return;
    state.games = Array.isArray(games) ? games : [];
    state.games.sort((a, b) => (a.system || "").localeCompare(b.system || "")
      || (a.displayName || a.name || "").localeCompare(b.displayName || b.name || ""));
    state.status = state.games.length ? "READY" : "CATALOG EMPTY";
    if (state.games.length) {
      const game = state.games.find((item) => gameKey(item) === state.activeGameKey) || state.games[0];
      const system = game.system || "OTHER";
      if (!state.expandedSystems.has(system)) await reduceDatabaseGroupState("toggle", system);
      await loadGame(game);
    } else {
      tracks = [];
      state.selectedTrack = 0;
      render();
    }
  } catch (error) {
    if (token !== state.catalogToken) return;
    state.status = `CATALOG ERROR: ${error.message}`;
    render();
  }
}

async function loadGame(game) {
  if (!bridge?.databaseGameTracks) return;
  const token = ++state.catalogToken;
  const selectedKey = gameKey(game);
  state.status = `LOADING ${game.displayName || game.name}`;
  render();
  try {
    await reduceDatabaseGroupState("selectGame", game.system || "OTHER", selectedKey);
    state.activeGameKey = selectedKey;
    const rows = await bridge.databaseGameTracks([game]);
    if (token !== state.catalogToken || rows?.stale) return;
    tracks = Array.isArray(rows) ? rows : [];
    state.selectedTrack = 0;
    state.queueScroll = 0;
    state.status = tracks.length ? (game.displayName || game.name) : "NO TRACKS";
    state.tab = "LIBRARY";
    render();
  } catch (error) {
    if (token !== state.catalogToken) return;
    tracks = [];
    state.status = `TRACK ERROR: ${error.message}`;
    render();
  }
}

function applyNativeStatus(snapshot) {
  if (!snapshot || typeof snapshot !== "object") return;
  const sequence = Number(snapshot.status_sequence) || 0;
  const generation = Number(snapshot.generation) || 0;
  if (sequence && sequence < state.statusSequence) return;
  if (generation && generation < state.nativeGeneration) return;
  state.statusSequence = sequence || state.statusSequence;
  state.nativeGeneration = generation || state.nativeGeneration;
  const nextTransport = snapshot.transport_state || "stopped";
  const priorTransport = state.transport;
  const priorSecond = Math.floor((state.positionMs || 0) / 1000);
  state.transport = nextTransport;
  state.playing = state.transport === "playing";
  state.positionMs = Number(snapshot.position_ms) || 0;
  if (snapshot.error) state.status = `PLAYBACK ERROR: ${snapshot.error}`;
  if (priorTransport !== nextTransport || priorSecond !== Math.floor(state.positionMs / 1000)
      || snapshot.error) render();
}

async function handleNativeEnded(snapshot) {
  const generation = Number(snapshot?.generation) || 0;
  if (!generation || generation !== state.playbackGeneration
      || generation <= state.retiredGeneration || !state.currentTrackId) return;
  applyNativeStatus(snapshot);
  state.retiredGeneration = generation;
  const completedId = state.currentTrackId;
  const queue = [...state.activeQueue];
  try {
    const decision = await bridge.playbackCompletionRetire({
      generation,
      state: {
        currentTrackId: completedId,
        selectedTrackId: completedId,
        pendingTrackId: null,
      },
      playlistIds: queue.map(trackID),
      intent: { repeatMode: state.preferences.repeatMode || "off" },
    });
    if (state.currentTrackId !== completedId) return;
    const next = decision?.action === "play"
      ? queue.find((track) => trackID(track) === decision.trackId) : null;
    if (next) {
      const visibleIndex = visibleTracks().findIndex((track) => trackID(track) === trackID(next));
      if (visibleIndex >= 0) selectTrack(visibleIndex, false);
      await startTrack(next, queue);
    } else {
      state.currentTrackId = null;
      state.playbackGeneration = 0;
      state.playing = false;
      state.transport = "stopped";
      state.status = "ENDED";
      render();
    }
  } catch (error) {
    state.status = `QUEUE ERROR: ${error.message}`;
    render();
  }
}

async function openLocalPath() {
  if (!bridge?.choosePath) return;
  try {
    const snapshot = await bridge.choosePath();
    if (!snapshot || snapshot.stale) return;
    ++state.catalogToken;
    let playlist = snapshot.playlist;
    if ((!Array.isArray(playlist) || !playlist.length) && snapshot.rootPath && bridge.selectFolder) {
      playlist = (await bridge.selectFolder(snapshot.rootPath))?.playlist;
    }
    tracks = Array.isArray(playlist) ? playlist : [];
    state.selectedTrack = 0;
    state.queueScroll = 0;
    state.activeGameKey = null;
    state.activeQueue = tracks;
    state.tab = "QUEUE";
    state.status = tracks.length ? "LOCAL FILES" : "NO PLAYABLE FILES AT PATH";
    render();
  } catch (error) {
    state.status = `OPEN ERROR: ${error.message}`;
    render();
  }
}

async function configureAudio() {
  if (!bridge?.nativePlaybackAudioConfig) return;
  const pref = state.preferences;
  await bridge.nativePlaybackAudioConfig(
    Number(pref.appVolume ?? 1),
    pref.equalizerEnabled === true,
    pref.equalizerBandGains || Array(10).fill(0),
    pref.monoEnabled === true,
  );
}

async function startTrack(track, queue = activeTracks()) {
  if (!track || !bridge?.nativePlaybackStart) return;
  const token = ++state.playbackToken;
  state.currentTrackId = trackID(track);
  state.playbackGeneration = 0;
  state.activeQueue = [...queue];
  state.status = `LOADING ${track.title || track.filename}`;
  render();
  try {
    await bridge.nativePlaybackInit();
    await configureAudio();
    if (token !== state.playbackToken) return;
    const pref = state.preferences;
    const snapshot = await bridge.nativePlaybackStart({
      path: track.path,
      archivePath: track.archivePath || null,
      archiveEntry: track.archiveEntry || null,
      trackIndex: track.trackIndex || 0,
      startMilliseconds: 0,
      playMilliseconds: pref.longPlayEnabled ? Math.max(0, Number(pref.manualPlayTimeSeconds ?? 180)) * 1000 : 0,
      fadeMilliseconds: pref.fadeEnabled === false ? 0 : Math.max(0, Number(pref.spcFadeSeconds ?? 6)) * 1000,
      tempo: 1,
      longPlayEnabled: pref.longPlayEnabled === true,
      timedOverride: false,
      unknownDurationMilliseconds: Math.max(1, Number(pref.unknownDurationSeconds ?? 150)) * 1000,
    });
    if (token !== state.playbackToken) return;
    state.playbackGeneration = Number(snapshot?.generation) || 0;
    state.status = track.title || track.filename || "PLAYING";
    applyNativeStatus(snapshot);
  } catch (error) {
    if (token !== state.playbackToken) return;
    state.currentTrackId = null;
    state.playbackGeneration = 0;
    state.playing = false;
    state.transport = "stopped";
    state.status = `PLAYBACK ERROR: ${error.message}`;
    render();
  }
}

async function togglePlaying() {
  if (!bridge) return;
  try {
    const selected = visibleTracks()[state.selectedTrack];
    if (state.playing) {
      applyNativeStatus(await bridge.nativePlaybackPause());
    } else if (state.transport === "paused" && state.currentTrackId) {
      applyNativeStatus(await bridge.nativePlaybackResume());
    } else if (selected) {
      await startTrack(selected);
    }
  } catch (error) {
    state.status = `PLAYBACK ERROR: ${error.message}`;
    render();
  }
}

async function stopPlayback() {
  if (!bridge?.nativePlaybackStop) return;
  ++state.playbackToken;
  try {
    applyNativeStatus(await bridge.nativePlaybackStop());
    state.currentTrackId = null;
    state.playbackGeneration = 0;
    state.status = "STOPPED";
    render();
  } catch (error) {
    state.status = `STOP ERROR: ${error.message}`;
    render();
  }
}

function selectTrack(index, wrap = true) {
  const shownTracks = visibleTracks();
  if (!shownTracks.length) return;
  state.selectedTrack = wrap ? (index + shownTracks.length) % shownTracks.length
    : Math.max(0, Math.min(shownTracks.length - 1, index));
  if (state.selectedTrack < state.queueScroll) state.queueScroll = state.selectedTrack;
  if (state.selectedTrack >= state.queueScroll + visibleRowCount()) {
    state.queueScroll = state.selectedTrack - visibleRowCount() + 1;
  }
  announce(`Selected ${shownTracks[state.selectedTrack].title || shownTracks[state.selectedTrack].filename}`);
  render(true);
}

function playAdjacent(delta) {
  const shownTracks = visibleTracks();
  const queue = state.activeQueue.length ? state.activeQueue : shownTracks;
  if (!queue.length) return;
  const index = queue.findIndex((track) => trackID(track) === state.currentTrackId);
  const nextIndex = index < 0 ? (delta < 0 ? queue.length - 1 : 0)
    : (index + delta + queue.length) % queue.length;
  const next = queue[nextIndex];
  const visibleIndex = shownTracks.findIndex((track) => trackID(track) === trackID(next));
  if (visibleIndex >= 0) selectTrack(visibleIndex, false);
  startTrack(next, queue);
}

function selectPrevious() {
  playAdjacent(-1);
}

function selectNext() {
  playAdjacent(1);
}

async function setPreference(key, value, updateAudio = false) {
  if (!bridge?.frontendSettingsSave) return;
  const prior = state.preferences;
  state.preferences = { ...prior, [key]: value };
  render();
  try {
    await bridge.frontendSettingsSave(state.preferences);
    if (updateAudio) await configureAudio();
    if (state.currentTrackId && ["longPlayEnabled", "fadeEnabled"].includes(key)) {
      const pref = state.preferences;
      applyNativeStatus(await bridge.nativePlaybackReconfigure({
        longPlayEnabled: pref.longPlayEnabled === true,
        manualPlayMilliseconds: Math.max(0, Number(pref.manualPlayTimeSeconds ?? 180)) * 1000,
        fadeMilliseconds: pref.fadeEnabled === false ? 0 : Math.max(0, Number(pref.spcFadeSeconds ?? 6)) * 1000,
        unknownDurationMilliseconds: Math.max(1, Number(pref.unknownDurationSeconds ?? 150)) * 1000,
        tempo: 1,
      }));
    }
  } catch (error) {
    state.preferences = prior;
    state.status = `OPTION ERROR: ${error.message}`;
    render();
  }
}

function cycleRepeat() {
  const modes = ["off", "all", "one"];
  const current = modes.indexOf(state.preferences.repeatMode || "off");
  setPreference("repeatMode", modes[(current + 1) % modes.length]);
}

function changeVolume(delta) {
  const current = Number(state.preferences.appVolume ?? 1);
  const next = Math.round(Math.max(0, Math.min(1, current + delta)) * 10) / 10;
  setPreference("appVolume", next, true);
}

function logicalPoint(event) {
  const rect = canvas.getBoundingClientRect();
  return {
    x: Math.floor(((event.clientX - rect.left) / rect.width) * WIDTH),
    y: Math.floor(((event.clientY - rect.top) / rect.height) * HEIGHT),
  };
}

function findTarget(point) {
  for (let index = hitTargets.length - 1; index >= 0; index -= 1) {
    const { widget, box } = hitTargets[index];
    if (point.x >= box.x && point.x < box.x + box.width
      && point.y >= box.y && point.y < box.y + box.height) return widget;
  }
  return null;
}

canvas.addEventListener("pointermove", (event) => {
  const target = findTarget(logicalPoint(event));
  canvas.style.cursor = target ? "pointer" : "default";
});

canvas.addEventListener("click", (event) => {
  canvas.focus({ preventScroll: true });
  const target = findTarget(logicalPoint(event));
  if (target?.meta.onClick) target.meta.onClick(event);
});

canvas.addEventListener("wheel", (event) => {
  if (state.tab === "SETTINGS") return;
  event.preventDefault();
  const point = logicalPoint(event);
  const sidebarWidth = (WIDTH < 420 ? 94 : 128) * STYLE_SCALE + 8 * STYLE_SCALE;
  const library = point.x < sidebarWidth;
  const key = library ? "libraryScroll" : "queueScroll";
  const length = library ? libraryRows().length : visibleTracks().length;
  const direction = Math.sign(event.deltaY);
  state[key] = Math.max(0, Math.min(Math.max(0, length - visibleRowCount()), state[key] + direction * 3));
  render();
}, { passive: false });

canvas.addEventListener("keydown", (event) => {
  if (event.code === "Space") {
    event.preventDefault();
    togglePlaying();
  } else if (event.code === "ArrowDown") {
    event.preventDefault();
    selectTrack(state.selectedTrack + 1, false);
  } else if (event.code === "ArrowUp") {
    event.preventDefault();
    selectTrack(state.selectedTrack - 1, false);
  } else if (event.code === "Enter") {
    event.preventDefault();
    startTrack(visibleTracks()[state.selectedTrack]);
  } else if (event.code === "PageDown" || event.code === "PageUp") {
    event.preventDefault();
    selectTrack(state.selectedTrack + (event.code === "PageDown" ? 1 : -1) * visibleRowCount(), false);
  } else if (event.key === "1") {
    selectSidebarView("LIBRARY");
  } else if (event.key === "2") {
    selectSidebarView("QUEUE");
  } else if (event.key === "3") {
    state.tab = "SETTINGS";
    render();
  }
});

function fitCanvas() {
  const screenRect = screenWindow?.getBoundingClientRect();
  if (screenWindow && (!screenRect || screenRect.width <= 0 || screenRect.height <= 0)) return;
  const availableWidth = Math.max(1, (screenRect?.width || window.innerWidth) - 10);
  const availableHeight = Math.max(1, (screenRect?.height || window.innerHeight) - 10);
  const ratio = Math.max(1, window.devicePixelRatio || 1);
  const dotCssSize = DEVICE_PIXELS_PER_LCD_DOT / ratio;
  // Keep widget sizing stable while the shared screen-dot grid gets finer.
  const styleScale = BASELINE_LAYOUT_UNIT_CSS_PIXELS / dotCssSize;
  const width = Math.max(1, Math.floor(availableWidth / dotCssSize));
  const height = Math.max(1, Math.floor(availableHeight / dotCssSize));
  const changed = width !== WIDTH || height !== HEIGHT
    || ratio !== DEVICE_PIXEL_RATIO || dotCssSize !== UI_UNIT_CSS_PIXELS
    || styleScale !== STYLE_SCALE;

  WIDTH = width;
  HEIGHT = height;
  DEVICE_PIXEL_RATIO = ratio;
  UI_UNIT_CSS_PIXELS = dotCssSize;
  STYLE_SCALE = styleScale;
  canvas.style.width = `${WIDTH * UI_UNIT_CSS_PIXELS}px`;
  canvas.style.height = `${HEIGHT * UI_UNIT_CSS_PIXELS}px`;

  if (changed) {
    canvas.width = WIDTH * DEVICE_PIXELS_PER_LCD_DOT;
    canvas.height = HEIGHT * DEVICE_PIXELS_PER_LCD_DOT;
    context.imageSmoothingEnabled = false;
    pixels = new Uint8Array(WIDTH * HEIGHT);
    image = context.createImageData(
      WIDTH * DEVICE_PIXELS_PER_LCD_DOT,
      HEIGHT * DEVICE_PIXELS_PER_LCD_DOT,
    );
  }

  if (changed || !widgetTree) render();
}

const screenWindow = document.querySelector("#screen-window");
const screenResizeObserver = typeof ResizeObserver === "function" && screenWindow
  ? new ResizeObserver(fitCanvas) : null;
screenResizeObserver?.observe(screenWindow);
window.addEventListener("resize", fitCanvas);
window.addEventListener("load", fitCanvas, { once: true });
window.addEventListener("pagehide", () => {
  if (selectionAnimationFrame) cancelAnimationFrame(selectionAnimationFrame);
  if (sidebarAnimationFrame) cancelAnimationFrame(sidebarAnimationFrame);
  screenResizeObserver?.disconnect();
  if (widgetTree) widgetTree.yoga.freeRecursive();
});

requestAnimationFrame(fitCanvas);
fitCanvas();

const pendingCommands = window.__viewBoyCommandQueue || [];
window.ViewBoy = Object.freeze({
  dispatch(command) {
    switch (command) {
      case "previous": selectPrevious(); break;
      case "playPause": togglePlaying(); break;
      case "next": selectNext(); break;
      case "openPath": openLocalPath(); break;
      case "settings": state.tab = "SETTINGS"; render(); break;
      case "library": selectSidebarView("LIBRARY"); break;
      case "queue": selectSidebarView("QUEUE"); break;
      case "closeWindow": bridge?.closeMainWindow?.(); break;
      default: break;
    }
  },
});
pendingCommands.splice(0).forEach((command) => window.ViewBoy.dispatch(command));

if (bridge) {
  bridge.onNativePlaybackState?.(applyNativeStatus);
  bridge.onNativePlaybackEnded?.(handleNativeEnded);
  bridge.onFrontendSettingsChanged?.((settings) => {
    state.preferences = settings || {};
    render();
  });
  bridge.onCatalogReloaded?.(() => loadCatalog());
  bridge.onLibrarySnapshot?.((snapshot) => {
    if (Array.isArray(snapshot?.playlist)) {
      tracks = snapshot.playlist;
      state.selectedTrack = 0;
      state.tab = "QUEUE";
      render();
    }
  });
  (async () => {
    try {
      state.preferences = await bridge.frontendSettingsLoad();
      await configureAudio();
      await loadFavorites();
    } catch (error) {
      state.status = `OPTION ERROR: ${error.message}`;
      render();
    }
    await loadCatalog();
    try { applyNativeStatus(await bridge.nativePlaybackState()); } catch (_) { /* No active transport. */ }
  })();
}
