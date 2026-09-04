(() => {
function create({ state, formatTime }) {
  function leafFilename(value) {
    if (typeof value !== "string" || value.length === 0) return "";
    const normalized = value.replace(/\\/g, "/");
    return normalized.split("/").filter(Boolean).pop() || "";
  }

  function databaseRowsToPlaylistTracks(rows, games) {
    const fallbackGame = games[0] || {};
    return rows.map((row, index) => {
      // Older/native bridge payloads may still call the archive container
      // `filename`; the catalog member identity is authoritative when it is
      // present, so File never regresses to the parent archive name.
      const filename = leafFilename(row.sourceFilename) || leafFilename(row.archiveEntry) || leafFilename(row.filename) || leafFilename(row.path) || "—";
      const trackCount = Number(row.trackCount) || 1;
      const trackIndex = Number(row.trackIndex) || 0;
      const fallbackFilename = `${filename}${trackCount > 1 ? ` [${trackIndex + 1}]` : ""}`;
      const fallbackDisplayName = `${filename.replace(/\.[^.]+$/i, "")}${trackCount > 1 ? ` [${trackIndex + 1}]` : ""}`;
      const lengthMilliseconds = Number(row.playLengthMs) || 0;
      return {
        id: row.playlistId,
        favoriteId: row.favoriteId || null,
        index: index + 1,
        path: row.path,
        rootPath: row.rootPath || fallbackGame.rootPath || state.rootPath,
        sourceFilename: filename,
        trackIndex,
        trackCount: Math.max(1, trackCount),
        archivePath: row.archivePath || null,
        archiveEntry: row.archiveEntry || null,
        fileSize: Number(row.fileSize) || 0,
        modifiedAt: Number(row.modifiedAt) || 0,
        sourceSignature: row.sourceSignature || null,
        scanVersion: Number(row.scanVersion) || 0,
        filename: row.displayFilename || fallbackFilename,
        displayName: row.displayName || fallbackDisplayName,
        title: row.title || row.displayName || fallbackDisplayName,
        game: row.game || fallbackGame.displayName || fallbackGame.name || "—",
        artist: row.artist || "—",
        dumper: row.dumper || "—",
        system: row.system || fallbackGame.system || "—",
        lengthLabel: row.lengthLabel || (lengthMilliseconds > 0 ? formatTime(Math.round(lengthMilliseconds / 1000)) : "—"),
        basePlaybackSeconds: Number.isFinite(Number(row.basePlaybackSeconds)) ? Number(row.basePlaybackSeconds) : lengthMilliseconds / 1000,
        metadataLoaded: row.metadataLoaded === true,
        catalogRow: true
      };
    });
  }

  return Object.freeze({ databaseRowsToPlaylistTracks });
}

window.SPCBoyCatalogTrackMapper = Object.freeze({ create });
})();
