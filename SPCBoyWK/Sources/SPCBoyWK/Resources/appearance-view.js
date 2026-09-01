(() => {
function create({ state, refs, escapeHtml, onSetRoutingPreference }) {
  function applyUISettings() {
    const rootStyle = document.documentElement.style;
    rootStyle.setProperty("--ui-font-size-pt", String(state.uiFontSizePt));
    rootStyle.setProperty("--app-font-family", state.applicationMonospace ? "var(--mono-font-family)" : "var(--ui-font-family)");
    rootStyle.setProperty("--sidebar-font-size-pt", String(state.sidebarFontSizePt));
    rootStyle.setProperty("--sidebar-text-color", state.sidebarTextColor);
    rootStyle.setProperty("--sidebar-font-family", state.sidebarMonospace || state.applicationMonospace ? "var(--mono-font-family)" : "var(--ui-font-family)");
    rootStyle.setProperty("--playlist-font-size-pt", String(state.playlistFontSizePt));
    rootStyle.setProperty("--playlist-text-color", state.playlistTextColor);
    rootStyle.setProperty("--playlist-font-family", state.playlistMonospace || state.applicationMonospace ? "var(--mono-font-family)" : "var(--ui-font-family)");
    rootStyle.setProperty("--playlist-header-font-weight", state.playlistHeaderBold ? "700" : "400");
    rootStyle.setProperty("--sidebar-width-percent", String(state.sidebarWidthPercent));
    rootStyle.setProperty("--accent", state.accentColor);
    rootStyle.setProperty("--item-spacing-rem", String(state.uiItemSpacingRem));
    rootStyle.setProperty("--column-resize-duration", `${state.autoResizeAnimationEnabled ? state.autoResizeAnimationMilliseconds : 0}ms`);
    rootStyle.setProperty("--selection-animation-duration", `${state.selectionAnimationEnabled ? state.selectionAnimationMilliseconds : 0}ms`);
  }

  function appearanceSettings() {
    return {
      uiItemSpacingRem: state.uiItemSpacingRem,
      sidebarWidthPercent: state.sidebarWidthPercent,
      sidebarFontSizePt: state.sidebarFontSizePt,
      sidebarTextColor: state.sidebarTextColor,
      sidebarMonospace: state.sidebarMonospace,
      sidebarPathCounts: state.sidebarPathCounts,
      playlistFontSizePt: state.playlistFontSizePt,
      playlistTextColor: state.playlistTextColor,
      playlistMonospace: state.playlistMonospace,
      applicationMonospace: state.applicationMonospace,
      playlistHeaderBold: state.playlistHeaderBold,
      accentColor: state.accentColor
    };
  }

  function formatArchiveCacheSummary(summary) {
    const size = `${(Number(summary?.byteCount || 0) / (1024 * 1024)).toFixed(1)} MB`;
    const limit = Number(summary?.limitBytes || state.archiveCacheLimitBytes || 0);
    const limitLabel = limit >= 1024 * 1024 * 1024
      ? `${(limit / (1024 * 1024 * 1024)).toFixed(limit % (1024 * 1024 * 1024) ? 1 : 0)} GB limit`
      : `${Math.round(limit / (1024 * 1024))} MB limit`;
    return `${size} • ${summary?.fileCount || 0} files • ${limitLabel}${summary?.partialCount ? ` • ${summary.partialCount} partial` : ""}${summary?.legacyFileCount ? ` • ${summary.legacyFileCount} legacy` : ""}`;
  }

  function renderRoutingConflicts() {
    const conflicts = window.SPCBoyPlaybackBackends?.conflicts || [];
    if (!conflicts.length) {
      refs.routingConflictsList.innerHTML = '<div class="options-help-text">No overlapping decoder extensions are registered. New plugins that overlap an existing format will appear here before their routing policy is applied.</div>';
      return;
    }
    refs.routingConflictsList.innerHTML = conflicts.map(({ extension, candidates }) => {
      const candidateNames = candidates.map((backend) => escapeHtml(backend.displayName || backend.id)).join(" → ");
      const preferredBackendId = state.routingPreferences[extension] || candidates[0]?.id;
      return `<label class="routing-conflict"><span><strong>${escapeHtml(extension)}</strong><small>${candidateNames}</small></span><select class="options-input" data-routing-extension="${escapeHtml(extension)}" aria-label="Decoder for ${escapeHtml(extension)}">${candidates.map((backend) => `<option value="${escapeHtml(backend.id)}" ${backend.id === preferredBackendId ? "selected" : ""}>${escapeHtml(backend.displayName || backend.id)}</option>`).join("")}</select></label>`;
    }).join("");
    refs.routingConflictsList.querySelectorAll("[data-routing-extension]").forEach((input) => {
      input.addEventListener("change", () => onSetRoutingPreference(input.dataset.routingExtension, input.value));
    });
  }

  return Object.freeze({
    applyUISettings,
    appearanceSettings,
    formatArchiveCacheSummary,
    renderRoutingConflicts
  });
}

window.SPCBoyAppearanceView = Object.freeze({ create });
})();
