(() => {
  function trackControls(track, playerUrl) {
    const id = String(track?.trackId || track?.id || "");
    if (!id) return null;
    const title = String(track.title || id);
    const game = String(track.game || "");
    const consoleName = String(track.console || "");
    const duration = String(Number(track.durationSeconds) || 0);
    const href = new URL(playerUrl, window.location.href);
    href.searchParams.set("play", id);
    const controls = document.createElement("span");
    controls.className = "play-track-controls";
    const play = document.createElement("a");
    play.className = "play-track-now";
    play.dataset.sitePlayTrack = "";
    play.href = href.href;
    play.setAttribute("aria-label", `Play ${title} now`);
    play.title = "Play now";
    const assignTrackData = (element) => {
      element.dataset.trackId = id;
      element.dataset.trackTitle = title;
      element.dataset.trackGame = game;
      element.dataset.trackConsole = consoleName;
      element.dataset.trackDuration = duration;
    };
    assignTrackData(play);
    play.innerHTML = '<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M4 2.5v11L13 8z"/></svg>';
    const link = document.createElement("a");
    link.className = "play-track-link";
    link.dataset.sitePlayTrack = "";
    link.href = href.href;
    link.textContent = title;
    assignTrackData(link);
    controls.append(play, link);
    return controls;
  }

  function trackDisplay(track, playerUrl) {
    const controls = trackControls(track, playerUrl);
    if (!controls) return null;
    const display = document.createElement("div");
    display.className = "site-track-display";
    const metadata = document.createElement("span");
    metadata.className = "site-track-metadata";
    metadata.textContent = [track.game, track.console, track.artist].filter(Boolean).join(" · ");
    display.append(controls, metadata);
    return display;
  }

  function formatSiteTime(value) {
    const date = new Date(value);
    if (!value || Number.isNaN(date.getTime())) return "";
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: "America/Detroit",
      month: "short",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hour12: true,
    }).formatToParts(date);
    const values = Object.fromEntries(parts.map(({ type, value: part }) => [type, part]));
    return `${values.month}. ${values.day}, ${values.hour}:${values.minute} ${values.dayPeriod}`;
  }

  function recordTime(value, { className = "", label = "" } = {}) {
    const text = formatSiteTime(value);
    if (!text) return null;
    const time = document.createElement("time");
    time.className = `site-record-time ${className}`.trim();
    time.dateTime = String(value);
    time.textContent = `${label}${text}`;
    return time;
  }


  const commandHistory = [];
  const MAX_COMMAND_HISTORY = 120;
  let nextCommandId = 1;

  function recordCommand(type, details = {}) {
    const id = nextCommandId++;
    const start = (typeof performance !== "undefined" && performance.now) ? performance.now() : Date.now();
    const entry = {
      id,
      type: String(type || "unknown"),
      details: typeof details === "object" && details !== null ? { ...details } : { value: details },
      timestamp: Date.now(),
      durationMs: null,
      status: "pending",
    };

    commandHistory.push(entry);
    if (commandHistory.length > MAX_COMMAND_HISTORY) {
      commandHistory.shift();
    }

    let completed = false;
    const handle = {
      id,
      complete(status = "completed", extraDetails = null) {
        if (completed) return entry;
        completed = true;
        const end = (typeof performance !== "undefined" && performance.now) ? performance.now() : Date.now();
        entry.durationMs = Math.round((end - start) * 100) / 100;
        entry.status = status;
        if (extraDetails && typeof extraDetails === "object") {
          Object.assign(entry.details, extraDetails);
        }
        if (typeof document !== "undefined" && document.dispatchEvent) {
          try {
            document.dispatchEvent(new CustomEvent("site:command-completed", { detail: entry }));
          } catch {}
        }
        return entry;
      },
    };

    if (typeof document !== "undefined" && document.dispatchEvent) {
      try {
        document.dispatchEvent(new CustomEvent("site:command-recorded", { detail: entry }));
      } catch {}
    }

    return handle;
  }

  function getCommandHistory() {
    return [...commandHistory];
  }

  function getCommandSummary() {
    const total = commandHistory.length;
    if (!total) return { total: 0, averageMs: 0, maxMs: 0, slowCommands: [] };
    const completed = commandHistory.filter((c) => typeof c.durationMs === "number");
    const avg = completed.length
      ? Math.round(completed.reduce((sum, c) => sum + c.durationMs, 0) / completed.length * 10) / 10
      : 0;
    const max = completed.reduce((m, c) => Math.max(m, c.durationMs), 0);
    const slow = completed.filter((c) => c.durationMs > 100);
    return {
      total,
      completedCount: completed.length,
      averageMs: avg,
      maxMs: max,
      slowCount: slow.length,
      recent: commandHistory.slice(-10),
    };
  }

  function clearCommandHistory() {
    commandHistory.length = 0;
  }

  window.SiteCommands = Object.freeze({
    record: recordCommand,
    history: getCommandHistory,
    summary: getCommandSummary,
    clear: clearCommandHistory,
  });

  window.SiteComponents = Object.freeze({ trackControls, trackDisplay, formatSiteTime, recordTime });
})();
