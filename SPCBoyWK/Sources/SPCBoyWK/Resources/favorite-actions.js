(() => {
function create({
  state,
  listFavorites,
  toggleFavoriteTracks,
  renderSidebar,
  renderPlaylist,
  isSidebarFocused,
  visibleDatabaseGames,
  databaseGameKey,
  databaseConsoleName,
  databaseGameTracks,
  databaseRowsToPlaylistTracks
}) {
  function applyFavoriteSnapshot(favorites) {
    state.favorites = Array.isArray(favorites) ? favorites : [];
    state.favoriteIds = state.favorites.map((track) => track.favoriteId).filter(Boolean);
  }

  function isFavoritePresentation(track) {
    return Boolean(track?.favoriteId) && state.favoriteIds.includes(track.favoriteId);
  }

  async function refreshFavorites() {
    const favorites = await listFavorites(state.favoriteSortOrder);
    applyFavoriteSnapshot(favorites);
    return state.favorites;
  }

  async function toggleFavorites(tracks) {
    applyFavoriteSnapshot(await toggleFavoriteTracks(tracks, state.favoriteSortOrder));
  }

  async function toggleSelectedFavorites() {
    if (!isSidebarFocused() && state.selectedTrackIds.length) {
      const tracks = state.playlist.filter((entry) => state.selectedTrackIds.includes(entry.id));
      if (tracks.length) {
        await toggleFavorites(tracks);
        renderSidebar();
        renderPlaylist();
        return;
      }
    }
    const games = state.selectedDatabaseGameKey
      ? visibleDatabaseGames().filter((game) => databaseGameKey(game) === state.selectedDatabaseGameKey)
      : state.selectedDatabaseConsoleName
        ? visibleDatabaseGames().filter((game) => databaseConsoleName(game) === state.selectedDatabaseConsoleName)
        : [];
    if (!games.length) return;
    const rows = await databaseGameTracks(games);
    if (rows?.stale === true) return;
    await toggleFavorites(databaseRowsToPlaylistTracks(rows, games));
    renderSidebar();
    renderPlaylist();
  }

  return Object.freeze({
    isFavoritePresentation,
    refreshFavorites,
    toggleFavorites,
    toggleSelectedFavorites
  });
}

window.SPCBoyFavoriteActions = Object.freeze({ create });
})();
