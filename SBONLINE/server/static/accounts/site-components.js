(() => {
  function memberAvatar(profile, variant = "") {
    const avatar = document.createElement("span");
    avatar.className = `member-avatar ${variant}`.trim();
    avatar.setAttribute("aria-hidden", "true");
    if (profile?.avatarUrl) {
      const image = document.createElement("img");
      image.src = profile.avatarUrl;
      image.alt = "";
      image.loading = "lazy";
      image.decoding = "async";
      avatar.append(image);
    } else {
      const initials = document.createElement("span");
      initials.textContent = profile?.initials || "?";
      avatar.append(initials);
    }
    return avatar;
  }

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

  window.SiteComponents = Object.freeze({ memberAvatar, trackControls, trackDisplay, formatSiteTime, recordTime });
})();
