(() => {
  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
  const bridge = (action, values = {}) => window.webkit?.messageHandlers?.uacman?.postMessage({ action, ...values });
  const esc = value => String(value ?? "").replace(/[&<>"']/g, char => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;" }[char]));
  const textOrDash = value => value ? esc(value) : '<span class="muted">—</span>';
  const memberLocation = member => {
    const prefix = member.variantID ? `variants/${member.variantID}/` : "";
    const relativePath = Number(state?.variantCount) === 1 && prefix && member.path.startsWith(prefix)
      ? member.path.slice(prefix.length)
      : member.path;
    const variantName = member.variantLabel || member.variantID;
    return member.variantID ? `${variantName} · ${relativePath}` : relativePath;
  };
  const bytes = count => {
    const value = Number(count) || 0;
    if (value < 1024) return `${value} B`;
    const units = ["KB", "MB", "GB", "TB"];
    let size = value / 1024, index = 0;
    while (size >= 1024 && index < units.length - 1) { size /= 1024; index++; }
    return `${size.toFixed(size >= 100 ? 0 : size >= 10 ? 1 : 2)} ${units[index]}`;
  };
  const parseObject = raw => {
    try { const value = JSON.parse(raw || "{}"); return value && typeof value === "object" && !Array.isArray(value) ? value : null; }
    catch { return null; }
  };
  const preferredMetadataColumns = ["title", "artist", "album", "year", "genre", "playLengthMs", "durationMs"];
  const metadataDisplayNames = {
    title: "Title",
    artist: "Artist",
    album: "Album",
    game: "Game",
    system: "System",
    year: "Year",
    genre: "Genre",
    comment: "Comment",
    trackNumber: "Track #",
    playLengthMs: "Play length",
    durationMs: "Duration",
    introLengthMs: "Intro length",
    loopLengthMs: "Loop length",
    fadeLengthMs: "Fade length",
    discFilename: "Disc filename",
    filename: "Filename"
  };
  const displayMetadataKey = key => {
    const value = String(key ?? "");
    if (metadataDisplayNames[value]) return metadataDisplayNames[value];
    return value
      .replace(/^extension\./, "")
      .replace(/([a-z])([A-Z])/g, "$1 $2")
      .replace(/[_-]+/g, " ")
      .replace(/\b\w/g, character => character.toUpperCase());
  };
  const tagNameAcronyms = new Set(["api", "blake3", "cd", "cue", "eu", "id", "jp", "json", "lba", "md5", "ost", "pcm", "psf", "psx", "rom", "sha1", "sha256", "spc", "uac", "url", "us", "vgm", "xa", "xml"]);
  const titleCaseTagName = raw => {
    let value = String(raw ?? "").trim();
    let namespace = "";
    if (value.toLowerCase().startsWith("extension.")) {
      namespace = "extension.";
      value = value.slice("extension.".length).trim();
    }
    value = value.replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/[_-]+/g, " ").replace(/\s+/g, " ");
    const words = value.split(" ").filter(Boolean);
    if (!words.length) return "";
    return namespace + words.map(word => {
      const lower = word.toLocaleLowerCase();
      return tagNameAcronyms.has(lower) ? lower.toUpperCase() : lower.charAt(0).toUpperCase() + lower.slice(1);
    }).join(" ");
  };
  const displayTrackKey = key => String(key).startsWith("extension.") ? `Extension: ${displayMetadataKey(String(key).slice("extension.".length))}` : displayMetadataKey(key);
  const canonicalHeaderMarkup = labels => `<div class="field-grid-row field-grid-header" role="row">${labels.map(label => `<div class="field-grid-cell field-grid-heading" role="columnheader"><input class="tag-table-field field-grid-heading-input" value="${esc(label)}" aria-label="${esc(label)}" disabled></div>`).join("")}</div>`;
  const technicalKeyPattern = /^(?:extension\.)?(?:contained|source|native|technical|diagnostic|hash|blake3|md5|sha1|loop|fade|intro|disc|xa|pcm|raw|tracktotal|disctotal|schema|versions|formats|dumper|cue|memberpath|sector|lba)/i;
  const isTechnicalKey = key => technicalKeyPattern.test(String(key)) || /^(?:SOURCE_|NATIVE_|XA_|LOOP_|PCM_)/i.test(String(key));
  const memberFields = member => ({
    ...(member.metadata || {}),
    ...Object.fromEntries(Object.entries(member.extensions || {}).map(([key, value]) => [`extension.${key}`, value]))
  });
  const isEmptyTagValue = value => value === null || value === undefined || (typeof value === "string" && value.trim() === "");
  const hasMeaningfulTagValue = value => !isEmptyTagValue(value);
  const metadataColumns = () => {
    const keys = new Set();
    playableMembers().forEach(member => Object.keys(memberFields(member)).forEach(key => keys.add(key)));
    return [...keys].sort((a, b) => {
      const ai = preferredMetadataColumns.indexOf(a), bi = preferredMetadataColumns.indexOf(b);
      if (ai >= 0 || bi >= 0) return (ai < 0 ? 999 : ai) - (bi < 0 ? 999 : bi);
      return a.localeCompare(b, undefined, { numeric:true, sensitivity:"base" });
    });
  };
  const displayMetadataValue = value => {
    if (value === null || value === undefined || value === "") return '<span class="muted">—</span>';
    if (typeof value === "object") {
      const count = Array.isArray(value) ? value.length : Object.keys(value).length;
      return `<span class="structured-value" title="Multiple Values; open the disclosure to inspect them">Multiple Values · ${count}</span>`;
    }
    return esc(String(value));
  };
  const canonicalFoldMarkup = (label, body, options = {}) => {
    const open = options.open === true;
    const meta = options.meta ? `<span class="canonical-fold-meta">${esc(options.meta)}</span>` : "";
    return `<div class="canonical-fold ${esc(options.className || "")}"><button class="canonical-fold-toggle" type="button" data-action="toggleCanonicalFold" aria-expanded="${open}"><span>${esc(label)}</span>${meta}<span class="canonical-fold-icon">${open ? "−" : "＋"}</span></button><div class="canonical-fold-panel${open ? " open" : ""}"><div class="canonical-fold-inner">${body}</div></div></div>`;
  };
  const multipleValuesMarkup = (value, suppliedEntries = null) => {
    const entries = suppliedEntries || (Array.isArray(value) ? value.map((item, index) => [String(index + 1), item]) : Object.entries(value || {}));
    const body = entries.length
      ? entries.map(([key, item]) => `<div class="tag-multiple-value-row"><span>${esc(key)}</span><span>${esc(typeof item === "object" ? JSON.stringify(item) : String(item ?? "—"))}</span></div>`).join("")
      : '<div class="tag-multiple-value-row"><span>—</span><span>Empty</span></div>';
    return canonicalFoldMarkup("Multiple Values", body, { className:"tag-multiple-values" });
  };
  const nestedJSONValueMarkup = (value, key, editable = true) => {
    const raw = JSON.stringify(value, null, 2);
    const body = editable
      ? `<textarea class="tag-table-field nested-json-editor" data-multiple-value aria-label="JSON value for ${esc(key)}">${esc(raw)}</textarea>`
      : `<pre class="nested-json-preview">${esc(raw)}</pre>`;
    return `<details class="nested-json-dropdown"><summary class="nested-json-trigger"><span>[Nested Tags]</span><span class="canonical-fold-icon">＋</span></summary><div class="nested-json-panel">${body}</div></details>`;
  };
  const multipleValuesCloseMarkup = context => context.foldID
    ? `<button class="tag-table-field field-grid-heading-input multiple-values-header-action multiple-values-subtable-close" data-action="closeCanonicalSubtable" data-fold-id="${esc(context.foldID)}" type="button" title="Close nested tags table" aria-label="Close nested tags table">×</button>`
    : `<button class="tag-table-field field-grid-heading-input multiple-values-header-action multiple-values-popup-close" data-action="closeMultipleValuesPopup" data-popup-id="${esc(context.popupID || "")}" type="button" title="Close" aria-label="Close">×</button>`;
  const multipleValuesTableTitleRowMarkup = context => {
    const title = context.title || context.key || "Values";
    return `<div class="field-grid-row field-grid-header multiple-values-table-title-row" role="row"><div class="field-grid-cell field-grid-heading" role="columnheader"><input class="tag-table-field field-grid-heading-input" value="${esc(title)}" aria-label="${esc(title)}" disabled></div></div>`;
  };
  const multipleValuesTableHeaderRowMarkup = (context, editable) => {
    const submitMarkup = editable
      ? '<button class="tag-table-field field-grid-heading-input multiple-values-header-action" data-action="commitMultipleValues" type="button" title="Submit all changed values" aria-label="Submit all changed values">✓</button>'
      : '<input class="tag-table-field field-grid-heading-input" value="" aria-label="Submit" disabled>';
    return `<div class="field-grid-row field-grid-header multiple-values-table-header-row" role="row"><div class="field-grid-cell field-grid-heading" role="columnheader"><input class="tag-table-field field-grid-heading-input" value="#" aria-label="#" disabled></div><div class="field-grid-cell field-grid-heading" role="columnheader"><input class="tag-table-field field-grid-heading-input" value="Tag Name" aria-label="Tag Name" disabled></div><div class="field-grid-cell field-grid-heading" role="columnheader"><input class="tag-table-field field-grid-heading-input" value="Tag Value" aria-label="Tag Value" disabled></div><div class="field-grid-cell field-grid-heading field-grid-action-cell" role="columnheader">${submitMarkup}</div><div class="field-grid-cell field-grid-heading field-grid-action-cell" role="columnheader">${multipleValuesCloseMarkup(context)}</div></div>`;
  };
  const multipleValuesTableChromeMarkup = (context, editable) => `${multipleValuesTableTitleRowMarkup(context)}${multipleValuesTableHeaderRowMarkup(context, editable)}`;
  const multipleValuesEditorBodyMarkup = (value, context = {}) => {
    const isArray = Array.isArray(value);
    const popupLayout = context.layout === "popup";
    const canonicalLayout = ["canonical", "subtable", "popup"].includes(context.layout);
    const subtableLayout = context.layout === "subtable";
    const tableLayout = subtableLayout || popupLayout;
    const gridClass = context.layout === "subtable" ? "inserted-table-grid" : "canonical-popup-field-grid";
    const entries = isArray ? value.map((item, index) => [String(index), item]) : Object.entries(value || {});
    const rowMarkup = ([key, item], index) => {
      const kind = fieldKind(item);
      const raw = kind === "json" ? JSON.stringify(item, null, 2) : String(item ?? "");
      const valueControl = kind === "json"
        ? (canonicalLayout ? nestedJSONValueMarkup(item, key) : `<textarea class="multiple-value-editor" data-multiple-value aria-label="Value for ${esc(key)}">${esc(raw)}</textarea>`)
        : `<input class="${canonicalLayout ? "tag-table-field " : ""}multiple-value-editor" data-multiple-value value="${esc(raw)}" aria-label="Value for ${esc(key)}">`;
      const rowClass = canonicalLayout ? "field-grid-row multiple-value-editor-row" : "tag-multiple-value-row multiple-value-editor-row";
      const keyMarkup = `<input class="${canonicalLayout ? "tag-table-field " : ""}multiple-value-key" data-multiple-key value="${esc(key)}" aria-label="Key for ${esc(key)}"${isArray ? " disabled" : ""}>`;
      const numberMarkup = tableLayout ? `<div class="field-grid-cell"><input class="tag-table-field multiple-value-number" value="${index + 1}" aria-label="Value number ${index + 1}" disabled></div>` : "";
      const removeMarkup = `<button class="icon-button danger multiple-value-remove" data-action="removeMultipleValue" type="button" title="Remove value" aria-label="Remove value">×</button>`;
      const submitMarkup = tableLayout ? '<button class="icon-button multiple-value-submit" data-action="commitMultipleValueRow" type="button" title="Submit changed value" aria-label="Submit changed value">✓</button>' : "";
      return canonicalLayout
        ? `<div class="${rowClass}" data-multiple-entry data-multiple-kind="${kind}">${numberMarkup}<div class="field-grid-cell">${keyMarkup}</div><div class="field-grid-cell">${valueControl}</div>${tableLayout ? `<div class="field-grid-cell field-grid-action-cell">${submitMarkup}</div>` : ""}<div class="field-grid-cell field-grid-action-cell">${removeMarkup}</div></div>`
        : `<div class="${rowClass}" data-multiple-entry data-multiple-kind="${kind}">${keyMarkup}${valueControl}${removeMarkup}</div>`;
    };
    const rows = entries.map(rowMarkup).join("");
    const data = [
      `data-multiple-editor`,
      `data-multiple-target="${esc(context.target || "member")}"`,
      `data-multiple-array="${isArray}"`,
      `data-multiple-layout="${subtableLayout ? "subtable" : popupLayout ? "popup" : canonicalLayout ? "canonical" : "compact"}"`,
      `data-multiple-path="${esc(context.path || "")}"`,
      `data-multiple-scope="${esc(context.scope || "")}"`,
      `data-multiple-key="${esc(context.key || "")}"`
    ].join(" ");
    const rowsMarkup = canonicalLayout
      ? popupLayout
        ? `<div class="multiple-values-rows">${rows || '<div class="field-grid-empty multiple-values-empty" role="row"><span role="cell">No values</span></div>'}</div>`
        : `<div class="field-grid ${gridClass} canonical-multiple-values-grid" role="table">${multipleValuesTableChromeMarkup(context, true)}<div class="multiple-values-rows">${rows || '<div class="field-grid-empty multiple-values-empty" role="row"><span role="cell">No values</span></div>'}</div></div>`
      : `<div class="multiple-values-rows">${rows || '<div class="file-tag-empty multiple-values-empty">No values</div>'}</div>`;
    const body = `<div class="multiple-values-editor${canonicalLayout ? " canonical-multiple-values-editor" : ""}${popupLayout ? " canonical-popup-editor" : ""}" ${data}>${rowsMarkup}${canonicalLayout ? "" : '<div class="multiple-values-editor-actions"><button class="icon-button" data-action="addMultipleValue" type="button" title="Add value" aria-label="Add value">＋</button><button class="icon-button" data-action="commitMultipleValues" type="button" title="Submit changed values" aria-label="Submit changed values">✓</button>'}<div class="multiple-values-editor-error" role="status"></div></div>`;
    return { body, count:entries.length };
  };
  const multipleValuesEditorMarkup = (value, context = {}) => {
    const editor = multipleValuesEditorBodyMarkup(value, context);
    return canonicalFoldMarkup("Multiple Values", editor.body, { className:"tag-multiple-values editable-multiple-values", meta:context.showCount === false ? "" : editor.count });
  };
  const multipleValuesTriggerMarkup = foldID => `<button class="canonical-fold-toggle canonical-fold-trigger" type="button" data-action="toggleCanonicalFold" data-fold-id="${esc(foldID)}" aria-expanded="false"><span>[Nested Tags]</span><span class="canonical-fold-icon">＋</span></button>`;
  const multipleValuesReadOnlyTableMarkup = (entries, context = {}) => {
    const popupLayout = context.layout === "popup";
    const subtableLayout = context.layout === "subtable";
    const tableLayout = popupLayout || subtableLayout;
    const gridClass = subtableLayout ? "inserted-table-grid" : "canonical-popup-field-grid";
    const rows = entries.length
      ? entries.map(([key, item], index) => `<div class="field-grid-row multiple-value-readonly-row" role="row">${tableLayout ? `<div class="field-grid-cell"><input class="tag-table-field multiple-value-number" value="${index + 1}" aria-label="Value number ${index + 1}" disabled></div>` : ""}<div class="field-grid-cell"><input class="tag-table-field" value="${esc(key)}" disabled></div><div class="field-grid-cell">${item && typeof item === "object" ? nestedJSONValueMarkup(item, key, false) : `<input class="tag-table-field" value="${esc(String(item ?? "—"))}" disabled>`}</div><div class="field-grid-cell"></div><div class="field-grid-cell"></div></div>`).join("")
      : '<div class="field-grid-empty multiple-values-empty" role="row"><span role="cell">No values</span></div>';
    if (popupLayout) return `<div class="multiple-values-rows">${rows}</div>`;
    return `<div class="field-grid ${gridClass} canonical-multiple-values-grid" role="table">${multipleValuesTableChromeMarkup(context, false)}<div class="multiple-values-rows">${rows}</div></div>`;
  };
  const multipleValuesSubtableMarkup = (value, context = {}, options = {}) => {
    const entries = options.entries || (Array.isArray(value) ? value.map((item, index) => [String(index + 1), item]) : Object.entries(value || {}));
    const subtableContext = { ...context, layout:"subtable" };
    if (options.editable === false) return `<div class="inserted-table-panel">${multipleValuesReadOnlyTableMarkup(entries, subtableContext)}</div>`;
    const editor = multipleValuesEditorBodyMarkup(value, subtableContext);
    return `<div class="inserted-table-panel"><div class="editable-multiple-values">${editor.body}</div></div>`;
  };
  const multipleValuesPopupParts = (value, context = {}, options = {}) => {
    const popupID = context.popupID || "multiple-values";
    const title = context.title || context.key || "Values";
    const editable = options.editable !== false;
    const entries = options.entries || (Array.isArray(value) ? value.map((item, index) => [String(index + 1), item]) : Object.entries(value || {}));
    const body = editable
      ? multipleValuesEditorBodyMarkup(value, { ...context, layout:"popup", popupID }).body
      : multipleValuesReadOnlyTableMarkup(entries, { ...context, layout:"popup" });
    const trigger = `<button class="canonical-fold-toggle canonical-fold-trigger multiple-values-popup-trigger" type="button" data-action="toggleMultipleValuesPopup" data-popup-id="${esc(popupID)}" aria-controls="multiple-values-popup-${esc(popupID)}" aria-expanded="false"><span>[Nested Tags]</span><span class="canonical-fold-icon">＋</span></button>`;
    const popup = `<div class="multiple-values-popup-backdrop" id="multiple-values-popup-${esc(popupID)}" data-multiple-values-popup="${esc(popupID)}" data-multiple-target="${esc(context.target || "member")}" data-multiple-path="${esc(context.path || "")}" data-multiple-scope="${esc(context.scope || "")}" data-multiple-key="${esc(context.key || "")}" data-multiple-editable="${editable}" hidden><div class="multiple-values-popup-card" role="dialog" aria-modal="true" aria-label="${esc(title)}"><div class="multiple-values-popup-content"><div class="field-grid canonical-popup-field-grid canonical-multiple-values-grid" role="table">${multipleValuesTableChromeMarkup({ ...context, popupID, title }, editable)}${body}</div></div></div></div>`;
    return { trigger, popup };
  };
  const metadataSortValue = (member, key) => {
    const value = memberFields(member)[key];
    return value && typeof value === "object" ? JSON.stringify(value) : (value ?? "");
  };
  let state = null;
  let sort = { key:"track", direction:1 };
  let inspectorTab = "set";
  let mainView = "members";
  let trackBrowserPath = "";
  let dirtyTrackPaths = new Set();
  let lastUnsavedChanges = false;
  let lastRenderedView = "";
  let lastDocumentName = "";
  const uiMotionDuration = 250;

  function animateRowRemoval(row, completion) {
    if (!row) return;
    row.classList.add("row-removing");
    window.setTimeout(() => {
      if (row.isConnected) row.remove();
      completion?.();
    }, uiMotionDuration);
  }

  function visibleMembers() {
    if (!state) return [];
    const query = $("#member-filter")?.value.trim().toLocaleLowerCase() || "";
    const source = playableMembers();
    const result = source.filter(member => !query || [member.title, member.artist, member.album, member.year, member.genre, member.name, member.path, member.role, member.format, ...Object.values(memberFields(member))].some(value => String(typeof value === "object" ? JSON.stringify(value) : (value || "")).toLocaleLowerCase().includes(query)));
    return result.sort((a, b) => {
      let left;
      let right;
      if (sort.key === "track") {
        left = trackNumberFor(a, source.indexOf(a));
        right = trackNumberFor(b, source.indexOf(b));
      } else if (sort.key === "filename") {
        left = a.name || a.path;
        right = b.name || b.path;
      } else {
        left = metadataColumns().includes(sort.key) ? metadataSortValue(a, sort.key) : (a[sort.key] ?? "");
        right = metadataColumns().includes(sort.key) ? metadataSortValue(b, sort.key) : (b[sort.key] ?? "");
      }
      if (sort.key === "duration") { left = Number(a.playLengthMs) || -1; right = Number(b.playLengthMs) || -1; }
      if (typeof left === "number" && typeof right === "number") return (left - right) * sort.direction;
      return String(left).localeCompare(String(right), undefined, { numeric:true, sensitivity:"base" }) * sort.direction;
    });
  }

  function render(stateValue) {
    state = stateValue;
    if (state.documentName !== lastDocumentName) {
      lastDocumentName = state.documentName || "";
      inspectorTab = "set";
      mainView = "members";
      trackBrowserPath = "";
      dirtyTrackPaths = new Set();
      lastUnsavedChanges = Boolean(state.hasUnsavedChanges);
    }
    if (lastUnsavedChanges && !state.hasUnsavedChanges) dirtyTrackPaths.clear();
    lastUnsavedChanges = Boolean(state.hasUnsavedChanges);
    const viewChanged = mainView !== lastRenderedView;
    lastRenderedView = mainView;
    const active = document.activeElement;
    const focusId = active?.dataset?.focusId;
    const selection = active && "selectionStart" in active ? [active.selectionStart, active.selectionEnd] : null;

    $("#document-name").textContent = state.documentName || "No package open";
    $("#document-path").textContent = state.documentPath || "Choose a collection or open one UAC file";
    $("#member-filter-wrap").classList.toggle("hidden", !["members", "files"].includes(mainView));
    const singleDocumentMode = Boolean(state.documentName) && !state.collectionRoot;
    $("#workspace").classList.toggle("library-collapsed", singleDocumentMode);
    $("#library-panel").classList.toggle("single-document-hidden", singleDocumentMode);
    $("#save-button").disabled = !state.hasUnsavedChanges || state.isHarvestingMetadata;
    $("#revert-button").disabled = !state.hasUnsavedChanges && !state.isHarvestingMetadata;
    $("#collection-root").textContent = state.collectionRoot || "No collection selected";
    $("#collection-foot").textContent = state.isScanningCollection ? "Reading package manifests…" : state.collectionStatus || `${state.collectionEntries.length} packages`;
    $("#rescan-button").disabled = !state.collectionRoot;
    $("#rescan-button").dataset.action = state.isScanningCollection ? "cancelCollectionScan" : "rescanCollection";
    $("#rescan-button").title = state.isScanningCollection ? "Cancel collection scan" : "Rescan collection";
    $("#rescan-button").textContent = state.isScanningCollection ? "×" : "↻";

    renderCollections();
    renderIssues();
    renderMembers();
    renderInspector();
    $("#members-view").classList.toggle("hidden", mainView !== "members");
    $("#metadata-view").classList.toggle("hidden", mainView === "members");
    $$(".main-view-tabs button").forEach(button => button.classList.toggle("active", button.dataset.view === mainView));
    if (viewChanged) {
      const visiblePage = mainView === "members" ? $("#members-view") : $("#metadata-view");
      visiblePage?.classList.remove("page-enter");
      if (visiblePage) {
        void visiblePage.offsetWidth;
        visiblePage.classList.add("page-enter");
      }
    }

    $("#status-message").textContent = state.isHarvestingMetadata ? state.harvestProgressMessage || "Reading metadata…" : state.statusMessage || "Ready";
    $("#encoding-info").textContent = state.manifestEncodingDescription || "";
    $("#notice").textContent = state.isHarvestingMetadata ? "Reading SPC metadata through the seek table. Package payload bytes remain untouched." : "";
    $("#notice").classList.toggle("hidden", !state.isHarvestingMetadata);
    $("#error-text").textContent = state.errorMessage || "";
    $("#error-banner").classList.toggle("hidden", !state.errorMessage);
    if (focusId) {
      const replacement = $(`[data-focus-id="${CSS.escape(focusId)}"]`);
      if (replacement) {
        replacement.focus({ preventScroll:true });
        if (selection && replacement.setSelectionRange) replacement.setSelectionRange(...selection);
      }
    }
  }

  function renderCollections() {
    const query = $("#collection-filter").value.trim().toLocaleLowerCase();
    const entries = state.collectionEntries.filter(entry => !query || [entry.title, entry.console, entry.packageID, entry.relativePath].some(value => String(value || "").toLocaleLowerCase().includes(query)));
    $("#collection-list").innerHTML = entries.map(entry => {
      const title = entry.title || entry.relativePath.split("/").pop().replace(/\.uac$/i, "");
      const selected = state.selectedCollectionPackagePath === entry.relativePath;
      return `<div class="collection-item ${selected ? "selected" : ""}" data-package="${esc(entry.relativePath)}" title="${esc(entry.packageID)} · ${bytes(entry.fileByteCount)}"><div class="collection-title">${esc(title)}</div><div class="collection-meta">${esc(entry.console || "Unknown system")} · ${entry.playableMemberCount} playable · ${entry.totalMemberCount} members</div><div class="collection-path">${esc(entry.relativePath)}</div></div>`;
    }).join("");
    if (entries.length === 0) $("#collection-list").innerHTML = `<div class="empty-note">${state.collectionEntries.length ? "No packages match this filter." : "Choose Collection to scan a folder of UAC packages."}</div>`;
  }

  function renderIssues() {
    const details = $("#issues-details");
    details.classList.toggle("hidden", state.collectionIssues.length === 0);
    $("#issue-count").textContent = state.collectionIssues.length ? `(${state.collectionIssues.length})` : "";
    $("#issues-list").innerHTML = state.collectionIssues.map(issue => `<div class="issue"><strong>${esc(issue.relativePath)}</strong>${esc(issue.message)}</div>`).join("");
  }

  function renderMembers() {
    closeTrackContextMenu();
    const members = visibleMembers();
    const open = Boolean(state.documentName);
    const noRows = members.length === 0;
    const tableScroll = $("#table-scroll");
    tableScroll.className = "table-scroll canonical-table-surface giga-table-surface";
    tableScroll.innerHTML = open
      ? (noRows ? `<div class="empty-state"><div class="empty-icon">▤</div><h3>${state.members.length ? "No tracks match this filter" : "This package has no audio tracks"}</h3><p>${state.members.length ? "Change the search text to show audio tracks." : "The package contains no playable members."}</p></div>` : renderTrackArrayGrid(members))
      : `<div class="empty-state"><div class="empty-icon">▤</div><h3>Open a package to get started</h3><p>Browse a collection or open a UAC package. Audio streams appear here as rows with their tags as columns.</p><button class="button primary" data-action="openUAC">Open a UAC file</button></div>`;
    $("#member-summary").textContent = state.documentName ? `${members.length} shown · ${playableMembers().length} audio tracks` : "No package open";
    const gigaGrid = $(".tracks-field-grid");
    if (gigaGrid) {
      const template = trackArrayColumnTemplate(members, trackColumns());
      gigaGrid.style.setProperty("--field-grid-columns", template);
      $$(".field-grid-header, .track-array-row", gigaGrid).forEach(row => row.style.setProperty("grid-template-columns", template, "important"));
    }
  }

  function fieldKind(value) {
    if (typeof value === "string") return "string";
    if (typeof value === "number") return "number";
    if (typeof value === "boolean") return "boolean";
    return "json";
  }

  function fieldValueMarkup(value, id, kind) {
    const encoded = kind === "string" ? value : JSON.stringify(value, null, 2);
    if (value && typeof value === "object") {
      const count = Array.isArray(value) ? value.length : Object.keys(value).length;
      return `<details class="nested-field"><summary>Multiple Values · ${count} <span>Open</span></summary><textarea class="field-structured" data-field-value data-focus-id="${esc(id)}">${esc(encoded)}</textarea></details>`;
    }
    return `<input class="field-value" data-field-value data-focus-id="${esc(id)}" value="${esc(encoded)}">`;
  }

  function renderPropertyEditor(title, scope, raw, options = {}) {
    const includeTechnical = options.includeTechnical === true;
    const includeEmpty = options.includeEmpty === true;
    const value = parseObject(raw);
    const fields = value ? Object.entries(value).filter(([key, field]) => (includeTechnical || !isTechnicalKey(key)) && (includeEmpty || !isEmptyTagValue(field))).map(([key, field]) => {
      const kind = fieldKind(field);
      const editorID = `${scope}-${key}`;
      return `<tr class="field-row ${isTechnicalKey(key) ? "technical-field" : ""}" data-kind="${kind}"><td><input class="field-key" data-field-key data-focus-id="${esc(editorID)}" value="${esc(key)}" aria-label="Metadata field name"></td><td>${fieldValueMarkup(field, `${editorID}-value`, kind)}</td><td class="field-type-cell"><select class="field-type" data-field-type aria-label="Value type"><option value="string" ${kind === "string" ? "selected" : ""}>text</option><option value="number" ${kind === "number" ? "selected" : ""}>number</option><option value="boolean" ${kind === "boolean" ? "selected" : ""}>boolean</option><option value="json" ${kind === "json" ? "selected" : ""}>json</option></select></td><td class="field-action-cell"><button class="remove-field" data-action="removeField" title="Remove field" aria-label="Remove ${esc(key)}">×</button></td></tr>`;
    }).join("") : `<tr><td colspan="4" class="json-invalid">Metadata must be a JSON object. Use the JSON editor only if recovery is needed.</td></tr>`;
    return `<section class="inspector-section metadata-section" data-scope-section="${scope}"><div class="section-title">${esc(title)}<span class="section-actions"><button class="add-field" data-action="addField" data-scope="${scope}">＋ Add field</button></span></div><table class="kv-table"><thead><tr><th>Key</th><th>Value</th><th class="type-heading">Type</th><th class="action-heading"></th></tr></thead><tbody class="field-list" data-editor="${scope}">${fields}</tbody></table><div class="field-error" data-error-for="${scope}"></div><details class="raw-editor"><summary>Open JSON editor</summary><textarea data-raw-editor="${scope}" data-focus-id="raw-${scope}">${esc(raw || "{}")}</textarea></details></section>`;
  }

  function playableMembers() {
    const playable = state.members.filter(member => member.role === "playable" || member.role === "track");
    return playable.length ? playable : state.members;
  }

  function trackColumns() {
    const keys = new Set();
    playableMembers().forEach(member => Object.keys(memberFields(member)).forEach(key => keys.add(key)));
    return [...keys].sort((a, b) => {
      const ai = preferredMetadataColumns.indexOf(a), bi = preferredMetadataColumns.indexOf(b);
      if (ai >= 0 || bi >= 0) return (ai < 0 ? 999 : ai) - (bi < 0 ? 999 : bi);
      return a.localeCompare(b, undefined, { numeric:true, sensitivity:"base" });
    });
  }

  function trackNumberFor(member, index) {
    const fields = memberFields(member);
    const candidates = ["trackNumber", "track", "trackIndex", "number", "index", "discTrack"];
    for (const key of candidates) {
      const value = fields[key];
      if (typeof value === "number" && Number.isFinite(value)) return Math.max(1, Math.trunc(value));
      if (typeof value === "string" && /^\s*\d+\s*$/.test(value)) return Math.max(1, Number.parseInt(value, 10));
    }
    const sourceIndex = playableMembers().indexOf(member);
    return sourceIndex >= 0 ? sourceIndex + 1 : index + 1;
  }

  function metadataTagCatalog() {
    const catalog = new Map();
    const add = (key, scope, value) => {
      if (isEmptyTagValue(value)) return;
      const existing = catalog.get(key) || { key, scopes:new Set(), count:0, sample:value, signatures:new Set(), values:new Map(), scoped:new Map() };
      existing.scopes.add(scope);
      existing.count += 1;
      const signature = JSON.stringify(value);
      existing.signatures.add(signature);
      existing.values.set(signature, value);
      const scoped = existing.scoped.get(scope) || { count:0, sample:value, signatures:new Set(), values:new Map() };
      scoped.count += 1;
      scoped.signatures.add(signature);
      scoped.values.set(signature, value);
      if (isEmptyTagValue(scoped.sample) || typeof scoped.sample === "object") scoped.sample = value;
      existing.scoped.set(scope, scoped);
      if (isEmptyTagValue(existing.sample) || typeof existing.sample === "object") existing.sample = value;
      catalog.set(key, existing);
    };
    const game = parseObject(state.gameMetadataJSON) || {};
    const gameExtensions = parseObject(state.gameExtensionsJSON) || {};
    Object.entries(game).forEach(([key, value]) => add(key, "Package Tags", value));
    Object.entries(gameExtensions).forEach(([key, value]) => add(`extension.${key}`, "Package Extensions", value));
    playableMembers().forEach(member => {
      Object.entries(member.metadata || {}).forEach(([key, value]) => add(key, "Track Tags", value));
      Object.entries(member.extensions || {}).forEach(([key, value]) => add(`extension.${key}`, "Track Extensions", value));
    });
    return [...catalog.values()].sort((a, b) => a.key.localeCompare(b.key, undefined, { numeric:true, sensitivity:"base" }));
  }

  function renderTagScopePage(title, scope, includeAttachments = false) {
    const catalog = metadataTagCatalog();
    const rowsFor = scope => {
      const rows = catalog.filter(entry => [...entry.scopes].some(value => value.startsWith(scope))).map((entry, index) => {
      const scoped = [...entry.scoped.entries()].filter(([name]) => name.startsWith(scope)).map(([, value]) => value);
      const count = scoped.reduce((total, value) => total + value.count, 0);
      const signatures = new Set(scoped.flatMap(value => [...value.signatures]));
      const values = new Map(scoped.flatMap(value => [...value.values.entries()]));
      const sample = scoped[0]?.sample;
      const multipleValues = signatures.size > 1 || typeof sample === "object";
      const editableMultipleValues = signatures.size === 1 && sample !== null && typeof sample === "object";
      const foldID = `tag-${scope.toLowerCase()}-${index}`;
      let valueInput;
      let subrow = "";
      if (editableMultipleValues || multipleValues) {
        valueInput = multipleValuesTriggerMarkup(foldID);
        const subtable = multipleValuesSubtableMarkup(
          editableMultipleValues ? sample : null,
          { target:"metadata", scope:scope === "Package" ? "package" : "tracks", key:entry.key, foldID, title:entry.key },
          { editable:editableMultipleValues, entries:[...values.values()].map((value, valueIndex) => [String(valueIndex + 1), value]) }
        );
        subrow = `<div class="field-grid-row inserted-table-row" role="row" data-canonical-subrow="${esc(foldID)}"><div class="field-grid-cell inserted-table-cell" role="cell">${subtable}</div></div>`;
      } else {
        valueInput = `<input data-tag-value aria-label="Tag value for ${esc(entry.key)}" value="${esc(sample)}">`;
      }
      const tagType = multipleValues ? "Multiple Values" : signatures.size === 1 ? (Array.isArray(sample) ? "list" : typeof sample) : "various";
      const readOnlyMultipleValues = multipleValues && !editableMultipleValues;
      const submitTitle = readOnlyMultipleValues ? "Multiple Values contain different values" : "Submit changed fields";
      const foldAttribute = multipleValues ? ` data-multiple-fold-id="${esc(foldID)}"` : "";
      return `<div class="field-grid-row" role="row" data-tag-row data-tag-scope="${esc(scope)}" data-tag-from="${esc(entry.key)}"${foldAttribute}><div class="field-grid-cell tag-number-cell" role="cell"><input class="tag-table-field" value="${index + 1}" aria-label="Tag number" disabled></div><div class="field-grid-cell tag-type-cell" role="cell"><input class="tag-table-field" value="${esc(tagType)}" aria-label="Tag type for ${esc(entry.key)}" disabled></div><div class="field-grid-cell tag-name-cell" role="cell"><input class="tag-table-field" data-tag-to value="${esc(entry.key)}" aria-label="Tag name for ${esc(entry.key)}"></div><div class="field-grid-cell tag-value-cell" role="cell"><span class="tag-inline-editor">${valueInput}</span></div><div class="field-grid-cell tag-uses-cell" role="cell"><input class="tag-table-field" value="${count}" aria-label="Uses for ${esc(entry.key)}" disabled></div><div class="field-grid-cell tag-submit-cell" role="cell"><button class="icon-button" data-action="commitTagRow" title="${submitTitle}" aria-label="${submitTitle}"${readOnlyMultipleValues ? " disabled" : ""}>✓</button></div><div class="field-grid-cell tag-delete-cell" role="cell"><button class="icon-button danger" data-action="deleteTag" title="Delete ${esc(entry.key)}" aria-label="Delete ${esc(entry.key)}">×</button></div></div>${subrow}`;
      }).join("");
      return { rows };
    };
    const header = canonicalHeaderMarkup(["#", "Tag Type", "Tag Name", "Tag Value", "Uses", "✓", "×"]);
    const createForm = scope => `<form class="tag-create-form" data-tag-create data-tag-scope="${scope}" aria-label="New package tag"><span class="tag-create-label">New Tag</span><span class="tag-create-type">string</span><input class="tag-table-field" data-new-tag-key placeholder="Tag Name" aria-label="New tag name"><input class="tag-table-field" data-new-tag-value placeholder="Tag Value" aria-label="New tag value"><button class="icon-button tag-create-submit" type="submit" title="Add tag" aria-label="Add tag">✓</button></form>`;
    const grid = (title, rows, scope) => `<section class="tag-scope-table"><div class="section-title"><span>${title}</span><form class="tag-create-form" data-tag-create data-tag-scope="${scope}"><input data-new-tag-key placeholder="Tag Name" aria-label="New tag name"><input data-new-tag-value placeholder="New tag value" aria-label="New tag value"><button class="icon-button add-tag-submit" type="submit" title="Add tag" aria-label="Add tag">✓</button></form></div><div class="data-table-scroll"><div class="field-grid meta-field-grid" role="table" aria-label="${title}">${header}${rows || '<div class="field-grid-empty" role="row"><span role="cell">No tags</span>'}</div></div></section>`;
    const table = rowsFor(scope);
    const canonicalGrid = (gridTitle, rows, popups, gridScope) => `<section class="tag-scope-table"><div class="section-title"><span>${gridTitle}</span><span class="section-help">Package-level metadata</span></div>${gridScope === "package" ? createForm(gridScope) : ""}<div class="data-table-scroll canonical-table-surface"><div class="field-grid canonical-table flat-table meta-field-grid canonical-tag-grid" role="table" aria-label="${gridTitle}">${header}${rows || '<div class="field-grid-empty" role="row"><span role="cell">No tags</span></div>'}</div></div>${popups.join("")}</section>`;
    return `<section class="data-page schema-page">${canonicalGrid(title, table.rows, [], scope === "Package" ? "package" : "tracks")}${includeAttachments ? renderAttachments() : ""}</section>`;
  }

  function renderPackTagsPage() { return renderTagScopePage("Pack Tags", "Package", true); }

  function renderTrackArrayGrid(tracks) {
    const columns = trackColumns();
    const columnTemplate = trackArrayColumnTemplate(tracks, columns);
    // The giga table has its own explicit track list. Keep it on every row so
    // WebKit cannot fall back to the generic three-column field-grid default.
    const rowTemplateStyle = ` style="grid-template-columns:${columnTemplate} !important"`;
    const headerCells = ["#", "Track #", "Filename", ...columns.map(displayTrackKey)];
    const header = headerCells.map((label, index) => {
      const sortKey = index === 0 ? "row" : index === 1 ? "track" : index === 2 ? "filename" : columns[index - 3];
      const columnAttribute = index > 2 ? ` data-track-column-key="${esc(sortKey)}"` : "";
      return `<div class="field-grid-cell field-grid-heading" role="columnheader" data-sort="${esc(sortKey)}"${columnAttribute}><input class="tag-table-field field-grid-heading-input" value="${esc(label)}" disabled></div>`;
    }).join("");
    const popups = [];
    const rows = tracks.map((member, index) => {
      const trackNumber = trackNumberFor(member, index);
      const filename = member.name || member.path.split("/").pop() || member.path;
      const rowLabel = member.title || filename;
      const scalar = (value, key, scope, editable) => {
        const present = value !== undefined && value !== null && value !== "";
        const structured = present && typeof value === "object";
        const display = !present ? "—" : structured ? "[Nested Tags]" : String(value);
        const disabled = !editable || !present || structured ? " disabled" : "";
        const attributes = editable && present && !structured ? ` data-track-cell data-track-path="${esc(member.path)}" data-track-key="${esc(key)}" data-track-scope="${esc(scope)}"` : "";
        if (structured) {
          const popupID = `track-${index}-${key}`;
          const popup = multipleValuesPopupParts(value, { target:"member", path:member.path, scope, key, popupID, title:key }, { editable:true });
          popups.push(popup.popup);
          return popup.trigger;
        }
        return `<input class="tag-table-field track-array-value${editable && present ? " track-cell" : ""}" value="${esc(display)}" aria-label="${esc(rowLabel)} ${esc(key)}"${attributes}${disabled}>`;
      };
      const metadataCells = columns.map(key => {
        const extension = key.startsWith("extension.");
        const fieldKey = extension ? key.slice("extension.".length) : key;
        const source = extension ? member.extensions : member.metadata;
        return `<div class="field-grid-cell" role="cell" data-track-column-key="${esc(key)}">${scalar(source?.[fieldKey], fieldKey, extension ? "memberExtensions" : "memberMetadata", true)}</div>`;
      }).join("");
      const row = `<div class="field-grid-row track-array-row" role="row"${rowTemplateStyle}><div class="field-grid-cell" role="cell">${scalar(index + 1, "row", "memberMetadata", false)}</div><div class="field-grid-cell" role="cell">${scalar(trackNumber, "track", "memberMetadata", false)}</div><div class="field-grid-cell" role="cell">${scalar(filename, "filename", "memberMetadata", false)}</div>${metadataCells}</div>`;
      return row;
    }).join("");
    const empty = `<div class="field-grid-empty" role="row"><span role="cell">No playable tracks</span></div>`;
    return `<div class="field-grid canonical-table giga-table tracks-field-grid" data-field-grid="tracks" role="table" aria-label="Tracks" style="--field-grid-columns:${columnTemplate}"><div class="field-grid-row field-grid-header" role="row"${rowTemplateStyle}>${header}</div>${rows || empty}</div>${popups.join("")}`;
  }

  function trackArrayColumnTemplate(tracks, columns) {
    const canvas = document.createElement("canvas");
    const context = canvas.getContext("2d");
    if (!context) return "32px 64px 220px " + columns.map(() => "160px").join(" ");
    context.font = "10px ui-monospace, SFMono-Regular, Menlo, monospace";
    const widthFor = values => {
      const measured = values.map(value => context.measureText(String(value ?? "")).width).filter(Number.isFinite);
      return Math.max(58, Math.ceil(Math.max(...measured, 0) + 18));
    };
    const widths = [
      32,
      widthFor(["Track #", ...tracks.map((member, index) => String(trackNumberFor(member, index)).padStart(2, "0"))]),
      widthFor(["Filename", ...tracks.map(member => member.name || member.path.split("/").pop() || member.path)]),
      ...columns.map(key => widthFor([displayTrackKey(key), ...tracks.map(member => {
        const value = memberFields(member)[key];
        if (value === null || value === undefined || value === "") return "—";
        if (typeof value === "object") return "[Nested Tags]";
        return String(value);
      })]))
    ];
    return widths.map(width => width + "px").join(" ");
  }

  function visibleFileMembers() {
    const query = $("#member-filter")?.value.trim().toLocaleLowerCase() || "";
    return state.members.filter(member => !query || [member.name, member.path, member.role, member.format, member.title, member.artist, member.album, ...Object.values(memberFields(member))].some(value => String(typeof value === "object" ? JSON.stringify(value) : (value || "")).toLocaleLowerCase().includes(query)));
  }

  function fileTagEntries(member) {
    return [
      ...Object.entries(member.metadata || {}).map(([key, value]) => ({ key, value, scope:"memberMetadata" })),
      ...Object.entries(member.extensions || {}).map(([key, value]) => ({ key:`extension.${key}`, value, scope:"memberExtensions" }))
    ].filter(entry => hasMeaningfulTagValue(entry.value)).sort((a, b) => a.key.localeCompare(b.key, undefined, { numeric:true, sensitivity:"base" }));
  }

  function memberTagValueMarkup(member, entry) {
    return `<input class="tag-table-field file-tag-value" data-file-tag-value value="${esc(String(entry.value))}" aria-label="Value for ${esc(entry.key)}">`;
  }

  function renderTrackTagTable(member) {
    const entries = fileTagEntries(member);
    const header = canonicalHeaderMarkup(["#", "Scope", "Tag Name", "Tag Value", "✓", "×"]);
    const rows = entries.map((entry, index) => {
      const structured = entry.value && typeof entry.value === "object";
      let valueMarkup = memberTagValueMarkup(member, entry);
      let subrow = "";
      if (structured) {
        const foldID = `file-tag-${index}`;
        valueMarkup = multipleValuesTriggerMarkup(foldID);
        const subtable = multipleValuesSubtableMarkup(entry.value, { target:"member", path:member.path, scope:entry.scope, key:entry.key, foldID, title:entry.key }, { editable:true });
        subrow = `<div class="field-grid-row inserted-table-row" role="row" data-canonical-subrow="${esc(foldID)}"><div class="field-grid-cell inserted-table-cell" role="cell">${subtable}</div></div>`;
      }
      const foldAttribute = structured ? ` data-multiple-fold-id="file-tag-${index}"` : "";
      return `<div class="field-grid-row" role="row" data-file-tag-row data-file-tag-path="${esc(member.path)}" data-file-tag-scope="${esc(entry.scope)}" data-file-tag-from="${esc(entry.key)}"${foldAttribute}><div class="field-grid-cell tag-number-cell" role="cell"><input class="tag-table-field file-tag-number" value="${index + 1}" aria-label="Tag number" disabled></div><div class="field-grid-cell tag-type-cell" role="cell"><input class="tag-table-field file-tag-scope" value="${entry.scope === "memberExtensions" ? "extension" : "metadata"}" disabled></div><div class="field-grid-cell tag-name-cell" role="cell"><input class="tag-table-field file-tag-key" data-file-tag-key value="${esc(entry.key)}" aria-label="Tag name"></div><div class="field-grid-cell tag-value-cell" role="cell"><span class="tag-inline-editor">${valueMarkup}</span></div><div class="field-grid-cell tag-submit-cell" role="cell"><button class="icon-button" data-action="commitFileTag" title="Submit changed tag" aria-label="Submit changed tag">✓</button></div><div class="field-grid-cell tag-delete-cell" role="cell"><button class="icon-button danger" data-action="deleteFileTag" title="Delete tag" aria-label="Delete tag">×</button></div></div>${subrow}`;
    }).join("");
    const empty = '<div class="field-grid-empty" role="row"><span role="cell">No tags on this file</span></div>';
    return `<div class="field-grid canonical-table flat-table track-browser-field-grid canonical-tag-grid" role="table" aria-label="Tags for ${esc(member.name)}">${header}${rows || empty}</div>`;
  }

  function renderTrackPage() {
    const candidates = state.members.filter(member => fileTagEntries(member).length > 0);
    const selected = candidates.find(member => member.path === trackBrowserPath)
      || candidates.find(member => member.path === state.selectedMemberPath)
      || candidates[0];
    trackBrowserPath = selected?.path || "";
    const sidebarHeader = canonicalHeaderMarkup(["#", "Filename", "Tags"]);
    const sidebarRows = candidates.map((member, index) => {
      const selectedClass = member.path === trackBrowserPath ? " selected" : "";
      const tagCount = fileTagEntries(member).length;
      const dirty = dirtyTrackPaths.has(member.path);
      const tagLabel = dirty ? `${tagCount} •` : String(tagCount);
      return `<div class="field-grid-row${selectedClass}" role="row" tabindex="0" aria-label="Select ${esc(member.name)}" aria-selected="${member.path === trackBrowserPath}" data-action="selectTrackBrowserMember" data-track-browser-path="${esc(member.path)}" data-track-browser-row><div class="field-grid-cell" role="cell"><input class="tag-table-field track-browser-sidebar-number" value="${index + 1}" aria-label="Track number" disabled></div><div class="field-grid-cell" role="cell"><input class="tag-table-field file-name-field" value="${esc(member.name)}" aria-label="Filename" disabled></div><div class="field-grid-cell" role="cell"><input class="tag-table-field track-browser-sidebar-status${dirty ? " dirty" : ""}" value="${esc(tagLabel)}" aria-label="Tag count" disabled></div></div>`;
    }).join("");
    const sidebar = `<section class="track-browser-pane track-browser-sidebar-pane" aria-label="Tagged files"><div class="data-table-scroll canonical-table-surface track-browser-scroll"><div class="field-grid canonical-table flat-table track-browser-sidebar-field-grid" role="table" aria-label="Tagged tracks">${sidebarHeader}${sidebarRows || '<div class="field-grid-empty" role="row"><span role="cell">No files with tags</span></div>'}</div></div></section>`;
    const detailContent = selected
      ? renderTrackTagTable(selected)
      : '<div class="empty-tab"><strong>No tagged files</strong><span>Files with metadata or extensions will appear here.</span></div>';
    const detail = `<section class="track-browser-pane track-browser-detail-pane" aria-label="Selected track tags"><div class="data-table-scroll canonical-table-surface track-browser-scroll">${detailContent}</div></section>`;
    return `<section class="data-page track-browser-page">${sidebar}${detail}</section>`;
  }

  function selectTrackBrowserMember(path) {
    if (!path || path === trackBrowserPath) return;
    trackBrowserPath = path;
    bridge("selectMember", { path });
    render(state);
  }

  function renderFilesPage() {
    const members = visibleFileMembers();
    const header = ["#", "Role", "Format", "Filename", "Stored path", "Tags Count", "Size", "View"].map(label => `<div class="field-grid-cell field-grid-heading" role="columnheader"><input class="tag-table-field field-grid-heading-input" value="${esc(label)}" disabled></div>`).join("");
    const rows = members.map((member, index) => `<div class="field-grid-row file-row" role="row" tabindex="0" data-track-row="${esc(member.path)}" title="Open metadata for ${esc(member.name)}"><div class="field-grid-cell" role="cell"><input class="tag-table-field file-number" value="${index + 1}" aria-label="File number" disabled></div><div class="field-grid-cell" role="cell"><input class="tag-table-field" value="${esc(member.role)}" disabled></div><div class="field-grid-cell" role="cell"><input class="tag-table-field" value="${esc(member.format || "unknown")}" disabled></div><div class="field-grid-cell" role="cell"><input class="tag-table-field file-name-field" data-file-name data-file-path="${esc(member.path)}" value="${esc(member.name)}" aria-label="Filename"></div><div class="field-grid-cell" role="cell"><input class="tag-table-field file-path-field" value="${esc(member.path)}" disabled></div><div class="field-grid-cell" role="cell"><input class="tag-table-field file-tags-count" value="${fileTagEntries(member).length}" aria-label="Tag count" disabled></div><div class="field-grid-cell" role="cell"><input class="tag-table-field" value="${esc(bytes(member.bytes))}" disabled></div><div class="field-grid-cell field-grid-action-cell" role="cell">${member.previewable ? `<button class="icon-button" data-action="previewMember" data-preview-path="${esc(member.path)}" title="View bundled text" aria-label="View bundled text">⌕</button>` : `<span class="field-grid-action-placeholder" title="Text preview unavailable" aria-label="Text preview unavailable">—</span>`}</div></div>`).join("");
    const empty = `<div class="field-grid-empty" role="row"><span role="cell">No package members match this filter</span></div>`;
    const preview = state.filePreviewPath
      ? `<div class="file-preview-backdrop" role="presentation"><section class="file-preview" role="dialog" aria-modal="true" aria-label="Bundled file preview"><div class="file-preview-heading"><div><strong>${esc(state.filePreviewName || "Bundled file")}</strong><span>${esc(state.filePreviewPath)}</span></div><button class="icon-button" data-action="closeFilePreview" title="Close preview" aria-label="Close preview">×</button></div>${state.filePreviewError ? `<div class="file-preview-error">${esc(state.filePreviewError)}</div>` : `<pre class="file-preview-content">${esc(state.filePreviewContent)}</pre>${state.filePreviewTruncated ? '<div class="file-preview-note">Preview limited to the first 4 MiB. The bundled file remains unchanged.</div>' : ""}`}</section></div>`
      : "";
    return `<section class="data-page files-page"><div class="data-table-scroll canonical-table-surface giga-table-surface file-table-surface"><div class="field-grid canonical-table giga-table file-field-grid" role="table" aria-label="Package files"><div class="field-grid-row field-grid-header" role="row">${header}</div>${rows || empty}</div></div>${preview}</section>`;
  }

  function renderAttachments() {
    const assets = state.members.filter(member => member.role !== "playable" && member.role !== "track");
    if (!assets.length) return "";
    const header = ["#", "Role", "Format", "Filename", "Stored path", "Size"].map(label => `<div class="field-grid-cell field-grid-heading" role="columnheader"><input class="tag-table-field field-grid-heading-input" value="${esc(label)}" disabled></div>`).join("");
    const rows = assets.map((asset, index) => `<div class="field-grid-row attachment-row" role="row" tabindex="0" data-track-row="${esc(asset.path)}" title="Open metadata for ${esc(asset.name)}"><div class="field-grid-cell" role="cell"><input class="tag-table-field file-number" value="${index + 1}" aria-label="Attachment number" disabled></div><div class="field-grid-cell" role="cell"><input class="tag-table-field" value="${esc(asset.role)}" disabled></div><div class="field-grid-cell" role="cell"><input class="tag-table-field" value="${esc(asset.format || "unknown")}" disabled></div><div class="field-grid-cell" role="cell"><input class="tag-table-field file-name-field" value="${esc(asset.name)}" disabled></div><div class="field-grid-cell" role="cell"><input class="tag-table-field file-path-field" value="${esc(asset.path)}" disabled></div><div class="field-grid-cell" role="cell"><input class="tag-table-field" value="${esc(bytes(asset.bytes))}" disabled></div></div>`).join("");
    return `<section class="inspector-section attachments-section"><div class="section-title"><span>Attachments</span><span class="section-help">${assets.length} package files</span></div><div class="data-table-scroll canonical-table-surface attachment-table-scroll"><div class="field-grid canonical-table flat-table attachment-field-grid" role="table" aria-label="Package attachments"><div class="field-grid-row field-grid-header" role="row">${header}</div>${rows}</div></div></section>`;
  }

  function renderInspector() {
    const hasPackage = Boolean(state.documentName);
    const inspector = $("#inspector-content");
    inspector.className = `inspector-content${mainView === "trackBrowser" ? " track-browser-inspector" : ""}`;
    if (!hasPackage) {
      inspector.innerHTML = `<div class="metadata-empty"><div class="empty-icon">⌁</div><h3>Open a package to edit metadata</h3><p>Choose a collection entry or open a UAC file.</p></div>`;
      return;
    }
    let html = "";
    if (mainView === "files") html += renderFilesPage();
    else if (mainView === "packTags") html += renderPackTagsPage();
    else if (mainView === "trackBrowser") html += renderTrackPage();
    inspector.innerHTML = html;
  }

  function scopeToAction(scope) {
    return ({ gameMetadata:"setGameMetadata", gameExtensions:"setGameExtensions", memberMetadata:"setMemberMetadata", memberExtensions:"setMemberExtensions" })[scope];
  }

  function commitObjectEditor(scope) {
    const list = $(`[data-editor="${CSS.escape(scope)}"]`);
    if (!list) return;
    const object = {};
    for (const row of $$(".field-row", list)) {
      const key = $("[data-field-key]", row).value.trim();
      if (!key) continue;
      if (Object.prototype.hasOwnProperty.call(object, key)) { $(`[data-error-for="${scope}"]`).textContent = "Field names must be unique."; return; }
      const raw = $("[data-field-value]", row).value;
      const kind = $("[data-field-type]", row)?.value || row.dataset.kind;
      try {
        if (kind === "string") object[key] = raw;
        else if (kind === "number") { const number = Number(raw); if (!Number.isFinite(number)) throw new Error(); object[key] = number; }
        else if (kind === "boolean") { if (!/^(true|false)$/i.test(raw.trim())) throw new Error(); object[key] = raw.trim().toLowerCase() === "true"; }
        else object[key] = JSON.parse(raw);
      }
      catch { $(`[data-error-for="${scope}"]`).textContent = `Invalid JSON value in “${key}”.`; return; }
    }
    $(`[data-error-for="${scope}"]`).textContent = "";
    bridge(scopeToAction(scope), { value:JSON.stringify(object, null, 2) });
  }

  function addField(scope) {
    const list = $(`[data-editor="${CSS.escape(scope)}"]`);
    if (!list) return;
    const row = document.createElement("tr");
    row.className = "field-row";
    row.dataset.kind = "string";
    row.innerHTML = `<td><input class="field-key" data-field-key data-focus-id="${esc(scope)}-new-${Date.now()}" placeholder="Field name"></td><td><input class="field-value" data-field-value placeholder="Value"></td><td class="field-type-cell"><select class="field-type" data-field-type aria-label="Value type"><option value="string" selected>text</option><option value="number">number</option><option value="boolean">boolean</option><option value="json">json</option></select></td><td class="field-action-cell"><button class="remove-field" data-action="removeField" title="Remove field">×</button></td>`;
    list.append(row);
    $("[data-field-key]", row).focus();
  }

  function coerceValue(raw, kind) {
    if (kind === "string") return raw;
    if (kind === "number") {
      const number = Number(raw);
      if (!Number.isFinite(number)) throw new Error();
      return number;
    }
    if (kind === "boolean") {
      if (!/^(true|false)$/i.test(raw.trim())) throw new Error();
      return raw.trim().toLowerCase() === "true";
    }
    return JSON.parse(raw);
  }

  function commitTrackCell(target) {
    const member = state.members.find(item => item.path === target.dataset.trackPath);
    if (!member) return;
    const scope = target.dataset.trackScope;
    const key = target.dataset.trackKey;
    const source = scope === "memberExtensions" ? member.extensions : member.metadata;
    const values = { ...(source || {}) };
    try { values[key] = coerceValue(target.value, fieldKind(values[key] ?? "")); }
    catch { return; }
    dirtyTrackPaths.add(member.path);
    bridge("selectMember", { path:member.path });
    bridge(scopeToAction(scope), { value:JSON.stringify(values, null, 2) });
  }

  function markTrackDirty(path) {
    if (path) dirtyTrackPaths.add(path);
  }

  function markAllTracksDirty() {
    playableMembers().forEach(member => markTrackDirty(member.path));
  }

  function addMultipleValue(editor) {
    const rows = $(".multiple-values-rows", editor);
    if (!rows) return;
    const isArray = editor.dataset.multipleArray === "true";
    const popupLayout = editor.dataset.multipleLayout === "popup";
    const canonicalLayout = ["canonical", "subtable", "popup"].includes(editor.dataset.multipleLayout);
    const subtableLayout = editor.dataset.multipleLayout === "subtable";
    const tableLayout = subtableLayout || popupLayout;
    const number = $$('[data-multiple-entry]', rows).length + 1;
    $(".multiple-values-empty", rows)?.remove();
    const row = document.createElement("div");
    row.className = canonicalLayout ? "field-grid-row multiple-value-editor-row" : "tag-multiple-value-row multiple-value-editor-row";
    row.dataset.multipleEntry = "";
    row.dataset.multipleKind = "string";
    const keyMarkup = `<input class="${canonicalLayout ? "tag-table-field " : ""}multiple-value-key" data-multiple-key value="" aria-label="New value key"${isArray ? " disabled" : ""}>`;
    const valueMarkup = `<input class="${canonicalLayout ? "tag-table-field " : ""}multiple-value-editor" data-multiple-value value="" aria-label="New value">`;
    const numberMarkup = tableLayout ? `<div class="field-grid-cell"><input class="tag-table-field multiple-value-number" value="${number}" aria-label="Value number ${number}" disabled></div>` : "";
    const submitMarkup = tableLayout ? '<button class="icon-button multiple-value-submit" data-action="commitMultipleValueRow" type="button" title="Submit changed value" aria-label="Submit changed value">✓</button>' : "";
    const removeMarkup = `<button class="icon-button danger multiple-value-remove" data-action="removeMultipleValue" type="button" title="Remove value" aria-label="Remove value">×</button>`;
    row.innerHTML = canonicalLayout
      ? `${numberMarkup}<div class="field-grid-cell">${keyMarkup}</div><div class="field-grid-cell">${valueMarkup}</div>${tableLayout ? `<div class="field-grid-cell field-grid-action-cell">${submitMarkup}</div>` : ""}<div class="field-grid-cell field-grid-action-cell">${removeMarkup}</div>`
      : `${keyMarkup}${valueMarkup}${removeMarkup}`;
    rows.append(row);
    $("[data-multiple-key]", row)?.focus();
  }

  function removeMultipleValue(row) {
    const editor = row?.closest("[data-multiple-editor]");
    if (!row || !editor) return;
    row.remove();
    const rows = $(".multiple-values-rows", editor);
    if (rows && !$("[data-multiple-entry]", rows)) {
      rows.innerHTML = ["subtable", "popup"].includes(editor.dataset.multipleLayout)
        ? '<div class="field-grid-empty multiple-values-empty" role="row"><span role="cell">No values</span></div>'
        : '<div class="file-tag-empty multiple-values-empty">No values</div>';
    }
  }

  function collectMultipleValues(editor) {
    if (!editor) return null;
    const error = $(".multiple-values-editor-error", editor);
    const isArray = editor.dataset.multipleArray === "true";
    const result = isArray ? [] : {};
    const seenKeys = new Set();
    for (const row of $$("[data-multiple-entry]", editor)) {
      const key = isArray ? String(result.length) : $("[data-multiple-key]", row)?.value.trim() || "";
      if (!isArray && !key) {
        if (error) error.textContent = "Keys cannot be empty.";
        $("[data-multiple-key]", row)?.focus();
        return null;
      }
      if (!isArray && seenKeys.has(key)) {
        if (error) error.textContent = "Keys must be unique.";
        $("[data-multiple-key]", row)?.focus();
        return null;
      }
      seenKeys.add(key);
      const raw = $("[data-multiple-value]", row)?.value ?? "";
      try {
        const value = coerceValue(raw, row.dataset.multipleKind || "string");
        if (isArray) result.push(value); else result[key] = value;
      } catch {
        if (error) error.textContent = `Invalid JSON value for “${key || "value"}”.`;
        $("[data-multiple-value]", row)?.focus();
        return null;
      }
    }
    if (error) error.textContent = "";
    return { result, valueJSON:JSON.stringify(result) };
  }

  function commitMultipleValues(editor) {
    const collected = collectMultipleValues(editor);
    if (!editor || !collected) return false;
    const { valueJSON } = collected;
    const tagRow = editor.closest("[data-tag-row]");
    const fileRow = editor.closest("[data-file-tag-row]");
    if (editor.dataset.multipleTarget === "metadata") {
      const key = editor.dataset.multipleKey || tagRow?.dataset.tagFrom || "";
      let newKey = $("[data-tag-to]", tagRow)?.value.trim() || key;
      if (key.startsWith("extension.") && !newKey.startsWith("extension.")) newKey = `extension.${newKey}`;
      bridge("commitMetadataRow", { key, newKey, scope:editor.dataset.multipleScope || "", value:null, valueJSON });
    } else {
      const key = editor.dataset.multipleKey || fileRow?.dataset.fileTagFrom || "";
      const path = editor.dataset.multiplePath || fileRow?.dataset.fileTagPath || "";
      const newKey = $("[data-file-tag-key]", fileRow)?.value || key;
      markTrackDirty(path);
      bridge("commitMemberTag", { path, scope:editor.dataset.multipleScope || fileRow?.dataset.fileTagScope || "memberMetadata", key, newKey, value:"", valueJSON });
    }
    return true;
  }

  function commitMultipleValueRow(row) {
    const editor = row?.closest("[data-multiple-editor]");
    if (!row || !editor) return;
    const error = $(".multiple-values-editor-error", editor);
    const key = editor.dataset.multipleArray === "true" ? "value" : $("[data-multiple-key]", row)?.value.trim() || "value";
    try {
      coerceValue($("[data-multiple-value]", row)?.value ?? "", row.dataset.multipleKind || "string");
    } catch {
      if (error) error.textContent = `Invalid JSON value for “${key}”.`;
      $("[data-multiple-value]", row)?.focus();
      return;
    }
    commitMultipleValues(editor);
  }

  function commitMultipleValuesPopup(popup) {
    const editor = $("[data-multiple-editor]", popup);
    if (editor) {
      if (commitMultipleValues(editor)) closeMultipleValuesPopup(popup);
      return;
    }
    const textarea = $("[data-multiple-popup-text]", popup);
    const error = $(".multiple-values-popup-error", popup);
    if (!textarea) return;
    let value;
    try {
      value = JSON.parse(textarea.value);
    } catch {
      if (error) error.textContent = "Invalid JSON. Correct the value before submitting.";
      textarea.focus();
      return;
    }
    if (error) error.textContent = "";
    const key = popup.dataset.multipleKey || "";
    if (popup.dataset.multipleTarget === "metadata") {
      bridge("commitMetadataRow", { key, newKey:key, scope:popup.dataset.multipleScope || "", value:null, valueJSON:JSON.stringify(value) });
    } else {
      const path = popup.dataset.multiplePath || "";
      markTrackDirty(path);
      bridge("commitMemberTag", { path, scope:popup.dataset.multipleScope || "memberMetadata", key, newKey:key, value:"", valueJSON:JSON.stringify(value) });
    }
    closeMultipleValuesPopup(popup);
  }

  function multipleValuesEditorForRow(row) {
    const inlineEditor = $("[data-multiple-editor]", row);
    if (inlineEditor) return inlineEditor;
    const foldID = row?.dataset.multipleFoldId;
    if (foldID) {
      const childEditor = document.querySelector(`[data-canonical-subrow="${CSS.escape(foldID)}"] [data-multiple-editor]`);
      if (childEditor) return childEditor;
    }
    const popupID = row?.dataset.multiplePopupId;
    return popupID ? document.querySelector(`[data-multiple-values-popup="${CSS.escape(popupID)}"] [data-multiple-editor]`) : null;
  }

  function closeMultipleValuesPopup(popup) {
    if (!popup) return;
    popup.hidden = true;
    const popupID = popup.dataset.multipleValuesPopup || "";
    $$(`[data-action="toggleMultipleValuesPopup"][data-popup-id="${CSS.escape(popupID)}"]`).forEach(toggle => {
      toggle.setAttribute("aria-expanded", "false");
      $(".canonical-fold-icon", toggle).textContent = "＋";
    });
  }

  function closeCanonicalSubtable(button) {
    const foldID = button?.dataset.foldId || "";
    const subrow = foldID ? document.querySelector(`[data-canonical-subrow="${CSS.escape(foldID)}"]`) : button?.closest("[data-canonical-subrow]");
    const toggle = foldID ? document.querySelector(`[data-action="toggleCanonicalFold"][data-fold-id="${CSS.escape(foldID)}"]`) : null;
    subrow?.classList.remove("open");
    toggle?.setAttribute("aria-expanded", "false");
    if (toggle) $(".canonical-fold-icon", toggle).textContent = "＋";
    toggle?.focus({ preventScroll:true });
  }

  let trackContextMenu = null;
  function closeTrackContextMenu() {
    trackContextMenu?.remove();
    trackContextMenu = null;
  }

  function showTrackContextMenu(key, clientX, clientY) {
    closeTrackContextMenu();
    const menu = document.createElement("div");
    menu.className = "track-context-menu";
    menu.dataset.trackContextMenu = "";
    menu.innerHTML = `<button type="button" data-action="deleteTrackColumn" data-track-column-key="${esc(key)}">Delete tag column</button>`;
    document.body.append(menu);
    const bounds = menu.getBoundingClientRect();
    menu.style.left = Math.max(8, Math.min(clientX, window.innerWidth - bounds.width - 8)) + "px";
    menu.style.top = Math.max(8, Math.min(clientY, window.innerHeight - bounds.height - 8)) + "px";
    trackContextMenu = menu;
  }

  function toggleMultipleValuesPopup(popupID, toggle) {
    const popup = document.querySelector(`[data-multiple-values-popup="${CSS.escape(popupID)}"]`);
    if (!popup) return;
    const opening = popup.hidden;
    $$(`[data-multiple-values-popup]`).forEach(closeMultipleValuesPopup);
    if (!opening) return;
    popup.hidden = false;
    toggle?.setAttribute("aria-expanded", "true");
    $(".canonical-fold-icon", toggle).textContent = "−";
    $(".multiple-values-popup-close", popup)?.focus({ preventScroll:true });
  }

  document.addEventListener("click", event => {
    if (!event.target.closest(".track-context-menu")) closeTrackContextMenu();
    const popupBackdrop = event.target.closest("[data-multiple-values-popup]");
    if (popupBackdrop && event.target === popupBackdrop) {
      closeMultipleValuesPopup(popupBackdrop);
      return;
    }
    const action = event.target.closest("[data-action]")?.dataset.action;
    const packageItem = event.target.closest("[data-package]");
    const memberRow = event.target.closest("tr[data-member]");
    const trackRow = event.target.closest("[data-track-row]");
    if (packageItem) { bridge("selectPackage", { path:packageItem.dataset.package }); return; }
    if (memberRow && !event.target.closest("input[type=checkbox]")) {
      mainView = "trackBrowser";
      trackBrowserPath = memberRow.dataset.member;
      bridge("selectMember", { path:memberRow.dataset.member });
      render(state);
    }
    if (trackRow && !event.target.closest("input,button,form,.canonical-fold")) {
      const path = trackRow.dataset.trackRow;
      mainView = "trackBrowser";
      trackBrowserPath = path;
      bridge("selectMember", { path });
      render(state);
    }
    if (!action) return;
    if (action === "addField") addField(event.target.closest("[data-scope]").dataset.scope);
    else if (action === "renameTag") {
      const row = event.target.closest("[data-tag-row]");
      const from = row?.dataset.tagFrom || "";
      const rawTo = $("[data-tag-to]", row)?.value.trim() || "";
      const normalizedTo = rawTo === from ? from : titleCaseTagName(rawTo);
      if (from && normalizedTo && from !== normalizedTo) bridge("renameMetadataKey", { from, to:normalizedTo });
    }
    else if (action === "deleteTag") {
      const row = event.target.closest("[data-tag-row]");
      const key = row?.dataset.tagFrom || "";
      if (key) animateRowRemoval(row, () => bridge("deleteMetadataKey", { key, scope:row.dataset.tagScope || "" }));
    }
    else if (action === "deleteTrackColumn") {
      const key = event.target.closest("[data-track-column-key]")?.dataset.trackColumnKey || "";
      closeTrackContextMenu();
      if (key && window.confirm(`Delete the entire “${displayTrackKey(key)}” tag column from all tracks?`)) {
        markAllTracksDirty();
        bridge("deleteMetadataKey", { key, scope:"tracks" });
      }
    }
    else if (action === "selectTrackBrowserMember") {
      const row = event.target.closest("[data-track-browser-row]");
      const path = row?.dataset.trackBrowserPath || "";
      selectTrackBrowserMember(path);
    }
    else if (action === "addMultipleValue") addMultipleValue(event.target.closest("[data-multiple-editor]"));
    else if (action === "removeMultipleValue") removeMultipleValue(event.target.closest("[data-multiple-entry]"));
    else if (action === "commitMultipleValueRow") commitMultipleValueRow(event.target.closest("[data-multiple-entry]"));
    else if (action === "commitMultipleValues") {
      const popup = event.target.closest("[data-multiple-values-popup]");
      if (popup) commitMultipleValuesPopup(popup);
      else commitMultipleValues(event.target.closest("[data-multiple-editor]"));
    }
    else if (action === "toggleMultipleValuesPopup") toggleMultipleValuesPopup(event.target.closest("[data-action=toggleMultipleValuesPopup]")?.dataset.popupId || "", event.target.closest("[data-action=toggleMultipleValuesPopup]"));
    else if (action === "closeMultipleValuesPopup") closeMultipleValuesPopup(event.target.closest("[data-multiple-values-popup]"));
    else if (action === "closeCanonicalSubtable") closeCanonicalSubtable(event.target.closest("[data-action=closeCanonicalSubtable]"));
    else if (action === "toggleCanonicalFold") {
      const toggle = event.target.closest("[data-action=toggleCanonicalFold]");
      const fold = toggle?.closest(".canonical-fold");
      const panel = fold?.querySelector(".canonical-fold-panel");
      const subrow = toggle?.dataset.foldId ? document.querySelector(`[data-canonical-subrow="${CSS.escape(toggle.dataset.foldId)}"]`) : null;
      if (toggle && (panel || subrow)) {
        const target = panel || subrow;
        const open = target.classList.toggle("open");
        toggle.setAttribute("aria-expanded", String(open));
        $(".canonical-fold-icon", toggle).textContent = open ? "−" : "＋";
      }
    }
    else if (action === "previewMember") bridge("previewMember", { path:event.target.closest("[data-preview-path]")?.dataset.previewPath || "" });
    else if (action === "closeFilePreview") bridge("closeFilePreview");
    else if (action === "updateTagValue") {
      const row = event.target.closest("[data-tag-row]");
      if (row) bridge("updateMetadataValue", { key:row.dataset.tagFrom || "", value:$('[data-tag-value]', row)?.value || "" });
    }
    else if (action === "commitTagRow") {
      const row = event.target.closest("[data-tag-row]");
      if (row) {
        const popup = row.dataset.multiplePopupId ? document.querySelector(`[data-multiple-values-popup="${CSS.escape(row.dataset.multiplePopupId)}"]`) : null;
        if (popup) { commitMultipleValuesPopup(popup); return; }
        const editor = multipleValuesEditorForRow(row);
        if (editor) { commitMultipleValues(editor); return; }
        const from = row.dataset.tagFrom || "";
        const rawTo = $('[data-tag-to]', row)?.value.trim() || "";
        const to = rawTo === from ? from : titleCaseTagName(rawTo);
        bridge("commitMetadataRow", { key:from, newKey:to, scope:row.dataset.tagScope || "", value:$('[data-tag-value]', row)?.disabled ? null : ($('[data-tag-value]', row)?.value || "") });
      }
    }
    else if (action === "commitFileTag") {
      const row = event.target.closest("[data-file-tag-row]");
      if (row) {
        const popup = row.dataset.multiplePopupId ? document.querySelector(`[data-multiple-values-popup="${CSS.escape(row.dataset.multiplePopupId)}"]`) : null;
        if (popup) { commitMultipleValuesPopup(popup); return; }
        const editor = multipleValuesEditorForRow(row);
        if (editor) { commitMultipleValues(editor); return; }
        const from = row.dataset.fileTagFrom || "";
        const rawTo = $('[data-file-tag-key]', row)?.value.trim() || "";
        const newKey = rawTo === from ? from : titleCaseTagName(rawTo);
        markTrackDirty(row.dataset.fileTagPath || "");
        bridge("commitMemberTag", { path:row.dataset.fileTagPath || "", scope:row.dataset.fileTagScope || "", key:from, newKey, value:$('[data-file-tag-value]', row)?.value || "" });
      }
    }
    else if (action === "deleteFileTag") {
      const row = event.target.closest("[data-file-tag-row]");
      if (row) {
        markTrackDirty(row.dataset.fileTagPath || "");
        animateRowRemoval(row, () => bridge("deleteMemberTag", { path:row.dataset.fileTagPath || "", scope:row.dataset.fileTagScope || "", key:row.dataset.fileTagFrom || "" }));
      }
    }
    else if (action === "commitTechnicalRow") {
      const row = event.target.closest("[data-technical-row]");
      if (row) bridge("commitTechnicalRow", { scope:$('[data-tech-scope]', row)?.value || "", key:row.dataset.techKey || "", newKey:$('[data-tech-key]', row)?.value || "", value:$('[data-tech-value]', row)?.value || "" });
    }
    else if (action === "deleteTechnicalRow") {
      const row = event.target.closest("[data-technical-row]");
      if (row && window.confirm(`Delete ${row.dataset.techKey || "this technical field"}?`)) {
        const scope = row.dataset.techScope || "";
        const key = row.dataset.techKey || "";
        animateRowRemoval(row, () => bridge("deleteTechnicalRow", { scope, key }));
      }
    }
    else if (action === "removeField") {
      const row = event.target.closest(".field-row");
      const scope = row.closest("[data-editor]").dataset.editor;
      animateRowRemoval(row, () => commitObjectEditor(scope));
    } else if (action === "dismissError") bridge("dismissError");
    else if (action === "mainView") {
      mainView = event.target.closest("[data-view]").dataset.view;
      render(state);
    }
    else if (action === "closeInspector") { mainView = "members"; render(state); }
    else if (action === "rescanCollection") bridge("rescanCollection");
    else if (action === "cancelCollectionScan") bridge("cancelCollectionScan");
    else if (action === "cancelHarvest") bridge("cancelHarvest");
    else if (action === "openUAC" || action === "openCollection" || action === "save" || action === "revert" || action === "harvest") bridge(action);
  });

  document.addEventListener("submit", event => {
    const form = event.target.closest("[data-tag-create]");
    if (form) {
      event.preventDefault();
      bridge("addMetadataKey", { key:titleCaseTagName($('[data-new-tag-key]', form)?.value || ""), scope:form.dataset.tagScope || "package", value:$('[data-new-tag-value]', form)?.value || "" });
      return;
    }
  });

  document.addEventListener("focusin", event => {
    const row = event.target.closest("[data-track-browser-row]");
    if (row) selectTrackBrowserMember(row.dataset.trackBrowserPath || "");
  });

  document.addEventListener("pointerdown", event => {
    if (event.button !== 0) return;
    const row = event.target.closest("[data-track-browser-row]");
    if (row) selectTrackBrowserMember(row.dataset.trackBrowserPath || "");
  });

  document.addEventListener("change", event => {
    const target = event.target;
    if (target.matches("[data-track-cell]")) commitTrackCell(target);
    else if (target.matches("[data-file-name]")) bridge("renameMember", { path:target.dataset.filePath || "", name:target.value });
    else if (target.matches("[data-basic='packageTitle']")) bridge("setPackageTitle", { value:target.value });
    else if (target.matches("[data-basic='consoleName']")) bridge("setConsole", { value:target.value });
    else if (target.matches("[data-raw-editor]")) {
      const scope = target.dataset.rawEditor;
      bridge(scopeToAction(scope), { value:target.value });
    } else if (target.closest("[data-editor]")) commitObjectEditor(target.closest("[data-editor]").dataset.editor);
  });

  document.addEventListener("input", event => {
    if (event.target.id === "collection-filter") renderCollections();
    else if (event.target.id === "member-filter") mainView === "files" ? render(state) : renderMembers();
  });
  document.addEventListener("contextmenu", event => {
    const column = event.target.closest(".tracks-field-grid [data-track-column-key]");
    if (!column) {
      closeTrackContextMenu();
      return;
    }
    event.preventDefault();
    showTrackContextMenu(column.dataset.trackColumnKey || "", event.clientX, event.clientY);
  });
  document.addEventListener("click", event => {
    const header = event.target.closest("[data-sort]");
    if (header) {
      const key = header.dataset.sort;
      if (sort.key === key) sort.direction *= -1; else sort = { key, direction:1 };
      renderMembers();
    }
  });
  document.addEventListener("keydown", event => {
    if (event.key === "Escape") {
      if (trackContextMenu) { closeTrackContextMenu(); return; }
      const popup = $("[data-multiple-values-popup]:not([hidden])");
      if (popup) { closeMultipleValuesPopup(popup); return; }
    }
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "f") { event.preventDefault(); $("#collection-filter").focus(); }
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") { const field = $("#member-filter"); if (field) { event.preventDefault(); field.focus(); } }
  });

  window.UACMan = { render };
})();
