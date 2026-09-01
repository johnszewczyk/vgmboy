(() => {
function create({
  state,
  refs,
  expandedFolders,
  persistSettings,
  databaseRowsToPlaylistTracks,
  applyFolderSelection,
  playVisibleTrack,
  renderTree,
  syncTreeSelection,
  filteredTree,
  findBrowserNode,
  appendPlaylistTracks
}) {
  let browserSelectionGeneration = 0;

  async function loadBrowserChildren(node) {
    if (node.kind !== "folder" || node.childrenLoaded) return;
    node.children = await window.spcBoyWK.listFolder(node.path);
    node.childrenLoaded = true;
  }

  function catalogPlaylistSelection(rows, selectedPath) {
    if (rows?.stale === true) return null;
    return {
      selectedFolderPath: selectedPath,
      selectedBrowserPath: state.selectedBrowserPath,
      playlist: databaseRowsToPlaylistTracks(rows, [])
    };
  }

  async function loadBrowserSelection(node) {
    if (node.catalogFile) {
      return catalogPlaylistSelection(await window.spcBoyWK.databaseFileTracks([node.catalogFile]), node.catalogFile.path);
    }
    if (node.catalogFolder) {
      return catalogPlaylistSelection(await window.spcBoyWK.databaseFolderTracks([node.catalogFolder]), node.catalogFolder.folderPath);
    }
    const selection = node.kind === "folder"
      ? window.spcBoyWK.selectFolder(node.path)
      : window.spcBoyWK.selectFile(node.path);
    return selection.then((value) => value?.stale === true ? null : value);
  }

  async function activateBrowserNode(node, { playNow = true } = {}) {
    const generation = ++browserSelectionGeneration;
    try {
      state.selectedBrowserPath = node.path;
      persistSettings();
      if (node.kind === "folder") {
        expandedFolders.add(node.path);
        await loadBrowserChildren(node);
      }
      const selection = await loadBrowserSelection(node);
      if (!selection
          || generation !== browserSelectionGeneration
          || state.selectedBrowserPath !== node.path) return;
      applyFolderSelection(selection);
      const target = selection.playlist?.[0];
      if (playNow && target) await playVisibleTrack(target.id, 0);
    } catch (error) {
      console.error(error);
    }
  }

  async function previewBrowserLeaf(node) {
    const generation = ++browserSelectionGeneration;
    try {
      const selection = await loadBrowserSelection(node);
      if (!selection) return;
      if (generation !== browserSelectionGeneration || state.selectedBrowserPath !== node.path) return;
      applyFolderSelection(selection);
    } catch (error) {
      console.error(error);
    }
  }

  async function handleBrowserPrimaryClick(node) {
    await handleBrowserGesture(node, "primaryClick", state.selectedBrowserPath === node.path);
  }

  async function handleBrowserGesture(node, gesture, wasSelected = false) {
    const intent = await window.SPCBoySidebarController.resolveIntent(node, gesture, wasSelected);
    if (intent === "preview") await previewBrowserLeaf(node);
    else if (intent === "toggleExpansion") await toggleBrowserNode(node);
    else if (intent === "activate") await activateBrowserNode(node);
  }

  function selectBrowserNode(node, { focus = false, previewLeaf = true } = {}) {
    if (state.selectedBrowserPath !== node.path) {
      browserSelectionGeneration += 1;
    }
    state.selectedBrowserPath = node.path;
    persistSettings();
    syncTreeSelection();
    if (focus) refs.treeRoot.querySelector(`[data-browser-path="${CSS.escape(node.path)}"]`)?.focus();
    if (previewLeaf && node.kind === "file") void previewBrowserLeaf(node);
  }

  function visibleBrowserNodes() {
    return [...refs.treeRoot.querySelectorAll(".tree-node")]
      .map((button) => findBrowserNode(filteredTree(), button.dataset.browserPath))
      .filter(Boolean);
  }

  function moveBrowserSelection(delta) {
    const nodes = visibleBrowserNodes();
    if (!nodes.length) return;
    const currentIndex = nodes.findIndex((node) => node.path === state.selectedBrowserPath);
    const nextIndex = currentIndex < 0
      ? (delta >= 0 ? 0 : nodes.length - 1)
      : Math.max(0, Math.min(nodes.length - 1, currentIndex + delta));
    selectBrowserNode(nodes[nextIndex], { focus: true });
  }

  async function queueBrowserNode(node) {
    const selection = await loadBrowserSelection(node);
    if (!selection) return;
    appendPlaylistTracks(Array.isArray(selection.playlist) ? selection.playlist : [], node.path);
  }

  async function toggleBrowserNode(node) {
    if (node.kind !== "folder") return;
    if (node.path === state.rootPath) return;
    if (expandedFolders.has(node.path)) expandedFolders.delete(node.path);
    else {
      expandedFolders.add(node.path);
      await loadBrowserChildren(node);
    }
    renderTree();
    syncTreeSelection();
    refs.treeRoot.querySelector(`[data-browser-path="${CSS.escape(node.path)}"]`)?.focus();
  }

  return Object.freeze({
    activateBrowserNode,
    catalogPlaylistSelection,
    handleBrowserGesture,
    handleBrowserPrimaryClick,
    loadBrowserChildren,
    loadBrowserSelection,
    moveBrowserSelection,
    previewBrowserLeaf,
    queueBrowserNode,
    selectBrowserNode,
    toggleBrowserNode,
    visibleBrowserNodes
  });
}

window.SPCBoyBrowserActions = Object.freeze({ create });
})();
