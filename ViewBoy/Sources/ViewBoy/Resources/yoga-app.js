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

// The framebuffer expands each LCD dot to a configurable device-pixel cell.
// A one-pixel edge remains unlit so the matrix stays visible at every size.
const DEFAULT_LCD_DOT_SIZE = 3;
const LCD_DOT_SIZE_OPTIONS = [2, 3, 4, 5, 6];
const APP_EDGE_PADDING_PX = 8;
let DEVICE_PIXELS_PER_LCD_DOT = DEFAULT_LCD_DOT_SIZE;
const BASELINE_LAYOUT_UNIT_CSS_PIXELS = 2.5;
const RANDOM_HISTORY_LIMIT = 256;
const BUTTON_BORDER_DOTS = 1;
const SIDEBAR_ICON_SIZE_DOTS = 9;
const SIDEBAR_BUTTON_SIZE_DOTS = 13;
const SIDEBAR_ICON_ART = {
  library: [
    "000000000", "011111110", "000000000", "011111110", "000000000",
    "011111110", "000000000", "000000000", "000000000",
  ],
  folder: [
    "001110000", "011111110", "111111111", "100000001", "100000001",
    "100000001", "100000001", "111111111", "000000000",
  ],
  heart: [
    "001001000", "011111100", "111111110", "111111110", "011111100",
    "001111000", "000110000", "000010000", "000000000",
  ],
  clock: [
    "001111100", "011000110", "110000011", "110110011", "110111011",
    "110001011", "011000110", "001111100", "000000000",
  ],
  tree: [
    "011100000", "111110000", "001000000", "001111110", "001000010",
    "001000000", "001111110", "001000010", "001000000",
  ],
  gear: [
    "000100000", "001110000", "011111100", "111001110", "011001100",
    "111001110", "011111100", "001110000", "000100000",
  ],
};
const DEFAULT_CONTROL_PADDING_DOTS = 4;
const DEFAULT_UI_GAP_DOTS = 4;
const DEFAULT_TEXT_LINE_GAP_DOTS = 1;
const SPACING_DOTS_MIN = 1;
const SPACING_DOTS_MAX = 8;
const EQ_BAR_MIN_DOTS = 100;
const EQ_BAR_INSET_DOTS = 2;
const REORDER_ENTRY_THRESHOLD_DOTS = 2;
const EQ_GAIN_MIN_DB = 0;
const EQ_GAIN_MAX_DB = 12;
const EQ_GAIN_STEP_DB = 0.5;
const EQ_GAIN_STEPS = (EQ_GAIN_MAX_DB - EQ_GAIN_MIN_DB) / EQ_GAIN_STEP_DB;
const FAVORITES_TAB_SOURCE = "viewboy:special:favorites";
const HISTORY_TAB_SOURCE = "viewboy:special:history";
const DEFAULT_ANIMATION_FPS = 60;
const ANIMATION_FPS_MIN = 30;
const ANIMATION_FPS_MAX = 240;
const ANIMATION_FPS_TICKS = [30, 60, 90, 120, 150, 180, 210, 240];
// The DMG defines four ordered logical LCD tones, not fixed RGB values or
// numeric luminance intervals. ViewBoy keeps each theme's ink and screen
// colors, then derives the two middle tones at equal CIELAB L* intervals.
// Endpoint order follows the UI palette contract: active ink, two middle
// tones, then the LCD surface. Presets retain their own direction and tint;
// custom palettes follow the two user-entered endpoints.
const PALETTE_ENDPOINTS = {
  GAMEBOY: {
    STANDARD: { ink: "#222222", surface: "#9BBC0F" },
    HIGH_CONTRAST: { ink: "#080808", surface: "#9BBC0F" },
  },
  NIGHTBOY: {
    STANDARD: { ink: "#A9A9A9", surface: "#000000" },
    HIGH_CONTRAST: { ink: "#D3D3D3", surface: "#000000" },
  },
  GRAPEBOY: {
    STANDARD: { ink: "#201824", surface: "#A64AC9" },
    HIGH_CONTRAST: { ink: "#100B13", surface: "#A64AC9" },
  },
  TEALBOY: {
    STANDARD: { ink: "#06262A", surface: "#78D7D4" },
    HIGH_CONTRAST: { ink: "#031619", surface: "#78D7D4" },
  },
  ATOMICPURPLEBOY: {
    STANDARD: { ink: "#E2D2EA", surface: "#704883" },
    HIGH_CONTRAST: { ink: "#F4EAF8", surface: "#704883" },
  },
};
const THEME_ALIASES = {
  PURPLEBOY: "GRAPEBOY",
  IDIGLOWBOY: "TEALBOY",
  DARKPURPLEBOY: "ATOMICPURPLEBOY",
};
function normalizeThemeName(theme) {
  const name = String(theme || "").toUpperCase();
  return THEME_ALIASES[name] || name;
}
const COLOR_THEMES = new Set([...Object.keys(PALETTE_ENDPOINTS), "CUSTOM"]);
function hexToRGB(color) {
  const value = Number.parseInt(color.slice(1), 16);
  return [(value >> 16) & 255, (value >> 8) & 255, value & 255];
}
function srgbToLinear(channel) {
  const value = channel / 255;
  return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
}
function linearToSRGB(channel) {
  const value = Math.max(0, Math.min(1, channel));
  return Math.round(255 * (value <= 0.0031308
    ? value * 12.92
    : 1.055 * value ** (1 / 2.4) - 0.055));
}
function rgbToLab([red, green, blue]) {
  const r = srgbToLinear(red);
  const g = srgbToLinear(green);
  const b = srgbToLinear(blue);
  const x = (r * 0.4124564 + g * 0.3575761 + b * 0.1804375) / 0.95047;
  const y = r * 0.2126729 + g * 0.7151522 + b * 0.072175;
  const z = (r * 0.0193339 + g * 0.119192 + b * 0.9503041) / 1.08883;
  const f = (value) => value > 0.008856451679
    ? Math.cbrt(value)
    : (903.296296296 * value + 16) / 116;
  const fx = f(x);
  const fy = f(y);
  const fz = f(z);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}
function labToRGB([lightness, a, b]) {
  const fy = (lightness + 16) / 116;
  const fx = fy + a / 500;
  const fz = fy - b / 200;
  const inverse = (value) => value ** 3 > 0.008856451679
    ? value ** 3
    : (116 * value - 16) / 903.296296296;
  const x = 0.95047 * inverse(fx);
  const y = inverse(fy);
  const z = 1.08883 * inverse(fz);
  return [
    linearToSRGB(x * 3.2404542 + y * -1.5371385 + z * -0.4985314),
    linearToSRGB(x * -0.969266 + y * 1.8760108 + z * 0.041556),
    linearToSRGB(x * 0.0556434 + y * -0.2040259 + z * 1.0572252),
  ];
}
function rgbToHex([red, green, blue]) {
  return `#${[red, green, blue].map((channel) => channel.toString(16).padStart(2, "0")).join("")}`
    .toUpperCase();
}
function paletteTones(theme, contrast, custom = null) {
  const endpoints = theme === "CUSTOM" && custom
    ? { ink: custom.font, surface: custom.background }
    : PALETTE_ENDPOINTS[theme]?.[contrast] || PALETTE_ENDPOINTS.GAMEBOY.STANDARD;
  const inkLab = rgbToLab(hexToRGB(endpoints.ink));
  const surfaceLab = rgbToLab(hexToRGB(endpoints.surface));
  return Array.from({ length: 4 }, (_, index) => {
    if (index === 0) return endpoints.ink;
    if (index === 3) return endpoints.surface;
    const amount = index / 3;
    const lab = inkLab.map((value, channel) =>
      value + (surfaceLab[channel] - value) * amount);
    return rgbToHex(labToRGB(lab));
  });
}
function colorInputToHex(input) {
  const value = String(input ?? "").trim();
  if (!value) return null;
  const bareHex = value.replace(/^#/, "");
  if (/^[\da-f]{3}$/i.test(bareHex)) {
    return rgbToHex([...bareHex].map((digit) => Number.parseInt(`${digit}${digit}`, 16)));
  }
  if (/^[\da-f]{6}$/i.test(bareHex)) {
    return `#${bareHex.toUpperCase()}`;
  }
  const channels = value.match(/^(\d{1,3})[\s,]+(\d{1,3})[\s,]+(\d{1,3})$/);
  if (channels) {
    const rgb = channels.slice(1).map(Number);
    if (rgb.every((channel) => channel >= 0 && channel <= 255)) return rgbToHex(rgb);
    return null;
  }
  if (!globalThis.CSS?.supports?.("color", value) || !document?.createElement) return null;
  const probe = document.createElement("canvas");
  probe.width = 1;
  probe.height = 1;
  const probeContext = probe.getContext("2d", { willReadFrequently: true });
  if (!probeContext) return null;
  probeContext.clearRect(0, 0, 1, 1);
  probeContext.fillStyle = value;
  probeContext.fillRect(0, 0, 1, 1);
  const [red, green, blue, alpha] = probeContext.getImageData(0, 0, 1, 1).data;
  const opacity = alpha / 255;
  return rgbToHex([red, green, blue].map((channel) => Math.round(channel * opacity)));
}
function paletteRGB(palette) {
  return palette.map(hexToRGB);
}
let RGB = paletteRGB(paletteTones("GAMEBOY", "STANDARD"));
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
  "←": ["00100", "01000", "11111", "01000", "00100", "00000", "00000"],
  "→": ["00100", "00010", "11111", "00010", "00100", "00000", "00000"],
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
  "←": ["010", "100", "111", "100", "010"],
  "→": ["010", "001", "111", "001", "010"],
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
function storedAnimationFPS(value) {
  const fps = Number(value);
  if (value == null || !Number.isFinite(fps)) return DEFAULT_ANIMATION_FPS;
  return Math.max(ANIMATION_FPS_MIN, Math.min(ANIMATION_FPS_MAX, Math.round(fps)));
}
const savedDisplayOptions = storedDisplayOptions();
const legacyTextLineGapDots = Math.max(
  storedSpacing(savedDisplayOptions.sidebarLineGapDots, DEFAULT_TEXT_LINE_GAP_DOTS),
  storedSpacing(savedDisplayOptions.playlistLineGapDots, DEFAULT_TEXT_LINE_GAP_DOTS),
);
const legacyChromeGapDots = Math.max(
  storedSpacing(savedDisplayOptions.uiGapDots ?? savedDisplayOptions.uiGutterDots, DEFAULT_UI_GAP_DOTS),
  storedSpacing(savedDisplayOptions.playlistGapDots, DEFAULT_UI_GAP_DOTS),
);
function storedSpacing(value, fallback) {
  const number = Number(value);
  return Math.max(SPACING_DOTS_MIN, Math.min(SPACING_DOTS_MAX,
    Number.isFinite(number) ? Math.round(number) : fallback));
}
function displayPalette(theme = state.theme, contrast = state.contrast) {
  return paletteTones(theme, contrast, {
    background: state.customBackgroundColor,
    font: state.customFontColor,
  });
}
function updateThemeSurface() {
  const root = document.documentElement;
  if (!root) return;
  root.dataset.theme = state.theme;
  const surface = state.theme === "CUSTOM"
    ? state.customBackgroundColor : PALETTE_ENDPOINTS[state.theme][state.contrast].surface;
  root.style?.setProperty?.("--screen-surface", surface);
}
function saveDisplayOptions() {
  try {
    localStorage.setItem(DISPLAY_OPTIONS_KEY, JSON.stringify({
      font: state.font,
      contrast: state.contrast,
      theme: state.theme,
      customBackgroundColor: state.customBackgroundColor,
      customFontColor: state.customFontColor,
      customColorsInitialized: state.customColorsInitialized,
      lcdDotSize: state.lcdDotSize,
      uiButtonPadDots: state.controlPaddingDots,
      uiChromeGapDots: state.uiChromeGapDots,
      textLineGapDots: state.textLineGapDots,
      animationFPS: state.animationFPS,
      transportSymbols: state.transportSymbols,
      columnOrder: state.columnOrder,
      autoHideEmptyColumns: state.autoHideEmptyColumns,
      expandedPathNodes: [...state.expandedPathNodes],
      pathExpansionInitialized: state.pathExpansionInitialized,
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
let sidebarSelectionBand = null;
let sidebarSelectionRows = [];
let sidebarSelectionAnimation = null;
let sidebarAnimationFrame = 0;
let columnAnimationFrame = 0;
let equalizerAnimationFrame = 0;
let checkboxAnimationFrame = 0;
let libraryScrollFrame = 0;
let screenTransitionFrame = 0;
let spacingAnimationFrame = 0;
let pendingLibraryScrollDelta = 0;
const libraryScrollFrameTiming = { lastFrameAt: Number.NaN };
let searchCursorTimer = 0;
let searchCursorVisible = false;
let equalizerFrameTiming = { lastFrameAt: Number.NaN };
let equalizerAnimations = new Map();
let checkboxFrameTiming = { lastFrameAt: Number.NaN };
let checkboxAnimations = new Map();
let screenTransition = null;
let spacingAnimation = null;
let suppressFramePresentation = false;
let optionsReturnTab = "LIBRARY";
let columnLayoutAnimation = null;
let lastColumnWidths = null;
let columnAnimationTreeReusedFrames = 0;
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
  selectedTrackIDs: new Set(),
  selectionAnchorID: null,
  enterSelection: "playlist",
  sidebarEnterContext: null,
  playing: false,
  font: savedDisplayOptions.font === "STANDARD" ? "STANDARD" : "MICRO",
  contrast: savedDisplayOptions.contrast === "HIGH_CONTRAST" ? "HIGH_CONTRAST" : "STANDARD",
  theme: COLOR_THEMES.has(normalizeThemeName(savedDisplayOptions.theme))
    ? normalizeThemeName(savedDisplayOptions.theme) : "GAMEBOY",
  customBackgroundColor: colorInputToHex(savedDisplayOptions.customBackgroundColor) || "#9BBC0F",
  customFontColor: colorInputToHex(savedDisplayOptions.customFontColor) || "#333333",
  customColorsInitialized: savedDisplayOptions.customColorsInitialized === true,
  editingColorEndpoint: null,
  colorDraft: "",
  colorInputError: null,
  lcdDotSize: LCD_DOT_SIZE_OPTIONS.includes(Number(savedDisplayOptions.lcdDotSize))
    ? Number(savedDisplayOptions.lcdDotSize) : DEFAULT_LCD_DOT_SIZE,
  controlPaddingDots: storedSpacing(savedDisplayOptions.uiButtonPadDots
    ?? savedDisplayOptions.controlPaddingDots, DEFAULT_CONTROL_PADDING_DOTS),
  uiChromeGapDots: storedSpacing(savedDisplayOptions.uiChromeGapDots, legacyChromeGapDots),
  textLineGapDots: storedSpacing(savedDisplayOptions.textLineGapDots, legacyTextLineGapDots),
  animationFPS: storedAnimationFPS(savedDisplayOptions.animationFPS),
  searchQuery: "",
  searchFocused: false,
  optionsScrollOffset: 0,
  optionsScrollMaximum: 0,
  optionsContentViewportBox: null,
  optionsContentViewportWidget: null,
  optionsContentBodyWidget: null,
  transportSymbols: savedDisplayOptions.transportSymbols === true,
  optionsPage: "DISPLAY",
  transport: "stopped",
  nativePlaybackStatus: null,
  currentTrackId: null,
  activeQueue: [],
  playbackQueue: [],
  playbackPlaylistTabId: null,
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
  consoleSystems: [],
  favoriteTracks: [],
  favoriteIDs: new Set(),
  historyTracks: [],
  databaseFiles: [],
  databaseFileFolders: [],
  databaseFilesReady: false,
  databaseFilesLoading: false,
  expandedPathNodes: new Set(Array.isArray(savedDisplayOptions.expandedPathNodes)
    ? savedDisplayOptions.expandedPathNodes : []),
  pathExpansionInitialized: savedDisplayOptions.pathExpansionInitialized === true,
  selectedPathKey: null,
  sidebarMode: "consoles",
  databaseLocation: null,
  archiveCacheLocation: "",
  archiveCache: null,
  volumeGaugeBox: null,
  volumeValueBox: null,
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
  autoHideEmptyColumns: savedDisplayOptions.autoHideEmptyColumns !== false,
  autoHiddenColumnKeys: [],
  checkboxBoxes: [],
  editingRateBackend: null,
  rateDraft: "",
  animationFPSFocused: false,
  tableHorizontalScroll: 0,
  tableHorizontalMax: 0,
  tableViewportWidth: 0,
  tableViewportBox: null,
  tableContentWidth: 0,
  tableScrollbarBox: null,
  tableScrollbarThumb: null,
  tableViewportWidget: null,
  tableContentWidget: null,
  catalogPaneWidget: null,
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
  catalogLoading: false,
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
DEVICE_PIXELS_PER_LCD_DOT = state.lcdDotSize;
RGB = paletteRGB(displayPalette());
packedRGB = packedPalette(RGB);
updateThemeSurface();

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
  return activePlaylistTab()?.playlist || tracks;
}

function activePlaylistTab() {
  return state.playlistTabs.find((tab) => tab.id === state.activePlaylistTabId) || null;
}

function playlistTabForSource(sourceKey) {
  return state.playlistTabs.find((tab) => tab.sourceKey === sourceKey) || null;
}

function samePlaylist(first, second) {
  return first.length === second.length
    && first.every((track, index) => trackID(track) === trackID(second[index]));
}

function playlistTabID() {
  return globalThis.crypto?.randomUUID?.()
    || `viewboy-${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

function selectionIDsForTab(tab) {
  const validIDs = new Set((tab?.playlist || []).map(trackID));
  const ids = Array.isArray(tab?.selectedTrackIDs)
    ? tab.selectedTrackIDs.filter((id) => validIDs.has(id)) : [];
  if (ids.length) return ids;
  if (tab?.sourceKey === FAVORITES_TAB_SOURCE) return [];
  const fallback = tab?.playlist?.[Math.max(0, Number(tab?.selectedTrack) || 0)];
  return fallback ? [trackID(fallback)] : [];
}

function setPlaylistSelection(ids, anchorID = null, primaryID = null) {
  const shown = visibleTracks();
  const validIDs = new Set(shown.map(trackID));
  const nextIDs = [...new Set(ids)].filter((id) => validIDs.has(id));
  state.selectedTrackIDs = new Set(nextIDs);
  state.selectionAnchorID = anchorID && validIDs.has(anchorID) ? anchorID : nextIDs.at(-1) || null;
  const nextPrimaryID = primaryID && nextIDs.includes(primaryID) ? primaryID : nextIDs.at(-1);
  const nextIndex = nextPrimaryID ? shown.findIndex((track) => trackID(track) === nextPrimaryID) : -1;
  if (nextIndex >= 0) state.selectedTrack = nextIndex;
  const tab = activePlaylistTab();
  if (tab) {
    tab.selectedTrackIDs = [...nextIDs];
    tab.selectionAnchorID = state.selectionAnchorID;
    tab.selectedTrack = state.selectedTrack;
  }
}

function resetPlaylistSelection(playlist = tracks, tab = activePlaylistTab()) {
  const firstID = playlist[0] ? trackID(playlist[0]) : null;
  state.selectedTrack = 0;
  state.selectedTrackIDs = new Set(firstID ? [firstID] : []);
  state.selectionAnchorID = firstID;
  if (tab) {
    tab.selectedTrack = 0;
    tab.selectedTrackIDs = firstID ? [firstID] : [];
    tab.selectionAnchorID = firstID;
  }
}

function syncActivePlaylistTab() {
  const tab = activePlaylistTab();
  if (!tab || state.tab === "SETTINGS") return;
  tab.playlist = [...tracks];
  tab.selectedTrack = state.selectedTrack;
  tab.selectedTrackIDs = [...state.selectedTrackIDs];
  tab.selectionAnchorID = state.selectionAnchorID;
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
      selectedTrackIDs: Array.isArray(tab.selectedTrackIDs) ? tab.selectedTrackIDs : [],
      selectionAnchorID: tab.selectionAnchorID || null,
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
  }).map((tab) => {
    const playlist = Array.isArray(tab.playlist) ? tab.playlist : [];
    const selectedTrack = Math.max(0, Number(tab.selectedTrack) || 0);
    const selectedTrackIDs = Array.isArray(tab.selectedTrackIDs)
      ? tab.selectedTrackIDs.filter((id) => playlist.some((track) => trackID(track) === id)) : [];
    if (!selectedTrackIDs.length && playlist[selectedTrack]
      && tab.sourceKey !== FAVORITES_TAB_SOURCE) {
      selectedTrackIDs.push(trackID(playlist[selectedTrack]));
    }
    return {
      id: tab.id,
      title: typeof tab.title === "string" && tab.title.trim() ? tab.title : "PLAYLIST",
      gameKey: typeof tab.gameKey === "string" ? tab.gameKey : null,
      sourceKey: typeof tab.sourceKey === "string" ? tab.sourceKey : null,
      playlist,
      selectedTrack,
      selectedTrackIDs,
      selectionAnchorID: typeof tab.selectionAnchorID === "string"
        ? tab.selectionAnchorID : selectedTrackIDs.at(-1) || null,
      scroll: Math.max(0, Number(tab.scroll) || 0),
    };
  });
  if (!restored.length) return false;
  state.playlistTabs = restored;
  state.activePlaylistTabId = seen.has(value.activeID) ? value.activeID : restored[0].id;
  const active = activePlaylistTab();
  tracks = [...active.playlist];
  state.activeQueue = [...active.playlist];
  state.activeGameKey = active.gameKey;
  state.selectedGameKey = active.gameKey;
  state.selectedTrack = Math.min(active.selectedTrack, Math.max(0, active.playlist.length - 1));
  state.selectedTrackIDs = new Set(selectionIDsForTab(active));
  state.selectionAnchorID = active.selectionAnchorID || [...state.selectedTrackIDs].at(-1) || null;
  state.queueScroll = active.scroll;
  state.tab = "LIBRARY";
  return true;
}

function activatePlaylistTab(id) {
  const tab = state.playlistTabs.find((entry) => entry.id === id);
  if (!tab) return false;
  state.enterSelection = "playlist";
  state.sidebarEnterContext = null;
  const leavingOptions = state.tab === "SETTINGS";
  if (tab.id !== state.activePlaylistTabId) syncActivePlaylistTab();
  else if (state.tab !== "SETTINGS") return false;
  state.activePlaylistTabId = tab.id;
  tracks = [...tab.playlist];
  state.activeQueue = [...tab.playlist];
  state.activeGameKey = tab.gameKey;
  if (tab.sourceKey === HISTORY_TAB_SOURCE) {
    state.sortColumn = "timestamp";
    state.sortDirection = "DESCENDING";
  } else if (state.sortColumn === "timestamp") {
    state.sortColumn = null;
    state.sortDirection = "ASCENDING";
  }
  state.selectedTrack = Math.min(tab.selectedTrack || 0, Math.max(0, tab.playlist.length - 1));
  state.selectedTrackIDs = new Set(selectionIDsForTab(tab));
  state.selectionAnchorID = tab.selectionAnchorID || [...state.selectedTrackIDs].at(-1) || null;
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
  const duration = animationDurationMilliseconds();
  if (!animationEnabled() || duration <= 0) return;
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

function createPlaylistTab({
  duplicateActive = true,
  title = null,
  playlist = null,
  gameKey = null,
  preserveOptions = false,
} = {}) {
  const keepOptionsOpen = preserveOptions && state.tab === "SETTINGS";
  const priorWidths = state.tab !== "SETTINGS" ? captureTabWidths() : null;
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
    selectedTrackIDs: duplicateActive && source ? selectionIDsForTab(source)
      : (Array.isArray(playlist) && playlist[0] ? [trackID(playlist[0])] : []),
    selectionAnchorID: duplicateActive && source ? source.selectionAnchorID
      : (Array.isArray(playlist) && playlist[0] ? trackID(playlist[0]) : null),
    scroll: duplicateActive && source ? source.scroll : 0,
  };
  state.playlistTabs.push(next);
  if (priorWidths) animateTabLayout(priorWidths, [...state.playlistTabs]);
  state.activePlaylistTabId = next.id;
  tracks = [...next.playlist];
  state.activeQueue = [...next.playlist];
  state.activeGameKey = next.gameKey;
  state.selectedTrack = Math.min(next.selectedTrack, Math.max(0, next.playlist.length - 1));
  state.selectedTrackIDs = new Set(selectionIDsForTab(next));
  state.selectionAnchorID = next.selectionAnchorID || [...state.selectedTrackIDs].at(-1) || null;
  state.queueScroll = next.scroll;
  state.tab = keepOptionsOpen ? "SETTINGS" : "QUEUE";
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
    tab.sourceKey = null;
    tab.playlist = [];
    tab.selectedTrack = 0;
    tab.selectedTrackIDs = [];
    tab.selectionAnchorID = null;
    tab.scroll = 0;
    if (tab.id === state.activePlaylistTabId) {
      tracks = [];
      state.activeQueue = state.currentTrackId ? state.activeQueue : [];
      state.selectedTrack = 0;
      state.selectedTrackIDs = new Set();
      state.selectionAnchorID = null;
      state.queueScroll = 0;
      state.activeGameKey = null;
      state.tab = "LIBRARY";
    }
  } else {
    const priorTabs = [...state.playlistTabs];
    const priorWidths = state.tab !== "SETTINGS" ? captureTabWidths() : null;
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

function animationEnabled() {
  return state.preferences.autoResizeAnimationEnabled !== false
    && state.preferences.selectionAnimationEnabled !== false;
}

function animationDurationMilliseconds() {
  const value = Number(state.preferences.autoResizeAnimationMilliseconds
    ?? state.preferences.selectionAnimationMilliseconds);
  if (!Number.isFinite(value)) return 200;
  return Math.max(0, Math.min(1000, value));
}

function animationFrameIntervalMilliseconds() {
  return 1000 / Math.max(1, Number(state.animationFPS) || DEFAULT_ANIMATION_FPS);
}

export function animationFrameIsDue(animation, time) {
  const interval = animationFrameIntervalMilliseconds();
  if (!Number.isFinite(animation.lastFrameAt)) {
    animation.lastFrameAt = time;
    return true;
  }
  const elapsed = time - animation.lastFrameAt;
  if (elapsed < interval - 0.25) return false;
  const intervals = Math.max(1, Math.floor((elapsed + 0.25) / interval));
  animation.lastFrameAt += intervals * interval;
  return true;
}

export function animationSettingsSnapshot() {
  return {
    enabled: animationEnabled(),
    durationMilliseconds: animationDurationMilliseconds(),
    framesPerSecond: state.animationFPS,
  };
}

export function lcdDotSizeSnapshot() {
  return {
    devicePixelsPerDot: DEVICE_PIXELS_PER_LCD_DOT,
    cssPixelsPerDot: UI_UNIT_CSS_PIXELS,
    framebufferWidth: WIDTH,
    framebufferHeight: HEIGHT,
  };
}

export function lcdPaletteSnapshot(theme = state.theme, contrast = state.contrast) {
  return displayPalette(theme, contrast).map((color) => ({
    color,
    lightness: rgbToLab(hexToRGB(color))[0],
  }));
}

export function equalizerAnimationSnapshot(time = performance.now()) {
  return state.equalizerBarBoxes.flatMap((box, index) => {
    if (!box) return [];
    const gain = equalizerGainAt(index, time);
    const animation = equalizerAnimations.get(index);
    const bounds = equalizerTrackBounds(box);
    return [{
      index,
      gain,
      target: equalizerGain(index),
      from: animation?.from ?? gain,
      fillWidth: equalizerFillWidth(box, gain),
      maximumFillWidth: bounds.right - bounds.left,
      bounds: { ...bounds },
    }];
  });
}

export function checkboxAnimationSnapshot(time = performance.now()) {
  return [...checkboxAnimations].map(([key, animation]) => {
    const angle = checkboxAngleAt(animation, time);
    return {
      key,
      angle,
      horizontalScale: Math.abs(Math.cos(angle)),
      faceChecked: angle >= Math.PI / 2,
      startedAt: animation.startedAt,
      duration: animation.duration,
    };
  });
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
      || (widget.meta.playlistRow ? `TRACK ${widget.meta.trackIndex + 1}` : "")
      || (Number.isInteger(widget.meta.equalizerBar) ? `EQ BAND ${widget.meta.equalizerBar + 1}` : ""),
    displayText: typeof widget.meta.text === "string" ? widget.meta.text : null,
    columnMenuItem: widget.meta.columnMenuItem === true,
    columnHeader: widget.meta.columnHeader === true,
    optionChecklistItem: widget.meta.optionChecklistItem === true,
    optionPage: widget.meta.optionPage === true,
    optionOwner: widget.meta.optionOwner ?? null,
    optionCheckboxChecked: widget.meta.optionCheckboxChecked ?? null,
    optionCheckboxKey: widget.meta.optionCheckboxKey ?? null,
    optionCheckboxBox: widget.meta.optionCheckboxBox ? { ...widget.meta.optionCheckboxBox } : null,
    trackIndex: Number.isInteger(widget.meta.trackIndex) ? widget.meta.trackIndex : null,
    playlistRow: widget.meta.playlistRow === true,
    trackSelected: Number.isInteger(widget.meta.trackIndex)
      ? state.selectedTrackIDs.has(trackID(visibleTracks()[widget.meta.trackIndex])) : false,
    searchField: widget.meta.searchField === true,
    searchText: widget.meta.searchField ? searchFieldText(box) : null,
    textShade: widget.meta.searchField ? widget.meta.textShade ?? 0 : null,
    playlistTabTitle: widget.meta.playlistTabTitle === true,
    playlistTabClose: widget.meta.playlistTabClose === true,
    activePlaylistTab: widget.meta.activePlaylistTab === true,
    editableDurationKey: widget.meta.editableDuration ?? null,
    editableRateBackend: widget.meta.editableRateBackend ?? null,
    playlistTabId: widget.meta.playlistTabId ?? null,
    textInset: widget.meta.inset ?? controlPaddingDots(),
    glyphAdvance: fontProfile().advance,
    reorderKind: widget.meta.reorderKind ?? null,
    reorderKey: widget.meta.reorderKey ?? null,
    sidebarAction: widget.meta.sidebarAction ?? null,
    sidebarIcon: widget.meta.sidebarIcon ?? null,
    animationFPSControl: widget.meta.animationFPSControl === true,
    statusReadout: widget.meta.statusReadout === true,
    textAlign: widget.meta.align ?? "left",
    sidebarDisclosure: widget.meta.sidebarDisclosure === true,
    sidebarBulkAction: widget.meta.sidebarBulkAction === true,
    sidebarContextKind: widget.meta.sidebarContext?.kind || null,
    disclosureProgress: widget.meta.sidebarDisclosure ? widget.meta.disclosureProgress : null,
    sidebarSelection: widget.meta.sidebarSelection === true,
    sidebarSelectionKey: widget.meta.sidebarSelectionKey ?? null,
    sidebarSelectionDepth: widget.meta.sidebarSelectionDepth ?? null,
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

export function appStatusAreaSnapshot() {
  return layoutEntries.flatMap(({ widget, box }) => {
    const field = widget.meta.statusField;
    return field ? [{
      field,
      text: widget.meta.text,
      textAlign: widget.meta.align ?? "left",
      box: { ...box },
    }] : [];
  });
}

export function autoHiddenColumnSnapshot() {
  return [...state.autoHiddenColumnKeys];
}

export function volumeControlSnapshot() {
  return {
    value: Math.max(0, Math.min(1, Number(state.preferences.appVolume ?? 1))),
    gaugeBox: state.volumeGaugeBox ? { ...state.volumeGaugeBox } : null,
    valueBox: state.volumeValueBox ? { ...state.volumeValueBox } : null,
    tickXs: state.volumeGaugeBox ? linearTickPositions(state.volumeGaugeBox, 10) : [],
  };
}

export function choiceControlLayoutSnapshot() {
  const rows = new Map(layoutEntries.filter(({ widget }) => widget.meta.optionChoiceRow)
    .map(({ widget, box }) => [widget.meta.optionChoiceRow, { ...box }]));
  return layoutEntries.flatMap(({ widget, box }) => {
    const title = widget.meta.optionChoiceControls;
    return title ? [{ title, row: rows.get(title) || null, controls: { ...box } }] : [];
  });
}

export function contentRowLayoutSnapshot() {
  return layoutEntries.flatMap(({ widget, box }) => {
    const kind = widget.meta.contentRowKind;
    return kind ? [{ kind, index: widget.meta.trackIndex ?? null, box: { ...box } }] : [];
  });
}

export function playlistSelectionSnapshot() {
  const shown = visibleTracks();
  const selectedIndices = shown.flatMap((track, index) =>
    state.selectedTrackIDs.has(trackID(track)) ? [index] : []);
  return {
    selectedIDs: [...state.selectedTrackIDs],
    selectedIndices,
    anchorID: state.selectionAnchorID,
    primaryIndex: state.selectedTrack,
  };
}

export function spacingReadoutLayoutSnapshot() {
  return layoutEntries.flatMap(({ widget, box }) => widget.meta.spacingReadout
    ? [{ title: widget.meta.spacingReadout, text: widget.meta.text, box: { ...box } }] : []);
}

function selectionYAt(time = performance.now()) {
  if (!selectionAnimation) return selectionBand?.y ?? null;
  const progress = Math.max(0, Math.min(1,
    (time - selectionAnimation.startedAt) / selectionAnimation.duration));
  const eased = easeSelection(progress);
  return selectionAnimation.fromY
    + (selectionAnimation.toY - selectionAnimation.fromY) * eased;
}

function sidebarSelectionYAt(time = performance.now()) {
  if (!sidebarSelectionAnimation) return sidebarSelectionBand?.y ?? null;
  const progress = Math.max(0, Math.min(1,
    (time - sidebarSelectionAnimation.startedAt) / sidebarSelectionAnimation.duration));
  return sidebarSelectionAnimation.fromY
    + (sidebarSelectionAnimation.toY - sidebarSelectionAnimation.fromY) * easeSelection(progress);
}

function floor(value) {
  return Math.round(value);
}

function layoutPixelEdge(value) {
  return Math.floor(value + 0.000001);
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
  return normalizedBitmapText(value);
}

function normalizedBitmapText(value) {
  const text = String(value)
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[–—]/g, "-")
    .replace(/[’‘]/g, "'");
  return text.toUpperCase();
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
  const cursor = state.searchFocused && searchCursorVisible ? "|" : "";
  if (!query && !state.searchFocused) return "SEARCH LIBRARY";
  const availableWidth = box.width - 2 * controlPaddingDots();
  const limit = Math.max(1, Math.floor((availableWidth + 1) / fontProfile().advance));
  const queryCharacters = Array.from(query);
  const visibleCount = Math.max(0, limit - cursor.length);
  const visibleQuery = visibleCount > 0 ? queryCharacters.slice(-visibleCount).join("") : "";
  return `${visibleQuery}${cursor}`;
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
  const faceSize = Math.max(1, DEVICE_PIXELS_PER_LCD_DOT - 1);
  for (let y = firstRow; y < lastRow; y += 1) {
    const sourceRow = y * WIDTH;
    const topRow = y * DEVICE_PIXELS_PER_LCD_DOT * outputWidth;
    for (let x = firstColumn; x < lastColumn; x += 1) {
      const face = packedRGB[pixels[sourceRow + x]];
      const outputX = x * DEVICE_PIXELS_PER_LCD_DOT;
      for (let dotY = 0; dotY < DEVICE_PIXELS_PER_LCD_DOT; dotY += 1) {
        const row = topRow + dotY * outputWidth + outputX;
        for (let dotX = 0; dotX < DEVICE_PIXELS_PER_LCD_DOT; dotX += 1) {
          imageWords[row + dotX] = dotX < faceSize && dotY < faceSize ? face : background;
        }
      }
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
  if (style.widthPercent !== undefined) yoga.setWidthPercent(style.widthPercent);
  if (style.minWidth !== undefined) yoga.setMinWidth(style.minWidth * STYLE_SCALE);
  if (style.minHeight !== undefined) yoga.setMinHeight(style.minHeight * STYLE_SCALE);
  if (style.minWidthPercent !== undefined) yoga.setMinWidthPercent(style.minWidthPercent);
  if (style.maxWidth !== undefined) yoga.setMaxWidth(style.maxWidth * STYLE_SCALE);
  if (style.maxWidthPercent !== undefined) yoga.setMaxWidthPercent(style.maxWidthPercent);
  if (style.height !== undefined) yoga.setHeight(style.height * STYLE_SCALE);
  if (style.left !== undefined) yoga.setPosition(Edge.Left, style.left * STYLE_SCALE);
  if (style.top !== undefined) yoga.setPosition(Edge.Top, style.top * STYLE_SCALE);
  if (style.flexGrow !== undefined) yoga.setFlexGrow(style.flexGrow);
  if (style.flexBasis !== undefined) yoga.setFlexBasis(style.flexBasis * STYLE_SCALE);
  if (style.padding !== undefined) yoga.setPadding(Edge.All, style.padding * STYLE_SCALE);
  if (style.paddingHorizontal !== undefined) {
    yoga.setPadding(Edge.Horizontal, style.paddingHorizontal * STYLE_SCALE);
  }
  if (style.paddingLeft !== undefined) yoga.setPadding(Edge.Left, style.paddingLeft * STYLE_SCALE);
  if (style.marginLeft !== undefined) yoga.setMargin(Edge.Left, style.marginLeft * STYLE_SCALE);
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

function contentRowStride(kind) {
  return rowHeight() + spacingValue("textLineGapDots") / STYLE_SCALE;
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
  return spacingValue("uiChromeGapDots");
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

function spacingReadout(key) {
  return `${Math.round(spacingValue(key))} DOTS`;
}

function uiSectionGap() {
  return uiGap();
}

function textLineGapDots() {
  return spacingValue("textLineGapDots");
}

function playlistColumnGap() {
  return uiGapDots() / STYLE_SCALE;
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

function paintSidebarIcon(name, box) {
  const art = SIDEBAR_ICON_ART[name];
  if (!art) return;
  let minX = SIDEBAR_ICON_SIZE_DOTS;
  let minY = SIDEBAR_ICON_SIZE_DOTS;
  let maxX = -1;
  let maxY = -1;
  art.forEach((row, y) => {
    for (let x = 0; x < row.length; x += 1) {
      if (row[x] !== "1") continue;
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x);
      maxY = Math.max(maxY, y);
    }
  });
  if (maxX < minX || maxY < minY) return;
  const left = Math.round(box.x + box.width / 2 - (minX + maxX + 1) / 2);
  const top = Math.round(box.y + box.height / 2 - (minY + maxY + 1) / 2);
  art.forEach((row, y) => {
    for (let x = 0; x < row.length; x += 1) {
      if (row[x] === "1") fillRect(left + x, top + y, 1, 1, 0);
    }
  });
}

function libraryToolbarItems() {
  const bulkAction = sidebarBulkAction();
  return [
    {
      id: "library",
      title: "LIBRARY",
      icon: "library",
      view: "LIBRARY",
      onClick: () => { void setSidebarMode("consoles"); },
    },
    {
      id: "paths",
      title: "PATH",
      icon: "folder",
      view: "PATHS",
      onClick: () => { void setSidebarMode("paths"); },
    },
    {
      id: "favorites",
      title: "FAVORITES",
      icon: "heart",
      view: "FAVORITES",
      onClick: () => selectSidebarView("FAVORITES"),
    },
    {
      id: "history",
      title: "HISTORY",
      icon: "clock",
      view: "HISTORY",
      onClick: () => { void showPlaybackHistory(); },
    },
    {
      id: "tree",
      title: bulkAction.title,
      icon: "tree",
      sidebarBulkAction: true,
      onClick: () => toggleAllSidebarGroups(),
    },
    {
      id: "options",
      title: "OPTIONS",
      icon: "gear",
      view: "OPTIONS",
      onClick: () => openOptionsScreen(),
    },
  ];
}

function libraryPaneWidth() {
  const items = libraryToolbarItems();
  const toolbarWidth = items.length * SIDEBAR_BUTTON_SIZE_DOTS
    + Math.max(0, items.length - 1) * uiGapDots()
    + 2 * uiGapDots();
  return Math.max(94, toolbarWidth / STYLE_SCALE);
}

function appStatusDetails() {
  const playingQueue = state.currentTrackId && state.playbackQueue.length
    ? state.playbackQueue : null;
  const playingIndex = playingQueue
    ? playingQueue.findIndex((track) => trackID(track) === state.currentTrackId) : -1;
  const selected = visibleTracks()[state.selectedTrack] || null;
  const track = playingIndex >= 0 ? playingQueue[playingIndex] : selected;
  const sourcePath = String(track?.archivePath || track?.path || track?.filename || "");
  const archiveEntry = String(track?.archiveEntry || "");
  const playing = Boolean(track && state.currentTrackId === trackID(track));
  const playlist = activeTracks();
  const playlistDuration = playlist.reduce((sum, item) => sum + statusTrackDuration(item), 0);
  const playlistIsOpen = playlist.some(statusTrackIsOpen);
  const songDuration = track ? statusTrackDuration(track) : 0;
  const clock = track
    ? `${formatTime(playing ? state.positionMs : 0)} / ${songDuration > 0 ? formatTime(songDuration) : "OPEN"} / ${playlistIsOpen ? "OPEN" : formatTime(playlistDuration)}`
    : `0:00 / OPEN / ${playlistIsOpen ? "OPEN" : formatTime(playlistDuration)}`;
  const visibleStatus = state.catalogLoading ? "RELOADING CATALOG"
    : /^CATALOG ERROR:/.test(state.status) ? state.status : null;
  return {
    location: visibleStatus || (track
      ? [sourcePath, archiveEntry].filter(Boolean).join(" :: ") || "FILE PATH UNAVAILABLE"
      : state.status || "NO FILE SELECTED"),
    clock,
  };
}

function trackSupportsLongPlay(track) {
  const path = String(track?.archiveEntry || track?.path || track?.filename || "");
  const extension = path.match(/\.([a-z0-9]+)$/i)?.[1]?.toLowerCase();
  return Boolean(extension && bridge?.playbackBackends?.some((backend) => backend.supportsLongPlay
    && backend.extensions?.some((candidate) => String(candidate).toLowerCase() === extension)));
}

function statusTrackDuration(track) {
  const nativeLength = Math.max(0, Number(track?.playLengthMs) || 0);
  if (state.preferences.longPlayEnabled === true && trackSupportsLongPlay(track)) {
    const playLength = Math.max(0, Number(state.preferences.manualPlayTimeSeconds ?? 180)) * 1_000;
    if (playLength === 0) return 0;
    const fadeLength = state.preferences.fadeEnabled === false
      ? 0 : Math.max(0, Number(state.preferences.spcFadeSeconds ?? 6)) * 1_000;
    return playLength + fadeLength;
  }
  return nativeLength;
}

function statusTrackIsOpen(track) {
  return state.preferences.longPlayEnabled === true && trackSupportsLongPlay(track)
    && Number(state.preferences.manualPlayTimeSeconds ?? 180) === 0;
}

function appStatusArea(parent) {
  const details = appStatusDetails();
  const height = rowHeight();
  const status = makeWidget(parent, {
    direction: FlexDirection.Row,
    height,
    gap: uiGap(),
    alignItems: Align.Center,
  });
  label(status, details.location, {
    height,
    flexGrow: 1,
    flexBasis: 0,
    minWidth: 0,
    flexShrink: 1,
  }, {
    statusField: "location",
    textShade: 0,
    inset: controlPaddingDots(),
  });
  label(status, details.clock, {
    height,
    width: textLayoutWidth(details.clock),
    flexShrink: 0,
  }, {
    statusField: "clock",
    textShade: 0,
    inset: controlPaddingDots(),
    align: "right",
  });
  return status;
}

function panelTitle(parent, text) {
  const titleHeight = buttonStandardHeight();
  const row = makeWidget(parent, {
    direction: FlexDirection.Row,
    height: titleHeight,
    alignItems: Align.Center,
  }, {
    fill: 2,
    optionPanelTitle: text,
    paint(box) { fillRect(box.x, box.y, box.width, box.height, 2); },
  });
  label(row, text, { flexGrow: 1, height: titleHeight }, {
    textShade: 0,
    inset: controlPaddingDots(),
    align: "center",
  });
  return row;
}

function pixelButton(parent, text, onClick, style = {}) {
  return label(parent, text, {
    direction: FlexDirection.Row,
    alignItems: Align.Center,
    justifyContent: Justify.Center,
    height: style.height ?? buttonStandardHeight(),
    width: style.widthPercent !== undefined ? undefined : style.width ?? buttonWidth(text),
    widthPercent: style.widthPercent,
    minWidth: style.minWidth,
    flexGrow: style.flexGrow ?? 0,
    flexShrink: style.flexShrink,
    flexBasis: style.flexBasis,
  }, {
    border: 1,
    fill: style.optionPage ? undefined : style.selected ? 2 : undefined,
    textShade: 0,
    inset: style.inset ?? controlPaddingDots(),
    align: style.align ?? "center",
    controlTitle: style.controlTitle,
    optionOwner: style.optionOwner,
    optionPage: style.optionPage === true,
    columnMenuItem: style.columnMenuItem === true,
    sidebarBulkAction: style.sidebarBulkAction === true,
    sidebarAction: style.sidebarAction,
    sidebarIcon: style.sidebarIcon,
    animationFPSControl: style.animationFPSControl === true,
    paint: style.icon ? (box) => paintSidebarIcon(style.icon, box) : style.paint,
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
  return optionChecklistRow(parent, title, checked, onClick, extraMeta);
}

function appendOptionCheckboxGlyph(parent, checkboxKey, checked, metadata = {}) {
  const checkboxSize = fontProfile().height;
  return makeWidget(parent, { width: checkboxSize / STYLE_SCALE, height: checkboxSize / STYLE_SCALE }, {
    paint(box) {
      const square = checkboxSquareBox(box);
      metadata.optionCheckboxBox = square;
      if (!state.checkboxBoxes.some((entry) => entry.key === checkboxKey)) {
        state.checkboxBoxes.push({ key: checkboxKey, box: square });
      }
      paintCheckboxFace(square, checked === true);
    },
  });
}

function checkboxSquareBox(box) {
  const size = fontProfile().height;
  return {
    x: Math.floor(box.x + (box.width - size) / 2),
    y: Math.floor(box.y + (box.height - size) / 2),
    width: size,
    height: size,
  };
}

function paintCheckboxFace(box, checked, horizontalScale = 1) {
  const width = Math.max(1, Math.min(box.width, Math.round(box.width * horizontalScale)));
  const x = Math.floor(box.x + (box.width - width) / 2);
  if (width === 1) {
    fillRect(x, box.y, width, box.height, 1);
    return;
  }
  strokeRect(x, box.y, width, box.height, 0);
  if (checked && width > 2 && box.height > 2) {
    fillRect(x + 1, box.y + 1, width - 2, box.height - 2, 0);
  }
}

function checkboxAngleAt(animation, time = performance.now()) {
  const progress = Math.max(0, Math.min(1, (time - animation.startedAt) / animation.duration));
  return animation.fromAngle + (animation.toAngle - animation.fromAngle) * easeSelection(progress);
}

function startCheckboxAnimation(key, checked) {
  const duration = animationDurationMilliseconds();
  if (!animationEnabled() || duration <= 0) return;
  const now = performance.now();
  const active = checkboxAnimations.get(key);
  const fromAngle = active ? checkboxAngleAt(active, now) : (checked ? Math.PI : 0);
  const toAngle = checked ? 0 : Math.PI;
  if (fromAngle === toAngle) return;
  checkboxAnimations.set(key, { fromAngle, toAngle, startedAt: now, duration });
  checkboxFrameTiming.lastFrameAt = Number.NaN;
  if (!checkboxAnimationFrame) checkboxAnimationFrame = requestAnimationFrame(animateCheckboxFrame);
}

function optionChecklistRow(parent, title, checked, onClick, extraMeta = {}) {
  const height = buttonStandardHeight();
  const checkboxKey = extraMeta.optionCheckboxKey || `${state.optionsPage}:${title}`;
  const rowMeta = {
    onClick: () => {
      startCheckboxAnimation(checkboxKey, checked === true);
      onClick();
    },
    controlTitle: title,
    optionChecklistItem: true,
    optionCheckboxChecked: checked === true,
    optionCheckboxKey: checkboxKey,
    ...extraMeta,
  };
  const row = makeWidget(parent, {
    direction: FlexDirection.Row,
    alignItems: Align.Center,
    height,
    gap: uiGap(),
    paddingHorizontal: controlPaddingDots() / STYLE_SCALE,
  }, rowMeta);
  appendOptionCheckboxGlyph(row, checkboxKey, checked, rowMeta);
  label(row, title, { flexGrow: 1, height }, {
    textShade: 0, inset: controlPaddingDots(),
  });
  return row;
}

function optionToggleDuration(parent, title, controlPrefix, checked, onClick, key,
  minimum, maximum, fallback, step, allowOpen = false) {
  const height = buttonStandardHeight();
  const checkboxKey = `${state.optionsPage}:${title}`;
  const rowMeta = {
    onClick: () => {
      startCheckboxAnimation(checkboxKey, checked === true);
      onClick();
    },
    controlTitle: title,
    optionChecklistItem: true,
    optionCheckboxChecked: checked === true,
    optionCheckboxKey: checkboxKey,
  };
  const row = controlRow(parent, {
    height,
    gap: uiGap(),
    paddingHorizontal: controlPaddingDots() / STYLE_SCALE,
  }, rowMeta);
  appendOptionCheckboxGlyph(row, checkboxKey, checked, rowMeta);
  label(row, title, { flexGrow: 1, height }, {
    textShade: 0, inset: controlPaddingDots(),
  });
  pixelButton(row, "[-]", () => adjustPlaybackDuration(key, -step, minimum, maximum, fallback), {
    controlTitle: `${controlPrefix} -`,
  });
  pixelButton(row, "[+]", () => adjustPlaybackDuration(key, step, minimum, maximum, fallback), {
    controlTitle: `${controlPrefix} +`,
  });
  durationInput(row, key, optionDuration(state.preferences[key] ?? fallback, allowOpen),
    minimum, maximum, fallback, allowOpen);
  return row;
}

function optionToggleAdjuster(parent, title, controlPrefix, checked, onClick,
  value, onDecrease, onIncrease) {
  const height = buttonStandardHeight();
  const checkboxKey = `${state.optionsPage}:${title}`;
  const rowMeta = {
    onClick: () => {
      startCheckboxAnimation(checkboxKey, checked === true);
      onClick();
    },
    controlTitle: title,
    optionChecklistItem: true,
    optionCheckboxChecked: checked === true,
    optionCheckboxKey: checkboxKey,
  };
  const row = controlRow(parent, {
    height,
    gap: uiGap(),
    paddingHorizontal: controlPaddingDots() / STYLE_SCALE,
  }, rowMeta);
  appendOptionCheckboxGlyph(row, checkboxKey, checked, rowMeta);
  label(row, title, { flexGrow: 1, height }, {
    textShade: 0, inset: controlPaddingDots(),
  });
  pixelButton(row, "[-]", onDecrease, { controlTitle: `${controlPrefix} -` });
  pixelButton(row, "[+]", onIncrease, { controlTitle: `${controlPrefix} +` });
  label(row, value, { width: framedTextWidth(value), height }, {
    border: BUTTON_BORDER_DOTS,
    textShade: 0,
    align: "center",
    inset: controlPaddingDots(),
    spacingReadout: controlPrefix,
  });
  return row;
}

function optionChoice(parent, title, choices) {
  const height = buttonStandardHeight();
  const row = controlRow(parent, {
    height,
    gap: 0,
  }, {
    optionChoiceRow: title,
    paint(box) { line(box.x, box.y + box.height - 1, box.x + box.width, box.y + box.height, 2); },
  });
  label(row, title, { widthPercent: 33.3333, height }, {
    textShade: 0, inset: controlPaddingDots(),
  });
  const controls = makeWidget(row, {
    direction: FlexDirection.Row,
    widthPercent: 66.6667,
    gap: uiGap(),
    alignItems: Align.Center,
  }, { optionChoiceControls: title });
  choices.forEach((choice) => pixelButton(controls, choice.title, choice.onClick, {
    flexGrow: 1,
    flexBasis: 0,
    minWidth: 0,
    selected: choice.selected,
    controlTitle: `${title} ${choice.title}`,
  }));
  return row;
}

function optionAdjuster(parent, title, value, onDecrease, onIncrease) {
  const height = buttonStandardHeight();
  const row = controlRow(parent, { height }, {
    paint(box) { line(box.x, box.y + box.height - 1, box.x + box.width, box.y + box.height, 2); },
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
    spacingReadout: title,
  });
  return row;
}

function animationFPSTrack(box) {
  return {
    left: Math.floor(box.x + 3),
    right: Math.max(Math.floor(box.x + 3), Math.floor(box.x + box.width - 4)),
    y: Math.floor(box.y + box.height / 2),
  };
}

function animationFPSX(box, fps) {
  const track = animationFPSTrack(box);
  const fraction = (fps - ANIMATION_FPS_MIN) / (ANIMATION_FPS_MAX - ANIMATION_FPS_MIN);
  return Math.round(track.left + Math.max(0, Math.min(1, fraction)) * (track.right - track.left));
}

function paintAnimationFPSControl(box) {
  const track = animationFPSTrack(box);
  const thumbX = animationFPSX(box, state.animationFPS);
  fillRect(track.left, track.y, track.right - track.left + 1, 1, 1);
  fillRect(track.left, track.y, thumbX - track.left + 1, 1, 2);
  ANIMATION_FPS_TICKS.forEach((fps) => {
    const x = animationFPSX(box, fps);
    fillRect(x, track.y - 2, 1, 5, 0);
  });
  fillRect(thumbX - 2, track.y - 3, 5, 7, 0);
  if (state.animationFPSFocused) strokeRect(box.x, box.y, box.width, box.height, 0);
}

function setAnimationFPSFromPointer(pointerX, box, persist = false) {
  const track = animationFPSTrack(box);
  const fraction = Math.max(0, Math.min(1,
    (pointerX - track.left) / Math.max(1, track.right - track.left)));
  setAnimationFPS(ANIMATION_FPS_MIN
    + fraction * (ANIMATION_FPS_MAX - ANIMATION_FPS_MIN), persist);
}

function addAnimationFPSControl(parent) {
  const height = buttonStandardHeight();
  const row = controlRow(parent, { height }, {
    paint(box) { line(box.x, box.y + box.height - 1, box.x + box.width, box.y + box.height, 2); },
  });
  label(row, "ANIMATION FPS", { widthPercent: 33.3333, height }, {
    textShade: 0,
    inset: controlPaddingDots(),
  });
  makeWidget(row, {
    flexGrow: 1,
    flexShrink: 1,
    flexBasis: 0,
    minWidth: 0,
    height,
  }, {
    controlTitle: "ANIMATION FPS CAP",
    animationFPSControl: true,
    paint: paintAnimationFPSControl,
    onClick(event) {
      const point = logicalPoint(event);
      const entry = findTargetEntry(point, (widget) => widget.meta.animationFPSControl);
      if (entry) setAnimationFPSFromPointer(point.x, entry.box, true);
    },
  });
  label(row, `${state.animationFPS} FPS`, {
    width: framedTextWidth("240 FPS"),
    height,
  }, {
    border: BUTTON_BORDER_DOTS,
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
    case "favorite": return "";
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
    hasContent: Object.fromEntries(columns
      .filter((column) => !["favorite", "index", "title"].includes(column.key))
      .map((column) => [column.key, false])),
    lengths: Object.fromEntries(columns
      .filter((column) => !["favorite", "index", "title"].includes(column.key))
      .map((column) => [column.key, Array.from(normalizedText(column.title)).length])),
  };
  items.forEach((track, index) => {
    for (const column of columns) {
      if (["favorite", "index", "title"].includes(column.key)) continue;
      const value = tableValue(track, column.key, index);
      const normalized = normalizedText(value).trim();
      const valueLength = Array.from(normalized).length;
      measured.lengths[column.key] = Math.max(measured.lengths[column.key] ?? 0, valueLength);
      if (normalized && normalized !== "—") measured.hasContent[column.key] = true;
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
  const autoHidden = new Set(state.autoHideEmptyColumns
    ? columns.filter((column) => !["favorite", "index", "title"].includes(column.key)
      && !content.hasContent[column.key]).map((column) => column.key)
    : []);
  state.autoHiddenColumnKeys = [...autoHidden];
  const visible = columns.filter((column) => !autoHidden.has(column.key)
    && (column.mandatory || columnVisibility[column.key] !== false));
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
    const duration = animationDurationMilliseconds();
    if (animationEnabled() && duration > 0) {
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

export function optionsPaneSnapshot() {
  return layoutEntries.filter(({ widget }) => widget.meta.optionFrame)
    .map(({ widget, box }) => ({ frame: widget.meta.optionFrame, box: { ...box } }));
}

export function optionsContentSnapshot() {
  const viewport = layoutEntries.find(({ widget }) => widget.meta.optionContentViewport)?.box;
  const body = layoutEntries.find(({ widget }) => widget.meta.optionContentBody)?.box;
  return {
    viewport: viewport ? { ...viewport } : null,
    body: body ? { ...body } : null,
    scrollOffset: state.optionsScrollOffset,
    scrollMaximum: state.optionsScrollMaximum,
    screen: { width: WIDTH, height: HEIGHT },
  };
}

export function optionsStyleSnapshot() {
  return layoutEntries.flatMap(({ widget, box }) => {
    if (widget.meta.optionPanelTitle) {
      return [{ kind: "title", name: widget.meta.optionPanelTitle, box: { ...box } }];
    }
    if (widget.meta.optionOwnerTitle) {
      return [{ kind: "owner", name: widget.meta.optionOwnerTitle, box: { ...box } }];
    }
    if (widget.meta.optionGroupTitle) {
      return [{ kind: "group", name: widget.meta.optionGroupTitle, box: { ...box } }];
    }
    if (widget.meta.optionChecklistItem) {
      return [{
        kind: "checklist",
        name: widget.meta.controlTitle,
        checked: widget.meta.optionCheckboxChecked === true,
        checkboxBox: widget.meta.optionCheckboxBox ? { ...widget.meta.optionCheckboxBox } : null,
        box: { ...box },
      }];
    }
    if (widget.meta.optionDiagnosticValue) {
      return [{
        kind: "diagnostic",
        name: widget.meta.optionDiagnosticValue,
        value: widget.meta.text,
        box: { ...box },
      }];
    }
    return [];
  });
}

export function selectionBandSnapshot() {
  if (!selectionBand) return null;
  const time = performance.now();
  const y = selectionYAt(time);
  const progress = selectionAnimation
    ? Math.max(0, Math.min(1, (time - selectionAnimation.startedAt) / selectionAnimation.duration))
    : 1;
  return {
    kind: selectionBand.kind,
    x: selectionBand.x,
    y: selectionBand.y,
    animatedY: y,
    targetY: selectionAnimation?.toY ?? selectionBand.y,
    animationProgress: progress,
    width: selectionBand.width,
    height: selectionBand.height,
  };
}

export function sidebarSelectionBandSnapshot() {
  if (!sidebarSelectionBand) return null;
  const time = performance.now();
  return {
    key: sidebarSelectionBand.key,
    y: sidebarSelectionBand.y,
    animatedY: sidebarSelectionYAt(time),
    targetY: sidebarSelectionAnimation?.toY ?? sidebarSelectionBand.y,
    animationProgress: sidebarSelectionAnimation
      ? Math.max(0, Math.min(1,
        (time - sidebarSelectionAnimation.startedAt) / sidebarSelectionAnimation.duration)) : 1,
    animating: Boolean(sidebarSelectionAnimation),
    x: sidebarSelectionBand.x,
    width: sidebarSelectionBand.width,
    height: sidebarSelectionBand.height,
  };
}

export function reorderAnimationSnapshot(time = performance.now()) {
  const animation = reorderAnimation ? {
    kind: reorderAnimation.kind,
    duration: reorderAnimation.duration,
    progress: Math.max(0, Math.min(1,
      (time - reorderAnimation.startedAt) / reorderAnimation.duration)),
    fromX: { ...reorderAnimation.fromX },
  } : null;
  return {
    dragging: pointerInteraction?.kind === "reorder" && pointerInteraction.dragging,
    preview: reorderPreview ? { kind: reorderPreview.kind, keys: [...reorderPreview.keys] } : null,
    animation,
  };
}

export function columnResizePerformanceSnapshot() {
  return { reusedTreeFrames: columnAnimationTreeReusedFrames };
}

export function framebufferShadeSnapshot(x, y) {
  const column = Math.floor(x);
  const row = Math.floor(y);
  if (column < 0 || column >= WIDTH || row < 0 || row >= HEIGHT) return null;
  return pixels[row * WIDTH + column];
}

function createTableHeader(parent, columns) {
  const headerHeight = buttonStandardHeight();
  const header = makeWidget(parent, {
    direction: FlexDirection.Row,
    alignItems: Align.Center,
    height: headerHeight,
    gap: playlistColumnGap(),
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
  const rowHeightValue = rowHeight();
  const selected = state.selectedTrackIDs.has(trackID(track));
  const primarySelected = selected && index === state.selectedTrack;
  const row = makeWidget(parent, {
    direction: FlexDirection.Row,
    alignItems: Align.Center,
    height: rowHeightValue,
    gap: playlistColumnGap(),
  }, {
    onClick: (event) => {
      selectTrack(index, false, {
        extend: event.metaKey || event.ctrlKey,
        range: event.shiftKey,
      });
      if (event.detail >= 2) startTrack(track, activeTracks());
    },
    trackIndex: index,
    playlistRow: true,
    contentRowKind: "playlist",
    paint(box) {
      if (selected && !primarySelected) fillRect(box.x, box.y, box.width, box.height, 2);
    },
  });
  columns.forEach((column) => {
    if (column.key === "favorite") {
      const checked = state.favoriteIDs.has(favoriteID(track));
      const checkboxKey = `favorite:${favoriteID(track)}`;
      makeWidget(row, {
        width: column.width,
        height: rowHeightValue,
      }, {
        columnKey: column.key,
        trackIndex: index,
        controlTitle: "FAVORITE",
        onClick: () => {
          startCheckboxAnimation(checkboxKey, checked);
          void toggleFavorite(track);
        },
        paint(box) {
          const square = checkboxSquareBox(box);
          if (!state.checkboxBoxes.some((entry) => entry.key === checkboxKey)) {
            state.checkboxBoxes.push({ key: checkboxKey, box: square });
          }
          paintCheckboxFace(square, checked);
        },
      });
      return;
    }
    label(row, tableValue(track, column.key, index), {
      width: column.width,
      flexGrow: column.flexGrow,
      height: rowHeightValue,
    }, {
      textShade: 0,
      inset: controlPaddingDots(),
      align: column.rowAlign ?? column.align ?? "left",
      columnKey: column.key,
      trackIndex: index,
    });
  });
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
      height: spacingValue("textLineGapDots") / STYLE_SCALE,
      flexShrink: 0,
    });
  }
  const rowHeightValue = rowHeight();
  return label(parent, text, {
    height: rowHeightValue,
    paddingHorizontal: controlPaddingDots(),
  }, {
    textShade: 0,
    onClick: options.onClick,
    sidebarDisclosure: options.disclosure === true,
    sidebarSelection: selected,
    sidebarSelectionKey: options.selectionKey ?? null,
    sidebarSelectionDepth: options.selectionDepth ?? 0,
    contentRowKind: "sidebar",
    sidebarContext: options.context || null,
    disclosureProgress: options.disclosureProgress ?? 0,
    disclosureIndent: options.disclosureIndent ?? controlPaddingDots(),
    inset: options.indent ?? (options.disclosure ? controlPaddingDots() + 2 * fontProfile().advance : 0),
    paint(box) {
      if (options.disclosure) paintChevron(box, options.disclosureProgress ?? 0,
        options.disclosureIndent ?? controlPaddingDots());
    },
  });
}

function visibleRowCount() {
  const toolbarGrowth = 2 * (buttonStandardHeight() + uiGap()) + uiGap();
  const fixedChrome = 78 - buttonStandardHeight() - uiGap();
  return Math.max(1, Math.floor((HEIGHT / STYLE_SCALE - fixedChrome - toolbarGrowth)
    / contentRowStride("playlist")));
}

function visibleLibraryRowCount() {
  const rootChrome = 2 * buttonStandardHeight() + 3 * uiGap()
    + rowHeight(4);
  const sidebarChrome = buttonStandardHeight()
    + SIDEBAR_BUTTON_SIZE_DOTS / STYLE_SCALE + 4 * uiGap();
  return Math.max(1, Math.floor((HEIGHT / STYLE_SCALE - rootChrome - sidebarChrome)
    / contentRowStride("sidebar")));
}

function libraryRowPixelHeight(row) {
  if (row.spacer) return spacingValue("textLineGapDots") * (row.revealProgress ?? 1);
  return rowHeight() * STYLE_SCALE * (row.revealProgress ?? 1);
}

function pathFolderNodes(nodes = state.databaseFiles, folders = []) {
  for (const node of nodes) {
    const children = Array.isArray(node.children) ? node.children : [];
    if (node.path && children.length) folders.push(node);
    if (children.length) pathFolderNodes(children, folders);
  }
  return folders;
}

function consoleSystemNames() {
  return state.consoleSystems;
}

function sidebarBulkAction() {
  const keys = state.sidebarMode === "paths"
    ? state.databaseFileFolders.map((node) => node.path)
    : consoleSystemNames();
  if (!keys.length) return { title: "FOLD ALL" };
  const expanded = state.sidebarMode === "paths" ? state.expandedPathNodes : state.expandedSystems;
  const allExpanded = keys.every((key) => expanded.has(key));
  return { title: allExpanded ? "FOLD ALL" : "UNFOLD ALL" };
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
    const groupTransition = transition?.systems?.get(system);
    const isTransitioning = Boolean(groupTransition);
    const progress = groupTransition?.progress ?? Number(expanded);
    const showChildren = expanded || (isTransitioning && progress > 0);
    const disclosureProgress = progress;
    rows.push({ text: system, system, group: true, disclosureProgress });
    if (showChildren) {
      for (const game of groups.get(system)) {
        rows.push({
          text: game.displayName || game.name,
          game,
          indent: controlPaddingDots() + 2 * fontProfile().advance,
          revealProgress: isTransitioning ? progress : undefined,
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
  function append(node, depth, revealProgress) {
    const children = Array.isArray(node.children) ? node.children : [];
    const directMatch = !query || normalizedText(`${node.name || ""} ${node.path || ""}`).includes(query);
    const matchingChildren = query ? children.filter((child) => pathSubtreeMatches(child, query)) : children;
    if (query && !directMatch && matchingChildren.length === 0) return false;
    const expanded = Boolean(query) || state.expandedPathNodes.has(node.path);
    const nodeTransition = transition?.paths?.get(node.path);
    const inTransition = Boolean(nodeTransition);
    const progress = nodeTransition?.progress ?? Number(expanded);
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
      const childRevealProgress = inTransition ? progress : revealProgress;
      for (const child of matchingChildren) {
        append(child, depth + 1, childRevealProgress);
      }
    }
    return true;
  }
  for (const root of state.databaseFiles) append(root, 0);
  if (!rows.length) rows.push({ text: state.databaseFilesLoading ? "LOADING PATHS" : "NO CATALOG PATHS" });
  return rows;
}

function pathSubtreeMatches(node, query) {
  return normalizedText(`${node.name || ""} ${node.path || ""}`).includes(query)
    || (Array.isArray(node.children) && node.children.some((child) => pathSubtreeMatches(child, query)));
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
  label(library, "SEARCH LIBRARY", {
    height: buttonStandardHeight(),
  }, {
    textShade: state.searchQuery || state.searchFocused
      ? 0 : state.theme === "GAMEBOY" ? 2 : 1,
    inset: controlPaddingDots(),
    border: 1,
    fill: state.searchFocused ? 2 : undefined,
    searchField: true,
    textValue: searchFieldText,
    controlTitle: "SEARCH LIBRARY",
    onClick: () => {
      state.searchQuery = "";
      state.libraryScrollOffset = 0;
      setSearchFocused(true);
      render();
    },
  });
  makeWidget(library, { height: uiGap() });
  const sidebarButtonSize = SIDEBAR_BUTTON_SIZE_DOTS / STYLE_SCALE;
  const navigation = controlRow(library, {
    height: sidebarButtonSize,
    gap: uiGap(),
  });
  libraryToolbarItems().forEach((item) => pixelButton(navigation, "", item.onClick, {
    width: sidebarButtonSize,
    height: sidebarButtonSize,
    flexShrink: 0,
    selected: item.view === "PATHS" ? state.sidebarMode === "paths"
      : item.view === "FAVORITES" ? activePlaylistTab()?.sourceKey === FAVORITES_TAB_SOURCE
        : item.view === "HISTORY" ? activePlaylistTab()?.sourceKey === HISTORY_TAB_SOURCE
          : item.view === "OPTIONS" ? state.tab === "SETTINGS"
            : item.view === "LIBRARY" && state.sidebarMode !== "paths",
    controlTitle: item.title,
    icon: item.icon,
    sidebarAction: item.id,
    sidebarIcon: item.icon,
    sidebarBulkAction: item.sidebarBulkAction,
  }));
  makeWidget(library, { height: uiGap() });
  const rows = libraryRowsWithLineGaps(libraryRows());
  const count = visibleLibraryRowCount();
  const rowHeightDots = contentRowStride("sidebar") * STYLE_SCALE;
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
  const visibleRows = rows.slice(firstRow, lastRow);
  const appendRow = (parent, row) => {
    if (row.spacer) {
      createLibraryRow(parent, "", { spacer: true });
      return;
    }
    const context = row.node ? { kind: "path", node: row.node }
      : row.game ? { kind: "game", game: row.game }
        : row.system ? { kind: "system", system: row.system } : null;
    createLibraryRow(parent, row.text, {
      selected: row.node ? row.node.path === state.selectedPathKey
        : row.game && gameKey(row.game) === state.selectedGameKey,
      selectionKey: row.node ? `path:${row.node.path}`
        : row.game ? `game:${gameKey(row.game)}`
          : row.system ? `system:${row.system}` : null,
      selectionDepth: row.node || row.game ? 2 : row.system ? 1 : 0,
      indent: row.indent,
      disclosure: row.group,
      disclosureProgress: row.disclosureProgress,
      disclosureIndent: row.disclosureIndent,
      context,
      onClick: (event) => {
        if (context) {
          state.enterSelection = "sidebar";
          state.sidebarEnterContext = context;
        }
        if (row.node) {
          if (row.node.kind === "folder" && row.node.children?.length) {
            if (event.detail >= 2) void loadPathNode(row.node);
            else togglePathNode(row.node);
          } else void loadPathNode(row.node);
        } else if (row.game) void loadGame(row.game);
        else if (row.system) void toggleSystem(row.system);
      },
    });
  };
  for (let index = 0; index < visibleRows.length;) {
    const row = visibleRows[index];
    if (row.revealProgress === undefined) {
      appendRow(content, row);
      index += 1;
      continue;
    }

    let end = index + 1;
    while (end < visibleRows.length && visibleRows[end].revealProgress !== undefined) end += 1;
    const transitionRows = visibleRows.slice(index, end);
    const progress = row.revealProgress;
    const fullHeightPixels = transitionRows.reduce((sum, transitionRow) =>
      sum + libraryRowPixelHeight({ ...transitionRow, revealProgress: undefined }), 0);
    const revealViewport = makeWidget(content, {
      height: fullHeightPixels * progress / STYLE_SCALE,
      flexShrink: 0,
      minHeight: 0,
      overflow: Overflow.Hidden,
    }, { clipChildren: true });
    const slidingContent = makeWidget(revealViewport, {
      direction: FlexDirection.Column,
      flexShrink: 0,
    }, {
      translateY: -rowHeight() * STYLE_SCALE * (1 - progress),
    });
    transitionRows.forEach((transitionRow) => appendRow(slidingContent, transitionRow));
    index = end;
  }
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
    id: "catalog-pane",
    paint(box) {
      strokeRect(box.x, box.y, box.width, box.height, 1);
    },
  });
  state.catalogPaneWidget = panel;
  {
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
    activePlaylistTab: tab.id === state.activePlaylistTabId,
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
        onClick: isExiting ? undefined : () => closePlaylistTab(tab.id),
      });
    });
    pixelButton(tabRow, "[+]", () => createPlaylistTab({ duplicateActive: true }), {
      width: buttonWidth("[+]"),
    });
    makeWidget(panel, { height: uiGap() });
  }
  const columns = resolveTableColumns(tableColumns(viewTracks), currentRenderTime);
  const tableGap = Math.max(0, columns.length - 1) * playlistColumnGap();
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
  makeWidget(content, { height: uiGap(), flexShrink: 0 });
  const tableRows = makeWidget(content, {
    direction: FlexDirection.Column,
    gap: spacingValue("textLineGapDots") / STYLE_SCALE,
  }, { id: "catalog-table-rows" });
  const count = visibleRowCount();
  state.queueScroll = Math.max(0, Math.min(state.queueScroll, Math.max(0, viewTracks.length - count)));
  viewTracks.slice(state.queueScroll, state.queueScroll + count).forEach((track, offset) =>
    createQueueRow(tableRows, state.queueScroll + offset, track, columns));
  if (!viewTracks.length) label(tableRows, state.status, { height: rowHeight() }, {
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
  return panel;
}

function addColumnContextMenu(parent) {
  if (!state.columnMenu) return;

  if (state.columnMenu.kind === "sidebar") {
    const items = state.columnMenu.items || [];
    const title = "PLAYLIST";
    const longestLabel = items.reduce((longest, item) =>
      Math.max(longest, textLayoutWidth(item.title)), textLayoutWidth(title));
    const height = (items.length + 1) * buttonStandardHeight()
      + items.length * uiGap() + 2 * uiGroupInsetDots() / STYLE_SCALE + 2 / STYLE_SCALE;
    const width = Math.min(WIDTH / STYLE_SCALE - 16,
      Math.max(68, longestLabel + 2 * controlPaddingDots() / STYLE_SCALE
        + 2 * uiGroupInsetDots() / STYLE_SCALE + 2 / STYLE_SCALE));
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
    panelTitle(menu, title);
    items.forEach((item) => pixelButton(menu, item.title, () => {
      state.columnMenu = null;
      render();
      Promise.resolve(item.action()).catch((error) => {
        state.status = `QUEUE ERROR: ${error.message}`;
        render();
      });
    }, { flexGrow: 1, columnMenuItem: true, controlTitle: item.title }));
    return;
  }

  const height = (configurableColumns.length + 2) * buttonStandardHeight()
    + (configurableColumns.length + 1) * uiGap()
    + 2 * uiGroupInsetDots() / STYLE_SCALE + 2 / STYLE_SCALE;
  const checkboxWidth = (fontProfile().height + controlPaddingDots() * 2) / STYLE_SCALE;
  const contentWidth = checkboxWidth + uiGap() + textLayoutWidth("ARTIST")
    + 2 * controlPaddingDots() / STYLE_SCALE;
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
    optionGroupTitle: title,
    paint(box) { strokeRect(box.x, box.y, box.width, box.height, 1); },
  });
  optionSection(group, title);
  return group;
}

function optionsTocWidth() {
  const available = WIDTH / STYLE_SCALE;
  const labelWidth = framedTextWidth("OPTIONS - VGMBoy") + uiOptionsInsetDots() / STYLE_SCALE * 2;
  return Math.min(available * 0.34, Math.max(labelWidth, Math.min(220, available * 0.20)));
}

function addDisplayOptions(parent, pref) {
  const profile = optionGroup(parent, "SCREEN PROFILE");
  optionChoice(profile, "FONT", [
    { title: "MICRO 3X5", selected: state.font === "MICRO", onClick: () => setFontProfile("MICRO") },
    { title: "STANDARD 5X7", selected: state.font === "STANDARD", onClick: () => setFontProfile("STANDARD") },
  ]);
  optionAdjuster(profile, "LCD DOT SIZE", `${state.lcdDotSize} PX`,
    () => setLCDDotSize(state.lcdDotSize - 1),
    () => setLCDDotSize(state.lcdDotSize + 1));
  addThemeOptions(parent);
  addInterfaceOptions(parent, pref);
}

function beginColorEdit(endpoint) {
  if (!state.customColorsInitialized) {
    const endpoints = PALETTE_ENDPOINTS[state.theme]?.[state.contrast]
      || PALETTE_ENDPOINTS.GAMEBOY.STANDARD;
    state.customBackgroundColor = endpoints.surface;
    state.customFontColor = endpoints.ink;
    state.customColorsInitialized = true;
  }
  state.editingColorEndpoint = endpoint;
  state.colorDraft = "";
  state.colorInputError = null;
  render();
}

function finishColorEdit(commit) {
  const endpoint = state.editingColorEndpoint;
  const draft = state.colorDraft;
  state.editingColorEndpoint = null;
  state.colorDraft = "";
  state.colorInputError = null;
  if (commit && endpoint) {
    const color = colorInputToHex(draft);
    if (!color) state.colorInputError = endpoint;
    else if (endpoint === "background") state.customBackgroundColor = color;
    else state.customFontColor = color;
    if (color) {
      state.customColorsInitialized = true;
      state.theme = "CUSTOM";
      updateThemeSurface();
      RGB = paletteRGB(displayPalette());
      packedRGB = packedPalette(RGB);
      saveDisplayOptions();
    }
  }
  render();
}

function customColorInput(parent, endpoint, title) {
  const editing = state.editingColorEndpoint === endpoint;
  const defaults = state.customColorsInitialized ? null
    : PALETTE_ENDPOINTS[state.theme]?.[state.contrast] || PALETTE_ENDPOINTS.GAMEBOY.STANDARD;
  const value = endpoint === "background"
    ? defaults?.surface || state.customBackgroundColor
    : defaults?.ink || state.customFontColor;
  const row = controlRow(parent, { gap: 0 }, { optionChoiceRow: `${title} COLOR` });
  label(row, title, { widthPercent: 33.3333, height: buttonStandardHeight() }, {
    textShade: 0,
    inset: controlPaddingDots(),
  });
  label(row, editing ? `${state.colorDraft}|` : value, {
    widthPercent: 66.6667,
    height: buttonStandardHeight(),
  }, {
    border: BUTTON_BORDER_DOTS,
    fill: editing ? 2 : undefined,
    textShade: 0,
    inset: controlPaddingDots(),
    clipToBox: true,
    controlTitle: `${title} CSS COLOR INPUT`,
    onClick: () => beginColorEdit(endpoint),
  });
}

function addThemeOptions(parent) {
  const profile = optionGroup(parent, "COLOR THEME");
  optionChoice(profile, "THEME", [
    { title: "GAMEBOY", selected: state.theme === "GAMEBOY", onClick: () => setTheme("GAMEBOY") },
    { title: "NIGHTBOY", selected: state.theme === "NIGHTBOY", onClick: () => setTheme("NIGHTBOY") },
  ]);
  optionChoice(profile, "GAME BOY COLOR", [
    { title: "GRAPEBOY", selected: state.theme === "GRAPEBOY", onClick: () => setTheme("GRAPEBOY") },
    { title: "TEALBOY", selected: state.theme === "TEALBOY", onClick: () => setTheme("TEALBOY") },
  ]);
  optionChoice(profile, "TRANSLUCENT PURPLE", [
    { title: "ATOMIC PURPLE", selected: state.theme === "ATOMICPURPLEBOY", onClick: () => setTheme("ATOMICPURPLEBOY") },
  ]);
  optionChoice(profile, "CUSTOM THEME", [
    { title: "CUSTOM", selected: state.theme === "CUSTOM", onClick: () => setTheme("CUSTOM") },
  ]);
  if (state.theme !== "CUSTOM") {
    const inkLabels = {
      GAMEBOY: ["DARK CHARCOAL", "NEAR BLACK"],
      NIGHTBOY: ["DARKGRAY", "LIGHT GRAY"],
      GRAPEBOY: ["CHARCOAL", "NEAR BLACK"],
      TEALBOY: ["DEEP CHARCOAL", "NEAR BLACK"],
      ATOMICPURPLEBOY: ["LIGHT LAVENDER", "PALE LAVENDER"],
    }[state.theme];
    optionChoice(profile, "INK", [
      { title: inkLabels[0], selected: state.contrast === "STANDARD",
        onClick: () => setContrastProfile("STANDARD") },
      { title: inkLabels[1], selected: state.contrast === "HIGH_CONTRAST",
        onClick: () => setContrastProfile("HIGH_CONTRAST") },
    ]);
  }
  const colors = optionGroup(parent, "CUSTOM LCD COLORS");
  customColorInput(colors, "background", "BG");
  customColorInput(colors, "font", "PIXEL");
  label(colors, state.colorInputError ? "INVALID CSS COLOR" : "ENTER TO APPLY / ESC TO CANCEL", {
    height: rowHeight(),
  }, {
    textShade: 0,
    inset: controlPaddingDots(),
  });
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
  const duration = animationDurationMilliseconds();
  if (animationEnabled() && duration > 0 && current !== target
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
  const divisor = greatestCommonDivisor(steps, 32);
  const numerator = steps / divisor;
  const denominator = 32 / divisor;
  return denominator === 1 ? `${numerator}X` : `${numerator}/${denominator}X`;
}

function greatestCommonDivisor(left, right) {
  let a = Math.abs(left);
  let b = Math.abs(right);
  while (b !== 0) [a, b] = [b, a % b];
  return a || 1;
}

function adjustPlaybackRate(backend, delta) {
  const key = backend === "libvgm" ? "libvgmPlaybackSpeed" : "playbackSpeed";
  const steps = Math.max(1, Math.min(256, playbackRateSteps(backend) + delta));
  setPreference(key, { numerator: steps, denominator: 32 });
}

function beginPlaybackRateEdit(backend) {
  state.editingRateBackend = backend;
  state.rateDraft = "";
  render();
}

function finishPlaybackRateEdit(commit) {
  const backend = state.editingRateBackend;
  const draft = state.rateDraft.trim();
  state.editingRateBackend = null;
  state.rateDraft = "";
  if (!commit || !backend) { render(); return; }
  let multiplier = Number.NaN;
  const fraction = draft.match(/^(\d+)\s*\/\s*(\d+)$/);
  if (fraction) {
    const numerator = Number(fraction[1]);
    const denominator = Number(fraction[2]);
    if (denominator > 0) multiplier = numerator / denominator;
  } else if (/^(?:\d+(?:\.\d{1,6})?|\.\d{1,6})$/.test(draft)) {
    multiplier = Number(draft);
  }
  if (!Number.isFinite(multiplier) || multiplier <= 0 || multiplier > 8) {
    render();
    return;
  }
  const steps = Math.max(1, Math.min(256, Math.round(multiplier * 32)));
  const divisor = greatestCommonDivisor(steps, 32);
  const key = backend === "libvgm" ? "libvgmPlaybackSpeed" : "playbackSpeed";
  setPreference(key, { numerator: steps / divisor, denominator: 32 / divisor });
}

function playbackRateInput(parent, backend) {
  const editing = state.editingRateBackend === backend;
  const value = editing ? `${state.rateDraft}|` : playbackRateLabel(playbackRateSteps(backend));
  return label(parent, value, { width: framedTextWidth("255/32X"), height: buttonStandardHeight() }, {
    border: BUTTON_BORDER_DOTS,
    textShade: 0,
    align: "center",
    inset: controlPaddingDots(),
    editableRateBackend: backend,
    controlTitle: `${backend.toUpperCase()} RATE INPUT`,
    onClick: () => beginPlaybackRateEdit(backend),
  });
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
  const timing = optionGroup(parent, "PLAYBACK TIMING");
  optionToggleDuration(timing, "LONG PLAY", "LONG PLAY TIME", pref.longPlayEnabled === true,
    () => setPreference("longPlayEnabled", pref.longPlayEnabled !== true),
    "manualPlayTimeSeconds", 0, 3600, 180, 30, true);
  optionToggle(timing, "END FADE", pref.fadeEnabled !== false,
    () => setPreference("fadeEnabled", pref.fadeEnabled === false));
  optionDurationAdjuster(timing, "UNKNOWN LENGTH", "unknownDurationSeconds", 30, 3600, 150, 30);
  optionDurationAdjuster(timing, "FADE LENGTH", "spcFadeSeconds", 0, 60, 6, 1);
}

function addQueueOptions(parent, pref) {
  const behavior = optionGroup(parent, "QUEUE BEHAVIOR");
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
}

function diagnosticText(snapshot, key, suffix = "") {
  const value = snapshot?.[key];
  if (value === null || value === undefined || value === "") return "—";
  const number = Number(value);
  if (Number.isFinite(number)) return `${Math.trunc(number)}${suffix}`;
  return `${String(value)}${suffix}`;
}

function diagnosticRate(snapshot, key) {
  const rate = Number(snapshot?.[key]);
  return Number.isFinite(rate) && rate > 0 ? `${Math.trunc(rate)} HZ` : "—";
}

function optionDiagnosticRow(parent, title, value) {
  const height = rowHeight();
  const row = makeWidget(parent, {
    direction: FlexDirection.Row,
    alignItems: Align.Center,
    height,
    gap: uiGap(),
  }, { optionDiagnosticRow: title });
  label(row, title, { width: textLayoutWidth(title, 0), height }, {
    textShade: 0,
    inset: 0,
  });
  label(row, value, { flexGrow: 1, height }, {
    optionDiagnosticValue: title,
    textShade: 0,
    inset: 0,
    align: "right",
  });
}

function addDiagnosticsOptions(parent) {
  const snapshot = state.nativePlaybackStatus || {};
  const hasStatus = Object.keys(snapshot).length > 0;
  const output = optionGroup(parent, "AUDIO OUTPUT");
  optionDiagnosticRow(output, "STATE", hasStatus ? snapshot.output_state || "—" : "—");
  optionDiagnosticRow(output, "BUFFER", hasStatus
    ? `${diagnosticText(snapshot, "buffered_frames")} / ${diagnosticText(snapshot, "ring_buffer_frames")} FRAMES`
    : "—");
  optionDiagnosticRow(output, "UNDERRUNS", diagnosticText(snapshot, "underrun_count"));
  optionDiagnosticRow(output, "OUTPUT RATE", diagnosticRate(snapshot, "output_sample_rate"));

  const decoder = optionGroup(parent, "DECODER");
  optionDiagnosticRow(decoder, "FAMILY", snapshot.decoder_family || "—");
  optionDiagnosticRow(decoder, "SAMPLE RATE", diagnosticRate(snapshot, "decoder_sample_rate"));
  optionDiagnosticRow(decoder, "TEMPO", snapshot.track_loaded === true && Number.isFinite(Number(snapshot.tempo))
    ? `${Number(snapshot.tempo).toFixed(2)}X` : "—");
  optionDiagnosticRow(decoder, "FRAMES REQUESTED", diagnosticText(snapshot, "frames_requested"));
  optionDiagnosticRow(decoder, "FRAMES SUPPLIED", diagnosticText(snapshot, "frames_supplied"));
  optionDiagnosticRow(decoder, "DECODE ERROR", snapshot.decode_error === true ? "YES" : hasStatus ? "NO" : "—");
}

function optionPlaybackRateRow(parent, backend) {
  const title = backend.toUpperCase();
  const indentDots = 2 * controlPaddingDots() + fontProfile().height + uiGapDots();
  const row = controlRow(parent, {
    height: buttonStandardHeight(),
    gap: uiGap(),
    paddingLeft: indentDots / STYLE_SCALE,
  }, {
    optionPlaybackRate: title,
    paint(box) { line(box.x, box.y + box.height - 1, box.x + box.width, box.y + box.height, 2); },
  });
  label(row, "RATE", { width: textLayoutWidth("RATE", 0), height: buttonStandardHeight() }, {
    textShade: 0, inset: 0,
  });
  pixelButton(row, "[-]", () => adjustPlaybackRate(backend, -1), {
    controlTitle: `${title} RATE -`,
  });
  pixelButton(row, "[+]", () => adjustPlaybackRate(backend, 1), {
    controlTitle: `${title} RATE +`,
  });
  playbackRateInput(row, backend);
}

function addMethodOptions(parent, pref) {
  const speed = optionGroup(parent, "DECODER SPEED");
  optionToggle(speed, "LIBGME SPEED", pref.playbackSpeedEnabled === true,
    () => setPreference("playbackSpeedEnabled", pref.playbackSpeedEnabled !== true));
  optionPlaybackRateRow(speed, "libgme");
  optionToggle(speed, "LIBVGM SPEED", pref.libvgmPlaybackSpeedEnabled === true,
    () => setPreference("libvgmPlaybackSpeedEnabled", pref.libvgmPlaybackSpeedEnabled !== true));
  optionPlaybackRateRow(speed, "libvgm");
}

function paintEqualizerBar(box, gain) {
  paintGaugeBar(box,
    (gain - EQ_GAIN_MIN_DB) / (EQ_GAIN_MAX_DB - EQ_GAIN_MIN_DB), EQ_GAIN_STEPS);
}

function equalizerFillWidth(box, gain) {
  const { left, right } = equalizerTrackBounds(box);
  const fraction = Math.max(0, Math.min(1,
    (gain - EQ_GAIN_MIN_DB) / (EQ_GAIN_MAX_DB - EQ_GAIN_MIN_DB)));
  return Math.round((right - left) * fraction);
}

function paintEqualizerValue(box, gain) {
  fillRect(box.x + 1, box.y + 1, box.width - 2, box.height - 2, 3);
  drawText(equalizerGainLabel(gain), box.x + controlPaddingDots(),
    box.y + Math.floor((box.height - fontProfile().height) / 2),
    box.width - controlPaddingDots() * 2, 0, "center");
}

function equalizerTrackBounds(box) {
  return linearTrackBounds(box, EQ_GAIN_STEPS);
}

function linearTrackBounds(box, steps) {
  const inset = EQ_BAR_INSET_DOTS;
  const innerLeft = box.x + inset;
  const innerRight = box.x + box.width - 1 - inset;
  const span = Math.max(1, innerRight - innerLeft);
  const stepWidth = Math.max(1, Math.floor(span / steps));
  const tickSpan = stepWidth * steps;
  const left = innerLeft + Math.floor((span - tickSpan) / 2);
  return {
    left,
    right: left + tickSpan,
    stepWidth,
    steps,
  };
}

function linearTickPositions(box, steps) {
  const bounds = linearTrackBounds(box, steps);
  return Array.from({ length: steps + 1 }, (_, index) =>
    bounds.left + index * bounds.stepWidth);
}

function equalizerTickPositions(box) {
  return linearTickPositions(box, EQ_GAIN_STEPS);
}

function paintGaugeBar(box, fraction, steps) {
  strokeRect(box.x, box.y, box.width, box.height, 1);
  const { left, right } = linearTrackBounds(box, steps);
  const centerY = box.y + Math.floor(box.height / 2);
  const fillWidth = Math.round((right - left) * Math.max(0, Math.min(1, fraction)));
  fillRect(left, box.y + 1, fillWidth, Math.max(1, box.height - 2), 1);
  const tickTop = centerY - 1;
  for (const x of linearTickPositions(box, steps)) fillRect(x, tickTop, 1, 3, 2);
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
    // Preserve the rendered UI Gap after Yoga rounds a flexible gauge to LCD dots.
    marginLeft: oneDot(),
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
  state.volumeGaugeBox = null;
  state.volumeValueBox = null;
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
      const bounds = linearTrackBounds(box, 10);
      const fraction = Math.max(0, Math.min(1,
        (point.x - bounds.left) / Math.max(1, bounds.right - bounds.left)));
      setPreference("appVolume", Math.round(fraction * 10) / 10, true);
    },
    paint(box) {
      state.volumeGaugeBox = box;
      paintGaugeBar(box, volume, 10);
    },
  });
  label(volumeRow, `${Math.round(volume * 100)}%`, {
    width: framedTextWidth("100%"), height: buttonStandardHeight(),
    marginLeft: oneDot(),
  }, {
    border: BUTTON_BORDER_DOTS,
    textShade: 0,
    align: "center",
    inset: controlPaddingDots(),
    controlTitle: "VOLUME VALUE",
    paint(box) { state.volumeValueBox = box; },
  });

  const equalizer = optionGroup(parent, "TEN BAND EQUALIZER");
  optionToggle(equalizer, "EQUALIZER", pref.equalizerEnabled === true,
    () => setPreference("equalizerEnabled", pref.equalizerEnabled !== true, true));
  const equalizerBands = ["31 HZ", "62 HZ", "125 HZ", "250 HZ", "500 HZ", "1K HZ", "2K HZ", "4K HZ", "8K HZ", "16K HZ"];
  equalizerBands.forEach((title, index) => equalizerBand(equalizer, title, index));
}

function addInterfaceOptions(parent, pref) {
  const transport = optionGroup(parent, "TRANSPORT LABELS");
  optionChoice(transport, "BUTTONS", [
    { title: "WORDS", selected: !state.transportSymbols, onClick: () => setTransportSymbols(false) },
    { title: "SYMBOLS", selected: state.transportSymbols, onClick: () => setTransportSymbols(true) },
  ]);
  const layout = optionGroup(parent, "PLAYLIST LAYOUT");
  optionToggle(layout, "AUTO-SIZE COLUMNS", pref.columnAutoSize !== false,
    () => setPreference("columnAutoSize", pref.columnAutoSize === false));
  const spacing = optionGroup(parent, "LAYOUT SPACING");
  optionAdjuster(spacing, "UI BUTTON PAD", spacingReadout("controlPaddingDots"),
    () => adjustDisplaySpacing("controlPaddingDots", -1),
    () => adjustDisplaySpacing("controlPaddingDots", 1));
  optionAdjuster(spacing, "UI CHROME GAP", spacingReadout("uiChromeGapDots"),
    () => adjustDisplaySpacing("uiChromeGapDots", -1),
    () => adjustDisplaySpacing("uiChromeGapDots", 1));
  optionAdjuster(spacing, "TEXT LINE GAP", spacingReadout("textLineGapDots"),
    () => adjustDisplaySpacing("textLineGapDots", -1),
    () => adjustDisplaySpacing("textLineGapDots", 1));
  const window = optionGroup(parent, "WINDOW");
  optionToggle(window, "MAIN WINDOW ON TOP", pref.mainWindowAlwaysOnTop === true,
    () => setPreference("mainWindowAlwaysOnTop", pref.mainWindowAlwaysOnTop !== true));
  const motion = optionGroup(parent, "MOTION");
  optionToggleAdjuster(motion, "ANIMATIONS", "ANIMATION DURATION", animationEnabled(),
    () => setPreference("animationsEnabled", !animationEnabled()),
    `${animationDurationMilliseconds()} MS`,
    () => adjustAnimationTime(-50),
    () => adjustAnimationTime(50));
  addAnimationFPSControl(motion);
}

function setAutoHideEmptyColumns(enabled) {
  state.autoHideEmptyColumns = enabled === true;
  saveDisplayOptions();
  render();
}

function addLibraryOptions(parent, pref) {
  const fields = optionGroup(parent, "PLAYLIST COLUMNS");
  optionToggle(fields, "AUTO-HIDE EMPTY COLUMNS", state.autoHideEmptyColumns,
    () => setAutoHideEmptyColumns(!state.autoHideEmptyColumns));
  configurableColumns.forEach(({ key, title }) => {
    const visibility = pref.columnVisibility || {};
    optionChecklistRow(fields, title, visibility[key] !== false,
      () => setPreference("columnVisibility", {
        ...(state.preferences.columnVisibility || {}),
        [key]: state.preferences.columnVisibility?.[key] === false,
      }));
  });
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
  state.catalogLoading = true;
  state.status = "RELOADING CATALOG";
  render();
  try {
    state.databaseLocation = await bridge?.reloadDatabaseLibrary?.() || state.databaseLocation;
    state.databaseOptionsStatus = "LIBRARY RELOADED";
    state.catalogLoading = false;
    await loadCatalog();
    if (state.sidebarMode === "paths") {
      state.databaseFilesReady = false;
      await loadDatabaseFiles();
    }
  } catch (error) {
    state.catalogLoading = false;
    state.status = `DATABASE ERROR: ${error.message}`;
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
  state.optionsPage = page === "INTERFACE" ? "DISPLAY" : page;
  state.optionsScrollOffset = 0;
  render();
  if (page === "DATABASE") void refreshDatabaseOptions();
  if (page === "DIAGNOSTICS" && bridge?.nativePlaybackState) {
    void bridge.nativePlaybackState().then((snapshot) => {
      applyNativeStatus(snapshot);
      if (state.tab === "SETTINGS" && state.optionsPage === "DIAGNOSTICS") render();
    }).catch(() => {});
  }
}

function addOptionsContent(parent) {
  const navigationWidth = optionsTocWidth();
  const toc = makeWidget(parent, {
    direction: FlexDirection.Column,
    width: navigationWidth,
    flexShrink: 1,
    minWidth: 0,
    minHeight: 0,
    gap: uiGap(),
    padding: uiOptionsInsetDots() / STYLE_SCALE,
  }, {
    optionFrame: "toc",
    clipChildren: true,
    paint(box) { strokeRect(box.x, box.y, box.width, box.height, 1); },
  });
  [
    { title: "VIEWBOY", pages: ["DATABASE", "DISPLAY", "LIBRARY", "QUEUE"] },
    { title: "VGMBoy", pages: ["AUDIO", "DIAGNOSTICS", "METHODS", "PLAYBACK"] },
  ].forEach(({ title, pages }) => {
    panelTitle(toc, `OPTIONS - ${title}`);
    pages.forEach((page) => pixelButton(toc, page, () => selectOptionsPage(page), {
      widthPercent: 100,
      selected: state.optionsPage === page,
      controlTitle: page,
      optionOwner: title,
      optionPage: true,
    }));
  });
  makeWidget(toc, { flexGrow: 1 });

  const panel = makeWidget(parent, {
    direction: FlexDirection.Column,
    flexGrow: 1,
    flexShrink: 1,
    minWidth: 0,
    minHeight: 0,
    gap: uiGap(),
    padding: uiOptionsInsetDots() / STYLE_SCALE,
  }, {
    optionFrame: "content",
    paint(box) { strokeRect(box.x, box.y, box.width, box.height, 1); },
  });
  panelTitle(panel, state.optionsPage === "DISPLAY" ? "DISPLAY + UI" : state.optionsPage);
  const viewport = makeWidget(panel, {
    direction: FlexDirection.Column,
    flexGrow: 1,
    flexShrink: 1,
    flexBasis: 0,
    minWidth: 0,
    minHeight: 0,
    overflow: Overflow.Hidden,
  }, {
    id: "options-content-viewport",
    clipChildren: true,
    optionContentViewport: true,
  });
  const content = makeWidget(viewport, {
    direction: FlexDirection.Column,
    gap: uiSectionGap(),
    minWidth: 0,
  }, { optionContentBody: true, translateY: -state.optionsScrollOffset });
  state.optionsContentViewportWidget = viewport;
  state.optionsContentBodyWidget = content;
  const pref = state.preferences;
  if (state.optionsPage === "DATABASE") addDatabaseOptions(content);
  else if (state.optionsPage === "QUEUE") addQueueOptions(content, pref);
  else if (state.optionsPage === "PLAYBACK") addPlaybackOptions(content, pref);
  else if (state.optionsPage === "METHODS") addMethodOptions(content, pref);
  else if (state.optionsPage === "AUDIO") addAudioOptions(content, pref);
  else if (state.optionsPage === "DIAGNOSTICS") addDiagnosticsOptions(content);
  else if (state.optionsPage === "LIBRARY") addLibraryOptions(content, pref);
  else addDisplayOptions(content, pref);
}

function buildTree() {
  state.tableViewportWidget = null;
  state.tableContentWidget = null;
  state.catalogPaneWidget = null;
  state.tableScrollbarBox = null;
  state.tableScrollbarThumb = null;
  state.libraryViewportWidget = null;
  state.optionsContentViewportWidget = null;
  state.optionsContentBodyWidget = null;
  state.optionsScrollMaximum = 0;
  state.optionsContentViewportBox = null;
  const toolbarHeight = buttonStandardHeight();
  const root = makeWidget(null, {
    direction: FlexDirection.Column,
    width: WIDTH / STYLE_SCALE,
    height: HEIGHT / STYLE_SCALE,
    positionType: PositionType.Relative,
    padding: APP_EDGE_PADDING_PX / STYLE_SCALE,
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
      justifyContent: Justify.FlexStart,
    });
    pixelButton(navigation, "←", () => {
      closeOptionsScreen();
    }, {
      width: buttonWidth("←"),
      controlTitle: "BACK",
      align: "left",
      inset: 1,
    });
  } else {
    const fillButton = (parent, text, onClick, style = {}) => pixelButton(parent, text, onClick, {
      width: 0,
      minWidth: 0,
      flexBasis: 0,
      flexGrow: 1,
      flexShrink: 1,
      height: toolbarHeight,
      border: BUTTON_BORDER_DOTS,
      inset: controlPaddingDots(),
      align: "center",
      ...style,
    });
    const toolbar = controlRow(root, { height: toolbarHeight, gap: uiGap() });
    const transportLabels = state.transportSymbols
      ? { previous: "<<", stop: "[]", play: state.playing ? "||" : ">", next: ">>" }
      : { previous: "PREV", stop: "STOP", play: state.playing ? "PAUSE" : "PLAY", next: "NEXT" };
    fillButton(toolbar, transportLabels.previous, () => selectPrevious(), {
      controlTitle: "PREVIOUS",
      align: state.transportSymbols ? "left" : "center",
      inset: state.transportSymbols ? BUTTON_BORDER_DOTS : controlPaddingDots(),
    });
    fillButton(toolbar, transportLabels.stop, () => stopPlayback(), { controlTitle: "STOP" });
    fillButton(toolbar, transportLabels.play, () => togglePlaying(), {
      controlTitle: state.playing ? "PAUSE" : "PLAY",
    });
    fillButton(toolbar, transportLabels.next, () => selectNext(), { controlTitle: "NEXT" });
    fillButton(toolbar, "LP", () => toggleLongPlay(), {
      selected: state.preferences.longPlayEnabled === true,
      controlTitle: "LONG PLAY",
    });
    fillButton(toolbar, "R1", () => toggleRepeatOne(), {
      selected: state.preferences.repeatMode === "one",
      controlTitle: "REPEAT ONE",
    });
    fillButton(toolbar, "P-RND", () => toggleRandomMode("playlist"), {
      selected: state.preferences.randomMode === "playlist",
      controlTitle: "PLAYLIST RANDOM",
    });
    fillButton(toolbar, "L-RND", () => toggleRandomMode("library"), {
      selected: state.preferences.randomMode === "library",
      controlTitle: "LIBRARY RANDOM",
    });
  }

  const content = makeWidget(root, {
    direction: FlexDirection.Row,
    flexGrow: 1,
    flexShrink: 1,
    flexBasis: 0,
    minWidth: 0,
    minHeight: 0,
    gap: uiGap(),
    alignItems: Align.Stretch,
  });
  if (state.tab === "SETTINGS") {
    addOptionsContent(content);
  } else {
    addLibraryPane(content);
    addCatalogPane(content);
  }

  appStatusArea(root);

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
  if (state.optionsContentViewportWidget && state.optionsContentBodyWidget) {
    const viewportHeight = state.optionsContentViewportWidget.yoga.getComputedLayout().height;
    const contentHeight = state.optionsContentBodyWidget.yoga.getComputedLayout().height;
    state.optionsScrollMaximum = Math.max(0, contentHeight - viewportHeight);
    state.optionsScrollOffset = Math.max(0, Math.min(state.optionsScrollMaximum, state.optionsScrollOffset));
    state.optionsContentBodyWidget.meta.translateY = -state.optionsScrollOffset;
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
  const x = layoutPixelEdge(parentX + layout.left + translateX);
  const y = layoutPixelEdge(parentY + layout.top + translateY);
  const box = {
    x,
    y,
    width: Math.max(0, layoutPixelEdge(parentX + layout.left + translateX + layout.width) - x),
    height: Math.max(0, layoutPixelEdge(parentY + layout.top + translateY + layout.height) - y),
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
    const offsetX = layout.left + (child.meta.frameTranslateX ?? child.meta.translateX ?? 0);
    const offsetY = layout.top + (child.meta.frameTranslateY ?? child.meta.translateY ?? 0);
    const x = layoutPixelEdge(box.x + offsetX);
    const y = layoutPixelEdge(box.y + offsetY);
    paintTree(child, {
      x,
      y,
      width: Math.max(0, layoutPixelEdge(box.x + offsetX + layout.width) - x),
      height: Math.max(0, layoutPixelEdge(box.y + offsetY + layout.height) - y),
    }, childClip);
  }
  paintClip = priorClip;
}

function paintSelectionBandPixels(y) {
  if (selectionBand && y !== null) {
    const bandTop = floor(y);
    const priorClip = paintClip;
    paintClip = intersectBoxes(paintClip, selectionBand.clip);
    fillRect(selectionBand.x, bandTop, selectionBand.width, selectionBand.height, 2);
    for (const row of selectionRows) {
      if (row.box.y >= bandTop + selectionBand.height || row.box.y + row.box.height <= bandTop) continue;
      if (row.widget.meta.optionPage) {
        row.widget.meta.paint?.(row.box);
      } else {
        for (const child of row.widget.children) {
          const entry = layoutEntries.find((candidate) => candidate.widget === child);
          if (entry?.widget.meta.paint) entry.widget.meta.paint(entry.box);
        }
      }
    }
    paintClip = priorClip;
  }
}

function paintSidebarSelectionBandPixels(y) {
  if (!sidebarSelectionBand || y === null) return;
  const bandTop = floor(y);
  const priorClip = paintClip;
  paintClip = intersectBoxes(paintClip, sidebarSelectionBand.clip);
  fillRect(sidebarSelectionBand.x, bandTop,
    sidebarSelectionBand.width, sidebarSelectionBand.height, 2);
  for (const row of sidebarSelectionRows) {
    if (row.box.y >= bandTop + sidebarSelectionBand.height
      || row.box.y + row.box.height <= bandTop) continue;
    const rowClip = intersectBoxes(paintClip, row.clip);
    if (!rowClip) continue;
    paintClip = rowClip;
    row.widget.meta.paint?.(row.box);
    paintClip = intersectBoxes(priorClip, sidebarSelectionBand.clip);
  }
  paintClip = priorClip;
}

function paintSelectionAt(
  y,
  startY = 0,
  endY = HEIGHT,
  time = performance.now(),
  startX = 0,
  endX = WIDTH,
  restoreBase = true,
) {
  if (restoreBase) pixels.set(basePixels);
  paintSelectionBandPixels(y);
  paintSidebarSelectionBandPixels(sidebarSelectionYAt(time));
  paintCheckboxAnimationsAt(time);
  present(startY, endY, startX, endX);
}

function copyFramebufferRegion(destination, source, box) {
  const left = Math.max(0, Math.floor(box.x));
  const right = Math.min(WIDTH, Math.ceil(box.x + box.width));
  const top = Math.max(0, Math.floor(box.y));
  const bottom = Math.min(HEIGHT, Math.ceil(box.y + box.height));
  if (right <= left || bottom <= top) return;
  for (let y = top; y < bottom; y += 1) {
    const start = y * WIDTH + left;
    destination.set(source.subarray(start, y * WIDTH + right), start);
  }
}

function fillFramebufferRegion(destination, shade, box) {
  const left = Math.max(0, Math.floor(box.x));
  const right = Math.min(WIDTH, Math.ceil(box.x + box.width));
  const top = Math.max(0, Math.floor(box.y));
  const bottom = Math.min(HEIGHT, Math.ceil(box.y + box.height));
  if (right <= left || bottom <= top) return;
  for (let y = top; y < bottom; y += 1) {
    destination.fill(shade, y * WIDTH + left, y * WIDTH + right);
  }
}

function paintCheckboxAnimationsAt(time) {
  const boxes = new Map(state.checkboxBoxes.map((entry) => [entry.key, entry.box]));
  for (const [key, animation] of checkboxAnimations) {
    const box = boxes.get(key);
    if (!box) {
      checkboxAnimations.delete(key);
      continue;
    }
    const progress = Math.max(0, Math.min(1, (time - animation.startedAt) / animation.duration));
    if (progress >= 1) {
      checkboxAnimations.delete(key);
      continue;
    }
    const angle = checkboxAngleAt(animation, time);
    const scale = Math.max(1 / box.width, Math.abs(Math.cos(angle)));
    const sampleX = box.x > 0 ? box.x - 1 : Math.min(WIDTH - 1, box.x + box.width);
    for (let y = box.y; y < box.y + box.height; y += 1) {
      const shade = pixels[y * WIDTH + sampleX] ?? 3;
      fillRect(box.x, y, box.width, 1, shade);
    }
    paintCheckboxFace(box, angle >= Math.PI / 2, scale);
  }
}

function animateCheckboxFrame(time) {
  checkboxAnimationFrame = 0;
  if (!checkboxAnimations.size) return;
  if (!animationFrameIsDue(checkboxFrameTiming, time)) {
    checkboxAnimationFrame = requestAnimationFrame(animateCheckboxFrame);
    return;
  }
  const animatedKeys = new Set(checkboxAnimations.keys());
  pixels.set(basePixels);
  paintSelectionBandPixels(selectionYAt(time));
  paintSidebarSelectionBandPixels(sidebarSelectionYAt(time));
  paintCheckboxAnimationsAt(time);
  const paintedKeys = new Set();
  for (const { key, box } of state.checkboxBoxes) {
    if (paintedKeys.has(key) || !animatedKeys.has(key)) continue;
    paintedKeys.add(key);
    present(box.y, box.y + box.height, box.x, box.x + box.width);
  }
  if (checkboxAnimations.size) checkboxAnimationFrame = requestAnimationFrame(animateCheckboxFrame);
}

function animateSelectionFrame(time) {
  selectionAnimationFrame = 0;
  const playlistAnimation = selectionAnimation;
  const treeAnimation = sidebarSelectionAnimation;
  if (!playlistAnimation && !treeAnimation) return;
  const playlistComplete = !playlistAnimation
    || time - playlistAnimation.startedAt >= playlistAnimation.duration;
  const sidebarComplete = !treeAnimation
    || time - treeAnimation.startedAt >= treeAnimation.duration;
  const timing = playlistAnimation || treeAnimation;
  if ((!playlistComplete || !sidebarComplete) && !animationFrameIsDue(timing, time)) {
    selectionAnimationFrame = requestAnimationFrame(animateSelectionFrame);
    return;
  }
  const dirtyBands = [];
  if (playlistAnimation) {
    const y = selectionYAt(time);
    dirtyBands.push({
      x: selectionBand?.x ?? 0,
      right: (selectionBand?.x ?? 0) + (selectionBand?.width ?? WIDTH),
      top: Math.min(playlistAnimation.lastY, y) - 1,
      bottom: Math.max(playlistAnimation.lastY, y) + (selectionBand?.height ?? 0) + 1,
    });
    playlistAnimation.lastY = y;
  }
  if (treeAnimation) {
    const y = sidebarSelectionYAt(time);
    dirtyBands.push({
      x: sidebarSelectionBand?.x ?? 0,
      right: (sidebarSelectionBand?.x ?? 0) + (sidebarSelectionBand?.width ?? WIDTH),
      top: Math.min(treeAnimation.lastY, y) - 1,
      bottom: Math.max(treeAnimation.lastY, y) + (sidebarSelectionBand?.height ?? 0) + 1,
    });
    treeAnimation.lastY = y;
  }
  const dirty = dirtyBands.reduce((bounds, band) => ({
    x: Math.min(bounds.x, band.x),
    right: Math.max(bounds.right, band.right),
    top: Math.min(bounds.top, band.top),
    bottom: Math.max(bounds.bottom, band.bottom),
  }), { x: WIDTH, right: 0, top: HEIGHT, bottom: 0 });
  paintSelectionAt(selectionYAt(time), dirty.top, dirty.bottom, time, dirty.x, dirty.right);
  if (playlistComplete && playlistAnimation) {
    selectionBand.y = playlistAnimation.toY;
    selectionAnimation = null;
  }
  if (sidebarComplete && treeAnimation) {
    sidebarSelectionBand.y = treeAnimation.toY;
    sidebarSelectionAnimation = null;
  }
  if (selectionAnimation || sidebarSelectionAnimation) {
    selectionAnimationFrame = requestAnimationFrame(animateSelectionFrame);
  }
}

function repaintColumnLayoutFrame(time) {
  if (!widgetTree || !state.catalogPaneWidget || !state.tableViewportWidget || !state.tableContentWidget) {
    return false;
  }

  currentRenderTime = time;
  const columns = resolveTableColumns(tableColumns(visibleTracks()), time);
  const currentHeaderKeys = layoutEntries.filter((entry) => entry.widget.meta.columnHeader)
    .map((entry) => entry.widget.meta.columnKey);
  const nextHeaderKeys = columns.map((column) => column.key);
  if (currentHeaderKeys.length !== nextHeaderKeys.length
    || currentHeaderKeys.some((key, index) => key !== nextHeaderKeys[index])) return false;

  const columnsByKey = new Map(columns.map((column) => [column.key, column]));
  const columnCells = layoutEntries.filter((entry) => entry.widget.meta.columnKey);
  if (!columnCells.length || columnCells.some((entry) => !columnsByKey.has(entry.widget.meta.columnKey))) {
    return false;
  }
  columnCells.forEach((entry) => {
    const column = columnsByKey.get(entry.widget.meta.columnKey);
    entry.widget.yoga.setWidth(column.width * STYLE_SCALE);
  });

  const tableGap = Math.max(0, columns.length - 1) * playlistColumnGap();
  state.tableContentMinimumWidth = columns.reduce((sum, column) => sum + column.width, 0) + tableGap;
  const viewportWidth = state.tableViewportWidget.yoga.getComputedLayout().width;
  state.tableContentWidget.yoga.setWidth(Math.max(
    state.tableContentMinimumWidth * STYLE_SCALE,
    viewportWidth,
  ));
  widgetTree.yoga.calculateLayout(WIDTH, HEIGHT, Direction.LTR);

  const viewportLayout = state.tableViewportWidget.yoga.getComputedLayout();
  const contentLayout = state.tableContentWidget.yoga.getComputedLayout();
  state.tableViewportWidth = Math.floor(viewportLayout.width);
  state.tableContentWidth = Math.floor(contentLayout.width);
  state.tableHorizontalMax = Math.max(0, state.tableContentWidth - state.tableViewportWidth);
  state.tableHorizontalScroll = Math.max(0, Math.min(state.tableHorizontalMax, state.tableHorizontalScroll));
  state.tableContentWidget.meta.translateX = -state.tableHorizontalScroll;

  boxesById = new Map();
  hitTargets = [];
  layoutEntries = collect(widgetTree);
  state.tableViewportBox = boxesById.get("catalog-horizontal-viewport") ?? null;
  const paneBox = boxesById.get("catalog-pane");
  if (!paneBox) return false;

  // The scene background is shade 3. Start clean so shrinking/moving glyphs
  // cannot leave trails from the previous animation frame.
  fillFramebufferRegion(pixels, 3, paneBox);
  const previousClip = paintClip;
  paintClip = null;
  paintTree(state.catalogPaneWidget, paneBox, paneBox);
  paintClip = previousClip;
  copyFramebufferRegion(basePixels, pixels, paneBox);

  selectionRows = layoutEntries.filter((entry) => Number.isInteger(entry.widget.meta.trackIndex));
  const selectedTrack = visibleTracks()[state.selectedTrack];
  const selectedRow = selectedTrack && state.selectedTrackIDs.has(trackID(selectedTrack))
    ? selectionRows.find((entry) => entry.widget.meta.trackIndex === state.selectedTrack) : null;
  selectionBand = selectedRow ? {
    ...selectedRow.box,
    kind: "track",
    y: selectedRow.box.y - 1,
    height: selectedRow.box.height + 2,
    ...(selectedRow.clip ? {
      x: selectedRow.clip.x,
      width: selectedRow.clip.width,
      clip: selectedRow.clip,
    } : {}),
  } : null;
  paintClip = paneBox;
  paintSelectionAt(selectionYAt(time), paneBox.y, paneBox.y + paneBox.height,
    time, paneBox.x, paneBox.x + paneBox.width, false);
  paintClip = previousClip;
  columnAnimationTreeReusedFrames += 1;
  return true;
}

function animateColumnLayoutFrame(time) {
  columnAnimationFrame = 0;
  const isDragging = pointerInteraction?.kind === "reorder" && pointerInteraction.dragging;
  if (!columnLayoutAnimation && !tabLayoutAnimation && !reorderAnimation && !isDragging) return;
  const resizeOnlyFrame = Boolean(columnLayoutAnimation
    && !tabLayoutAnimation && !reorderAnimation && !isDragging
    && !spacingAnimation && !state.sidebarTransition && !screenTransition);
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
  // Reuse the Yoga tree and repaint only the catalog pane when column widths
  // are the sole animated property. Other concurrent transitions keep the
  // general renderer so their separate regions remain synchronized.
  const reusedTree = resizeOnlyFrame && repaintColumnLayoutFrame(time);
  if (!reusedTree) render(false, true, time, resizeOnlyFrame ? "playlist" : null);
  if ((columnLayoutAnimation || tabLayoutAnimation || reorderAnimation || isDragging)
    && !columnAnimationFrame) {
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

function render(animateSelection = false, preserveAnimations = false, frameTime = performance.now(), partialPresentation = null) {
  currentRenderTime = frameTime;
  state.checkboxBoxes = [];
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
  const priorSidebarBand = sidebarSelectionBand;
  const priorSidebarY = sidebarSelectionYAt(frameTime);
  const priorSidebarSelectionAnimation = sidebarSelectionAnimation;
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
  state.optionsContentViewportBox = boxesById.get("options-content-viewport") ?? null;
  const partialBox = partialPresentation === "playlist" ? boxesById.get("catalog-pane") : null;
  const presentX = partialBox?.x ?? 0;
  const presentY = partialBox?.y ?? 0;
  const presentEndX = partialBox ? partialBox.x + partialBox.width : WIDTH;
  const presentEndY = partialBox ? partialBox.y + partialBox.height : HEIGHT;
  paintTree(widgetTree, { x: 0, y: 0, width: WIDTH, height: HEIGHT });
  basePixels = pixels.slice();
  const isOptions = state.tab === "SETTINGS";
  selectionRows = isOptions
    ? layoutEntries.filter((entry) => entry.widget.meta.optionPage)
    : layoutEntries.filter((entry) => Number.isInteger(entry.widget.meta.trackIndex));
  sidebarSelectionRows = isOptions ? [] : layoutEntries.filter((entry) =>
    entry.widget.meta.contentRowKind === "sidebar" && entry.widget.meta.sidebarSelectionKey);
  const selectedSidebarRow = sidebarSelectionRows
    .filter((entry) => entry.widget.meta.sidebarSelection)
    .sort((first, second) => second.widget.meta.sidebarSelectionDepth
      - first.widget.meta.sidebarSelectionDepth)[0] || null;
  const nextSidebarBand = selectedSidebarRow ? {
    ...selectedSidebarRow.box,
    kind: "sidebar",
    key: selectedSidebarRow.widget.meta.sidebarSelectionKey,
    mode: state.sidebarMode,
    y: selectedSidebarRow.box.y - 1,
    height: selectedSidebarRow.box.height + 2,
    ...(selectedSidebarRow.clip ? { clip: selectedSidebarRow.clip } : {}),
  } : null;
  const selectedRow = isOptions
    ? selectionRows.find((entry) => entry.widget.meta.controlTitle === state.optionsPage)
    : state.selectedTrackIDs.has(trackID(visibleTracks()[state.selectedTrack]))
      ? selectionRows.find((entry) => entry.widget.meta.trackIndex === state.selectedTrack) : null;
  const optionsSidebar = isOptions
    ? layoutEntries.find((entry) => entry.widget.meta.optionFrame === "toc")?.box
    : null;
  const nextBand = selectedRow ? {
    ...selectedRow.box,
    kind: isOptions ? "options-page" : "track",
    key: isOptions ? `options:${state.optionsPage}`
      : trackID(visibleTracks()[state.selectedTrack]),
    ...(isOptions ? {
      x: selectedRow.box.x + 1,
      y: selectedRow.box.y + 1,
      width: Math.max(0, selectedRow.box.width - 2),
      height: Math.max(0, selectedRow.box.height - 2),
    } : { y: selectedRow.box.y - 1, height: selectedRow.box.height + 2 }),
    ...(optionsSidebar ? { clip: optionsSidebar } : {}),
    ...(selectedRow.clip && !isOptions ? {
      x: selectedRow.clip.x,
      width: selectedRow.clip.width,
      clip: selectedRow.clip,
    } : {}),
  } : null;
  const selectionDuration = animationDurationMilliseconds();
  const canSlide = (animateSelection || nextBand?.kind === "options-page")
    && animationEnabled() && selectionDuration > 0
    && priorBand && nextBand
    && priorBand.kind === nextBand.kind
    && priorBand.key !== nextBand.key
    && priorBand.x === nextBand.x && priorBand.width === nextBand.width
    && priorBand.height === nextBand.height && Math.abs(priorY - nextBand.y) > 0.5;
  const sidebarCanSlide = animationEnabled() && selectionDuration > 0
    && priorSidebarBand && nextSidebarBand
    && priorSidebarBand.key !== nextSidebarBand.key
    && priorSidebarBand.mode === nextSidebarBand.mode
    && priorSidebarBand.x === nextSidebarBand.x
    && priorSidebarBand.width === nextSidebarBand.width
    && priorSidebarBand.height === nextSidebarBand.height
    && Math.abs(priorSidebarY - nextSidebarBand.y) > 0.5;
  const canContinueSelection = priorSelectionAnimation && priorBand && nextBand
    && priorBand.key === nextBand.key
    && priorSelectionAnimation.toY === nextBand.y
    && priorBand.x === nextBand.x && priorBand.width === nextBand.width
    && priorBand.height === nextBand.height;
  const canContinueSidebarSelection = priorSidebarSelectionAnimation
    && priorSidebarBand && nextSidebarBand
    && priorSidebarBand.key === nextSidebarBand.key
    && priorSidebarSelectionAnimation.toY === nextSidebarBand.y
    && priorSidebarBand.x === nextSidebarBand.x
    && priorSidebarBand.width === nextSidebarBand.width
    && priorSidebarBand.height === nextSidebarBand.height;
  selectionBand = nextBand;
  sidebarSelectionBand = nextSidebarBand;
  if (sidebarCanSlide) {
    sidebarSelectionAnimation = {
      key: nextSidebarBand.key,
      fromY: priorSidebarY,
      toY: nextSidebarBand.y,
      startedAt: frameTime,
      duration: selectionDuration,
      lastY: priorSidebarY,
    };
  } else if ((preserveAnimations || canContinueSidebarSelection)
    && priorSidebarSelectionAnimation && nextSidebarBand
    && priorSidebarSelectionAnimation.key === nextSidebarBand.key) {
    sidebarSelectionAnimation = {
      ...priorSidebarSelectionAnimation,
      toY: nextSidebarBand.y,
    };
  } else {
    sidebarSelectionAnimation = null;
  }
  if (canSlide) {
    selectionAnimation = {
      fromY: priorY,
      toY: nextBand.y,
      startedAt: frameTime,
      duration: selectionDuration,
      lastY: priorY,
    };
    paintSelectionAt(priorY, presentY, presentEndY, frameTime, presentX, presentEndX);
  } else if ((preserveAnimations || canContinueSelection)
    && priorSelectionAnimation && nextBand
    && priorBand?.key === nextBand.key
    && priorSelectionAnimation.toY === nextBand.y) {
    selectionAnimation = priorSelectionAnimation;
    paintSelectionAt(selectionYAt(frameTime), presentY, presentEndY, frameTime, presentX, presentEndX);
  } else {
    selectionAnimation = null;
    paintSelectionAt(nextBand?.y ?? null, presentY, presentEndY, frameTime, presentX, presentEndX);
  }
  if ((selectionAnimation || sidebarSelectionAnimation) && !selectionAnimationFrame) {
    selectionAnimationFrame = requestAnimationFrame(animateSelectionFrame);
  }
  const isDragging = pointerInteraction?.kind === "reorder" && pointerInteraction.dragging;
  if ((columnLayoutAnimation || tabLayoutAnimation || reorderAnimation || isDragging)
    && !columnAnimationFrame) {
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
    equalizerAnimationFrame, checkboxAnimationFrame, libraryScrollFrame, spacingAnimationFrame]
    .forEach((frame) => { if (frame) cancelAnimationFrame(frame); });
  selectionAnimationFrame = 0;
  sidebarAnimationFrame = 0;
  columnAnimationFrame = 0;
  equalizerAnimationFrame = 0;
  checkboxAnimationFrame = 0;
  libraryScrollFrame = 0;
  spacingAnimationFrame = 0;
  selectionAnimation = null;
  sidebarSelectionAnimation = null;
  state.sidebarTransition = null;
  columnLayoutAnimation = null;
  tabLayoutAnimation = null;
  reorderAnimation = null;
  reorderPreview = null;
  equalizerAnimations.clear();
  checkboxAnimations.clear();
  spacingAnimation = null;
  pendingLibraryScrollDelta = 0;
  pointerInteraction = null;
}

function navigateAppTab(tab, optionsPage = null) {
  const selectedOptionsPage = optionsPage === "INTERFACE" ? "DISPLAY" : optionsPage;
  const previousTab = state.tab;
  if (previousTab === tab) {
    if (selectedOptionsPage && state.optionsPage !== selectedOptionsPage) {
      state.optionsPage = selectedOptionsPage;
    }
    if (selectedOptionsPage) render();
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
  if (selectedOptionsPage) state.optionsPage = selectedOptionsPage;
  if (tab === "SETTINGS") setSearchFocused(false);

  const duration = animationDurationMilliseconds();
  const shouldAnimate = crossesOptions && animationEnabled() && duration > 0;
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

function setLCDDotSize(value) {
  const size = Number(value);
  if (!LCD_DOT_SIZE_OPTIONS.includes(size) || size === state.lcdDotSize) return;
  cancelScreenLocalAnimations();
  if (screenTransitionFrame) cancelAnimationFrame(screenTransitionFrame);
  screenTransitionFrame = 0;
  screenTransition = null;
  state.lcdDotSize = size;
  DEVICE_PIXELS_PER_LCD_DOT = size;
  saveDisplayOptions();
  fitCanvas();
}

function toggleContrast() {
  setContrastProfile(state.contrast === "STANDARD" ? "HIGH_CONTRAST" : "STANDARD");
}

function setContrastProfile(contrast) {
  state.contrast = contrast === "HIGH_CONTRAST" ? "HIGH_CONTRAST" : "STANDARD";
  updateThemeSurface();
  RGB = paletteRGB(displayPalette());
  packedRGB = packedPalette(RGB);
  saveDisplayOptions();
  render();
}

function setTheme(theme) {
  const normalizedTheme = normalizeThemeName(theme);
  const selectedTheme = COLOR_THEMES.has(normalizedTheme) ? normalizedTheme : "GAMEBOY";
  if (selectedTheme === "CUSTOM" && !state.customColorsInitialized) {
    const endpoints = PALETTE_ENDPOINTS[state.theme]?.[state.contrast]
      || PALETTE_ENDPOINTS.GAMEBOY.STANDARD;
    state.customBackgroundColor = endpoints.surface;
    state.customFontColor = endpoints.ink;
    state.customColorsInitialized = true;
  }
  state.theme = selectedTheme;
  updateThemeSurface();
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
    uiChromeGapDots: DEFAULT_UI_GAP_DOTS,
    textLineGapDots: DEFAULT_TEXT_LINE_GAP_DOTS,
  };
  if (!(key in defaults)) return;
  const now = performance.now();
  const from = Object.fromEntries(Object.keys(defaults)
    .map((spacingKey) => [spacingKey, spacingValue(spacingKey, now)]));
  state[key] = storedSpacing(value, defaults[key]);
  saveDisplayOptions();
  if (spacingAnimationFrame) cancelAnimationFrame(spacingAnimationFrame);
  spacingAnimationFrame = 0;
  const duration = animationDurationMilliseconds();
  const to = Object.fromEntries(Object.keys(defaults).map((spacingKey) =>
    [spacingKey, state[spacingKey]]));
  const changed = Object.keys(defaults).some((spacingKey) => from[spacingKey] !== to[spacingKey]);
  spacingAnimation = changed && animationEnabled() && duration > 0
    ? { from, to, startedAt: now, duration, lastFrameAt: Number.NaN } : null;
  render();
  if (spacingAnimation) spacingAnimationFrame = requestAnimationFrame(animateSpacingFrame);
}

function adjustDisplaySpacing(key, delta) {
  const current = Number(state[key]);
  if (!Number.isFinite(current)) return;
  setDisplaySpacing(key, current + delta);
}

function adjustAnimationTime(delta) {
  setPreference("animationDurationMilliseconds", Math.max(0,
    Math.min(1000, animationDurationMilliseconds() + delta)));
}

function setAnimationFPS(value, persist = true) {
  const requestedFPS = Number(value);
  if (!Number.isFinite(requestedFPS)) return;
  const fps = Math.max(ANIMATION_FPS_MIN,
    Math.min(ANIMATION_FPS_MAX, Math.round(requestedFPS)));
  if (state.animationFPS === fps) return;
  state.animationFPS = fps;
  if (persist) saveDisplayOptions();
  [selectionAnimation, screenTransition, spacingAnimation, columnLayoutAnimation,
    tabLayoutAnimation, reorderAnimation, pointerInteraction, state.sidebarTransition]
    .filter(Boolean).forEach((animation) => { animation.lastFrameAt = Number.NaN; });
  equalizerFrameTiming.lastFrameAt = Number.NaN;
  checkboxFrameTiming.lastFrameAt = Number.NaN;
  libraryScrollFrameTiming.lastFrameAt = Number.NaN;
  render(false, true);
}

async function loadFavorites() {
  if (!bridge?.favoritesList) return;
  try {
    const favorites = await bridge.favoritesList("historical");
    if (!Array.isArray(favorites)) return;
    state.favoriteTracks = favorites;
    state.favoriteIDs = new Set(favorites.map(favoriteID));
    const tab = playlistTabForSource(FAVORITES_TAB_SOURCE);
    if (tab) tab.playlist = [...favorites];
    if (activePlaylistTab()?.sourceKey === FAVORITES_TAB_SOURCE) {
      tracks = [...favorites];
      state.activeQueue = [...favorites];
      state.selectedTrackIDs = new Set(selectionIDsForTab(tab));
      state.selectionAnchorID = tab?.selectionAnchorID || [...state.selectedTrackIDs].at(-1) || null;
    }
    persistPlaylistTabs();
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
      const favoritesTab = playlistTabForSource(FAVORITES_TAB_SOURCE);
      if (favoritesTab) favoritesTab.playlist = [...favorites];
      if (activePlaylistTab()?.sourceKey === FAVORITES_TAB_SOURCE) {
        tracks = [...favorites];
        state.activeQueue = [...favorites];
        state.selectedTrackIDs = new Set(selectionIDsForTab(favoritesTab));
        state.selectionAnchorID = favoritesTab?.selectionAnchorID || [...state.selectedTrackIDs].at(-1) || null;
      }
      state.selectedTrack = Math.min(state.selectedTrack, Math.max(0, favorites.length - 1));
      persistPlaylistTabs();
      render();
    }
  } catch (error) {
    state.status = `FAVORITE ERROR: ${error.message}`;
    render();
  }
}

function openProjectionPlaylist(sourceKey, title, playlist) {
  state.enterSelection = "playlist";
  state.sidebarEnterContext = null;
  const leavingOptions = state.tab === "SETTINGS";
  const priorWidths = leavingOptions ? null : captureTabWidths();
  if (!leavingOptions) syncActivePlaylistTab();
  let tab = playlistTabForSource(sourceKey);
  if (!tab) {
    if (state.playlistTabs.length >= 64) {
      state.status = "PLAYLIST TAB LIMIT REACHED";
      render();
      return false;
    }
    tab = {
      id: playlistTabID(),
      title,
      gameKey: null,
      sourceKey,
      playlist: [...playlist],
      selectedTrack: 0,
      scroll: 0,
    };
    state.playlistTabs.push(tab);
    if (priorWidths) animateTabLayout(priorWidths, [...state.playlistTabs]);
  } else {
    tab.title = title;
    tab.playlist = [...playlist];
  }

  state.activePlaylistTabId = tab.id;
  tracks = [...tab.playlist];
  state.activeQueue = [...tab.playlist];
  state.activeGameKey = null;
  state.selectedGameKey = null;
  tab.selectedTrack = 0;
  const autoSelectFirst = sourceKey !== FAVORITES_TAB_SOURCE;
  tab.selectedTrackIDs = autoSelectFirst && playlist[0] ? [trackID(playlist[0])] : [];
  tab.selectionAnchorID = tab.selectedTrackIDs[0] || null;
  tab.scroll = 0;
  if (autoSelectFirst) resetPlaylistSelection(tab.playlist, tab);
  else {
    state.selectedTrack = 0;
    state.selectedTrackIDs = new Set();
    state.selectionAnchorID = null;
  }
  state.queueScroll = 0;
  state.tableHorizontalScroll = 0;
  if (sourceKey === HISTORY_TAB_SOURCE) {
    state.sortColumn = "timestamp";
    state.sortDirection = "DESCENDING";
  } else if (state.sortColumn === "timestamp") {
    state.sortColumn = null;
    state.sortDirection = "ASCENDING";
  }
  state.status = `${tab.playlist.length} ${title} TRACKS`;
  if (leavingOptions) navigateAppTab("QUEUE");
  else {
    state.tab = "QUEUE";
    render();
  }
  persistPlaylistTabs();
  return true;
}

async function showFavoritesPlaylist() {
  if (!bridge?.favoritesList) return;
  try {
    const favorites = await bridge.favoritesList("historical");
    if (!Array.isArray(favorites)) return;
    state.favoriteTracks = favorites;
    state.favoriteIDs = new Set(favorites.map(favoriteID));
    openProjectionPlaylist(FAVORITES_TAB_SOURCE, "FAVORITES", favorites);
  } catch (error) {
    state.status = `FAVORITES ERROR: ${error.message}`;
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
    openProjectionPlaylist(HISTORY_TAB_SOURCE, "HISTORY", state.historyTracks);
  } catch (error) {
    state.status = `HISTORY ERROR: ${error.message}`;
    render();
  }
}

function selectSidebarView(view) {
  if (view === "FAVORITES") {
    state.enterSelection = "playlist";
    state.sidebarEnterContext = null;
    void showFavoritesPlaylist();
    return;
  }
  if (view === "HISTORY") {
    state.enterSelection = "playlist";
    state.sidebarEnterContext = null;
    void showPlaybackHistory();
    return;
  }
  if (view === "QUEUE") {
    state.enterSelection = "playlist";
    state.sidebarEnterContext = null;
  }
  const leavingOptions = state.tab === "SETTINGS";
  if (view === "QUEUE") {
    const currentQueue = state.currentTrackId && state.playbackQueue.length
      ? state.playbackQueue : state.activeQueue;
    const queue = currentQueue.length
      ? [...currentQueue] : [...(activePlaylistTab()?.playlist || tracks)];
    let tab = state.playlistTabs.find((entry) => ![FAVORITES_TAB_SOURCE, HISTORY_TAB_SOURCE]
      .includes(entry.sourceKey) && samePlaylist(entry.playlist, queue));
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
  resetPlaylistSelection(activePlaylistTab()?.playlist || [], activePlaylistTab());
  state.queueScroll = 0;
  if (leavingOptions) navigateAppTab(view);
  else {
    state.tab = view;
    render();
  }
  if (view === "QUEUE") persistPlaylistTabs();
}

async function loadDatabaseFiles() {
  if (!bridge?.databaseFileTree) return false;
  state.databaseFilesLoading = true;
  render();
  try {
    const tree = await bridge.databaseFileTree();
    if (tree?.stale) return false;
    state.databaseFiles = Array.isArray(tree) ? tree : [];
    state.databaseFileFolders = pathFolderNodes();
    state.databaseFilesReady = true;
    if (!state.pathExpansionInitialized) {
      state.databaseFiles.forEach((node) => {
        if (node.kind === "folder" && node.path) state.expandedPathNodes.add(node.path);
      });
      state.pathExpansionInitialized = true;
    }
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

function activeSidebarTransitionEntries(kind) {
  const active = state.sidebarTransition?.[kind];
  if (!(active instanceof Map)) return new Map();
  return new Map([...active].map(([key, entry]) => [key, {
    fromProgress: entry.progress,
    toProgress: entry.toProgress,
    progress: entry.progress,
  }]));
}

function startSidebarDisclosureTransition(kind, entries) {
  if (sidebarAnimationFrame) cancelAnimationFrame(sidebarAnimationFrame);
  sidebarAnimationFrame = 0;
  const active = new Map([...entries].filter(([, entry]) =>
    Math.abs(entry.toProgress - entry.fromProgress) > 0.0001));
  const distance = Math.max(0, ...[...active.values()].map((entry) =>
    Math.abs(entry.toProgress - entry.fromProgress)));
  const duration = animationDurationMilliseconds() * distance;
  if (!active.size || !animationEnabled() || duration <= 0) {
    state.sidebarTransition = null;
    render();
    return;
  }
  state.sidebarTransition = {
    [kind]: active,
    progress: 0,
    startedAt: performance.now(),
    duration,
  };
  render();
  sidebarAnimationFrame = requestAnimationFrame(animateSidebarFrame);
}

function transitionProgress(kind, key, fallback) {
  return state.sidebarTransition?.[kind]?.get(key)?.progress ?? Number(fallback);
}

function togglePathNode(node) {
  if (!node?.path || !node.children?.length) return;
  const expanded = state.expandedPathNodes.has(node.path);
  const currentProgress = transitionProgress("paths", node.path, expanded);
  const targetProgress = expanded ? 0 : 1;
  if (expanded) state.expandedPathNodes.delete(node.path);
  else state.expandedPathNodes.add(node.path);
  state.pathExpansionInitialized = true;
  saveDisplayOptions();
  const entries = activeSidebarTransitionEntries("paths");
  entries.set(node.path, {
    fromProgress: currentProgress,
    toProgress: targetProgress,
    progress: currentProgress,
  });
  startSidebarDisclosureTransition("paths", entries);
}

function setAllPathFoldersExpanded(expanded) {
  const folders = state.databaseFileFolders;
  if (!folders.length) return;
  const entries = activeSidebarTransitionEntries("paths");
  const targetProgress = Number(expanded);
  for (const node of folders) {
    const wasExpanded = state.expandedPathNodes.has(node.path);
    const currentProgress = transitionProgress("paths", node.path, wasExpanded);
    if (expanded) state.expandedPathNodes.add(node.path);
    else state.expandedPathNodes.delete(node.path);
    entries.set(node.path, {
      fromProgress: currentProgress,
      toProgress: targetProgress,
      progress: currentProgress,
    });
  }
  state.pathExpansionInitialized = true;
  saveDisplayOptions();
  startSidebarDisclosureTransition("paths", entries);
}

function toggleAllSidebarGroups() {
  if (state.sidebarMode === "paths") {
    const folders = pathFolderNodes();
    const allExpanded = folders.length > 0
      && folders.every((node) => state.expandedPathNodes.has(node.path));
    setAllPathFoldersExpanded(!allExpanded);
    return;
  }
  const systems = consoleSystemNames();
  const allExpanded = systems.length > 0
    && systems.every((system) => state.expandedSystems.has(system));
  void setAllSystemsExpanded(!allExpanded, systems);
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
      const priorWidths = state.tab === "SETTINGS" ? null : captureTabWidths();
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
      tab.selectedTrackIDs = tracks[0] ? [trackID(tracks[0])] : [];
      tab.selectionAnchorID = tracks[0] ? trackID(tracks[0]) : null;
      tab.scroll = 0;
      state.activePlaylistTabId = tab.id;
      state.activeGameKey = null;
    }
    state.selectedGameKey = null;
    resetPlaylistSelection(tracks, tab);
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

async function tracksForSidebarContext(context) {
  if (!context || !bridge) return [];
  let rows = [];
  if (context.kind === "game" && bridge.databaseGameTracks) {
    rows = await bridge.databaseGameTracks([context.game]);
  } else if (context.kind === "system" && bridge.databaseGameTracks) {
    const games = state.games.filter((game) => (game.system || "OTHER") === context.system);
    rows = await bridge.databaseGameTracks(games);
  } else if (context.kind === "path") {
    const node = context.node;
    if (node?.catalogFile && bridge.databaseFileTracks) {
      rows = await bridge.databaseFileTracks([node.catalogFile]);
    } else if (node?.catalogFolder && bridge.databaseFolderTracks) {
      rows = await bridge.databaseFolderTracks([node.catalogFolder]);
    }
  }
  return rows?.stale ? [] : Array.isArray(rows) ? rows : [];
}

function replaceActivePlaylistForSidebar(playlist, title) {
  const tab = activePlaylistTab();
  if (!tab) return null;
  state.enterSelection = "playlist";
  state.sidebarEnterContext = null;
  tab.playlist = [...playlist];
  tab.title = title || tab.title || "PLAYLIST";
  tab.gameKey = null;
  tab.sourceKey = null;
  tab.selectedTrack = 0;
  tab.selectedTrackIDs = playlist[0] ? [trackID(playlist[0])] : [];
  tab.selectionAnchorID = playlist[0] ? trackID(playlist[0]) : null;
  tracks = [...tab.playlist];
  state.activeQueue = [...tab.playlist];
  state.activeGameKey = null;
  state.selectedGameKey = null;
  state.selectedTrack = 0;
  state.selectedTrackIDs = new Set(tab.selectedTrackIDs);
  state.selectionAnchorID = tab.selectionAnchorID;
  state.queueScroll = 0;
  state.tableHorizontalScroll = 0;
  persistPlaylistTabs();
  render(true);
  return tab.playlist;
}

function enqueueSidebarTracks(additions, title) {
  const tab = activePlaylistTab();
  if (!tab || !additions.length) return [];
  state.enterSelection = "playlist";
  state.sidebarEnterContext = null;
  const current = [...tab.playlist];
  const existing = new Set(current.map(trackID));
  const unique = additions.filter((track) => !existing.has(trackID(track)));
  if (!unique.length) return [];
  tab.playlist = [...current, ...unique];
  tab.sourceKey = null;
  tab.gameKey = null;
  if (!current.length && title) tab.title = title;
  tracks = [...tab.playlist];
  if (state.playbackPlaylistTabId === tab.id && state.currentTrackId) {
    state.playbackQueue = [...state.playbackQueue, ...unique];
    state.activeQueue = [...state.playbackQueue];
  } else {
    state.activeQueue = [...tab.playlist];
  }
  const firstAddedID = trackID(unique[0]);
  const shown = visibleTracks();
  const firstAddedIndex = shown.findIndex((track) => trackID(track) === firstAddedID);
  tab.selectedTrack = Math.max(0, firstAddedIndex);
  tab.selectedTrackIDs = [firstAddedID];
  tab.selectionAnchorID = firstAddedID;
  state.selectedTrack = tab.selectedTrack;
  state.selectedTrackIDs = new Set(tab.selectedTrackIDs);
  state.selectionAnchorID = firstAddedID;
  state.queueScroll = Math.max(0, Math.min(state.queueScroll,
    Math.max(0, shown.length - visibleRowCount())));
  if (state.selectedTrack < state.queueScroll) state.queueScroll = state.selectedTrack;
  if (state.selectedTrack >= state.queueScroll + visibleRowCount()) {
    state.queueScroll = state.selectedTrack - visibleRowCount() + 1;
  }
  persistPlaylistTabs();
  render(true);
  return unique;
}

async function playNowSidebarContext(context) {
  const playlist = await tracksForSidebarContext(context);
  if (!playlist.length) return;
  const title = context.kind === "game" ? context.game.displayName || context.game.name
    : context.kind === "system" ? context.system
      : context.node?.name || "PATH";
  const queue = replaceActivePlaylistForSidebar(playlist, title);
  if (queue?.length) await startTrack(queue[0], queue);
}

async function enqueueSidebarContext(context) {
  const additions = await tracksForSidebarContext(context);
  if (!additions.length) return;
  const title = context.kind === "game" ? context.game.displayName || context.game.name
    : context.kind === "system" ? context.system
      : context.node?.name || "PATH";
  enqueueSidebarTracks(additions, title);
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
  const frameProgress = Math.max(0, Math.min(1,
    (time - transition.startedAt) / transition.duration));
  const easedProgress = easeSelection(frameProgress);
  transition.progress = frameProgress;
  for (const kind of ["paths", "systems"]) {
    for (const entry of transition[kind]?.values() || []) {
      entry.progress = entry.fromProgress
        + (entry.toProgress - entry.fromProgress) * easedProgress;
    }
  }
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
  const currentProgress = transitionProgress("systems", system, wasExpanded);
  const targetProgress = wasExpanded ? 0 : 1;
  try {
    if (await reduceDatabaseGroupState("toggle", system)) {
      const entries = activeSidebarTransitionEntries("systems");
      entries.set(system, {
        fromProgress: currentProgress,
        toProgress: targetProgress,
        progress: currentProgress,
      });
      startSidebarDisclosureTransition("systems", entries);
    }
  } catch (error) {
    state.status = `SIDEBAR ERROR: ${error.message}`;
    render();
  }
}

async function setAllSystemsExpanded(expanded, systems) {
  if (!systems.length || !bridge?.databaseGroupState) return;
  const previous = new Set(state.expandedSystems);
  const entries = activeSidebarTransitionEntries("systems");
  const token = ++state.groupTransitionToken;
  try {
    const next = await bridge.databaseGroupState({
      expandedGroupNames: [...state.expandedSystems],
      selectedGroupName: state.selectedSystem,
      selectedGameID: state.selectedGameKey,
      collapsed: !expanded,
      knownGroupNames: systems,
    }, "allCollapsed");
    if (token !== state.groupTransitionToken || !next) return;
    state.expandedSystems = new Set(Array.isArray(next.expandedGroupNames)
      ? next.expandedGroupNames : []);
    state.selectedSystem = next.selectedGroupName || null;
    state.selectedGameKey = next.selectedGameID || null;
    const targetProgress = Number(expanded);
    for (const system of systems) {
      const currentProgress = entries.get(system)?.progress ?? Number(previous.has(system));
      entries.set(system, {
        fromProgress: currentProgress,
        toProgress: targetProgress,
        progress: currentProgress,
      });
    }
    startSidebarDisclosureTransition("systems", entries);
  } catch (error) {
    state.status = `SIDEBAR ERROR: ${error.message}`;
    render();
  }
}

async function loadCatalog() {
  if (!bridge?.databaseGames) {
    state.status = "NATIVE BRIDGE UNAVAILABLE";
    state.catalogLoading = false;
    render();
    return;
  }
  state.status = "LOADING CATALOG";
  state.catalogLoading = true;
  const token = ++state.catalogToken;
  render();
  try {
    const games = await bridge.databaseGames();
    if (token !== state.catalogToken) return;
    if (games?.stale) {
      state.catalogLoading = false;
      render();
      return;
    }
    state.games = Array.isArray(games) ? games : [];
    state.games.sort((a, b) => (a.system || "").localeCompare(b.system || "")
      || (a.displayName || a.name || "").localeCompare(b.displayName || b.name || ""));
    state.consoleSystems = [...new Set(state.games.map((game) => game.system || "OTHER"))].sort();
    state.status = state.games.length ? "READY" : "CATALOG EMPTY";
    state.catalogLoading = false;
    render();
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
    state.catalogLoading = false;
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
        selectedTrackIDs: [],
        selectionAnchorID: null,
        scroll: 0,
      };
      state.playlistTabs.push(tab);
    }
    if (tab) {
      tab.title = game.displayName || game.name || tab.title;
      tab.playlist = [...tracks];
      tab.selectedTrack = 0;
      tab.selectedTrackIDs = tracks[0] ? [trackID(tracks[0])] : [];
      tab.selectionAnchorID = tracks[0] ? trackID(tracks[0]) : null;
      tab.scroll = 0;
      state.activePlaylistTabId = tab.id;
    }
    resetPlaylistSelection(tracks, tab);
    if (!state.currentTrackId) state.activeQueue = [...tracks];
    if (state.tab !== "SETTINGS") state.tab = "LIBRARY";
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
  state.nativePlaybackStatus = { ...snapshot };
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
  state.playbackPlaylistTabId = state.activePlaylistTabId;
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
    state.playbackPlaylistTabId = null;
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
    } else if (selected && state.selectedTrackIDs.has(trackID(selected))) {
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
    state.playbackPlaylistTabId = null;
    state.playbackGeneration = 0;
    state.playbackQueue = [];
    state.status = "STOPPED";
    render();
  } catch (error) {
    state.status = `STOP ERROR: ${error.message}`;
    render();
  }
}

function selectTrack(index, wrap = true, modifiers = {}) {
  state.enterSelection = "playlist";
  state.sidebarEnterContext = null;
  const shownTracks = visibleTracks();
  if (!shownTracks.length) return;
  const previousIndex = state.selectedTrack;
  const previousAnchorID = state.selectionAnchorID;
  const nextIndex = wrap ? (index + shownTracks.length) % shownTracks.length
    : Math.max(0, Math.min(shownTracks.length - 1, index));
  const targetID = trackID(shownTracks[nextIndex]);
  let nextIDs;
  let primaryID = targetID;
  let nextAnchorID = targetID;
  if (modifiers.range) {
    const anchorIndex = shownTracks.findIndex((track) => trackID(track) === state.selectionAnchorID);
    const start = Math.min(anchorIndex < 0 ? nextIndex : anchorIndex, nextIndex);
    const end = Math.max(anchorIndex < 0 ? nextIndex : anchorIndex, nextIndex);
    nextIDs = shownTracks.slice(start, end + 1).map(trackID);
    nextAnchorID = !state.selectionAnchorID || anchorIndex < 0 ? targetID : state.selectionAnchorID;
  } else if (modifiers.extend) {
    nextIDs = [...state.selectedTrackIDs];
    if (nextIDs.includes(targetID)) nextIDs = nextIDs.filter((id) => id !== targetID);
    else nextIDs.push(targetID);
    primaryID = nextIDs.includes(targetID) ? targetID : nextIDs.at(-1) || null;
    nextAnchorID = targetID;
  } else {
    nextIDs = [targetID];
    nextAnchorID = targetID;
  }
  state.selectedTrack = nextIndex;
  state.selectedTrackIDs = new Set(nextIDs);
  state.selectionAnchorID = nextAnchorID;
  if (primaryID) {
    const primaryIndex = shownTracks.findIndex((track) => trackID(track) === primaryID);
    if (primaryIndex >= 0) state.selectedTrack = primaryIndex;
  }
  const unchanged = previousIndex === state.selectedTrack
    && previousAnchorID === state.selectionAnchorID
    && nextIDs.length === state.selectedTrackIDs.size
    && nextIDs.every((id) => state.selectedTrackIDs.has(id));
  if (unchanged) return;
  const tab = activePlaylistTab();
  if (tab) {
    tab.selectedTrack = state.selectedTrack;
    tab.selectedTrackIDs = [...state.selectedTrackIDs];
    tab.selectionAnchorID = state.selectionAnchorID;
  }
  if (state.selectedTrack < state.queueScroll) state.queueScroll = state.selectedTrack;
  if (state.selectedTrack >= state.queueScroll + visibleRowCount()) {
    state.queueScroll = state.selectedTrack - visibleRowCount() + 1;
  }
  if (primaryID) announce(`Selected ${shownTracks[state.selectedTrack].title || shownTracks[state.selectedTrack].filename}`);
  persistPlaylistTabs();
  render(true);
}

function clearPlaylistSelection() {
  state.enterSelection = "playlist";
  state.sidebarEnterContext = null;
  state.selectedTrackIDs = new Set();
  state.selectionAnchorID = null;
  const tab = activePlaylistTab();
  if (tab) {
    tab.selectedTrackIDs = [];
    tab.selectionAnchorID = null;
  }
  persistPlaylistTabs();
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
  let changes = { [key]: value };
  if (key === "animationDurationMilliseconds") {
    changes = {
      autoResizeAnimationMilliseconds: value,
      selectionAnimationMilliseconds: value,
    };
  } else if (key === "animationsEnabled") {
    changes = {
      autoResizeAnimationEnabled: value,
      selectionAnimationEnabled: value,
    };
  }
  state.preferences = { ...prior, ...changes };
  if (key === "animationsEnabled" && value === false) {
    checkboxAnimations.clear();
    if (checkboxAnimationFrame) cancelAnimationFrame(checkboxAnimationFrame);
    checkboxAnimationFrame = 0;
  }
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
  const viewport = state.tableViewportBox;
  if (!viewport || point.x < viewport.x || point.x >= viewport.x + viewport.width
    || point.y < viewport.y || point.y >= viewport.y + viewport.height) return null;
  const rows = hitTargets.filter(({ widget, clip }) => widget.meta.playlistRow
    && predicate(widget)
    && (!clip || (point.x >= clip.x && point.x < clip.x + clip.width
      && point.y >= clip.y && point.y < clip.y + clip.height)))
    .sort((first, second) => first.box.y - second.box.y);
  for (let index = 0; index < rows.length - 1; index += 1) {
    const previous = rows[index];
    const next = rows[index + 1];
    const gapStart = previous.box.y + previous.box.height;
    const gapEnd = next.box.y;
    if (point.y < gapStart || point.y >= gapEnd) continue;
    const pointCenter = point.y + 0.5;
    const previousDistance = pointCenter - gapStart;
    const nextDistance = gapEnd - pointCenter;
    return previousDistance <= nextDistance ? previous : next;
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

function findReorderTarget(point, kind, sourceKey) {
  for (let index = hitTargets.length - 1; index >= 0; index -= 1) {
    const entry = hitTargets[index];
    const widget = entry.widget;
    const targetKey = kind === "column" ? widget.meta.columnKey : widget.meta.reorderKey;
    const targetable = kind === "column"
      ? widget.meta.columnHeader && widget.meta.reorderable
      : widget.meta.reorderContainer;
    if (!targetable || widget.meta.reorderKind !== kind || targetKey === sourceKey) continue;
    const { box, clip } = entry;
    if (clip && (point.x < clip.x || point.x >= clip.x + clip.width
      || point.y < clip.y || point.y >= clip.y + clip.height)) continue;
    if (point.x >= box.x && point.x < box.x + box.width
      && point.y >= box.y && point.y < box.y + box.height) return entry;
  }
  return null;
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

function orderWithDraggedItem(keys, sourceKey, targetKey, targetBox, pointerX, dragDirection) {
  if (!sourceKey || !targetKey || sourceKey === targetKey) return keys;
  const next = [...keys];
  const sourceIndex = next.indexOf(sourceKey);
  const targetIndex = next.indexOf(targetKey);
  if (sourceIndex < 0 || targetIndex < 0) return keys;
  next.splice(sourceIndex, 1);
  const threshold = Math.min(REORDER_ENTRY_THRESHOLD_DOTS, Math.max(1, targetBox.width * 0.05));
  const insertAfter = dragDirection > 0
    ? pointerX >= targetBox.x + threshold
    : dragDirection < 0
      ? pointerX >= targetBox.x + targetBox.width - threshold
      : pointerX >= targetBox.x + targetBox.width / 2;
  let insertionIndex = targetIndex + (insertAfter ? 1 : 0);
  if (sourceIndex < insertionIndex) insertionIndex -= 1;
  next.splice(Math.max(0, Math.min(next.length, insertionIndex)), 0, sourceKey);
  return next;
}

function sameOrder(first, second) {
  return first.length === second.length && first.every((key, index) => key === second[index]);
}

function setReorderAnimation(kind, fromX, time) {
  const duration = animationDurationMilliseconds();
  reorderAnimation = animationEnabled() && duration > 0
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
  if (target?.meta.animationFPSControl && (event.button ?? 0) === 0) {
    state.animationFPSFocused = true;
    pointerInteraction = {
      kind: "animation-fps",
      pointerId: event.pointerId,
      box: { ...entry.box },
      initialFPS: state.animationFPS,
    };
    canvas.setPointerCapture?.(event.pointerId);
    suppressNextClick = true;
    setAnimationFPSFromPointer(point.x, entry.box);
    render(false, true);
    event.preventDefault?.();
  } else if (target?.meta.horizontalScrollbar) {
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
      startX: point.x,
      startY: point.y,
      lastPointX: point.x,
      pointX: point.x,
      dragDirection: 0,
      dragging: false,
    };
    canvas.setPointerCapture?.(event.pointerId);
  }
});

canvas.addEventListener("pointermove", (event) => {
  const point = logicalPoint(event);
  if (pointerInteraction?.kind === "animation-fps") {
    setAnimationFPSFromPointer(point.x, pointerInteraction.box);
    return;
  }
  if (pointerInteraction?.kind === "scrollbar") {
    if (Math.abs(point.x - pointerInteraction.startX) >= 1) suppressNextClick = true;
    pointerInteraction.startX = point.x;
    setHorizontalScrollFromThumb(point.x, pointerInteraction.thumbOffset);
    return;
  }
  if (pointerInteraction?.kind === "reorder") {
    const distance = Math.hypot(point.x - pointerInteraction.startX, point.y - pointerInteraction.startY);
    const horizontalDelta = point.x - pointerInteraction.pointX;
    if (horizontalDelta !== 0) pointerInteraction.dragDirection = Math.sign(horizontalDelta);
    pointerInteraction.lastPointX = point.x;
    pointerInteraction.pointX = point.x;
    if (distance >= 1) {
      pointerInteraction.dragging = true;
      suppressNextClick = true;
      const dropTarget = findReorderTarget(
        point, pointerInteraction.itemKind, pointerInteraction.sourceKey,
      );
      if (dropTarget) {
        const targetKey = pointerInteraction.itemKind === "column"
          ? dropTarget.widget.meta.columnKey : dropTarget.widget.meta.reorderKey;
        const nextOrder = orderWithDraggedItem(
          currentReorderOrder(pointerInteraction.itemKind),
          pointerInteraction.sourceKey,
          targetKey,
          dropTarget.box,
          point.x,
          pointerInteraction.dragDirection,
        );
        if (!sameOrder(nextOrder, currentReorderOrder(pointerInteraction.itemKind))) {
          const fromX = captureReorderPositions(pointerInteraction.itemKind);
          reorderPreview = { kind: pointerInteraction.itemKind, keys: nextOrder };
          setReorderAnimation(pointerInteraction.itemKind, fromX, performance.now());
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
  if (interaction.kind === "animation-fps") {
    setAnimationFPSFromPointer(logicalPoint(event).x, interaction.box);
    pointerInteraction = null;
    if (state.animationFPS !== interaction.initialFPS) saveDisplayOptions();
  } else if (interaction.kind === "reorder") {
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
  if (pointerInteraction?.kind === "animation-fps") {
    const initialFPS = pointerInteraction.initialFPS;
    pointerInteraction = null;
    suppressNextClick = false;
    state.animationFPSFocused = false;
    setAnimationFPS(initialFPS, false);
    render(false, true);
  } else if (pointerInteraction?.kind === "reorder" && pointerInteraction.dragging) {
    finishReorderInteraction(pointerInteraction, false);
  } else {
    pointerInteraction = null;
  }
});

canvas.addEventListener("contextmenu", (event) => {
  const point = logicalPoint(event);
  const header = findTargetEntry(point, (widget) => widget.meta.columnHeader);
  if (header) {
    event.preventDefault();
    state.columnMenu = { kind: "columns", x: point.x, y: point.y };
    render();
    return;
  }
  const sidebarRow = findTargetEntry(point, (widget) => Boolean(widget.meta.sidebarContext));
  const context = sidebarRow?.widget.meta.sidebarContext;
  if (!context) return;
  event.preventDefault();
  state.enterSelection = "sidebar";
  state.sidebarEnterContext = context;
  if (context.kind === "path") state.selectedPathKey = context.node.path;
  else if (context.kind === "game") state.selectedGameKey = gameKey(context.game);
  else if (context.kind === "system") state.selectedSystem = context.system;
  state.columnMenu = {
    kind: "sidebar",
    x: point.x,
    y: point.y,
    items: [
      { title: "PLAY NOW", action: () => playNowSidebarContext(context) },
      { title: "ENQUEUE", action: () => enqueueSidebarContext(context) },
    ],
  };
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
  state.animationFPSFocused = target?.meta.animationFPSControl === true;
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
  else if (state.tab !== "SETTINGS") {
    const point = logicalPoint(event);
    const viewport = state.tableViewportBox;
    const insidePlaylist = viewport && point.x >= viewport.x && point.x < viewport.x + viewport.width
      && point.y >= viewport.y && point.y < viewport.y + viewport.height;
    if (insidePlaylist && !Number.isInteger(target?.meta.trackIndex)
        && state.selectedTrackIDs.size) clearPlaylistSelection();
  }
});

canvas.addEventListener("wheel", (event) => {
  const point = logicalPoint(event);
  if (state.tab === "SETTINGS") {
    const viewport = state.optionsContentViewportBox;
    const withinOptions = viewport && point.x >= viewport.x && point.x < viewport.x + viewport.width
      && point.y >= viewport.y && point.y < viewport.y + viewport.height;
    if (!withinOptions || state.optionsScrollMaximum <= 0) return;
    event.preventDefault();
    const rect = canvas.getBoundingClientRect();
    const cssDelta = event.deltaMode === 1 ? event.deltaY * 16
      : event.deltaMode === 2 ? event.deltaY * rect.height : event.deltaY;
    const dotDelta = cssDelta * HEIGHT / Math.max(1, rect.height);
    state.optionsScrollOffset = Math.max(0,
      Math.min(state.optionsScrollMaximum, state.optionsScrollOffset + dotDelta));
    render();
    return;
  }
  event.preventDefault();
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
  const sidebarWidth = libraryPaneWidth() * STYLE_SCALE;
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
  if (state.editingColorEndpoint) {
    if (event.key === "Escape") finishColorEdit(false);
    else if (event.key === "Enter" || event.key === "Tab") finishColorEdit(true);
    else if (event.key === "Backspace") {
      state.colorDraft = Array.from(state.colorDraft).slice(0, -1).join("");
      render();
    } else if (!commandKey && !event.altKey && event.key.length === 1
      && state.colorDraft.length < 96) {
      state.colorDraft += event.key;
      render();
    } else return;
    event.preventDefault();
    return;
  }
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
  if (state.editingRateBackend) {
    if (event.key === "Escape") finishPlaybackRateEdit(false);
    else if (event.key === "Enter" || event.key === "Tab") finishPlaybackRateEdit(true);
    else if (event.key === "Backspace") {
      state.rateDraft = Array.from(state.rateDraft).slice(0, -1).join("");
      render();
    } else if (/^[0-9/.]$/.test(event.key)) {
      state.rateDraft += event.key;
      render();
    } else return;
    event.preventDefault();
    return;
  }
  if (state.animationFPSFocused && !commandKey && !event.altKey) {
    let nextFPS = null;
    if (event.code === "ArrowLeft" || event.code === "ArrowDown") {
      nextFPS = state.animationFPS - (event.shiftKey ? 10 : 1);
    } else if (event.code === "ArrowRight" || event.code === "ArrowUp") {
      nextFPS = state.animationFPS + (event.shiftKey ? 10 : 1);
    } else if (event.code === "Home") {
      nextFPS = ANIMATION_FPS_MIN;
    } else if (event.code === "End") {
      nextFPS = ANIMATION_FPS_MAX;
    } else if (event.code === "Escape") {
      state.animationFPSFocused = false;
      render(false, true);
      event.preventDefault();
      return;
    }
    if (nextFPS !== null) {
      event.preventDefault();
      setAnimationFPS(nextFPS);
      return;
    }
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
  } else if (commandKey && !event.shiftKey && !event.altKey && /^[1-9]$/.test(event.key)) {
    event.preventDefault();
    const tab = state.playlistTabs[Number(event.key) - 1];
    if (tab) activatePlaylistTab(tab.id);
  } else if (commandKey && !event.shiftKey && !event.altKey && event.key.toLowerCase() === "d") {
    event.preventDefault();
    const selected = visibleTracks()[state.selectedTrack];
    if (selected && state.selectedTrackIDs.has(trackID(selected))) void toggleFavorite(selected);
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
  } else if (commandKey && !event.shiftKey && !event.altKey
      && event.key.toLowerCase() === "a" && state.tab !== "SETTINGS" && !state.searchFocused) {
    event.preventDefault();
    state.enterSelection = "playlist";
    state.sidebarEnterContext = null;
    const shown = visibleTracks();
    const ids = shown.map(trackID);
    setPlaylistSelection(ids, ids[0] || null, ids.at(-1) || null);
    if (shown.length) {
      state.selectedTrack = shown.length - 1;
      state.queueScroll = Math.max(0, Math.min(state.queueScroll,
        Math.max(0, shown.length - visibleRowCount())));
      if (state.selectedTrack >= state.queueScroll + visibleRowCount()) {
        state.queueScroll = state.selectedTrack - visibleRowCount() + 1;
      }
    }
    persistPlaylistTabs();
    render(true);
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
  } else if (event.code === "Escape" && state.selectedTrackIDs.size) {
    event.preventDefault();
    clearPlaylistSelection();
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
    selectTrack(state.selectedTrack + 1, false, { range: event.shiftKey });
  } else if (event.code === "ArrowUp") {
    event.preventDefault();
    selectTrack(state.selectedTrack - 1, false, { range: event.shiftKey });
  } else if (event.code === "Enter") {
    event.preventDefault();
    if (state.enterSelection === "sidebar" && state.sidebarEnterContext) {
      void playNowSidebarContext(state.sidebarEnterContext);
    } else {
      const selected = visibleTracks()[state.selectedTrack];
      if (selected && state.selectedTrackIDs.has(trackID(selected))) startTrack(selected);
    }
  } else if (event.code === "PageDown" || event.code === "PageUp") {
    event.preventDefault();
    selectTrack(state.selectedTrack + (event.code === "PageDown" ? 1 : -1) * visibleRowCount(), false,
      { range: event.shiftKey });
  }
});

function fitCanvas() {
  const screenRect = screenWindow?.getBoundingClientRect();
  if (screenWindow && (!screenRect || screenRect.width <= 0 || screenRect.height <= 0)) return;
  const availableWidth = Math.max(1, screenRect?.width || window.innerWidth);
  const availableHeight = Math.max(1, screenRect?.height || window.innerHeight);
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
      case "sidebarPaths": void setSidebarMode("paths"); break;
      case "sidebarConsoles": void setSidebarMode("consoles"); break;
      case "sidebarDiskPath": openLocalPath(); break;
      case "favoritesPlaylist": selectSidebarView("FAVORITES"); break;
      case "playbackHistory": void showPlaybackHistory(); break;
      case "library": selectSidebarView("LIBRARY"); break;
      case "queue": selectSidebarView("QUEUE"); break;
      case "optionsPage:DISPLAY": openOptionsScreen("DISPLAY"); break;
      case "optionsPage:THEME": openOptionsScreen("DISPLAY"); break;
      case "optionsPage:TRANSPORT": openOptionsScreen("DISPLAY"); break;
      case "optionsPage:PLAYBACK": openOptionsScreen("PLAYBACK"); break;
      case "optionsPage:METHODS": openOptionsScreen("METHODS"); break;
      case "optionsPage:AUDIO": openOptionsScreen("AUDIO"); break;
      case "optionsPage:DIAGNOSTICS": openOptionsScreen("DIAGNOSTICS"); break;
      case "optionsPage:QUEUE": openOptionsScreen("QUEUE"); break;
      case "optionsPage:INTERFACE": openOptionsScreen("DISPLAY"); break;
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
      const optionsOpen = state.tab === "SETTINGS";
      createPlaylistTab({ duplicateActive: false, title: "QUEUE", playlist: snapshot.playlist,
        preserveOptions: optionsOpen });
      if (optionsOpen) optionsReturnTab = "QUEUE";
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
