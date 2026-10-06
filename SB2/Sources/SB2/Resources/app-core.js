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
  { id: "system", label: "System" },
  { id: "path", label: "Path" },
  { id: "lengthLabel", label: "Length", className: "mono col-length" },
  { id: "timestamp", label: "Date/Time", className: "mono col-timestamp" }
];
const DEFAULT_COLUMN_ORDER = COLUMN_DEFS.map((column) => column.id);
const DEFAULT_COLUMN_WIDTHS = Object.freeze({
  favorite: 6,
  index: 6,
  filename: 24,
  title: 18,
  game: 18,
  artist: 16,
  system: 10,
  path: 28,
  lengthLabel: 8,
  timestamp: 24
});
const DEFAULT_COLUMN_VISIBILITY = Object.freeze(Object.fromEntries(COLUMN_DEFS.map((column) => [column.id, true])));
const EQUALIZER_BAND_FREQUENCIES = Object.freeze([31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]);
const playbackSpeed = window.SB2PlaybackSpeed;

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
  databaseGameGroups: [],
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
  catalogPlaylistColumnContentHints: null,
  catalogPlaylistSortSessionId: null,
  selectedTrackId: null,
  selectedTrackIds: [],
  playlistSelectionAnchorId: null,
  playlistTitle: "Playlist",
  playlistTabs: [],
  activePlaylistTabId: null,
  activePlaylistTabKind: "playlist",
  galleryGames: [],
  galleryGamesLoaded: false,
  galleryGamesError: "",
  gallerySizeScale: 1,
  galleryGapRem: 0.75,
  galleryRadiusRem: 0.25,
  playbackTabId: null,
  // The visible playlist is a browsing projection. Playback advances through
  // this separate queue so selecting another sidebar item cannot silently
  // replace the queue that is currently playing.
  playingPlaylist: [],
  currentTrackId: null,
  currentTrackInfo: null,
  isPlaying: false,
  elapsedSeconds: 0,
  totalSeconds: DEFAULT_PLAY_FADE_SECONDS,
  manualPlayTimeSeconds: DEFAULT_LONG_PLAY_SECONDS,
  unknownDurationSeconds: 150,
  spcFadeSeconds: DEFAULT_PLAY_FADE_SECONDS,
  uiItemSpacingRem: 0,
  uiFontSizePt: 10,
  uiChromeFontSizePt: 10,
  sidebarFontSizePt: 10,
  sidebarTextColor: "#b6b7dc",
  sidebarMonospace: true,
  sidebarPathCounts: true,
  playlistFontSizePt: 10,
  playlistTextColor: "#b6b7dc",
  playlistHeaderTextColor: "#777c9d",
  playlistMonospace: true,
  applicationMonospace: true,
  uiChromeMonospace: true,
  contentMonospace: true,
  playlistHeaderBold: false,
  sidebarWidthPercent: 31,
  accentColor: "#38aaff",
  uiChromeColor: "#111419",
  uiChromePrimaryColor: "#111419",
  uiChromeSecondaryColor: "#191d24",
  uiChromePaneColor: "#090b0f",
  uiChromeHoverColor: "#202633",
  uiChromeDividerColor: "#292f39",
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
  automaticallyHiddenColumns: new Set(),
  playlistColumnSizing: { horizontalPaddingPerSide: 8 },
  columnAutoSize: true,
  // Catalog order is authoritative until a user explicitly asks to sort a
  // column. Do not let a display/width feature reorder shared rows.
  playlistSortEnabled: false,
  sortColumn: null,
  sortDirection: "ascending",
  autoResizeAnimationMilliseconds: 200,
  selectionAnimationMilliseconds: 200,
  autoResizeAnimationEnabled: true,
  selectionAnimationEnabled: true,
  titlebarTextColor: "#e0e1eb",
  titlebarBold: false,
  mainWindowAlwaysOnTop: false,
  settingsWindowAlwaysOnTop: false,
  optionsOpen: false,
  optionsSection: "database",
  libraryRoots: [],
  archiveCacheSummary: null,
  archiveCacheLocation: "",
  databaseLocation: null,
  databaseLocationStatus: "",
  databaseReloading: false,
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

let settingsSaveChain = Promise.resolve();

const audioEngine = {
  context: null,
  gain: null
};

const refs = {
  sidebarSearchInput: document.getElementById("sidebar-search-input"),
  sidebarViewToggleButton: document.getElementById("sidebar-view-toggle-button"),
  sidebarViewButtons: [],
  databaseCollapseAllButton: document.getElementById("database-collapse-all-button"),
  databaseExpandAllButton: document.getElementById("database-expand-all-button"),
  treeRoot: document.getElementById("tree-root"),
  gallerySidebarToolbar: document.getElementById("gallery-sidebar-toolbar"),
  gallerySizeInput: document.getElementById("gallery-size-input"),
  galleryGapInput: document.getElementById("gallery-gap-input"),
  galleryRadiusInput: document.getElementById("gallery-radius-input"),
  gallerySizeValue: document.getElementById("gallery-size-value"),
  galleryGapValue: document.getElementById("gallery-gap-value"),
  galleryRadiusValue: document.getElementById("gallery-radius-value"),
  galleryView: document.getElementById("gallery-view"),
  galleryGrid: document.getElementById("gallery-grid"),
  sidebarResizeHandle: document.getElementById("sidebar-resize-handle"),
  workspace: document.querySelector(".workspace"),
  sidebarContextMenu: document.getElementById("sidebar-context-menu"),
  playlistScrollWrap: document.querySelector(".playlist-scroll-wrap"),
  playlistTabsToolbar: document.getElementById("playlist-tabs-toolbar"),
  playlistTabs: document.getElementById("playlist-tabs"),
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
  optionsFontsTab: document.getElementById("options-fonts-tab"),
  optionsWindowsTab: document.getElementById("options-windows-tab"),
  optionsThemeSection: document.getElementById("options-theme-section"),
  optionsFontsSection: document.getElementById("options-fonts-section"),
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
  favoriteHistoricalSortCheckbox: document.getElementById("favorite-historical-sort-checkbox"),
  libraryCachePath: document.getElementById("library-cache-path"),
  libraryCacheBrowseButton: document.getElementById("library-cache-browse-button"),
  libraryCacheDefaultButton: document.getElementById("library-cache-default-button"),
  sidebarFontSizeInput: document.getElementById("sidebar-font-size-input"),
  uiChromeFontSizeInput: document.getElementById("ui-chrome-font-size-input"),
  sidebarTextColorInput: document.getElementById("sidebar-text-color-input"),
  playlistHeaderTextColorInput: document.getElementById("playlist-header-text-color-input"),
  sidebarPathCountsCheckbox: document.getElementById("sidebar-path-counts-checkbox"),
  applicationMonospaceCheckbox: document.getElementById("application-monospace-checkbox"),
  uiChromeMonospaceCheckbox: document.getElementById("ui-chrome-monospace-checkbox"),
  aacExportDirectoryPath: document.getElementById("aac-export-directory-path"),
  aacExportChooseButton: document.getElementById("aac-export-choose-button"),
  aacExportStatus: document.getElementById("aac-export-status"),
  aacExportCancelButton: document.getElementById("aac-export-cancel-button"),
  playlistHeaderBoldCheckbox: document.getElementById("playlist-header-bold-checkbox"),
  titlebarTextColorInput: document.getElementById("titlebar-text-color-input"),
  titlebarBoldCheckbox: document.getElementById("titlebar-bold-checkbox"),
  columnAutoSizeCheckbox: document.getElementById("column-auto-size-checkbox"),
  autoResizeAnimationEnabledCheckbox: document.getElementById("auto-resize-animation-enabled-checkbox"),
  autoResizeAnimationInput: document.getElementById("auto-resize-animation-input"),
  selectionAnimationEnabledCheckbox: document.getElementById("selection-animation-enabled-checkbox"),
  selectionAnimationInput: document.getElementById("selection-animation-input"),
  mainWindowAlwaysOnTopCheckbox: document.getElementById("main-window-always-on-top-checkbox"),
  settingsWindowAlwaysOnTopCheckbox: document.getElementById("settings-window-always-on-top-checkbox"),
  sidebarWidthInput: document.getElementById("sidebar-width-input"),
  accentColorInput: document.getElementById("accent-color-input"),
  uiChromeColorInput: document.getElementById("ui-chrome-color-input"),
  uiChromePrimaryColorInput: document.getElementById("ui-chrome-primary-color-input"),
  uiChromeSecondaryColorInput: document.getElementById("ui-chrome-secondary-color-input"),
  uiChromePaneColorInput: document.getElementById("ui-chrome-pane-color-input"),
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
  stopButton: document.getElementById("stop-button"),
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
  repeatButton: document.getElementById("repeat-button"),
  optionsToolbarButton: document.getElementById("options-toolbar-button"),
  sb2ConsoleLabel: document.getElementById("sb2-console-label"),
  sb2AlbumLabel: document.getElementById("sb2-album-label"),
  sb2CPUValue: document.getElementById("sb2-cpu-value"),
  sb2CPUFill: document.getElementById("sb2-cpu-fill"),
  playbackErrorToast: document.getElementById("playback-error-toast")
};

async function loadSettings() {
  try {
    const parsed = await window.spcBoySB2.frontendSettingsLoad();
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
      : (await window.spcBoySB2.defaultAACExportDirectory?.()) || "";
    state.uiItemSpacingRem = normalizeItemSpacing(parsed.uiItemSpacingRem);
    // SB2 is a database-backed player. Older preference files may still
    // contain local-browser state, but it must never reactivate that UI.
    state.rootPath = null;
    state.localBrowserEnabled = false;
    state.selectedFolderPath = null;
    state.selectedBrowserPath = null;
    state.sidebarMode = parsed.sidebarMode === "paths" ? "paths" : "consoles";
    state.gallerySizeScale = Math.max(0.65, Math.min(1.6, Number(parsed.gallerySizeScale) || 1));
    state.galleryGapRem = Math.max(0, Math.min(1, Number(parsed.galleryGapRem ?? 0.75)));
    state.galleryRadiusRem = Math.max(0, Math.min(1, Number(parsed.galleryRadiusRem ?? 0.25)));
    state.favoriteSortOrder = parsed.favoriteSortOrder === "alphabetical" ? "alphabetical" : "historical";
    state.selectedDatabaseGameKey = parsed.selectedDatabaseGameKey || null;
    state.collapsedConsoleNames = Array.isArray(parsed.collapsedConsoleNames)
      ? parsed.collapsedConsoleNames.filter((name) => typeof name === "string")
      : [];
    const contentFontSize = normalizeFontSize(parsed.contentFontSizePt ?? parsed.sidebarFontSizePt ?? parsed.playlistFontSizePt ?? parsed.uiFontSizePt);
    const chromeFontSize = normalizeFontSize(parsed.uiChromeFontSizePt ?? parsed.uiFontSizePt ?? contentFontSize);
    const interfaceFontColor = normalizeFontColor(parsed.sidebarTextColor ?? parsed.playlistTextColor ?? "#b6b7dc");
    const contentMonospace = Boolean(parsed.contentMonospace ?? parsed.sidebarMonospace ?? parsed.playlistMonospace ?? parsed.applicationMonospace ?? true);
    const chromeMonospace = Boolean(parsed.uiChromeMonospace ?? parsed.applicationMonospace ?? true);
    state.uiFontSizePt = chromeFontSize;
    state.uiChromeFontSizePt = chromeFontSize;
    state.sidebarFontSizePt = contentFontSize;
    state.sidebarTextColor = interfaceFontColor;
    state.sidebarMonospace = contentMonospace;
    state.sidebarPathCounts = parsed.sidebarPathCounts !== false;
    state.playlistFontSizePt = contentFontSize;
    state.playlistTextColor = interfaceFontColor;
    state.playlistHeaderTextColor = normalizeFontColor(parsed.playlistHeaderTextColor ?? "#777c9d");
    state.playlistMonospace = contentMonospace;
    state.contentMonospace = contentMonospace;
    state.uiChromeMonospace = chromeMonospace;
    state.applicationMonospace = chromeMonospace;
    state.playlistHeaderBold = Boolean(parsed.playlistHeaderBold);
    state.titlebarTextColor = normalizeFontColor(parsed.titlebarTextColor ?? "#e0e1eb");
    state.titlebarBold = Boolean(parsed.titlebarBold);
    state.sidebarWidthPercent = normalizeSidebarWidth(parsed.sidebarWidthPercent ?? 31);
    state.accentColor = normalizeAccentColor(parsed.accentColor ?? "#38aaff");
    state.uiChromePrimaryColor = normalizeUIColor(parsed.uiChromePrimaryColor ?? parsed.uiChromeColor, "#111419");
    // The old palette exposed a no-op Secondary and used Tertiary for the
    // visible secondary surface. Migrate that visible value into Secondary.
    state.uiChromeSecondaryColor = normalizeUIColor(parsed.uiChromeTertiaryColor ?? parsed.uiChromeSecondaryColor, "#191d24");
    state.uiChromePaneColor = normalizeUIColor(parsed.uiChromePaneColor ?? parsed.uiChromeSidebarColor, "#090b0f");
    state.uiChromeHoverColor = normalizeUIColor(parsed.uiChromeHoverColor, "#202633");
    state.uiChromeDividerColor = normalizeUIColor(parsed.uiChromeDividerColor, "#292f39");
    state.uiChromeColor = state.uiChromePrimaryColor;
    state.routingPreferences = parsed.routingPreferences && typeof parsed.routingPreferences === "object" ? { ...parsed.routingPreferences } : {};
    state.archiveCacheEnabled = parsed.archiveCacheEnabled !== false;
    state.archiveCacheLimitBytes = normalizeArchiveCacheLimit(parsed.archiveCacheLimitBytes);
    // The native snapshot already applies the shared column schema. WebKit
    // receives a projection to render rather than a second layout policy.
    state.columnOrder = Array.isArray(parsed.columnOrder) ? [...parsed.columnOrder] : [...DEFAULT_COLUMN_ORDER];
    state.columnWidths = normalizeColumnWidths(parsed.columnWidths);
    state.columnVisibility = parsed.columnVisibility && typeof parsed.columnVisibility === "object"
      ? { ...parsed.columnVisibility }
      : { ...DEFAULT_COLUMN_VISIBILITY };
    state.playlistColumnSizing = normalizePlaylistColumnSizing(parsed.playlistColumnSizing);
    state.columnAutoSize = parsed.columnAutoSize !== false;
    const savedSortColumn = typeof parsed.sortColumn === "string" ? parsed.sortColumn : null;
    const savedSortIsValid = savedSortColumn !== null
      && COLUMN_DEFS.some((column) => column.id === savedSortColumn && column.sortable !== false);
    // The old renderer always persisted a sort column, even when the user had
    // not chosen one. Absence of the opt-in flag marks that legacy state as
    // inactive so fresh catalog order reaches the list unchanged.
    const legacySortEnabled = parsed.playlistSortEnabled === true && savedSortColumn !== null;
    state.playlistSortEnabled = legacySortEnabled && savedSortIsValid;
    state.sortColumn = state.playlistSortEnabled ? savedSortColumn : null;
    state.sortDirection = parsed.sortDirection === "descending" ? "descending" : "ascending";
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
    rootPath: null,
    localBrowserEnabled: false,
    selectedFolderPath: null,
    selectedBrowserPath: null,
    sidebarMode: state.sidebarMode === "paths" ? "paths" : "consoles",
    gallerySizeScale: state.gallerySizeScale,
    galleryGapRem: state.galleryGapRem,
    galleryRadiusRem: state.galleryRadiusRem,
    favoriteSortOrder: state.favoriteSortOrder,
    selectedDatabaseGameKey: state.selectedDatabaseGameKey,
    collapsedConsoleNames: state.collapsedConsoleNames,
    uiFontSizePt: state.uiFontSizePt,
    uiChromeFontSizePt: state.uiChromeFontSizePt,
    contentFontSizePt: state.sidebarFontSizePt,
    sidebarFontSizePt: state.sidebarFontSizePt,
    sidebarTextColor: state.sidebarTextColor,
    sidebarMonospace: state.sidebarMonospace,
    sidebarPathCounts: state.sidebarPathCounts,
    playlistFontSizePt: state.playlistFontSizePt,
    playlistTextColor: state.playlistTextColor,
    playlistHeaderTextColor: state.playlistHeaderTextColor,
    playlistMonospace: state.playlistMonospace,
    applicationMonospace: state.applicationMonospace,
    uiChromeMonospace: state.uiChromeMonospace,
    contentMonospace: state.contentMonospace,
    playlistHeaderBold: state.playlistHeaderBold,
    titlebarTextColor: state.titlebarTextColor,
    titlebarBold: state.titlebarBold,
    sidebarWidthPercent: state.sidebarWidthPercent,
    accentColor: state.accentColor,
    uiChromeColor: state.uiChromeColor,
    uiChromePrimaryColor: state.uiChromePrimaryColor,
    uiChromeSecondaryColor: state.uiChromeSecondaryColor,
    uiChromePaneColor: state.uiChromePaneColor,
    uiChromeHoverColor: state.uiChromeHoverColor,
    uiChromeDividerColor: state.uiChromeDividerColor,
    routingPreferences: state.routingPreferences,
    archiveCacheEnabled: state.archiveCacheEnabled,
    archiveCacheLimitBytes: state.archiveCacheLimitBytes,
    columnOrder: state.columnOrder,
    columnWidths: state.columnWidths,
    columnVisibility: state.columnVisibility,
    playlistColumnSizing: state.playlistColumnSizing,
    columnAutoSize: state.columnAutoSize,
    playlistSortEnabled: state.playlistSortEnabled,
    sortColumn: state.sortColumn,
    sortDirection: state.sortDirection,
    autoResizeAnimationMilliseconds: state.autoResizeAnimationMilliseconds,
    selectionAnimationMilliseconds: state.selectionAnimationMilliseconds,
    autoResizeAnimationEnabled: state.autoResizeAnimationEnabled,
    selectionAnimationEnabled: state.selectionAnimationEnabled,
    mainWindowAlwaysOnTop: state.mainWindowAlwaysOnTop,
    settingsWindowAlwaysOnTop: state.settingsWindowAlwaysOnTop
  };
  settingsSaveChain = settingsSaveChain
    .catch(() => {})
    .then(() => window.spcBoySB2.frontendSettingsSave(settings))
    .catch((error) => console.error("[SPCBoy] native settings save failed", error));
  return settingsSaveChain;
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

function normalizeUIColor(value, fallback) {
  const text = String(value || "").trim();
  if (!text) return fallback;
  // Accept compact values commonly used while tuning a palette. Bare hex
  // values gain their CSS prefix, and space-separated channels become modern
  // rgb() syntax with optional alpha as the fourth value.
  if (/^(?:[0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(text)) {
    return `#${text.toLowerCase()}`;
  }
  const channels = text.match(/^(\d{1,3})\s+(\d{1,3})\s+(\d{1,3})(?:\s+([0-9]*\.?[0-9]+))?$/);
  if (channels) {
    const [, red, green, blue, alpha] = channels;
    const rgb = [red, green, blue].map(Number);
    const parsedAlpha = alpha === undefined ? null : Number(alpha);
    if (rgb.every((channel) => channel <= 255) && (parsedAlpha === null || parsedAlpha <= 1)) {
      return parsedAlpha === null
        ? `rgb(${rgb.join(" ")})`
        : `rgb(${rgb.join(" ")} / ${parsedAlpha})`;
    }
  }
  if (typeof CSS !== "undefined" && typeof CSS.supports === "function" && CSS.supports("color", text)) {
    return text;
  }
  return /^#[0-9a-f]{3,4}$/i.test(text) || /^#[0-9a-f]{6,8}$/i.test(text)
    ? text.toLowerCase()
    : fallback;
}

function normalizeFontColor(value) {
  return normalizeUIColor(value, "#a9a9a9");
}

function normalizeAccentColor(value) {
  return normalizeUIColor(value, "lightskyblue");
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

function normalizeColumnWidths(value) {
  const widths = { ...DEFAULT_COLUMN_WIDTHS };
  if (!value || typeof value !== "object") return widths;
  for (const column of COLUMN_DEFS) {
    const numeric = Number(value[column.id]);
    if (Number.isFinite(numeric)) widths[column.id] = Math.max(0, Math.min(80, numeric));
  }
  return widths;
}

function normalizePlaylistColumnSizing(value) {
  const numeric = Number(value?.horizontalPaddingPerSide);
  return {
    horizontalPaddingPerSide: Number.isFinite(numeric)
      ? Math.max(0, Math.min(16, numeric))
      : 8
  };
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

window.SB2App = {
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
  normalizeUIColor,
  EQUALIZER_BAND_FREQUENCIES,
  normalizeEqualizerGain,
  normalizeAppVolume,
  normalizeArchiveCacheLimit,
  normalizeSidebarWidth,
  normalizeColumnWidths,
  currentTrack,
  selectedTrack,
  activeTrackInfo,
  playbackBaseSeconds,
  currentFadeSeconds,
  targetPlaybackSeconds
};
