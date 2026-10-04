(() => {
const app = window.SB2App;
const { state, persistSettings } = app;

function renderAll() {
  app.ui.renderAll();
}

function refreshDatabaseGamesForVisibleRoots() {
  return app.ui.refreshDatabaseGamesForVisibleRoots();
}

async function refreshLibraryRoots() {
  if (!window.spcBoySB2?.databaseRoots) return;
  state.libraryRoots = await window.spcBoySB2.databaseRoots();
  renderAll();
}

async function handleLibraryRootsChanged(roots) {
  state.libraryRoots = Array.isArray(roots) ? roots : [];
  state.databaseSidebarLoading = true;
  state.databaseSidebarError = "";
  state.databaseFiles = [];
  state.databaseFileTree = [];
  renderAll();
  try {
    await refreshDatabaseGamesForVisibleRoots();
    if (state.sidebarMode === "paths") await app.ui.loadDatabaseFiles();
    persistSettings();
  } finally {
    state.databaseSidebarLoading = false;
    renderAll();
  }
}

async function refreshArchiveCacheSummary() {
  if (!window.spcBoySB2?.archiveCacheSummary) return;
  try {
    state.archiveCacheLocation = await window.spcBoySB2.archiveCacheLocation?.() || "";
    state.archiveCacheSummary = await window.spcBoySB2.archiveCacheSummary();
  } catch (error) {
    state.archiveCacheSummary = null;
    state.databaseLocationStatus = `Archive cache status unavailable • ${error.message}`;
  }
  renderAll();
}

async function refreshDatabaseLocation() {
  if (!window.spcBoySB2?.databaseLocation) return;
  state.databaseLocation = await window.spcBoySB2.databaseLocation();
  state.databaseLocationStatus = state.databaseLocation.requiresRestart
    ? "Restart SPCBoy to use the selected database."
    : "The shared ScanSong catalog is active and opened read-only.";
  renderAll();
}

async function chooseDatabaseLocation() {
  const result = await window.spcBoySB2?.chooseDatabaseLocation?.();
  if (!result) return;
  state.databaseLocation = result;
  state.databaseLocationStatus = `Validated ${Number(result.catalog?.trackCount || 0).toLocaleString()} tracks. Restart SPCBoy to use this database.`;
  renderAll();
}

async function useDefaultDatabaseLocation() {
  state.databaseLocation = await window.spcBoySB2?.useDefaultDatabaseLocation?.();
  state.databaseLocationStatus = state.databaseLocation?.requiresRestart
    ? "Restart SPCBoy to use the default CocoaSpice database."
    : "The default CocoaSpice database is already active.";
  renderAll();
}

async function handleCatalogReloaded(result) {
  state.databaseLocation = result || await window.spcBoySB2?.databaseLocation?.() || null;
  state.databaseLocationStatus = state.databaseLocation?.reloaded
    ? "Library reloaded. SPCBoy is reading the latest ScanSong catalog."
    : state.databaseLocation?.requiresRestart
      ? "Restart SPCBoy to use the selected database."
      : "The shared ScanSong catalog is active and opened read-only.";
  if (!window.spcBoySB2?.isOptionsWindow && window.spcBoySB2?.databaseRoots) {
    state.libraryRoots = await window.spcBoySB2.databaseRoots();
    await handleLibraryRootsChanged(state.libraryRoots);
  }
  renderAll();
}

async function reloadDatabaseLibrary() {
  if (!window.spcBoySB2?.reloadDatabaseLibrary) return;
  state.databaseReloading = true;
  state.databaseLocationStatus = "Reloading the latest ScanSong catalog…";
  renderAll();
  try {
    await handleCatalogReloaded(await window.spcBoySB2.reloadDatabaseLibrary());
  } finally {
    state.databaseReloading = false;
    renderAll();
  }
}

async function clearLibraryArchiveCache() {
  if (!window.spcBoySB2?.clearArchiveCache) return;
  try {
    await window.spcBoySB2.clearArchiveCache();
  } finally {
    await refreshArchiveCacheSummary();
  }
  renderAll();
}

async function showLibraryArchiveCacheInFinder() {
  await window.spcBoySB2?.showArchiveCacheInFinder?.();
}

Object.assign(app.ui, {
  refreshLibraryRoots,
  handleLibraryRootsChanged,
  refreshArchiveCacheSummary,
  refreshDatabaseLocation,
  chooseDatabaseLocation,
  useDefaultDatabaseLocation,
  handleCatalogReloaded,
  reloadDatabaseLibrary,
  clearLibraryArchiveCache,
  showLibraryArchiveCacheInFinder
});
})();
