(() => {
  const RAW_BACKENDS = window.spcBoyWK?.playbackBackends;
  if (!Array.isArray(RAW_BACKENDS)) {
    throw new Error("Playback backend registry is unavailable from the SPCBoy WK native bridge.");
  }
  function normalizedExtension(value) {
    const source = String(value || "").trim().toLowerCase();
    const separator = source.lastIndexOf(".");
    return (separator >= 0 ? source.slice(separator + 1) : source).replace(/^\.+/, "");
  }

  const BACKENDS = Object.freeze(RAW_BACKENDS.map((backend) => Object.freeze({
    ...backend,
    extensions: Object.freeze((backend.extensions || []).map(normalizedExtension).filter(Boolean)),
    playbackSpeedExtensions: Object.freeze(
      (backend.playbackSpeedExtensions || []).map(normalizedExtension).filter(Boolean)
    )
  })));
  const CANDIDATES_BY_EXTENSION = new Map();

  for (const backend of BACKENDS) {
    for (const extension of backend.extensions) {
      const normalized = normalizedExtension(extension);
      if (!normalized) continue;
      const candidates = [...(CANDIDATES_BY_EXTENSION.get(normalized) || [])];
      candidates.push(backend);
      CANDIDATES_BY_EXTENSION.set(normalized, Object.freeze(candidates));
    }
  }

  function candidatesForPath(filePath) {
    const extension = normalizedExtension(filePath);
    return CANDIDATES_BY_EXTENSION.get(extension) || Object.freeze([]);
  }

  function backendForPath(filePath) {
    return candidatesForPath(filePath)[0] || null;
  }

  const conflicts = Object.freeze([...CANDIDATES_BY_EXTENSION]
    .filter(([, candidates]) => candidates.length > 1)
    .map(([extension, candidates]) => Object.freeze({ extension, candidates })));

  window.SPCBoyPlaybackBackends = Object.freeze({
    all: BACKENDS,
    conflicts,
    forPath: backendForPath,
    candidatesForPath
  });
})();
