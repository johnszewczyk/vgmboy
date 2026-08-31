(() => {
  function reduceSelection({ playlist, selectedIds, anchorId }, trackId, { extend = false, range = false } = {}) {
    if (!playlist.some((track) => track.id === trackId)) return null;
    let nextIds;
    if (range && anchorId) {
      const anchorIndex = playlist.findIndex((track) => track.id === anchorId);
      const targetIndex = playlist.findIndex((track) => track.id === trackId);
      const start = Math.min(anchorIndex < 0 ? targetIndex : anchorIndex, targetIndex);
      const end = Math.max(anchorIndex < 0 ? targetIndex : anchorIndex, targetIndex);
      nextIds = playlist.slice(start, end + 1).map((track) => track.id);
    } else if (extend) {
      nextIds = selectedIds.includes(trackId)
        ? selectedIds.filter((id) => id !== trackId)
        : [...selectedIds, trackId];
    } else {
      nextIds = [trackId];
    }
    return Object.freeze({ selectedIds: nextIds, primaryId: nextIds.includes(trackId) ? trackId : (nextIds.at(-1) || null), anchorId: range ? anchorId : trackId });
  }

  window.SPCBoyPlaylistController = Object.freeze({ reduceSelection });
})();
