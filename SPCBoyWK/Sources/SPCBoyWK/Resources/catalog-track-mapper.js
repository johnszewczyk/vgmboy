(() => {
function create({ state, formatTime }) {
  function databaseRowsToPlaylistTracks(rows, games) {
    const fallbackGame = games[0] || {};
    return rows.map((row, index) => ({
      id: row.playlistId,
      favoriteId: row.favoriteId || null,
      index: index + 1,
      path: row.path,
      rootPath: row.rootPath || fallbackGame.rootPath || state.rootPath,
      sourceFilename: row.filename,
      trackIndex: Number(row.trackIndex) || 0,
      trackCount: Math.max(1, Number(row.trackCount) || 1),
      archivePath: row.archivePath || null,
      archiveEntry: row.archiveEntry || null,
      fileSize: Number(row.fileSize) || 0,
      modifiedAt: Number(row.modifiedAt) || 0,
      sourceSignature: row.sourceSignature || null,
      scanVersion: Number(row.scanVersion) || 0,
      filename: `${row.filename}${Number(row.trackCount) > 1 ? ` [${Number(row.trackIndex) + 1}]` : ""}`,
      displayName: `${row.filename.replace(/\.[^.]+$/i, "")}${Number(row.trackCount) > 1 ? ` [${Number(row.trackIndex) + 1}]` : ""}`,
      title: row.title || row.filename.replace(/\.[^.]+$/i, ""),
      game: row.game || fallbackGame.name || "—",
      artist: row.artist || "—",
      dumper: row.dumper || "—",
      system: row.system || fallbackGame.system || "—",
      lengthLabel: row.playLengthMs > 0 ? formatTime(Math.round(row.playLengthMs / 1000)) : "—",
      basePlaybackSeconds: row.playLengthMs > 0 ? row.playLengthMs / 1000 : 0,
      metadataLoaded: row.metadataLoaded === true,
      catalogRow: true
    }));
  }

  return Object.freeze({ databaseRowsToPlaylistTracks });
}

window.SPCBoyCatalogTrackMapper = Object.freeze({ create });
})();
