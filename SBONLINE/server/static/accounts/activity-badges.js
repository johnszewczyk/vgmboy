(() => {
  const countKeyByNavKey = { history: "played" };
  const activityLabels = { history: "new plays" };
  const navLinks = [...document.querySelectorAll(".topnav a[data-nav-key], .mobile-site-drawer nav a")];
  const primaryLinks = navLinks.filter((link) => link.dataset.navKey);
  const keyByPath = new Map(primaryLinks.map((link) => [new URL(link.href, window.location.href).pathname, link.dataset.navKey]));
  const linksByKey = new Map();

  for (const link of navLinks) {
    const key = link.dataset.navKey || keyByPath.get(new URL(link.href, window.location.href).pathname);
    if (!countKeyByNavKey[key]) continue;
    link.dataset.navKey = key;
    link.dataset.activityOriginalLabel = link.textContent.trim();
    if (!linksByKey.has(key)) linksByKey.set(key, []);
    linksByKey.get(key).push(link);

    const badge = document.createElement("span");
    badge.className = "activity-badge";
    badge.dataset.activityBadge = "";
    badge.setAttribute("aria-hidden", "true");
    badge.hidden = true;
    link.append(badge);
  }

  if (!linksByKey.size) return;

  function updateBadges(counts) {
    const activeKey = keyByPath.get(window.location.pathname);
    for (const [key, links] of linksByKey) {
      const count = key === activeKey ? 0 : Math.max(0, Number(counts[countKeyByNavKey[key]]) || 0);
      const badgeText = count > 99 ? "99+" : String(count);
      for (const link of links) {
        const badge = link.querySelector("[data-activity-badge]");
        if (!badge) continue;
        badge.textContent = badgeText;
        badge.hidden = count === 0;
        if (count > 0) {
          link.setAttribute("aria-label", `${link.dataset.activityOriginalLabel}, ${count} ${activityLabels[key]}`);
        } else {
          link.removeAttribute("aria-label");
        }
      }
    }
  }

  let pending = false;
  async function refreshBadges() {
    if (pending || document.visibilityState === "hidden") return;
    pending = true;
    try {
      const response = await fetch("/activity/badges.json", {
        credentials: "same-origin",
        cache: "no-store",
        headers: { Accept: "application/json" },
      });
      if (!response.ok) return;
      const payload = await response.json();
      if (payload.counts && typeof payload.counts === "object") updateBadges(payload.counts);
    } catch {
      // Navigation remains usable when badge refresh is unavailable.
    } finally {
      pending = false;
    }
  }

  document.addEventListener("site:navigated", refreshBadges);
  document.addEventListener("visibilitychange", refreshBadges);
  window.setInterval(refreshBadges, 20000);
  refreshBadges();
})();
