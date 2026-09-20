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
  const displayTrackKey = key => String(key).startsWith("extension.") ? `Extension: ${displayMetadataKey(String(key).slice("extension.".length))}` : displayMetadataKey(key);
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
  const multipleValuesEditorBodyMarkup = (value, context = {}) => {
    const isArray = Array.isArray(value);
    const entries = isArray ? value.map((item, index) => [String(index), item]) : Object.entries(value || {});
    const rowMarkup = ([key, item]) => {
      const kind = fieldKind(item);
      const raw = kind === "json" ? JSON.stringify(item, null, 2) : String(item ?? "");
      const valueControl = kind === "json"
        ? `<textarea class="multiple-value-editor" data-multiple-value aria-label="Value for ${esc(key)}">${esc(raw)}</textarea>`
        : `<input class="multiple-value-editor" data-multiple-value value="${esc(raw)}" aria-label="Value for ${esc(key)}">`;
      return `<div class="tag-multiple-value-row multiple-value-editor-row" data-multiple-entry data-multiple-kind="${kind}"><input class="multiple-value-key" data-multiple-key value="${esc(key)}" aria-label="Key for ${esc(key)}"${isArray ? " disabled" : ""}>${valueControl}<button class="icon-button danger multiple-value-remove" data-action="removeMultipleValue" type="button" title="Remove value" aria-label="Remove value">×</button></div>`;
    };
    const rows = entries.map(rowMarkup).join("");
    const data = [
      `data-multiple-editor`,
      `data-multiple-target="${esc(context.target || "member")}"`,
      `data-multiple-array="${isArray}"`,
      `data-multiple-path="${esc(context.path || "")}"`,
      `data-multiple-scope="${esc(context.scope || "")}"`,
      `data-multiple-key="${esc(context.key || "")}"`
    ].join(" ");
    const body = `<div class="multiple-values-editor" ${data}><div class="multiple-values-rows">${rows || '<div class="file-tag-empty multiple-values-empty">No values</div>'}</div><div class="multiple-values-editor-actions"><button class="icon-button" data-action="addMultipleValue" type="button" title="Add value" aria-label="Add value">＋</button><button class="icon-button" data-action="commitMultipleValues" type="button" title="Submit changed values" aria-label="Submit changed values">✓</button></div><div class="multiple-values-editor-error" role="status"></div></div>`;
    return { body, count:entries.length };
  };
  const multipleValuesEditorMarkup = (value, context = {}) => {
    const editor = multipleValuesEditorBodyMarkup(value, context);
    return canonicalFoldMarkup("Multiple Values", editor.body, { className:"tag-multiple-values editable-multiple-values", meta:context.showCount === false ? "" : editor.count });
  };
  const multipleValuesTriggerMarkup = foldID => `<button class="canonical-fold-toggle canonical-fold-trigger" type="button" data-action="toggleCanonicalFold" data-fold-id="${esc(foldID)}" aria-expanded="false"><span>Multiple Values</span><span class="canonical-fold-icon">＋</span></button>`;
  const multipleValuesSubtableMarkup = (value, context = {}) => {
    const editor = multipleValuesEditorBodyMarkup(value, context);
    return `<div class="canonical-subtable-panel">${editor.body}</div>`;
  };
  const multipleValuesPopupParts = (value, context = {}, options = {}) => {
    const popupID = context.popupID || "multiple-values";
    const isEditor = options.editable === true;
    const entries = options.entries || (Array.isArray(value) ? value.map((item, index) => [String(index + 1), item]) : Object.entries(value || {}));
    const editor = isEditor ? multipleValuesEditorBodyMarkup(value, context) : null;
    const body = editor
      ? `<div class="editable-multiple-values">${editor.body}</div>`
      : `<div class="multiple-values-popup-table" role="table">${entries.length ? entries.map(([key, item]) => `<div class="tag-multiple-value-row" role="row"><span role="cell">${esc(key)}</span><span role="cell">${esc(typeof item === "object" ? JSON.stringify(item) : String(item ?? "—"))}</span></div>`).join("") : '<div class="tag-multiple-value-row" role="row"><span role="cell">—</span><span role="cell">Empty</span></div>'}</div>`;
    const trigger = `<button class="canonical-fold-toggle canonical-fold-trigger multiple-values-popup-trigger" type="button" data-action="toggleMultipleValuesPopup" data-popup-id="${esc(popupID)}" aria-controls="multiple-values-popup-${esc(popupID)}" aria-expanded="false"><span>Multiple Values</span><span class="canonical-fold-icon">＋</span></button>`;
    const popup = `<div class="multiple-values-popup-backdrop" id="multiple-values-popup-${esc(popupID)}" data-multiple-values-popup="${esc(popupID)}" hidden><div class="multiple-values-popup-card" role="dialog" aria-modal="true" aria-label="Multiple Values"><div class="multiple-values-popup-heading"><strong>Multiple Values</strong><button class="icon-button multiple-values-popup-close" data-action="closeMultipleValuesPopup" data-popup-id="${esc(popupID)}" type="button" title="Close" aria-label="Close">×</button></div><div class="multiple-values-popup-content">${body}</div></div></div>`;
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
  let lastRenderedView = "";
  let lastDocumentName = "";
  const uiMotionDuration = 200;

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
    }
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
    const members = visibleMembers();
    const open = Boolean(state.documentName);
    const noRows = members.length === 0;
    $("#table-scroll").innerHTML = open
      ? (noRows ? `<div class="empty-state"><div class="empty-icon">▤</div><h3>${state.members.length ? "No tracks match this filter" : "This package has no audio tracks"}</h3><p>${state.members.length ? "Change the search text to show audio tracks." : "The package contains no playable members."}</p></div>` : renderTrackArrayGrid(members))
      : `<div class="empty-state"><div class="empty-icon">▤</div><h3>Open a package to get started</h3><p>Browse a collection or open a UAC package. Audio streams appear here as rows with their tags as columns.</p><button class="button primary" data-action="openUAC">Open a UAC file</button></div>`;
    $("#member-summary").textContent = state.documentName ? `${members.length} shown · ${playableMembers().length} audio tracks` : "No package open";
    scheduleTrackArraySizing();
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
      const popups = [];
      const rows = catalog.filter(entry => [...entry.scopes].some(value => value.startsWith(scope))).map((entry, index) => {
      const scoped = [...entry.scoped.entries()].filter(([name]) => name.startsWith(scope)).map(([, value]) => value);
      const count = scoped.reduce((total, value) => total + value.count, 0);
      const signatures = new Set(scoped.flatMap(value => [...value.signatures]));
      const values = new Map(scoped.flatMap(value => [...value.values.entries()]));
      const sample = scoped[0]?.sample;
      const multipleValues = signatures.size > 1 || typeof sample === "object";
      const editableMultipleValues = signatures.size === 1 && sample !== null && typeof sample === "object";
      let popupID = "";
      let valueInput;
      if (editableMultipleValues || multipleValues) {
        popupID = `tag-${scope.toLowerCase()}-${index}`;
        const popup = multipleValuesPopupParts(
          editableMultipleValues ? sample : null,
          { target:"metadata", scope:scope === "Package" ? "package" : "tracks", key:entry.key, popupID },
          { editable:editableMultipleValues, entries:[...values.values()].map((value, valueIndex) => [String(valueIndex + 1), value]) }
        );
        valueInput = popup.trigger;
        popups.push(popup.popup);
      } else {
        valueInput = `<input data-tag-value aria-label="Tag value for ${esc(entry.key)}" value="${esc(sample)}">`;
      }
      const tagType = multipleValues ? "Multiple Values" : signatures.size === 1 ? (Array.isArray(sample) ? "list" : typeof sample) : "various";
      const readOnlyMultipleValues = multipleValues && !editableMultipleValues;
      const submitTitle = readOnlyMultipleValues ? "Multiple Values contain different values" : "Submit changed fields";
      const popupAttribute = popupID ? ` data-multiple-popup-id="${esc(popupID)}"` : "";
      return `<div class="field-grid-row" role="row" data-tag-row data-tag-scope="${esc(scope)}" data-tag-from="${esc(entry.key)}"${popupAttribute}><div class="field-grid-cell tag-number-cell" role="cell"><input class="tag-table-field" value="${index + 1}" aria-label="Tag number" disabled></div><div class="field-grid-cell tag-type-cell" role="cell"><input class="tag-table-field" value="${esc(tagType)}" aria-label="Tag type for ${esc(entry.key)}" disabled></div><div class="field-grid-cell tag-name-cell" role="cell"><input class="tag-table-field" data-tag-to value="${esc(entry.key)}" aria-label="Tag name for ${esc(entry.key)}"></div><div class="field-grid-cell tag-value-cell" role="cell"><span class="tag-inline-editor">${valueInput}</span></div><div class="field-grid-cell tag-uses-cell" role="cell"><input class="tag-table-field" value="${count}" aria-label="Uses for ${esc(entry.key)}" disabled></div><div class="field-grid-cell tag-submit-cell" role="cell"><button class="icon-button" data-action="commitTagRow" title="${submitTitle}" aria-label="${submitTitle}"${readOnlyMultipleValues ? " disabled" : ""}>✓</button></div><div class="field-grid-cell tag-delete-cell" role="cell"><button class="icon-button danger" data-action="deleteTag" title="Delete ${esc(entry.key)}" aria-label="Delete ${esc(entry.key)}">×</button></div></div>`;
      }).join("");
      return { rows, popups:popups.join("") };
    };
    const header = `<div class="field-grid-row field-grid-header" role="row"><div class="field-grid-cell field-grid-heading" role="columnheader"><input class="tag-table-field field-grid-heading-input" value="#" disabled></div><div class="field-grid-cell field-grid-heading" role="columnheader"><input class="tag-table-field field-grid-heading-input" value="Tag Type" disabled></div><div class="field-grid-cell field-grid-heading" role="columnheader"><input class="tag-table-field field-grid-heading-input" value="Tag Name" disabled></div><div class="field-grid-cell field-grid-heading" role="columnheader"><input class="tag-table-field field-grid-heading-input" value="Tag Value" disabled></div><div class="field-grid-cell field-grid-heading" role="columnheader"><input class="tag-table-field field-grid-heading-input" value="Uses" disabled></div><div class="field-grid-cell field-grid-heading" role="columnheader"><input class="tag-table-field field-grid-heading-input" value="✓" aria-label="Submit" disabled></div><div class="field-grid-cell field-grid-heading" role="columnheader"><input class="tag-table-field field-grid-heading-input" value="×" aria-label="Delete" disabled></div></div>`;
    const grid = (title, rows, popups, scope) => `<section class="tag-scope-table"><div class="section-title"><span>${title}</span><form class="tag-create-form" data-tag-create data-tag-scope="${scope}"><input data-new-tag-key placeholder="Tag Name" aria-label="New tag name"><input data-new-tag-value placeholder="New tag value" aria-label="New tag value"><button class="icon-button add-tag-submit" type="submit" title="Add tag" aria-label="Add tag">✓</button></form></div><div class="data-table-scroll"><div class="field-grid meta-field-grid" role="table" aria-label="${title}">${header}${rows || '<div class="field-grid-empty" role="row"><span role="cell">No tags</span>'}</div></div>${popups}</section>`;
    const table = rowsFor(scope);
    return `<section class="data-page schema-page"><div class="data-page-heading"><div><h2>${esc(title)}</h2><p>${scope === "Package" ? "Package-level fields and attachments. Add or edit scalar values here; open an unambiguous structured value to edit its child fields." : "Track-level tag vocabulary across playable members. Add a field to every track or edit a shared scalar or unambiguous structured value."}</p></div><span class="data-page-count">${table.rows ? table.rows.split("data-tag-row").length - 1 : 0} fields</span></div>${grid(title, table.rows, table.popups, scope === "Package" ? "package" : "tracks")}${includeAttachments ? renderAttachments() : ""}</section>`;
  }

  function renderPackTagsPage() { return renderTagScopePage("Pack Tags", "Package", true); }

  function renderTrackArrayGrid(tracks) {
    const columns = trackColumns();
    const headerCells = ["Track", "Filename", ...columns.map(displayTrackKey)];
    const header = headerCells.map((label, index) => {
      const sortKey = index === 0 ? "track" : index === 1 ? "filename" : columns[index - 2];
      return `<div class="field-grid-cell field-grid-heading" role="columnheader" data-sort="${esc(sortKey)}"><input class="tag-table-field field-grid-heading-input" value="${esc(label)}" disabled></div>`;
    }).join("");
    const rows = tracks.map((member, index) => {
      const trackNumber = trackNumberFor(member, index);
      const filename = member.name || member.path.split("/").pop() || member.path;
      const rowLabel = member.title || filename;
      const structuredValues = [];
      const scalar = (value, key, scope, editable) => {
        const present = value !== undefined && value !== null && value !== "";
        const structured = present && typeof value === "object";
        const display = !present ? "—" : structured ? "Multiple Values" : String(value);
        const disabled = !editable || !present || structured ? " disabled" : "";
        const attributes = editable && present && !structured ? ` data-track-cell data-track-path="${esc(member.path)}" data-track-key="${esc(key)}" data-track-scope="${esc(scope)}"` : "";
        if (structured) {
          const foldID = `track-${index}-${structuredValues.length}`;
          structuredValues.push({ foldID, value, context:{ target:"member", path:member.path, scope, key, showCount:false } });
          return multipleValuesTriggerMarkup(foldID);
        }
        return `<input class="tag-table-field track-array-value${editable && present ? " track-cell" : ""}" value="${esc(display)}" aria-label="${esc(rowLabel)} ${esc(key)}"${attributes}${disabled}>`;
      };
      const metadataCells = columns.map(key => {
        const extension = key.startsWith("extension.");
        const fieldKey = extension ? key.slice("extension.".length) : key;
        const source = extension ? member.extensions : member.metadata;
        return `<div class="field-grid-cell" role="cell">${scalar(source?.[fieldKey], fieldKey, extension ? "memberExtensions" : "memberMetadata", true)}</div>`;
      }).join("");
      const row = `<div class="field-grid-row track-array-row" role="row"><div class="field-grid-cell" role="cell">${scalar(trackNumber, "track", "memberMetadata", false)}</div><div class="field-grid-cell" role="cell">${scalar(filename, "filename", "memberMetadata", false)}</div>${metadataCells}</div>`;
      const subrows = structuredValues.map(({ foldID, value, context }) => `<div class="field-grid-row field-grid-subrow" role="row" data-canonical-subrow="${esc(foldID)}"><div class="field-grid-cell canonical-subtable-cell" role="cell">${multipleValuesSubtableMarkup(value, context)}</div></div>`).join("");
      return row + subrows;
    }).join("");
    const empty = `<div class="field-grid-empty" role="row"><span role="cell">No playable tracks</span></div>`;
    return `<div class="field-grid tracks-field-grid" data-field-grid="tracks" role="table" aria-label="Tracks"><div class="field-grid-row field-grid-header" role="row">${header}</div>${rows || empty}</div>`;
  }

  function scheduleTrackArraySizing() {
    const grid = $(".tracks-field-grid");
    if (!grid) return;
    const tracks = visibleMembers();
    const columns = trackColumns();
    requestAnimationFrame(() => {
      const canvas = document.createElement("canvas");
      const context = canvas.getContext("2d");
      if (!context) return;
      context.font = "10px ui-monospace, SFMono-Regular, Menlo, monospace";
      const widthFor = values => Math.max(58, Math.ceil(Math.max(...values.map(value => context.measureText(String(value ?? "")).width), 0) + 18));
      const widths = [widthFor(["Track", ...tracks.map((member, index) => String(trackNumberFor(member, index)).padStart(2, "0"))]), widthFor(["Filename", ...tracks.map(member => member.name || member.path.split("/").pop() || member.path)]), ...columns.map(key => widthFor([displayTrackKey(key), ...tracks.map(member => { const value = memberFields(member)[key]; if (value === null || value === undefined || value === "") return "—"; if (typeof value === "object") return "Multiple Values"; return String(value); })]))];
      grid.style.setProperty("--field-grid-columns", widths.map(width => `${width}px`).join(" "));
    });
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
    const popups = [];
    const header = ["Scope", "Tag Name", "Tag Value", "Actions"].map(label => `<div class="field-grid-cell field-grid-heading" role="columnheader"><input class="tag-table-field field-grid-heading-input" value="${label}" disabled></div>`).join("");
    const rows = entries.map((entry, index) => {
      const structured = entry.value && typeof entry.value === "object";
      let popupID = "";
      let valueMarkup = memberTagValueMarkup(member, entry);
      if (structured) {
        popupID = `file-tag-${index}`;
        const popup = multipleValuesPopupParts(entry.value, { target:"member", path:member.path, scope:entry.scope, key:entry.key, popupID }, { editable:true });
        valueMarkup = popup.trigger;
        popups.push(popup.popup);
      }
      const popupAttribute = popupID ? ` data-multiple-popup-id="${esc(popupID)}"` : "";
      return `<div class="field-grid-row track-browser-row" role="row" data-file-tag-row data-file-tag-path="${esc(member.path)}" data-file-tag-scope="${esc(entry.scope)}" data-file-tag-from="${esc(entry.key)}"${popupAttribute}><div class="field-grid-cell" role="cell"><input class="tag-table-field file-tag-scope" value="${entry.scope === "memberExtensions" ? "extension" : "metadata"}" disabled></div><div class="field-grid-cell" role="cell"><input class="tag-table-field file-tag-key" data-file-tag-key value="${esc(entry.key)}" aria-label="Tag name"></div><div class="field-grid-cell track-browser-value-cell" role="cell">${valueMarkup}</div><div class="field-grid-cell track-browser-actions" role="cell"><button class="icon-button" data-action="commitFileTag" title="Submit changed tag" aria-label="Submit changed tag">✓</button><button class="icon-button danger" data-action="deleteFileTag" title="Delete tag" aria-label="Delete tag">×</button></div></div>`;
    }).join("");
    const empty = '<div class="field-grid-empty" role="row"><span role="cell">No tags on this file</span></div>';
    const form = `<form class="file-tag-create-form track-browser-create-form" data-file-tag-create data-file-tag-path="${esc(member.path)}"><select data-file-tag-scope aria-label="Tag namespace"><option value="memberMetadata">metadata</option><option value="memberExtensions">extension</option></select><input data-file-tag-key placeholder="Tag name" aria-label="New file tag name"><input data-file-tag-value placeholder="Value" aria-label="New file tag value"><button class="icon-button" type="submit" title="Add tag" aria-label="Add tag">✓</button></form>`;
    return `<div class="track-browser-table-wrap"><div class="field-grid track-browser-field-grid" role="table" aria-label="Tags for ${esc(member.name)}"><div class="field-grid-row field-grid-header" role="row">${header}</div>${rows || empty}</div>${form}${popups.join("")}</div>`;
  }

  function renderTrackPage() {
    const candidates = state.members.filter(member => fileTagEntries(member).length > 0);
    const selected = candidates.find(member => member.path === trackBrowserPath)
      || candidates.find(member => member.path === state.selectedMemberPath)
      || candidates[0];
    trackBrowserPath = selected?.path || "";
    const options = candidates.map(member => `<option value="${esc(member.path)}"${member.path === trackBrowserPath ? " selected" : ""}>${esc(member.name)} · ${fileTagEntries(member).length} tags</option>`).join("");
    const selector = `<label class="track-browser-selector"><span>File</span><select data-track-browser-select aria-label="File with tags">${options || '<option value="">No files with tags</option>'}</select></label>`;
    const body = selected ? renderTrackTagTable(selected) : '<div class="empty-tab"><strong>No tagged files</strong><span>Files with metadata or extensions will appear here.</span></div>';
    return `<section class="data-page track-browser-page"><div class="data-page-heading"><div><h2>Track</h2><p>Select a package file to inspect and edit every metadata and extension tag it contains.</p></div>${selector}</div>${body}</section>`;
  }

  function renderFilesPage() {
    const members = visibleFileMembers();
    const header = ["Role", "Format", "Filename", "Stored path", "Tags Count", "Size", "View"].map(label => `<div class="field-grid-cell field-grid-heading" role="columnheader"><input class="tag-table-field field-grid-heading-input" value="${esc(label)}" disabled></div>`).join("");
    const rows = members.map(member => `<div class="field-grid-row file-row" role="row" tabindex="0" data-track-row="${esc(member.path)}" title="Open metadata for ${esc(member.name)}"><div class="field-grid-cell" role="cell"><input class="tag-table-field" value="${esc(member.role)}" disabled></div><div class="field-grid-cell" role="cell"><input class="tag-table-field" value="${esc(member.format || "unknown")}" disabled></div><div class="field-grid-cell" role="cell"><input class="tag-table-field file-name-field" data-file-name data-file-path="${esc(member.path)}" value="${esc(member.name)}" aria-label="Filename"></div><div class="field-grid-cell" role="cell"><input class="tag-table-field file-path-field" value="${esc(member.path)}" disabled></div><div class="field-grid-cell" role="cell"><input class="tag-table-field file-tags-count" value="${fileTagEntries(member).length}" aria-label="Tag count" disabled></div><div class="field-grid-cell" role="cell"><input class="tag-table-field" value="${esc(bytes(member.bytes))}" disabled></div><div class="field-grid-cell file-preview-action" role="cell">${member.previewable ? `<button class="icon-button" data-action="previewMember" data-preview-path="${esc(member.path)}" title="View bundled text" aria-label="View bundled text">⌕</button>` : `<span class="file-preview-unavailable" title="Text preview unavailable">—</span>`}</div></div>`).join("");
    const empty = `<div class="field-grid-empty" role="row"><span role="cell">No package members match this filter</span></div>`;
    const preview = state.filePreviewPath
      ? `<section class="file-preview" aria-label="Bundled file preview"><div class="file-preview-heading"><div><strong>${esc(state.filePreviewName || "Bundled file")}</strong><span>${esc(state.filePreviewPath)}</span></div><button class="icon-button" data-action="closeFilePreview" title="Close preview" aria-label="Close preview">×</button></div>${state.filePreviewError ? `<div class="file-preview-error">${esc(state.filePreviewError)}</div>` : `<pre class="file-preview-content">${esc(state.filePreviewContent)}</pre>${state.filePreviewTruncated ? '<div class="file-preview-note">Preview limited to the first 4 MiB. The bundled file remains unchanged.</div>' : ""}`}</section>`
      : "";
    return `<section class="data-page files-page"><div class="data-page-heading"><div><h2>Files</h2><p>Every stored package member, including playable tracks, artwork, cues, and documents. Rename the displayed filename, preview text files, or choose Track to edit exhaustive per-file tags.</p></div><span class="data-page-count">${members.length} of ${state.members.length} members</span></div><div class="field-grid file-field-grid" role="table" aria-label="Package files"><div class="field-grid-row field-grid-header" role="row">${header}</div>${rows || empty}</div><p class="file-edit-note">Stored paths and payload members stay immutable so metadata saves preserve the compressed UAC payload byte-for-byte.</p>${preview}</section>`;
  }

  function renderAttachments() {
    const assets = state.members.filter(member => member.role !== "playable" && member.role !== "track");
    if (!assets.length) return "";
    const header = ["Role", "Format", "Filename", "Stored path", "Size"].map(label => `<div class="field-grid-cell field-grid-heading" role="columnheader"><input class="tag-table-field field-grid-heading-input" value="${esc(label)}" disabled></div>`).join("");
    const rows = assets.map(asset => `<div class="field-grid-row attachment-row" role="row" tabindex="0" data-track-row="${esc(asset.path)}" title="Open metadata for ${esc(asset.name)}"><div class="field-grid-cell" role="cell"><input class="tag-table-field" value="${esc(asset.role)}" disabled></div><div class="field-grid-cell" role="cell"><input class="tag-table-field" value="${esc(asset.format || "unknown")}" disabled></div><div class="field-grid-cell" role="cell"><input class="tag-table-field file-name-field" value="${esc(asset.name)}" disabled></div><div class="field-grid-cell" role="cell"><input class="tag-table-field file-path-field" value="${esc(asset.path)}" disabled></div><div class="field-grid-cell" role="cell"><input class="tag-table-field" value="${esc(bytes(asset.bytes))}" disabled></div></div>`).join("");
    return `<section class="inspector-section attachments-section"><div class="section-title"><span>Attachments</span><span class="section-help">${assets.length} package files</span></div><div class="data-table-scroll attachment-table-scroll"><div class="field-grid attachment-field-grid" role="table" aria-label="Package attachments"><div class="field-grid-row field-grid-header" role="row">${header}</div>${rows}</div></div></section>`;
  }

  function renderInspector() {
    const hasPackage = Boolean(state.documentName);
    const member = state.members.find(item => item.path === state.selectedMemberPath);
    if (!hasPackage) {
      $("#inspector-content").innerHTML = `<div class="metadata-empty"><div class="empty-icon">⌁</div><h3>Open a package to edit metadata</h3><p>Choose a collection entry or open a UAC file.</p></div>`;
      return;
    }
    const title = member?.title || member?.name || "Package metadata";
    const pageTitle = ["files", "packTags", "trackBrowser"].includes(mainView) ? state.packageTitle || state.packageID : title;
    const eyebrow = mainView === "files" ? "FILES" : mainView === "trackBrowser" || mainView === "track" ? "TRACK" : mainView === "packTags" ? "PACK TAGS" : "PACKAGE";
    let html = `<div class="inspector-head"><div class="inspector-title-row"><div><span class="eyebrow">${eyebrow}</span><h2>${esc(pageTitle)}</h2></div></div>${mainView === "track" && member ? `<div class="inspector-sub">${esc(member.role)} · ${esc(member.format || "unknown format")} · ${bytes(member.bytes)}<br><span title="Stored UAC path: ${esc(member.path)}">${esc(memberLocation(member))}</span></div>` : `<div class="inspector-sub">${esc(state.packageID)}</div>`}</div>`;
    if (mainView === "track") {
      if (member) {
        html += `<section class="track-tags-editor">${renderPropertyEditor("Track Metadata", "memberMetadata", state.memberMetadataJSON, { includeTechnical:true, includeEmpty:true })}${renderPropertyEditor("Track Extensions", "memberExtensions", state.memberExtensionsJSON, { includeTechnical:true, includeEmpty:true })}</section>`;
      } else html += `<section class="inspector-section"><div class="empty-tab"><strong>Select a track</strong><span>Choose a row in Tracks to edit its tags.</span></div></section>`;
    } else if (mainView === "files") html += renderFilesPage();
    else if (mainView === "packTags") html += renderPackTagsPage();
    else if (mainView === "trackBrowser") html += renderTrackPage();
    $("#inspector-content").innerHTML = html;
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
    bridge("selectMember", { path:member.path });
    bridge(scopeToAction(scope), { value:JSON.stringify(values, null, 2) });
  }

  function addMultipleValue(editor) {
    const rows = $(".multiple-values-rows", editor);
    if (!rows) return;
    const isArray = editor.dataset.multipleArray === "true";
    $(".multiple-values-empty", rows)?.remove();
    const row = document.createElement("div");
    row.className = "tag-multiple-value-row multiple-value-editor-row";
    row.dataset.multipleEntry = "";
    row.dataset.multipleKind = "string";
    row.innerHTML = `<input class="multiple-value-key" data-multiple-key value="" aria-label="New value key"${isArray ? " disabled" : ""}><input class="multiple-value-editor" data-multiple-value value="" aria-label="New value"><button class="icon-button danger multiple-value-remove" data-action="removeMultipleValue" type="button" title="Remove value" aria-label="Remove value">×</button>`;
    rows.append(row);
    $("[data-multiple-key]", row)?.focus();
  }

  function removeMultipleValue(row) {
    const editor = row?.closest("[data-multiple-editor]");
    if (!row || !editor) return;
    row.remove();
    const rows = $(".multiple-values-rows", editor);
    if (rows && !$("[data-multiple-entry]", rows)) rows.innerHTML = '<div class="file-tag-empty multiple-values-empty">No values</div>';
  }

  function commitMultipleValues(editor) {
    if (!editor) return;
    const error = $(".multiple-values-editor-error", editor);
    const isArray = editor.dataset.multipleArray === "true";
    const result = isArray ? [] : {};
    const seenKeys = new Set();
    for (const row of $$("[data-multiple-entry]", editor)) {
      const key = isArray ? String(result.length) : $("[data-multiple-key]", row)?.value.trim() || "";
      if (!isArray && !key) {
        if (error) error.textContent = "Keys cannot be empty.";
        $("[data-multiple-key]", row)?.focus();
        return;
      }
      if (!isArray && seenKeys.has(key)) {
        if (error) error.textContent = "Keys must be unique.";
        $("[data-multiple-key]", row)?.focus();
        return;
      }
      seenKeys.add(key);
      const raw = $("[data-multiple-value]", row)?.value ?? "";
      try {
        const value = coerceValue(raw, row.dataset.multipleKind || "string");
        if (isArray) result.push(value); else result[key] = value;
      } catch {
        if (error) error.textContent = `Invalid JSON value for “${key || "value"}”.`;
        $("[data-multiple-value]", row)?.focus();
        return;
      }
    }
    if (error) error.textContent = "";
    const valueJSON = JSON.stringify(result);
    const tagRow = editor.closest("[data-tag-row]");
    const fileRow = editor.closest("[data-file-tag-row]");
    if (editor.dataset.multipleTarget === "metadata") {
      const key = editor.dataset.multipleKey || tagRow?.dataset.tagFrom || "";
      let newKey = $("[data-tag-to]", tagRow)?.value.trim() || key;
      if (key.startsWith("extension.") && !newKey.startsWith("extension.")) newKey = `extension.${newKey}`;
      bridge("commitMetadataRow", { key, newKey, scope:editor.dataset.multipleScope || "", value:null, valueJSON });
    } else {
      const key = editor.dataset.multipleKey || fileRow?.dataset.fileTagFrom || "";
      const newKey = $("[data-file-tag-key]", fileRow)?.value || key;
      bridge("commitMemberTag", { path:editor.dataset.multiplePath || fileRow?.dataset.fileTagPath || "", scope:editor.dataset.multipleScope || fileRow?.dataset.fileTagScope || "memberMetadata", key, newKey, value:"", valueJSON });
    }
  }

  function multipleValuesEditorForRow(row) {
    const inlineEditor = $("[data-multiple-editor]", row);
    if (inlineEditor) return inlineEditor;
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
      mainView = "track";
      bridge("selectMember", { path:memberRow.dataset.member });
      render(state);
    }
    if (trackRow && !event.target.closest("input,button,form,.canonical-fold")) {
      const path = trackRow.dataset.trackRow;
      mainView = "track"; bridge("selectMember", { path }); render(state);
    }
    if (!action) return;
    if (action === "addField") addField(event.target.closest("[data-scope]").dataset.scope);
    else if (action === "renameTag") {
      const row = event.target.closest("[data-tag-row]");
      const from = row?.dataset.tagFrom || "";
      const to = $("[data-tag-to]", row)?.value.trim() || "";
      const normalizedTo = from.startsWith("extension.") && !to.startsWith("extension.") ? `extension.${to}` : to;
      if (from && normalizedTo && from !== normalizedTo) bridge("renameMetadataKey", { from, to:normalizedTo });
    }
    else if (action === "deleteTag") {
      const row = event.target.closest("[data-tag-row]");
      const key = row?.dataset.tagFrom || "";
      if (key) animateRowRemoval(row, () => bridge("deleteMetadataKey", { key, scope:row.dataset.tagScope || "" }));
    }
    else if (action === "addMultipleValue") addMultipleValue(event.target.closest("[data-multiple-editor]"));
    else if (action === "removeMultipleValue") removeMultipleValue(event.target.closest("[data-multiple-entry]"));
    else if (action === "commitMultipleValues") commitMultipleValues(event.target.closest("[data-multiple-editor]"));
    else if (action === "toggleMultipleValuesPopup") toggleMultipleValuesPopup(event.target.closest("[data-action=toggleMultipleValuesPopup]")?.dataset.popupId || "", event.target.closest("[data-action=toggleMultipleValuesPopup]"));
    else if (action === "closeMultipleValuesPopup") closeMultipleValuesPopup(event.target.closest("[data-multiple-values-popup]"));
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
        const editor = multipleValuesEditorForRow(row);
        if (editor) { commitMultipleValues(editor); return; }
        const from = row.dataset.tagFrom || "";
        let to = $('[data-tag-to]', row)?.value || "";
        if (from.startsWith("extension.") && !to.startsWith("extension.")) to = `extension.${to}`;
        bridge("commitMetadataRow", { key:from, newKey:to, scope:row.dataset.tagScope || "", value:$('[data-tag-value]', row)?.disabled ? null : ($('[data-tag-value]', row)?.value || "") });
      }
    }
    else if (action === "commitFileTag") {
      const row = event.target.closest("[data-file-tag-row]");
      if (row) {
        const editor = multipleValuesEditorForRow(row);
        if (editor) { commitMultipleValues(editor); return; }
        bridge("commitMemberTag", { path:row.dataset.fileTagPath || "", scope:row.dataset.fileTagScope || "", key:row.dataset.fileTagFrom || "", newKey:$('[data-file-tag-key]', row)?.value || "", value:$('[data-file-tag-value]', row)?.value || "" });
      }
    }
    else if (action === "deleteFileTag") {
      const row = event.target.closest("[data-file-tag-row]");
      if (row) animateRowRemoval(row, () => bridge("deleteMemberTag", { path:row.dataset.fileTagPath || "", scope:row.dataset.fileTagScope || "", key:row.dataset.fileTagFrom || "" }));
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
      bridge("addMetadataKey", { key:$('[data-new-tag-key]', form)?.value || "", scope:form.dataset.tagScope || "package", value:$('[data-new-tag-value]', form)?.value || "" });
      return;
    }
    const fileForm = event.target.closest("[data-file-tag-create]");
    if (!fileForm) return;
    event.preventDefault();
    bridge("addMemberTag", { path:fileForm.dataset.fileTagPath || "", scope:$('[data-file-tag-scope]', fileForm)?.value || "memberMetadata", key:$('[data-file-tag-key]', fileForm)?.value || "", value:$('[data-file-tag-value]', fileForm)?.value || "" });
  });

  document.addEventListener("change", event => {
    const target = event.target;
    if (target.matches("[data-track-cell]")) commitTrackCell(target);
    else if (target.matches("[data-track-browser-select]")) { trackBrowserPath = target.value; render(state); }
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
      const popup = $("[data-multiple-values-popup]:not([hidden])");
      if (popup) { closeMultipleValuesPopup(popup); return; }
    }
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "f") { event.preventDefault(); $("#collection-filter").focus(); }
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") { const field = $("#member-filter"); if (field) { event.preventDefault(); field.focus(); } }
  });

  window.UACMan = { render };
})();
