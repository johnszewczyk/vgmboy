(() => {
function create({
  state,
  refs,
  expandedFolders,
  currentSidebarView,
  escapeHtml,
  resetSidebarContent,
  scheduleSelectionIndicators,
  selectBrowserNode,
  handleBrowserPrimaryClick,
  handleBrowserGesture,
  showSidebarContextMenu,
  moveBrowserSelection,
  setSelectedBrowserButton
}) {
  let browserClickTimer = 0;

  function findBrowserNode(nodes, targetPath) {
    for (const node of nodes) {
      if (node.path === targetPath) return node;
      const child = findBrowserNode(node.children || [], targetPath);
      if (child) return child;
    }
    return null;
  }

  function pathToNode(nodes, targetPath, lineage = []) {
    for (const node of nodes) {
      const nextLineage = [...lineage, node.path];
      if (node.path === targetPath) {
        return nextLineage;
      }

      const nested = pathToNode(node.children, targetPath, nextLineage);
      if (nested) {
        return nested;
      }
    }

    return null;
  }

  function ensureExpandedToSelection(tree = state.tree, selectedPath = state.selectedBrowserPath) {
    if (!selectedPath) {
      return;
    }

    const lineage = pathToNode(tree, selectedPath) ?? [];
    // Expand ancestors only. The selected folder itself must remain foldable.
    lineage.slice(0, -1).forEach((folderPath) => expandedFolders.add(folderPath));
  }

  function isNodeExpanded(node) {
    // The active filesystem root is the Folder View anchor. It must remain
    // expanded so folding descendants can never make the browser disappear.
    if (node.path === state.rootPath || node.alwaysExpanded) return true;
    if (state.sidebarQuery.trim()) {
      return true;
    }

    if (!node.children.length) {
      return false;
    }

    return expandedFolders.has(node.path);
  }

  function filteredTree() {
    const terms = state.sidebarQuery.trim().toLowerCase().split(/\s+/).filter(Boolean);
    if (!terms.length) {
      return currentSidebarView().view === "paths" ? state.databaseFileTree : state.tree;
    }

    function filterNode(node) {
      const filteredChildren = node.children.map(filterNode).filter(Boolean);
      const searchableText = `${node.name || ""} ${node.path || ""}`.toLowerCase();
      if (terms.every((term) => searchableText.includes(term)) || filteredChildren.length > 0) {
        return {
          ...node,
          children: filteredChildren
        };
      }
      return null;
    }

    const sourceTree = currentSidebarView().view === "paths" ? state.databaseFileTree : state.tree;
    const localMatches = sourceTree.map(filterNode).filter(Boolean);
    return localMatches;
  }

  function renderTreeNode(node, container) {
    const wrapper = document.createElement("div");
    wrapper.className = "tree-item";
    const button = document.createElement("button");
    const expanded = isNodeExpanded(node);
    button.dataset.browserPath = node.path;
    button.className = `tree-node${state.selectedBrowserPath === node.path ? " is-selected" : ""}`;
    if (state.selectedBrowserPath === node.path) setSelectedBrowserButton(button);
    button.classList.toggle("tree-file", node.kind === "file");
    button.setAttribute("aria-expanded", node.kind === "folder" ? String(expanded) : "false");
    button.innerHTML = `
    <span class="tree-disclosure">${node.kind === "folder" ? (expanded ? "▾" : "▸") : "·"}</span><span class="tree-label">${escapeHtml(node.name)}</span>
  `;
    button.addEventListener("click", (event) => {
      window.clearTimeout(browserClickTimer);
      selectBrowserNode(node, { focus: true, previewLeaf: false });
      if (event.detail > 1) return;
      browserClickTimer = window.setTimeout(() => void handleBrowserPrimaryClick(node), 220);
    });
    button.addEventListener("dblclick", (event) => {
      event.preventDefault();
      event.stopPropagation();
      window.clearTimeout(browserClickTimer);
      void handleBrowserGesture(node, "activate", true);
    });
    button.addEventListener("contextmenu", (event) => showSidebarContextMenu(node, event));
    button.addEventListener("keydown", (event) => {
      if (event.key === "ArrowDown" || event.key === "ArrowUp") {
        event.preventDefault();
        event.stopPropagation();
        moveBrowserSelection(event.key === "ArrowDown" ? 1 : -1);
        return;
      }
      if (event.key !== "Enter" && event.key !== " ") return;
      event.preventDefault();
      event.stopPropagation();
      if (event.key === "Enter") void handleBrowserGesture(node, "activate", true);
      else if (node.kind === "folder") void handleBrowserGesture(node, "disclosureClick", true);
    });

    wrapper.appendChild(button);

    if (node.kind === "folder" && node.children.length && expanded) {
      const group = document.createElement("div");
      group.className = "tree-group";
      node.children.forEach((child) => renderTreeNode(child, group));
      wrapper.appendChild(group);
    }

    container.appendChild(wrapper);
  }

  function renderTree() {
    const visibleTree = filteredTree();
    resetSidebarContent();
    setSelectedBrowserButton(null);
    if (visibleTree.length === 0) {
      const empty = document.createElement("div");
      empty.className = "empty sidebar-empty";
      empty.textContent = currentSidebarView().view === "paths"
        ? "No catalog paths match this view."
        : state.rootPath
          ? "No subfolders match this view."
          : "Choose Open Path to browse a local folder.";
      refs.treeRoot.appendChild(empty);
      scheduleSelectionIndicators();
      return;
    }

    ensureExpandedToSelection(visibleTree);
    visibleTree.forEach((node) => renderTreeNode(node, refs.treeRoot));
    scheduleSelectionIndicators();
  }

  return Object.freeze({
    findBrowserNode,
    filteredTree,
    renderTree
  });
}

window.SPCBoySidebarTree = Object.freeze({ create });
})();
