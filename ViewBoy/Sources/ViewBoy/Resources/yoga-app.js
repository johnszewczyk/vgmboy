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
const BASELINE_LAYOUT_UNIT_CSS_PIXELS = 2.5;
const RANDOM_HISTORY_LIMIT = 256;
const APP_BORDER_GAP_DOTS = 8;
const BUTTON_BORDER_DOTS = 1;
const DEFAULT_CONTROL_PADDING_DOTS = 4;
const DEFAULT_UI_GAP_DOTS = 4;
const DEFAULT_PLAYLIST_GAP_DOTS = 4;
const SPACING_DOTS_MIN = 1;
const SPACING_DOTS_MAX = 8;
const EQ_BAR_MIN_DOTS = 100;
const EQ_BAR_INSET_DOTS = 2;
const EQ_GAIN_MIN_DB = 0;
const EQ_GAIN_MAX_DB = 12;
const EQ_GAIN_STEP_DB = 0.5;
const EQ_GAIN_STEPS = (EQ_GAIN_MAX_DB - EQ_GAIN_MIN_DB) / EQ_GAIN_STEP_DB;
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
function packedPalette(palette) {
  return Uint32Array.from(palette, ([red, green, blue]) =>
    ((255 << 24) | (blue << 16) | (green << 8) | red) >>> 0);
}
let packedRGB = packedPalette(RGB);
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
  a: ["00000", "01110", "00001", "01111", "10001", "01111", "00000"],
  b: ["10000", "10000", "11110", "10001", "10001", "10001", "11110"],
  c: ["00000", "01111", "10000", "10000", "10000", "01111", "00000"],
  d: ["00001", "00001", "01111", "10001", "10001", "10001", "01111"],
  e: ["00000", "01110", "10001", "11111", "10000", "01111", "00000"],
  f: ["00110", "01001", "01000", "11100", "01000", "01000", "01000"],
  g: ["00000", "01111", "10001", "10001", "01111", "00001", "01110"],
  h: ["10000", "10000", "11110", "10001", "10001", "10001", "10001"],
  i: ["00100", "00000", "01100", "00100", "00100", "00100", "01110"],
  j: ["00010", "00000", "00010", "00010", "00010", "10010", "01100"],
  k: ["10000", "10000", "10010", "10100", "11000", "10100", "10010"],
  l: ["01100", "00100", "00100", "00100", "00100", "00100", "01110"],
  m: ["00000", "11010", "10101", "10101", "10101", "10101", "10101"],
  n: ["00000", "11110", "10001", "10001", "10001", "10001", "10001"],
  o: ["00000", "01110", "10001", "10001", "10001", "01110", "00000"],
  p: ["00000", "11110", "10001", "10001", "11110", "10000", "10000"],
  q: ["00000", "01111", "10001", "10001", "01111", "00001", "00001"],
  r: ["00000", "10110", "11001", "10000", "10000", "10000", "10000"],
  s: ["00000", "01111", "10000", "01110", "00001", "11110", "00000"],
  t: ["01000", "01000", "11100", "01000", "01000", "01001", "00110"],
  u: ["00000", "10001", "10001", "10001", "10001", "10011", "01101"],
  v: ["00000", "10001", "10001", "10001", "01010", "01010", "00100"],
  w: ["00000", "10001", "10001", "10101", "10101", "10101", "01010"],
  x: ["00000", "10001", "01010", "00100", "01010", "10001", "00000"],
  y: ["00000", "10001", "10001", "10001", "01111", "00001", "01110"],
  z: ["00000", "11111", "00010", "00100", "01000", "11111", "00000"],
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
  "…": ["00000", "00000", "00000", "00000", "00000", "10101", "10101"],
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
  "|": ["00100", "00100", "00100", "00100", "00100", "00100", "00100"],
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
  "…": ["000", "000", "000", "000", "101"],
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
  "|": ["010", "010", "010", "010", "010"],
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
function storedSpacing(value, fallback) {
  const number = Number(value);
  return Math.max(SPACING_DOTS_MIN, Math.min(SPACING_DOTS_MAX,
    Number.isFinite(number) ? Math.round(number) : fallback));
}
function displayPalette() {
  return PALETTES[state.theme][state.contrast];
}
function saveDisplayOptions() {
  try {
    localStorage.setItem(DISPLAY_OPTIONS_KEY, JSON.stringify({
      font: state.font,
      contrast: state.contrast,
      theme: state.theme,
      controlPaddingDots: state.controlPaddingDots,
      uiGapDots: state.uiGapDots,
      playlistGapDots: state.playlistGapDots,
      transportSymbols: state.transportSymbols,
      columnOrder: state.columnOrder,
      expandedPathNodes: [...state.expandedPathNodes],
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
let imageWords = new Uint32Array(image.data.buffer, image.data.byteOffset, image.data.byteLength / 4);
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
let equalizerAnimationFrame = 0;
let libraryScrollFrame = 0;
let screenTransitionFrame = 0;
let spacingAnimationFrame = 0;
let pendingLibraryScrollDelta = 0;
const libraryScrollFrameTiming = { lastFrameAt: Number.NaN };
let searchCursorTimer = 0;
let searchCursorVisible = false;
let equalizerFrameTiming = { lastFrameAt: Number.NaN };
let equalizerAnimations = new Map();
let screenTransition = null;
let spacingAnimation = null;
let suppressFramePresentation = false;
let optionsReturnTab = "LIBRARY";
let columnLayoutAnimation = null;
let lastColumnWidths = null;
let tabLayoutAnimation = null;
let reorderAnimation = null;
let reorderPreview = null;
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
  controlPaddingDots: storedSpacing(savedDisplayOptions.controlPaddingDots, DEFAULT_CONTROL_PADDING_DOTS),
  uiGapDots: storedSpacing(savedDisplayOptions.uiGapDots ?? savedDisplayOptions.uiGutterDots, DEFAULT_UI_GAP_DOTS),
  playlistGapDots: storedSpacing(savedDisplayOptions.playlistGapDots, DEFAULT_PLAYLIST_GAP_DOTS),
  searchQuery: "",
  searchFocused: false,
  transportSymbols: savedDisplayOptions.transportSymbols === true,
  optionsPage: "DISPLAY",
  transport: "stopped",
  currentTrackId: null,
  activeQueue: [],
  playbackQueue: [],
  randomSeenIDs: new Set(),
  randomQueueSignature: "",
  randomPlaylistQueue: [],
  randomHistory: [],
  randomHistoryIndex: -1,
  equalizerBarBoxes: [],
  equalizerLabelBoxes: [],
  equalizerValueBoxes: [],
  libraryRandomToken: 0,
  games: [],
  favoriteTracks: [],
  favoriteIDs: new Set(),
  historyTracks: [],
  databaseFiles: [],
  databaseFilesReady: false,
  databaseFilesLoading: false,
  expandedPathNodes: new Set(Array.isArray(savedDisplayOptions.expandedPathNodes)
    ? savedDisplayOptions.expandedPathNodes : []),
  selectedPathKey: null,
  sidebarMode: "consoles",
  databaseLocation: null,
  archiveCacheLocation: "",
  archiveCache: null,
  volumeGaugeBox: null,
  databaseOptionsStatus: "",
  editingDurationKey: null,
  durationDraft: "",
  durationBounds: null,
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
  libraryScrollOffset: 0,
  libraryViewportHeight: 0,
  libraryContentHeight: 0,
  libraryViewportWidget: null,
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
packedRGB = packedPalette(RGB);
if (document.documentElement) document.documentElement.dataset.theme = state.theme;

let tracks = [];

const bridge = window.viewBoy;

function trackID(track) {
  return track?.playlistId || `${track?.path || ""}:${track?.trackIndex || 0}`;
}

function favoriteID(track) {
  return track?.favoriteId || trackID(track);
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
  if (state.tab === "HISTORY") return state.historyTracks;
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
  if (!tab || state.tab === "FAVORITES" || state.tab === "HISTORY" || state.tab === "SETTINGS") return;
  tab.playlist = [...tracks];
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
      sourceKey: tab.sourceKey || null,
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
    sourceKey: typeof tab.sourceKey === "string" ? tab.sourceKey : null,
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
  const leavingOptions = state.tab === "SETTINGS";
  if (tab.id !== state.activePlaylistTabId) syncActivePlaylistTab();
  else if (state.tab !== "SETTINGS" && state.tab !== "FAVORITES" && state.tab !== "HISTORY") return false;
  state.activePlaylistTabId = tab.id;
  tracks = [...tab.playlist];
  state.activeQueue = [...tab.playlist];
  state.activeGameKey = tab.gameKey;
  state.selectedTrack = Math.min(tab.selectedTrack || 0, Math.max(0, tab.playlist.length - 1));
  state.queueScroll = Math.max(0, tab.scroll || 0);
  state.tableHorizontalScroll = 0;
  if (leavingOptions) navigateAppTab("QUEUE");
  else {
    state.tab = "QUEUE";
    render();
  }
  persistPlaylistTabs();
  return true;
}

function captureTabWidths() {
  const tabIDs = new Set(state.playlistTabs.map((tab) => tab.id));
  return Object.fromEntries(hitTargets
    .filter(({ widget }) => widget.meta.reorderKind === "tab" && tabIDs.has(widget.meta.reorderKey))
    .map(({ widget, box }) => [widget.meta.reorderKey, box.width]));
}

function animateTabLayout(fromWidths, visualTabs) {
  tabLayoutAnimation = null;
  if (!fromWidths || !visualTabs.length || !state.playlistTabs.length) return;
  const duration = animationMilliseconds("autoResizeAnimationMilliseconds");
  if (!animationEnabled("autoResizeAnimationEnabled") || duration <= 0) return;
  const priorWidth = Object.values(fromWidths).reduce((sum, width) => sum + width, 0);
  if (priorWidth <= 0) return;
  const targetWidth = priorWidth / state.playlistTabs.length;
  const targetIDs = new Set(state.playlistTabs.map((tab) => tab.id));
  const from = Object.fromEntries(visualTabs.map((tab) => [tab.id, fromWidths[tab.id] ?? 0]));
  const to = Object.fromEntries(visualTabs.map((tab) => [tab.id, targetIDs.has(tab.id) ? targetWidth : 0]));
  if (!visualTabs.some((tab) => from[tab.id] !== to[tab.id])) return;
  tabLayoutAnimation = {
    from,
    to,
    visualTabs,
    startedAt: performance.now(),
    duration,
  };
}

function tabLayoutWeightAt(id, time = currentRenderTime) {
  const animation = tabLayoutAnimation;
  if (!animation || !Object.hasOwn(animation.to, id)) return 1;
  const progress = Math.max(0, Math.min(1, (time - animation.startedAt) / animation.duration));
  const eased = easeSelection(progress);
  return animation.from[id] + (animation.to[id] - animation.from[id]) * eased;
}

function createPlaylistTab({ duplicateActive = true, title = null, playlist = null, gameKey = null } = {}) {
  const priorWidths = state.tab !== "FAVORITES" && state.tab !== "HISTORY" && state.tab !== "SETTINGS"
    ? captureTabWidths() : null;
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
  if (priorWidths) animateTabLayout(priorWidths, [...state.playlistTabs]);
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
    const priorTabs = [...state.playlistTabs];
    const priorWidths = state.tab !== "FAVORITES" && state.tab !== "SETTINGS"
      ? captureTabWidths() : null;
    const wasActive = state.playlistTabs[index].id === state.activePlaylistTabId;
    state.playlistTabs.splice(index, 1);
    if (priorWidths) animateTabLayout(priorWidths, priorTabs);
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
  return items.sort((first, second) => {
    if (state.sortColumn === "timestamp") {
      return direction * ((Number(first.track.timestampMilliseconds) || 0)
        - (Number(second.track.timestampMilliseconds) || 0)) || first.index - second.index;
    }
    return direction * String(tableValue(first.track, state.sortColumn, first.index))
      .localeCompare(String(tableValue(second.track, state.sortColumn, second.index)), undefined,
        { numeric: true, sensitivity: "base" }) || first.index - second.index;
  })
    .map(({ track }) => track);
}

function easeSelection(progress) {
  return progress < 0.5
    ? 2 * progress * progress
    : 1 - Math.pow(-2 * progress + 2, 2) / 2;
}

function reorderKeyFor(widget) {
  if (!widget.meta.reorderKey) return null;
  return widget.meta.reorderContainer || widget.meta.columnHeader ? widget.meta.reorderKey : null;
}

function widgetTranslationX(widget, targetX, time) {
  const base = widget.meta.translateX ?? 0;
  const key = reorderKeyFor(widget);
  const kind = widget.meta.reorderKind;
  if (!key || !kind) return base;
  if (pointerInteraction?.kind === "reorder" && pointerInteraction.dragging
    && pointerInteraction.itemKind === kind && pointerInteraction.sourceKey === key) {
    return base + pointerInteraction.pointX - pointerInteraction.grabOffset - targetX;
  }
  if (reorderAnimation?.kind !== kind || !Object.hasOwn(reorderAnimation.fromX, key)) return base;
  const progress = Math.max(0, Math.min(1,
    (time - reorderAnimation.startedAt) / reorderAnimation.duration));
  return base + (reorderAnimation.fromX[key] - targetX) * (1 - easeSelection(progress));
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
  if (!Number.isFinite(animation.lastFrameAt)) {
    animation.lastFrameAt = time;
    return true;
  }
  const elapsed = time - animation.lastFrameAt;
  if (elapsed < ANIMATION_FRAME_INTERVAL_MS - 0.25) return false;
  const intervals = Math.max(1, Math.floor((elapsed + 0.25) / ANIMATION_FRAME_INTERVAL_MS));
  animation.lastFrameAt += intervals * ANIMATION_FRAME_INTERVAL_MS;
  return true;
}

export function screenTransitionSnapshot() {
  return screenTransition
    ? { direction: screenTransition.direction, targetTab: screenTransition.targetTab }
    : null;
}

export function bitmapFontSnapshot(name = "STANDARD") {
  const font = FONT_PROFILES[name] ?? FONT_PROFILES.STANDARD;
  return {
    width: font.width,
    height: font.height,
    glyphs: Object.fromEntries(Object.entries(font.glyphs).map(([glyph, rows]) => [glyph, [...rows]])),
  };
}

export function hitTargetSnapshot() {
  const snapshot = hitTargets.map(({ widget, box }) => ({
    name: widget.meta.controlTitle || widget.meta.text
      || (Number.isInteger(widget.meta.equalizerBar) ? `EQ BAND ${widget.meta.equalizerBar + 1}` : ""),
    columnMenuItem: widget.meta.columnMenuItem === true,
    columnHeader: widget.meta.columnHeader === true,
    trackIndex: Number.isInteger(widget.meta.trackIndex) ? widget.meta.trackIndex : null,
    searchField: widget.meta.searchField === true,
    playlistTabTitle: widget.meta.playlistTabTitle === true,
    playlistTabClose: widget.meta.playlistTabClose === true,
    editableDurationKey: widget.meta.editableDuration ?? null,
    playlistTabId: widget.meta.playlistTabId ?? null,
    textInset: widget.meta.inset ?? controlPaddingDots(),
    glyphAdvance: fontProfile().advance,
    reorderKind: widget.meta.reorderKind ?? null,
    reorderKey: widget.meta.reorderKey ?? null,
    statusReadout: widget.meta.statusReadout === true,
    textAlign: widget.meta.align ?? "left",
    sidebarDisclosure: widget.meta.sidebarDisclosure === true,
    disclosureProgress: widget.meta.sidebarDisclosure ? widget.meta.disclosureProgress : null,
    box: { ...box },
    equalizerValueBox: Number.isInteger(widget.meta.equalizerBar)
      ? { ...state.equalizerValueBoxes[widget.meta.equalizerBar] } : null,
    equalizerLabelBox: Number.isInteger(widget.meta.equalizerBar)
      ? { ...state.equalizerLabelBoxes[widget.meta.equalizerBar] } : null,
    equalizerTrackBounds: Number.isInteger(widget.meta.equalizerBar)
      && state.equalizerBarBoxes[widget.meta.equalizerBar]
      ? equalizerTrackBounds(state.equalizerBarBoxes[widget.meta.equalizerBar]) : null,
    equalizerTickXs: Number.isInteger(widget.meta.equalizerBar)
      && state.equalizerBarBoxes[widget.meta.equalizerBar]
      ? equalizerTickPositions(state.equalizerBarBoxes[widget.meta.equalizerBar]) : null,
  })).filter((target) => target.name);
  layoutEntries.filter(({ widget }) => widget.meta.statusReadout).forEach(({ widget, box }) => {
    snapshot.push({
      name: widget.meta.text,
      statusReadout: true,
      textAlign: widget.meta.align ?? "left",
      textInset: widget.meta.inset ?? controlPaddingDots(),
      box: { ...box },
    });
  });
  return snapshot;
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
  return normalizedBitmapText(value).toUpperCase();
}

function normalizedBitmapText(value) {
  const text = String(value)
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[–—]/g, "-")
    .replace(/[’‘]/g, "'");
  return state.font === "STANDARD" ? text : text.toUpperCase();
}

function setSearchFocused(focused) {
  state.searchFocused = focused === true;
  if (searchCursorTimer) clearTimeout(searchCursorTimer);
  searchCursorTimer = 0;
  searchCursorVisible = state.searchFocused;
  if (state.searchFocused) searchCursorTimer = setTimeout(blinkSearchCursor, 500);
}

function resetSearchCursorBlink() {
  if (!state.searchFocused) return;
  if (searchCursorTimer) clearTimeout(searchCursorTimer);
  searchCursorVisible = true;
  searchCursorTimer = setTimeout(blinkSearchCursor, 500);
}

function blinkSearchCursor() {
  searchCursorTimer = 0;
  if (!state.searchFocused) return;
  searchCursorVisible = !searchCursorVisible;
  render();
  searchCursorTimer = setTimeout(blinkSearchCursor, 500);
}

function searchFieldText(box) {
  const query = state.searchQuery;
  const prefix = query ? "SEARCH: " : "SEARCH LIBRARY";
  const cursor = state.searchFocused && searchCursorVisible ? "|" : "";
  const text = `${prefix}${query}${cursor}`;
  const availableWidth = box.width - 2 * controlPaddingDots();
  const limit = Math.max(1, Math.floor((availableWidth + 1) / fontProfile().advance));
  const characters = Array.from(text);
  if (characters.length <= limit) return text;
  if (state.searchFocused && query) {
    const queryCharacters = Array.from(query);
    const queryLength = Math.max(0, limit - Array.from(prefix).length - cursor.length);
    return `${Array.from(prefix).slice(0, Math.max(0, limit - queryLength - cursor.length)).join("")}`
      + `${queryCharacters.slice(-queryLength).join("")}${cursor}`;
  }
  return `${characters.slice(0, Math.max(0, limit - 1)).join("")}…`;
}

function fontProfile() {
  return FONT_PROFILES[state.font] ?? FONT_PROFILES.MICRO;
}

function drawRawText(value, x, y, shade) {
  const font = fontProfile();
  const text = normalizedBitmapText(value);
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
  let text = normalizedBitmapText(value);
  const chars = Array.from(text);
  if (chars.length > maxCharacters) {
    text = maxCharacters === 1 ? "…" : `${chars.slice(0, maxCharacters - 1).join("")}…`;
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

function presentPixels(startY = 0, endY = HEIGHT, startX = 0, endX = WIDTH) {
  const outputWidth = WIDTH * DEVICE_PIXELS_PER_LCD_DOT;
  const firstRow = Math.max(0, Math.floor(startY));
  const lastRow = Math.min(HEIGHT, Math.ceil(endY));
  const firstColumn = Math.max(0, Math.floor(startX));
  const lastColumn = Math.min(WIDTH, Math.ceil(endX));
  if (lastRow <= firstRow || lastColumn <= firstColumn) return;
  const background = packedRGB[3];
  for (let y = firstRow; y < lastRow; y += 1) {
    const sourceRow = y * WIDTH;
    const topRow = y * DEVICE_PIXELS_PER_LCD_DOT * outputWidth;
    for (let x = firstColumn; x < lastColumn; x += 1) {
      const face = packedRGB[pixels[sourceRow + x]];
      const outputX = x * DEVICE_PIXELS_PER_LCD_DOT;
      const top = topRow + outputX;
      const middle = top + outputWidth;
      const bottom = middle + outputWidth;
      // A two-by-two shaded face leaves an unlit one-device-pixel seam.
      imageWords[top] = face;
      imageWords[top + 1] = face;
      imageWords[top + 2] = background;
      imageWords[middle] = face;
      imageWords[middle + 1] = face;
      imageWords[middle + 2] = background;
      imageWords[bottom] = background;
      imageWords[bottom + 1] = background;
      imageWords[bottom + 2] = background;
    }
  }
  context.putImageData(image, 0, 0, firstColumn * DEVICE_PIXELS_PER_LCD_DOT,
    firstRow * DEVICE_PIXELS_PER_LCD_DOT,
    (lastColumn - firstColumn) * DEVICE_PIXELS_PER_LCD_DOT,
    (lastRow - firstRow) * DEVICE_PIXELS_PER_LCD_DOT);
}

function composeScreenTransition(transition, time) {
  const progress = Math.max(0, Math.min(1,
    (time - transition.startedAt) / transition.duration));
  const offset = Math.round(HEIGHT * easeSelection(progress));
  pixels.fill(3);
  for (let y = 0; y < HEIGHT; y += 1) {
    const outgoingY = transition.direction === "up" ? y + offset : y - offset;
    if (outgoingY >= 0 && outgoingY < HEIGHT) {
      const sourceStart = outgoingY * WIDTH;
      pixels.set(transition.fromPixels.subarray(sourceStart, sourceStart + WIDTH), y * WIDTH);
    }
    const incomingY = transition.direction === "up" ? y - HEIGHT + offset : y + HEIGHT - offset;
    if (incomingY >= 0 && incomingY < HEIGHT) {
      const sourceStart = incomingY * WIDTH;
      pixels.set(transition.toPixels.subarray(sourceStart, sourceStart + WIDTH), y * WIDTH);
    }
  }
}

function present(startY = 0, endY = HEIGHT, startX = 0, endX = WIDTH) {
  if (suppressFramePresentation) return;
  if (screenTransition) {
    const endpointPixels = pixels.slice();
    screenTransition.toPixels = endpointPixels;
    composeScreenTransition(screenTransition, performance.now());
    presentPixels();
    pixels.set(endpointPixels);
    return;
  }
  presentPixels(startY, endY, startX, endX);
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
      const displayText = typeof meta.textValue === "function" ? meta.textValue(box) : text;
      drawText(displayText, box.x + (meta.inset ?? controlPaddingDots()), textY,
        box.width - (meta.inset ?? controlPaddingDots()) * 2,
        meta.textShade ?? 0, meta.align ?? "left");
      paintClip = previousClip;
    },
  });
}

function rowHeight(extraDots = 0) {
  return (fontProfile().height + extraDots) / STYLE_SCALE;
}

function spacingValue(key, time = currentRenderTime) {
  const animation = spacingAnimation;
  if (!animation || !Object.hasOwn(animation.to, key)) return state[key];
  const progress = Math.max(0, Math.min(1, (time - animation.startedAt) / animation.duration));
  return animation.from[key]
    + (animation.to[key] - animation.from[key]) * easeSelection(progress);
}

function controlPaddingDots() {
  return spacingValue("controlPaddingDots");
}

function uiGapDots() {
  return spacingValue("uiGapDots");
}

function uiGroupInsetDots() {
  return uiGapDots();
}

function uiOptionsInsetDots() {
  return uiGapDots() * 2;
}

function buttonStandardHeight() {
  return rowHeight(2 * controlPaddingDots() + 2 * BUTTON_BORDER_DOTS);
}

function uiGap() {
  return uiGapDots() / STYLE_SCALE;
}

function uiSectionGap() {
  return uiGapDots() * 2 / STYLE_SCALE;
}

function playlistGap() {
  return spacingValue("playlistGapDots") / STYLE_SCALE;
}

function textLayoutWidth(text, horizontalInsetDots = controlPaddingDots()) {
  return (Array.from(String(text)).length * fontProfile().advance + horizontalInsetDots * 2) / STYLE_SCALE;
}

function framedTextWidth(text) {
  return (Array.from(String(text)).length * fontProfile().advance
    + (BUTTON_BORDER_DOTS + controlPaddingDots()) * 2) / STYLE_SCALE;
}

function buttonWidth(text) {
  return framedTextWidth(text);
}

function minimumColumnWidth(characterCount = 1) {
  return (characterCount * fontProfile().advance
    + (BUTTON_BORDER_DOTS + controlPaddingDots()) * 2) / STYLE_SCALE;
}

function oneDot() {
  return 1 / STYLE_SCALE;
}

function libraryToolbarItems() {
  return [
    { title: "LIB", view: "LIBRARY", onClick: () => { void setSidebarMode("consoles"); selectSidebarView("LIBRARY"); } },
    { title: "PATH", view: "PATHS", onClick: () => { void setSidebarMode("paths"); selectSidebarView("LIBRARY"); } },
    { title: "Q", view: "QUEUE", onClick: () => selectSidebarView("QUEUE") },
    { title: "FAV", view: "FAVORITES", onClick: () => selectSidebarView("FAVORITES") },
    { title: "HIST", view: "HISTORY", controlTitle: "HISTORY", onClick: () => { void showPlaybackHistory(); } },
    { title: "OPEN", onClick: () => openLocalPath() },
    { title: "SYNC", onClick: () => loadCatalog() },
    { title: "OPT", controlTitle: "OPTIONS", onClick: () => openOptionsScreen() },
  ];
}

function libraryPaneWidth() {
  const items = libraryToolbarItems();
  const buttonsWidth = items.reduce((sum, item) => sum + buttonWidth(item.title), 0);
  return Math.max(WIDTH < 420 ? 94 : 128,
    buttonsWidth + Math.max(0, items.length - 1) * uiGap() + 4);
}

function statusBar(parent, leftText, rightText = state.transport.toUpperCase()) {
  const row = controlRow(parent, { height: buttonStandardHeight(), gap: uiGap() });
  for (const [text, align] of [[leftText, "left"], [rightText, "right"]]) {
    label(row, text, { flexGrow: 1, flexBasis: 0, minWidth: 0, height: buttonStandardHeight() }, {
      border: BUTTON_BORDER_DOTS,
      textShade: 0,
      align,
      inset: controlPaddingDots(),
      statusReadout: true,
    });
  }
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
  label(row, text, { flexGrow: 1, height: titleHeight }, {
    textShade: 0, inset: controlPaddingDots(), align: "center",
  });
  return row;
}

function pixelButton(parent, text, onClick, style = {}) {
  return label(parent, text, {
    direction: FlexDirection.Row,
    alignItems: Align.Center,
    justifyContent: Justify.Center,
    height: buttonStandardHeight(),
    width: style.width ?? buttonWidth(text),
    minWidth: style.minWidth,
    flexGrow: style.flexGrow ?? 0,
    flexShrink: style.flexShrink,
    flexBasis: style.flexBasis,
  }, {
    border: 1,
    fill: style.selected ? 2 : undefined,
    textShade: 0,
    inset: controlPaddingDots(),
    align: "center",
    controlTitle: style.controlTitle,
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
    alignItems: Align.Stretch,
    height,
    gap: uiGap(),
  }, {
    onClick,
    controlTitle: title,
    paint(box) {
      strokeRect(box.x, box.y, box.width, box.height, 1);
    },
    ...extraMeta,
  });
  const marker = checked ? "[x]" : "[ ]";
  label(row, marker, {
    width: textLayoutWidth(marker),
    height,
  }, { textShade: 0, align: "center", inset: controlPaddingDots() });
  label(row, title, { flexGrow: 1, height }, { textShade: 0, inset: controlPaddingDots() });
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
  label(row, title, { width: titleWidth, height }, { textShade: 0, inset: controlPaddingDots() });
  choices.forEach((choice) => pixelButton(row, choice.title, choice.onClick, {
    flexGrow: 1,
    selected: choice.selected,
    controlTitle: `${title} ${choice.title}`,
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
  label(row, title, { flexGrow: 1, height }, {
    textShade: 0, inset: controlPaddingDots(),
  });
  const controlHeight = buttonStandardHeight();
  pixelButton(row, "[-]", onDecrease, { controlTitle: `${title} -` });
  pixelButton(row, "[+]", onIncrease, { controlTitle: `${title} +` });
  label(row, value, { width: framedTextWidth(value), height: controlHeight }, {
    border: 1,
    textShade: 0,
    align: "center",
    inset: controlPaddingDots(),
  });
  return row;
}

function beginDurationEdit(key, minimum, maximum, fallback, allowOpen = false) {
  state.editingDurationKey = key;
  state.durationDraft = "";
  state.durationBounds = { key, minimum, maximum, fallback, allowOpen };
  render();
}

function finishDurationEdit(commit) {
  const bounds = state.durationBounds;
  const draft = state.durationDraft.trim();
  state.editingDurationKey = null;
  state.durationDraft = "";
  state.durationBounds = null;
  if (!commit || !bounds) { render(); return; }
  let seconds = null;
  if (bounds.allowOpen && draft.toUpperCase() === "OPEN") seconds = 0;
  else if (/^\d+$/.test(draft)) seconds = Number(draft);
  else {
    const match = draft.match(/^(\d+):(\d{1,2})$/);
    if (match && Number(match[2]) < 60) seconds = Number(match[1]) * 60 + Number(match[2]);
  }
  if (seconds === null || !Number.isFinite(seconds)) { render(); return; }
  setPreference(bounds.key, Math.max(bounds.minimum, Math.min(bounds.maximum, Math.round(seconds))));
}

function durationInput(parent, key, value, minimum, maximum, fallback, allowOpen = false) {
  const editing = state.editingDurationKey === key;
  const display = editing ? `${state.durationDraft}|` : value;
  return label(parent, display, { width: framedTextWidth("60:00"), height: buttonStandardHeight() }, {
    border: BUTTON_BORDER_DOTS,
    fill: editing ? 2 : undefined,
    textShade: 0,
    align: "center",
    inset: controlPaddingDots(),
    editableDuration: key,
    controlTitle: `${key} TIME`,
    onClick: () => beginDurationEdit(key, minimum, maximum, fallback, allowOpen),
  });
}

function optionDurationAdjuster(parent, title, key, minimum, maximum, fallback, step, allowOpen = false) {
  const row = controlRow(parent, { height: buttonStandardHeight() }, {
    paint(box) { line(box.x, box.y + box.height - 1, box.x + box.width, box.y + box.height, 2); },
  });
  label(row, title, { flexGrow: 1, height: buttonStandardHeight() }, {
    textShade: 0, inset: controlPaddingDots(),
  });
  pixelButton(row, "[-]", () => adjustPlaybackDuration(key, -step, minimum, maximum, fallback), {
    controlTitle: `${title} -`,
  });
  pixelButton(row, "[+]", () => adjustPlaybackDuration(key, step, minimum, maximum, fallback), {
    controlTitle: `${title} +`,
  });
  durationInput(row, key, optionDuration(state.preferences[key] ?? fallback, allowOpen),
    minimum, maximum, fallback, allowOpen);
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
    case "favorite": return state.favoriteIDs.has(favoriteID(track)) ? "[x]" : "[]";
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
    case "timestamp": return track.timestamp || "";
    default: return track[key] || "";
  }
}

const configurableColumns = [
  { key: "filename", title: "FILE" },
  { key: "game", title: "GAME" },
  { key: "artist", title: "ARTIST" },
  { key: "path", title: "PATH" },
  { key: "size", title: "SIZE" },
  { key: "timestamp", title: "DATE/TIME" },
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
  if (items.some((track) => Number.isFinite(Number(track.timestampMilliseconds)))) {
    columns.push({ key: "timestamp", title: "DATE/TIME", width: 80, align: "center" });
  }

  // Reserve the sort-marker cell in every sortable heading. Without this
  // floor, an auto-sized header can clip its arrow even though row widths and
  // the 250 ms resize animation are using the same column measurements.
  columns.forEach((column) => {
    if (column.key === "favorite" || column.key === "index") return;
    const headingCharacters = Array.from(column.title).length + 1;
    const headingWidth = (headingCharacters * fontProfile().advance
      + 2 * (BUTTON_BORDER_DOTS + controlPaddingDots())) / STYLE_SCALE;
    column.width = Math.max(column.width, headingWidth);
  });

  const autoSize = state.preferences.columnAutoSize !== false;
  const content = tableContentLengths(items, columns);
  if (autoSize) {
    columns.forEach((column) => {
      if (column.key === "favorite" || column.key === "index" || column.key === "title") return;
      const textWidth = ((content.lengths[column.key] ?? 0) * fontProfile().advance
        + 2 * (BUTTON_BORDER_DOTS + controlPaddingDots())) / STYLE_SCALE;
      const headingCharacters = Array.from(column.title).length + 1;
      const headingWidth = (headingCharacters * fontProfile().advance
        + 2 * (BUTTON_BORDER_DOTS + controlPaddingDots())) / STYLE_SCALE;
      column.width = Math.max(headingWidth, textWidth);
    });
  }

  const columnVisibility = state.preferences.columnVisibility || {};
  const visible = columns.filter((column) => column.mandatory || columnVisibility[column.key] !== false);
  const byKey = new Map(columns.map((column) => [column.key, column]));
  const savedOrder = reorderPreview?.kind === "column" ? reorderPreview.keys : state.columnOrder;
  const preferredOrder = savedOrder.filter((key) => key !== "index" && byKey.has(key));
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
    gap: playlistGap(),
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
      inset: controlPaddingDots(),
      border: 1,
      fill: marker ? 2 : undefined,
      align: "center",
      columnKey: column.key,
      columnHeader: true,
      reorderKind: "column",
      reorderKey: column.key,
      reorderable: column.reorderable !== false,
      onClick: column.sortable === false ? undefined : () => toggleSort(column.key),
    });
  });
  return header;
}

function createQueueRow(parent, index, track, columns) {
  const rowHeightValue = rowHeight(2 * controlPaddingDots());
  const row = makeWidget(parent, {
    direction: FlexDirection.Row,
    alignItems: Align.Center,
    height: rowHeightValue,
    gap: playlistGap(),
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
    inset: controlPaddingDots(),
    align: column.rowAlign ?? column.align ?? "left",
    trackIndex: index,
    onClick: column.key === "favorite" ? () => toggleFavorite(track) : undefined,
  }));
  return row;
}

function disclosureSquare(box, indent = controlPaddingDots()) {
  const font = fontProfile();
  const size = font.height;
  const centerX = box.x + indent + font.advance / 2;
  const centerY = box.y + Math.floor(box.height / 2);
  return {
    x: Math.floor(centerX - size / 2),
    y: Math.floor(centerY - size / 2),
    width: size,
    height: size,
  };
}

function paintChevron(box, progress, indent = controlPaddingDots()) {
  const font = fontProfile();
  const square = disclosureSquare(box, indent);
  const glyph = font.glyphs[">"];
  const angle = Math.max(0, Math.min(1, progress)) * Math.PI / 2;
  const cosine = Math.cos(angle);
  const sine = Math.sin(angle);
  const glyphInset = Math.floor((square.width - font.width) / 2);
  const centerX = square.x + square.width / 2;
  const centerY = square.y + square.height / 2;
  for (let row = 0; row < font.height; row += 1) {
    for (let column = 0; column < font.width; column += 1) {
      if (glyph[row][column] !== "1") continue;
      const sourceX = glyphInset + column + 0.5 - square.width / 2;
      const sourceY = row + 0.5 - square.height / 2;
      const x = Math.round(centerX + sourceX * cosine - sourceY * sine - 0.5);
      const y = Math.round(centerY + sourceX * sine + sourceY * cosine - 0.5);
      fillRect(x, y, 1, 1, 0);
    }
  }
}

function createLibraryRow(parent, text, options = {}) {
  const selected = options.selected ?? false;
  if (options.spacer) {
    return makeWidget(parent, {
      height: uiGap() * (options.revealProgress ?? 1),
      flexShrink: 0,
    });
  }
  const rowHeightValue = rowHeight(2 * controlPaddingDots());
  const revealProgress = options.revealProgress;
  return label(parent, text, {
    height: rowHeightValue * (revealProgress ?? 1),
    paddingHorizontal: controlPaddingDots(),
  }, {
    textShade: 0,
    clipToBox: revealProgress !== undefined,
    revealProgress,
    onClick: options.onClick,
    sidebarDisclosure: options.disclosure === true,
    disclosureProgress: options.disclosureProgress ?? 0,
    disclosureIndent: options.disclosureIndent ?? controlPaddingDots(),
    inset: options.indent ?? (options.disclosure ? controlPaddingDots() + 2 * fontProfile().advance : 0),
    paint(box) {
      if (selected) fillRect(box.x, box.y, box.width, box.height, 2);
      if (options.disclosure) paintChevron(box, options.disclosureProgress ?? 0,
        options.disclosureIndent ?? controlPaddingDots());
    },
  });
}

function visibleRowCount() {
  const toolbarGrowth = 2 * (buttonStandardHeight() + uiGap()) + uiGap();
  return Math.max(1, Math.floor((HEIGHT / STYLE_SCALE - 78 - toolbarGrowth)
    / rowHeight(2 * controlPaddingDots())));
}

function visibleLibraryRowCount() {
  const rootChrome = 2 * APP_BORDER_GAP_DOTS + 2 * buttonStandardHeight() + 3 * uiGap()
    + rowHeight(4);
  const sidebarChrome = 3 * buttonStandardHeight() + 4 * uiGap();
  return Math.max(1, Math.floor((HEIGHT / STYLE_SCALE - rootChrome - sidebarChrome)
    / rowHeight(2 * controlPaddingDots())));
}

function libraryRowPixelHeight(row) {
  if (row.spacer) return uiGapDots() * (row.revealProgress ?? 1);
  return rowHeight(2 * controlPaddingDots()) * STYLE_SCALE * (row.revealProgress ?? 1);
}

function libraryRowsWithLineGaps(rows) {
  const lines = rows.filter((row) => !row.spacer);
  const spaced = [];
  lines.forEach((row, index) => {
    if (index > 0) {
      const previousProgress = lines[index - 1].revealProgress ?? 1;
      const currentProgress = row.revealProgress ?? 1;
      spaced.push({
        spacer: true,
        revealProgress: Math.min(previousProgress, currentProgress),
      });
    }
    spaced.push(row);
  });
  return spaced;
}

function libraryRows() {
  if (state.sidebarMode === "paths") return pathRows();
  const query = normalizedText(state.searchQuery).trim();
  const groups = new Map();
  for (const game of state.games) {
    const system = game.system || "OTHER";
    const gameName = game.displayName || game.name || "";
    const matches = !query || normalizedText(`${gameName} ${game.name || ""} ${system}`).includes(query);
    if (!matches) continue;
    if (!groups.has(system)) groups.set(system, []);
    groups.get(system).push(game);
  }
  const rows = [];
  const transition = state.sidebarTransition;
  for (const system of [...groups.keys()].sort()) {
    const searching = Boolean(query);
    const expanded = searching || state.expandedSystems.has(system);
    const isTransitioning = transition?.system === system;
    const showChildren = expanded || (isTransitioning && transition.progress > 0);
    const disclosureProgress = isTransitioning ? transition.progress : Number(expanded);
    rows.push({ text: system, system, group: true, disclosureProgress });
    if (showChildren) {
      for (const game of groups.get(system)) {
        rows.push({
          text: game.displayName || game.name,
          game,
          indent: controlPaddingDots() + 2 * fontProfile().advance,
          revealProgress: isTransitioning ? transition.progress : undefined,
        });
      }
    }
  }
  return rows;
}

function pathRows() {
  const query = normalizedText(state.searchQuery).trim();
  const rows = [];
  const transition = state.sidebarTransition;
  function append(node, depth, isRoot = false, revealProgress) {
    const children = Array.isArray(node.children) ? node.children : [];
    const directMatch = !query || normalizedText(`${node.name || ""} ${node.path || ""}`).includes(query);
    const matchingChildren = query ? children.filter((child) => pathSubtreeMatches(child, query)) : children;
    if (query && !directMatch && matchingChildren.length === 0) return false;
    const expanded = isRoot || Boolean(query) || state.expandedPathNodes.has(node.path);
    const inTransition = transition?.path === node.path;
    const progress = inTransition ? transition.progress : Number(expanded);
    rows.push({
      text: node.name || node.path || "PATH",
      node,
      group: children.length > 0,
      indent: controlPaddingDots() + depth * 2 * fontProfile().advance
        + (children.length ? 2 * fontProfile().advance : 0),
      disclosureIndent: controlPaddingDots() + depth * 2 * fontProfile().advance,
      disclosureProgress: progress,
      revealProgress,
    });
    if (children.length && (expanded || (inTransition && progress > 0))) {
      const childRevealProgress = inTransition ? transition.progress : revealProgress;
      for (const child of matchingChildren) {
        append(child, depth + 1, false, childRevealProgress);
      }
    }
    return true;
  }
  for (const root of state.databaseFiles) append(root, 0, true);
  if (!rows.length) rows.push({ text: state.databaseFilesLoading ? "LOADING PATHS" : "NO CATALOG PATHS" });
  return rows;
}

function pathSubtreeMatches(node, query) {
  return normalizedText(`${node.name || ""} ${node.path || ""}`).includes(query)
    || (Array.isArray(node.children) && node.children.some((child) => pathSubtreeMatches(child, query)));
}

function libraryStatusText(filteredGames, systemCount, query) {
  if (query) return `MATCH ${filteredGames.length} / ${state.games.length} GAMES`;
  const selectedGame = state.games.find((game) => gameKey(game) === state.selectedGameKey);
  if (selectedGame) {
    const title = selectedGame.displayName || selectedGame.name || "GAME";
    const trackCount = Number(selectedGame.trackCount);
    const tracksLabel = Number.isFinite(trackCount) ? `${trackCount} TRK` : "TRACKS";
    return `${title} / ${tracksLabel}`;
  }
  if (state.selectedSystem) {
    const gamesInSystem = state.games.filter((game) => (game.system || "OTHER") === state.selectedSystem).length;
    return `${state.selectedSystem} / ${gamesInSystem} GAMES`;
  }
  return `${state.games.length} GAMES / ${systemCount} SYSTEMS`;
}

function addLibraryPane(parent) {
  const paneWidth = libraryPaneWidth();
  const library = makeWidget(parent, {
    direction: FlexDirection.Column,
    width: paneWidth,
    minWidth: paneWidth,
    maxWidth: paneWidth,
    flexBasis: paneWidth,
    flexGrow: 0,
    flexShrink: 0,
    gap: 0,
    padding: uiGapDots(),
  }, {
    paint(box) {
      strokeRect(box.x, box.y, box.width, box.height, 1);
    },
  });
  label(library, state.searchQuery ? `SEARCH: ${state.searchQuery}` : "SEARCH LIBRARY", {
    height: buttonStandardHeight(),
  }, {
    textShade: 0,
    inset: controlPaddingDots(),
    border: 1,
    fill: state.searchFocused ? 2 : undefined,
    searchField: true,
    textValue: searchFieldText,
    controlTitle: "SEARCH LIBRARY",
    onClick: () => { setSearchFocused(true); render(); },
  });
  makeWidget(library, { height: uiGap() });
  const navigation = controlRow(library, { gap: uiGap() });
  libraryToolbarItems().forEach((item) => pixelButton(navigation, item.title, item.onClick, {
    width: 0,
    minWidth: 0,
    flexBasis: 0,
    flexGrow: 1,
    flexShrink: 1,
    selected: item.view === "PATHS" ? state.sidebarMode === "paths"
      : item.view === "HISTORY" ? state.tab === "HISTORY"
        : item.view === state.tab && state.sidebarMode !== "paths",
    controlTitle: item.controlTitle,
  }));
  makeWidget(library, { height: uiGap() });
  const rows = libraryRowsWithLineGaps(libraryRows());
  const count = visibleLibraryRowCount();
  const rowHeightDots = rowHeight(2 * controlPaddingDots()) * STYLE_SCALE;
  state.libraryContentHeight = rows.reduce((sum, row) => sum + libraryRowPixelHeight(row), 0);
  const estimatedViewportHeight = state.libraryViewportHeight || count * rowHeightDots;
  const maxScroll = Math.max(0, state.libraryContentHeight - estimatedViewportHeight);
  state.libraryScrollOffset = Math.max(0, Math.min(maxScroll, state.libraryScrollOffset));
  let firstRow = 0;
  let rowTop = 0;
  while (firstRow < rows.length
    && rowTop + libraryRowPixelHeight(rows[firstRow]) <= state.libraryScrollOffset) {
    rowTop += libraryRowPixelHeight(rows[firstRow]);
    firstRow += 1;
  }
  const partialRowOffset = Math.max(0, state.libraryScrollOffset - rowTop);
  const viewport = makeWidget(library, {
    flexGrow: 1,
    flexShrink: 1,
    flexBasis: 0,
    minWidth: 0,
    minHeight: 0,
    overflow: Overflow.Hidden,
  }, {
    id: "sidebar-tree-viewport",
    clipChildren: true,
  });
  const content = makeWidget(viewport, {
    direction: FlexDirection.Column,
  }, { translateY: -partialRowOffset });
  state.libraryViewportWidget = viewport;
  const lastRow = Math.min(rows.length, firstRow + count * 2 + 2);
  rows.slice(firstRow, lastRow).forEach((row) => {
    if (row.spacer) {
      createLibraryRow(content, "", { spacer: true, revealProgress: row.revealProgress });
      return;
    }
    createLibraryRow(content, row.text, {
      selected: row.node ? row.node.path === state.selectedPathKey
        : row.game && gameKey(row.game) === state.selectedGameKey,
      indent: row.indent,
      disclosure: row.group,
      disclosureProgress: row.disclosureProgress,
      disclosureIndent: row.disclosureIndent,
      revealProgress: row.revealProgress,
      onClick: (event) => {
        if (row.node) {
          if (row.node.kind === "folder" && row.node.children?.length) {
            if (event.detail >= 2) void loadPathNode(row.node);
            else togglePathNode(row.node);
          } else void loadPathNode(row.node);
        } else if (row.game) void loadGame(row.game);
        else if (row.system) void toggleSystem(row.system);
      },
    });
  });
  const query = normalizedText(state.searchQuery).trim();
  const filteredGames = query ? state.games.filter((game) =>
    normalizedText(`${game.displayName || game.name || ""} ${game.name || ""} ${game.system || "OTHER"}`)
      .includes(query)) : state.games;
  const systemCount = new Set(filteredGames.map((game) => game.system || "OTHER")).size;
  const leftStatus = state.sidebarMode === "paths"
    ? (state.selectedPathKey ? state.selectedPathKey.split("/").filter(Boolean).at(-1) || "PATHS"
      : `${state.databaseFiles.length} ROOTS / ${state.databaseFilesReady ? "PATH INDEX" : "PATHS"}`)
    : libraryStatusText(filteredGames, systemCount, query);
  statusBar(library, leftStatus, state.status);
  return library;
}

function addCatalogPane(parent) {
  const viewTracks = visibleTracks();
  const panel = makeWidget(parent, {
    direction: FlexDirection.Column,
    flexGrow: 1,
    flexShrink: 1,
    gap: 0,
    padding: uiGapDots(),
  }, {
    paint(box) {
      strokeRect(box.x, box.y, box.width, box.height, 1);
    },
  });
  if (state.tab !== "FAVORITES" && state.tab !== "HISTORY") {
    const tabRow = controlRow(panel, { gap: uiGap() });
    const tabList = makeWidget(tabRow, {
      direction: FlexDirection.Row,
      flexGrow: 1,
      flexBasis: 0,
      gap: uiGap(),
      overflow: Overflow.Hidden,
    }, { clipChildren: true });
    const tabs = reorderPreview?.kind === "tab"
      ? reorderPreview.keys.map((id) => state.playlistTabs.find((tab) => tab.id === id)).filter(Boolean)
      : tabLayoutAnimation?.visualTabs ?? state.playlistTabs;
    tabs.forEach((tab) => {
      const isExiting = !state.playlistTabs.some((entry) => entry.id === tab.id);
      const item = makeWidget(tabList, {
        direction: FlexDirection.Row,
        flexGrow: tabLayoutWeightAt(tab.id),
        flexBasis: 0,
        flexShrink: 1,
        minWidth: 0,
        gap: uiGap(),
        height: buttonStandardHeight(),
        alignItems: Align.Center,
      }, {
        clipChildren: true,
        tabLayoutVisual: true,
        reorderContainer: !isExiting && !tabLayoutAnimation,
        reorderKind: "tab",
        reorderKey: tab.id,
        onClick: isExiting ? undefined : () => activatePlaylistTab(tab.id),
        controlTitle: `TAB ${tab.title}`,
        paint(box) {
          if (tab.id === state.activePlaylistTabId) fillRect(box.x, box.y, box.width, box.height, 2);
          strokeRect(box.x, box.y, box.width, box.height, 1);
        },
      });
      label(item, tab.title, {
        flexGrow: 1,
        flexBasis: 0,
        flexShrink: 1,
        minWidth: 0,
        height: buttonStandardHeight(),
      }, {
        textShade: 0,
        inset: controlPaddingDots(),
        align: "left",
        playlistTabTitle: true,
        playlistTabId: tab.id,
        reorderKey: tab.id,
        controlTitle: `TAB ${tab.title}`,
        onClick: isExiting ? undefined : () => activatePlaylistTab(tab.id),
      });
      label(item, "X", {
        width: buttonWidth("X"),
        flexShrink: 0,
        height: buttonStandardHeight(),
      }, {
        textShade: 0,
        inset: controlPaddingDots(),
        align: "center",
        playlistTabClose: true,
        playlistTabId: tab.id,
        controlTitle: "X",
        onClick: isExiting || tabLayoutAnimation ? undefined : () => closePlaylistTab(tab.id),
      });
    });
    pixelButton(tabRow, "[+]", () => createPlaylistTab({ duplicateActive: true }), {
      width: buttonWidth("[+]"),
    });
    makeWidget(panel, { height: uiGap() });
  }
  const columns = resolveTableColumns(tableColumns(viewTracks), currentRenderTime);
  const tableGap = Math.max(0, columns.length - 1) * playlistGap();
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
    gap: uiGap(),
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
  if (!viewTracks.length) label(content, state.status, { height: rowHeight(2 * controlPaddingDots()) }, {
    textShade: 0, inset: controlPaddingDots(),
  });
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
  statusBar(panel, `TRACKS ${first}-${last}/${viewTracks.length}`, state.transport.toUpperCase());
  return panel;
}

function addColumnContextMenu(parent) {
  if (!state.columnMenu) return;

  const height = (configurableColumns.length + 2) * buttonStandardHeight()
    + (configurableColumns.length + 1) * uiGap()
    + 2 * uiGroupInsetDots() / STYLE_SCALE + 2 / STYLE_SCALE;
  const contentWidth = textLayoutWidth("[x]") + uiGap() + textLayoutWidth("ARTIST");
  const width = Math.min(WIDTH / STYLE_SCALE - 16,
    Math.max(68, contentWidth + 2 * uiGroupInsetDots() / STYLE_SCALE + 2 / STYLE_SCALE));
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
    gap: uiGap(),
    padding: uiGroupInsetDots() / STYLE_SCALE,
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
    paddingHorizontal: uiGroupInsetDots() / STYLE_SCALE,
    paddingVertical: uiGapDots() / STYLE_SCALE,
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
    padding: uiGroupInsetDots() / STYLE_SCALE,
  }, {
    paint(box) { strokeRect(box.x, box.y, box.width, box.height, 1); },
  });
  optionSection(group, title);
  return group;
}

function optionsTocWidth() {
  const available = WIDTH / STYLE_SCALE;
  const labelWidth = framedTextWidth("TRANSPORT") + uiOptionsInsetDots() / STYLE_SCALE * 2;
  return Math.min(available * 0.34, Math.max(labelWidth, Math.min(220, available * 0.20)));
}

function addDisplayOptions(parent) {
  const profile = optionGroup(parent, "SCREEN PROFILE");
  optionChoice(profile, "FONT", [
    { title: "MICRO 3X5", selected: state.font === "MICRO", onClick: () => setFontProfile("MICRO") },
    { title: "STANDARD 5X7", selected: state.font === "STANDARD", onClick: () => setFontProfile("STANDARD") },
  ]);
}

function addThemeOptions(parent) {
  const profile = optionGroup(parent, "COLOR THEME");
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

function addTransportOptions(parent) {
  const controls = optionGroup(parent, "TRANSPORT CONTROLS");
  optionChoice(controls, "BUTTONS", [
    { title: "WORDS", selected: !state.transportSymbols, onClick: () => setTransportSymbols(false) },
    { title: "SYMBOLS", selected: state.transportSymbols, onClick: () => setTransportSymbols(true) },
  ]);
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
  return Math.max(EQ_GAIN_MIN_DB, Math.min(EQ_GAIN_MAX_DB, Number.isFinite(value) ? value : 0));
}

function equalizerGainAt(index, time = performance.now()) {
  const animation = equalizerAnimations.get(index);
  if (!animation) return equalizerGain(index);
  const progress = Math.max(0, Math.min(1, (time - animation.startedAt) / animation.duration));
  return animation.from + (animation.to - animation.from) * easeSelection(progress);
}

function changeEqualizerGain(index, delta) {
  setEqualizerGain(index, equalizerGain(index) + delta);
}

function setEqualizerGain(index, value) {
  const now = performance.now();
  const current = equalizerGainAt(index, now);
  const numeric = Number(value);
  const bounded = Number.isFinite(numeric)
    ? Math.max(EQ_GAIN_MIN_DB, Math.min(EQ_GAIN_MAX_DB, numeric))
    : EQ_GAIN_MIN_DB;
  const target = EQ_GAIN_MIN_DB
    + Math.round((bounded - EQ_GAIN_MIN_DB) / EQ_GAIN_STEP_DB) * EQ_GAIN_STEP_DB;
  const gains = Array.from({ length: 10 }, (_, band) => equalizerGain(band));
  gains[index] = target;
  const duration = animationMilliseconds("selectionAnimationMilliseconds");
  if (animationEnabled("selectionAnimationEnabled") && duration > 0 && current !== target
    && state.tab === "SETTINGS" && state.optionsPage === "AUDIO") {
    equalizerAnimations.set(index, { from: current, to: target, startedAt: now, duration });
    equalizerFrameTiming.lastFrameAt = Number.NaN;
  } else {
    equalizerAnimations.delete(index);
  }
  setPreference("equalizerBandGains", gains, true);
  if (equalizerAnimations.size && !equalizerAnimationFrame) {
    equalizerAnimationFrame = requestAnimationFrame(animateEqualizerFrame);
  }
}

function equalizerGainLabel(value) {
  return `+${value.toFixed(1)}`;
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
  optionDurationAdjuster(timing, "LONG PLAY TIME", "manualPlayTimeSeconds", 0, 3600, 180, 30, true);
  optionDurationAdjuster(timing, "UNKNOWN LENGTH", "unknownDurationSeconds", 30, 3600, 150, 30);
  optionDurationAdjuster(timing, "FADE LENGTH", "spcFadeSeconds", 0, 60, 6, 1);
}

function addMethodOptions(parent, pref) {
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
  const { left, right } = equalizerTrackBounds(box);
  const centerY = box.y + Math.floor(box.height / 2);
  const fraction = Math.max(0, Math.min(1,
    (gain - EQ_GAIN_MIN_DB) / (EQ_GAIN_MAX_DB - EQ_GAIN_MIN_DB)));
  const fillWidth = Math.round((right - left) * fraction);
  fillRect(left, box.y + 1, fillWidth, Math.max(1, box.height - 2), 1);
  const tickTop = centerY - 1;
  for (const x of equalizerTickPositions(box)) fillRect(x, tickTop, 1, 3, 2);
}

function paintEqualizerValue(box, gain) {
  fillRect(box.x + 1, box.y + 1, box.width - 2, box.height - 2, 3);
  drawText(equalizerGainLabel(gain), box.x + controlPaddingDots(),
    box.y + Math.floor((box.height - fontProfile().height) / 2),
    box.width - controlPaddingDots() * 2, 0, "center");
}

function equalizerTrackBounds(box) {
  const inset = EQ_BAR_INSET_DOTS;
  const innerLeft = box.x + inset;
  const innerRight = box.x + box.width - 1 - inset;
  const span = Math.max(1, innerRight - innerLeft);
  const usableSpan = span - (span % 2);
  const stepWidth = Math.max(1, Math.floor(usableSpan / EQ_GAIN_STEPS));
  const tickSpan = stepWidth * EQ_GAIN_STEPS;
  const left = innerLeft + Math.floor((usableSpan - tickSpan) / 2);
  return {
    left,
    right: left + tickSpan,
    stepWidth,
  };
}

function equalizerTickPositions(box) {
  const bounds = equalizerTrackBounds(box);
  return Array.from({ length: EQ_GAIN_STEPS + 1 }, (_, index) =>
    bounds.left + index * bounds.stepWidth);
}

function equalizerBand(parent, title, index) {
  const row = makeWidget(parent, {
    direction: FlexDirection.Row,
    alignItems: Align.Center,
    height: rowHeight(12),
    gap: uiGap(),
  });
  label(row, title, { width: textLayoutWidth("16K HZ"), height: buttonStandardHeight() }, {
    textShade: 0,
    inset: controlPaddingDots(),
    paint(box) { state.equalizerLabelBoxes[index] = box; },
  });
  pixelButton(row, "[-]", () => setEqualizerGain(index,
    Math.max(EQ_GAIN_MIN_DB, equalizerGain(index) - EQ_GAIN_STEP_DB)), {
    controlTitle: `EQ ${title} -`,
  });
  pixelButton(row, "[+]", () => setEqualizerGain(index,
    Math.min(EQ_GAIN_MAX_DB, equalizerGain(index) + EQ_GAIN_STEP_DB)), {
    controlTitle: `EQ ${title} +`,
  });
  makeWidget(row, {
    flexGrow: 1,
    minWidth: EQ_BAR_MIN_DOTS / STYLE_SCALE,
    height: buttonStandardHeight(),
  }, {
    equalizerBar: index,
    controlTitle: `EQ ${title}`,
    onClick(event) {
      const box = state.equalizerBarBoxes[index];
      if (!box) return;
      const point = logicalPoint(event);
      const bounds = equalizerTrackBounds(box);
      const fraction = Math.max(0, Math.min(1,
        (point.x - bounds.left) / Math.max(1, bounds.right - bounds.left)));
      const step = Math.round(fraction * EQ_GAIN_STEPS);
      setEqualizerGain(index, EQ_GAIN_MIN_DB + step * EQ_GAIN_STEP_DB);
    },
    paint(box) {
      state.equalizerBarBoxes[index] = box;
      paintEqualizerBar(box, equalizerGainAt(index, currentRenderTime));
    },
  });
  label(row, equalizerGainLabel(equalizerGainAt(index, currentRenderTime)), {
    width: framedTextWidth("+12.0"),
    height: buttonStandardHeight(),
  }, {
    border: 1,
    textShade: 0,
    align: "center",
    inset: controlPaddingDots(),
    paint(box) { state.equalizerValueBoxes[index] = box; },
  });
}

function animateEqualizerFrame(time) {
  equalizerAnimationFrame = 0;
  if (!equalizerAnimations.size) return;
  if (state.tab !== "SETTINGS" || state.optionsPage !== "AUDIO") {
    equalizerAnimations.clear();
    return;
  }

  const complete = [...equalizerAnimations.values()]
    .every((animation) => time - animation.startedAt >= animation.duration);
  if (!complete && !animationFrameIsDue(equalizerFrameTiming, time)) {
    equalizerAnimationFrame = requestAnimationFrame(animateEqualizerFrame);
    return;
  }

  pixels.set(basePixels);
  state.equalizerBarBoxes.forEach((box, index) => {
    if (!box) return;
    const gain = equalizerGainAt(index, time);
    paintEqualizerBar(box, gain);
    const valueBox = state.equalizerValueBoxes[index];
    if (valueBox) paintEqualizerValue(valueBox, gain);
  });
  for (const [index, animation] of equalizerAnimations) {
    if (time - animation.startedAt >= animation.duration) equalizerAnimations.delete(index);
  }
  state.equalizerBarBoxes.forEach((box) => {
    if (box) present(box.y, box.y + box.height, box.x, box.x + box.width);
  });
  state.equalizerValueBoxes.forEach((box) => {
    if (box) present(box.y, box.y + box.height, box.x, box.x + box.width);
  });
  if (equalizerAnimations.size) {
    equalizerAnimationFrame = requestAnimationFrame(animateEqualizerFrame);
  }
}

function addAudioOptions(parent, pref) {
  state.equalizerBarBoxes = [];
  state.equalizerLabelBoxes = [];
  state.equalizerValueBoxes = [];
  const output = optionGroup(parent, "OUTPUT");
  optionToggle(output, "MONO OUTPUT", pref.monoEnabled === true,
    () => setPreference("monoEnabled", pref.monoEnabled !== true, true));
  const volume = Math.max(0, Math.min(1, Number(pref.appVolume ?? 1)));
  const volumeRow = controlRow(output, {}, {
    paint(box) { line(box.x, box.y + box.height - 1, box.x + box.width, box.y + box.height, 2); },
  });
  label(volumeRow, "VOLUME", { width: textLayoutWidth("VOLUME"), height: buttonStandardHeight() }, {
    textShade: 0, inset: controlPaddingDots(),
  });
  pixelButton(volumeRow, "[-]", () => changeVolume(-0.1), { controlTitle: "VOLUME -" });
  pixelButton(volumeRow, "[+]", () => changeVolume(0.1), { controlTitle: "VOLUME +" });
  makeWidget(volumeRow, { flexGrow: 1, minWidth: EQ_BAR_MIN_DOTS / STYLE_SCALE, height: buttonStandardHeight() }, {
    controlTitle: "VOLUME GAUGE",
    onClick(event) {
      const box = state.volumeGaugeBox;
      if (!box) return;
      const point = logicalPoint(event);
      const fraction = Math.max(0, Math.min(1, (point.x - box.x) / Math.max(1, box.width)));
      setPreference("appVolume", Math.round(fraction * 10) / 10, true);
    },
    paint(box) {
      state.volumeGaugeBox = box;
      strokeRect(box.x, box.y, box.width, box.height, 1);
      const count = 10;
      const gap = uiGapDots();
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
  }, { textShade: 0, align: "right", inset: controlPaddingDots() });

  const equalizer = optionGroup(parent, "TEN BAND EQUALIZER");
  optionToggle(equalizer, "EQUALIZER", pref.equalizerEnabled === true,
    () => setPreference("equalizerEnabled", pref.equalizerEnabled !== true, true));
  const equalizerBands = ["31 HZ", "62 HZ", "125 HZ", "250 HZ", "500 HZ", "1K HZ", "2K HZ", "4K HZ", "8K HZ", "16K HZ"];
  equalizerBands.forEach((title, index) => equalizerBand(equalizer, title, index));
}

function addInterfaceOptions(parent, pref) {
  const layout = optionGroup(parent, "PLAYLIST LAYOUT");
  optionToggle(layout, "AUTO-SIZE COLUMNS", pref.columnAutoSize !== false,
    () => setPreference("columnAutoSize", pref.columnAutoSize === false));
  const spacing = optionGroup(parent, "LAYOUT SPACING");
  optionAdjuster(spacing, "CONTROL PADDING", `${controlPaddingDots()} DOTS`,
    () => adjustDisplaySpacing("controlPaddingDots", -1),
    () => adjustDisplaySpacing("controlPaddingDots", 1));
  optionAdjuster(spacing, "UI GAP", `${uiGapDots()} DOTS`,
    () => adjustDisplaySpacing("uiGapDots", -1),
    () => adjustDisplaySpacing("uiGapDots", 1));
  optionAdjuster(spacing, "PLAYLIST GAP", `${state.playlistGapDots} DOTS`,
    () => adjustDisplaySpacing("playlistGapDots", -1),
    () => adjustDisplaySpacing("playlistGapDots", 1));
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

function cacheByteLabel(bytes) {
  const value = Math.max(0, Number(bytes) || 0);
  if (value >= 1024 ** 3) return `${(value / 1024 ** 3).toFixed(1)} GB`;
  if (value >= 1024 ** 2) return `${(value / 1024 ** 2).toFixed(1)} MB`;
  if (value >= 1024) return `${Math.round(value / 1024)} KB`;
  return `${Math.round(value)} B`;
}

async function refreshDatabaseOptions() {
  state.databaseOptionsStatus = "READING DATABASE + CACHE";
  render();
  try {
    const [database, cache, cacheLocation] = await Promise.all([
      bridge?.databaseLocation?.(),
      bridge?.archiveCacheSummary?.(),
      bridge?.archiveCacheLocation?.(),
    ]);
    state.databaseLocation = database || null;
    state.archiveCache = cache || null;
    state.archiveCacheLocation = String(cacheLocation || "");
    state.databaseOptionsStatus = "READY";
  } catch (error) {
    state.databaseOptionsStatus = `DATABASE ERROR: ${error.message}`;
  }
  render();
}

async function configureArchiveCache(next) {
  if (!bridge?.configureArchiveCache) return;
  try {
    const result = await bridge.configureArchiveCache({
      enabled: next.enabled ?? state.archiveCache?.enabled ?? true,
      limitBytes: next.limitBytes ?? state.archiveCache?.limitBytes ?? 2 * 1024 ** 3,
    });
    state.archiveCache = result?.summary || await bridge.archiveCacheSummary?.();
    state.databaseOptionsStatus = "CACHE SETTINGS SAVED";
  } catch (error) {
    state.databaseOptionsStatus = `CACHE ERROR: ${error.message}`;
  }
  render();
}

async function clearArchiveCache() {
  try {
    await bridge?.clearArchiveCache?.();
    state.archiveCache = await bridge?.archiveCacheSummary?.() || state.archiveCache;
    state.databaseOptionsStatus = "CACHE CLEARED";
  } catch (error) {
    state.databaseOptionsStatus = `CACHE ERROR: ${error.message}`;
  }
  render();
}

async function reloadDatabase() {
  try {
    state.databaseLocation = await bridge?.reloadDatabaseLibrary?.() || state.databaseLocation;
    state.databaseOptionsStatus = "LIBRARY RELOADED";
    await loadCatalog();
    if (state.sidebarMode === "paths") {
      state.databaseFilesReady = false;
      await loadDatabaseFiles();
    }
  } catch (error) {
    state.databaseOptionsStatus = `DATABASE ERROR: ${error.message}`;
    render();
  }
}

function addDatabaseOptions(parent) {
  const database = optionGroup(parent, "CATALOG DATABASE");
  label(database, state.databaseLocation?.path || "DATABASE LOCATION",
    { height: buttonStandardHeight() }, {
      border: BUTTON_BORDER_DOTS,
      textShade: 0,
      inset: controlPaddingDots(),
      controlTitle: "DATABASE LOCATION",
      onClick: () => {
        const path = state.databaseLocation?.path;
        if (path) void bridge?.showInFinder?.(path);
      },
    });
  if (state.databaseLocation?.catalog) {
    label(database,
      `SCHEMA ${state.databaseLocation.catalog.schemaVersion} / ${state.databaseLocation.catalog.trackCount} TRACKS`,
      { height: buttonStandardHeight() }, { textShade: 0, inset: controlPaddingDots() });
  }
  const databaseActions = controlRow(database, { height: buttonStandardHeight() });
  pixelButton(databaseActions, "RELOAD LIBRARY", () => { void reloadDatabase(); }, { flexGrow: 1, width: 0 });
  pixelButton(databaseActions, "SHOW IN FINDER", () => {
    const path = state.databaseLocation?.path;
    if (path) void bridge?.showInFinder?.(path);
  }, { flexGrow: 1, width: 0 });

  const cache = optionGroup(parent, "ARCHIVE CACHE");
  const summary = state.archiveCache || {};
  label(cache, state.archiveCacheLocation || "ARCHIVE CACHE LOCATION",
    { height: buttonStandardHeight() }, {
      border: BUTTON_BORDER_DOTS,
      textShade: 0,
      inset: controlPaddingDots(),
      controlTitle: "ARCHIVE CACHE LOCATION",
      onClick: () => { void bridge?.showArchiveCacheInFinder?.(); },
    });
  optionToggle(cache, "CACHE ENABLED", summary.enabled !== false,
    () => { void configureArchiveCache({ enabled: summary.enabled === false }); });
  optionChoice(cache, "LIMIT", [2, 4, 8, 16].map((gigabytes) => {
    const limitBytes = gigabytes * 1024 ** 3;
    return {
      title: `${gigabytes}G`,
      selected: Number(summary.limitBytes) === limitBytes,
      onClick: () => { void configureArchiveCache({ limitBytes }); },
    };
  }));
  label(cache,
    `FILES ${Number(summary.fileCount) || 0} / ${cacheByteLabel(summary.byteCount)} OF ${cacheByteLabel(summary.limitBytes)}`,
    { height: buttonStandardHeight() }, { textShade: 0, inset: controlPaddingDots() });
  const cacheActions = controlRow(cache, { height: buttonStandardHeight() });
  pixelButton(cacheActions, "CLEAR CACHE", () => { void clearArchiveCache(); }, { flexGrow: 1, width: 0 });
  pixelButton(cacheActions, "SHOW CACHE FOLDER", () => { void bridge?.showArchiveCacheInFinder?.(); }, {
    flexGrow: 1, width: 0,
  });
  label(parent, state.databaseOptionsStatus, { height: buttonStandardHeight() }, {
    textShade: 0, inset: controlPaddingDots(),
  });
}

function selectOptionsPage(page) {
  state.optionsPage = page;
  render();
  if (page === "DATABASE") void refreshDatabaseOptions();
}

function addOptionsContent(parent) {
  const navigationWidth = optionsTocWidth();
  const toc = makeWidget(parent, {
    direction: FlexDirection.Column,
    width: navigationWidth,
    gap: uiGap(),
    padding: uiOptionsInsetDots() / STYLE_SCALE,
  }, {
    paint(box) { strokeRect(box.x, box.y, box.width, box.height, 1); },
  });
  panelTitle(toc, "OPTIONS");
  const pageButtonWidth = navigationWidth - 2 * uiOptionsInsetDots() / STYLE_SCALE;
  ["AUDIO", "DATABASE", "DISPLAY", "INTERFACE", "LIBRARY", "METHODS", "PLAYBACK", "THEME", "TRANSPORT"]
    .forEach((page) => {
      pixelButton(toc, page, () => selectOptionsPage(page), {
        width: pageButtonWidth, selected: state.optionsPage === page,
      });
  });
  makeWidget(toc, { flexGrow: 1 });
  statusBar(toc, "SETTINGS");

  const panel = makeWidget(parent, {
    direction: FlexDirection.Column,
    flexGrow: 1,
    gap: uiGap(),
    padding: uiOptionsInsetDots() / STYLE_SCALE,
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
  if (state.optionsPage === "DATABASE") addDatabaseOptions(content);
  else if (state.optionsPage === "THEME") addThemeOptions(content);
  else if (state.optionsPage === "TRANSPORT") addTransportOptions(content);
  else if (state.optionsPage === "PLAYBACK") addPlaybackOptions(content, pref);
  else if (state.optionsPage === "METHODS") addMethodOptions(content, pref);
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
  state.libraryViewportWidget = null;
  const toolbarHeight = buttonStandardHeight();
  const root = makeWidget(null, {
    direction: FlexDirection.Column,
    width: WIDTH / STYLE_SCALE,
    height: HEIGHT / STYLE_SCALE,
    positionType: PositionType.Relative,
    padding: APP_BORDER_GAP_DOTS,
    gap: uiGap(),
    alignItems: Align.Stretch,
  }, {
    paint() {
      fillRect(0, 0, WIDTH, HEIGHT, 3);
    },
  });

  const buttonWidth = (text) => framedTextWidth(text);
  if (state.tab === "SETTINGS") {
    const navigation = controlRow(root, {
      height: toolbarHeight,
      justifyContent: Justify.FlexEnd,
    });
    pixelButton(navigation, "BACK", () => {
      closeOptionsScreen();
    }, { width: buttonWidth("BACK") });
  } else {
    const toolbarWidth = (WIDTH / STYLE_SCALE - 2 * APP_BORDER_GAP_DOTS) / 2;
    const toolbarStage = makeWidget(root, {
      direction: FlexDirection.Row,
      alignItems: Align.Stretch,
    });
    makeWidget(toolbarStage, { flexGrow: 1, minWidth: 0 });
    const toolbarGroup = makeWidget(toolbarStage, {
      direction: FlexDirection.Column,
      width: toolbarWidth,
      gap: uiGap(),
    });
    makeWidget(toolbarStage, { flexGrow: 1, minWidth: 0 });

    const fillButton = (parent, text, onClick, style = {}) => pixelButton(parent, text, onClick, {
      width: 0,
      minWidth: 0,
      flexBasis: 0,
      flexGrow: 1,
      flexShrink: 1,
      ...style,
    });
    const transport = controlRow(toolbarGroup, { height: toolbarHeight, gap: uiGap() });
    const transportLabels = state.transportSymbols
      ? { previous: "<<", play: state.playing ? "||" : ">", next: ">>", stop: "[]" }
      : { previous: "PREV", play: state.playing ? "PAUSE" : "PLAY", next: "NEXT", stop: "STOP" };
    fillButton(transport, transportLabels.previous, () => selectPrevious(), {
      controlTitle: "PREVIOUS",
    });
    fillButton(transport, transportLabels.play, () => togglePlaying(), {
      controlTitle: state.playing ? "PAUSE" : "PLAY",
    });
    fillButton(transport, transportLabels.next, () => selectNext(), { controlTitle: "NEXT" });
    fillButton(transport, transportLabels.stop, () => stopPlayback(), { controlTitle: "STOP" });

    const playbackModes = controlRow(toolbarGroup, { height: toolbarHeight, gap: uiGap() });
    fillButton(playbackModes, "LP", () => toggleLongPlay(), {
      selected: state.preferences.longPlayEnabled === true,
      controlTitle: "LONG PLAY",
    });
    fillButton(playbackModes, "R1", () => toggleRepeatOne(), {
      selected: state.preferences.repeatMode === "one",
      controlTitle: "REPEAT ONE",
    });
    fillButton(playbackModes, "P-RND", () => toggleRandomMode("playlist"), {
      selected: state.preferences.randomMode === "playlist",
      controlTitle: "PLAYLIST RANDOM",
    });
    fillButton(playbackModes, "L-RND", () => toggleRandomMode("library"), {
      selected: state.preferences.randomMode === "library",
      controlTitle: "LIBRARY RANDOM",
    });
  }

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
  if (state.libraryViewportWidget) {
    state.libraryViewportHeight = state.libraryViewportWidget.yoga.getComputedLayout().height;
    const maxLibraryScroll = Math.max(0, state.libraryContentHeight - state.libraryViewportHeight);
    state.libraryScrollOffset = Math.max(0, Math.min(maxLibraryScroll, state.libraryScrollOffset));
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
  const translateX = widgetTranslationX(widget, parentX + layout.left, currentRenderTime);
  const translateY = widget.meta.translateY ?? 0;
  widget.meta.frameTranslateX = translateX;
  widget.meta.frameTranslateY = translateY;
  const box = {
    x: floor(parentX + layout.left + translateX),
    y: floor(parentY + layout.top + translateY),
    width: floor(layout.width),
    height: floor(layout.height),
  };
  const entry = { widget, box, clip: inheritedClip };
  output.push(entry);
  if (widget.meta.id) boxesById.set(widget.meta.id, box);
  if (widget.meta.onClick || widget.meta.columnHeader || widget.meta.tabLayoutVisual) hitTargets.push(entry);
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
      x: floor(box.x + layout.left + (child.meta.frameTranslateX ?? child.meta.translateX ?? 0)),
      y: floor(box.y + layout.top + (child.meta.frameTranslateY ?? child.meta.translateY ?? 0)),
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
  const isDragging = pointerInteraction?.kind === "reorder" && pointerInteraction.dragging;
  if (!columnLayoutAnimation && !tabLayoutAnimation && !reorderAnimation && !isDragging) return;
  const timing = columnLayoutAnimation || tabLayoutAnimation || reorderAnimation || pointerInteraction;
  if (!animationFrameIsDue(timing, time)) {
    columnAnimationFrame = requestAnimationFrame(animateColumnLayoutFrame);
    return;
  }
  if (columnLayoutAnimation
    && time - columnLayoutAnimation.startedAt >= columnLayoutAnimation.duration) {
    lastColumnWidths = columnLayoutAnimation.to;
    columnLayoutAnimation = null;
  }
  if (reorderAnimation
    && time - reorderAnimation.startedAt >= reorderAnimation.duration) reorderAnimation = null;
  if (tabLayoutAnimation
    && time - tabLayoutAnimation.startedAt >= tabLayoutAnimation.duration) tabLayoutAnimation = null;
  render(false, true, time);
  if ((columnLayoutAnimation || tabLayoutAnimation || reorderAnimation) && !columnAnimationFrame) {
    columnAnimationFrame = requestAnimationFrame(animateColumnLayoutFrame);
  }
}

function animateSpacingFrame(time) {
  spacingAnimationFrame = 0;
  const animation = spacingAnimation;
  if (!animation) return;
  const complete = time - animation.startedAt >= animation.duration;
  if (!complete && !animationFrameIsDue(animation, time)) {
    spacingAnimationFrame = requestAnimationFrame(animateSpacingFrame);
    return;
  }
  if (complete) spacingAnimation = null;
  render(false, true, time);
  if (!complete) spacingAnimationFrame = requestAnimationFrame(animateSpacingFrame);
}

function applyLibraryScrollFrame(time) {
  libraryScrollFrame = 0;
  if (!animationFrameIsDue(libraryScrollFrameTiming, time)) {
    libraryScrollFrame = requestAnimationFrame(applyLibraryScrollFrame);
    return;
  }
  const delta = pendingLibraryScrollDelta;
  pendingLibraryScrollDelta = 0;
  const maxScroll = Math.max(0, state.libraryContentHeight - state.libraryViewportHeight);
  state.libraryScrollOffset = Math.max(0, Math.min(maxScroll, state.libraryScrollOffset + delta));
  render(false, true, time);
  if (pendingLibraryScrollDelta !== 0 && !libraryScrollFrame) {
    libraryScrollFrame = requestAnimationFrame(applyLibraryScrollFrame);
  }
}

function render(animateSelection = false, preserveAnimations = false, frameTime = performance.now()) {
  currentRenderTime = frameTime;
  state.equalizerBarBoxes = [];
  state.equalizerLabelBoxes = [];
  state.equalizerValueBoxes = [];
  if (state.tab !== "SETTINGS" || state.optionsPage !== "AUDIO") {
    equalizerAnimations.clear();
    if (equalizerAnimationFrame) cancelAnimationFrame(equalizerAnimationFrame);
    equalizerAnimationFrame = 0;
  }
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
  const libraryOffsetBeforeLayout = state.libraryScrollOffset;
  widgetTree = buildTree();
  if (state.libraryViewportWidget && state.libraryScrollOffset !== libraryOffsetBeforeLayout) {
    widgetTree.yoga.freeRecursive();
    widgetTree = buildTree();
  }
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
  if ((columnLayoutAnimation || tabLayoutAnimation || reorderAnimation) && !columnAnimationFrame) {
    columnAnimationFrame = requestAnimationFrame(animateColumnLayoutFrame);
  }
  const selected = visibleTracks()[state.selectedTrack];
  status.textContent = `${state.tab}. ${state.status}. ${state.transport}. `
    + (selected ? `Selected track ${state.selectedTrack + 1}: ${selected.title || selected.filename}.` : "No track selected.");
}

function animateScreenTransitionFrame(time) {
  screenTransitionFrame = 0;
  const transition = screenTransition;
  if (!transition) return;
  const complete = time - transition.startedAt >= transition.duration;
  if (!complete && !animationFrameIsDue(transition, time)) {
    screenTransitionFrame = requestAnimationFrame(animateScreenTransitionFrame);
    return;
  }
  composeScreenTransition(transition, time);
  presentPixels();
  pixels.set(transition.toPixels);
  if (complete) {
    screenTransition = null;
  } else {
    screenTransitionFrame = requestAnimationFrame(animateScreenTransitionFrame);
  }
}

function visiblePixelsAt(time) {
  if (!screenTransition) return pixels.slice();
  const endpointPixels = pixels.slice();
  composeScreenTransition(screenTransition, time);
  const visible = pixels.slice();
  pixels.set(endpointPixels);
  return visible;
}

function cancelScreenLocalAnimations() {
  [selectionAnimationFrame, sidebarAnimationFrame, columnAnimationFrame,
    equalizerAnimationFrame, libraryScrollFrame, spacingAnimationFrame]
    .forEach((frame) => { if (frame) cancelAnimationFrame(frame); });
  selectionAnimationFrame = 0;
  sidebarAnimationFrame = 0;
  columnAnimationFrame = 0;
  equalizerAnimationFrame = 0;
  libraryScrollFrame = 0;
  spacingAnimationFrame = 0;
  selectionAnimation = null;
  state.sidebarTransition = null;
  columnLayoutAnimation = null;
  tabLayoutAnimation = null;
  reorderAnimation = null;
  reorderPreview = null;
  equalizerAnimations.clear();
  spacingAnimation = null;
  pendingLibraryScrollDelta = 0;
  pointerInteraction = null;
}

function navigateAppTab(tab, optionsPage = null) {
  const previousTab = state.tab;
  if (previousTab === tab) {
    if (optionsPage && state.optionsPage !== optionsPage) state.optionsPage = optionsPage;
    if (optionsPage) render();
    return;
  }
  const crossesOptions = (previousTab === "SETTINGS") !== (tab === "SETTINGS");
  if (previousTab !== "SETTINGS" && tab === "SETTINGS") optionsReturnTab = previousTab;
  const visiblePixels = visiblePixelsAt(performance.now());
  if (screenTransitionFrame) cancelAnimationFrame(screenTransitionFrame);
  screenTransitionFrame = 0;
  screenTransition = null;
  cancelScreenLocalAnimations();
  state.tab = tab;
  if (optionsPage) state.optionsPage = optionsPage;
  if (tab === "SETTINGS") setSearchFocused(false);

  const duration = animationMilliseconds("autoResizeAnimationMilliseconds");
  const shouldAnimate = crossesOptions && animationEnabled("autoResizeAnimationEnabled") && duration > 0;
  if (!shouldAnimate) {
    render();
    return;
  }

  suppressFramePresentation = true;
  render();
  suppressFramePresentation = false;
  const destinationPixels = pixels.slice();
  screenTransition = {
    fromPixels: visiblePixels,
    toPixels: destinationPixels,
    targetTab: tab,
    direction: tab === "SETTINGS" ? "down" : "up",
    startedAt: performance.now(),
    duration,
    lastFrameAt: Number.NaN,
  };
  pixels.set(visiblePixels);
  composeScreenTransition(screenTransition, screenTransition.startedAt);
  presentPixels();
  pixels.set(destinationPixels);
  screenTransitionFrame = requestAnimationFrame(animateScreenTransitionFrame);
}

function openOptionsScreen(page = null) {
  navigateAppTab("SETTINGS", page);
  if (page === "DATABASE") void refreshDatabaseOptions();
}

function toggleOptionsScreen() {
  if (state.tab === "SETTINGS") closeOptionsScreen();
  else openOptionsScreen();
}

function closeOptionsScreen() {
  if (state.tab !== "SETTINGS") return;
  navigateAppTab(optionsReturnTab || "LIBRARY");
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
  packedRGB = packedPalette(RGB);
  saveDisplayOptions();
  render();
}

function setTheme(theme) {
  state.theme = theme === "NIGHTBOY" ? "NIGHTBOY" : "GAMEBOY";
  if (document.documentElement) document.documentElement.dataset.theme = state.theme;
  RGB = paletteRGB(displayPalette());
  packedRGB = packedPalette(RGB);
  saveDisplayOptions();
  render();
}

function setTransportSymbols(enabled) {
  state.transportSymbols = enabled === true;
  saveDisplayOptions();
  render();
}

function setDisplaySpacing(key, value) {
  const defaults = {
    controlPaddingDots: DEFAULT_CONTROL_PADDING_DOTS,
    uiGapDots: DEFAULT_UI_GAP_DOTS,
    playlistGapDots: DEFAULT_PLAYLIST_GAP_DOTS,
  };
  if (!(key in defaults)) return;
  const now = performance.now();
  const from = Object.fromEntries(Object.keys(defaults)
    .map((spacingKey) => [spacingKey, spacingValue(spacingKey, now)]));
  state[key] = storedSpacing(value, defaults[key]);
  saveDisplayOptions();
  if (spacingAnimationFrame) cancelAnimationFrame(spacingAnimationFrame);
  spacingAnimationFrame = 0;
  const duration = animationMilliseconds("autoResizeAnimationMilliseconds");
  const to = Object.fromEntries(Object.keys(defaults).map((spacingKey) =>
    [spacingKey, state[spacingKey]]));
  const changed = Object.keys(defaults).some((spacingKey) => from[spacingKey] !== to[spacingKey]);
  spacingAnimation = changed && animationEnabled("autoResizeAnimationEnabled") && duration > 0
    ? { from, to, startedAt: now, duration, lastFrameAt: Number.NaN } : null;
  render();
  if (spacingAnimation) spacingAnimationFrame = requestAnimationFrame(animateSpacingFrame);
}

function adjustDisplaySpacing(key, delta) {
  const current = Number(state[key]);
  if (!Number.isFinite(current)) return;
  setDisplaySpacing(key, current + delta);
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
    state.favoriteIDs = new Set(favorites.map(favoriteID));
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
      state.favoriteIDs = new Set(favorites.map(favoriteID));
      state.selectedTrack = Math.min(state.selectedTrack, Math.max(0, favorites.length - 1));
      render();
    }
  } catch (error) {
    state.status = `FAVORITE ERROR: ${error.message}`;
    render();
  }
}

function historyTimestamp(milliseconds) {
  const date = new Date(Number(milliseconds));
  if (!Number.isFinite(date.getTime())) return "";
  const pad = (value, width = 2) => String(value).padStart(width, "0");
  return `${pad(date.getFullYear(), 4)}.${pad(date.getMonth() + 1)}.${pad(date.getDate())}`
    + `-${pad(date.getHours())}.${pad(date.getMinutes())}.${pad(date.getSeconds())}.${pad(date.getMilliseconds(), 3)}`;
}

async function showPlaybackHistory() {
  if (!bridge?.playbackHistoryList) return;
  const leavingOptions = state.tab === "SETTINGS";
  try {
    const records = await bridge.playbackHistoryList();
    state.historyTracks = (Array.isArray(records) ? records : []).map((record) => {
      const snapshot = record?.snapshot || {};
      const identity = snapshot.identity || {};
      const sourcePath = String(identity.sourcePath || "");
      if (!sourcePath) return null;
      const trackIndex = Math.max(0, Number(identity.trackIndex) || 0);
      const trackCount = Math.max(1, Number(identity.trackCount) || 1);
      const timestampMilliseconds = Number(record.timestampMilliseconds) || 0;
      const filename = String(snapshot.filename || sourcePath.split(/[\\/]/).at(-1) || "TRACK");
      const archiveEntry = identity.archiveEntry || null;
      return {
        playlistId: String(record.id || `${sourcePath}:${trackIndex}:${timestampMilliseconds}`),
        favoriteId: `${sourcePath}:${trackIndex}`,
        path: sourcePath,
        archivePath: archiveEntry ? sourcePath : null,
        archiveEntry,
        trackIndex,
        trackCount,
        filename,
        title: String(snapshot.title || ""),
        game: String(snapshot.game || ""),
        artist: String(snapshot.author || ""),
        system: String(snapshot.system || ""),
        playLengthMs: Math.max(0, Number(snapshot.playLengthMilliseconds) || 0),
        lengthLabel: Math.max(0, Number(snapshot.playLengthMilliseconds) || 0) > 0
          ? formatTime(snapshot.playLengthMilliseconds) : "",
        timestampMilliseconds,
        timestamp: historyTimestamp(timestampMilliseconds),
      };
    }).filter(Boolean);
    if (!leavingOptions) state.tab = "HISTORY";
    state.sortColumn = "timestamp";
    state.sortDirection = "DESCENDING";
    state.selectedTrack = 0;
    state.queueScroll = 0;
    state.tableHorizontalScroll = 0;
    state.status = `${state.historyTracks.length} HISTORY ITEMS`;
    if (leavingOptions) navigateAppTab("HISTORY");
    else render();
  } catch (error) {
    state.status = `HISTORY ERROR: ${error.message}`;
    render();
  }
}

function selectSidebarView(view) {
  const leavingOptions = state.tab === "SETTINGS";
  if (view === "QUEUE") {
    const currentQueue = state.currentTrackId && state.playbackQueue.length
      ? state.playbackQueue : state.activeQueue;
    const queue = currentQueue.length
      ? [...currentQueue] : [...(activePlaylistTab()?.playlist || tracks)];
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
  state.selectedTrack = 0;
  state.queueScroll = 0;
  if (leavingOptions) navigateAppTab(view);
  else {
    state.tab = view;
    render();
  }
  if (view === "QUEUE") persistPlaylistTabs();
  if (view === "FAVORITES") loadFavorites();
}

async function loadDatabaseFiles() {
  if (!bridge?.databaseFileTree) return false;
  state.databaseFilesLoading = true;
  render();
  try {
    const tree = await bridge.databaseFileTree();
    if (tree?.stale) return false;
    state.databaseFiles = Array.isArray(tree) ? tree : [];
    state.databaseFilesReady = true;
    state.databaseFiles.forEach((node) => {
      if (node.kind === "folder" && node.path) state.expandedPathNodes.add(node.path);
    });
    saveDisplayOptions();
    state.status = state.databaseFiles.length ? "PATH INDEX READY" : "NO CATALOG PATHS";
    return true;
  } catch (error) {
    state.status = `PATH ERROR: ${error.message}`;
    return false;
  } finally {
    state.databaseFilesLoading = false;
    render();
  }
}

async function setSidebarMode(mode) {
  if (mode !== "paths" && mode !== "consoles") return false;
  state.sidebarMode = mode;
  state.libraryScrollOffset = 0;
  if (mode === "paths" && !state.databaseFilesReady) await loadDatabaseFiles();
  if (state.preferences.sidebarMode !== mode) await setPreference("sidebarMode", mode);
  render();
  return true;
}

function togglePathNode(node) {
  if (!node?.path || !node.children?.length) return;
  const expanded = state.expandedPathNodes.has(node.path);
  const currentProgress = state.sidebarTransition?.path === node.path
    ? state.sidebarTransition.progress : Number(expanded);
  const targetProgress = expanded ? 0 : 1;
  if (expanded) state.expandedPathNodes.delete(node.path);
  else state.expandedPathNodes.add(node.path);
  saveDisplayOptions();
  if (sidebarAnimationFrame) cancelAnimationFrame(sidebarAnimationFrame);
  sidebarAnimationFrame = 0;
  const duration = animationMilliseconds("autoResizeAnimationMilliseconds")
    * Math.abs(targetProgress - currentProgress);
  if (!animationEnabled("autoResizeAnimationEnabled") || duration <= 0) {
    state.sidebarTransition = null;
    render();
    return;
  }
  state.sidebarTransition = {
    path: node.path,
    fromProgress: currentProgress,
    toProgress: targetProgress,
    progress: currentProgress,
    startedAt: performance.now(),
    duration,
  };
  render();
  sidebarAnimationFrame = requestAnimationFrame(animateSidebarFrame);
}

async function loadPathNode(node) {
  if (!node || !bridge) return false;
  const key = `catalog-path:${node.path}`;
  const token = ++state.catalogToken;
  state.selectedPathKey = node.path;
  state.status = `LOADING ${node.name || "PATH"}`;
  render();
  try {
    const rows = node.catalogFile
      ? await bridge.databaseFileTracks([node.catalogFile])
      : node.catalogFolder
        ? await bridge.databaseFolderTracks([node.catalogFolder])
        : [];
    if (token !== state.catalogToken || rows?.stale) return false;
    tracks = Array.isArray(rows) ? rows : [];
    let tab = state.playlistTabs.find((entry) => entry.sourceKey === key);
    if (!tab && state.playlistTabs.length < 64) {
      const priorWidths = state.tab === "FAVORITES" || state.tab === "HISTORY" || state.tab === "SETTINGS"
        ? null : captureTabWidths();
      tab = {
        id: playlistTabID(),
        title: node.name || "PATH",
        gameKey: null,
        sourceKey: key,
        playlist: [...tracks],
        selectedTrack: 0,
        scroll: 0,
      };
      state.playlistTabs.push(tab);
      if (priorWidths) animateTabLayout(priorWidths, [...state.playlistTabs]);
    }
    if (tab) {
      tab.title = node.name || tab.title;
      tab.sourceKey = key;
      tab.playlist = [...tracks];
      tab.selectedTrack = 0;
      tab.scroll = 0;
      state.activePlaylistTabId = tab.id;
      state.activeGameKey = null;
    }
    state.selectedGameKey = null;
    state.selectedTrack = 0;
    state.queueScroll = 0;
    state.tableHorizontalScroll = 0;
    if (!state.currentTrackId) state.activeQueue = [...tracks];
    state.status = tracks.length ? `${node.name} / ${tracks.length} TRACKS` : "NO TRACKS AT PATH";
    state.tab = "LIBRARY";
    persistPlaylistTabs();
    render();
    return true;
  } catch (error) {
    if (token !== state.catalogToken) return false;
    state.status = `PATH ERROR: ${error.message}`;
    render();
    return false;
  }
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
  if (state.currentTrackId && state.playbackQueue.length) return state.playbackQueue;
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
  const queue = [...(state.playbackQueue.length ? state.playbackQueue : state.activeQueue)];
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
    Array.from({ length: 10 }, (_, index) => equalizerGain(index, pref)),
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
  state.playbackQueue = [...queue];
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
    if (snapshot?.transport_state === "playing" && !snapshot.error) {
      try {
        await bridge.playbackHistoryRecord?.(track, Date.now());
      } catch (error) {
        console.error("[ViewBoy] playback history could not be recorded", error);
      }
    }
  } catch (error) {
    if (token !== state.playbackToken) return;
    state.currentTrackId = null;
    state.playbackGeneration = 0;
    state.playbackQueue = [];
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
    state.playbackQueue = [];
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
  const queue = state.currentTrackId && state.playbackQueue.length
    ? state.playbackQueue : (state.activeQueue.length ? state.activeQueue : shownTracks);
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

function currentReorderOrder(kind) {
  if (reorderPreview?.kind === kind) return [...reorderPreview.keys];
  if (kind === "column") {
    return tableColumns(activeTracks()).all.map((column) => column.key).filter((key) => key !== "index");
  }
  return state.playlistTabs.map((tab) => tab.id);
}

function captureReorderPositions(kind) {
  const positions = {};
  hitTargets.forEach(({ widget, box }) => {
    if (widget.meta.reorderKind !== kind) return;
    const key = widget.meta.reorderKey;
    if (key && !Object.hasOwn(positions, key)) positions[key] = box.x;
  });
  return positions;
}

function orderWithDraggedItem(keys, sourceKey, targetKey, targetBox, draggedCenter) {
  if (!sourceKey || !targetKey || sourceKey === targetKey) return keys;
  const next = [...keys];
  const sourceIndex = next.indexOf(sourceKey);
  const targetIndex = next.indexOf(targetKey);
  if (sourceIndex < 0 || targetIndex < 0) return keys;
  next.splice(sourceIndex, 1);
  let insertionIndex = targetIndex
    + (draggedCenter >= targetBox.x + targetBox.width / 2 ? 1 : 0);
  if (sourceIndex < insertionIndex) insertionIndex -= 1;
  next.splice(Math.max(0, Math.min(next.length, insertionIndex)), 0, sourceKey);
  return next;
}

function sameOrder(first, second) {
  return first.length === second.length && first.every((key, index) => key === second[index]);
}

function setReorderAnimation(kind, fromX, time) {
  const duration = animationMilliseconds("autoResizeAnimationMilliseconds");
  reorderAnimation = animationEnabled("autoResizeAnimationEnabled") && duration > 0
    ? { kind, fromX, startedAt: time, duration }
    : null;
}

function applyReorderOrder(kind, keys) {
  if (kind === "column") {
    state.columnOrder = [...keys];
    saveDisplayOptions();
    return;
  }
  const tabsByID = new Map(state.playlistTabs.map((tab) => [tab.id, tab]));
  state.playlistTabs = keys.map((id) => tabsByID.get(id)).filter(Boolean);
  persistPlaylistTabs();
}

function finishReorderInteraction(interaction, commit, time = performance.now()) {
  if (interaction.dragging) {
    interaction.pointX = interaction.lastPointX;
    render(false, true, time);
  }
  const fromX = captureReorderPositions(interaction.itemKind);
  const previewKeys = reorderPreview?.kind === interaction.itemKind
    ? reorderPreview.keys : interaction.originalOrder;
  const nextKeys = commit ? previewKeys : interaction.originalOrder;
  const changed = !sameOrder(nextKeys, interaction.originalOrder);
  if (commit && changed) applyReorderOrder(interaction.itemKind, nextKeys);
  reorderPreview = null;
  pointerInteraction = null;
  setReorderAnimation(interaction.itemKind, fromX, time);
  render(false, true, time);
  if (interaction.dragging) suppressNextClick = true;
}

function scheduleDragRender() {
  if (columnAnimationFrame) return;
  columnAnimationFrame = requestAnimationFrame(animateColumnLayoutFrame);
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
  } else {
    const columnEntry = findTargetEntry(point,
      (widget) => widget.meta.columnHeader && widget.meta.reorderable);
    const tabEntry = findTargetEntry(point, (widget) => widget.meta.reorderContainer);
    const draggable = columnEntry || (!target?.meta.playlistTabClose ? tabEntry : null);
    if (!draggable) return;
    const itemKind = columnEntry ? "column" : "tab";
    const sourceKey = itemKind === "column"
      ? draggable.widget.meta.columnKey : draggable.widget.meta.reorderKey;
    pointerInteraction = {
      kind: "reorder",
      itemKind,
      pointerId: event.pointerId,
      sourceKey,
      originalOrder: currentReorderOrder(itemKind),
      grabOffset: point.x - draggable.box.x,
      draggedWidth: draggable.box.width,
      startX: point.x,
      startY: point.y,
      lastPointX: point.x,
      pointX: point.x,
      dragging: false,
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
  if (pointerInteraction?.kind === "reorder") {
    const distance = Math.hypot(point.x - pointerInteraction.startX, point.y - pointerInteraction.startY);
    pointerInteraction.lastPointX = point.x;
    pointerInteraction.pointX = point.x;
    if (distance >= 1) {
      pointerInteraction.dragging = true;
      reorderAnimation = null;
      suppressNextClick = true;
      const dropTarget = pointerInteraction.itemKind === "column"
        ? findTargetEntry(point, (widget) => widget.meta.columnHeader && widget.meta.reorderable)
        : findTargetEntry(point, (widget) => widget.meta.reorderContainer);
      if (dropTarget) {
        const targetKey = pointerInteraction.itemKind === "column"
          ? dropTarget.widget.meta.columnKey : dropTarget.widget.meta.reorderKey;
        const nextOrder = orderWithDraggedItem(
          currentReorderOrder(pointerInteraction.itemKind),
          pointerInteraction.sourceKey,
          targetKey,
          dropTarget.box,
          point.x - pointerInteraction.grabOffset + pointerInteraction.draggedWidth / 2,
        );
        if (!sameOrder(nextOrder, currentReorderOrder(pointerInteraction.itemKind))) {
          reorderPreview = { kind: pointerInteraction.itemKind, keys: nextOrder };
        }
      }
    }
    scheduleDragRender();
    return;
  }
  const target = findTarget(point);
  canvas.style.cursor = target ? "pointer" : "default";
});

canvas.addEventListener("pointerup", (event) => {
  if (!pointerInteraction || (pointerInteraction.pointerId !== undefined
    && event.pointerId !== undefined && pointerInteraction.pointerId !== event.pointerId)) return;
  const interaction = pointerInteraction;
  if (interaction.kind === "reorder") {
    if (interaction.dragging) {
      const point = logicalPoint(event);
      interaction.lastPointX = point.x;
      interaction.pointX = point.x;
      finishReorderInteraction(interaction, true);
    } else {
      pointerInteraction = null;
    }
  } else if (interaction.kind === "scrollbar") {
    pointerInteraction = null;
    suppressNextClick = true;
  }
});

canvas.addEventListener("pointercancel", () => {
  if (pointerInteraction?.kind === "reorder" && pointerInteraction.dragging) {
    finishReorderInteraction(pointerInteraction, false);
  } else {
    pointerInteraction = null;
  }
});

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
  if (screenTransition) return;
  const target = findTarget(logicalPoint(event));
  if (state.searchFocused && !target?.meta.searchField) {
    setSearchFocused(false);
    if (!target?.meta.onClick) render();
  }
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
  if (library) {
    const rect = canvas.getBoundingClientRect();
    const cssDelta = event.deltaMode === 1 ? event.deltaY * 16
      : event.deltaMode === 2 ? event.deltaY * rect.height : event.deltaY;
    const dotDelta = cssDelta * HEIGHT / Math.max(1, rect.height);
    pendingLibraryScrollDelta += dotDelta;
    if (!libraryScrollFrame) libraryScrollFrame = requestAnimationFrame(applyLibraryScrollFrame);
    return;
  }
  const key = "queueScroll";
  const length = visibleTracks().length;
  const visibleCount = visibleRowCount();
  const direction = Math.sign(event.deltaY);
  state[key] = Math.max(0, Math.min(Math.max(0, length - visibleCount), state[key] + direction * 3));
  render();
}, { passive: false });

canvas.addEventListener("keydown", (event) => {
  const commandKey = event.metaKey || event.ctrlKey;
  if (state.editingDurationKey) {
    if (event.key === "Escape") finishDurationEdit(false);
    else if (event.key === "Enter" || event.key === "Tab") finishDurationEdit(true);
    else if (event.key === "Backspace") {
      state.durationDraft = Array.from(state.durationDraft).slice(0, -1).join("");
      render();
    } else if (/^[0-9:]$/.test(event.key)
      || (state.durationBounds?.allowOpen && /^[OPEN]$/i.test(event.key))) {
      state.durationDraft += event.key.toUpperCase();
      render();
    } else return;
    event.preventDefault();
    return;
  }
  if (commandKey && !event.altKey && !event.shiftKey && event.key.toLowerCase() === "w") {
    event.preventDefault();
    event.stopPropagation();
    closePlaylistTab();
  } else if (commandKey && !event.altKey && !event.shiftKey && event.key === ",") {
    event.preventDefault();
    toggleOptionsScreen();
  } else if (commandKey && event.shiftKey && event.key.toLowerCase() === "d") {
    event.preventDefault();
    selectSidebarView("FAVORITES");
  } else if (commandKey && event.shiftKey && event.key.toLowerCase() === "h") {
    event.preventDefault();
    void showPlaybackHistory();
  } else if (commandKey && !event.shiftKey && !event.altKey && event.key === "1") {
    event.preventDefault();
    void setSidebarMode("paths").then(() => selectSidebarView("LIBRARY"));
  } else if (commandKey && !event.shiftKey && !event.altKey && event.key === "2") {
    event.preventDefault();
    void setSidebarMode("consoles").then(() => selectSidebarView("LIBRARY"));
  } else if (commandKey && !event.shiftKey && !event.altKey && event.key === "3") {
    event.preventDefault();
    openLocalPath();
  } else if (commandKey && !event.shiftKey && !event.altKey && event.key.toLowerCase() === "d") {
    event.preventDefault();
    const selected = visibleTracks()[state.selectedTrack];
    if (selected) void toggleFavorite(selected);
  } else if (commandKey && event.altKey && /^[1-9]$/.test(event.key)) {
    event.preventDefault();
    const tab = state.playlistTabs[Number(event.key) - 1];
    if (tab) activatePlaylistTab(tab.id);
  } else if (commandKey && !event.shiftKey && !event.altKey && event.key.toLowerCase() === "t") {
    event.preventDefault();
    createPlaylistTab({ duplicateActive: true });
  } else if (commandKey && !event.shiftKey && !event.altKey && event.key.toLowerCase() === "o") {
    event.preventDefault();
    openLocalPath();
  } else if (state.searchFocused && state.tab !== "SETTINGS") {
    if (event.key === "Escape") {
      if (state.searchQuery) state.searchQuery = "";
      else setSearchFocused(false);
    } else if (event.key === "Backspace") {
      state.searchQuery = Array.from(state.searchQuery).slice(0, -1).join("");
    } else if (event.key === "Enter") {
      setSearchFocused(false);
    } else if (event.key.length === 1 && !event.altKey) {
      state.searchQuery += normalizedText(event.key);
    } else {
      return;
    }
    event.preventDefault();
    resetSearchCursorBlink();
    state.libraryScrollOffset = 0;
    render();
  } else if (event.code === "Escape" && state.columnMenu) {
    event.preventDefault();
    state.columnMenu = null;
    render();
  } else if (event.code === "Escape" && state.tab === "SETTINGS") {
    event.preventDefault();
    closeOptionsScreen();
  } else if (event.shiftKey && (event.code === "ArrowLeft" || event.code === "ArrowRight")) {
    event.preventDefault();
    state.tableHorizontalScroll = Math.max(0, Math.min(state.tableHorizontalMax,
      state.tableHorizontalScroll + (event.code === "ArrowRight" ? 1 : -1) * 8 * fontProfile().advance));
    render();
  } else if (event.code === "Space") {
    event.preventDefault();
    togglePlaying();
  } else if (event.code === "F7") {
    event.preventDefault();
    selectPrevious();
  } else if (event.code === "F8") {
    event.preventDefault();
    togglePlaying();
  } else if (event.code === "F9") {
    event.preventDefault();
    selectNext();
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
    imageWords = new Uint32Array(image.data.buffer, image.data.byteOffset, image.data.byteLength / 4);
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
  if (libraryScrollFrame) cancelAnimationFrame(libraryScrollFrame);
  if (equalizerAnimationFrame) cancelAnimationFrame(equalizerAnimationFrame);
  if (screenTransitionFrame) cancelAnimationFrame(screenTransitionFrame);
  if (spacingAnimationFrame) cancelAnimationFrame(spacingAnimationFrame);
  if (searchCursorTimer) clearTimeout(searchCursorTimer);
  searchCursorTimer = 0;
  screenTransitionFrame = 0;
  spacingAnimationFrame = 0;
  screenTransition = null;
  spacingAnimation = null;
  screenResizeObserver?.disconnect();
  if (widgetTree) widgetTree.yoga.freeRecursive();
});

requestAnimationFrame(fitCanvas);
fitCanvas();

const pendingCommands = window.__viewBoyCommandQueue || [];
window.ViewBoy = Object.freeze({
  dispatch(command) {
    if (String(command).startsWith("selectPlaylistTab:")) {
      const tab = state.playlistTabs[Number(String(command).split(":").at(-1)) - 1];
      if (tab) activatePlaylistTab(tab.id);
      return;
    }
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
      case "settings": toggleOptionsScreen(); break;
      case "sidebarPaths": void setSidebarMode("paths").then(() => selectSidebarView("LIBRARY")); break;
      case "sidebarConsoles": void setSidebarMode("consoles").then(() => selectSidebarView("LIBRARY")); break;
      case "sidebarDiskPath": openLocalPath(); break;
      case "favoritesPlaylist": selectSidebarView("FAVORITES"); break;
      case "playbackHistory": void showPlaybackHistory(); break;
      case "library": selectSidebarView("LIBRARY"); break;
      case "queue": selectSidebarView("QUEUE"); break;
      case "optionsPage:DISPLAY": openOptionsScreen("DISPLAY"); break;
      case "optionsPage:THEME": openOptionsScreen("THEME"); break;
      case "optionsPage:TRANSPORT": openOptionsScreen("TRANSPORT"); break;
      case "optionsPage:PLAYBACK": openOptionsScreen("PLAYBACK"); break;
      case "optionsPage:METHODS": openOptionsScreen("METHODS"); break;
      case "optionsPage:AUDIO": openOptionsScreen("AUDIO"); break;
      case "optionsPage:INTERFACE": openOptionsScreen("INTERFACE"); break;
      case "optionsPage:LIBRARY": openOptionsScreen("LIBRARY"); break;
      case "optionsPage:DATABASE": openOptionsScreen("DATABASE"); break;
      case "closeWindow": closePlaylistTab(); break;
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
    state.sidebarMode = state.preferences.sidebarMode === "paths" ? "paths" : "consoles";
    if (priorRandomMode !== (state.preferences.randomMode || "off")) resetRandomPlaybackState();
    if (state.sidebarMode === "paths" && !state.databaseFilesReady) void loadDatabaseFiles();
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
      state.sidebarMode = state.preferences.sidebarMode === "paths" ? "paths" : "consoles";
      if (state.sidebarMode === "paths") await loadDatabaseFiles();
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
