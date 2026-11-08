(() => {
  const player = document.querySelector("#site-player");
  if (!player) return;

  const favoriteURL = player.dataset.favoritesUrl;
  const status = document.querySelector("#site-favorites-status");
  const pending = new Set();

  function favoriteLabel(button, favorite) {
    const title = button.dataset.favoriteTitle || "this item";
    const kind = button.dataset.favoriteKind === "album" ? "album" : "track";
    const action = favorite ? "Remove" : "Add";
    const phrase = favorite ? "from" : "to";
    button.setAttribute("aria-pressed", String(favorite));
    button.setAttribute("aria-label", `${action} ${title} ${kind === "album" ? "album " : ""}${phrase} favorites`);
    button.title = `${action} ${title} ${kind === "album" ? "album " : ""}${phrase} favorites`;
    button.classList.toggle("is-active", favorite);
    button.classList.toggle("is-favorite", favorite);
  }

  function syncAllFromLists(trackIDs, albumIDs) {
    for (const button of document.querySelectorAll("[data-site-favorite-toggle]")) {
      const ids = button.dataset.favoriteKind === "album" ? albumIDs : trackIDs;
      favoriteLabel(button, ids.has(button.dataset.favoriteId));
    }
  }

  document.addEventListener("click", async (event) => {
    const button = event.target instanceof Element ? event.target.closest("button[data-site-favorite-toggle]") : null;
    if (!button || button.disabled) return;
    event.preventDefault();

    const kind = button.dataset.favoriteKind === "album" ? "album" : "track";
    const id = button.dataset.favoriteId;
    if (!id) return;
    const key = `${kind}:${id}`;
    if (pending.has(key)) return;
    const favorite = button.getAttribute("aria-pressed") !== "true";
    pending.add(key);
    const peers = [...document.querySelectorAll("[data-site-favorite-toggle]")]
      .filter((item) => item.dataset.favoriteKind === kind && item.dataset.favoriteId === id);
    peers.forEach((item) => { item.disabled = true; item.setAttribute("aria-busy", "true"); });

    try {
      const payload = kind === "album"
        ? { albumId: id, favorite }
        : favorite ? { trackId: id, favorite } : { removeTrackIds: [id] };
      const csrf = document.querySelector("#site-player-csrf [name='csrfmiddlewaretoken']")?.value || "";
      const response = await fetch(favoriteURL, {
        method: "POST",
        credentials: "same-origin",
        headers: { "Content-Type": "application/json", "X-CSRFToken": csrf, Accept: "application/json" },
        body: JSON.stringify(payload),
      });
      const result = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(result.error || "The favorite could not be updated.");

      if (Array.isArray(result.trackIds) && Array.isArray(result.albumIds)) {
        const trackIDs = new Set(result.trackIds);
        const albumIDs = new Set(result.albumIds);
        syncAllFromLists(trackIDs, albumIDs);
        document.dispatchEvent(new CustomEvent("site:favorites-updated", { detail: result }));
      } else {
        peers.forEach((item) => favoriteLabel(item, favorite));
        document.dispatchEvent(new CustomEvent("site:favorites-updated", {
          detail: kind === "album" ? { albumId: id, favorite } : { trackId: id, favorite },
        }));
      }

      if (!favorite && button.closest("[data-remove-on-unfavorite]")) {
        const row = button.closest("[data-favorite-swipe]");
        row?.classList.add("is-removing-favorite");
        window.setTimeout(() => row?.remove(), 200);
      }
      if (status) status.textContent = favorite ? "Added to favorites." : "Removed from favorites.";
    } catch (error) {
      if (status) status.textContent = error.message || "The favorite could not be updated.";
    } finally {
      pending.delete(key);
      peers.forEach((item) => { item.disabled = false; item.removeAttribute("aria-busy"); });
    }
  });

  let touchStart = null;
  let clearSuppressedClick = 0;
  let clearSwipeHint = 0;
  document.addEventListener("pointerdown", (event) => {
    const target = event.target instanceof Element ? event.target : null;
    const row = target?.closest("[data-favorite-swipe]");
    if (!row) {
      document.querySelectorAll("[data-favorite-swipe].is-revealed").forEach((other) => other.classList.remove("is-revealed"));
      touchStart = null;
      return;
    }
    if (target?.closest("[data-site-favorite-toggle]")) return;
    if (row.classList.contains("is-removing-favorite")) return;
    document.querySelectorAll("[data-favorite-swipe].is-revealed").forEach((other) => {
      if (other !== row) other.classList.remove("is-revealed");
    });
    if (event.pointerType !== "touch" || !event.isPrimary) return;
    const width = row.querySelector(".site-favorite-swipe-action")?.getBoundingClientRect().width || 52;
    const baseOffset = row.classList.contains("is-revealed") ? -width : 0;
    window.clearTimeout(clearSwipeHint);
    document.querySelectorAll("[data-favorite-swipe].is-swipe-hint").forEach((other) => {
      if (other !== row) other.classList.remove("is-swipe-hint");
    });
    touchStart = {
      row,
      x: event.clientX,
      y: event.clientY,
      pointerId: event.pointerId,
      baseOffset,
      width,
      offset: baseOffset,
    };
    if (baseOffset === 0) {
      row.classList.add("is-swipe-hint");
      clearSwipeHint = window.setTimeout(() => row.classList.remove("is-swipe-hint"), 260);
    }
  }, { passive: true });

  window.addEventListener("pointermove", (event) => {
    if (!touchStart || event.pointerId !== touchStart.pointerId) return;
    const deltaX = event.clientX - touchStart.x;
    const deltaY = event.clientY - touchStart.y;
    const horizontalDistance = Math.abs(deltaX);
    const verticalDistance = Math.abs(deltaY);

    // Start tracking from the first horizontal pixel. Give vertical scrolling
    // a little room to declare itself, so a small diagonal finger wobble does
    // not cancel a deliberate swipe before the row visibly follows it.
    if (verticalDistance >= 8 && verticalDistance > horizontalDistance * 1.25) {
      window.clearTimeout(clearSwipeHint);
      touchStart.row.classList.remove("is-dragging", "is-swipe-hint");
      touchStart.row.style.removeProperty("--favorite-swipe-offset");
      touchStart = null;
      return;
    }

    if (horizontalDistance > 0) {
      window.clearTimeout(clearSwipeHint);
      touchStart.row.classList.remove("is-swipe-hint");
      touchStart.row.classList.add("is-dragging");
    }
    touchStart.offset = Math.max(-touchStart.width, Math.min(0, touchStart.baseOffset + deltaX));
    touchStart.row.style.setProperty("--favorite-swipe-offset", `${touchStart.offset}px`);
  }, { passive: true });

  window.addEventListener("pointerup", (event) => {
    if (!touchStart || event.pointerId !== touchStart.pointerId) return;
    const { row, x, baseOffset, width } = touchStart;
    touchStart = null;
    const deltaX = event.clientX - x;
    const tracking = Math.abs(deltaX) > 0;
    const offset = Math.max(-width, Math.min(0, baseOffset + deltaX));
    row.classList.remove("is-dragging");
    row.style.removeProperty("--favorite-swipe-offset");
    if (!tracking) return;
    const wasRevealed = baseOffset < 0;
    const shouldReveal = offset <= -(width * 0.45);
    row.classList.toggle("is-revealed", shouldReveal);
    if (shouldReveal === wasRevealed && Math.abs(deltaX) < 8) return;
    row.dataset.swipeMoved = "true";
    window.clearTimeout(clearSuppressedClick);
    clearSuppressedClick = window.setTimeout(() => delete row.dataset.swipeMoved, 300);
  }, { passive: true });

  window.addEventListener("pointercancel", (event) => {
    if (!touchStart || event.pointerId !== touchStart.pointerId) return;
    window.clearTimeout(clearSwipeHint);
    touchStart.row.classList.remove("is-dragging", "is-swipe-hint");
    touchStart.row.style.removeProperty("--favorite-swipe-offset");
    touchStart = null;
  }, { passive: true });
  document.addEventListener("click", (event) => {
    const row = event.target instanceof Element ? event.target.closest("[data-favorite-swipe]") : null;
    if (row?.dataset.swipeMoved !== "true") return;
    delete row.dataset.swipeMoved;
    window.clearTimeout(clearSuppressedClick);
    event.preventDefault();
    event.stopImmediatePropagation();
  }, true);
})();
