(() => {
const app = window.SPCBoyApp;
const { state, persistSettings } = app;

function renderAll() {
  app.ui.renderAll();
}

function refreshDatabaseGamesForVisibleRoots() {
  return app.ui.refreshDatabaseGamesForVisibleRoots();
}

async function refreshLibraryRoots() {
  if (!window.spcBoyWK?.databaseRoots) return;
  state.libraryRoots = await window.spcBoyWK.databaseRoots();
  renderAll();
}

async function handleLibraryRootsChanged(roots) {
  state.libraryRoots = Array.isArray(roots) ? roots : [];
  state.databaseSidebarLoading = true;
  state.databaseSidebarError = "";
  renderAll();
  try {
    await refreshDatabaseGamesForVisibleRoots();
    state.databaseFiles = [];
    state.databaseFileTree = [];
    persistSettings();
    if (state.sidebarMode === "paths") {
      await app.ui.loadDatabaseFiles();
    }
  } finally {
    state.databaseSidebarLoading = false;
    renderAll();
  }
  app.ui.syncTreeSelection();
}

async function refreshArchiveCacheSummary() {
  if (!window.spcBoyWK?.archiveCacheSummary) return;
  try {
    state.archiveCacheLocation = await window.spcBoyWK.archiveCacheLocation?.() || "";
    state.archiveCacheSummary = await window.spcBoyWK.archiveCacheSummary();
  } catch (error) {
    state.archiveCacheSummary = null;
    state.databaseLocationStatus = `Archive cache status unavailable • ${error.message}`;
  }
  renderAll();
}

async function refreshDatabaseLocation() {
  if (!window.spcBoyWK?.databaseLocation) return;
  state.databaseLocation = await window.spcBoyWK.databaseLocation();
  state.databaseLocationStatus = state.databaseLocation.requiresRestart
    ? "Restart SPCBoy to use the selected database."
    : "The shared ScanSong catalog is active and opened read-only.";
  renderAll();
}

async function chooseDatabaseLocation() {
  const result = await window.spcBoyWK?.chooseDatabaseLocation?.();
  if (!result) return;
  state.databaseLocation = result;
  state.databaseLocationStatus = `Validated ${Number(result.catalog?.trackCount || 0).toLocaleString()} tracks. Restart SPCBoy to use this database.`;
  renderAll();
}

async function useDefaultDatabaseLocation() {
  state.databaseLocation = await window.spcBoyWK?.useDefaultDatabaseLocation?.();
  state.databaseLocationStatus = state.databaseLocation?.requiresRestart
    ? "Restart SPCBoy to use the default CocoaSpice database."
    : "The default CocoaSpice database is already active.";
  renderAll();
}

async function handleCatalogReloaded(result) {
  state.databaseLocation = result || await window.spcBoyWK?.databaseLocation?.() || null;
  state.databaseLocationStatus = state.databaseLocation?.reloaded
    ? "Library reloaded. SPCBoy is reading the latest ScanSong catalog."
    : state.databaseLocation?.requiresRestart
      ? "Restart SPCBoy to use the selected database."
      : "The shared ScanSong catalog is active and opened read-only.";
  if (!window.spcBoyWK?.isOptionsWindow && window.spcBoyWK?.databaseRoots) {
    state.libraryRoots = await window.spcBoyWK.databaseRoots();
    await handleLibraryRootsChanged(state.libraryRoots);
  }
  renderAll();
}

async function reloadDatabaseLibrary() {
  if (!window.spcBoyWK?.reloadDatabaseLibrary) return;
  await handleCatalogReloaded(await window.spcBoyWK.reloadDatabaseLibrary());
}

async function clearLibraryArchiveCache() {
  if (!window.spcBoyWK?.clearArchiveCache) return;
  try {
    await window.spcBoyWK.clearArchiveCache();
  } finally {
    await refreshArchiveCacheSummary();
  }
  renderAll();
}

async function showLibraryArchiveCacheInFinder() {
  await window.spcBoyWK?.showArchiveCacheInFinder?.();
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
