(() => {
  function reduceSelection({ playlist, selectedIds, selectedIDSet, anchorId, indexByID }, trackId, { extend = false, range = false } = {}) {
    const targetIndex = indexByID?.get(trackId) ?? playlist.findIndex((track) => track.id === trackId);
    if (targetIndex < 0) return null;
    const selected = selectedIDSet || new Set(selectedIds);
    let nextIds;
    if (range && anchorId) {
      const anchorIndex = indexByID?.get(anchorId) ?? playlist.findIndex((track) => track.id === anchorId);
      const start = Math.min(anchorIndex < 0 ? targetIndex : anchorIndex, targetIndex);
      const end = Math.max(anchorIndex < 0 ? targetIndex : anchorIndex, targetIndex);
      nextIds = playlist.slice(start, end + 1).map((track) => track.id);
    } else if (extend) {
      nextIds = selected.has(trackId)
        ? selectedIds.filter((id) => id !== trackId)
        : [...selectedIds, trackId];
    } else {
      nextIds = [trackId];
    }
    return Object.freeze({ selectedIds: nextIds, primaryId: nextIds.includes(trackId) ? trackId : (nextIds.at(-1) || null), anchorId: range ? anchorId : trackId });
  }

  window.SPCBoyPlaylistController = Object.freeze({ reduceSelection });
})();
