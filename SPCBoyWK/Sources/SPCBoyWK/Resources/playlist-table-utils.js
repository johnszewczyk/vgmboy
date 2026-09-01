(() => {
  function displayPath(track, rootPath = "") {
    const sourcePath = String(track?.path || "");
    const selectedRootPath = String(track?.rootPath || rootPath || "");
    if (!sourcePath || !selectedRootPath) return sourcePath;
    const hashIndex = sourcePath.indexOf("#");
    const physicalPath = hashIndex === -1 ? sourcePath : sourcePath.slice(0, hashIndex);
    const archiveSuffix = hashIndex === -1 ? "" : sourcePath.slice(hashIndex);
    const normalizedRoot = selectedRootPath.replace(/[\\/]+$/, "");
    const normalizedPhysical = physicalPath.replace(/\\/g, "/");
    const normalizedRootForMatch = normalizedRoot.replace(/\\/g, "/");
    const rootPrefix = `${normalizedRootForMatch}/`;
    const rootLabel = normalizedRootForMatch.split("/").at(-1);
    const sourceForMatch = normalizedPhysical.toLocaleLowerCase();
    const rootForMatch = normalizedRootForMatch.toLocaleLowerCase();
    if (sourceForMatch === rootForMatch) return `${rootLabel}${archiveSuffix}`;
    if (sourceForMatch.startsWith(rootPrefix.toLocaleLowerCase())) {
      return `${rootLabel}/${normalizedPhysical.slice(rootPrefix.length)}${archiveSuffix}`;
    }
    return sourcePath;
  }

  function valueForColumn(track, column, rowIndex = null, rootPath = "") {
    if (column.id === "index") return rowIndex === null ? "" : rowIndex + 1;
    if (column.id === "favorite") return "";
    if (column.id === "dumper") return track.dumper || "—";
    return column.id === "path" ? displayPath(track, rootPath) : (track[column.id] ?? "");
  }

  function sortValue(track, column, rootPath = "") {
    if (column.id === "lengthLabel") return Number(track.basePlaybackSeconds) || 0;
    return String(valueForColumn(track, column, null, rootPath)).toLocaleLowerCase();
  }

  window.SPCBoyPlaylistTable = Object.freeze({ displayPath, valueForColumn, sortValue });
})();
