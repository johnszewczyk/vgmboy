(() => {
  const BACKENDS = window.spcBoySB2?.playbackBackends;
  if (!Array.isArray(BACKENDS)) {
    throw new Error("Playback backend registry is unavailable from the SPCBOY SB2 native bridge.");
  }
  const CANDIDATES_BY_EXTENSION = new Map();

  function normalizeExtension(extension) {
    return String(extension || "").trim().replace(/^\.+/, "").toLowerCase();
  }

  function extensionForPath(filePath) {
    const fileName = String(filePath || "").split(/[\\/#]/).pop() || "";
    const dotIndex = fileName.lastIndexOf(".");
    return dotIndex > 0 ? normalizeExtension(fileName.slice(dotIndex + 1)) : "";
  }

  for (const backend of BACKENDS) {
    for (const extension of backend.extensions) {
      const normalizedExtension = normalizeExtension(extension);
      if (!normalizedExtension) continue;
      const candidates = [...(CANDIDATES_BY_EXTENSION.get(normalizedExtension) || [])];
      candidates.push(backend);
      CANDIDATES_BY_EXTENSION.set(normalizedExtension, Object.freeze(candidates));
    }
  }

  function candidatesForPath(filePath) {
    return candidatesForExtension(extensionForPath(filePath));
  }

  function candidatesForExtension(extension) {
    const normalizedExtension = normalizeExtension(extension);
    return CANDIDATES_BY_EXTENSION.get(normalizedExtension) || Object.freeze([]);
  }

  function backendForPath(filePath) {
    return candidatesForPath(filePath)[0] || null;
  }

  const conflicts = Object.freeze([...CANDIDATES_BY_EXTENSION]
    .filter(([, candidates]) => candidates.length > 1)
    .map(([extension, candidates]) => Object.freeze({ extension, candidates })));

  window.SB2PlaybackBackends = Object.freeze({
    all: BACKENDS,
    conflicts,
    normalizeExtension,
    extensionForPath,
    candidatesForExtension,
    forPath: backendForPath,
    candidatesForPath
  });
})();
