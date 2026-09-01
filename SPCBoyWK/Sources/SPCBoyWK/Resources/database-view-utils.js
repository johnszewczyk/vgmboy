(() => {
  function sidebarView(mode, query) {
    const normalizedQuery = String(query || "").trim();
    const view = normalizedQuery ? "search" : mode;
    return {
      storedMode: mode,
      query: normalizedQuery,
      view,
      contentMode: view === "paths" || view === "diskPath" ? "tree" : "database",
      resultSource: view === "paths" ? "catalog-path-index" : view === "diskPath" ? "disk-path-tree" : "catalog-console-index",
      isTemporary: view === "search"
    };
  }

  function searchRecords(games) {
    return (Array.isArray(games) ? games : []).map((game) => ({
      game,
      searchText: `${game.name || ""} ${game.system || ""} ${game.rootName || ""} ${game.displayName || ""}`.toLowerCase()
    }));
  }

  function filterSearchRecords(records, query, fallbackGames = []) {
    const terms = String(query || "").trim().toLowerCase().split(/\s+/).filter(Boolean);
    if (!terms.length) return fallbackGames;
    return records
      .filter(({ searchText }) => terms.every((term) => searchText.includes(term)))
      .map(({ game }) => game);
  }

  window.SPCBoyDatabaseView = Object.freeze({ sidebarView, searchRecords, filterSearchRecords });
})();
