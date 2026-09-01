(() => {
function create({
  state,
  refs,
  currentSidebarView,
  visibleBrowserNodes,
  selectBrowserNode,
  selectPlaylistTrack,
  updateTimingSummary
}) {
  function scrollSelectedBrowserItemIntoView() {
    if (!state.selectedBrowserPath) return;
    const button = refs.treeRoot.querySelector(`[data-browser-path="${CSS.escape(state.selectedBrowserPath)}"]`);
    button?.scrollIntoView({ block: "nearest" });
  }

  function jumpFocusedListToEdge(toEnd, focused = document.activeElement) {
    if (refs.treeRoot.contains(focused)) {
      if (currentSidebarView().contentMode === "tree") {
        const nodes = visibleBrowserNodes();
        if (nodes.length) selectBrowserNode(nodes[toEnd ? nodes.length - 1 : 0], { focus: true });
        return true;
      }
      const games = [...refs.treeRoot.querySelectorAll(".database-console-games:not(.is-hidden) .database-game-row")];
      const target = games[toEnd ? games.length - 1 : 0];
      target?.focus();
      return Boolean(target);
    }
    if (refs.playlistBody.contains(focused) && state.playlist.length) {
      const track = state.playlist[toEnd ? state.playlist.length - 1 : 0];
      selectPlaylistTrack(track.id, { focus: true });
      updateTimingSummary();
      return true;
    }
    return false;
  }

  return Object.freeze({ jumpFocusedListToEdge, scrollSelectedBrowserItemIntoView });
}

window.SPCBoyNavigationActions = Object.freeze({ create });
})();
