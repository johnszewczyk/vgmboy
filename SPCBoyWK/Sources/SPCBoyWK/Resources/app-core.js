const DEFAULT_PLAY_FADE_SECONDS = 6;
const DEFAULT_LONG_PLAY_SECONDS = 180;
const SAMPLE_RATE = 44_100;
const DEFAULT_ARCHIVE_CACHE_LIMIT_BYTES = 2 * 1024 * 1024 * 1024;
const ARCHIVE_CACHE_LIMIT_CHOICES = Object.freeze([2, 4, 8, 16].map((gigabytes) => gigabytes * 1024 * 1024 * 1024));
const COLUMN_DEFS = [
  { id: "favorite", label: "★", className: "col-favorite", sortable: false },
  { id: "index", label: "#", className: "mono col-index", sortable: false },
  { id: "filename", label: "File" },
  { id: "title", label: "Title" },
  { id: "game", label: "Game" },
  { id: "artist", label: "Artist" },
  { id: "dumper", label: "Dumper" },
  { id: "system", label: "System" },
  { id: "path", label: "Path" },
  { id: "lengthLabel", label: "Length", className: "mono col-length" }
];
const DEFAULT_COLUMN_ORDER = COLUMN_DEFS.map((column) => column.id);
const DEFAULT_COLUMN_WIDTHS = Object.freeze({
  favorite: 6,
  index: 6,
  filename: 24,
  title: 18,
  game: 18,
  artist: 16,
  dumper: 16,
  system: 10,
  path: 28,
  lengthLabel: 8
});
const DEFAULT_COLUMN_VISIBILITY = Object.freeze(Object.fromEntries(COLUMN_DEFS.map((column) => [column.id, true])));
const EQUALIZER_BAND_FREQUENCIES = Object.freeze([31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]);
const playbackSpeed = window.SPCBoyPlaybackSpeed;

const state = {
  rootPath: null,
  localBrowserEnabled: false,
  tree: [],
  sidebarQuery: "",
  sidebarMode: "consoles",
  sidebarView: Object.freeze({ storedMode: "consoles", query: "", view: "consoles", contentMode: "database", resultSource: "catalog-console-index", isTemporary: false }),
  favorites: [],
  favoriteIds: [],
  favoriteSortOrder: "historical",
  databaseGames: [],
  databaseFiles: [],
  databaseFileTree: [],
  databaseSearchGames: null,
  databaseSidebarError: "",
  databaseSidebarLoading: false,
  collapsedConsoleNames: [],
  selectedDatabaseGameKey: null,
  selectedDatabaseConsoleName: null,
  selectedFolderPath: null,
  selectedBrowserPath: null,
  playlist: [],
  selectedTrackId: null,
  selectedTrackIds: [],
  playlistSelectionAnchorId: null,
  // The visible playlist is a browsing projection. Playback advances through
  // this separate queue so selecting another sidebar item cannot silently
  // replace the queue that is currently playing.
  playingPlaylist: [],
  lastSelectedTrackId: null,
  currentTrackId: null,
  currentTrackInfo: null,
  isPlaying: false,
  elapsedSeconds: 0,
  totalSeconds: DEFAULT_PLAY_FADE_SECONDS,
  manualPlayTimeSeconds: DEFAULT_LONG_PLAY_SECONDS,
  unknownDurationSeconds: 150,
  spcFadeSeconds: DEFAULT_PLAY_FADE_SECONDS,
  uiItemSpacingRem: 0.2,
  uiFontSizePt: 10,
  sidebarFontSizePt: 10,
  sidebarTextColor: "#a9a9a9",
  sidebarMonospace: false,
  sidebarPathCounts: true,
  playlistFontSizePt: 10,
  playlistTextColor: "#a9a9a9",
  playlistMonospace: false,
  applicationMonospace: false,
  playlistHeaderBold: false,
  sidebarWidthPercent: 20,
  accentColor: "lightskyblue",
  routingPreferences: {},
  archiveCacheEnabled: true,
  archiveCacheLimitBytes: DEFAULT_ARCHIVE_CACHE_LIMIT_BYTES,
  playbackSpeed: { ...playbackSpeed.DEFAULT },
  playbackSpeedEnabled: false,
  libvgmPlaybackSpeed: { ...playbackSpeed.DEFAULT },
  libvgmPlaybackSpeedEnabled: false,
  longPlayEnabled: false,
  repeatMode: "off",
  queuedSkipsEnabled: false,
  fadeEnabled: true,
  equalizerEnabled: false,
  equalizerBandGains: EQUALIZER_BAND_FREQUENCIES.map(() => 0),
  appVolume: 1,
  monoEnabled: false,
  aacExportDirectory: "",
  aacExportStatus: "",
  aacExportInProgress: false,
  aacExportID: null,
  columnOrder: [...DEFAULT_COLUMN_ORDER],
  columnWidths: { ...DEFAULT_COLUMN_WIDTHS },
  columnVisibility: { ...DEFAULT_COLUMN_VISIBILITY },
  columnAutoSize: true,
  sortColumn: "filename",
  sortDirection: "ascending",
  autoResizeAnimationMilliseconds: 200,
  selectionAnimationMilliseconds: 200,
  autoResizeAnimationEnabled: true,
  selectionAnimationEnabled: true,
  mainWindowAlwaysOnTop: false,
  settingsWindowAlwaysOnTop: false,
  optionsOpen: false,
  optionsSection: "database",
  libraryRoots: [],
  archiveCacheSummary: null,
  archiveCacheLocation: "",
  databaseLocation: null,
  databaseLocationStatus: "",
  nativePlayback: {
    transportState: "stopped",
    outputState: "idle",
    generation: 0,
    statusSequence: 0,
    trackLoaded: false,
    decodeError: false,
    reachedEnd: false,
    bufferedFrames: 0,
    ringBufferFrames: 0,
    underrunCount: 0,
    framesRequested: 0,
    framesSupplied: 0,
    decoderFamily: "",
    decoderSampleRate: 0,
    outputSampleRate: 0,
    decodedFrames: 0,
    audiblePositionFrames: 0,
    tempo: 1,
    positionMs: 0,
    errorMessage: ""
  }
};

const audioEngine = {
  context: null,
  gain: null
};

const refs = {
  sidebarSearchInput: document.getElementById("sidebar-search-input"),
  sidebarViewButtons: [],
  sidebarViewToggleButton: document.getElementById("sidebar-view-toggle-button"),
  databaseCollapseAllButton: document.getElementById("database-collapse-all-button"),
  databaseExpandAllButton: document.getElementById("database-expand-all-button"),
  treeRoot: document.getElementById("tree-root"),
  sidebarResizeHandle: document.getElementById("sidebar-resize-handle"),
  workspace: document.querySelector(".workspace"),
  sidebarContextMenu: document.getElementById("sidebar-context-menu"),
  playlistScrollWrap: document.querySelector(".playlist-scroll-wrap"),
  playlistHeaderWrap: document.querySelector(".playlist-header-wrap"),
  playlistBodyWrap: document.querySelector(".playlist-body-wrap"),
  playlistSelectionIndicator: document.getElementById("playlist-selection-indicator"),
  playlistHeaderTable: document.querySelector(".playlist-header-table"),
  playlistHeaderRow: document.querySelector(".playlist-header-table thead tr"),
  playlistBodyTable: document.querySelector(".playlist-body-table"),
  playlistBody: document.getElementById("playlist-body"),
  optionsOverlay: document.getElementById("options-overlay"),
  optionsCloseButton: document.getElementById("options-close-button"),
  optionsDatabaseTab: document.getElementById("options-database-tab"),
  optionsRoutingTab: document.getElementById("options-routing-tab"),
  optionsPlaybackTab: document.getElementById("options-playback-tab"),
  optionsDiagnosticsTab: document.getElementById("options-diagnostics-tab"),
  optionsAudioTab: document.getElementById("options-audio-tab"),
  optionsThemeTab: document.getElementById("options-theme-tab"),
  optionsWindowsTab: document.getElementById("options-windows-tab"),
  optionsThemeSection: document.getElementById("options-theme-section"),
  optionsWindowsSection: document.getElementById("options-windows-section"),
  optionsDatabaseSection: document.getElementById("options-database-section"),
  optionsRoutingSection: document.getElementById("options-routing-section"),
  optionsPlaybackSection: document.getElementById("options-playback-section"),
  optionsDiagnosticsSection: document.getElementById("options-diagnostics-section"),
  optionsAudioSection: document.getElementById("options-audio-section"),
  routingConflictsList: document.getElementById("routing-conflicts-list"),
  libraryClearCacheButton: document.getElementById("library-clear-cache-button"),
  libraryShowCacheButton: document.getElementById("library-show-cache-button"),
  archiveCacheEnabledCheckbox: document.getElementById("archive-cache-enabled-checkbox"),
  archiveCacheLimitSelect: document.getElementById("archive-cache-limit-select"),
  databaseCacheSummary: document.getElementById("database-cache-summary"),
  libraryDatabasePath: document.getElementById("library-database-path"),
  libraryDatabaseLocationStatus: document.getElementById("library-database-location-status"),
  libraryDatabaseBrowseButton: document.getElementById("library-database-browse-button"),
  libraryDatabaseShowButton: document.getElementById("library-database-show-button"),
  libraryDatabaseDefaultButton: document.getElementById("library-database-default-button"),
  libraryDatabaseReloadButton: document.getElementById("library-database-reload-button"),
  localBrowserEnabledCheckbox: document.getElementById("local-browser-enabled-checkbox"),
  localBrowserPath: document.getElementById("local-browser-path"),
  localBrowserBrowseButton: document.getElementById("local-browser-browse-button"),
  favoriteHistoricalSortCheckbox: document.getElementById("favorite-historical-sort-checkbox"),
  libraryCachePath: document.getElementById("library-cache-path"),
  libraryCacheBrowseButton: document.getElementById("library-cache-browse-button"),
  libraryCacheDefaultButton: document.getElementById("library-cache-default-button"),
  sidebarFontSizeInput: document.getElementById("sidebar-font-size-input"),
  sidebarTextColorInput: document.getElementById("sidebar-text-color-input"),
  sidebarPathCountsCheckbox: document.getElementById("sidebar-path-counts-checkbox"),
  applicationMonospaceCheckbox: document.getElementById("application-monospace-checkbox"),
  aacExportDirectoryPath: document.getElementById("aac-export-directory-path"),
  aacExportChooseButton: document.getElementById("aac-export-choose-button"),
  aacExportStatus: document.getElementById("aac-export-status"),
  aacExportCancelButton: document.getElementById("aac-export-cancel-button"),
  playlistHeaderBoldCheckbox: document.getElementById("playlist-header-bold-checkbox"),
  columnAutoSizeCheckbox: document.getElementById("column-auto-size-checkbox"),
  autoResizeAnimationEnabledCheckbox: document.getElementById("auto-resize-animation-enabled-checkbox"),
  autoResizeAnimationInput: document.getElementById("auto-resize-animation-input"),
  selectionAnimationEnabledCheckbox: document.getElementById("selection-animation-enabled-checkbox"),
  selectionAnimationInput: document.getElementById("selection-animation-input"),
  mainWindowAlwaysOnTopCheckbox: document.getElementById("main-window-always-on-top-checkbox"),
  settingsWindowAlwaysOnTopCheckbox: document.getElementById("settings-window-always-on-top-checkbox"),
  sidebarWidthInput: document.getElementById("sidebar-width-input"),
  accentColorInput: document.getElementById("accent-color-input"),
  uiItemSpacingInput: document.getElementById("ui-item-spacing-input"),
  spcForceLengthCheckbox: document.getElementById("spc-force-length-checkbox"),
  queuedSkipsCheckbox: document.getElementById("queued-skips-checkbox"),
  spcFadeCheckbox: document.getElementById("spc-fade-checkbox"),
  spcLengthInput: document.getElementById("spc-length-input"),
  spcUnknownDurationInput: document.getElementById("spc-unknown-duration-input"),
  spcFadeInput: document.getElementById("spc-fade-input"),
  playbackSpeedInput: document.getElementById("libgme-playback-speed-input"),
  playbackSpeedEnabledCheckbox: document.getElementById("libgme-playback-speed-enabled-checkbox"),
  libvgmPlaybackSpeedInput: document.getElementById("libvgm-playback-speed-input"),
  libvgmPlaybackSpeedEnabledCheckbox: document.getElementById("libvgm-playback-speed-enabled-checkbox"),
  equalizerEnabledCheckbox: document.getElementById("equalizer-enabled-checkbox"),
  equalizerResetButton: document.getElementById("equalizer-reset-button"),
  equalizerBandInputs: [...document.querySelectorAll("[data-equalizer-band]")],
  equalizerBandValues: [...document.querySelectorAll("[data-equalizer-value]")],
  appVolumeInput: document.getElementById("app-volume-input"),
  appVolumeValue: document.getElementById("app-volume-value"),
  monoEnabledCheckbox: document.getElementById("mono-enabled-checkbox"),
  previousButton: document.getElementById("previous-button"),
  playButton: document.getElementById("play-button"),
  nextButton: document.getElementById("next-button"),
  equalizerToolbarButton: document.getElementById("equalizer-toolbar-button"),
  nativeDiagnostics: document.getElementById("native-diagnostics"),
  nativeTransportLabel: document.getElementById("native-transport-label"),
  nativeTrackLabel: document.getElementById("native-track-label"),
  nativeOutputLabel: document.getElementById("native-output-label"),
  nativePositionLabel: document.getElementById("native-position-label"),
  nativeBufferLabel: document.getElementById("native-buffer-label"),
  nativeBufferFillLabel: document.getElementById("native-buffer-fill-label"),
  nativeUnderrunLabel: document.getElementById("native-underrun-label"),
  nativeFramesLabel: document.getElementById("native-frames-label"),
  nativeDecoderLabel: document.getElementById("native-decoder-label"),
  nativeRatesLabel: document.getElementById("native-rates-label"),
  nativeDecodedLabel: document.getElementById("native-decoded-label"),
  nativeTempoLabel: document.getElementById("native-tempo-label"),
  nativeDecodeLabel: document.getElementById("native-decode-label"),
  elapsedLabel: document.getElementById("elapsed-label"),
  progressSliderShell: document.getElementById("progress-slider-shell"),
  progressSlider: document.getElementById("progress-slider"),
  songLengthLabel: document.getElementById("song-length-label"),
  playlistTotalLabel: document.getElementById("playlist-total-label"),
  longPlayButton: document.getElementById("long-play-button"),
  repeatButton: document.getElementById("repeat-button")
};

async function loadSettings() {
  try {
    const parsed = await window.spcBoyWK.frontendSettingsLoad();
    state.manualPlayTimeSeconds = normalizeLongPlayTime(parsed.manualPlayTimeSeconds);
    state.unknownDurationSeconds = normalizePlayTime(parsed.unknownDurationSeconds);
    state.longPlayEnabled = Boolean(parsed.longPlayEnabled);
    state.repeatMode = ["off", "all", "one"].includes(parsed.repeatMode) ? parsed.repeatMode : "off";
    state.queuedSkipsEnabled = Boolean(parsed.queuedSkipsEnabled);
    state.fadeEnabled = parsed.fadeEnabled ?? (parsed.spcFadeEnabled !== false);
    state.spcFadeSeconds = normalizeFadeTime(parsed.spcFadeSeconds);
    state.playbackSpeed = playbackSpeed.normalize(parsed.playbackSpeed);
    state.playbackSpeedEnabled = Boolean(parsed.playbackSpeedEnabled);
    state.libvgmPlaybackSpeed = playbackSpeed.normalize(parsed.libvgmPlaybackSpeed);
    state.libvgmPlaybackSpeedEnabled = Boolean(parsed.libvgmPlaybackSpeedEnabled);
    state.equalizerEnabled = Boolean(parsed.equalizerEnabled);
    state.equalizerBandGains = EQUALIZER_BAND_FREQUENCIES.map((_, index) => normalizeEqualizerGain(parsed.equalizerBandGains?.[index]));
    state.appVolume = normalizeAppVolume(parsed.appVolume);
    state.monoEnabled = Boolean(parsed.monoEnabled);
    state.aacExportDirectory = typeof parsed.aacExportDirectory === "string" && parsed.aacExportDirectory
      ? parsed.aacExportDirectory
      : (await window.spcBoyWK.defaultAACExportDirectory?.()) || "";
    state.uiItemSpacingRem = normalizeItemSpacing(parsed.uiItemSpacingRem);
    state.rootPath = parsed.rootPath || null;
    state.localBrowserEnabled = Boolean(parsed.localBrowserEnabled && state.rootPath);
    state.selectedFolderPath = parsed.selectedFolderPath || null;
    state.selectedBrowserPath = parsed.selectedBrowserPath || state.selectedFolderPath;
    state.sidebarMode = ["paths", "consoles", "diskPath"].includes(parsed.sidebarMode)
      ? parsed.sidebarMode
      : "consoles";
    state.favoriteSortOrder = parsed.favoriteSortOrder === "alphabetical" ? "alphabetical" : "historical";
    state.selectedDatabaseGameKey = parsed.selectedDatabaseGameKey || null;
    state.collapsedConsoleNames = Array.isArray(parsed.collapsedConsoleNames)
      ? parsed.collapsedConsoleNames.filter((name) => typeof name === "string")
      : [];
    state.lastSelectedTrackId = parsed.lastSelectedTrackId || null;
    const interfaceFontSize = normalizeFontSize(parsed.uiFontSizePt ?? parsed.sidebarFontSizePt ?? parsed.playlistFontSizePt);
    const interfaceFontColor = normalizeFontColor(parsed.sidebarTextColor ?? parsed.playlistTextColor);
    const interfaceMonospace = Boolean(parsed.applicationMonospace ?? parsed.sidebarMonospace ?? parsed.playlistMonospace);
    state.uiFontSizePt = interfaceFontSize;
    state.sidebarFontSizePt = interfaceFontSize;
    state.sidebarTextColor = interfaceFontColor;
    state.sidebarMonospace = interfaceMonospace;
    state.sidebarPathCounts = parsed.sidebarPathCounts !== false;
    state.playlistFontSizePt = interfaceFontSize;
    state.playlistTextColor = interfaceFontColor;
    state.playlistMonospace = interfaceMonospace;
    state.applicationMonospace = interfaceMonospace;
    state.playlistHeaderBold = Boolean(parsed.playlistHeaderBold);
    state.sidebarWidthPercent = normalizeSidebarWidth(parsed.sidebarWidthPercent);
    state.accentColor = normalizeAccentColor(parsed.accentColor);
    state.routingPreferences = parsed.routingPreferences && typeof parsed.routingPreferences === "object" ? { ...parsed.routingPreferences } : {};
    state.archiveCacheEnabled = parsed.archiveCacheEnabled !== false;
    state.archiveCacheLimitBytes = normalizeArchiveCacheLimit(parsed.archiveCacheLimitBytes);
    state.columnOrder = normalizeColumnOrder(parsed.columnOrder);
    state.columnWidths = normalizeColumnWidths(parsed.columnWidths);
    state.columnVisibility = normalizeColumnVisibility(parsed.columnVisibility);
    state.columnAutoSize = parsed.columnAutoSize !== false;
    state.sortColumn = normalizeSortColumn(parsed.sortColumn);
    state.sortDirection = normalizeSortDirection(parsed.sortDirection);
    state.autoResizeAnimationMilliseconds = normalizeAnimationMilliseconds(parsed.autoResizeAnimationMilliseconds);
    state.selectionAnimationMilliseconds = normalizeAnimationMilliseconds(parsed.selectionAnimationMilliseconds);
    state.autoResizeAnimationEnabled = parsed.autoResizeAnimationEnabled !== false;
    state.selectionAnimationEnabled = parsed.selectionAnimationEnabled !== false;
    state.mainWindowAlwaysOnTop = Boolean(parsed.mainWindowAlwaysOnTop);
    state.settingsWindowAlwaysOnTop = Boolean(parsed.settingsWindowAlwaysOnTop);
  } catch {
    return;
  }
}

function persistSettings() {
  const settings = {
    manualPlayTimeSeconds: state.manualPlayTimeSeconds,
    unknownDurationSeconds: state.unknownDurationSeconds,
    longPlayEnabled: state.longPlayEnabled,
    repeatMode: state.repeatMode,
    queuedSkipsEnabled: state.queuedSkipsEnabled,
    fadeEnabled: state.fadeEnabled,
    equalizerEnabled: state.equalizerEnabled,
    equalizerBandGains: state.equalizerBandGains,
    appVolume: state.appVolume,
    monoEnabled: state.monoEnabled,
    aacExportDirectory: state.aacExportDirectory,
    spcFadeSeconds: state.spcFadeSeconds,
    playbackSpeed: state.playbackSpeed,
    playbackSpeedEnabled: state.playbackSpeedEnabled,
    libvgmPlaybackSpeed: state.libvgmPlaybackSpeed,
    libvgmPlaybackSpeedEnabled: state.libvgmPlaybackSpeedEnabled,
    uiItemSpacingRem: state.uiItemSpacingRem,
    rootPath: state.rootPath,
    localBrowserEnabled: state.localBrowserEnabled,
    selectedFolderPath: state.selectedFolderPath,
    selectedBrowserPath: state.selectedBrowserPath,
    sidebarMode: state.sidebarMode,
    favoriteSortOrder: state.favoriteSortOrder,
    selectedDatabaseGameKey: state.selectedDatabaseGameKey,
    collapsedConsoleNames: state.collapsedConsoleNames,
    lastSelectedTrackId: state.lastSelectedTrackId,
    uiFontSizePt: state.uiFontSizePt,
    sidebarFontSizePt: state.sidebarFontSizePt,
    sidebarTextColor: state.sidebarTextColor,
    sidebarMonospace: state.sidebarMonospace,
    sidebarPathCounts: state.sidebarPathCounts,
    playlistFontSizePt: state.playlistFontSizePt,
    playlistTextColor: state.playlistTextColor,
    playlistMonospace: state.playlistMonospace,
    applicationMonospace: state.applicationMonospace,
    playlistHeaderBold: state.playlistHeaderBold,
    sidebarWidthPercent: state.sidebarWidthPercent,
    accentColor: state.accentColor,
    routingPreferences: state.routingPreferences,
    archiveCacheEnabled: state.archiveCacheEnabled,
    archiveCacheLimitBytes: state.archiveCacheLimitBytes,
    columnOrder: state.columnOrder,
    columnWidths: state.columnWidths,
    columnVisibility: state.columnVisibility,
    columnAutoSize: state.columnAutoSize,
    sortColumn: state.sortColumn,
    sortDirection: state.sortDirection,
    autoResizeAnimationMilliseconds: state.autoResizeAnimationMilliseconds,
    selectionAnimationMilliseconds: state.selectionAnimationMilliseconds,
    autoResizeAnimationEnabled: state.autoResizeAnimationEnabled,
    selectionAnimationEnabled: state.selectionAnimationEnabled,
    mainWindowAlwaysOnTop: state.mainWindowAlwaysOnTop,
    settingsWindowAlwaysOnTop: state.settingsWindowAlwaysOnTop
  };
  window.spcBoyWK.frontendSettingsSave(settings)
    .catch((error) => console.error("[SPCBoy] native settings save failed", error));
}

function formatTime(totalSeconds) {
  const whole = Math.max(0, Math.round(totalSeconds));
  const minutes = Math.floor(whole / 60);
  const seconds = whole % 60;
  return `${minutes}:${String(seconds).padStart(2, "0")}`;
}

function normalizePlayTime(value) {
  const numeric = Number(value);
  return Number.isFinite(numeric)
    ? Math.max(30, Math.min(900, Math.round(numeric)))
    : 150;
}

function normalizeLongPlayTime(value) {
  const numeric = Number(value);
  return Number.isFinite(numeric)
    // Long Play is an explicit user policy. Zero means no finite cap; do not
    // silently rewrite the user's value to an arbitrary window.
    ? Math.max(0, Math.round(numeric))
    : DEFAULT_LONG_PLAY_SECONDS;
}

function normalizeFadeTime(value) {
  const numeric = Number(value);
  return Number.isFinite(numeric)
    ? Math.max(0, Math.min(30, Math.round(numeric)))
    : DEFAULT_PLAY_FADE_SECONDS;
}

function normalizeAnimationMilliseconds(value) {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? Math.max(0, Math.min(1000, Math.round(numeric))) : 200;
}

function normalizeEqualizerGain(value) {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? Math.max(-12, Math.min(12, Math.round(numeric * 2) / 2)) : 0;
}

function normalizeAppVolume(value) {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? Math.max(0, Math.min(1, numeric)) : 1;
}

function normalizeArchiveCacheLimit(value) {
  const numeric = Number(value);
  return ARCHIVE_CACHE_LIMIT_CHOICES.includes(numeric) ? numeric : DEFAULT_ARCHIVE_CACHE_LIMIT_BYTES;
}

function parseDurationSeconds(value) {
  const text = String(value || "").trim();
  if (!text) {
    return null;
  }

  if (text.includes(":")) {
    const parts = text.split(":").map((part) => part.trim());
    if (parts.length !== 2) {
      return null;
    }

    const minutes = Number(parts[0]);
    const seconds = Number(parts[1]);
    if (!Number.isFinite(minutes) || !Number.isFinite(seconds)) {
      return null;
    }

    return Math.max(0, Math.round(minutes * 60 + seconds));
  }

  const numeric = Number(text);
  if (!Number.isFinite(numeric)) {
    return null;
  }

  return Math.max(0, Math.round(numeric));
}

function normalizeItemSpacing(value) {
  const numeric = Number(value);
  return Number.isFinite(numeric)
    ? Math.max(0, Math.min(2, Math.round(numeric * 100) / 100))
    : 0.2;
}

function normalizeFontSize(value) {
  const numeric = Number(value);
  return Number.isFinite(numeric)
    ? Math.max(8, Math.min(18, Math.round(numeric)))
    : 10;
}

function normalizeFontColor(value) {
  const text = String(value || "").trim();
  if (!text) return "#a9a9a9";
  if (typeof CSS !== "undefined" && typeof CSS.supports === "function" && CSS.supports("color", text)) {
    return text;
  }
  return /^#[0-9a-f]{3,4}$/i.test(text) || /^#[0-9a-f]{6,8}$/i.test(text)
    ? text.toLowerCase()
    : "#a9a9a9";
}

function normalizeAccentColor(value) {
  const text = String(value || "").trim();
  if (!text) return "lightskyblue";
  if (typeof CSS !== "undefined" && typeof CSS.supports === "function" && CSS.supports("color", text)) return text;
  return /^#[0-9a-f]{3,4}$/i.test(text) || /^#[0-9a-f]{6,8}$/i.test(text)
    ? text.toLowerCase()
    : "lightskyblue";
}

function normalizeSidebarWidth(value) {
  const numeric = Number(value);
  return Number.isFinite(numeric)
    ? Math.max(12, Math.min(50, Math.round(numeric)))
    : 20;
}

function parseNumericInput(value) {
  const numeric = Number(String(value || "").trim().replace(/[^0-9.\\-]/g, ""));
  return Number.isFinite(numeric) ? numeric : null;
}

function normalizeColumnOrder(value) {
  if (!Array.isArray(value)) {
    return [...DEFAULT_COLUMN_ORDER];
  }

  const validIds = new Set(DEFAULT_COLUMN_ORDER);
  const deduped = value.filter((columnId, index) => (
    validIds.has(columnId) &&
    value.indexOf(columnId) === index
  ));
  const missing = DEFAULT_COLUMN_ORDER.filter((columnId) => !deduped.includes(columnId));
  return ["favorite", ...deduped.filter((columnId) => columnId !== "favorite"), ...missing.filter((columnId) => columnId !== "favorite")];
}

function normalizeColumnWidths(value) {
  const widths = { ...DEFAULT_COLUMN_WIDTHS };
  if (!value || typeof value !== "object") return widths;
  for (const column of COLUMN_DEFS) {
    const numeric = Number(value[column.id]);
    if (Number.isFinite(numeric)) widths[column.id] = Math.max(4, Math.min(80, numeric));
  }
  return widths;
}

function normalizeColumnVisibility(value) {
  const visibility = { ...DEFAULT_COLUMN_VISIBILITY };
  if (!value || typeof value !== "object") return visibility;
  for (const column of COLUMN_DEFS) {
    if (typeof value[column.id] === "boolean") visibility[column.id] = value[column.id];
  }
  if (!Object.values(visibility).some(Boolean)) visibility[DEFAULT_COLUMN_ORDER[0]] = true;
  return visibility;
}

function normalizeSortColumn(value) {
  return DEFAULT_COLUMN_ORDER.includes(value) && !["index", "favorite"].includes(value) ? value : "filename";
}

function normalizeSortDirection(value) {
  return value === "descending" ? "descending" : "ascending";
}

function currentTrack() {
  const queue = state.playingPlaylist?.length ? state.playingPlaylist : state.playlist;
  return queue.find((track) => track.id === state.currentTrackId) ?? null;
}

function selectedTrack() {
  return state.playlist.find((track) => track.id === state.selectedTrackId) ?? null;
}

function activeTrackInfo() {
  return currentTrack() ?? state.currentTrackInfo ?? selectedTrack();
}

function playbackBaseSeconds() {
  return state.manualPlayTimeSeconds;
}

function currentFadeSeconds(track = null) {
  if (!state.fadeEnabled) {
    return 0;
  }

  return state.spcFadeSeconds;
}

function targetPlaybackSeconds() {
  return playbackBaseSeconds() + currentFadeSeconds();
}

window.SPCBoyApp = {
  DEFAULT_PLAY_FADE_SECONDS,
  DEFAULT_LONG_PLAY_SECONDS,
  SAMPLE_RATE,
  COLUMN_DEFS,
  DEFAULT_COLUMN_ORDER,
  state,
  audioEngine,
  refs,
  loadSettings,
  persistSettings,
  formatTime,
  normalizePlayTime,
  normalizeLongPlayTime,
  normalizeFadeTime,
  normalizeAnimationMilliseconds,
  normalizePlaybackSpeed: playbackSpeed.normalize,
  parsePlaybackSpeed: playbackSpeed.parse,
  formatPlaybackSpeed: playbackSpeed.format,
  scalePlaybackMilliseconds: playbackSpeed.scaleMilliseconds,
  parseDurationSeconds,
  parseNumericInput,
  normalizeItemSpacing,
  normalizeFontSize,
  normalizeFontColor,
  normalizeAccentColor,
  EQUALIZER_BAND_FREQUENCIES,
  normalizeEqualizerGain,
  normalizeAppVolume,
  normalizeArchiveCacheLimit,
  normalizeSidebarWidth,
  normalizeColumnOrder,
  normalizeColumnWidths,
  normalizeColumnVisibility,
  normalizeSortColumn,
  normalizeSortDirection,
  currentTrack,
  selectedTrack,
  activeTrackInfo,
  playbackBaseSeconds,
  currentFadeSeconds,
  targetPlaybackSeconds
};
