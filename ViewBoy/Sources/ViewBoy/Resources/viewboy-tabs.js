(() => {
const app = window.SPCBoyApp;
const { state, refs } = app;
const toolbar = document.getElementById("playlist-tabs-toolbar");
const strip = document.getElementById("playlist-tabs");
const tabs = [];
let activeID = null;
let ready = false;
let saveTimer = 0;
let saveChain = Promise.resolve();

function makeID() {
  return globalThis.crypto?.randomUUID?.()
    || `viewboy-${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

function activeTab() {
  return tabs.find((tab) => tab.id === activeID) || null;
}

function titleForPlaylist() {
  const game = state.playlist?.[0]?.game;
  return game && game !== "—" ? String(game) : "Playlist";
}

function snapshotCurrent(tab = activeTab()) {
  if (!tab) return false;
  const previousTitle = tab.title;
  tab.playlist = [...(state.playlist || [])];
  tab.selectedTrackId = state.selectedTrackId || null;
  tab.selectedTrackIds = [...(state.selectedTrackIds || [])];
  tab.scrollTop = Math.max(0, Number(refs.playlistBodyWrap?.scrollTop) || 0);
  if (!tab.pinnedTitle) tab.title = titleForPlaylist();
  return tab.title !== previousTitle;
}

function paint() {
  toolbar.classList.toggle("is-hidden", tabs.length <= 1);
  strip.replaceChildren();
  if (tabs.length <= 1) return;
  for (const tab of tabs) {
    const item = document.createElement("div");
    item.className = `playlist-tab${tab.id === activeID ? " is-active" : ""}`;
    const select = document.createElement("button");
    select.type = "button";
    select.className = "playlist-tab-select";
    select.textContent = tab.title;
    select.title = tab.title;
    select.setAttribute("role", "tab");
    select.setAttribute("aria-selected", String(tab.id === activeID));
    select.tabIndex = tab.id === activeID ? 0 : -1;
    select.addEventListener("click", () => activate(tab.id));
    const close = document.createElement("button");
    close.type = "button";
    close.className = "playlist-tab-close";
    close.textContent = "×";
    close.title = `Close ${tab.title}`;
    close.setAttribute("aria-label", close.title);
    close.addEventListener("click", () => closeTab(tab.id));
    item.append(select, close);
    strip.appendChild(item);
  }
}

function queueSave(titleChanged = false) {
  if (!ready || window.spcBoyWK?.isOptionsWindow) return;
  window.clearTimeout(saveTimer);
  saveTimer = window.setTimeout(() => {
    saveTimer = 0;
    const payload = {
      version: 1,
      activeID,
      tabs: tabs.map(({ id, title, playlist, selectedTrackId, selectedTrackIds, scrollTop }) => ({
        id, title, playlist, selectedTrackId, selectedTrackIds, scrollTop
      }))
    };
    saveChain = saveChain.catch(() => {})
      .then(() => window.spcBoyWK.playlistTabsSave(payload))
      .catch((error) => console.error("[ViewBoy] playlist tabs save failed", error));
  }, 500);
  if (titleChanged) paint();
}

function scheduleSave() {
  if (!ready || window.spcBoyWK?.isOptionsWindow) return;
  queueSave(snapshotCurrent());
}

function scheduleSelectionSave() {
  if (!ready || window.spcBoyWK?.isOptionsWindow) return;
  const tab = activeTab();
  if (!tab) return;
  tab.selectedTrackId = state.selectedTrackId || null;
  tab.selectedTrackIds = [...(state.selectedTrackIds || [])];
  queueSave();
}

function scheduleScrollSave() {
  if (!ready || window.spcBoyWK?.isOptionsWindow) return;
  const tab = activeTab();
  if (!tab) return;
  tab.scrollTop = Math.max(0, Number(refs.playlistBodyWrap?.scrollTop) || 0);
  queueSave();
}

function restoreView(tab) {
  activeID = tab.id;
  state.playlist = [...tab.playlist];
  state.selectedTrackId = tab.selectedTrackId;
  state.selectedTrackIds = [...tab.selectedTrackIds];
  state.lastSelectedTrackId = tab.selectedTrackId;
  app.ui.renderPlaylist();
  app.playback.updateTimingSummary();
  app.playback.updatePlaybackReadout();
  if (refs.playlistBodyWrap) refs.playlistBodyWrap.scrollTop = tab.scrollTop;
  paint();
}

function activate(id) {
  const tab = tabs.find((entry) => entry.id === id);
  if (!tab || id === activeID) return false;
  snapshotCurrent();
  window.spcBoyWK?.catalogSessionInvalidate?.("playlist")
    .catch((error) => console.error("[ViewBoy] tab switch invalidation failed", error));
  restoreView(tab);
  scheduleSave();
  return true;
}

function createTab({ duplicateActive = true } = {}) {
  if (tabs.length >= 64) return null;
  snapshotCurrent();
  const source = activeTab();
  window.spcBoyWK?.catalogSessionInvalidate?.("playlist")
    .catch((error) => console.error("[ViewBoy] tab creation invalidation failed", error));
  const tab = {
    id: makeID(),
    title: duplicateActive && source ? source.title : "Playlist",
    pinnedTitle: false,
    playlist: duplicateActive && source ? [...source.playlist] : [],
    selectedTrackId: duplicateActive && source ? source.selectedTrackId : null,
    selectedTrackIds: duplicateActive && source ? [...source.selectedTrackIds] : [],
    scrollTop: duplicateActive && source ? source.scrollTop : 0
  };
  tabs.push(tab);
  restoreView(tab);
  scheduleSave();
  return tab;
}

function closeTab(id = activeID) {
  if (tabs.length <= 1) {
    window.spcBoyWK?.closeMainWindow?.();
    return false;
  }
  const index = tabs.findIndex((tab) => tab.id === id);
  if (index < 0) return false;
  const wasActive = id === activeID;
  if (wasActive) window.spcBoyWK?.catalogSessionInvalidate?.("playlist")
    .catch((error) => console.error("[ViewBoy] tab close invalidation failed", error));
  if (wasActive) snapshotCurrent();
  tabs.splice(index, 1);
  if (wasActive) restoreView(tabs[Math.min(index, tabs.length - 1)]);
  scheduleSave();
  return true;
}

function restoreSaved(value) {
  if (value?.version !== 1 || !Array.isArray(value.tabs) || !value.tabs.length) return false;
  const seen = new Set();
  for (const entry of value.tabs.slice(0, 64)) {
    if (!entry || typeof entry.id !== "string" || !entry.id || seen.has(entry.id)) continue;
    seen.add(entry.id);
    tabs.push({
      id: entry.id,
      title: String(entry.title || "Playlist"),
      pinnedTitle: false,
      playlist: Array.isArray(entry.playlist) ? entry.playlist : [],
      selectedTrackId: typeof entry.selectedTrackId === "string" ? entry.selectedTrackId : null,
      selectedTrackIds: Array.isArray(entry.selectedTrackIds) ? entry.selectedTrackIds : [],
      scrollTop: Math.max(0, Number(entry.scrollTop) || 0)
    });
  }
  if (!tabs.length) return false;
  restoreView(tabs.find((tab) => tab.id === value.activeID) || tabs[0]);
  return true;
}

const bootstrap = app.ui.bootstrap;
app.ui.bootstrap = async (...args) => {
  await bootstrap(...args);
  if (window.spcBoyWK?.isOptionsWindow) return;
  let saved = null;
  try { saved = await window.spcBoyWK?.playlistTabsLoad?.(); }
  catch (error) { console.error("[ViewBoy] playlist tabs load failed", error); }
  if (!restoreSaved(saved)) {
    tabs.push({ id: makeID(), title: titleForPlaylist(), pinnedTitle: false,
      playlist: [...state.playlist], selectedTrackId: state.selectedTrackId || null,
      selectedTrackIds: [...(state.selectedTrackIds || [])], scrollTop: 0 });
    activeID = tabs[0].id;
  }
  ready = true;
  paint();
  scheduleSave();
};

refs.playlistBodyWrap?.addEventListener("scroll", scheduleScrollSave, { passive: true });
app.ui.createPlaylistTab = createTab;
app.ui.closePlaylistTab = closeTab;
app.ui.activatePlaylistTabAtIndex = (index) => tabs[index] ? activate(tabs[index].id) : false;
window.ViewBoyTabs = { scheduleSave, scheduleSelectionSave };
})();
