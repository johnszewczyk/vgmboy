(() => {
function create({
  state,
  refs,
  persistSettings,
  selectPlaylistTrack,
  refreshPlaylistPlaybackState,
  renderPlaylist,
  playlistRows,
  updateTimingSummary,
  getSelectedTrack,
  playVisibleTrack
}) {
  function selectedTrackIndex() {
    return state.playlist.findIndex((track) => track.id === state.selectedTrackId);
  }

  function scrollSelectedTrackIntoView() {
    if (!state.selectedTrackId) {
      return;
    }

    const row = refs.playlistBody.querySelector(`[data-track-id="${CSS.escape(state.selectedTrackId)}"]`);
    row?.scrollIntoView({ block: "nearest" });
  }

  function moveSelection(delta, { range = false, extend = false } = {}) {
    if (state.playlist.length === 0) {
      return;
    }

    const currentIndex = selectedTrackIndex();
    const nextIndex = currentIndex >= 0
      ? Math.max(0, Math.min(state.playlist.length - 1, currentIndex + delta))
      : (delta >= 0 ? 0 : state.playlist.length - 1);

    // Keep DOM focus and the visual selection together. Without this, Enter
    // can be routed through an old sidebar/focused row after arrow navigation.
    selectPlaylistTrack(state.playlist[nextIndex].id, { focus: true, range, extend });
    updateTimingSummary();
    if (playlistRows.playlistUsesVirtualRows() && !playlistRows.hasRow(state.selectedTrackId)) {
      refs.playlistBodyWrap.scrollTop = Math.max(
        0,
        nextIndex * playlistRows.playlistVirtualRowHeight() - (refs.playlistBodyWrap.clientHeight / 2)
      );
      renderPlaylist({ sort: false });
      selectPlaylistTrack(state.selectedTrackId, { focus: true, range, extend });
    }
    scrollSelectedTrackIntoView();
  }

  function selectAllPlaylistTracks() {
    if (!state.playlist.length) return;
    state.selectedTrackIds = state.playlist.map((track) => track.id);
    state.selectedTrackId = state.playlist[0].id;
    state.lastSelectedTrackId = state.selectedTrackId;
    state.playlistSelectionAnchorId = state.selectedTrackId;
    persistSettings();
    refreshPlaylistPlaybackState();
  }

  function playSelectedTrack() {
    // Never fall back to the current/last-playing track. Enter is a selection
    // command; a missing selection is a no-op rather than an accidental replay.
    const active = getSelectedTrack();
    if (!active) {
      return;
    }

    playVisibleTrack(active.id, 0).catch((error) => {
      console.error(error);
    });
  }

  return Object.freeze({
    moveSelection,
    playSelectedTrack,
    scrollSelectedTrackIntoView,
    selectAllPlaylistTracks,
    selectedTrackIndex
  });
}

window.SPCBoyPlaylistSelectionActions = Object.freeze({ create });
})();
