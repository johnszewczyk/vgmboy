(() => {
  function resolve(storedMode, searchQuery) {
    const normalizedMode = ["paths", "consoles", "diskPath", "favorites"].includes(storedMode)
      ? storedMode
      : "consoles";
    const query = String(searchQuery || "").trim();
    const isTemporary = query.length > 0;
    const view = isTemporary && normalizedMode !== "favorites" ? "search" : normalizedMode;
    const contentMode = view === "consoles" || view === "search" ? "database" : view === "favorites" ? "favorites" : "tree";
    return Object.freeze({
      storedMode: normalizedMode,
      query,
      view,
      contentMode,
      resultSource: view === "paths"
        ? "catalog-path-index"
        : view === "diskPath"
          ? "disk-path-tree"
          : view === "favorites"
            ? "favorite-track-history"
          : "catalog-console-index",
      isTemporary
    });
  }

  window.SPCBoySidebarViewState = Object.freeze({ resolve });
})();
