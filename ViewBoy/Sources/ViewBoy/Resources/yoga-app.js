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
const FONT_WIDTH = 5;
const FONT_HEIGHT = 7;
const FONT_ADVANCE = 6;
const PALETTE = ["#0C300C", "#285428", "#78940D", "#9BBC0F"];
const RGB = PALETTE.map((color) => {
  const value = Number.parseInt(color.slice(1), 16);
  return [(value >> 16) & 255, (value >> 8) & 255, value & 255];
});
// Compact 5x7 bitmap glyphs, one screen dot per bit, with a 6-dot advance.
const glyphs = {
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
const state = {
  tab: "LIBRARY",
  selectedTrack: 0,
  playing: false,
  transport: "stopped",
  currentTrackId: null,
  activeQueue: [],
  games: [],
  activeGameKey: null,
  expandedSystems: new Set(),
  libraryScroll: 0,
  queueScroll: 0,
  status: "LOADING CATALOG",
  preferences: {},
  nativeGeneration: 0,
  playbackGeneration: 0,
  statusSequence: 0,
  catalogToken: 0,
  playbackToken: 0,
  retiredGeneration: 0,
};

let tracks = [];

const bridge = window.spcBoyWK;

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

function displayTrack(track, index) {
  return {
    id: String(index + 1).padStart(2, "0"),
    title: track.title || track.filename || "UNTITLED",
    collection: track.game || "LOCAL FILE",
    system: track.system || "—",
    time: formatTime(track.playLengthMs),
  };
}

function floor(value) {
  return Math.round(value);
}

function fillRect(x, y, width, height, shade) {
  const left = Math.max(0, floor(x));
  const top = Math.max(0, floor(y));
  const right = Math.min(WIDTH, floor(x + width));
  const bottom = Math.min(HEIGHT, floor(y + height));
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

function drawRawText(value, x, y, shade) {
  const text = normalizedText(value);
  let cursor = floor(x);
  for (const character of text) {
    const rows = glyphs[character] ?? glyphs["?"];
    for (let row = 0; row < FONT_HEIGHT; row += 1) {
      for (let column = 0; column < FONT_WIDTH; column += 1) {
        if (rows[row][column] === "1") {
          const px = cursor + column;
          const py = floor(y) + row;
          if (px >= 0 && px < WIDTH && py >= 0 && py < HEIGHT) {
            const index = py * WIDTH + px;
            pixels[index] = shade;
          }
        }
      }
    }
    cursor += FONT_ADVANCE;
  }
}

function drawText(value, x, y, width, shade = 0, align = "left") {
  const maxCharacters = Math.max(0, Math.floor((width + 1) / FONT_ADVANCE));
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
  const measuredWidth = Math.max(0, Array.from(text).length * FONT_ADVANCE - 1);
  let textX = x;
  if (align === "center") textX += Math.floor((width - measuredWidth) / 2);
  if (align === "right") textX += width - measuredWidth;
  drawRawText(text, textX, y, shade);
}

function line(x1, y1, x2, y2, shade) {
  if (y1 === y2) fillRect(x1, y1, x2 - x1, 1, shade);
  else if (x1 === x2) fillRect(x1, y1, 1, y2 - y1, shade);
}

function present() {
  const target = image.data;
  const outputWidth = WIDTH * DEVICE_PIXELS_PER_LCD_DOT;
  for (let index = 0; index < pixels.length; index += 1) {
    const x = index % WIDTH;
    const y = Math.floor(index / WIDTH);
    const baseShade = pixels[index];
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
  context.putImageData(image, 0, 0);
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
      if (meta.fill !== undefined) fillRect(box.x, box.y, box.width, box.height, meta.fill);
      if (meta.border !== undefined) strokeRect(box.x, box.y, box.width, box.height, meta.border);
      if (meta.bottomLine !== undefined) {
        line(box.x, box.y + box.height - 1, box.x + box.width, box.y + box.height, meta.bottomLine);
      }
      if (meta.paint) meta.paint(box);
      const textY = box.y + Math.floor((box.height - FONT_HEIGHT) / 2);
      drawText(text, box.x + (meta.inset ?? 2), textY, box.width - (meta.inset ?? 2) * 2,
        meta.textShade ?? 0, meta.align ?? "left");
    },
  });
}

function panelTitle(parent, text, suffix = "", suffixWidth = 40) {
  const row = makeWidget(parent, {
    direction: FlexDirection.Row,
    height: 6,
    alignItems: Align.Center,
  }, {
    fill: 2,
    paint(box) {
      fillRect(box.x, box.y, box.width, box.height, 2);
    },
  });
  label(row, text, { flexGrow: 1, height: 6 }, { textShade: 0, inset: 2 });
  if (suffix) label(row, suffix, { width: suffixWidth, height: 6 }, { textShade: 0, align: "right", inset: 2 });
  return row;
}

function pixelButton(parent, text, onClick, style = {}) {
  return label(parent, text, {
    direction: FlexDirection.Row,
    alignItems: Align.Center,
    justifyContent: Justify.Center,
    height: style.height ?? 12,
    flexGrow: style.flexGrow ?? 1,
  }, {
    border: style.active ? 0 : 1,
    textShade: 0,
    inset: 2,
    align: "center",
    onClick,
  });
}

function tableColumns() {
  const columns = [
    { key: "id", title: "#", width: 12, align: "center" },
    { key: "title", title: "TRACK TITLE", flexGrow: 1 },
  ];
  if (WIDTH >= 390) columns.push({ key: "collection", title: "COLLECTION", width: 66 });
  if (WIDTH >= 490) columns.push({ key: "system", title: "SYSTEM", width: 54 });
  columns.push({ key: "time", title: "TIME", width: 25, align: "right" });
  return columns;
}

function createTableHeader(parent, columns) {
  const header = makeWidget(parent, {
    direction: FlexDirection.Row,
    alignItems: Align.Center,
    height: 8,
    gap: 2,
  }, {
    paint(box) {
      line(box.x, box.y + box.height - 1, box.x + box.width, box.y + box.height, 1);
    },
  });
  columns.forEach((column) => label(header, column.title, {
    width: column.width,
    flexGrow: column.flexGrow,
    height: 7,
  }, {
    textShade: 0,
    inset: 0,
    align: column.align ?? "left",
  }));
  return header;
}

function createQueueRow(parent, index, track, columns) {
  const selected = index === state.selectedTrack;
  const values = displayTrack(track, index);
  const row = makeWidget(parent, {
    direction: FlexDirection.Row,
    alignItems: Align.Center,
    height: 6,
    gap: 2,
  }, {
    onClick: (event) => {
      selectTrack(index, false);
      if (event.detail >= 2) startTrack(track);
    },
    paint(box) {
      if (selected) fillRect(box.x, box.y, box.width, box.height, 2);
    },
  });
  columns.forEach((column) => label(row, values[column.key], {
    width: column.width,
    flexGrow: column.flexGrow,
    height: 6,
  }, {
    textShade: 0,
    inset: 0,
    align: column.align ?? "left",
  }));
  return row;
}

function createLibraryRow(parent, text, options = {}) {
  const selected = options.selected ?? false;
  return label(parent, text, {
    height: 6,
    paddingHorizontal: 2,
  }, {
    textShade: 0,
    onClick: options.onClick,
    inset: options.indent ?? 1,
    paint(box) {
      if (selected) fillRect(box.x, box.y, box.width, box.height, 2);
    },
  });
}

function visibleRowCount() {
  return Math.max(1, Math.floor((HEIGHT / STYLE_SCALE - 85) / 6));
}

function libraryRows() {
  const groups = new Map();
  for (const game of state.games) {
    const system = game.system || "OTHER";
    if (!groups.has(system)) groups.set(system, []);
    groups.get(system).push(game);
  }
  const rows = [];
  for (const system of [...groups.keys()].sort()) {
    rows.push({ text: `${state.expandedSystems.has(system) ? "V" : ">"} ${system}`, system });
    if (state.expandedSystems.has(system)) {
      for (const game of groups.get(system)) {
        rows.push({ text: game.displayName || game.name, game, indent: 7 });
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
  panelTitle(library, "LIBRARY", String(state.games.length));
  const rows = libraryRows();
  const count = visibleRowCount();
  state.libraryScroll = Math.max(0, Math.min(state.libraryScroll, Math.max(0, rows.length - count)));
  rows.slice(state.libraryScroll, state.libraryScroll + count).forEach((row) => {
    createLibraryRow(library, row.text, {
      selected: row.game && gameKey(row.game) === state.activeGameKey,
      indent: row.indent,
      onClick: row.game ? () => loadGame(row.game) : () => toggleSystem(row.system),
    });
  });
  label(library, `${rows.length ? state.libraryScroll + 1 : 0}-${Math.min(rows.length, state.libraryScroll + count)} / ${rows.length}`, {
    flexGrow: 1, height: 6,
  }, { textShade: 0, align: "right", inset: 1 });
  return library;
}

function addCatalogPane(parent, mode) {
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
  panelTitle(panel, mode === "QUEUE" ? "PLAY QUEUE" : "TRACK CATALOG",
    `${tracks.length} TRACKS`, 60);
  const columns = tableColumns();
  createTableHeader(panel, columns);
  const count = visibleRowCount();
  state.queueScroll = Math.max(0, Math.min(state.queueScroll, Math.max(0, tracks.length - count)));
  tracks.slice(state.queueScroll, state.queueScroll + count).forEach((track, offset) =>
    createQueueRow(panel, state.queueScroll + offset, track, columns));
  if (!tracks.length) label(panel, state.status, { height: 12 }, { textShade: 0, inset: 1 });
  label(panel, `${tracks.length ? state.queueScroll + 1 : 0}-${Math.min(tracks.length, state.queueScroll + count)} / ${tracks.length}`, {
    flexGrow: 1,
    height: 6,
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
    ["LCD DOT", "3 DEVICE PX"],
    ["FONT", "BITMAP 5 X 7"],
    ["LONG PLAY", pref.longPlayEnabled ? "ON" : "OFF", () => setPreference("longPlayEnabled", !pref.longPlayEnabled)],
    ["END FADE", pref.fadeEnabled === false ? "OFF" : "ON", () => setPreference("fadeEnabled", pref.fadeEnabled === false)],
    ["REPEAT", String(pref.repeatMode || "off"), () => cycleRepeat()],
    ["MONO", pref.monoEnabled ? "ON" : "OFF", () => setPreference("monoEnabled", !pref.monoEnabled, true)],
    ["VOLUME -", `${Math.round(Number(pref.appVolume ?? 1) * 100)}%`, () => changeVolume(-0.1)],
    ["VOLUME +", `${Math.round(Number(pref.appVolume ?? 1) * 100)}%`, () => changeVolume(0.1)],
    ["RELOAD LIBRARY", "RUN", () => loadCatalog()],
  ];
  rows.forEach(([name, value, onClick]) => {
    const row = makeWidget(panel, {
      direction: FlexDirection.Row,
      alignItems: Align.Center,
      height: 9,
      paddingHorizontal: 2,
    }, {
      onClick,
      paint(box) {
        line(box.x, box.y + box.height - 1, box.x + box.width, box.y + box.height, 2);
      },
    });
    label(row, name, { flexGrow: 1, height: 8 }, { textShade: 0, inset: 1 });
    label(row, value, { width: 82, height: 8 }, {
      textShade: 0,
      align: "right",
      inset: 1,
    });
  });
}

function buildTree() {
  const root = makeWidget(null, {
    direction: FlexDirection.Column,
    width: WIDTH / STYLE_SCALE,
    height: HEIGHT / STYLE_SCALE,
    padding: 8,
    gap: 3,
    alignItems: Align.Stretch,
  }, {
    paint() {
      fillRect(0, 0, WIDTH, HEIGHT, 3);
    },
  });

  // App pages are the first toolbar row.
  const tabs = makeWidget(root, {
    direction: FlexDirection.Row,
    height: 12,
    gap: 2,
  });
  ["LIBRARY", "QUEUE", "SETTINGS"].forEach((tab) => {
    const active = state.tab === tab;
    label(tabs, tab, { flexGrow: 1, height: 12 }, {
      border: active ? 0 : 1,
      textShade: 0,
      align: "center",
      inset: 0,
      onClick: () => {
        state.tab = tab;
        render();
      },
    });
  });

  // Compact transport controls fill the second toolbar row.
  const controls = makeWidget(root, {
    direction: FlexDirection.Row,
    height: 12,
    gap: 2,
  });
  pixelButton(controls, "PREV", () => selectPrevious());
  pixelButton(controls, state.playing ? "PAUSE" : "PLAY", () => togglePlaying(), { active: true });
  pixelButton(controls, "NEXT", () => selectNext());
  pixelButton(controls, "STOP", () => stopPlayback());

  const content = makeWidget(root, {
    direction: FlexDirection.Row,
    flexGrow: 1,
    gap: 3,
    alignItems: Align.Stretch,
  });
  if (state.tab === "SETTINGS") {
    addOptionsContent(content);
  } else if (state.tab === "LIBRARY") {
    addLibraryPane(content);
    addCatalogPane(content, "LIBRARY");
  } else {
    addCatalogPane(content, "QUEUE");
  }

  const bottom = makeWidget(root, {
    direction: FlexDirection.Row,
    alignItems: Align.Center,
    height: 12,
  }, {
    paint(box) {
      line(box.x, box.y, box.x + box.width, box.y, 2);
    },
  });
  const current = state.activeQueue.find((track) => trackID(track) === state.currentTrackId);
  const selected = tracks[state.selectedTrack];
  label(bottom, "NOW / " + (current?.title || current?.filename || selected?.title || selected?.filename || state.status), {
    flexGrow: 1,
    height: 10,
  }, {
    textShade: 0,
    inset: 0,
  });
  label(bottom, state.playing ? "PLAYING" : state.transport.toUpperCase(), {
    width: 48,
    height: 10,
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

function render() {
  if (widgetTree) widgetTree.yoga.freeRecursive();
  boxesById = new Map();
  hitTargets = [];
  pixels.fill(3);
  widgetTree = buildTree();
  collect(widgetTree);
  paintTree(widgetTree, { x: 0, y: 0, width: WIDTH, height: HEIGHT });
  present();
  const selected = tracks[state.selectedTrack];
  status.textContent = `${state.tab}. ${state.status}. ${state.transport}. `
    + (selected ? `Selected track ${state.selectedTrack + 1}: ${selected.title || selected.filename}.` : "No track selected.");
}

function announce(message) {
  status.textContent = message;
}

function toggleSystem(system) {
  if (state.expandedSystems.has(system)) state.expandedSystems.delete(system);
  else state.expandedSystems.add(system);
  render();
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
      state.expandedSystems.add(game.system || "OTHER");
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
  state.activeGameKey = gameKey(game);
  state.status = `LOADING ${game.displayName || game.name}`;
  render();
  try {
    const rows = await bridge.databaseGameTracks([game]);
    if (token !== state.catalogToken || rows?.stale) return;
    tracks = Array.isArray(rows) ? rows : [];
    state.selectedTrack = 0;
    state.queueScroll = 0;
    state.status = tracks.length ? (game.displayName || game.name) : "NO TRACKS";
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
      const visibleIndex = tracks.findIndex((track) => trackID(track) === trackID(next));
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

async function startTrack(track, queue = tracks) {
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
    const selected = tracks[state.selectedTrack];
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
  if (!tracks.length) return;
  state.selectedTrack = wrap ? (index + tracks.length) % tracks.length
    : Math.max(0, Math.min(tracks.length - 1, index));
  if (state.selectedTrack < state.queueScroll) state.queueScroll = state.selectedTrack;
  if (state.selectedTrack >= state.queueScroll + visibleRowCount()) {
    state.queueScroll = state.selectedTrack - visibleRowCount() + 1;
  }
  announce(`Selected ${tracks[state.selectedTrack].title || tracks[state.selectedTrack].filename}`);
  render();
}

function playAdjacent(delta) {
  const queue = state.activeQueue.length ? state.activeQueue : tracks;
  if (!queue.length) return;
  const index = queue.findIndex((track) => trackID(track) === state.currentTrackId);
  const nextIndex = index < 0 ? (delta < 0 ? queue.length - 1 : 0)
    : (index + delta + queue.length) % queue.length;
  const next = queue[nextIndex];
  const visibleIndex = tracks.findIndex((track) => trackID(track) === trackID(next));
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
  const library = state.tab === "LIBRARY" && point.x < sidebarWidth;
  const key = library ? "libraryScroll" : "queueScroll";
  const length = library ? libraryRows().length : tracks.length;
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
    startTrack(tracks[state.selectedTrack]);
  } else if (event.code === "PageDown" || event.code === "PageUp") {
    event.preventDefault();
    selectTrack(state.selectedTrack + (event.code === "PageDown" ? 1 : -1) * visibleRowCount(), false);
  } else if (event.key === "1") {
    state.tab = "LIBRARY";
    render();
  } else if (event.key === "2") {
    state.tab = "QUEUE";
    render();
  } else if (event.key === "3") {
    state.tab = "SETTINGS";
    render();
  }
});

function fitCanvas() {
  const frameInset = 28;
  const availableWidth = Math.max(1, window.innerWidth - frameInset);
  const availableHeight = Math.max(1, window.innerHeight - frameInset);
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

window.addEventListener("resize", fitCanvas);
window.addEventListener("pagehide", () => {
  if (widgetTree) widgetTree.yoga.freeRecursive();
});

fitCanvas();

const pendingCommands = window.__viewBoyCommandQueue || [];
window.SPCBoyWK = Object.freeze({
  dispatch(command) {
    switch (command) {
      case "previous": selectPrevious(); break;
      case "playPause": togglePlaying(); break;
      case "next": selectNext(); break;
      case "openPath": openLocalPath(); break;
      case "settings": state.tab = "SETTINGS"; render(); break;
      case "library": state.tab = "LIBRARY"; render(); break;
      case "queue": state.tab = "QUEUE"; render(); break;
      case "closeWindow": bridge?.closeMainWindow?.(); break;
      default: break;
    }
  },
});
pendingCommands.splice(0).forEach((command) => window.SPCBoyWK.dispatch(command));

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
    } catch (error) {
      state.status = `OPTION ERROR: ${error.message}`;
      render();
    }
    await loadCatalog();
    try { applyNativeStatus(await bridge.nativePlaybackState()); } catch (_) { /* No active transport. */ }
  })();
}
