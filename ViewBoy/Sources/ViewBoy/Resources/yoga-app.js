import Yoga, {
  Align,
  BoxSizing,
  Direction,
  Edge,
  FlexDirection,
  Gutter,
  Justify,
  Overflow,
  PositionType,
} from "./yoga-layout.js";

// Each LCD dot occupies three physical display pixels per side. On a Retina
// display (2x), that is a 1.5-CSS-pixel dot with a 2x2 face and a fine edge.
const DEVICE_PIXELS_PER_LCD_DOT = 3;
const LCD_FACE_DEVICE_PIXELS = DEVICE_PIXELS_PER_LCD_DOT - 1;
const BASELINE_LAYOUT_UNIT_CSS_PIXELS = 2.5;
const RANDOM_HISTORY_LIMIT = 256;
const BUTTON_BORDER_DOTS = 1;
const BUTTON_HORIZONTAL_INSET_DOTS = 2;
const BUTTON_VERTICAL_INSET_DOTS = 2;
const PANE_INSET_DOTS = 2;
const UI_SPACING_DOTS = Object.freeze({
  minimumGap: 2,
  sectionGap: 6,
  groupInset: 4,
  optionsInset: 6,
});
const EQ_BAR_MIN_DOTS = 100;
const EQ_GAIN_STEPS = 48;
const ANIMATION_FRAME_INTERVAL_MS = 1000 / 60;
const PALETTES = {
  GAMEBOY: {
    STANDARD: ["#0C300C", "#285428", "#78940D", "#9BBC0F"],
    HIGH_CONTRAST: ["#333333", "#285428", "#78940D", "#9BBC0F"],
  },
  NIGHTBOY: {
    STANDARD: ["#D8D6DF", "#A5A2AF", "#51495E", "#211A2B"],
    HIGH_CONTRAST: ["#F0EFF4", "#A5A2AF", "#51495E", "#211A2B"],
  },
};
function paletteRGB(palette) {
  return palette.map((color) => {
    const value = Number.parseInt(color.slice(1), 16);
    return [(value >> 16) & 255, (value >> 8) & 255, value & 255];
  });
}
let RGB = paletteRGB(PALETTES.GAMEBOY.STANDARD);
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
  "•": ["00000", "00000", "00100", "00000", "00000", "00000", "00000"],
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
  "•": ["000", "000", "010", "000", "000"],
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
const savedDisplayOptions = storedDisplayOptions();
function displayPalette() {
  return PALETTES[state.theme][state.contrast];
}
function saveDisplayOptions() {
  try {
    localStorage.setItem(DISPLAY_OPTIONS_KEY, JSON.stringify({
      font: state.font,
      contrast: state.contrast,
      theme: state.theme,
      columnOrder: state.columnOrder,
    }));
  }
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
let columnAnimationFrame = 0;
let columnLayoutAnimation = null;
let lastColumnWidths = null;
let currentRenderTime = 0;
let paintClip = null;
let pointerInteraction = null;
let suppressNextClick = false;
const state = {
  tab: "LIBRARY",
  playlistTabs: [],
  activePlaylistTabId: null,
  playlistTabsReady: false,
  playlistSaveChain: Promise.resolve(),
  selectedTrack: 0,
  playing: false,
  font: savedDisplayOptions.font === "STANDARD" ? "STANDARD" : "MICRO",
  contrast: savedDisplayOptions.contrast === "HIGH_CONTRAST" ? "HIGH_CONTRAST" : "STANDARD",
  theme: savedDisplayOptions.theme === "NIGHTBOY" ? "NIGHTBOY" : "GAMEBOY",
  optionsPage: "DISPLAY",
  transport: "stopped",
  currentTrackId: null,
  activeQueue: [],
  randomSeenIDs: new Set(),
  randomQueueSignature: "",
  randomPlaylistQueue: [],
  randomHistory: [],
  randomHistoryIndex: -1,
  equalizerBarBoxes: [],
  libraryRandomToken: 0,
  games: [],
  favoriteTracks: [],
  favoriteIDs: new Set(),
  selectedSystem: null,
  selectedGameKey: null,
  sortColumn: null,
  sortDirection: "ASCENDING",
  columnOrder: Array.isArray(savedDisplayOptions.columnOrder)
    ? savedDisplayOptions.columnOrder.filter((key) => typeof key === "string") : [],
  tableHorizontalScroll: 0,
  tableHorizontalMax: 0,
  tableViewportWidth: 0,
  tableViewportBox: null,
  tableContentWidth: 0,
  tableScrollbarBox: null,
  tableScrollbarThumb: null,
  tableViewportWidget: null,
  tableContentWidget: null,
  tableContentMinimumWidth: 0,
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
  preferenceMutationToken: 0,
  preferenceSaveChain: Promise.resolve(),
  catalogToken: 0,
  groupTransitionToken: 0,
  playbackToken: 0,
  retiredGeneration: 0,
  columnMenu: null,
};
RGB = paletteRGB(displayPalette());
if (document.documentElement) document.documentElement.dataset.theme = state.theme;

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
  if (state.tab === "QUEUE") return state.activeQueue.length
    ? state.activeQueue : (activePlaylistTab()?.playlist || tracks);
  if (state.tab === "FAVORITES") return state.favoriteTracks;
  return activePlaylistTab()?.playlist || tracks;
}

function activePlaylistTab() {
  return state.playlistTabs.find((tab) => tab.id === state.activePlaylistTabId) || null;
}

function samePlaylist(first, second) {
  return first.length === second.length
    && first.every((track, index) => trackID(track) === trackID(second[index]));
}

function playlistTabID() {
  return globalThis.crypto?.randomUUID?.()
    || `viewboy-${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

function syncActivePlaylistTab() {
  const tab = activePlaylistTab();
  if (!tab || state.tab === "FAVORITES" || state.tab === "SETTINGS") return;
  tab.playlist = [...(state.tab === "QUEUE" && state.activeQueue.length ? state.activeQueue : tracks)];
  tab.selectedTrack = state.selectedTrack;
  tab.scroll = state.queueScroll;
  tab.gameKey = state.activeGameKey;
}

function persistPlaylistTabs() {
  if (!state.playlistTabsReady || !bridge?.playlistTabsSave) return;
  syncActivePlaylistTab();
  const payload = {
    version: 1,
    activeID: state.activePlaylistTabId,
    tabs: state.playlistTabs.slice(0, 64).map((tab) => ({
      id: tab.id,
      title: tab.title,
      gameKey: tab.gameKey || null,
      playlist: Array.isArray(tab.playlist) ? tab.playlist : [],
      selectedTrack: Math.max(0, Number(tab.selectedTrack) || 0),
      scroll: Math.max(0, Number(tab.scroll) || 0),
    })),
  };
  state.playlistSaveChain = state.playlistSaveChain.catch(() => {})
    .then(() => bridge.playlistTabsSave(payload))
    .catch((error) => { console.error("[ViewBoy] playlist tabs could not be saved", error); });
}

function restorePlaylistTabs(value) {
  if (value?.version !== 1 || !Array.isArray(value.tabs)) return false;
  const seen = new Set();
  const restored = value.tabs.slice(0, 64).filter((tab) => {
    if (!tab || typeof tab.id !== "string" || !tab.id || seen.has(tab.id)) return false;
    seen.add(tab.id);
    return true;
  }).map((tab) => ({
    id: tab.id,
    title: typeof tab.title === "string" && tab.title.trim() ? tab.title : "PLAYLIST",
    gameKey: typeof tab.gameKey === "string" ? tab.gameKey : null,
    playlist: Array.isArray(tab.playlist) ? tab.playlist : [],
    selectedTrack: Math.max(0, Number(tab.selectedTrack) || 0),
    scroll: Math.max(0, Number(tab.scroll) || 0),
  }));
  if (!restored.length) return false;
  state.playlistTabs = restored;
  state.activePlaylistTabId = seen.has(value.activeID) ? value.activeID : restored[0].id;
  const active = activePlaylistTab();
  tracks = [...active.playlist];
  state.activeQueue = [...active.playlist];
  state.activeGameKey = active.gameKey;
  state.selectedGameKey = active.gameKey;
  state.selectedTrack = Math.min(active.selectedTrack, Math.max(0, active.playlist.length - 1));
  state.queueScroll = active.scroll;
  state.tab = "LIBRARY";
  return true;
}

function activatePlaylistTab(id) {
  const tab = state.playlistTabs.find((entry) => entry.id === id);
  if (!tab) return false;
  if (tab.id !== state.activePlaylistTabId) syncActivePlaylistTab();
  else if (state.tab !== "SETTINGS" && state.tab !== "FAVORITES") return false;
  state.activePlaylistTabId = tab.id;
  tracks = [...tab.playlist];
  state.activeQueue = [...tab.playlist];
  state.activeGameKey = tab.gameKey;
  state.selectedTrack = Math.min(tab.selectedTrack || 0, Math.max(0, tab.playlist.length - 1));
  state.queueScroll = Math.max(0, tab.scroll || 0);
  state.tableHorizontalScroll = 0;
  state.tab = "QUEUE";
  render();
  persistPlaylistTabs();
  return true;
}

function createPlaylistTab({ duplicateActive = true, title = null, playlist = null, gameKey = null } = {}) {
  syncActivePlaylistTab();
  if (state.playlistTabs.length >= 64) return null;
  const source = activePlaylistTab();
  const next = {
    id: playlistTabID(),
    title: String(title || `PLAYLIST ${state.playlistTabs.length + 1}`),
    gameKey,
    playlist: Array.isArray(playlist) ? [...playlist]
      : duplicateActive && source ? [...source.playlist] : [],
    selectedTrack: duplicateActive && source ? source.selectedTrack : 0,
    scroll: duplicateActive && source ? source.scroll : 0,
  };
  state.playlistTabs.push(next);
  state.activePlaylistTabId = next.id;
  tracks = [...next.playlist];
  state.activeQueue = [...next.playlist];
  state.activeGameKey = next.gameKey;
  state.selectedTrack = Math.min(next.selectedTrack, Math.max(0, next.playlist.length - 1));
  state.queueScroll = next.scroll;
  state.tab = "QUEUE";
  state.tableHorizontalScroll = 0;
  render();
  persistPlaylistTabs();
  return next;
}

function closePlaylistTab(id = state.activePlaylistTabId) {
  const index = state.playlistTabs.findIndex((tab) => tab.id === id);
  if (index < 0) return false;
  if (state.playlistTabs.length === 1) {
    const tab = state.playlistTabs[0];
    tab.title = "PLAYLIST";
    tab.gameKey = null;
    tab.playlist = [];
    tab.selectedTrack = 0;
    tab.scroll = 0;
    if (tab.id === state.activePlaylistTabId) {
      tracks = [];
      state.activeQueue = state.currentTrackId ? state.activeQueue : [];
      state.selectedTrack = 0;
      state.queueScroll = 0;
      state.activeGameKey = null;
      state.tab = "LIBRARY";
    }
  } else {
    const wasActive = state.playlistTabs[index].id === state.activePlaylistTabId;
    state.playlistTabs.splice(index, 1);
    if (wasActive) {
      const next = state.playlistTabs[Math.min(index, state.playlistTabs.length - 1)];
      state.activePlaylistTabId = null;
      activatePlaylistTab(next.id);
      return true;
    }
  }
  render();
  persistPlaylistTabs();
  return true;
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

function animationEnabled(key) {
  return state.preferences[key] !== false;
}

function animationMilliseconds(key) {
  const value = Number(state.preferences[key]);
  if (!Number.isFinite(value)) return 200;
  return Math.max(0, Math.min(1000, value));
}

export function animationFrameIsDue(animation, time) {
  if (!Number.isFinite(animation.lastFrameAt)
    || time - animation.lastFrameAt >= ANIMATION_FRAME_INTERVAL_MS - 0.25) {
    animation.lastFrameAt = time;
    return true;
  }
  return false;
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
  if (style.positionType !== undefined) yoga.setPositionType(style.positionType);
  if (style.width !== undefined) yoga.setWidth(style.width * STYLE_SCALE);
  if (style.minWidth !== undefined) yoga.setMinWidth(style.minWidth * STYLE_SCALE);
  if (style.height !== undefined) yoga.setHeight(style.height * STYLE_SCALE);
  if (style.left !== undefined) yoga.setPosition(Edge.Left, style.left * STYLE_SCALE);
  if (style.top !== undefined) yoga.setPosition(Edge.Top, style.top * STYLE_SCALE);
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
      if (meta.clipToBox) paintClip = intersectBoxes(paintClip, box);
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

function buttonStandardHeight() {
  return rowHeight(2 * BUTTON_VERTICAL_INSET_DOTS + 2 * BUTTON_BORDER_DOTS);
}

function uiGap() {
  return UI_SPACING_DOTS.minimumGap / STYLE_SCALE;
}

function uiSectionGap() {
  return UI_SPACING_DOTS.sectionGap / STYLE_SCALE;
}

function textLayoutWidth(text, horizontalInsetDots = BUTTON_HORIZONTAL_INSET_DOTS) {
  return (Array.from(String(text)).length * fontProfile().advance + horizontalInsetDots * 2) / STYLE_SCALE;
}

function framedTextWidth(text) {
  return (Array.from(String(text)).length * fontProfile().advance
    + (BUTTON_BORDER_DOTS + BUTTON_HORIZONTAL_INSET_DOTS) * 2) / STYLE_SCALE;
}

function buttonWidth(text) {
  return framedTextWidth(text);
}

function minimumColumnWidth(characterCount = 1) {
  return (characterCount * fontProfile().advance
    + (BUTTON_BORDER_DOTS + BUTTON_HORIZONTAL_INSET_DOTS) * 2) / STYLE_SCALE;
}

function oneDot() {
  return 1 / STYLE_SCALE;
}

function libraryToolbarItems() {
  return [
    { title: "LIB", view: "LIBRARY", onClick: () => selectSidebarView("LIBRARY") },
    { title: "Q", view: "QUEUE", onClick: () => selectSidebarView("QUEUE") },
    { title: "FAV", view: "FAVORITES", onClick: () => selectSidebarView("FAVORITES") },
    { title: "OPEN", onClick: () => openLocalPath() },
    { title: "SYNC", onClick: () => loadCatalog() },
  ];
}

function libraryPaneWidth() {
  const items = libraryToolbarItems();
  const buttonsWidth = items.reduce((sum, item) => sum + buttonWidth(item.title), 0);
  return Math.max(WIDTH < 420 ? 94 : 128,
    buttonsWidth + Math.max(0, items.length - 1) * uiGap() + 4);
}

function statusBar(parent, text) {
  const height = buttonStandardHeight();
  const row = makeWidget(parent, {
    direction: FlexDirection.Row,
    alignItems: Align.Center,
    height,
  }, {
    paint(box) { line(box.x, box.y, box.x + box.width, box.y, 1); },
  });
  label(row, text, { flexGrow: 1, height }, {
    textShade: 0,
    align: "center",
    inset: BUTTON_HORIZONTAL_INSET_DOTS,
  });
  return row;
}

function panelTitle(parent, text) {
  const titleHeight = buttonStandardHeight();
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
  label(row, text, { flexGrow: 1, height: titleHeight }, { textShade: 0, inset: 2, align: "center" });
  return row;
}

function pixelButton(parent, text, onClick, style = {}) {
  return label(parent, text, {
    direction: FlexDirection.Row,
    alignItems: Align.Center,
    justifyContent: Justify.Center,
    height: buttonStandardHeight(),
    width: style.width ?? buttonWidth(text),
    flexGrow: style.flexGrow ?? 0,
  }, {
    border: 1,
    fill: style.selected ? 2 : undefined,
    textShade: 0,
    inset: BUTTON_HORIZONTAL_INSET_DOTS,
    align: "center",
    onClick,
  });
}

function controlRow(parent, style = {}, meta = {}) {
  return makeWidget(parent, {
    direction: FlexDirection.Row,
    alignItems: Align.Center,
    height: buttonStandardHeight(),
    gap: uiGap(),
    ...style,
  }, meta);
}

function optionSection(parent, title) {
  return panelTitle(parent, title);
}

function optionToggle(parent, title, checked, onClick, extraMeta = {}) {
  const height = buttonStandardHeight();
  const row = makeWidget(parent, {
    direction: FlexDirection.Row,
    alignItems: Align.Center,
    height,
    gap: uiGap(),
    paddingHorizontal: BUTTON_HORIZONTAL_INSET_DOTS,
  }, {
    onClick,
    paint(box) {
      strokeRect(box.x, box.y, box.width, box.height, 1);
    },
    ...extraMeta,
  });
  const marker = checked ? "[•]" : "[]";
  label(row, marker, {
    width: textLayoutWidth(marker),
    height: fontProfile().height / STYLE_SCALE,
  }, { textShade: 0, align: "center", inset: BUTTON_HORIZONTAL_INSET_DOTS });
  label(row, title, { flexGrow: 1, height }, { textShade: 0, inset: BUTTON_HORIZONTAL_INSET_DOTS });
  return row;
}

function optionChoice(parent, title, choices) {
  const height = buttonStandardHeight();
  const row = controlRow(parent, {
    height,
    gap: uiGap(),
  }, {
    paint(box) {
      line(box.x, box.y + box.height - 1, box.x + box.width, box.y + box.height, 2);
    },
  });
  const titleWidth = textLayoutWidth(title);
  label(row, title, { width: titleWidth, height }, { textShade: 0, inset: BUTTON_HORIZONTAL_INSET_DOTS });
  choices.forEach((choice) => pixelButton(row, choice.title, choice.onClick, {
    flexGrow: 1,
    selected: choice.selected,
  }));
  return row;
}

function optionAdjuster(parent, title, value, onDecrease, onIncrease) {
  const height = buttonStandardHeight();
  const row = controlRow(parent, { height }, {
    paint(box) {
      line(box.x, box.y + box.height - 1, box.x + box.width, box.y + box.height, 2);
    },
  });
  label(row, title, { flexGrow: 1, height }, { textShade: 0, inset: 1 });
  const controlHeight = buttonStandardHeight();
  pixelButton(row, "[-]", onDecrease);
  label(row, value, { width: framedTextWidth(value), height: controlHeight }, {
    border: 1,
    textShade: 0,
    align: "center",
    inset: BUTTON_HORIZONTAL_INSET_DOTS,
  });
  pixelButton(row, "[+]", onIncrease);
  return row;
}

function formatSize(bytes) {
  const value = Number(bytes);
  if (!Number.isFinite(value) || value <= 0) return "";
  if (value < 1024 * 1024) return `${Math.round(value / 1024)}K`;
  return `${(value / (1024 * 1024)).toFixed(1)}M`;
}

function tableValue(track, key, rowIndex = 0) {
  switch (key) {
    case "favorite": return state.favoriteIDs.has(trackID(track)) ? "[x]" : "[]";
    case "index": return String(rowIndex + 1);
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

const configurableColumns = [
  { key: "filename", title: "FILE" },
  { key: "game", title: "GAME" },
  { key: "artist", title: "ARTIST" },
  { key: "path", title: "PATH" },
  { key: "size", title: "SIZE" },
];
const tableContentLengthCache = new WeakMap();

function tableContentLengths(items, columns) {
  const cached = tableContentLengthCache.get(items);
  if (cached) return cached;

  const measured = {
    lengths: Object.fromEntries(columns
      .filter((column) => !["favorite", "index", "title"].includes(column.key))
      .map((column) => [column.key, Array.from(normalizedText(column.title)).length])),
  };
  items.forEach((track, index) => {
    for (const column of columns) {
      if (["favorite", "index", "title"].includes(column.key)) continue;
      const value = tableValue(track, column.key, index);
      const valueLength = Array.from(normalizedText(value)).length;
      measured.lengths[column.key] = Math.max(measured.lengths[column.key] ?? 0, valueLength);
    }
  });
  tableContentLengthCache.set(items, measured);
  return measured;
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
  const minimumTitleWidth = (20 * fontProfile().advance) / STYLE_SCALE;
  const columns = [
    {
      key: "index",
      title: "#",
      width: minimumColumnWidth(String(Math.max(1, items.length)).length),
      align: "center",
      rowAlign: "right",
      mandatory: true,
      reorderable: false,
      sortable: false,
    },
    { key: "favorite", title: "FAV", width: minimumColumnWidth(3), align: "center", mandatory: true, sortable: false },
    { key: "filename", title: "FILE", width: 34 },
    { key: "title", title: "TITLE", width: minimumTitleWidth, flexGrow: 1, mandatory: true },
    { key: "game", title: "GAME", width: 40 },
    { key: "artist", title: "ARTIST", width: 40 },
    { key: "system", title: "SYSTEM", width: 28, mandatory: true },
    { key: "path", title: "PATH", width: 58 },
    { key: "length", title: "LENGTH", width: 32, align: "right", mandatory: true },
    { key: "size", title: "SIZE", width: 28 },
  ];

  // Reserve the sort-marker cell in every sortable heading. Without this
  // floor, an auto-sized header can clip its arrow even though row widths and
  // the 250 ms resize animation are using the same column measurements.
  columns.forEach((column) => {
    if (column.key === "favorite" || column.key === "index") return;
    const headingCharacters = Array.from(column.title).length + 1;
    const headingWidth = (headingCharacters * fontProfile().advance
      + 2 * (BUTTON_BORDER_DOTS + BUTTON_HORIZONTAL_INSET_DOTS)) / STYLE_SCALE;
    column.width = Math.max(column.width, headingWidth);
  });

  const autoSize = state.preferences.columnAutoSize !== false;
  const content = tableContentLengths(items, columns);
  if (autoSize) {
    columns.forEach((column) => {
      if (column.key === "favorite" || column.key === "index" || column.key === "title") return;
      const textWidth = ((content.lengths[column.key] ?? 0) * fontProfile().advance
        + 2 * (BUTTON_BORDER_DOTS + BUTTON_HORIZONTAL_INSET_DOTS)) / STYLE_SCALE;
      const headingCharacters = Array.from(column.title).length + 1;
      const headingWidth = (headingCharacters * fontProfile().advance
        + 2 * (BUTTON_BORDER_DOTS + BUTTON_HORIZONTAL_INSET_DOTS)) / STYLE_SCALE;
      column.width = Math.max(headingWidth, textWidth);
    });
  }

  const columnVisibility = state.preferences.columnVisibility || {};
  const visible = columns.filter((column) => column.mandatory || columnVisibility[column.key] !== false);
  const byKey = new Map(columns.map((column) => [column.key, column]));
  const preferredOrder = state.columnOrder.filter((key) => key !== "index" && byKey.has(key));
  const orderedKeys = [...new Set(preferredOrder)];
  columns.forEach((column) => {
    if (column.key !== "index" && !orderedKeys.includes(column.key)) orderedKeys.push(column.key);
  });
  const ordered = [byKey.get("index"), ...orderedKeys.map((key) => byKey.get(key))]
    .filter(Boolean);
  return { all: ordered, visible: ordered.filter((column) => visible.includes(column)) };
}

function columnWidthSignature(widths) {
  return Object.keys(widths).sort()
    .map((key) => `${key}:${Math.round(widths[key] * 100)}`).join("|");
}

function columnWidthsAt(time) {
  const animation = columnLayoutAnimation;
  if (!animation) return lastColumnWidths;
  const progress = Math.max(0, Math.min(1, (time - animation.startedAt) / animation.duration));
  const eased = easeSelection(progress);
  const widths = {};
  Object.keys(animation.to).forEach((key) => {
    const from = animation.from[key] ?? 0;
    const to = animation.to[key] ?? 0;
    widths[key] = from + (to - from) * eased;
  });
  return widths;
}

function resolveTableColumns(layout, time) {
  const visibleKeys = new Set(layout.visible.map((column) => column.key));
  const target = Object.fromEntries(layout.all
    .filter((column) => column.key !== "title")
    .map((column) => [column.key, visibleKeys.has(column.key) ? column.width : 0]));
  const targetSignature = columnWidthSignature(target);
  let current = columnLayoutAnimation ? columnWidthsAt(time) : lastColumnWidths;

  if (!current) {
    lastColumnWidths = target;
    return layout.visible;
  }

  if (columnLayoutAnimation?.targetSignature !== targetSignature) {
    if (columnWidthSignature(current) === targetSignature) {
      columnLayoutAnimation = null;
      lastColumnWidths = target;
      return layout.visible;
    }
    const duration = animationMilliseconds("autoResizeAnimationMilliseconds");
    if (animationEnabled("autoResizeAnimationEnabled") && duration > 0) {
      columnLayoutAnimation = {
        from: current,
        to: target,
        targetSignature,
        startedAt: time,
        duration,
      };
      current = columnWidthsAt(time);
    } else {
      columnLayoutAnimation = null;
      lastColumnWidths = target;
      return layout.visible;
    }
  } else if (columnLayoutAnimation) {
    current = columnWidthsAt(time);
  }

  if (!columnLayoutAnimation) {
    lastColumnWidths = current;
    return layout.visible;
  }

  lastColumnWidths = current;
  return layout.all.filter((column) => column.key === "title"
    || (current[column.key] ?? 0) > 0.5
    || (columnLayoutAnimation.to[column.key] ?? 0) > 0.5).map((column) => ({
    ...column,
    width: column.key === "title" ? column.width : Math.max(0, current[column.key] ?? 0),
  }));
}

function createTableHeader(parent, columns) {
  const headerHeight = buttonStandardHeight();
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
      inset: BUTTON_HORIZONTAL_INSET_DOTS,
      border: 1,
      fill: marker ? 2 : undefined,
      align: "center",
      columnKey: column.key,
      columnHeader: true,
      reorderable: column.reorderable !== false,
      onClick: column.sortable === false ? undefined : () => toggleSort(column.key),
    });
  });
  return header;
}

function createQueueRow(parent, index, track, columns) {
  const rowHeightValue = rowHeight(4);
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
    align: column.rowAlign ?? column.align ?? "left",
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
  return Math.max(1, Math.floor((HEIGHT / STYLE_SCALE - 78) / rowHeight(3)));
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
    width: libraryPaneWidth(),
    gap: 0,
    padding: PANE_INSET_DOTS,
  }, {
    paint(box) {
      strokeRect(box.x, box.y, box.width, box.height, 1);
    },
  });
  panelTitle(library, "BROWSE");
  const navigation = controlRow(library);
  libraryToolbarItems().forEach((item) => pixelButton(navigation, item.title, item.onClick, {
    width: buttonWidth(item.title),
    selected: item.view === state.tab,
  }));
  makeWidget(library, { height: uiGap() });
  panelTitle(library, "SYSTEMS");
  const rows = libraryRows();
  const count = Math.max(1, Math.floor((HEIGHT / STYLE_SCALE - 96) / rowHeight(3)));
  state.libraryScroll = Math.max(0, Math.min(state.libraryScroll, Math.max(0, rows.length - count)));
  rows.slice(state.libraryScroll, state.libraryScroll + count).forEach((row) => {
    createLibraryRow(library, row.text, {
      selected: row.game && gameKey(row.game) === state.selectedGameKey,
      indent: row.indent,
      revealProgress: row.revealProgress,
      onClick: row.game ? () => loadGame(row.game) : () => toggleSystem(row.system),
    });
  });
  makeWidget(library, { flexGrow: 1 });
  const systemCount = new Set(state.games.map((game) => game.system || "OTHER")).size;
  const first = rows.length ? state.libraryScroll + 1 : 0;
  const last = Math.min(rows.length, state.libraryScroll + count);
  statusBar(library, `SYS ${systemCount} ${first}-${last}/${rows.length}`);
  return library;
}

function addCatalogPane(parent) {
  const viewTracks = visibleTracks();
  const panel = makeWidget(parent, {
    direction: FlexDirection.Column,
    flexGrow: 1,
    flexShrink: 1,
    gap: 0,
    padding: PANE_INSET_DOTS,
  }, {
    paint(box) {
      strokeRect(box.x, box.y, box.width, box.height, 1);
    },
  });
  if (state.tab !== "FAVORITES") {
    const tabRow = controlRow(panel);
    const tabList = makeWidget(tabRow, {
      direction: FlexDirection.Row,
      flexGrow: 1,
      flexBasis: 0,
      gap: uiGap(),
      overflow: Overflow.Hidden,
    }, { clipChildren: true });
    state.playlistTabs.forEach((tab) => {
      const item = makeWidget(tabList, {
        direction: FlexDirection.Row,
        flexGrow: 1,
        flexBasis: 0,
        gap: uiGap(),
      });
      pixelButton(item, tab.title, () => activatePlaylistTab(tab.id), {
        flexGrow: 1,
        selected: tab.id === state.activePlaylistTabId,
      });
      pixelButton(item, "[x]", () => closePlaylistTab(tab.id), {
        width: buttonWidth("[x]"),
      });
    });
    pixelButton(tabRow, "[+]", () => createPlaylistTab({ duplicateActive: true }), {
      width: buttonWidth("[+]"),
    });
  }
  const columns = resolveTableColumns(tableColumns(viewTracks), currentRenderTime);
  const tableGap = Math.max(0, columns.length - 1) * oneDot();
  state.tableContentMinimumWidth = columns.reduce((sum, column) => sum + column.width, 0) + tableGap;
  const viewport = makeWidget(panel, {
    direction: FlexDirection.Column,
    flexGrow: 1,
    overflow: Overflow.Hidden,
  }, {
    id: "catalog-horizontal-viewport",
    clipChildren: true,
  });
  const content = makeWidget(viewport, {
    direction: FlexDirection.Column,
    width: state.tableContentMinimumWidth,
    gap: 0,
  }, {
    id: "catalog-scroll-content",
    translateX: -state.tableHorizontalScroll,
  });
  state.tableViewportWidget = viewport;
  state.tableContentWidget = content;
  createTableHeader(content, columns);
  const count = visibleRowCount();
  state.queueScroll = Math.max(0, Math.min(state.queueScroll, Math.max(0, viewTracks.length - count)));
  viewTracks.slice(state.queueScroll, state.queueScroll + count).forEach((track, offset) =>
    createQueueRow(content, state.queueScroll + offset, track, columns));
  if (!viewTracks.length) label(content, state.status, { height: rowHeight(4) }, { textShade: 0, inset: 1 });
  makeWidget(panel, {
    height: rowHeight(4),
  }, {
    horizontalScrollbar: true,
    onClick(event) {
      if (state.tableHorizontalMax <= 0) return;
      const point = logicalPoint(event);
      const box = state.tableScrollbarBox;
      if (!box) return;
      const trackWidth = Math.max(1, box.width - 2);
      state.tableHorizontalScroll = Math.max(0, Math.min(state.tableHorizontalMax,
        ((point.x - box.x - 1) / trackWidth) * state.tableHorizontalMax));
      render();
    },
    paint(box) {
      state.tableScrollbarBox = box;
      const trackLeft = box.x + 1;
      const trackWidth = Math.max(1, box.width - 2);
      const centerY = box.y + Math.floor(box.height / 2);
      line(trackLeft, centerY, trackLeft + trackWidth, centerY, 2);
      const contentWidth = Math.max(trackWidth, state.tableContentWidth);
      const viewportWidth = Math.min(contentWidth, state.tableViewportWidth || contentWidth);
      const thumbWidth = state.tableHorizontalMax > 0
        ? Math.max(6, Math.min(trackWidth, Math.floor(trackWidth * viewportWidth / contentWidth)))
        : trackWidth;
      const thumbTravel = Math.max(0, trackWidth - thumbWidth);
      const thumbLeft = trackLeft + (state.tableHorizontalMax > 0
        ? Math.round(thumbTravel * state.tableHorizontalScroll / state.tableHorizontalMax) : 0);
      fillRect(thumbLeft, centerY, thumbWidth, 1, 0);
      state.tableScrollbarThumb = { x: thumbLeft, y: centerY, width: thumbWidth, height: 1 };
    },
  });
  const first = viewTracks.length ? state.queueScroll + 1 : 0;
  const last = Math.min(viewTracks.length, state.queueScroll + count);
  statusBar(panel, `TRACKS ${first}-${last}/${viewTracks.length}`);
  return panel;
}

function addColumnContextMenu(parent) {
  if (!state.columnMenu) return;

  const height = rowHeight(2) + 6 * buttonStandardHeight() + 6 * oneDot() + 4;
  const width = Math.min(WIDTH / STYLE_SCALE - 16,
    Math.max(68, (8 * fontProfile().advance + 12) / STYLE_SCALE));
  const widthPixels = width * STYLE_SCALE;
  const heightPixels = height * STYLE_SCALE;
  const edge = 8 * STYLE_SCALE;
  const left = Math.max(edge, Math.min(state.columnMenu.x, WIDTH - edge - widthPixels));
  const top = Math.max(edge, Math.min(state.columnMenu.y + oneDot() * STYLE_SCALE,
    HEIGHT - edge - heightPixels));
  const menu = makeWidget(parent, {
    positionType: PositionType.Absolute,
    left: left / STYLE_SCALE,
    top: top / STYLE_SCALE,
    width,
    height,
    direction: FlexDirection.Column,
    gap: oneDot(),
    padding: 2,
  }, {
    paint(box) {
      fillRect(box.x, box.y, box.width, box.height, 2);
      strokeRect(box.x, box.y, box.width, box.height, 0);
    },
  });
  panelTitle(menu, "COLUMNS");
  configurableColumns.forEach(({ key, title }) => {
    const visibility = state.preferences.columnVisibility || {};
    optionToggle(menu, title, visibility[key] !== false,
      () => setPreference("columnVisibility", {
        ...(state.preferences.columnVisibility || {}),
        [key]: state.preferences.columnVisibility?.[key] === false,
      }), { columnMenuItem: true });
  });
  pixelButton(menu, "DONE", () => {
    state.columnMenu = null;
    render();
  }, { flexGrow: 1 });
}

function addPalettePreview(parent) {
  const preview = makeWidget(parent, {
    direction: FlexDirection.Row,
    flexGrow: 1,
    gap: uiGap(),
    paddingHorizontal: UI_SPACING_DOTS.groupInset / STYLE_SCALE,
    paddingVertical: UI_SPACING_DOTS.minimumGap / STYLE_SCALE,
  });
  RGB.forEach((_, shade) => makeWidget(preview, {
    flexGrow: 1,
    height: rowHeight(8),
  }, {
    paint(box) {
      strokeRect(box.x, box.y, box.width, box.height, 1);
      fillRect(box.x + 1, box.y + 1, box.width - 2, box.height - 2, shade);
      drawText(String(shade), box.x + 2, box.y + Math.floor((box.height - fontProfile().height) / 2),
        box.width - 4, shade < 2 ? 3 : 0, "center");
    },
  }));
}

function optionGroup(parent, title) {
  const group = makeWidget(parent, {
    direction: FlexDirection.Column,
    gap: uiGap(),
    padding: UI_SPACING_DOTS.groupInset / STYLE_SCALE,
  }, {
    paint(box) { strokeRect(box.x, box.y, box.width, box.height, 1); },
  });
  optionSection(group, title);
  return group;
}

function optionsTocWidth() {
  const available = WIDTH / STYLE_SCALE;
  const labelWidth = framedTextWidth("INTERFACE") + UI_SPACING_DOTS.optionsInset / STYLE_SCALE * 2;
  return Math.min(available * 0.34, Math.max(labelWidth, Math.min(220, available * 0.20)));
}

function addDisplayOptions(parent) {
  const profile = optionGroup(parent, "SCREEN PROFILE");
  optionChoice(profile, "FONT", [
    { title: "MICRO 3X5", selected: state.font === "MICRO", onClick: () => setFontProfile("MICRO") },
    { title: "STANDARD 5X7", selected: state.font === "STANDARD", onClick: () => setFontProfile("STANDARD") },
  ]);
  optionChoice(profile, "THEME", [
    { title: "GAMEBOY", selected: state.theme === "GAMEBOY", onClick: () => setTheme("GAMEBOY") },
    { title: "NIGHTBOY", selected: state.theme === "NIGHTBOY", onClick: () => setTheme("NIGHTBOY") },
  ]);
  optionChoice(profile, "INK", [
    { title: state.theme === "GAMEBOY" ? "LCD GREEN" : "SILVER", selected: state.contrast === "STANDARD",
      onClick: () => setContrastProfile("STANDARD") },
    { title: state.theme === "GAMEBOY" ? "CHARCOAL" : "BRIGHT", selected: state.contrast === "HIGH_CONTRAST",
      onClick: () => setContrastProfile("HIGH_CONTRAST") },
  ]);
  const tones = optionGroup(parent, "FOUR LCD TONES");
  addPalettePreview(tones);
}

function optionDuration(seconds, allowOpen = false) {
  const value = Math.max(0, Math.floor(Number(seconds) || 0));
  if (allowOpen && value === 0) return "OPEN";
  return `${Math.floor(value / 60)}:${String(value % 60).padStart(2, "0")}`;
}

function adjustPlaybackDuration(key, delta, minimum, maximum, fallback) {
  const current = Number(state.preferences[key] ?? fallback);
  setPreference(key, Math.max(minimum, Math.min(maximum, current + delta)));
}

function equalizerGain(index, preferences = state.preferences) {
  const value = Number(preferences.equalizerBandGains?.[index] ?? 0);
  return Math.max(-12, Math.min(12, Number.isFinite(value) ? value : 0));
}

function changeEqualizerGain(index, delta) {
  setEqualizerGain(index, equalizerGain(index) + delta);
}

function setEqualizerGain(index, value) {
  const gains = Array.from({ length: 10 }, (_, band) => equalizerGain(band));
  gains[index] = Math.max(-12, Math.min(12, Math.round(Number(value) * 2) / 2));
  setPreference("equalizerBandGains", gains, true);
}

function equalizerGainLabel(value) {
  return `${value > 0 ? "+" : ""}${value.toFixed(1)}`;
}

function playbackRateSteps(backend, preferences = state.preferences) {
  const key = backend === "libvgm" ? "libvgmPlaybackSpeed" : "playbackSpeed";
  const rate = preferences[key] || { numerator: 1, denominator: 1 };
  const numerator = Number(rate.numerator) || 1;
  const denominator = Number(rate.denominator) || 1;
  return Math.max(1, Math.min(256, Math.round(numerator / denominator * 32)));
}

function playbackRateLabel(steps) {
  return steps === 32 ? "1X" : `${steps}/32X`;
}

function adjustPlaybackRate(backend, delta) {
  const key = backend === "libvgm" ? "libvgmPlaybackSpeed" : "playbackSpeed";
  const steps = Math.max(1, Math.min(256, playbackRateSteps(backend) + delta));
  setPreference(key, { numerator: steps, denominator: 32 });
}

function playbackTempoForTrack(track, preferences = state.preferences) {
  const path = String(track?.archiveEntry || track?.path || track?.filename || "");
  const extension = path.match(/\.([a-z0-9]+)$/i)?.[1]?.toLowerCase();
  if (!extension) return 1;
  const descriptor = bridge?.playbackBackends?.find((backend) => backend.supportsTempo
    && backend.extensions?.some((candidate) => String(candidate).toLowerCase() === extension));
  const family = descriptor?.id === "libvgm" ? "libvgm"
    : descriptor?.id === "libgme" ? "libgme" : null;
  if (!family) return 1;
  const enabledKey = family === "libvgm" ? "libvgmPlaybackSpeedEnabled" : "playbackSpeedEnabled";
  return preferences[enabledKey] === true ? playbackRateSteps(family, preferences) / 32 : 1;
}

function addPlaybackOptions(parent, pref) {
  const behavior = optionGroup(parent, "PLAYBACK BEHAVIOR");
  optionToggle(behavior, "LONG PLAY", pref.longPlayEnabled === true,
    () => setPreference("longPlayEnabled", pref.longPlayEnabled !== true));
  optionToggle(behavior, "END FADE", pref.fadeEnabled !== false,
    () => setPreference("fadeEnabled", pref.fadeEnabled === false));
  optionChoice(behavior, "REPEAT", [
    { title: "OFF", selected: (pref.repeatMode || "off") === "off", onClick: () => setPreference("repeatMode", "off") },
    { title: "ALL", selected: pref.repeatMode === "all", onClick: () => setPreference("repeatMode", "all") },
    { title: "ONE", selected: pref.repeatMode === "one", onClick: () => setPreference("repeatMode", "one") },
  ]);
  optionChoice(behavior, "RANDOM", [
    { title: "OFF", selected: (pref.randomMode || "off") === "off", onClick: () => setRandomMode("off") },
    { title: "PLAYLIST", selected: pref.randomMode === "playlist", onClick: () => setRandomMode("playlist") },
    { title: "LIBRARY", selected: pref.randomMode === "library", onClick: () => setRandomMode("library") },
  ]);

  const timing = optionGroup(parent, "TRACK TIMING");
  optionAdjuster(timing, "LONG PLAY", optionDuration(pref.manualPlayTimeSeconds ?? 180, true),
    () => adjustPlaybackDuration("manualPlayTimeSeconds", -30, 0, 3600, 180),
    () => adjustPlaybackDuration("manualPlayTimeSeconds", 30, 0, 3600, 180));
  optionAdjuster(timing, "UNKNOWN LENGTH", optionDuration(pref.unknownDurationSeconds ?? 150),
    () => adjustPlaybackDuration("unknownDurationSeconds", -30, 30, 3600, 150),
    () => adjustPlaybackDuration("unknownDurationSeconds", 30, 30, 3600, 150));
  optionAdjuster(timing, "FADE LENGTH", optionDuration(pref.spcFadeSeconds ?? 6),
    () => adjustPlaybackDuration("spcFadeSeconds", -1, 0, 60, 6),
    () => adjustPlaybackDuration("spcFadeSeconds", 1, 0, 60, 6));

  const speed = optionGroup(parent, "DECODER SPEED");
  optionToggle(speed, "LIBGME SPEED", pref.playbackSpeedEnabled === true,
    () => setPreference("playbackSpeedEnabled", pref.playbackSpeedEnabled !== true));
  optionAdjuster(speed, "LIBGME RATE", playbackRateLabel(playbackRateSteps("libgme", pref)),
    () => adjustPlaybackRate("libgme", -1),
    () => adjustPlaybackRate("libgme", 1));
  optionToggle(speed, "LIBVGM SPEED", pref.libvgmPlaybackSpeedEnabled === true,
    () => setPreference("libvgmPlaybackSpeedEnabled", pref.libvgmPlaybackSpeedEnabled !== true));
  optionAdjuster(speed, "LIBVGM RATE", playbackRateLabel(playbackRateSteps("libvgm", pref)),
    () => adjustPlaybackRate("libvgm", -1),
    () => adjustPlaybackRate("libvgm", 1));
}

function paintEqualizerBar(box, gain) {
  strokeRect(box.x, box.y, box.width, box.height, 1);
  const left = box.x + 2;
  const right = Math.max(left + EQ_GAIN_STEPS, box.x + box.width - 3);
  const span = right - left;
  const centerY = box.y + Math.floor(box.height / 2);
  const zeroStep = EQ_GAIN_STEPS / 2;
  const currentStep = Math.max(0, Math.min(EQ_GAIN_STEPS, Math.round((gain + 12) * 2)));
  const zeroX = left + Math.round(span * zeroStep / EQ_GAIN_STEPS);
  const currentX = left + Math.round(span * currentStep / EQ_GAIN_STEPS);
  const cellWidth = Math.max(1, Math.min(4, Math.floor(span / EQ_GAIN_STEPS)));

  line(left, centerY, right, centerY, 2);
  for (let step = 0; step <= EQ_GAIN_STEPS; step += 1) {
    const x = left + Math.round(span * step / EQ_GAIN_STEPS);
    if (step === zeroStep) continue;
    line(x, centerY - 2, x, centerY + 2, 2);
    if ((currentStep >= zeroStep && step > zeroStep && step <= currentStep)
      || (currentStep < zeroStep && step >= currentStep && step < zeroStep)) {
      fillRect(x - Math.floor(cellWidth / 2), centerY - 1, cellWidth, 3, 1);
    }
  }
  line(zeroX, box.y + 2, zeroX, box.y + box.height - 3, 0);
  fillRect(currentX - 1, box.y + 2, 3, Math.max(1, box.height - 4), 0);
}

function equalizerBand(parent, title, index, gain) {
  const row = makeWidget(parent, {
    direction: FlexDirection.Row,
    alignItems: Align.Center,
    height: rowHeight(12),
    gap: uiGap(),
  });
  label(row, title, { width: textLayoutWidth("16K HZ"), height: buttonStandardHeight() }, {
    textShade: 0,
    inset: BUTTON_HORIZONTAL_INSET_DOTS,
  });
  makeWidget(row, {
    flexGrow: 1,
    minWidth: EQ_BAR_MIN_DOTS / STYLE_SCALE,
    height: buttonStandardHeight(),
  }, {
    equalizerBar: index,
    onClick(event) {
      const box = state.equalizerBarBoxes[index];
      if (!box) return;
      const point = logicalPoint(event);
      const fraction = Math.max(0, Math.min(1, (point.x - box.x - 2) / Math.max(1, box.width - 4)));
      const step = Math.round(fraction * EQ_GAIN_STEPS);
      setEqualizerGain(index, (step - EQ_GAIN_STEPS / 2) / 2);
    },
    paint(box) {
      state.equalizerBarBoxes[index] = box;
      paintEqualizerBar(box, gain);
    },
  });
  label(row, equalizerGainLabel(gain), {
    width: framedTextWidth("-12.0"),
    height: buttonStandardHeight(),
  }, {
    border: 1,
    textShade: 0,
    align: "center",
    inset: BUTTON_HORIZONTAL_INSET_DOTS,
  });
}

function addAudioOptions(parent, pref) {
  const output = optionGroup(parent, "OUTPUT");
  optionToggle(output, "MONO OUTPUT", pref.monoEnabled === true,
    () => setPreference("monoEnabled", pref.monoEnabled !== true, true));
  const volume = Math.max(0, Math.min(1, Number(pref.appVolume ?? 1)));
  const volumeRow = controlRow(output, {}, {
    paint(box) { line(box.x, box.y + box.height - 1, box.x + box.width, box.y + box.height, 2); },
  });
  label(volumeRow, "VOLUME", { width: textLayoutWidth("VOLUME"), height: buttonStandardHeight() }, {
    textShade: 0, inset: BUTTON_HORIZONTAL_INSET_DOTS,
  });
  pixelButton(volumeRow, "[-]", () => changeVolume(-0.1));
  makeWidget(volumeRow, { flexGrow: 1, minWidth: EQ_BAR_MIN_DOTS / STYLE_SCALE, height: buttonStandardHeight() }, {
    paint(box) {
      strokeRect(box.x, box.y, box.width, box.height, 1);
      const count = 10;
      const gap = UI_SPACING_DOTS.minimumGap;
      const segmentWidth = Math.max(1, Math.floor((box.width - 2 - (count - 1) * gap) / count));
      const active = Math.round(volume * count);
      for (let index = 0; index < active; index += 1) {
        fillRect(box.x + 1 + index * (segmentWidth + gap), box.y + 1,
          segmentWidth, Math.max(1, box.height - 2), 0);
      }
    },
  });
  label(volumeRow, `${Math.round(volume * 100)}%`, {
    width: framedTextWidth("100%"), height: buttonStandardHeight(),
  }, { textShade: 0, align: "right", inset: BUTTON_HORIZONTAL_INSET_DOTS });
  pixelButton(volumeRow, "[+]", () => changeVolume(0.1));

  const equalizer = optionGroup(parent, "TEN BAND EQUALIZER");
  optionToggle(equalizer, "EQUALIZER", pref.equalizerEnabled === true,
    () => setPreference("equalizerEnabled", pref.equalizerEnabled !== true, true));
  const equalizerBands = ["31 HZ", "62 HZ", "125 HZ", "250 HZ", "500 HZ", "1K HZ", "2K HZ", "4K HZ", "8K HZ", "16K HZ"];
  equalizerBands.forEach((title, index) => equalizerBand(equalizer, title, index, equalizerGain(index, pref)));
}

function addInterfaceOptions(parent, pref) {
  const layout = optionGroup(parent, "PLAYLIST LAYOUT");
  optionToggle(layout, "AUTO-SIZE COLUMNS", pref.columnAutoSize !== false,
    () => setPreference("columnAutoSize", pref.columnAutoSize === false));
  const window = optionGroup(parent, "WINDOW");
  optionToggle(window, "MAIN WINDOW ON TOP", pref.mainWindowAlwaysOnTop === true,
    () => setPreference("mainWindowAlwaysOnTop", pref.mainWindowAlwaysOnTop !== true));
  const motion = optionGroup(parent, "MOTION");
  optionToggle(motion, "AUTO-RESIZE HEADERS + ROWS", animationEnabled("autoResizeAnimationEnabled"),
    () => setPreference("autoResizeAnimationEnabled", !animationEnabled("autoResizeAnimationEnabled")));
  optionAdjuster(motion, "RESIZE TIME", `${animationMilliseconds("autoResizeAnimationMilliseconds")} MS`,
    () => adjustAnimationTime("autoResizeAnimationMilliseconds", -50),
    () => adjustAnimationTime("autoResizeAnimationMilliseconds", 50));
  optionToggle(motion, "SELECTION SLIDE", animationEnabled("selectionAnimationEnabled"),
    () => setPreference("selectionAnimationEnabled", !animationEnabled("selectionAnimationEnabled")));
  optionAdjuster(motion, "SLIDE TIME", `${animationMilliseconds("selectionAnimationMilliseconds")} MS`,
    () => adjustAnimationTime("selectionAnimationMilliseconds", -50),
    () => adjustAnimationTime("selectionAnimationMilliseconds", 50));
}

function addLibraryOptions(parent, pref) {
  const fields = optionGroup(parent, "PLAYLIST COLUMNS");
  configurableColumns.forEach(({ key, title }) => {
    const visibility = pref.columnVisibility || {};
    optionToggle(fields, title, visibility[key] !== false,
      () => setPreference("columnVisibility", {
        ...(state.preferences.columnVisibility || {}),
        [key]: state.preferences.columnVisibility?.[key] === false,
      }));
  });
  const catalog = optionGroup(parent, "CATALOG");
  pixelButton(catalog, "RELOAD LIBRARY", () => loadCatalog());
}

function addOptionsContent(parent) {
  const navigationWidth = optionsTocWidth();
  const toc = makeWidget(parent, {
    direction: FlexDirection.Column,
    width: navigationWidth,
    gap: uiGap(),
    padding: UI_SPACING_DOTS.optionsInset / STYLE_SCALE,
  }, {
    paint(box) { strokeRect(box.x, box.y, box.width, box.height, 1); },
  });
  panelTitle(toc, "OPTIONS");
  const pageButtonWidth = navigationWidth - 2 * UI_SPACING_DOTS.optionsInset / STYLE_SCALE;
  ["DISPLAY", "PLAYBACK", "AUDIO", "INTERFACE", "LIBRARY"].forEach((page) => {
    pixelButton(toc, page, () => {
      state.optionsPage = page;
      render();
    }, { width: pageButtonWidth, selected: state.optionsPage === page });
  });
  makeWidget(toc, { flexGrow: 1 });
  statusBar(toc, "SETTINGS");

  const panel = makeWidget(parent, {
    direction: FlexDirection.Column,
    flexGrow: 1,
    gap: uiGap(),
    padding: UI_SPACING_DOTS.optionsInset / STYLE_SCALE,
  }, {
    paint(box) { strokeRect(box.x, box.y, box.width, box.height, 1); },
  });
  panelTitle(panel, state.optionsPage);
  const content = makeWidget(panel, {
    direction: FlexDirection.Column,
    flexGrow: 1,
    gap: uiSectionGap(),
  });
  const pref = state.preferences;
  if (state.optionsPage === "PLAYBACK") addPlaybackOptions(content, pref);
  else if (state.optionsPage === "AUDIO") addAudioOptions(content, pref);
  else if (state.optionsPage === "INTERFACE") addInterfaceOptions(content, pref);
  else if (state.optionsPage === "LIBRARY") addLibraryOptions(content, pref);
  else addDisplayOptions(content);
  statusBar(panel, `${state.optionsPage} OPTIONS`);
}

function buildTree() {
  state.tableViewportWidget = null;
  state.tableContentWidget = null;
  state.tableScrollbarBox = null;
  state.tableScrollbarThumb = null;
  const toolbarHeight = rowHeight(6);
  const root = makeWidget(null, {
    direction: FlexDirection.Column,
    width: WIDTH / STYLE_SCALE,
    height: HEIGHT / STYLE_SCALE,
    positionType: PositionType.Relative,
    padding: 8,
    gap: uiGap(),
    alignItems: Align.Stretch,
  }, {
    paint() {
      fillRect(0, 0, WIDTH, HEIGHT, 3);
    },
  });

  const toolbar = controlRow(root, { height: toolbarHeight });
  label(toolbar, "VIEWBOY", { flexGrow: 1, height: toolbarHeight }, {
    textShade: 0, inset: 0,
  });
  const buttonWidth = (text) => framedTextWidth(text);
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
  pixelButton(toolbar, "LP", () => toggleLongPlay(), {
    width: buttonWidth("LP"), selected: state.preferences.longPlayEnabled === true,
  });
  pixelButton(toolbar, "R1", () => toggleRepeatOne(), {
    width: buttonWidth("R1"), selected: state.preferences.repeatMode === "one",
  });
  pixelButton(toolbar, "P-RND", () => toggleRandomMode("playlist"), {
    width: buttonWidth("P-RND"), selected: state.preferences.randomMode === "playlist",
  });
  pixelButton(toolbar, "L-RND", () => toggleRandomMode("library"), {
    width: buttonWidth("L-RND"), selected: state.preferences.randomMode === "library",
  });

  const content = makeWidget(root, {
    direction: FlexDirection.Row,
    flexGrow: 1,
    gap: uiGap(),
    alignItems: Align.Stretch,
  });
  if (state.tab === "SETTINGS") {
    addOptionsContent(content);
  } else {
    addLibraryPane(content);
    addCatalogPane(content);
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

  addColumnContextMenu(root);

  root.yoga.calculateLayout(WIDTH, HEIGHT, Direction.LTR);
  if (state.tableViewportWidget && state.tableContentWidget) {
    const viewportWidth = state.tableViewportWidget.yoga.getComputedLayout().width;
    const contentWidth = Math.max(
      state.tableContentMinimumWidth * STYLE_SCALE,
      viewportWidth,
    );
    state.tableContentWidget.yoga.setWidth(contentWidth);
    root.yoga.calculateLayout(WIDTH, HEIGHT, Direction.LTR);
  }
  return root;
}

function intersectBoxes(first, second) {
  if (!first) return second;
  if (!second) return first;
  const x = Math.max(first.x, second.x);
  const y = Math.max(first.y, second.y);
  const right = Math.min(first.x + first.width, second.x + second.width);
  const bottom = Math.min(first.y + first.height, second.y + second.height);
  return { x, y, width: Math.max(0, right - x), height: Math.max(0, bottom - y) };
}

function collect(widget, parentX = 0, parentY = 0, output = [], inheritedClip = null) {
  const layout = widget.yoga.getComputedLayout();
  const box = {
    x: floor(parentX + layout.left + (widget.meta.translateX ?? 0)),
    y: floor(parentY + layout.top),
    width: floor(layout.width),
    height: floor(layout.height),
  };
  const entry = { widget, box, clip: inheritedClip };
  output.push(entry);
  if (widget.meta.id) boxesById.set(widget.meta.id, box);
  if (widget.meta.onClick || widget.meta.columnHeader) hitTargets.push(entry);
  const childClip = widget.meta.clipChildren ? intersectBoxes(inheritedClip, box) : inheritedClip;
  for (const child of widget.children) collect(child, box.x, box.y, output, childClip);
  return output;
}

function paintTree(widget, box, inheritedClip = null) {
  const priorClip = paintClip;
  paintClip = intersectBoxes(paintClip, inheritedClip);
  if (widget.meta.paint) widget.meta.paint(box);
  const childClip = widget.meta.clipChildren ? intersectBoxes(inheritedClip, box) : inheritedClip;
  for (const child of widget.children) {
    const layout = child.yoga.getComputedLayout();
    paintTree(child, {
      x: floor(box.x + layout.left + (child.meta.translateX ?? 0)),
      y: floor(box.y + layout.top),
      width: floor(layout.width),
      height: floor(layout.height),
    }, childClip);
  }
  paintClip = priorClip;
}

function paintSelectionAt(y, startY = 0, endY = HEIGHT) {
  pixels.set(basePixels);
  if (selectionBand && y !== null) {
    const bandTop = floor(y);
    const priorClip = paintClip;
    paintClip = intersectBoxes(paintClip, selectionBand.clip);
    fillRect(selectionBand.x, bandTop, selectionBand.width, selectionBand.height, 2);
    for (const row of selectionRows) {
      if (row.box.y >= bandTop + selectionBand.height || row.box.y + row.box.height <= bandTop) continue;
      for (const child of row.widget.children) {
        const entry = layoutEntries.find((candidate) => candidate.widget === child);
        if (entry?.widget.meta.paint) entry.widget.meta.paint(entry.box);
      }
    }
    paintClip = priorClip;
  }
  present(startY, endY);
}

function animateSelectionFrame(time) {
  selectionAnimationFrame = 0;
  if (!selectionAnimation) return;
  const complete = time - selectionAnimation.startedAt >= selectionAnimation.duration;
  if (!complete && !animationFrameIsDue(selectionAnimation, time)) {
    selectionAnimationFrame = requestAnimationFrame(animateSelectionFrame);
    return;
  }
  const priorY = selectionAnimation.lastY;
  const y = selectionYAt(time);
  const extent = selectionBand?.height ?? 0;
  paintSelectionAt(y, Math.min(priorY, y) - 1, Math.max(priorY, y) + extent + 1);
  selectionAnimation.lastY = y;
  if (!complete) {
    selectionAnimationFrame = requestAnimationFrame(animateSelectionFrame);
  } else {
    selectionBand.y = selectionAnimation.toY;
    selectionAnimation = null;
  }
}

function animateColumnLayoutFrame(time) {
  columnAnimationFrame = 0;
  if (!columnLayoutAnimation) return;
  const complete = time - columnLayoutAnimation.startedAt >= columnLayoutAnimation.duration;
  if (!complete && !animationFrameIsDue(columnLayoutAnimation, time)) {
    columnAnimationFrame = requestAnimationFrame(animateColumnLayoutFrame);
    return;
  }
  if (complete) {
    lastColumnWidths = columnLayoutAnimation.to;
    columnLayoutAnimation = null;
    render(false, true, time);
    return;
  }
  render(false, true, time);
}

function render(animateSelection = false, preserveAnimations = false, frameTime = performance.now()) {
  currentRenderTime = frameTime;
  const priorBand = selectionBand;
  const priorY = selectionYAt(frameTime);
  const priorSelectionAnimation = selectionAnimation;
  if (selectionAnimationFrame && !preserveAnimations) {
    cancelAnimationFrame(selectionAnimationFrame);
    selectionAnimationFrame = 0;
  }
  if (widgetTree) widgetTree.yoga.freeRecursive();
  boxesById = new Map();
  hitTargets = [];
  pixels.fill(3);
  widgetTree = buildTree();
  if (state.tableViewportWidget && state.tableContentWidget) {
    const viewportLayout = state.tableViewportWidget.yoga.getComputedLayout();
    const contentLayout = state.tableContentWidget.yoga.getComputedLayout();
    state.tableViewportWidth = Math.floor(viewportLayout.width);
    state.tableContentWidth = Math.floor(contentLayout.width);
    state.tableHorizontalMax = Math.max(0, state.tableContentWidth - state.tableViewportWidth);
    state.tableHorizontalScroll = Math.max(0, Math.min(state.tableHorizontalMax, state.tableHorizontalScroll));
    state.tableContentWidget.meta.translateX = -state.tableHorizontalScroll;
  } else {
    state.tableHorizontalMax = 0;
    state.tableHorizontalScroll = 0;
    state.tableViewportBox = null;
  }
  layoutEntries = collect(widgetTree);
  state.tableViewportBox = boxesById.get("catalog-horizontal-viewport") ?? null;
  paintTree(widgetTree, { x: 0, y: 0, width: WIDTH, height: HEIGHT });
  basePixels = pixels.slice();
  selectionRows = layoutEntries.filter((entry) => Number.isInteger(entry.widget.meta.trackIndex));
  const selectedRow = selectionRows.find((entry) => entry.widget.meta.trackIndex === state.selectedTrack);
  const nextBand = selectedRow ? {
    ...selectedRow.box,
    ...(selectedRow.clip ? {
      x: selectedRow.clip.x,
      width: selectedRow.clip.width,
      clip: selectedRow.clip,
    } : {}),
  } : null;
  const selectionDuration = animationMilliseconds("selectionAnimationMilliseconds");
  const canSlide = animateSelection && animationEnabled("selectionAnimationEnabled") && selectionDuration > 0
    && priorBand && nextBand
    && priorBand.x === nextBand.x && priorBand.width === nextBand.width
    && priorBand.height === nextBand.height && Math.abs(priorY - nextBand.y) > 0.5;
  selectionBand = nextBand;
  if (canSlide) {
    selectionAnimation = {
      fromY: priorY,
      toY: nextBand.y,
      startedAt: frameTime,
      duration: selectionDuration,
      lastY: priorY,
    };
    paintSelectionAt(priorY);
    selectionAnimationFrame = requestAnimationFrame(animateSelectionFrame);
  } else if (preserveAnimations && priorSelectionAnimation && nextBand) {
    selectionAnimation = priorSelectionAnimation;
    paintSelectionAt(selectionYAt(frameTime));
  } else {
    selectionAnimation = null;
    paintSelectionAt(nextBand?.y ?? null);
  }
  if (columnLayoutAnimation && !columnAnimationFrame) {
    columnAnimationFrame = requestAnimationFrame(animateColumnLayoutFrame);
  }
  const selected = visibleTracks()[state.selectedTrack];
  status.textContent = `${state.tab}. ${state.status}. ${state.transport}. `
    + (selected ? `Selected track ${state.selectedTrack + 1}: ${selected.title || selected.filename}.` : "No track selected.");
}

function announce(message) {
  status.textContent = message;
}

function toggleFont() {
  setFontProfile(state.font === "MICRO" ? "STANDARD" : "MICRO");
}

function setFontProfile(font) {
  state.font = font;
  saveDisplayOptions();
  render();
}

function toggleContrast() {
  setContrastProfile(state.contrast === "STANDARD" ? "HIGH_CONTRAST" : "STANDARD");
}

function setContrastProfile(contrast) {
  state.contrast = contrast === "HIGH_CONTRAST" ? "HIGH_CONTRAST" : "STANDARD";
  RGB = paletteRGB(displayPalette());
  saveDisplayOptions();
  render();
}

function setTheme(theme) {
  state.theme = theme === "NIGHTBOY" ? "NIGHTBOY" : "GAMEBOY";
  if (document.documentElement) document.documentElement.dataset.theme = state.theme;
  RGB = paletteRGB(displayPalette());
  saveDisplayOptions();
  render();
}

function adjustAnimationTime(key, delta) {
  setPreference(key, Math.max(0, Math.min(1000, animationMilliseconds(key) + delta)));
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
  if (view === "QUEUE") {
    const queue = state.activeQueue.length
      ? [...state.activeQueue] : [...(activePlaylistTab()?.playlist || tracks)];
    let tab = state.playlistTabs.find((entry) => samePlaylist(entry.playlist, queue));
    if (!tab) {
      syncActivePlaylistTab();
      tab = state.playlistTabs.length < 64 ? {
        id: playlistTabID(), title: "QUEUE", gameKey: null,
        playlist: [...queue], selectedTrack: state.selectedTrack, scroll: state.queueScroll,
      } : activePlaylistTab();
      if (tab && !state.playlistTabs.some((entry) => entry.id === tab.id)) state.playlistTabs.push(tab);
      if (tab) tab.playlist = [...queue];
    }
    if (tab) {
      state.activePlaylistTabId = tab.id;
      tracks = [...queue];
    }
    if (!state.activeQueue.length) state.activeQueue = [...queue];
  }
  state.tab = view;
  state.selectedTrack = 0;
  state.queueScroll = 0;
  render();
  if (view === "QUEUE") persistPlaylistTabs();
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
  const complete = time - transition.startedAt >= transition.duration;
  if (!complete && !animationFrameIsDue(transition, time)) {
    sidebarAnimationFrame = requestAnimationFrame(animateSidebarFrame);
    return;
  }
  const progress = Math.max(0, Math.min(1,
    (time - transition.startedAt) / transition.duration));
  transition.progress = transition.fromProgress
    + (transition.toProgress - transition.fromProgress) * easeSelection(progress);
  render(false, true, time);
  if (!complete) {
    sidebarAnimationFrame = requestAnimationFrame(animateSidebarFrame);
  } else {
    state.sidebarTransition = null;
    render(false, true, time);
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
      const duration = animationMilliseconds("autoResizeAnimationMilliseconds")
        * Math.abs(targetProgress - currentProgress);
      if (!animationEnabled("autoResizeAnimationEnabled") || duration <= 0) {
        state.sidebarTransition = null;
        render();
        return;
      }
      state.sidebarTransition = {
        system,
        fromProgress: currentProgress,
        toProgress: targetProgress,
        progress: currentProgress,
        startedAt: performance.now(),
        duration,
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
    let tab = state.playlistTabs.find((entry) => entry.gameKey === selectedKey);
    if (!tab && state.playlistTabs.length < 64) {
      tab = {
        id: playlistTabID(),
        title: game.displayName || game.name || "PLAYLIST",
        gameKey: selectedKey,
        playlist: [],
        selectedTrack: 0,
        scroll: 0,
      };
      state.playlistTabs.push(tab);
    }
    if (tab) {
      tab.title = game.displayName || game.name || tab.title;
      tab.playlist = [...tracks];
      tab.selectedTrack = 0;
      tab.scroll = 0;
      state.activePlaylistTabId = tab.id;
    }
    if (!state.currentTrackId) state.activeQueue = [...tracks];
    state.tab = "LIBRARY";
    persistPlaylistTabs();
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

function randomQueue() {
  return state.activeQueue.length ? state.activeQueue : activeTracks();
}

function queueSignature(queue) {
  return JSON.stringify(queue.map(trackID));
}

function preparePlaylistRandom(queue) {
  const signature = queueSignature(queue);
  if (signature === state.randomQueueSignature) return;
  state.randomQueueSignature = signature;
  state.randomPlaylistQueue = queue;
  state.randomSeenIDs = new Set();
  if (queue.some((track) => trackID(track) === state.currentTrackId)) {
    state.randomSeenIDs.add(state.currentTrackId);
  }
}

function randomItem(items) {
  return items.length ? items[Math.floor(Math.random() * items.length)] : null;
}

function pickPlaylistRandom(queue, allowRepeat = false) {
  if (!queue.length) return null;
  preparePlaylistRandom(queue);
  let candidates = queue.filter((track) => !state.randomSeenIDs.has(trackID(track)));
  if (!candidates.length && allowRepeat) {
    state.randomSeenIDs = new Set(state.currentTrackId ? [state.currentTrackId] : []);
    candidates = queue.filter((track) => !state.randomSeenIDs.has(trackID(track)));
    if (!candidates.length && queue.length === 1) candidates = queue;
  }
  return randomItem(candidates);
}

async function pickLibraryRandom() {
  if (!bridge?.databaseGameTracks || !state.games.length) return null;
  const token = ++state.libraryRandomToken;
  const currentTrack = randomQueue().find((track) => trackID(track) === state.currentTrackId);
  const currentGame = currentTrack && state.games.find((game) => game.name === currentTrack.game
    && game.system === currentTrack.system
    && (!game.rootPath || !currentTrack.rootPath || currentTrack.rootPath.startsWith(game.rootPath)));
  const candidates = state.games.map((game) => ({
    game,
    weight: Math.max(0, Number(game.trackCount) || 0)
      - (currentGame && gameKey(game) === gameKey(currentGame) ? 1 : 0),
  })).filter(({ weight }) => weight > 0);
  if (!candidates.length) {
    state.games.forEach((game) => candidates.push({ game, weight: Math.max(1, Number(game.trackCount) || 1) }));
  }

  while (candidates.length) {
    const totalWeight = candidates.reduce((sum, candidate) => sum + candidate.weight, 0);
    let choice = Math.random() * totalWeight;
    const selectedIndex = candidates.findIndex(({ weight }) => {
      choice -= weight;
      return choice < 0;
    });
    const [{ game }] = candidates.splice(selectedIndex < 0 ? 0 : selectedIndex, 1);
    try {
      const rows = await bridge.databaseGameTracks([game]);
      if (token !== state.libraryRandomToken) return null;
      if (!Array.isArray(rows) || !rows.length) continue;
      const differentTracks = rows.filter((track) => trackID(track) !== state.currentTrackId);
      const track = randomItem(differentTracks.length ? differentTracks : rows);
      return { track, queue: rows };
    } catch (error) {
      if (token !== state.libraryRandomToken) return null;
      state.status = `RANDOM ERROR: ${error.message}`;
      render();
    }
  }
  return null;
}

function recordRandomHistory(track, queue) {
  const mode = state.preferences.randomMode || "off";
  if (mode === "off") return;
  const id = trackID(track);
  const current = state.randomHistory[state.randomHistoryIndex];
  if (current?.id === id) {
    current.track = track;
    return;
  }
  state.randomHistory = state.randomHistory.slice(0, state.randomHistoryIndex + 1);
  const historyQueue = mode === "library" ? [track]
    : (state.randomPlaylistQueue.length ? state.randomPlaylistQueue : queue);
  state.randomHistory.push({ id, track, queue: historyQueue });
  state.randomHistoryIndex = state.randomHistory.length - 1;
  if (state.randomHistory.length > RANDOM_HISTORY_LIMIT) {
    state.randomHistory.splice(0, state.randomHistory.length - RANDOM_HISTORY_LIMIT);
    state.randomHistoryIndex = state.randomHistory.length - 1;
  }
}

function playRandomHistory(delta) {
  const index = state.randomHistoryIndex + delta;
  if (index < 0 || index >= state.randomHistory.length) return false;
  const entry = state.randomHistory[index];
  state.randomHistoryIndex = index;
  startTrack(entry.track, entry.queue, { recordHistory: false });
  return true;
}

function resetRandomPlaybackState() {
  ++state.libraryRandomToken;
  state.randomSeenIDs = new Set();
  state.randomQueueSignature = "";
  state.randomPlaylistQueue = [];
  state.randomHistory = [];
  state.randomHistoryIndex = -1;
  if ((state.preferences.randomMode || "off") === "off" || !state.currentTrackId) return;
  const queue = randomQueue();
  const current = queue.find((track) => trackID(track) === state.currentTrackId);
  if (current) {
    if (state.preferences.randomMode === "playlist") {
      preparePlaylistRandom(queue);
      state.randomSeenIDs.add(state.currentTrackId);
    }
    recordRandomHistory(current, queue);
  }
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
      intent: { repeatMode: state.preferences.repeatMode === "one" ? "one" : "off" },
    });
    if (state.currentTrackId !== completedId) return;
    const repeatMode = state.preferences.repeatMode || "off";
    const randomMode = state.preferences.randomMode || "off";
    let next = null;
    let nextQueue = queue;
    if (repeatMode === "one") {
      next = queue.find((track) => trackID(track) === completedId) || null;
    } else if (randomMode === "playlist") {
      next = pickPlaylistRandom(queue, repeatMode === "all");
    } else if (randomMode === "library") {
      const selection = await pickLibraryRandom();
      if (state.currentTrackId !== completedId) return;
      next = selection?.track || null;
      nextQueue = selection?.queue || queue;
    } else {
      next = decision?.action === "play"
        ? queue.find((track) => trackID(track) === decision.trackId) : null;
    }
    if (next) {
      const visibleIndex = visibleTracks().findIndex((track) => trackID(track) === trackID(next));
      if (visibleIndex >= 0) selectTrack(visibleIndex, false);
      await startTrack(next, nextQueue);
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
    const localTracks = Array.isArray(playlist) ? playlist : [];
    const sourceName = String(snapshot.rootPath || snapshot.path || "LOCAL FILES").split(/[\\/]/).filter(Boolean).at(-1) || "LOCAL FILES";
    state.status = localTracks.length ? "LOCAL FILES" : "NO PLAYABLE FILES AT PATH";
    createPlaylistTab({ duplicateActive: false, title: sourceName, playlist: localTracks });
    state.tab = "QUEUE";
    persistPlaylistTabs();
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

async function startTrack(track, queue = activeTracks(), { recordHistory = true } = {}) {
  if (!track || !bridge?.nativePlaybackStart) return;
  ++state.libraryRandomToken;
  const token = ++state.playbackToken;
  state.currentTrackId = trackID(track);
  state.playbackGeneration = 0;
  state.activeQueue = [...queue];
  if (state.preferences.randomMode === "playlist") {
    preparePlaylistRandom(state.activeQueue);
    state.randomSeenIDs.add(state.currentTrackId);
  }
  if (recordHistory) recordRandomHistory(track, state.activeQueue);
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
      tempo: playbackTempoForTrack(track, pref),
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
  ++state.libraryRandomToken;
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

async function playAdjacent(delta) {
  const shownTracks = visibleTracks();
  const queue = state.activeQueue.length ? state.activeQueue : shownTracks;
  if (!queue.length) return;
  const randomMode = state.preferences.randomMode || "off";
  if (randomMode !== "off") {
    if (playRandomHistory(delta)) return;
    if (delta < 0) return;
    if (randomMode === "playlist") {
      const next = pickPlaylistRandom(queue, state.preferences.repeatMode === "all");
      if (next) {
        const visibleIndex = shownTracks.findIndex((track) => trackID(track) === trackID(next));
        if (visibleIndex >= 0) selectTrack(visibleIndex, false);
        await startTrack(next, queue);
      } else {
        state.status = "RANDOM CYCLE COMPLETE";
        render();
      }
      return;
    }
    const currentId = state.currentTrackId;
    const selection = await pickLibraryRandom();
    if (state.currentTrackId !== currentId) return;
    if (!selection) {
      state.status = "NO LIBRARY TRACKS";
      render();
      return;
    }
    const visibleIndex = shownTracks.findIndex((track) => trackID(track) === trackID(selection.track));
    if (visibleIndex >= 0) selectTrack(visibleIndex, false);
    await startTrack(selection.track, selection.queue);
    return;
  }
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
  const token = ++state.preferenceMutationToken;
  state.preferences = { ...prior, [key]: value };
  if (key === "randomMode") resetRandomPlaybackState();
  render();
  try {
    const snapshot = { ...state.preferences };
    const save = state.preferenceSaveChain.catch(() => {})
      .then(() => bridge.frontendSettingsSave(snapshot));
    state.preferenceSaveChain = save.catch(() => {});
    await save;
    if (updateAudio) await configureAudio();
    if (state.currentTrackId && [
      "longPlayEnabled",
      "manualPlayTimeSeconds",
      "unknownDurationSeconds",
      "fadeEnabled",
      "spcFadeSeconds",
      "playbackSpeed",
      "playbackSpeedEnabled",
      "libvgmPlaybackSpeed",
      "libvgmPlaybackSpeedEnabled",
    ].includes(key)) {
      const pref = state.preferences;
      const currentTrack = state.activeQueue.find((track) => trackID(track) === state.currentTrackId)
        || tracks.find((track) => trackID(track) === state.currentTrackId);
      applyNativeStatus(await bridge.nativePlaybackReconfigure({
        longPlayEnabled: pref.longPlayEnabled === true,
        manualPlayMilliseconds: Math.max(0, Number(pref.manualPlayTimeSeconds ?? 180)) * 1000,
        fadeMilliseconds: pref.fadeEnabled === false ? 0 : Math.max(0, Number(pref.spcFadeSeconds ?? 6)) * 1000,
        unknownDurationMilliseconds: Math.max(1, Number(pref.unknownDurationSeconds ?? 150)) * 1000,
        tempo: playbackTempoForTrack(currentTrack, pref),
      }));
    }
  } catch (error) {
    if (token !== state.preferenceMutationToken) return;
    state.preferences = prior;
    if (key === "randomMode") resetRandomPlaybackState();
    state.status = `OPTION ERROR: ${error.message}`;
    render();
  }
}

function toggleLongPlay() {
  setPreference("longPlayEnabled", state.preferences.longPlayEnabled !== true);
}

function toggleRepeatOne() {
  setPreference("repeatMode", state.preferences.repeatMode === "one" ? "off" : "one");
}

function setRandomMode(mode) {
  setPreference("randomMode", mode);
}

function toggleRandomMode(mode) {
  setRandomMode(state.preferences.randomMode === mode ? "off" : mode);
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

function findTargetEntry(point, predicate = () => true) {
  for (let index = hitTargets.length - 1; index >= 0; index -= 1) {
    const entry = hitTargets[index];
    const { widget, box, clip } = entry;
    if (!predicate(widget) || (clip && (point.x < clip.x || point.x >= clip.x + clip.width
      || point.y < clip.y || point.y >= clip.y + clip.height))) continue;
    if (point.x >= box.x && point.x < box.x + box.width
      && point.y >= box.y && point.y < box.y + box.height) return entry;
  }
  return null;
}

function findTarget(point) {
  return findTargetEntry(point)?.widget ?? null;
}

function setHorizontalScrollFromThumb(pointerX, thumbOffset) {
  const box = state.tableScrollbarBox;
  const thumb = state.tableScrollbarThumb;
  if (!box || !thumb || state.tableHorizontalMax <= 0) return;
  const trackLeft = box.x + 1;
  const trackWidth = Math.max(1, box.width - 2);
  const travel = Math.max(0, trackWidth - thumb.width);
  if (travel <= 0) return;
  const thumbLeft = Math.max(trackLeft, Math.min(trackLeft + travel, pointerX - thumbOffset));
  state.tableHorizontalScroll = (thumbLeft - trackLeft) / travel * state.tableHorizontalMax;
  render();
}

function reorderTableColumn(sourceKey, targetKey, targetBox, pointerX) {
  if (!sourceKey || !targetKey || sourceKey === "index" || targetKey === "index") return;
  const keys = tableColumns(activeTracks()).all.map((column) => column.key)
    .filter((key) => key !== "index");
  const sourceIndex = keys.indexOf(sourceKey);
  const targetIndex = keys.indexOf(targetKey);
  if (sourceIndex < 0 || targetIndex < 0) return;
  keys.splice(sourceIndex, 1);
  let insertionIndex = targetIndex + (pointerX >= targetBox.x + targetBox.width / 2 ? 1 : 0);
  if (sourceIndex < insertionIndex) insertionIndex -= 1;
  keys.splice(Math.max(0, Math.min(keys.length, insertionIndex)), 0, sourceKey);
  state.columnOrder = keys;
  saveDisplayOptions();
  render();
}

canvas.addEventListener("pointerdown", (event) => {
  const point = logicalPoint(event);
  const entry = findTargetEntry(point);
  const target = entry?.widget;
  if (target?.meta.horizontalScrollbar) {
    const thumb = state.tableScrollbarThumb;
    const localX = point.x - (thumb?.x ?? point.x);
    const thumbOffset = thumb && localX >= 0 && localX < thumb.width
      ? localX : Math.floor((thumb?.width ?? 1) / 2);
    pointerInteraction = { kind: "scrollbar", pointerId: event.pointerId, thumbOffset, startX: point.x };
    canvas.setPointerCapture?.(event.pointerId);
    setHorizontalScrollFromThumb(point.x, thumbOffset);
    event.preventDefault?.();
  } else if (target?.meta.columnHeader && target.meta.reorderable) {
    pointerInteraction = {
      kind: "column",
      pointerId: event.pointerId,
      sourceKey: target.meta.columnKey,
      targetKey: target.meta.columnKey,
      targetBox: entry.box,
      startX: point.x,
      startY: point.y,
      moved: false,
    };
    canvas.setPointerCapture?.(event.pointerId);
  }
});

canvas.addEventListener("pointermove", (event) => {
  const point = logicalPoint(event);
  if (pointerInteraction?.kind === "scrollbar") {
    if (Math.abs(point.x - pointerInteraction.startX) >= 1) suppressNextClick = true;
    pointerInteraction.startX = point.x;
    setHorizontalScrollFromThumb(point.x, pointerInteraction.thumbOffset);
    return;
  }
  if (pointerInteraction?.kind === "column") {
    const distance = Math.hypot(point.x - pointerInteraction.startX, point.y - pointerInteraction.startY);
    if (distance >= 3) {
      pointerInteraction.moved = true;
      suppressNextClick = true;
      const dropTarget = findTargetEntry(point, (widget) => widget.meta.columnHeader);
      if (dropTarget?.widget.meta.reorderable) {
        pointerInteraction.targetKey = dropTarget.widget.meta.columnKey;
        pointerInteraction.targetBox = dropTarget.box;
      }
    }
    return;
  }
  const target = findTarget(point);
  canvas.style.cursor = target ? "pointer" : "default";
});

canvas.addEventListener("pointerup", (event) => {
  if (!pointerInteraction || (pointerInteraction.pointerId !== undefined
    && event.pointerId !== undefined && pointerInteraction.pointerId !== event.pointerId)) return;
  const interaction = pointerInteraction;
  pointerInteraction = null;
  if (interaction.kind === "column" && interaction.moved) {
    const point = logicalPoint(event);
    const dropTarget = findTargetEntry(point, (widget) => widget.meta.columnHeader && widget.meta.reorderable);
    if (dropTarget) {
      interaction.targetKey = dropTarget.widget.meta.columnKey;
      interaction.targetBox = dropTarget.box;
    }
    reorderTableColumn(interaction.sourceKey, interaction.targetKey, interaction.targetBox, point.x);
    suppressNextClick = true;
  } else if (interaction.kind === "scrollbar") {
    suppressNextClick = true;
  }
});

canvas.addEventListener("pointercancel", () => { pointerInteraction = null; });

canvas.addEventListener("contextmenu", (event) => {
  const point = logicalPoint(event);
  const header = findTargetEntry(point, (widget) => widget.meta.columnHeader);
  if (!header) return;
  event.preventDefault();
  state.columnMenu = { x: point.x, y: point.y };
  render();
});

canvas.addEventListener("click", (event) => {
  canvas.focus({ preventScroll: true });
  if (suppressNextClick) {
    suppressNextClick = false;
    return;
  }
  const target = findTarget(logicalPoint(event));
  if (state.columnMenu && !target?.meta.columnMenuItem) {
    state.columnMenu = null;
    if (target?.meta.onClick) target.meta.onClick(event);
    else render();
    return;
  }
  if (target?.meta.onClick) target.meta.onClick(event);
});

canvas.addEventListener("wheel", (event) => {
  if (state.tab === "SETTINGS") return;
  event.preventDefault();
  const point = logicalPoint(event);
  const viewport = state.tableViewportBox;
  const overTable = viewport && point.x >= viewport.x && point.x < viewport.x + viewport.width
    && point.y >= viewport.y && point.y < viewport.y + viewport.height;
  if (overTable && (event.shiftKey || Math.abs(event.deltaX) > 0)) {
    const rect = canvas.getBoundingClientRect();
    const delta = event.deltaX || event.deltaY;
    state.tableHorizontalScroll = Math.max(0, Math.min(state.tableHorizontalMax,
      state.tableHorizontalScroll + delta * WIDTH / Math.max(1, rect.width)));
    render();
    return;
  }
  const sidebarWidth = libraryPaneWidth() * STYLE_SCALE + 8 * STYLE_SCALE;
  const library = point.x < sidebarWidth;
  const key = library ? "libraryScroll" : "queueScroll";
  const length = library ? libraryRows().length : visibleTracks().length;
  const direction = Math.sign(event.deltaY);
  state[key] = Math.max(0, Math.min(Math.max(0, length - visibleRowCount()), state[key] + direction * 3));
  render();
}, { passive: false });

canvas.addEventListener("keydown", (event) => {
  const commandKey = event.metaKey || event.ctrlKey;
  if (commandKey && event.key === ",") {
    event.preventDefault();
    state.tab = "SETTINGS";
    render();
  } else if (commandKey && /^[1-9]$/.test(event.key)) {
    event.preventDefault();
    const tab = state.playlistTabs[Number(event.key) - 1];
    if (tab) activatePlaylistTab(tab.id);
  } else if (event.code === "Escape" && state.columnMenu) {
    event.preventDefault();
    state.columnMenu = null;
    render();
  } else if (event.shiftKey && (event.code === "ArrowLeft" || event.code === "ArrowRight")) {
    event.preventDefault();
    state.tableHorizontalScroll = Math.max(0, Math.min(state.tableHorizontalMax,
      state.tableHorizontalScroll + (event.code === "ArrowRight" ? 1 : -1) * 8 * fontProfile().advance));
    render();
  } else if (event.code === "Space") {
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
  if (columnAnimationFrame) cancelAnimationFrame(columnAnimationFrame);
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
      case "longPlay": toggleLongPlay(); break;
      case "repeatOne": toggleRepeatOne(); break;
      case "playlistRandom": toggleRandomMode("playlist"); break;
      case "libraryRandom": toggleRandomMode("library"); break;
      case "newPlaylistTab": createPlaylistTab({ duplicateActive: true }); break;
      case "closePlaylistTab": closePlaylistTab(); break;
      case "openPath": openLocalPath(); break;
      case "settings": state.tab = "SETTINGS"; render(); break;
      case "library": selectSidebarView("LIBRARY"); break;
      case "queue": selectSidebarView("QUEUE"); break;
      case "optionsPage:DISPLAY": state.tab = "SETTINGS"; state.optionsPage = "DISPLAY"; render(); break;
      case "optionsPage:PLAYBACK": state.tab = "SETTINGS"; state.optionsPage = "PLAYBACK"; render(); break;
      case "optionsPage:AUDIO": state.tab = "SETTINGS"; state.optionsPage = "AUDIO"; render(); break;
      case "optionsPage:INTERFACE": state.tab = "SETTINGS"; state.optionsPage = "INTERFACE"; render(); break;
      case "optionsPage:LIBRARY": state.tab = "SETTINGS"; state.optionsPage = "LIBRARY"; render(); break;
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
    const priorRandomMode = state.preferences.randomMode || "off";
    state.preferences = settings || {};
    if (priorRandomMode !== (state.preferences.randomMode || "off")) resetRandomPlaybackState();
    render();
  });
  bridge.onCatalogReloaded?.(() => loadCatalog());
  bridge.onLibrarySnapshot?.((snapshot) => {
    if (Array.isArray(snapshot?.playlist)) {
      createPlaylistTab({ duplicateActive: false, title: "QUEUE", playlist: snapshot.playlist });
      state.tab = "QUEUE";
      persistPlaylistTabs();
      render();
    }
  });
  (async () => {
    let restoredTabs = false;
    try {
      state.preferences = await bridge.frontendSettingsLoad();
      await configureAudio();
      await loadFavorites();
      restoredTabs = restorePlaylistTabs(await bridge.playlistTabsLoad?.());
    } catch (error) {
      state.status = `OPTION ERROR: ${error.message}`;
      render();
    }
    await loadCatalog();
    if (restoredTabs) restorePlaylistTabs(await bridge.playlistTabsLoad?.());
    if (!state.playlistTabs.length) {
      state.playlistTabs = [{
        id: playlistTabID(), title: "PLAYLIST", gameKey: null, playlist: [...tracks], selectedTrack: 0, scroll: 0,
      }];
      state.activePlaylistTabId = state.playlistTabs[0].id;
    }
    state.playlistTabsReady = true;
    persistPlaylistTabs();
    render();
    try { applyNativeStatus(await bridge.nativePlaybackState()); } catch (_) { /* No active transport. */ }
  })();
}
