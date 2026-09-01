(() => {
function create({
  state,
  persistSettings,
  renderTree,
  syncTreeSelection,
  renderPlaylist,
  updateTimingSummary
}) {
  function appendPlaylistTracks(additions, selectedBrowserPath = state.selectedBrowserPath) {
    if (!additions.length) return;
    const existingIds = new Set(state.playlist.map((track) => track.id));
    const uniqueAdditions = additions.filter((track) => !existingIds.has(track.id));
    if (!uniqueAdditions.length) return;
    state.selectedBrowserPath = selectedBrowserPath;
    state.playlist = [...state.playlist, ...uniqueAdditions];
    state.selectedTrackId = uniqueAdditions[0].id;
    state.lastSelectedTrackId = state.selectedTrackId;
    persistSettings();
    renderTree();
    syncTreeSelection();
    renderPlaylist();
    updateTimingSummary();
  }

  return Object.freeze({ appendPlaylistTracks });
}

window.SPCBoyPlaylistMutationActions = Object.freeze({ create });
})();
