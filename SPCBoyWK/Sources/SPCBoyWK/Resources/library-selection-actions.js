(() => {
function create({
  state,
  refs,
  rebuildDatabaseGameSearchIndex,
  resolveSelectedTrackId,
  targetPlaybackSeconds,
  persistSettings,
  renderAll,
  syncTreeSelection,
  scrollSelectedTrackIntoView,
  renderTree,
  renderPlaylist,
  updateTimingSummary,
  updatePlaybackReadout,
  isBrowserFocused,
  focusSelectedBrowserNode
}) {
  function applyLibrarySnapshot(snapshot) {
    if (snapshot?.stale === true) return;
    Object.assign(state, snapshot);
    rebuildDatabaseGameSearchIndex(state.databaseGames);
    state.localBrowserEnabled = true;
    state.sidebarMode = "diskPath";
    state.sidebarQuery = "";
    state.selectedDatabaseGameKey = null;
    refs.sidebarSearchInput.value = "";
    state.selectedTrackId = resolveSelectedTrackId(snapshot.playlist);
    state.lastSelectedTrackId = state.selectedTrackId;
    state.totalSeconds = targetPlaybackSeconds();
    persistSettings();
    renderAll();
    syncTreeSelection();
    scrollSelectedTrackIntoView();
  }

  function applyFolderSelection(selection) {
    const preserveBrowserFocus = isBrowserFocused();
    state.selectedFolderPath = selection.selectedFolderPath;
    state.playlist = selection.playlist;
    state.selectedTrackId = resolveSelectedTrackId(selection.playlist);
    state.lastSelectedTrackId = state.selectedTrackId;
    if (!state.currentTrackId) {
      state.totalSeconds = targetPlaybackSeconds();
    }
    persistSettings();
    renderTree();
    syncTreeSelection();
    if (preserveBrowserFocus && state.selectedBrowserPath) {
      focusSelectedBrowserNode(state.selectedBrowserPath);
    }
    renderPlaylist();
    updateTimingSummary();
    updatePlaybackReadout();
    scrollSelectedTrackIntoView();
  }

  return Object.freeze({ applyFolderSelection, applyLibrarySnapshot });
}

window.SPCBoyLibrarySelectionActions = Object.freeze({ create });
})();
