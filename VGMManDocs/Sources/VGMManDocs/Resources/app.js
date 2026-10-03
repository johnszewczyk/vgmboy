(function () {
  "use strict";

  const $ = (selector) => document.querySelector(selector);
  const ui = {
    tree: $("#tree"),
    search: $("#search"),
    document: $("#document"),
    edit: $("#edit-document"),
    newDocument: $("#new-document"),
    crumbOwner: $("#crumb-owner"),
    liveStatus: $("#live-status"),
    sourceLabel: $("#source-label"),
    drawer: $("#editor-drawer"),
    backdrop: $("#editor-backdrop"),
    editorTitle: $("#editor-title"),
    editor: $("#markdown-source"),
    save: $("#save-document"),
    close: $("#close-editor"),
    cancel: $("#cancel-editor"),
    reload: $("#reload-editor"),
    conflict: $("#editor-conflict"),
    saveStatus: $("#save-status"),
    toast: $("#toast"),
  };

  const state = {
    documents: [],
    selectedPath: "",
    currentDocument: null,
    editorOpen: false,
    editorPath: "",
    editorBaseMarkdown: "",
    editorBaseVersion: "",
    editorConflict: false,
    treeExpanded: new Set(),
    treeInitialized: false,
    pending: new Map(),
    nextRequest: 1,
    toastTimer: null,
  };

  function native(method, values = {}) {
    return new Promise((resolve, reject) => {
      const id = String(state.nextRequest++);
      state.pending.set(id, { resolve, reject });
      window.webkit.messageHandlers.vgmManDocs.postMessage({ id, method, ...values });
      window.setTimeout(() => {
        if (!state.pending.has(id)) return;
        state.pending.delete(id);
        reject(new Error("VGMManDocs did not answer the request."));
      }, 30000);
    });
  }

  function showToast(message, isError = false) {
    window.clearTimeout(state.toastTimer);
    ui.toast.textContent = message;
    ui.toast.classList.toggle("is-error", isError);
    ui.toast.classList.add("is-visible");
    state.toastTimer = window.setTimeout(() => ui.toast.classList.remove("is-visible"), 2600);
  }

  function showPageError(message) {
    const panel = document.createElement("div");
    panel.className = "empty-state";
    const heading = document.createElement("strong");
    heading.textContent = "Unable to open this document";
    const detail = document.createElement("span");
    detail.textContent = message;
    panel.append(heading, detail);
    ui.document.replaceChildren(panel);
  }

  function prettyName(value) {
    return value.replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/[-_]/g, " ");
  }

  function insertIntoTree(root, path, title) {
    const parts = path.split("/").filter(Boolean);
    let parent = root;
    for (let index = 0; index < parts.length; index += 1) {
      const part = parts[index];
      const leaf = index === parts.length - 1;
      const key = leaf ? parts.slice(0, index + 1).join("/") : `folder:${parts.slice(0, index + 1).join("/")}`;
      if (!parent.children.has(key)) {
        parent.children.set(key, {
          id: parts.slice(0, index + 1).join("/"),
          name: leaf ? title : prettyName(part),
          path: leaf ? parts.slice(0, index + 1).join("/") : "",
          kind: leaf ? "document" : "folder",
          children: new Map(),
        });
      }
      parent = parent.children.get(key);
    }
  }

  function buildTree() {
    const root = { children: new Map() };
    state.documents.forEach((doc) => insertIntoTree(root, doc.path, doc.title));
    return Array.from(root.children.values()).sort((a, b) => a.name.localeCompare(b.name));
  }

  function renderTree() {
    const filter = ui.search.value.trim().toLocaleLowerCase();
    ui.tree.replaceChildren();
    if (state.documents.length === 0) {
      const empty = document.createElement("div");
      empty.className = "tree-empty";
      empty.textContent = "No Markdown documents found.";
      ui.tree.append(empty);
      return;
    }

    const createNode = (node, level = 0) => {
      if (node.kind === "document") {
        if (filter && !`${node.name} ${node.path}`.toLocaleLowerCase().includes(filter)) return null;
        const button = document.createElement("button");
        button.type = "button";
        button.className = `tree-leaf${state.selectedPath === node.path ? " is-active" : ""}`;
        button.setAttribute("role", "treeitem");
        button.dataset.path = node.path;
        const icon = document.createElement("span");
        icon.className = "tree-leaf-icon";
        icon.textContent = "▤";
        const label = document.createElement("span");
        label.className = "tree-leaf-label";
        label.textContent = node.name;
        button.append(icon, label);
        button.addEventListener("click", () => openDocument(node.path));
        return button;
      }

      const children = Array.from(node.children.values()).sort((a, b) => a.name.localeCompare(b.name));
      const renderedChildren = children.map((child) => createNode(child, level + 1)).filter(Boolean);
      if (!renderedChildren.length) return null;
      const wrapper = document.createElement("div");
      wrapper.className = level === 0 ? "tree-group" : "tree-subfolder";
      const button = document.createElement("button");
      button.type = "button";
      button.className = "tree-folder-button";
      button.setAttribute("role", "treeitem");
      const expanded = filter || state.treeExpanded.has(node.id) || level === 0 && !state.treeInitialized;
      button.setAttribute("aria-expanded", String(Boolean(expanded)));
      const chevron = document.createElement("span");
      chevron.className = "folder-chevron";
      chevron.textContent = "›";
      const folderIcon = document.createElement("span");
      folderIcon.className = "tree-folder-icon";
      folderIcon.textContent = level === 0 ? "◫" : "▱";
      const label = document.createElement("span");
      label.textContent = node.name;
      button.append(chevron, folderIcon, label);
      const childrenWrap = document.createElement("div");
      childrenWrap.className = `tree-children${expanded ? "" : " is-collapsed"}`;
      const inner = document.createElement("div");
      inner.className = "tree-children-inner";
      renderedChildren.forEach((child) => inner.append(child));
      childrenWrap.append(inner);
      button.addEventListener("click", () => {
        if (state.treeExpanded.has(node.id)) state.treeExpanded.delete(node.id);
        else state.treeExpanded.add(node.id);
        state.treeInitialized = true;
        renderTree();
      });
      wrapper.append(button, childrenWrap);
      return wrapper;
    };

    buildTree().map((node) => createNode(node)).filter(Boolean).forEach((node) => ui.tree.append(node));
    state.treeInitialized = true;
    if (!ui.tree.childElementCount) {
      const empty = document.createElement("div");
      empty.className = "tree-empty";
      empty.textContent = "No documents match this filter.";
      ui.tree.append(empty);
    }
  }

  function setOwner(path) {
    const owner = path.split("/")[0] || "Documentation";
    ui.crumbOwner.textContent = prettyName(owner);
  }

  function renderDocument(doc) {
    ui.document.replaceChildren();
    const owner = document.createElement("p");
    owner.className = "document-kicker";
    owner.textContent = prettyName(doc.path.split("/")[0] || "Documentation");
    const rendered = document.createElement("div");
    rendered.className = "markdown-body";
    rendered.innerHTML = window.vgmManDocsRenderMarkdown(doc.markdown, {
      documentFileURL: doc.documentFileURL,
      markdownRootURL: state.markdownRootURL,
      projectRootURL: state.projectRootURL,
    });
    const firstParagraph = rendered.querySelector("p");
    if (firstParagraph) firstParagraph.classList.add("doc-intro");
    ui.document.append(owner, rendered);
    ui.edit.disabled = false;
  }

  async function openDocument(path, anchor = "") {
    try {
      const doc = await native("read", { path });
      state.selectedPath = doc.path;
      state.currentDocument = doc;
      state.treeExpanded.add(doc.path.split("/")[0]);
      setOwner(doc.path);
      renderTree();
      renderDocument(doc);
      if (anchor) {
        requestAnimationFrame(() => document.getElementById(anchor)?.scrollIntoView({ behavior: "smooth", block: "start" }));
      } else {
        ui.document.scrollTop = 0;
      }
    } catch (error) {
      showPageError(error.message);
      showToast(error.message, true);
    }
  }

  function openEditor() {
    if (!state.currentDocument) return;
    state.editorOpen = true;
    state.editorPath = state.currentDocument.path;
    state.editorBaseMarkdown = state.currentDocument.markdown;
    state.editorBaseVersion = state.currentDocument.version;
    state.editorConflict = false;
    ui.editor.value = state.editorBaseMarkdown;
    ui.editorTitle.textContent = state.currentDocument.title;
    ui.editor.setAttribute("data-path", state.editorPath);
    ui.conflict.hidden = true;
    setSaveStatus("Markdown source");
    document.body.classList.add("editor-open");
    ui.drawer.setAttribute("aria-hidden", "false");
    ui.backdrop.setAttribute("aria-hidden", "false");
    window.setTimeout(() => ui.editor.focus(), 220);
  }

  function closeEditor() {
    state.editorOpen = false;
    document.body.classList.remove("editor-open");
    ui.drawer.setAttribute("aria-hidden", "true");
    ui.backdrop.setAttribute("aria-hidden", "true");
  }

  function setSaveStatus(message, isError = false) {
    ui.saveStatus.textContent = message;
    ui.saveStatus.classList.toggle("is-error", isError);
  }

  async function saveEditor() {
    if (!state.editorOpen || state.editorConflict) return;
    ui.save.disabled = true;
    setSaveStatus("Saving…");
    try {
      const result = await native("save", {
        path: state.editorPath,
        markdown: ui.editor.value,
        expectedVersion: state.editorBaseVersion,
      });
      state.editorBaseMarkdown = result.markdown;
      state.editorBaseVersion = result.version;
      if (state.currentDocument?.path === result.path) {
        state.currentDocument.markdown = result.markdown;
        state.currentDocument.version = result.version;
        state.currentDocument.documentFileURL = result.documentFileURL;
        state.currentDocument.title = result.markdown.match(/^#\s+(.+)$/m)?.[1]?.trim() || state.currentDocument.title;
        renderDocument(state.currentDocument);
        renderTree();
      }
      setSaveStatus("Saved to Docs/md");
      showToast("Markdown saved.");
      window.setTimeout(() => { if (state.editorOpen) closeEditor(); }, 300);
    } catch (error) {
      state.editorConflict = /changed on disk/i.test(error.message);
      if (state.editorConflict) ui.conflict.hidden = false;
      setSaveStatus(error.message, true);
    } finally {
      ui.save.disabled = false;
    }
  }

  async function reloadEditor() {
    try {
      const doc = await native("read", { path: state.editorPath });
      state.editorBaseMarkdown = doc.markdown;
      state.editorBaseVersion = doc.version;
      state.editorConflict = false;
      ui.editor.value = doc.markdown;
      ui.conflict.hidden = true;
      setSaveStatus("Loaded latest version");
      if (state.selectedPath === doc.path) {
        state.currentDocument = doc;
        renderDocument(doc);
      }
    } catch (error) {
      setSaveStatus(error.message, true);
    }
  }

  async function createDocument() {
    const title = window.prompt("New document title");
    if (!title?.trim()) return;
    const activeOwner = state.selectedPath.split("/")[0] || "VGMMan";
    const slug = title.trim().toLocaleLowerCase().replace(/[^\p{L}\p{N}]+/gu, "-").replace(/^-|-$/g, "") || "document";
    const path = `${activeOwner}/${slug}.md`;
    try {
      const created = await native("create", { path, markdown: `# ${title.trim()}\n\n` });
      state.currentDocument = created;
      state.selectedPath = created.path;
      await refreshFromDisk();
      await openDocument(created.path);
      openEditor();
    } catch (error) {
      showToast(error.message, true);
    }
  }

  async function refreshFromDisk() {
    try {
      const index = await native("list");
      state.documents = index.documents || [];
      state.markdownRootURL = index.markdownRootURL;
      state.projectRootURL = index.projectRootURL;
      ui.sourceLabel.textContent = `Watching ${new URL(index.markdownRootURL).pathname.split("/").slice(-2).join("/")}`;
      renderTree();
      if (!state.documents.length) {
        state.selectedPath = "";
        state.currentDocument = null;
        ui.edit.disabled = true;
        ui.crumbOwner.textContent = "Documentation";
        ui.document.innerHTML = `<div class="empty-state"><strong>No published documents yet</strong><span>Add Markdown to <code>Docs/md/&lt;SubAppName&gt;/</code> or use the plus button to create the first page.</span></div>`;
        return;
      }
      const selectedStillExists = state.documents.some((doc) => doc.path === state.selectedPath);
      if (!selectedStillExists) state.selectedPath = state.documents[0].path;
      if (state.editorOpen) {
        const sourceStillExists = state.documents.some((doc) => doc.path === state.editorPath);
        if (!sourceStillExists) {
          state.editorConflict = true;
          ui.conflict.hidden = false;
          ui.save.disabled = true;
          setSaveStatus("The Markdown source was removed.", true);
        } else {
          const latestEditorFile = await native("read", { path: state.editorPath });
          if (latestEditorFile.version !== state.editorBaseVersion) {
            if (ui.editor.value === state.editorBaseMarkdown) {
              state.editorBaseMarkdown = latestEditorFile.markdown;
              state.editorBaseVersion = latestEditorFile.version;
              ui.editor.value = latestEditorFile.markdown;
              state.editorConflict = false;
              ui.conflict.hidden = true;
              setSaveStatus("Loaded the latest source");
              if (state.currentDocument?.path === latestEditorFile.path) state.currentDocument = latestEditorFile;
            } else {
              state.editorConflict = true;
              ui.conflict.hidden = false;
              ui.save.disabled = true;
              setSaveStatus("The Markdown source changed on disk.", true);
            }
          }
        }
      }
      if (!state.editorOpen || ui.editor.value === state.editorBaseMarkdown) {
        const doc = await native("read", { path: state.selectedPath });
        state.currentDocument = doc;
        setOwner(doc.path);
        renderDocument(doc);
      }
      ui.liveStatus.textContent = "Live";
      ui.liveStatus.style.color = "";
    } catch (error) {
      ui.liveStatus.textContent = "Refresh error";
      ui.liveStatus.style.color = "var(--danger)";
      showToast(error.message, true);
    }
  }

  document.addEventListener("click", async (event) => {
    const link = event.target.closest("a");
    if (!link) return;
    if (link.dataset.documentLink) {
      event.preventDefault();
      await openDocument(link.dataset.documentLink, link.dataset.anchor || "");
    } else if (link.dataset.anchor) {
      event.preventDefault();
      document.getElementById(link.dataset.anchor)?.scrollIntoView({ behavior: "smooth", block: "start" });
    } else if (link.dataset.externalLink) {
      event.preventDefault();
      native("openExternal", { url: link.dataset.externalLink }).catch((error) => showToast(error.message, true));
    } else if (link.dataset.localLink) {
      event.preventDefault();
      native("openLocal", { url: link.href }).catch((error) => showToast(error.message, true));
    }
  });

  window.VGMManDocs = {
    _receive(response) {
      const pending = state.pending.get(String(response.id));
      if (!pending) return;
      state.pending.delete(String(response.id));
      if (response.ok) pending.resolve(response.value);
      else pending.reject(new Error(response.error || "The request failed."));
    },
    refreshFromDisk,
  };

  window.addEventListener("error", (event) => {
    const message = event.message || "The documentation renderer encountered an error.";
    showPageError(message);
  });

  ui.search.addEventListener("input", renderTree);
  ui.edit.addEventListener("click", openEditor);
  ui.newDocument.addEventListener("click", createDocument);
  ui.save.addEventListener("click", saveEditor);
  ui.close.addEventListener("click", closeEditor);
  ui.cancel.addEventListener("click", closeEditor);
  ui.backdrop.addEventListener("click", closeEditor);
  ui.reload.addEventListener("click", reloadEditor);
  ui.editor.addEventListener("input", () => {
    ui.save.disabled = state.editorConflict;
    setSaveStatus(state.editorConflict ? "Reload before saving" : "Unsaved changes");
  });
  ui.search.addEventListener("keydown", (event) => {
    if (event.key === "Escape") { ui.search.value = ""; renderTree(); }
  });
  window.addEventListener("keydown", (event) => {
    if ((event.metaKey || event.ctrlKey) && event.key.toLocaleLowerCase() === "k") {
      event.preventDefault();
      ui.search.focus();
    } else if (event.key === "Escape" && state.editorOpen) {
      closeEditor();
    } else if ((event.metaKey || event.ctrlKey) && event.key.toLocaleLowerCase() === "s" && state.editorOpen) {
      event.preventDefault();
      saveEditor();
    }
  });

  native("list").then(async (index) => {
    state.documents = index.documents || [];
    state.markdownRootURL = index.markdownRootURL;
    state.projectRootURL = index.projectRootURL;
    ui.sourceLabel.textContent = `Watching ${new URL(index.markdownRootURL).pathname.split("/").slice(-2).join("/")}`;
    renderTree();
    if (state.documents.length) await openDocument(state.documents[0].path);
    else await refreshFromDisk();
  }).catch((error) => {
    ui.document.innerHTML = `<div class="empty-state"><strong>Unable to load documentation</strong><span>${error.message.replaceAll("<", "&lt;")}</span></div>`;
    showToast(error.message, true);
  });
})();
