(() => {
  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
  const bridge = (action, values = {}) => window.webkit?.messageHandlers?.uacman?.postMessage({ action, ...values });
  const esc = value => String(value ?? "").replace(/[&<>"']/g, char => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;" }[char]));
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
  const canonicalCellMarkup = (content, options = {}) => {
    const classes = ["field-grid-cell", options.className].filter(Boolean).join(" ");
    const role = options.role || "cell";
    const attributes = options.attributes ? ` ${options.attributes}` : "";
    return `<div class="${classes}" role="${role}"${attributes}>${content}</div>`;
  };
  const canonicalNumberCellMarkup = (value, label, options = {}) => canonicalCellMarkup(
    `<input class="tag-table-field canonical-number-field" value="${esc(value)}" aria-label="${esc(label)}" disabled>`,
    { className:["canonical-number-cell", options.className].filter(Boolean).join(" "), attributes:options.attributes }
  );
  const canonicalRowMarkup = (cells, options = {}) => {
    const classes = ["field-grid-row", options.className].filter(Boolean).join(" ");
    const role = options.role || "row";
    const attributes = options.attributes ? ` ${options.attributes}` : "";
    const style = options.style ? ` style="${esc(options.style)}"` : "";
    return `<div class="${classes}" role="${role}"${attributes}${style}>${cells.join("")}</div>`;
  };
  const canonicalHeaderCellMarkup = (label, options = {}) => {
    const heading = `<input class="tag-table-field field-grid-heading-input" value="${esc(label)}" aria-label="${esc(label)}" disabled>`;
    return canonicalCellMarkup(heading, { ...options, className:["field-grid-heading", options.className].filter(Boolean).join(" "), role:"columnheader" });
  };
  const canonicalTitleRowMarkup = (title, className = "") => {
    const titleCell = canonicalCellMarkup(`<input class="tag-table-field field-grid-heading-input" value="${esc(title)}" aria-label="${esc(title)}" disabled>`, { className:"field-grid-heading", role:"columnheader" });
    return canonicalRowMarkup([titleCell], { className:["field-grid-header", "canonical-table-title-row", className].filter(Boolean).join(" ") });
  };
  const canonicalHeaderMarkup = (labels, options = {}) => canonicalRowMarkup(
    labels.map((label, index) => canonicalHeaderCellMarkup(label, options.cell?.(label, index) || {})),
    { className:"field-grid-header", attributes:options.attributes, style:options.style }
  );
  const canonicalTableMarkup = (options = {}) => {
    const classes = ["field-grid", "canonical-table", options.className].filter(Boolean).join(" ");
    const attributes = options.attributes ? ` ${options.attributes}` : "";
    const ariaLabel = options.ariaLabel ? ` aria-label="${esc(options.ariaLabel)}"` : "";
    const style = options.style ? ` style="${esc(options.style)}"` : "";
    const rows = options.rows || options.empty || "";
    return `<div class="${classes}" role="table"${ariaLabel}${attributes}${style}>${options.header || ""}${rows}</div>${options.trailing || ""}`;
  };
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
  const nestedJSONValueMarkup = (value, key, editable = true) => {
    const raw = JSON.stringify(value, null, 2);
    const body = editable
      ? `<textarea class="tag-table-field nested-json-editor" data-multiple-value aria-label="JSON value for ${esc(key)}">${esc(raw)}</textarea>`
      : `<pre class="nested-json-preview">${esc(raw)}</pre>`;
    return `<details class="nested-json-dropdown"><summary class="nested-json-trigger"><span>[Nested Tags]</span><span class="canonical-fold-icon">＋</span></summary><div class="nested-json-panel">${body}</div></details>`;
  };
  const multipleValuesCloseMarkup = context => context.foldID
    ? `<button class="tag-table-field field-grid-heading-input multiple-values-header-action multiple-values-subtable-close" data-action="closeCanonicalSubtable" data-fold-id="${esc(context.foldID)}" ${context.closeAttributes || ""} type="button" title="Close nested tags table" aria-label="Close nested tags table">×</button>`
    : `<button class="tag-table-field field-grid-heading-input multiple-values-header-action multiple-values-popup-close" data-action="closeMultipleValuesPopup" data-popup-id="${esc(context.popupID || "")}" type="button" title="Close" aria-label="Close">×</button>`;
  const multipleValuesTableTitleRowMarkup = context => {
    const title = context.title || context.key || "Values";
    if (!context.titleClose) return canonicalTitleRowMarkup(title, "multiple-values-table-title-row");
    const heading = `<input class="tag-table-field field-grid-heading-input" value="${esc(title)}" aria-label="${esc(title)}" disabled>`;
    const titleControl = `<div class="multiple-values-table-title-control">${heading}${multipleValuesCloseMarkup(context)}</div>`;
    return canonicalRowMarkup([
      canonicalCellMarkup(titleControl, { className:"field-grid-heading", role:"columnheader" })
    ], { className:"field-grid-header canonical-table-title-row multiple-values-table-title-row" });
  };
  const multipleValuesTableHeaderRowMarkup = (context, editable) => {
    const submitMarkup = editable
      ? '<button class="tag-table-field field-grid-heading-input multiple-values-header-action" data-action="commitMultipleValues" type="button" title="Submit all changed values" aria-label="Submit all changed values">✓</button>'
      : '<input class="tag-table-field field-grid-heading-input" value="" aria-label="Submit" disabled>';
    return canonicalRowMarkup([
      canonicalHeaderCellMarkup("#"),
      canonicalHeaderCellMarkup("Tag Name"),
      canonicalHeaderCellMarkup("Tag Value"),
      canonicalCellMarkup(submitMarkup, { className:"field-grid-heading field-grid-action-cell", role:"columnheader" }),
      canonicalCellMarkup(multipleValuesCloseMarkup(context), { className:"field-grid-heading field-grid-action-cell", role:"columnheader" })
    ], { className:"field-grid-header multiple-values-table-header-row" });
  };
  const multipleValuesTableChromeMarkup = (context, editable) => `${multipleValuesTableTitleRowMarkup(context)}${multipleValuesTableHeaderRowMarkup(context, editable)}`;
  const multipleValuesEditorBodyMarkup = (value, context = {}) => {
    const isArray = Array.isArray(value);
    const popupLayout = context.layout === "popup";
    const subtableLayout = context.layout === "subtable";
    const gridClass = context.layout === "subtable" ? "inserted-table-grid" : "canonical-popup-field-grid";
    const entries = isArray ? value.map((item, index) => [String(index), item]) : Object.entries(value || {});
    const rowMarkup = ([key, item], index) => {
      const kind = fieldKind(item);
      const raw = kind === "json" ? JSON.stringify(item, null, 2) : String(item ?? "");
      const valueControl = kind === "json"
        ? nestedJSONValueMarkup(item, key)
        : `<input class="tag-table-field multiple-value-editor" data-multiple-value value="${esc(raw)}" aria-label="Value for ${esc(key)}">`;
      const keyMarkup = `<input class="tag-table-field multiple-value-key" data-multiple-key value="${esc(key)}" aria-label="Key for ${esc(key)}"${isArray ? " disabled" : ""}>`;
      const numberMarkup = canonicalNumberCellMarkup(index + 1, `Value number ${index + 1}`, { className:"multiple-value-number-cell" });
      const removeMarkup = `<button class="icon-button danger multiple-value-remove" data-action="removeMultipleValue" type="button" title="Remove value" aria-label="Remove value">×</button>`;
      const submitMarkup = '<button class="icon-button multiple-value-submit" data-action="commitMultipleValueRow" type="button" title="Submit changed value" aria-label="Submit changed value">✓</button>';
      const cells = [
        numberMarkup,
        canonicalCellMarkup(keyMarkup),
        canonicalCellMarkup(valueControl),
        canonicalCellMarkup(submitMarkup, { className:"field-grid-action-cell" }),
        canonicalCellMarkup(removeMarkup, { className:"field-grid-action-cell" })
      ];
      return canonicalRowMarkup(cells, { className:"multiple-value-editor-row", attributes:`data-multiple-entry data-multiple-kind="${kind}"` });
    };
    const rows = entries.map(rowMarkup).join("");
    const data = [
      `data-multiple-editor`,
      `data-multiple-target="${esc(context.target || "member")}"`,
      `data-multiple-array="${isArray}"`,
      `data-multiple-layout="${subtableLayout ? "subtable" : "popup"}"`,
      `data-multiple-path="${esc(context.path || "")}"`,
      `data-multiple-scope="${esc(context.scope || "")}"`,
      `data-multiple-key="${esc(context.key || "")}"`
    ].join(" ");
    const rowsMarkup = popupLayout
      ? `<div class="multiple-values-rows">${rows || '<div class="field-grid-empty multiple-values-empty" role="row"><span role="cell">No values</span></div>'}</div>`
      : `<div class="field-grid ${gridClass} canonical-multiple-values-grid" role="table">${multipleValuesTableChromeMarkup(context, true)}<div class="multiple-values-rows">${rows || '<div class="field-grid-empty multiple-values-empty" role="row"><span role="cell">No values</span></div>'}</div></div>`;
    const body = `<div class="multiple-values-editor canonical-multiple-values-editor${popupLayout ? " canonical-popup-editor" : ""}" ${data}>${rowsMarkup}<div class="multiple-values-editor-error" role="status"></div></div>`;
    return { body, count:entries.length };
  };
  const multipleValuesTriggerMarkup = foldID => `<button class="canonical-fold-toggle canonical-fold-trigger" type="button" data-action="toggleCanonicalFold" data-fold-id="${esc(foldID)}" aria-expanded="false"><span>[Nested Tags]</span><span class="canonical-fold-icon">＋</span></button>`;
  const multipleValuesReadOnlyTableMarkup = (entries, context = {}) => {
    const popupLayout = context.layout === "popup";
    const subtableLayout = context.layout === "subtable";
    const tableLayout = popupLayout || subtableLayout;
    const gridClass = subtableLayout ? "inserted-table-grid" : "canonical-popup-field-grid";
    const rows = entries.length
      ? entries.map(([key, item], index) => {
        const cells = [
          ...(tableLayout ? [canonicalNumberCellMarkup(index + 1, `Value number ${index + 1}`, { className:"multiple-value-number-cell" })] : []),
          canonicalCellMarkup(`<input class="tag-table-field" value="${esc(key)}" disabled>`),
          canonicalCellMarkup(item && typeof item === "object" ? nestedJSONValueMarkup(item, key, false) : `<input class="tag-table-field" value="${esc(String(item ?? "—"))}" disabled>`),
          ...(tableLayout ? [canonicalCellMarkup(""), canonicalCellMarkup("")] : [])
        ];
        return canonicalRowMarkup(cells, { className:"multiple-value-readonly-row" });
      }).join("")
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
  let mainView = "members";
  let trackBrowserPath = "";
  let selectedTagTrackPaths = new Set();
  let dirtyTrackPaths = new Set();
  let lastUnsavedChanges = false;
  let lastRenderedView = "";
  let lastDocumentPath = "";
  let expandedTagAnalyzerName = "";
  let expandedTagAnalyzerPackPath = "";
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
    if (state.documentPath !== lastDocumentPath) {
      lastDocumentPath = state.documentPath || "";
      if (mainView !== "tagAnalyzer") mainView = "members";
      trackBrowserPath = "";
      selectedTagTrackPaths = new Set();
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
    $("#member-filter-wrap").classList.toggle("hidden", !["members", "files", "newTag", "tagAnalyzer"].includes(mainView));
    $("#member-filter").placeholder = mainView === "tagAnalyzer"
      ? "Filter package filenames…"
      : "Search title, artist, album, filename, path…";
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

  function playableMembers() {
    const playable = state.members.filter(member => member.role === "playable" || member.role === "track");
    return playable.length ? playable : state.members;
  }

  function tagEligibleTracks() {
    return state?.members.filter(member => member.role === "playable" || member.role === "track") || [];
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
        subrow = canonicalRowMarkup([
          canonicalCellMarkup(subtable, { className:"inserted-table-cell" })
        ], { className:"inserted-table-row", attributes:`data-canonical-subrow="${esc(foldID)}"` });
      } else {
        valueInput = `<input data-tag-value aria-label="Tag value for ${esc(entry.key)}" value="${esc(sample)}">`;
      }
      const tagType = multipleValues ? "Multiple Values" : signatures.size === 1 ? (Array.isArray(sample) ? "list" : typeof sample) : "various";
      const readOnlyMultipleValues = multipleValues && !editableMultipleValues;
      const submitTitle = readOnlyMultipleValues ? "Multiple Values contain different values" : "Submit changed fields";
      const foldAttribute = multipleValues ? ` data-multiple-fold-id="${esc(foldID)}"` : "";
      const cells = [
        canonicalNumberCellMarkup(index + 1, `Tag number ${index + 1}`, { className:"tag-number-cell" }),
        canonicalCellMarkup(`<input class="tag-table-field" value="${esc(tagType)}" aria-label="Tag type for ${esc(entry.key)}" disabled>`, { className:"tag-type-cell" }),
        canonicalCellMarkup(`<input class="tag-table-field" data-tag-to value="${esc(entry.key)}" aria-label="Tag name for ${esc(entry.key)}">`, { className:"tag-name-cell" }),
        canonicalCellMarkup(`<span class="tag-inline-editor">${valueInput}</span>`, { className:"tag-value-cell" }),
        canonicalCellMarkup(`<input class="tag-table-field" value="${count}" aria-label="Uses for ${esc(entry.key)}" disabled>`, { className:"tag-uses-cell" }),
        canonicalCellMarkup(`<button class="icon-button" data-action="commitTagRow" title="${submitTitle}" aria-label="${submitTitle}"${readOnlyMultipleValues ? " disabled" : ""}>✓</button>`, { className:"tag-submit-cell" }),
        canonicalCellMarkup(`<button class="icon-button danger" data-action="deleteTag" title="Delete ${esc(entry.key)}" aria-label="Delete ${esc(entry.key)}">×</button>`, { className:"tag-delete-cell" })
      ];
      return canonicalRowMarkup(cells, { attributes:`data-tag-row data-tag-scope="${esc(scope)}" data-tag-from="${esc(entry.key)}"${foldAttribute}` }) + subrow;
      }).join("");
      return { rows };
    };
    const headers = ["#", "Tag Type", "Tag Name", "Tag Value", "Uses", "✓", "×"];
    const header = `${canonicalTitleRowMarkup(title)}${canonicalHeaderMarkup(headers)}`;
    const packageTagDraftRow = () => canonicalRowMarkup([
        canonicalNumberCellMarkup("＋", "Add package tag", { className:"tag-create-number" }),
        canonicalCellMarkup('<input class="tag-table-field" value="string" aria-label="Tag type" disabled>', { className:"tag-type-cell" }),
        canonicalCellMarkup('<input class="tag-table-field" data-new-tag-key placeholder="Tag Name" aria-label="New tag name" required>', { className:"tag-name-cell" }),
        canonicalCellMarkup('<input class="tag-table-field" data-new-tag-value placeholder="Tag Value" aria-label="New tag value">', { className:"tag-value-cell" }),
        canonicalCellMarkup('<input class="tag-table-field" value="—" aria-label="Uses" disabled>', { className:"tag-uses-cell" }),
        canonicalCellMarkup('<button class="icon-button" data-action="createPackageTag" title="Add package tag" aria-label="Add package tag">✓</button>', { className:"tag-submit-cell field-grid-action-cell" }),
        canonicalCellMarkup('<button class="icon-button danger" data-action="clearPackageTagDraft" title="Clear new tag" aria-label="Clear new tag">×</button>', { className:"tag-delete-cell field-grid-action-cell" })
      ], { className:"tag-create-row", attributes:'data-new-tag-row data-tag-scope="package"' });
    const table = rowsFor(scope);
    const rows = scope === "Package" ? `${table.rows}${packageTagDraftRow()}` : table.rows;
    const grid = `<section class="tag-scope-table"><div class="data-table-scroll canonical-table-surface">${canonicalTableMarkup({ className:"flat-table meta-field-grid canonical-tag-grid", ariaLabel:title, header, rows, empty:table.rows ? "" : '<div class="field-grid-empty" role="row"><span role="cell">No tags</span></div>' })}</div></section>`;
    return `<section class="data-page schema-page">${grid}${includeAttachments ? renderAttachments() : ""}</section>`;
  }

  function renderPackTagsPage() { return renderTagScopePage("Pack Tags", "Package", true); }

  function renderNewTagPage() {
    const tracks = tagEligibleTracks();
    const query = $("#member-filter")?.value.trim().toLocaleLowerCase() || "";
    const visibleTracks = tracks.filter(member => !query || [member.title, member.artist, member.album, member.name, member.path, member.role, member.format, ...Object.values(memberFields(member))].some(value => String(typeof value === "object" ? JSON.stringify(value) : (value || "")).toLocaleLowerCase().includes(query)));
    const sidebarRows = visibleTracks.map(member => {
      const number = tracks.indexOf(member) + 1;
      const checked = selectedTagTrackPaths.has(member.path) ? " checked" : "";
      const cells = [
        canonicalNumberCellMarkup(number, `Track row ${number}`),
        canonicalCellMarkup(`<input class="new-tag-track-checkbox" type="checkbox" data-new-tag-track value="${esc(member.path)}" aria-label="Select ${esc(member.name)}"${checked}>`, { className:"field-grid-action-cell new-tag-checkbox-cell" }),
        canonicalCellMarkup(`<input class="tag-table-field file-name-field" value="${esc(member.name)}" aria-label="Track filename" title="${esc(member.path)}" disabled>`)
      ];
      return canonicalRowMarkup(cells, { className:"new-tag-track-row" });
    }).join("");
    const sidebar = canonicalTableMarkup({
      className:"flat-table track-browser-sidebar-field-grid new-tag-sidebar-field-grid",
      ariaLabel:"Select tracks for a new tag",
      header:canonicalHeaderMarkup(["#", "✓", "Track"]),
      rows:sidebarRows,
      empty:'<div class="field-grid-empty" role="row"><span role="cell">No tracks match this filter</span></div>'
    });
    const draft = canonicalRowMarkup([
      canonicalNumberCellMarkup("＋", "Create tag"),
      canonicalCellMarkup('<select class="tag-table-field" data-new-tag-target aria-label="Apply to"><option value="allTracks">All Tracks</option><option value="selectedTracks">Selected Tracks</option><option value="package">Package</option></select>'),
      canonicalCellMarkup('<input class="tag-table-field" data-new-tag-key placeholder="Tag Name" aria-label="New tag name" required>'),
      canonicalCellMarkup('<input class="tag-table-field" data-new-tag-value placeholder="Tag Value" aria-label="New tag value">'),
      canonicalCellMarkup('<button class="icon-button" type="submit" data-new-tag-submit title="Apply new tag" aria-label="Apply new tag">✓</button>', { className:"field-grid-action-cell" })
    ], { className:"tag-create-row" });
    const newTagTable = canonicalTableMarkup({
      className:"flat-table new-tag-editor-field-grid",
      ariaLabel:"Create a new tag",
      header:`${canonicalTitleRowMarkup("New Tag")}${canonicalHeaderMarkup(["#", "Apply To", "Tag Name", "Tag Value", "✓"])}`,
      rows:draft
    });
    const detail = `<section class="track-browser-pane new-tag-editor-pane" aria-label="New tag fields"><form class="data-table-scroll canonical-table-surface new-tag-form" data-new-tag-form>${newTagTable}</form></section>`;
    const trackPane = `<section class="track-browser-pane track-browser-sidebar-pane new-tag-track-pane" aria-label="Track selection"><div class="data-table-scroll canonical-table-surface track-browser-scroll">${sidebar}</div></section>`;
    return `<section class="data-page track-browser-page new-tag-page">${trackPane}${detail}</section>`;
  }

  function renderTrackArrayGrid(tracks) {
    const columns = trackColumns();
    const columnTemplate = trackArrayColumnTemplate(tracks, columns);
    // The giga table has its own explicit track list. Keep it on every row so
    // WebKit cannot fall back to the generic three-column field-grid default.
    const rowTemplateStyle = `grid-template-columns:${columnTemplate} !important`;
    const headerCells = ["#", "Track #", "Filename", ...columns.map(displayTrackKey)];
    const header = canonicalHeaderMarkup(headerCells, { style:rowTemplateStyle, cell:(label, index) => {
      const sortKey = index === 0 ? "row" : index === 1 ? "track" : index === 2 ? "filename" : columns[index - 3];
      const columnAttribute = index > 2 ? ` data-track-column-key="${esc(sortKey)}"` : "";
      return { attributes:`data-sort="${esc(sortKey)}"${columnAttribute}` };
    }});
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
      const cells = [
        canonicalNumberCellMarkup(index + 1, `Track row ${index + 1}`),
        canonicalCellMarkup(scalar(trackNumber, "track", "memberMetadata", false)),
        canonicalCellMarkup(scalar(filename, "filename", "memberMetadata", false)),
        ...columns.map(key => {
          const extension = key.startsWith("extension.");
          const fieldKey = extension ? key.slice("extension.".length) : key;
          const source = extension ? member.extensions : member.metadata;
          return canonicalCellMarkup(scalar(source?.[fieldKey], fieldKey, extension ? "memberExtensions" : "memberMetadata", true), { attributes:`data-track-column-key="${esc(key)}"` });
        })
      ];
      return canonicalRowMarkup(cells, { className:"track-array-row", style:rowTemplateStyle });
    }).join("");
    const empty = `<div class="field-grid-empty" role="row"><span role="cell">No playable tracks</span></div>`;
    return canonicalTableMarkup({ className:"giga-table tracks-field-grid", ariaLabel:"Tracks", attributes:'data-field-grid="tracks"', style:`--field-grid-columns:${columnTemplate}`, header, rows, empty, trailing:popups.join("") });
  }

  function trackArrayColumnTemplate(tracks, columns) {
    const canvas = document.createElement("canvas");
    const context = canvas.getContext("2d");
    const numberColumn = getComputedStyle(document.documentElement).getPropertyValue("--canonical-number-column").trim() || "32px";
    if (!context) return `${numberColumn} 64px 220px ` + columns.map(() => "160px").join(" ");
    context.font = "10px ui-monospace, SFMono-Regular, Menlo, monospace";
    const widthFor = values => {
      const measured = values.map(value => context.measureText(String(value ?? "")).width).filter(Number.isFinite);
      return Math.max(58, Math.ceil(Math.max(...measured, 0) + 18));
    };
    const widths = [
      Number.parseFloat(numberColumn) || 32,
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
        subrow = canonicalRowMarkup([
          canonicalCellMarkup(subtable, { className:"inserted-table-cell" })
        ], { className:"inserted-table-row", attributes:`data-canonical-subrow="${esc(foldID)}"` });
      }
      const foldAttribute = structured ? ` data-multiple-fold-id="file-tag-${index}"` : "";
      const cells = [
        canonicalNumberCellMarkup(index + 1, `Tag number ${index + 1}`, { className:"tag-number-cell" }),
        canonicalCellMarkup(`<input class="tag-table-field file-tag-scope" value="${entry.scope === "memberExtensions" ? "extension" : "metadata"}" disabled>`, { className:"tag-type-cell" }),
        canonicalCellMarkup(`<input class="tag-table-field file-tag-key" data-file-tag-key value="${esc(entry.key)}" aria-label="Tag name">`, { className:"tag-name-cell" }),
        canonicalCellMarkup(`<span class="tag-inline-editor">${valueMarkup}</span>`, { className:"tag-value-cell" }),
        canonicalCellMarkup(`<button class="icon-button" data-action="commitFileTag" title="Submit changed tag" aria-label="Submit changed tag">✓</button>`, { className:"tag-submit-cell" }),
        canonicalCellMarkup(`<button class="icon-button danger" data-action="deleteFileTag" title="Delete tag" aria-label="Delete tag">×</button>`, { className:"tag-delete-cell" })
      ];
      return canonicalRowMarkup(cells, { attributes:`data-file-tag-row data-file-tag-path="${esc(member.path)}" data-file-tag-scope="${esc(entry.scope)}" data-file-tag-from="${esc(entry.key)}"${foldAttribute}` }) + subrow;
    }).join("");
    const empty = '<div class="field-grid-empty" role="row"><span role="cell">No tags on this file</span></div>';
    return canonicalTableMarkup({ className:"flat-table track-browser-field-grid canonical-tag-grid", ariaLabel:`Tags for ${member.name}`, header, rows, empty });
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
      const cells = [
        canonicalNumberCellMarkup(index + 1, `Track row ${index + 1}`, { className:"track-browser-sidebar-number" }),
        canonicalCellMarkup(`<input class="tag-table-field file-name-field" value="${esc(member.name)}" aria-label="Filename" disabled>`),
        canonicalCellMarkup(`<input class="tag-table-field track-browser-sidebar-status${dirty ? " dirty" : ""}" value="${esc(tagLabel)}" aria-label="Tag count" disabled>`)
      ];
      return canonicalRowMarkup(cells, { className:selectedClass.trim(), attributes:`tabindex="0" aria-label="Select ${esc(member.name)}" aria-selected="${member.path === trackBrowserPath}" data-action="selectTrackBrowserMember" data-track-browser-path="${esc(member.path)}" data-track-browser-row` });
    }).join("");
    const sidebarTable = canonicalTableMarkup({ className:"flat-table track-browser-sidebar-field-grid", ariaLabel:"Tagged tracks", header:sidebarHeader, rows:sidebarRows, empty:'<div class="field-grid-empty" role="row"><span role="cell">No files with tags</span></div>' });
    const sidebar = `<section class="track-browser-pane track-browser-sidebar-pane" aria-label="Tagged files"><div class="data-table-scroll canonical-table-surface track-browser-scroll">${sidebarTable}</div></section>`;
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


  function tagAnalyzerSubtableTitleMarkup(title, foldID, closeAttributes = "") {
    return multipleValuesTableTitleRowMarkup({ title, foldID, titleClose:true, closeAttributes });
  }

  function tagAnalyzerFieldRowMarkup(tagName, match, index) {
    const memberPath = match.memberRelativePath || "";
    const trackName = memberPath ? memberPath.split("/").pop() : "Package";
    const value = match.valueIsJSON ? match.valueJSON : match.value;
    const valueControl = match.valueIsJSON
      ? '<textarea class="tag-table-field tag-analyzer-match-value" data-tag-analyzer-value rows="3" aria-label="Tag value for ' + esc(tagName) + '">' + esc(value) + '</textarea>'
      : '<input class="tag-table-field tag-analyzer-match-value" data-tag-analyzer-value value="' + esc(value) + '" aria-label="Tag value for ' + esc(tagName) + '">';
    const trackControl = '<input class="tag-table-field tag-analyzer-match-track" value="' + esc(trackName) + '" title="' + esc(memberPath || "Package-level tag field") + '" aria-label="Track" disabled>';
    const nameControl = '<input class="tag-table-field" data-tag-analyzer-name value="' + esc(tagName) + '" aria-label="Tag name ' + esc(tagName) + '">';
    const rowAttributes = 'data-tag-analyzer-match data-tag-name="' + esc(tagName) + '" data-archive-relative-path="' + esc(match.archiveRelativePath) + '" data-member-relative-path="' + esc(match.memberRelativePath || "") + '" data-storage-scope="' + esc(match.storageScope) + '" data-storage-key="' + esc(match.storageKey) + '" data-expected-value-json="' + esc(match.valueJSON) + '" data-value-is-json="' + match.valueIsJSON + '"';
    const disabled = state?.isDeletingTagAnalyzerTrackFields ? " disabled" : "";
    return canonicalRowMarkup([
      canonicalNumberCellMarkup(index + 1, "Tag field number " + (index + 1), { className:"multiple-value-number-cell" }),
      canonicalCellMarkup(trackControl, { className:"tag-analyzer-match-track-cell" }),
      canonicalCellMarkup(nameControl, { className:"tag-analyzer-match-name-cell" }),
      canonicalCellMarkup(valueControl + '<small class="tag-analyzer-match-error" data-tag-analyzer-error></small>', { className:"tag-analyzer-match-value-cell" }),
      canonicalCellMarkup('<button class="icon-button" data-action="commitTagAnalyzerMatch" title="Save this tag field" aria-label="Save this tag field"' + disabled + '>✓</button>', { className:"field-grid-action-cell" }),
      canonicalCellMarkup('<button class="icon-button danger" data-action="deleteTagAnalyzerMatch" title="Delete this tag field" aria-label="Delete this tag field"' + disabled + '>×</button>', { className:"field-grid-action-cell" })
    ], { className:"multiple-value-editor-row tag-analyzer-match-row", attributes:rowAttributes });
  }

  function tagAnalyzerFieldsSubtableMarkup(tagName, matches, foldID, archiveRelativePath) {
    const header = tagAnalyzerSubtableTitleMarkup(tagName + " · " + matches.length + " tag field(s)", foldID, 'data-close-pack-path="' + esc(archiveRelativePath) + '"') +
      canonicalHeaderMarkup(["#", "Track", "Tag Name", "Tag Value", "✓", "×"]);
    const rows = matches.map((match, index) => tagAnalyzerFieldRowMarkup(tagName, match, index)).join("") ||
      '<div class="field-grid-empty multiple-values-empty" role="row"><span role="cell">No matching tag fields</span></div>';
    const table = canonicalTableMarkup({
      className:"inserted-table-grid canonical-multiple-values-grid tag-analyzer-field-grid",
      ariaLabel:"Tag values in " + archiveRelativePath,
      header,
      rows
    });
    return '<div class="inserted-table-panel">' + table + '</div>';
  }

  function groupTagAnalyzerMatchesByPack(matches) {
    const groups = new Map();
    matches.forEach(match => {
      const path = match.archiveRelativePath || "";
      if (!groups.has(path)) groups.set(path, { archiveRelativePath:path, matches:[] });
      groups.get(path).matches.push(match);
    });
    return [...groups.values()].sort((left, right) =>
      left.archiveRelativePath.localeCompare(right.archiveRelativePath, undefined, { numeric:true, sensitivity:"base" })
    );
  }

  function tagAnalyzerPackSubtableMarkup(tagName, matches, tagIndex) {
    const packs = groupTagAnalyzerMatchesByPack(matches);
    const foldID = "tag-analyzer-matches-" + tagIndex;
    const title = tagName + " · " + packs.length + " matched pack(s)";
    const header = tagAnalyzerSubtableTitleMarkup(title, foldID, 'data-close-tag-name="' + esc(tagName) + '"') +
      canonicalHeaderMarkup(["#", "Filename", "Tracks", "Tag Fields"]);
    const rows = packs.map((pack, index) => {
      const first = pack.matches[0] || {};
      const packFoldID = "tag-analyzer-pack-" + tagIndex + "-" + index;
      const isExpanded = expandedTagAnalyzerName === tagName && expandedTagAnalyzerPackPath === pack.archiveRelativePath;
      const packageName = pack.archiveRelativePath.split("/").pop() || first.archiveTitle || pack.archiveRelativePath;
      const packToggle = '<button class="canonical-fold-toggle canonical-fold-trigger tag-analyzer-pack-trigger" type="button" data-action="toggleCanonicalFold" data-fold-id="' + esc(packFoldID) + '" data-tag-analyzer-name="' + esc(tagName) + '" data-tag-analyzer-pack-path="' + esc(pack.archiveRelativePath) + '" aria-expanded="' + isExpanded + '" aria-label="Show ' + pack.matches.length + ' tag fields in ' + esc(packageName) + '"><span>' + pack.matches.length + '</span><span class="canonical-fold-icon">' + (isExpanded ? "−" : "＋") + '</span></button>';
      const packRow = canonicalRowMarkup([
        canonicalNumberCellMarkup(index + 1, "Matched pack number " + (index + 1), { className:"tag-number-cell" }),
        canonicalCellMarkup('<input class="tag-table-field" value="' + esc(packageName) + '" title="' + esc(pack.archiveRelativePath) + '" aria-label="Filename" disabled>'),
        canonicalCellMarkup('<input class="tag-table-field" value="' + (Number(first.archiveTrackCount) || 0) + '" aria-label="Track count" disabled>'),
        canonicalCellMarkup(packToggle, { className:"tag-uses-cell" })
      ]);
      const nestedRow = canonicalRowMarkup([
        canonicalCellMarkup('<div class="inserted-table-panel"></div>', { className:"inserted-table-cell" })
      ], { className:"inserted-table-row", attributes:'data-canonical-subrow="' + esc(packFoldID) + '"' });
      return packRow + nestedRow;
    }).join("") ||
      '<div class="field-grid-empty multiple-values-empty" role="row"><span role="cell">No matched packs</span></div>';
    const table = canonicalTableMarkup({
      className:"inserted-table-grid canonical-multiple-values-grid tag-analyzer-pack-grid",
      ariaLabel:"Matched packs for " + tagName,
      header,
      rows
    });
    return '<div class="inserted-table-panel">' + table + '</div>';
  }

  function setCanonicalFoldOpen(toggle, open) {
    if (!toggle) return;
    const fold = toggle.closest(".canonical-fold");
    const panel = fold?.querySelector(".canonical-fold-panel");
    const subrow = toggle.dataset.foldId
      ? document.querySelector('[data-canonical-subrow="' + CSS.escape(toggle.dataset.foldId) + '"]')
      : null;
    const target = panel || subrow;
    if (!target) return;
    target.classList.toggle("open", open);
    toggle.setAttribute("aria-expanded", String(open));
    const icon = $(".canonical-fold-icon", toggle);
    if (icon) icon.textContent = open ? "−" : "＋";
  }

  function closeExpandedTagAnalyzerPack() {
    if (!expandedTagAnalyzerPackPath) return;
    const archiveRelativePath = expandedTagAnalyzerPackPath;
    const toggle = [...document.querySelectorAll(".tag-analyzer-pack-grid [data-action='toggleCanonicalFold']")]
      .find(candidate => candidate.dataset.tagAnalyzerPackPath === archiveRelativePath);
    setCanonicalFoldOpen(toggle, false);
    expandedTagAnalyzerPackPath = "";
    const subrow = toggle?.dataset.foldId
      ? document.querySelector('[data-canonical-subrow="' + CSS.escape(toggle.dataset.foldId) + '"]')
      : null;
    window.setTimeout(() => {
      if (!subrow || expandedTagAnalyzerPackPath === archiveRelativePath || subrow.classList.contains("open")) return;
      const cell = $(".inserted-table-cell", subrow);
      if (cell) cell.innerHTML = '<div class="inserted-table-panel"></div>';
    }, uiMotionDuration + 25);
  }

  function populateTagAnalyzerPack(toggle) {
    const foldID = toggle?.dataset.foldId || "";
    const subrow = foldID
      ? document.querySelector('[data-canonical-subrow="' + CSS.escape(foldID) + '"]')
      : null;
    const cell = subrow && $(".inserted-table-cell", subrow);
    if (!cell || $(".tag-analyzer-field-grid", cell)) return Boolean(cell);
    const tagName = toggle.dataset.tagAnalyzerName || "";
    const archiveRelativePath = toggle.dataset.tagAnalyzerPackPath || "";
    const matches = (state?.tagAnalyzerSelectedMatches || []).filter(match => match.archiveRelativePath === archiveRelativePath);
    cell.innerHTML = tagAnalyzerFieldsSubtableMarkup(tagName, matches, foldID, archiveRelativePath);
    return true;
  }

  function restoreTagAnalyzerFolds() {
    const tagName = expandedTagAnalyzerName;
    if (!tagName || state?.tagAnalyzerSelectedMatchesTagName !== tagName) return;
    requestAnimationFrame(() => requestAnimationFrame(() => {
      if (expandedTagAnalyzerName !== tagName || state?.tagAnalyzerSelectedMatchesTagName !== tagName) return;
      const outerToggle = [...document.querySelectorAll('[data-action="toggleTagAnalyzerPacks"]')]
        .find(toggle => toggle.dataset.tagName === tagName);
      setCanonicalFoldOpen(outerToggle, true);
      if (!expandedTagAnalyzerPackPath) return;
      const packToggle = [...document.querySelectorAll(".tag-analyzer-pack-grid [data-action='toggleCanonicalFold']")]
        .find(toggle => toggle.dataset.tagAnalyzerPackPath === expandedTagAnalyzerPackPath);
      if (!populateTagAnalyzerPack(packToggle)) return;
      requestAnimationFrame(() => requestAnimationFrame(() => {
        if (expandedTagAnalyzerName === tagName && packToggle?.dataset.tagAnalyzerPackPath === expandedTagAnalyzerPackPath) {
          setCanonicalFoldOpen(packToggle, true);
        }
      }));
    }));
  }

  function tagAnalyzerFilenameMatches(relativePath, query) {
    if (!query) return true;
    const filename = String(relativePath || "").split("/").pop() || "";
    return filename.toLocaleLowerCase().includes(query);
  }

  function renderTagAnalyzerPage() {
    const tags = state.tagAnalyzerTags || [];
    const query = $("#member-filter")?.value.trim().toLocaleLowerCase() || "";
    const deleting = Boolean(state.isDeletingTagAnalyzerTrackFields);
    const busy = Boolean(state.isAnalyzingTagNames) || deleting;
    const visibleTags = tags.map(tag => {
      const archives = (tag.archiveMatches || []).filter(archive => tagAnalyzerFilenameMatches(archive.relativePath, query));
      return {
        tag,
        matchedPackCount:query ? archives.length : Number(tag.matchedPackCount) || 0,
        trackCount:query
          ? archives.reduce((total, archive) => total + (Number(archive.trackCount) || 0), 0)
          : Number(tag.trackCount) || 0,
        trackArchives:archives.filter(archive => Number(archive.trackCount) > 0)
      };
    }).filter(item => !query || item.matchedPackCount > 0);
    const issues = state.tagAnalyzerIssues || [];
    const progress = state.tagAnalyzerProgress || {};
    const running = Boolean(state.isAnalyzingTagNames);
    const phase = progress.phase || "discovering";
    const total = Number(progress.totalPackages) || 0;
    const processed = Number(progress.packagesProcessed) || 0;
    const deletionProgress = state.tagAnalyzerDeletionProgress || {};
    const deletionTotal = Number(deletionProgress.totalPackages) || 0;
    const deletionCompleted = Number(deletionProgress.packagesCompleted) || 0;
    const progressControl = deleting && deletionTotal > 0
      ? '<progress class="tag-analyzer-progress-meter" max="' + deletionTotal + '" value="' + Math.min(deletionCompleted, deletionTotal) + '" aria-label="Packages updated"></progress>'
      : running && phase === "reading" && total > 0
      ? '<progress class="tag-analyzer-progress-meter" max="' + total + '" value="' + Math.min(processed, total) + '" aria-label="Packages read"></progress>'
      : running
        ? '<progress class="tag-analyzer-progress-meter" aria-label="Finding UAC packages"></progress>'
        : "";
    const currentPath = deleting
      ? deletionProgress.currentRelativePath || ""
      : progress.currentRelativePath || "";
    const status = state.isCancellingTagAnalysis
      ? "Cancelling after the current manifest read…"
      : deleting
        ? state.tagAnalyzerStatusMessage || "Deleting matching track fields…"
      : state.tagAnalyzerStatusMessage || "Browse for a folder to inventory its UAC tag names.";
    const selectedMatchesTagName = state.tagAnalyzerSelectedMatchesTagName || "";
    const selectedMatches = (state.tagAnalyzerSelectedMatches || []).filter(match =>
      tagAnalyzerFilenameMatches(match.archiveRelativePath, query)
    );
    const rows = visibleTags.map(({ tag, matchedPackCount, trackCount, trackArchives }, index) => {
      const hasSelectedMatches = selectedMatchesTagName === tag.name;
      const tagIsExpanded = expandedTagAnalyzerName === tag.name && hasSelectedMatches;
      const foldID = "tag-analyzer-matches-" + index;
      const matches = hasSelectedMatches ? selectedMatches : [];
      const toggle = '<button class="canonical-fold-toggle canonical-fold-trigger tag-analyzer-match-trigger" type="button" data-action="toggleTagAnalyzerPacks" data-tag-name="' + esc(tag.name) + '" data-fold-id="' + esc(foldID) + '" aria-expanded="' + tagIsExpanded + '" aria-label="Show ' + matchedPackCount + ' matched packs for ' + esc(tag.name) + '"><span>' + matchedPackCount + '</span><span class="canonical-fold-icon">' + (tagIsExpanded ? "−" : "＋") + '</span></button>';
      const cells = [
        canonicalNumberCellMarkup(index + 1, "Tag number " + (index + 1), { className:"tag-number-cell" }),
        canonicalCellMarkup('<input class="tag-table-field" value="' + esc(tag.name) + '" title="' + esc(tag.name) + '" aria-label="Tag name ' + esc(tag.name) + '" disabled>', { className:"tag-name-cell" }),
        canonicalCellMarkup(toggle, { className:"tag-uses-cell" }),
        canonicalCellMarkup('<input class="tag-table-field" value="' + trackCount + '" aria-label="Tracks with ' + esc(tag.name) + '" disabled>', { className:"tag-uses-cell" }),
        canonicalCellMarkup('<button class="icon-button danger tag-analyzer-delete-button" data-action="deleteTagAnalyzerTrackFields" data-tag-name="' + esc(tag.name) + '" data-track-field-count="' + trackCount + '" data-package-count="' + trackArchives.length + '" data-archive-paths="' + esc(JSON.stringify(trackArchives.map(archive => archive.relativePath))) + '" title="Delete ' + trackCount + ' track field(s) from ' + trackArchives.length + ' matching package(s)" aria-label="Delete ' + trackCount + ' track field(s) named ' + esc(tag.name) + ' from ' + trackArchives.length + ' matching package(s)"' + (trackCount < 1 || busy ? " disabled" : "") + '>×</button>', { className:"field-grid-action-cell tag-analyzer-delete-cell" })
      ];
      const parentRow = canonicalRowMarkup(cells);
      if (!hasSelectedMatches) return parentRow;
      const subtable = tagAnalyzerPackSubtableMarkup(tag.name, matches, index);
      const subrow = canonicalRowMarkup([
        canonicalCellMarkup(subtable, { className:"inserted-table-cell" })
      ], { className:"inserted-table-row", attributes:'data-canonical-subrow="' + esc(foldID) + '"' });
      return parentRow + subrow;
    }).join("");
    const emptyMessage = state.tagAnalyzerHasResult
      ? query
        ? 'No tag fields match package filenames containing "' + esc(query) + '".'
        : "No tag fields were found in the readable UAC manifests."
      : "Browse for a folder to list its UAC tag names.";
    const issuesDisclosure = issues.length
      ? '<details class="tag-analyzer-issues"><summary>' + issues.length + ' unreadable folder or package item(s) · results may be incomplete</summary><div class="tag-analyzer-issue-list">' + issues.map(issue => '<div class="issue"><strong>' + esc(issue.relativePath || "Selected folder") + '</strong>' + esc(issue.message) + '</div>').join("") + '</div></details>'
      : "";
    const table = canonicalTableMarkup({
      className:"flat-table meta-field-grid tag-analyzer-table",
      ariaLabel:"Tag names, matched packs, and tracks",
      header:canonicalTitleRowMarkup("Tag Names" + (state.tagAnalyzerHasResult ? " · " + visibleTags.length : "")) + canonicalHeaderMarkup(["#", "Tag Name", "Matched Packs", "Tracks", "×"], {
        cell:label => label === "×" ? { className:"tag-analyzer-delete-header", attributes:'title="Delete matching track fields"' } : {}
      }),
      rows,
      empty:'<div class="field-grid-empty tag-analyzer-empty" role="row"><span role="cell">' + esc(emptyMessage) + '</span></div>'
    });

    return '<section class="data-page tag-analyzer-page" aria-label="Tag Analyzer">' +
      '<div class="data-page-heading"><div><div class="tag-analyzer-heading-line"><h2>Tag Analyzer</h2><span class="beta-badge">Beta</span></div><p>List exact tag field names in a folder. Matched-pack counts identify packages with that field; values may differ. Expand a pack to inspect its field entries.</p></div><span class="data-page-count">' + (state.tagAnalyzerHasResult ? (query ? visibleTags.length + ' / ' + tags.length + ' matching name(s)' : tags.length + ' unique name(s)') : "Manifest fields") + '</span></div>' +
      '<div class="tag-analyzer-controls">' +
        '<label class="tag-analyzer-path-control">Folder Path<input class="tag-table-field" value="' + esc(state.tagAnalyzerRootPath || "") + '" placeholder="Choose a folder path" aria-label="Tag analysis folder path" readonly></label>' +
        '<button class="button primary" data-action="chooseTagAnalyzerFolder"' + (busy ? " disabled" : "") + '>Browse</button>' +
        '<button class="button secondary tag-analyzer-cancel" data-action="cancelTagAnalysis"' + (!running || state.isCancellingTagAnalysis ? " disabled" : "") + '>Cancel</button>' +
      '</div>' +
      '<div class="tag-analyzer-progress" role="status" aria-live="polite">' + progressControl + '<span>' + esc(status) + '</span>' + ((running || deleting) && currentPath ? '<code title="' + esc(currentPath) + '">' + esc(currentPath) + '</code>' : "") + '</div>' +
      issuesDisclosure +
      '<div class="tag-analyzer-results"><div class="data-table-scroll canonical-table-surface">' + table + '</div></div>' +
    '</section>';
  }

  function renderFilesPage() {
    const members = visibleFileMembers();
    const header = canonicalHeaderMarkup(["#", "Role", "Format", "Filename", "Stored path", "Tags Count", "Size", "⌕"]);
    const rows = members.map((member, index) => canonicalRowMarkup([
      canonicalNumberCellMarkup(index + 1, `File number ${index + 1}`, { className:"file-number" }),
      canonicalCellMarkup(`<input class="tag-table-field" value="${esc(member.role)}" disabled>`),
      canonicalCellMarkup(`<input class="tag-table-field" value="${esc(member.format || "unknown")}" disabled>`),
      canonicalCellMarkup(`<input class="tag-table-field file-name-field" data-file-name data-file-path="${esc(member.path)}" value="${esc(member.name)}" aria-label="Filename">`),
      canonicalCellMarkup(`<input class="tag-table-field file-path-field" value="${esc(member.path)}" disabled>`),
      canonicalCellMarkup(`<input class="tag-table-field file-tags-count" value="${fileTagEntries(member).length}" aria-label="Tag count" disabled>`),
      canonicalCellMarkup(`<input class="tag-table-field" value="${esc(bytes(member.bytes))}" disabled>`),
      canonicalCellMarkup(member.previewable ? `<button class="icon-button file-preview-action" data-action="previewMember" data-preview-path="${esc(member.path)}" title="View bundled text" aria-label="View bundled text">⌕</button>` : "", { className:"field-grid-action-cell file-view-cell" })
    ], { className:"file-row", attributes:`tabindex="0" data-track-row="${esc(member.path)}" title="Open metadata for ${esc(member.name)}"` })).join("");
    const empty = `<div class="field-grid-empty" role="row"><span role="cell">No package members match this filter</span></div>`;
    const preview = state.filePreviewPath
      ? `<div class="file-preview-backdrop" role="presentation"><section class="file-preview" role="dialog" aria-modal="true" aria-label="Bundled file preview"><div class="file-preview-heading"><div><strong>${esc(state.filePreviewName || "Bundled file")}</strong><span>${esc(state.filePreviewPath)}</span></div><button class="icon-button" data-action="closeFilePreview" title="Close preview" aria-label="Close preview">×</button></div>${state.filePreviewError ? `<div class="file-preview-error">${esc(state.filePreviewError)}</div>` : `<pre class="file-preview-content">${esc(state.filePreviewContent)}</pre>${state.filePreviewTruncated ? '<div class="file-preview-note">Preview limited to the first 4 MiB. The bundled file remains unchanged.</div>' : ""}`}</section></div>`
      : "";
    const table = canonicalTableMarkup({ className:"giga-table file-field-grid", ariaLabel:"Package files", header, rows, empty });
    return `<section class="data-page files-page"><div class="data-table-scroll canonical-table-surface giga-table-surface file-table-surface">${table}</div>${preview}</section>`;
  }

  function renderAttachments() {
    const assets = state.members.filter(member => member.role !== "playable" && member.role !== "track");
    if (!assets.length) return "";
    const header = `${canonicalTitleRowMarkup("Attachments")}${canonicalHeaderMarkup(["#", "Role", "Format", "Filename", "Stored path", "Size", "⌕"])}`;
    const rows = assets.map((asset, index) => canonicalRowMarkup([
      canonicalNumberCellMarkup(index + 1, `Attachment number ${index + 1}`, { className:"file-number" }),
      canonicalCellMarkup(`<input class="tag-table-field" value="${esc(asset.role)}" disabled>`),
      canonicalCellMarkup(`<input class="tag-table-field" value="${esc(asset.format || "unknown")}" disabled>`),
      canonicalCellMarkup(`<input class="tag-table-field file-name-field" value="${esc(asset.name)}" disabled>`),
      canonicalCellMarkup(`<input class="tag-table-field file-path-field" value="${esc(asset.path)}" disabled>`),
      canonicalCellMarkup(`<input class="tag-table-field" value="${esc(bytes(asset.bytes))}" disabled>`),
      canonicalCellMarkup(asset.previewable ? `<button class="icon-button file-preview-action" data-action="previewMember" data-preview-path="${esc(asset.path)}" title="View bundled text" aria-label="View bundled text">⌕</button>` : "", { className:"field-grid-action-cell file-view-cell" })
    ], { className:"attachment-row", attributes:`tabindex="0" data-track-row="${esc(asset.path)}" title="Open metadata for ${esc(asset.name)}"` })).join("");
    const table = canonicalTableMarkup({ className:"flat-table attachment-field-grid", ariaLabel:"Package attachments", header, rows });
    return `<section class="attachments-section"><div class="data-table-scroll canonical-table-surface attachment-table-scroll">${table}</div></section>`;
  }

  function renderInspector() {
    const hasPackage = Boolean(state.documentName);
    const inspector = $("#inspector-content");
    inspector.className = `inspector-content${["trackBrowser", "newTag"].includes(mainView) ? " track-browser-inspector" : ""}`;
    if (mainView === "tagAnalyzer") {
      inspector.innerHTML = renderTagAnalyzerPage();
      restoreTagAnalyzerFolds();
      return;
    }
    if (!hasPackage) {
      inspector.innerHTML = `<div class="metadata-empty"><div class="empty-icon">⌁</div><h3>Open a package to edit metadata</h3><p>Choose a collection entry or open a UAC file.</p></div>`;
      return;
    }
    let html = "";
    if (mainView === "files") html += renderFilesPage();
    else if (mainView === "packTags") html += renderPackTagsPage();
    else if (mainView === "trackBrowser") html += renderTrackPage();
    else if (mainView === "newTag") html += renderNewTagPage();
    inspector.innerHTML = html;
    if (mainView === "newTag") updateNewTagSubmitState();
  }

  function scopeToAction(scope) {
    return ({ gameMetadata:"setGameMetadata", gameExtensions:"setGameExtensions", memberMetadata:"setMemberMetadata", memberExtensions:"setMemberExtensions" })[scope];
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
    $$('[data-action="toggleMultipleValuesPopup"][data-popup-id="' + CSS.escape(popupID) + '"]').forEach(toggle => {
      toggle.setAttribute("aria-expanded", "false");
      $(".canonical-fold-icon", toggle).textContent = "＋";
    });
  }

  function closeCanonicalSubtable(button) {
    if (!button) return;
    const foldID = button.dataset.foldId || "";
    const subrow = foldID
      ? document.querySelector('[data-canonical-subrow="' + CSS.escape(foldID) + '"]')
      : button.closest("[data-canonical-subrow]");
    const toggle = foldID
      ? [...document.querySelectorAll("[data-fold-id]")].find(candidate => candidate.dataset.foldId === foldID)
      : null;
    setCanonicalFoldOpen(toggle, false);
    const tagName = button.dataset.closeTagName || "";
    const packPath = button.dataset.closePackPath || "";
    if (tagName && expandedTagAnalyzerName === tagName) {
      closeExpandedTagAnalyzerPack();
      expandedTagAnalyzerName = "";
    }
    if (packPath && expandedTagAnalyzerPackPath === packPath) expandedTagAnalyzerPackPath = "";
    subrow?.classList.remove("open");
    toggle?.focus({ preventScroll:true });
  }

  function updateNewTagSubmitState(form = $("[data-new-tag-form]")) {
    if (!form) return;
    const target = $("[data-new-tag-target]", form)?.value;
    const hasTargets = target === "package" || (target === "selectedTracks" ? selectedTagTrackPaths.size > 0 : tagEligibleTracks().length > 0);
    const submit = $("[data-new-tag-submit]", form);
    if (submit) submit.disabled = !hasTargets;
  }

  function submitNewTag(form) {
    if (!form) return;
    const keyField = $("[data-new-tag-key]", form);
    const key = titleCaseTagName(keyField?.value || "");
    if (!key) { keyField?.focus(); return; }
    const value = $("[data-new-tag-value]", form)?.value || "";
    const target = $("[data-new-tag-target]", form)?.value || "allTracks";
    if (target === "package") {
      bridge("addMetadataKey", { key, scope:"package", value });
      return;
    }
    const paths = target === "selectedTracks"
      ? [...selectedTagTrackPaths]
      : tagEligibleTracks().map(member => member.path);
    if (!paths.length) return;
    paths.forEach(markTrackDirty);
    bridge("addMemberTags", { paths, key, value });
  }

  function createPackageTagFromDraft(row) {
    const keyField = $("[data-new-tag-key]", row);
    const key = titleCaseTagName(keyField?.value || "");
    if (!key) { keyField?.focus(); return; }
    bridge("addMetadataKey", { key, scope:"package", value:$('[data-new-tag-value]', row)?.value || "" });
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
    const popup = document.querySelector('[data-multiple-values-popup="' + CSS.escape(popupID) + '"]');
    if (!popup) return;
    const opening = popup.hidden;
    $$("[data-multiple-values-popup]").forEach(closeMultipleValuesPopup);
    if (!opening) return;
    popup.hidden = false;
    toggle?.setAttribute("aria-expanded", "true");
    $(".canonical-fold-icon", toggle).textContent = "−";
    $(".multiple-values-popup-close", popup)?.focus({ preventScroll:true });
  }

  function toggleTagAnalyzerPacks(tagName, toggle) {
    if (!tagName) return;
    if (expandedTagAnalyzerName === tagName) {
      closeExpandedTagAnalyzerPack();
      expandedTagAnalyzerName = "";
      setCanonicalFoldOpen(toggle, false);
      return;
    }
    const previousToggle = [...document.querySelectorAll('[data-action="toggleTagAnalyzerPacks"]')]
      .find(candidate => candidate.dataset.tagName === expandedTagAnalyzerName);
    closeExpandedTagAnalyzerPack();
    setCanonicalFoldOpen(previousToggle, false);
    expandedTagAnalyzerName = tagName;
    expandedTagAnalyzerPackPath = "";
    if (state?.tagAnalyzerSelectedMatchesTagName === tagName) setCanonicalFoldOpen(toggle, true);
    else bridge("loadTagAnalyzerMatches", { tagName });
  }

  function toggleTagAnalyzerPack(tagName, packPath, toggle) {
    if (!tagName || !packPath || tagName !== expandedTagAnalyzerName) return;
    const opening = expandedTagAnalyzerPackPath !== packPath;
    if (!opening) {
      closeExpandedTagAnalyzerPack();
      return;
    }
    if (expandedTagAnalyzerPackPath) closeExpandedTagAnalyzerPack();
    expandedTagAnalyzerPackPath = packPath;
    const subrow = document.querySelector('[data-canonical-subrow="' + CSS.escape(toggle.dataset.foldId || "") + '"]');
    const hasTable = subrow && $(".tag-analyzer-field-grid", subrow);
    if (!populateTagAnalyzerPack(toggle)) return;
    if (hasTable) {
      setCanonicalFoldOpen(toggle, true);
      return;
    }
    requestAnimationFrame(() => requestAnimationFrame(() => {
      if (expandedTagAnalyzerName === tagName && expandedTagAnalyzerPackPath === packPath) setCanonicalFoldOpen(toggle, true);
    }));
  }

  function tagAnalyzerMatchPayload(row) {
    return {
      tagName:row?.dataset.tagName || "",
      archiveRelativePath:row?.dataset.archiveRelativePath || "",
      memberRelativePath:row?.dataset.memberRelativePath || "",
      storageScope:row?.dataset.storageScope || "",
      storageKey:row?.dataset.storageKey || "",
      expectedValueJSON:row?.dataset.expectedValueJson || ""
    };
  }

  function commitTagAnalyzerMatch(row) {
    if (!row || state?.isDeletingTagAnalyzerTrackFields) return;
    const nameField = $("[data-tag-analyzer-name]", row);
    const valueField = $("[data-tag-analyzer-value]", row);
    const name = nameField?.value.trim() || "";
    const value = valueField?.value ?? "";
    const error = $("[data-tag-analyzer-error]", row);
    const valueIsJSON = row.dataset.valueIsJson === "true";
    if (!name) {
      if (error) error.textContent = "Tag name cannot be empty.";
      nameField?.focus();
      return;
    }
    if (valueIsJSON) {
      try { JSON.parse(value); }
      catch {
        if (error) error.textContent = "Enter a valid JSON value.";
        valueField?.focus();
        return;
      }
    }
    if (error) error.textContent = "";
    if (expandedTagAnalyzerName === row.dataset.tagName) expandedTagAnalyzerName = name;
    bridge("commitTagAnalyzerMatch", {
      ...tagAnalyzerMatchPayload(row),
      newName:name,
      value,
      valueIsJSON
    });
  }

  function deleteTagAnalyzerMatch(row) {
    if (!row || state?.isDeletingTagAnalyzerTrackFields) return;
    const source = [row.dataset.archiveRelativePath, row.dataset.memberRelativePath].filter(Boolean).join(" · ");
    const name = row.dataset.tagName || "this tag";
    if (!window.confirm('Delete only "' + name + '" from ' + source + '?')) return;
    bridge("deleteTagAnalyzerMatch", tagAnalyzerMatchPayload(row));
  }

  function deleteTagAnalyzerTrackFields(button) {
    if (!button || state?.isDeletingTagAnalyzerTrackFields) return;
    const tagName = button.dataset.tagName || "";
    const trackFieldCount = Number(button.dataset.trackFieldCount) || 0;
    const packageCount = Number(button.dataset.packageCount) || 0;
    let archiveRelativePaths = [];
    try {
      archiveRelativePaths = JSON.parse(button.dataset.archivePaths || "[]");
    } catch { return; }
    if (!tagName || trackFieldCount < 1 || !packageCount || !Array.isArray(archiveRelativePaths)) return;
    const scope = packageCount === 1 ? "1 package" : packageCount + " packages";
    const message = 'Delete all ' + trackFieldCount + ' "' + tagName + '" track fields from ' + scope + ' matched by the current filename filter? This edits their UAC manifests.';
    if (!window.confirm(message)) return;
    bridge("deleteTagAnalyzerTrackFields", { tagName, archiveRelativePaths });
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
    if (action === "deleteTag") {
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
    else if (action === "removeMultipleValue") removeMultipleValue(event.target.closest("[data-multiple-entry]"));
    else if (action === "commitMultipleValueRow") commitMultipleValueRow(event.target.closest("[data-multiple-entry]"));
    else if (action === "commitMultipleValues") {
      const popup = event.target.closest("[data-multiple-values-popup]");
      if (popup) commitMultipleValuesPopup(popup);
      else commitMultipleValues(event.target.closest("[data-multiple-editor]"));
    }
    else if (action === "toggleMultipleValuesPopup") toggleMultipleValuesPopup(event.target.closest("[data-action=toggleMultipleValuesPopup]")?.dataset.popupId || "", event.target.closest("[data-action=toggleMultipleValuesPopup]"));
    else if (action === "toggleTagAnalyzerPacks") {
      const toggle = event.target.closest("[data-action=toggleTagAnalyzerPacks]");
      toggleTagAnalyzerPacks(toggle?.dataset.tagName || "", toggle);
    }
    else if (action === "commitTagAnalyzerMatch") commitTagAnalyzerMatch(event.target.closest("[data-tag-analyzer-match]"));
    else if (action === "deleteTagAnalyzerMatch") deleteTagAnalyzerMatch(event.target.closest("[data-tag-analyzer-match]"));
    else if (action === "deleteTagAnalyzerTrackFields") deleteTagAnalyzerTrackFields(event.target.closest("[data-action=deleteTagAnalyzerTrackFields]"));
    else if (action === "closeMultipleValuesPopup") closeMultipleValuesPopup(event.target.closest("[data-multiple-values-popup]"));
    else if (action === "closeCanonicalSubtable") closeCanonicalSubtable(event.target.closest("[data-action=closeCanonicalSubtable]"));
    else if (action === "toggleCanonicalFold") {
      const toggle = event.target.closest("[data-action=toggleCanonicalFold]");
      const packPath = toggle?.dataset.tagAnalyzerPackPath || "";
      if (toggle && packPath) {
        toggleTagAnalyzerPack(toggle.dataset.tagAnalyzerName || "", packPath, toggle);
        return;
      }
      const foldID = toggle?.dataset.foldId || "";
      const subrow = foldID ? document.querySelector('[data-canonical-subrow="' + CSS.escape(foldID) + '"]') : null;
      if (toggle && subrow) setCanonicalFoldOpen(toggle, !subrow.classList.contains("open"));
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
    else if (action === "createPackageTag") createPackageTagFromDraft(event.target.closest("[data-new-tag-row]"));
    else if (action === "clearPackageTagDraft") {
      const row = event.target.closest("[data-new-tag-row]");
      if (row) { $("[data-new-tag-key]", row).value = ""; $("[data-new-tag-value]", row).value = ""; }
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
    else if (action === "dismissError") bridge("dismissError");
    else if (action === "mainView") {
      mainView = event.target.closest("[data-view]").dataset.view;
      if (mainView !== "tagAnalyzer") { expandedTagAnalyzerName = ""; expandedTagAnalyzerPackPath = ""; }
      render(state);
    }
    else if (action === "closeInspector") { mainView = "members"; render(state); }
    else if (action === "rescanCollection") bridge("rescanCollection");
    else if (action === "cancelCollectionScan") bridge("cancelCollectionScan");
    else if (action === "cancelHarvest") bridge("cancelHarvest");
    else if (["chooseTagAnalyzerFolder", "cancelTagAnalysis"].includes(action)) {
      if (action !== "cancelTagAnalysis") { expandedTagAnalyzerName = ""; expandedTagAnalyzerPackPath = ""; }
      bridge(action);
    }
    else if (action === "openUAC" || action === "openCollection" || action === "save" || action === "revert" || action === "harvest") bridge(action);
  });

  document.addEventListener("submit", event => {
    const form = event.target.closest("[data-new-tag-form]");
    if (form) {
      event.preventDefault();
      submitNewTag(form);
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
    if (target.matches("[data-new-tag-track]")) {
      if (target.checked) selectedTagTrackPaths.add(target.value); else selectedTagTrackPaths.delete(target.value);
      updateNewTagSubmitState(target.closest(".new-tag-page")?.querySelector("[data-new-tag-form]"));
    }
    else if (target.matches("[data-new-tag-target]")) updateNewTagSubmitState(target.closest("[data-new-tag-form]"));
    else if (target.matches("[data-track-cell]")) commitTrackCell(target);
    else if (target.matches("[data-file-name]")) bridge("renameMember", { path:target.dataset.filePath || "", name:target.value });
  });

  document.addEventListener("input", event => {
    if (event.target.id === "collection-filter") renderCollections();
    else if (event.target.id === "member-filter") ["files", "newTag", "tagAnalyzer"].includes(mainView) ? render(state) : renderMembers();
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
