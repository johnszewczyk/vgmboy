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
    discFilename: "Disc filename"
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
    playableMembers().forEach(member => Object.entries(memberFields(member)).forEach(([key, value]) => { if (hasMeaningfulTagValue(value) && !isTechnicalKey(key)) keys.add(key); }));
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
      const kind = Array.isArray(value) ? "List" : "Object";
      return `<span class="structured-value" title="${kind} value; open the editor to inspect it">${kind} · ${count}</span>`;
    }
    return esc(String(value));
  };
  const structuredPopup = value => {
    const entries = Array.isArray(value) ? value.map((item, index) => [String(index + 1), item]) : Object.entries(value || {});
    const kind = Array.isArray(value) ? "List" : "Object";
    const body = entries.length ? entries.map(([key, item]) => `<div><strong>${esc(key)}</strong><span>${displayMetadataValue(item)}</span></div>`).join("") : '<div class="muted">Empty</div>';
    return `<details class="tag-values-popover track-structured-popover"><summary>${kind} · ${entries.length}</summary><div class="tag-values-list">${body}</div></details>`;
  };
  const metadataSortValue = (member, key) => {
    const value = memberFields(member)[key];
    return value && typeof value === "object" ? JSON.stringify(value) : (value ?? "");
  };
  let state = null;
  let sort = { key:"track", direction:1 };
  let inspectorTab = "set";
  let mainView = "members";
  let lastDocumentName = "";
  let selectionAnchorPath = null;

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
    }
    const active = document.activeElement;
    const focusId = active?.dataset?.focusId;
    const selection = active && "selectionStart" in active ? [active.selectionStart, active.selectionEnd] : null;

    $("#document-name").textContent = state.documentName || "No package open";
    $("#document-path").textContent = state.documentPath || "Choose a collection or open one UAC file";
    $("#member-filter-wrap").classList.toggle("hidden", mainView !== "members");
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
    if (mainView === "schema" || mainView === "technical") scheduleSchemaColumnSizing();
    $("#members-view").classList.toggle("hidden", mainView !== "members");
    $("#metadata-view").classList.toggle("hidden", mainView === "members");
    $$(".main-view-tabs button").forEach(button => button.classList.toggle("active", button.dataset.view === mainView));

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
      ? (noRows ? `<div class="empty-state"><div class="empty-icon">▤</div><h3>${state.members.length ? "No tracks match this filter" : "This package has no audio tracks"}</h3><p>${state.members.length ? "Change the search text to show audio tracks." : "The package contains no playable members."}</p></div>` : renderTrackGrid(members))
      : `<div class="empty-state"><div class="empty-icon">▤</div><h3>Open a package to get started</h3><p>Browse a collection or open a UAC package. Audio streams appear here as rows with their tags as columns.</p><button class="button primary" data-action="openUAC">Open a UAC file</button></div>`;
    $("#member-summary").textContent = state.documentName ? `${members.length} shown · ${playableMembers().length} audio tracks` : "No package open";
    $("#table-selection-summary").textContent = state.selectedMemberPaths.length ? `${state.selectedMemberPaths.length} selected` : "";
    $$(".track-grid th[data-sort]").forEach(th => { const marker = $("span", th); marker.textContent = sort.key === th.dataset.sort ? (sort.direction > 0 ? " ↑" : " ↓") : ""; });
    scheduleTrackColumnSizing();
    const selectAll = $("[data-select-all]");
    if (selectAll) {
      const visiblePaths = members.map(member => member.path);
      const selectedVisible = visiblePaths.filter(path => state.selectedMemberPaths.includes(path)).length;
      selectAll.checked = visiblePaths.length > 0 && selectedVisible === visiblePaths.length;
      selectAll.indeterminate = selectedVisible > 0 && selectedVisible < visiblePaths.length;
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
      const label = Array.isArray(value) ? `List · ${value.length} items` : `Object · ${Object.keys(value).length} fields`;
      return `<details class="nested-field"><summary>${esc(label)} <span>Open</span></summary><textarea class="field-structured" data-field-value data-focus-id="${esc(id)}">${esc(encoded)}</textarea></details>`;
    }
    return `<input class="field-value" data-field-value data-focus-id="${esc(id)}" value="${esc(encoded)}">`;
  }

  function renderPropertyEditor(title, scope, raw) {
    const value = parseObject(raw);
    const fields = value ? Object.entries(value).filter(([key, field]) => !isTechnicalKey(key) && !isEmptyTagValue(field)).map(([key, field]) => {
      const kind = fieldKind(field);
      const editorID = `${scope}-${key}`;
      return `<tr class="field-row ${isTechnicalKey(key) ? "technical-field" : ""}" data-kind="${kind}"><td><input class="field-key" data-field-key data-focus-id="${esc(editorID)}" value="${esc(key)}" aria-label="Metadata field name"></td><td>${fieldValueMarkup(field, `${editorID}-value`, kind)}</td><td class="field-type-cell"><select class="field-type" data-field-type aria-label="Value type"><option value="string" ${kind === "string" ? "selected" : ""}>text</option><option value="number" ${kind === "number" ? "selected" : ""}>number</option><option value="boolean" ${kind === "boolean" ? "selected" : ""}>boolean</option><option value="json" ${kind === "json" ? "selected" : ""}>json</option></select></td><td class="field-action-cell"><button class="remove-field" data-action="removeField" title="Remove field" aria-label="Remove ${esc(key)}">×</button></td></tr>`;
    }).join("") : `<tr><td colspan="4" class="json-invalid">Metadata must be a JSON object. Use the JSON editor only if recovery is needed.</td></tr>`;
    return `<section class="inspector-section metadata-section" data-scope-section="${scope}"><div class="section-title">${esc(title)}<span class="section-actions"><button class="add-field" data-action="addField" data-scope="${scope}">＋ Add field</button></span></div><table class="kv-table"><thead><tr><th>Key</th><th>Value</th><th class="type-heading">Type</th><th class="action-heading"></th></tr></thead><tbody class="field-list" data-editor="${scope}">${fields}</tbody></table><div class="field-error" data-error-for="${scope}"></div><details class="raw-editor"><summary>Open JSON editor</summary><textarea data-raw-editor="${scope}" data-focus-id="raw-${scope}">${esc(raw || "{}")}</textarea></details></section>`;
  }

  function treeValue(key, value, depth = 0) {
    const label = esc(key);
    if (value !== null && typeof value === "object") {
      const entries = Array.isArray(value) ? value.map((item, index) => [String(index + 1), item]) : Object.entries(value);
      const kind = Array.isArray(value) ? `list · ${entries.length}` : `object · ${entries.length}`;
      const children = entries.length ? entries.map(([childKey, childValue]) => treeValue(childKey, childValue, depth + 1)).join("") : '<div class="tree-empty">Empty</div>';
      return `<details class="tree-node" ${depth < 1 ? "open" : ""}><summary><span class="tree-key">${label}</span><span class="tree-kind">${kind}</span></summary><div class="tree-children">${children}</div></details>`;
    }
    return `<div class="tree-leaf"><span class="tree-key">${label}</span><span class="tree-value">${displayMetadataValue(value)}</span></div>`;
  }

  function playableMembers() {
    const playable = state.members.filter(member => member.role === "playable" || member.role === "track");
    return playable.length ? playable : state.members;
  }

  function trackColumns() {
    const keys = new Set();
    playableMembers().forEach(member => Object.entries(memberFields(member)).forEach(([key, value]) => { if (hasMeaningfulTagValue(value) && !isTechnicalKey(key)) keys.add(key); }));
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

  function technicalEntries() {
    const entries = [];
    const add = (scope, track, key, value) => {
      if (isTechnicalKey(key) && hasMeaningfulTagValue(value)) entries.push({ scope, track, key, value });
    };
    const game = parseObject(state.gameMetadataJSON) || {};
    const gameExtensions = parseObject(state.gameExtensionsJSON) || {};
    Object.entries(game).forEach(([key, value]) => add("Package Tags", "Package", key, value));
    Object.entries(gameExtensions).forEach(([key, value]) => add("Package Extensions", "Package", `extension.${key}`, value));
    state.members.forEach((member, index) => {
      const track = String(trackNumberFor(member, index)).padStart(2, "0");
      Object.entries(member.metadata || {}).forEach(([key, value]) => add("Track Tags", track, key, value));
      Object.entries(member.extensions || {}).forEach(([key, value]) => add("Track Extensions", track, `extension.${key}`, value));
      add("Identity", track, "fileBLAKE3", member.rawHash);
      if (typeof member.streamHash === "string" && member.streamHash) add("Identity", track, "streamBLAKE3", member.streamHash);
      (member.hashes || []).forEach(hash => add("Identity", track, `${hash.scope}.${hash.profile}`, hash.digest));
    });
    return entries;
  }

  function renderTechnicalPage() {
    const entries = technicalEntries();
    const rows = entries.map(entry => `<tr data-technical-row data-tech-scope="${esc(entry.scope)}" data-tech-track="${esc(entry.track)}" data-tech-key="${esc(entry.key)}"><td><input class="tag-table-field" data-tech-scope value="${esc(entry.scope)}"></td><td><input class="tag-table-field" data-tech-track value="${esc(entry.track)}"></td><td><input class="tag-table-field" data-tech-key value="${esc(entry.key)}"></td><td class="tag-value-cell"><input class="tag-table-field" data-tech-value value="${esc(typeof entry.value === "object" ? displayMetadataValue(entry.value).replace(/<[^>]+>/g, "") : entry.value)}"></td><td class="tag-submit-cell"><button class="icon-button" data-action="commitTechnicalRow" title="Submit changed fields" aria-label="Submit changed fields">✓</button></td><td class="tag-delete-cell"><button class="icon-button danger" data-action="deleteTechnicalRow" title="Delete technical field" aria-label="Delete technical field">×</button></td></tr>`).join("");
    return `<section class="data-page technical-page"><div class="data-page-heading"><div><h2>Technical Fields</h2></div><span class="data-page-count">${entries.length} fields</span></div><div class="data-table-scroll"><table class="data-table schema-table technical-table"><colgroup><col class="technical-scope-column"><col class="technical-track-column"><col class="technical-key-column"><col class="technical-value-column"><col class="technical-submit-column"><col class="technical-delete-column"></colgroup><thead><tr><th>Scope</th><th>Track</th><th>Key</th><th>Value</th><th class="action-heading" colspan="2">Actions</th></tr></thead><tbody>${rows || '<tr><td colspan="6" class="tree-empty">No technical fields</td></tr>'}</tbody></table></div></section>`;
  }

  function metadataTagCatalog() {
    const catalog = new Map();
    const add = (key, scope, value) => {
      if (isEmptyTagValue(value)) return;
      const existing = catalog.get(key) || { key, scopes:new Set(), count:0, sample:value, signatures:new Set(), values:new Map() };
      existing.scopes.add(scope);
      existing.count += 1;
      const signature = JSON.stringify(value);
      existing.signatures.add(signature);
      existing.values.set(signature, value);
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

  function renderMetaTagsPage() {
    const catalog = metadataTagCatalog();
    const rowsFor = scope => catalog.filter(entry => [...entry.scopes].some(value => value.startsWith(scope))).map(entry => {
      const example = entry.signatures.size === 1
        ? displayMetadataValue(entry.sample)
        : `<details class="tag-values-popover"><summary><span class="muted">(${entry.signatures.size} values)</span></summary><div class="tag-values-list">${[...entry.values.values()].map(value => `<div>${displayMetadataValue(value)}</div>`).join("")}</div></details>`;
      const valueEditor = entry.signatures.size === 1 && typeof entry.sample !== "object"
        ? `<span class="tag-inline-editor"><input data-tag-value aria-label="New value for ${esc(entry.key)}" value="${esc(entry.sample)}" placeholder="New value"><button class="icon-button" data-action="updateTagValue" title="Apply value to every use" aria-label="Submit value">✓</button></span>`
        : `<span class="muted tag-value-disabled">Multiple Values</span>`;
      const valueInput = entry.signatures.size === 1 && typeof entry.sample !== "object" ? `<input data-tag-value aria-label="Tag value for ${esc(entry.key)}" value="${esc(entry.sample)}">` : `<input data-tag-value aria-label="Tag value for ${esc(entry.key)}" value="Multiple Values" disabled>`;
      const tagType = entry.signatures.size === 1 ? (Array.isArray(entry.sample) ? "list" : typeof entry.sample) : "various";
      return `<tr data-tag-row data-tag-from="${esc(entry.key)}"><td class="tag-number-cell"><input class="tag-table-field" value="${catalog.indexOf(entry) + 1}" aria-label="Tag number" disabled></td><td class="tag-type-cell"><input class="tag-table-field" value="${esc(tagType)}" aria-label="Tag type for ${esc(entry.key)}" disabled></td><td class="tag-name-cell"><input class="tag-table-field" data-tag-to value="${esc(entry.key)}" aria-label="Tag name for ${esc(entry.key)}"></td><td class="tag-value-cell"><span class="tag-inline-editor">${valueInput}</span></td><td class="tag-uses-cell"><input class="tag-table-field" value="${entry.count}" aria-label="Uses for ${esc(entry.key)}" disabled></td><td class="tag-submit-cell"><button class="icon-button" data-action="commitTagRow" title="Submit changed fields" aria-label="Submit changed fields">✓</button></td><td class="tag-delete-cell"><button class="icon-button danger" data-action="deleteTag" title="Delete ${esc(entry.key)}" aria-label="Delete ${esc(entry.key)}">×</button></td></tr>`;
    }).join("");
    const table = (title, rows, scope) => `<section class="tag-scope-table"><div class="section-title"><span>${title}</span><form class="tag-create-form" data-tag-create data-tag-scope="${scope}"><input data-new-tag-key placeholder="Meta Tag Name" aria-label="New tag name"><input data-new-tag-value placeholder="New Key Value" aria-label="New tag value"><button class="icon-button add-tag-submit" type="submit" title="Add tag" aria-label="Add tag">✓</button></form></div><div class="data-table-scroll"><table class="data-table schema-table"><colgroup><col class="tag-number-column"><col class="tag-type-column"><col class="tag-name-column"><col class="tag-value-column"><col class="tag-uses-column"><col class="tag-submit-column"><col class="tag-delete-column"></colgroup><thead><tr><th>#</th><th>Tag Type</th><th>Tag Name</th><th>Tag Value</th><th>Uses</th><th></th><th></th></tr></thead><tbody>${rows || '<tr><td colspan="7" class="tree-empty">No metadata tags</td></tr>'}</tbody></table></div></section>`;
    return `<section class="data-page schema-page">${table("Package Tags", rowsFor("Package"), "package")}${table("Track Tags", rowsFor("Track"), "tracks")}</section>`;
  }

  function renderTrackGrid(tracks) {
    const columns = trackColumns();
    const rows = tracks.map((member, index) => {
      const fields = memberFields(member);
      const cells = columns.map(key => {
        const value = fields[key];
        if (!Object.prototype.hasOwnProperty.call(fields, key) || isEmptyTagValue(value)) return `<td><span class="muted">—</span></td>`;
        if (value && typeof value === "object") return `<td>${structuredPopup(value)}</td>`;
        const extension = key.startsWith("extension.");
        const fieldKey = extension ? key.slice("extension.".length) : key;
        return `<td><input class="track-cell" data-track-cell data-track-path="${esc(member.path)}" data-track-key="${esc(fieldKey)}" data-track-scope="${extension ? "memberExtensions" : "memberMetadata"}" value="${esc(value ?? "")}" aria-label="${esc(member.title || member.name)} ${esc(key)}"></td>`;
      }).join("");
      const trackNumber = trackNumberFor(member, index);
      return `<tr tabindex="0" data-track-row="${esc(member.path)}" class="${member.path === state.selectedMemberPath ? "active" : ""}"><td class="select-cell"><input type="checkbox" data-select-member="${esc(member.path)}" ${state.selectedMemberPaths.includes(member.path) ? "checked" : ""} aria-label="Select ${esc(member.name)}"></td><td class="track-number-cell" title="${esc(member.path)}"><span class="track-number">${esc(String(trackNumber).padStart(2, "0"))}</span></td>${cells}</tr>`;
    }).join("");
    return `<div class="track-grid-wrap"><div class="track-grid-scroll"><table class="track-grid"><colgroup><col data-column-key="select" style="width:28px"><col data-column-key="track" style="width:64px">${columns.map(key => `<col data-column-key="${esc(key)}" style="width:100px">`).join("")}</colgroup><thead><tr><th class="select-heading"><input type="checkbox" data-select-all aria-label="Select all visible tracks"></th><th class="track-number-heading" data-sort="track">Track <span></span></th>${columns.map(key => `<th data-sort="${esc(key)}" title="Sort by ${esc(displayMetadataKey(key))}">${esc(displayMetadataKey(key))} <span></span></th>`).join("")}</tr></thead><tbody>${rows || '<tr><td class="tree-empty" colspan="3">No playable tracks</td></tr>'}</tbody></table></div></div>`;
  }

  function scheduleTrackColumnSizing() {
    const table = $(".track-grid");
    if (!table) return;
    const tracks = visibleMembers();
    const columns = trackColumns();
    requestAnimationFrame(() => {
      const canvas = document.createElement("canvas");
      const context = canvas.getContext("2d");
      if (!context) return;
      context.font = "10px ui-monospace, SFMono-Regular, Menlo, monospace";
      const widthFor = values => Math.max(42, Math.ceil(Math.max(...values.map(value => context.measureText(String(value ?? "")).width), 0) + 16));
      const widths = [28, widthFor(["Track", ...tracks.map((member, index) => String(trackNumberFor(member, index)).padStart(2, "0"))])];
      columns.forEach(key => widths.push(widthFor([key, ...tracks.map(member => {
        const value = memberFields(member)[key];
        if (value === null || value === undefined || value === "") return "—";
        if (typeof value === "object") return Array.isArray(value) ? `List · ${value.length}` : `Object · ${Object.keys(value).length}`;
        return String(value);
      })])));
      const total = widths.reduce((sum, width) => sum + width, 0);
      table.style.width = `${Math.max(980, total)}px`;
      table.style.tableLayout = "fixed";
      $$("col[data-column-key]", table).forEach((column, index) => { column.style.width = `${widths[index]}px`; });
    });
  }

  function scheduleSchemaColumnSizing() {
    requestAnimationFrame(() => {
      $$(".schema-table").forEach(table => {
        const rows = $$('thead tr:first-child, tbody tr', table);
        const columns = Math.max(...rows.map(row => row.children.length), 0);
        if (!columns) return;
        const canvas = document.createElement("canvas"), context = canvas.getContext("2d");
        if (!context) return;
        context.font = "10px ui-monospace, SFMono-Regular, Menlo, monospace";
        const widths = Array.from({ length:columns }, (_, index) => Math.max(30, ...rows.map(row => context.measureText(row.children[index]?.textContent?.trim() || row.children[index]?.querySelector("input")?.value || "").width + 18)));
        table.style.width = "100%";
        table.style.minWidth = "0";
        const colgroup = table.querySelector("colgroup");
        if (colgroup) [...colgroup.children].forEach((column, index) => { if (index === 0 || index === 1 || index === 4 || index === 5 || index === 6) column.style.width = `${widths[index]}px`; else column.style.width = "auto"; });
      });
    });
  }

  function renderAttachments() {
    const assets = state.members.filter(member => member.role !== "playable" && member.role !== "track");
    if (!assets.length) return "";
    return `<section class="inspector-section attachments-section"><div class="section-title"><span>Attachments</span><span class="section-help">${assets.length} package files</span></div><div class="attachment-list">${assets.map(asset => `<div class="attachment-row"><span class="attachment-kind">${esc(asset.format || asset.role)}</span><span class="attachment-name" title="${esc(asset.path)}">${esc(asset.name)}</span><span class="attachment-path">${esc(asset.path)}</span></div>`).join("")}</div></section>`;
  }

  function treeEditor(scope, fields, memberPath, title) {
    const rootID = `${scope}-${memberPath || "set"}`;
    const rows = Object.entries(fields).filter(([key, value]) => !isTechnicalKey(key) && !isEmptyTagValue(value)).map(([key, value]) => {
      const kind = fieldKind(value);
      const structured = value && typeof value === "object";
      const valueMarkup = structured
        ? `<details class="tree-structured"><summary>Structured value · ${Array.isArray(value) ? value.length : Object.keys(value).length}</summary><span>Open the ${memberPath ? "Track Tags" : "Package Tags"} page to edit this value.</span></details>`
        : `<input data-tree-value value="${esc(value ?? "")}" aria-label="${esc(key)} value">`;
      return `<tr class="tree-entry ${isTechnicalKey(key) ? "technical-entry" : ""}" data-tree-kind="${kind}" data-tree-raw="${structured ? esc(JSON.stringify(value)) : ""}"><td><input data-tree-key value="${esc(key)}" aria-label="Metadata key"></td><td>${valueMarkup}</td><td class="tree-type">${kind === "json" ? (structured ? "structured" : "json") : esc(kind)}</td></tr>`;
    }).join("");
    return `<section class="tree-dictionary" data-tree-editor data-tree-scope="${scope}" data-tree-member="${esc(memberPath || "")}" data-tree-id="${esc(rootID)}"><div class="tree-dictionary-heading"><strong>${esc(title)}</strong><span><button class="add-field" data-action="addTreeField">＋ Add field</button></span></div><table class="tree-table"><thead><tr><th>Key</th><th>Value</th><th>Type</th></tr></thead><tbody class="tree-entry-list">${rows || '<tr><td colspan="3" class="tree-empty">No fields</td></tr>'}</tbody></table></section>`;
  }

  function renderTree() {
    const game = parseObject(state.gameMetadataJSON) || {};
    const gameExtensions = parseObject(state.gameExtensionsJSON) || {};
    const tracks = playableMembers().map(member => {
      const selected = member.path === state.selectedMemberPath;
      const metadata = member.metadata || {};
      const extensions = member.extensions || {};
      return `<details class="tree-track" ${selected ? "open" : ""}><summary data-tree-member="${esc(member.path)}"><span class="tree-track-title">${esc(member.title || member.name)}</span><span class="tree-kind">${esc(member.format || member.role)}</span></summary><div class="tree-track-body">${treeEditor("memberMetadata", metadata, member.path, "Track Tags")}${Object.keys(extensions).length ? treeEditor("memberExtensions", extensions, member.path, "Track Extensions") : ""}</div></details>`;
    }).join("");
    return `<section class="tree-page"><p class="tab-note">A plain key : value view. Scalar fields can be edited here; technical fields are collected on the Technical page.</p><details class="tree-branch" open><summary><strong>Set</strong><span>${esc(state.packageTitle || state.packageID)}</span></summary><div class="tree-branch-body">${treeEditor("gameMetadata", game, "", "Set Tags")}${Object.keys(gameExtensions).length ? treeEditor("gameExtensions", gameExtensions, "", "Set Extensions") : ""}</div></details><details class="tree-branch" open><summary><strong>Tracks</strong><span>${playableMembers().length} audio tracks</span></summary><div class="tree-track-list">${tracks || '<div class="tree-empty">No playable tracks</div>'}</div></details></section>`;
  }

  function renderInspector() {
    const hasPackage = Boolean(state.documentName);
    const member = state.members.find(item => item.path === state.selectedMemberPath);
    if (!hasPackage) {
      $("#inspector-content").innerHTML = `<div class="metadata-empty"><div class="empty-icon">⌁</div><h3>Open a package to edit metadata</h3><p>Choose a collection entry or open a UAC file.</p></div>`;
      return;
    }
    const title = member?.title || member?.name || "Package metadata";
    const pageTitle = ["package", "technical", "schema", "tree"].includes(mainView) ? state.packageTitle || state.packageID : title;
    let html = `<div class="inspector-head"><div class="inspector-title-row"><div><span class="eyebrow">${mainView === "package" ? "PACKAGE TAGS" : mainView === "track" ? "TRACK TAGS" : mainView === "technical" ? "TECHNICAL" : mainView === "schema" ? "META TAGS" : "METADATA TREE"}</span><h2>${esc(pageTitle)}</h2></div></div>${mainView === "track" && member ? `<div class="inspector-sub">${esc(member.role)} · ${esc(member.format || "unknown format")} · ${bytes(member.bytes)}<br><span title="Stored UAC path: ${esc(member.path)}">${esc(memberLocation(member))}</span></div>` : `<div class="inspector-sub">${esc(state.packageID)}</div>`}</div>`;
    if (mainView === "package") {
      html += `<section class="inspector-section identity-strip"><div class="identity-fields"><label>Title<input data-basic="packageTitle" data-focus-id="package-title" value="${esc(state.packageTitle)}"></label><label>System<input data-basic="consoleName" data-focus-id="console-name" value="${esc(state.consoleName)}"></label></div></section>`;
      html += renderPropertyEditor("Package Tags And Attachments", "gameMetadata", state.gameMetadataJSON);
      html += renderPropertyEditor("Package Extensions", "gameExtensions", state.gameExtensionsJSON);
      html += renderAttachments();
    } else if (mainView === "track") {
      if (member) {
        html += `<section class="track-tags-editor">${renderPropertyEditor("Track Tags", "memberMetadata", state.memberMetadataJSON)}${renderPropertyEditor("Track Extensions", "memberExtensions", state.memberExtensionsJSON)}</section>`;
      } else html += `<section class="inspector-section"><div class="empty-tab"><strong>Select a track</strong><span>Choose a row in Tracks to edit its tags.</span></div></section>`;
    } else if (mainView === "technical") html += renderTechnicalPage();
    else if (mainView === "schema") html += renderMetaTagsPage();
    else if (mainView === "tree") html += renderTree();
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

  function commitTreeEditor(root) {
    const object = {};
    for (const row of $$(".tree-entry", root)) {
      const key = $("[data-tree-key]", row)?.value.trim();
      if (!key) continue;
      if (Object.prototype.hasOwnProperty.call(object, key)) return;
      try {
        const valueInput = $("[data-tree-value]", row);
        object[key] = valueInput ? coerceValue(valueInput.value, row.dataset.treeKind) : JSON.parse(row.dataset.treeRaw || "null");
      } catch { return; }
    }
    const scope = root.dataset.treeScope;
    if (root.dataset.treeMember) bridge("selectMember", { path:root.dataset.treeMember });
    bridge(scopeToAction(scope), { value:JSON.stringify(object, null, 2) });
  }

  function addTreeField(root) {
    const list = $(".tree-entry-list", root);
    if (!list) return;
    const row = document.createElement("tr");
    row.className = "tree-entry";
    row.dataset.treeKind = "string";
    row.innerHTML = `<td><input data-tree-key placeholder="Field name" aria-label="Metadata key"></td><td><input data-tree-value placeholder="Value" aria-label="Metadata value"></td><td class="tree-type">text</td>`;
    list.append(row);
    $("[data-tree-key]", row).focus();
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

  document.addEventListener("click", event => {
    const action = event.target.closest("[data-action]")?.dataset.action;
    const packageItem = event.target.closest("[data-package]");
    const memberRow = event.target.closest("tr[data-member]");
    const trackRow = event.target.closest("tr[data-track-row]");
    const treeMember = event.target.closest("[data-tree-member]");
    if (packageItem) { bridge("selectPackage", { path:packageItem.dataset.package }); return; }
    if (treeMember) { mainView = "tree"; bridge("selectMember", { path:treeMember.dataset.treeMember }); render(state); return; }
    if (memberRow && !event.target.closest("input[type=checkbox]")) {
      mainView = "track";
      bridge("selectMember", { path:memberRow.dataset.member });
      render(state);
    }
    if (trackRow && !event.target.closest("input")) {
      const path = trackRow.dataset.trackRow;
      if (event.shiftKey && selectionAnchorPath) {
        const visible = visibleMembers().map(member => member.path), anchor = visible.indexOf(selectionAnchorPath), index = visible.indexOf(path), paths = new Set(state.selectedMemberPaths);
        if (anchor >= 0 && index >= 0) visible.slice(Math.min(anchor, index), Math.max(anchor, index) + 1).forEach(item => paths.add(item));
        bridge("selectMembers", { paths:[...paths] });
      } else if (event.metaKey || event.ctrlKey) {
        const paths = new Set(state.selectedMemberPaths); paths.has(path) ? paths.delete(path) : paths.add(path); bridge("selectMembers", { paths:[...paths] }); selectionAnchorPath = path;
      } else { mainView = "track"; bridge("selectMember", { path }); render(state); }
    }
    if (!action) return;
    if (action === "addField") addField(event.target.closest("[data-scope]").dataset.scope);
    else if (action === "addTreeField") addTreeField(event.target.closest("[data-tree-editor]"));
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
      if (key && window.confirm(`Delete ${key} everywhere in this package?`)) bridge("deleteMetadataKey", { key });
    }
    else if (action === "updateTagValue") {
      const row = event.target.closest("[data-tag-row]");
      if (row) bridge("updateMetadataValue", { key:row.dataset.tagFrom || "", value:$('[data-tag-value]', row)?.value || "" });
    }
    else if (action === "commitTagRow") {
      const row = event.target.closest("[data-tag-row]");
      if (row) bridge("commitMetadataRow", { key:row.dataset.tagFrom || "", newKey:$('[data-tag-to]', row)?.value || "", value:$('[data-tag-value]', row)?.disabled ? null : ($('[data-tag-value]', row)?.value || "") });
    }
    else if (action === "commitTechnicalRow") {
      const row = event.target.closest("[data-technical-row]");
      if (row) bridge("commitTechnicalRow", { scope:$('[data-tech-scope]', row)?.value || "", track:$('[data-tech-track]', row)?.value || "", key:row.dataset.techKey || "", newKey:$('[data-tech-key]', row)?.value || "", value:$('[data-tech-value]', row)?.value || "" });
    }
    else if (action === "deleteTechnicalRow") {
      const row = event.target.closest("[data-technical-row]");
      if (row && window.confirm(`Delete ${row.dataset.techKey || "this technical field"}?`)) bridge("deleteTechnicalRow", { scope:row.dataset.techScope || "", track:row.dataset.techTrack || "", key:row.dataset.techKey || "" });
    }
    else if (action === "removeField") {
      const row = event.target.closest(".field-row");
      const scope = row.closest("[data-editor]").dataset.editor;
      row.remove(); commitObjectEditor(scope);
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
    if (!form) return;
    event.preventDefault();
    bridge("addMetadataKey", { key:$('[data-new-tag-key]', form)?.value || "", scope:form.dataset.tagScope || "package", value:$('[data-new-tag-value]', form)?.value || "" });
  });

  document.addEventListener("change", event => {
    const target = event.target;
    if (target.matches("[data-select-all]")) {
      const visiblePaths = visibleMembers().map(member => member.path);
      const allVisible = visiblePaths.length > 0 && visiblePaths.every(path => state.selectedMemberPaths.includes(path));
      const paths = new Set(state.selectedMemberPaths);
      visiblePaths.forEach(path => allVisible ? paths.delete(path) : paths.add(path));
      bridge("selectMembers", { paths:[...paths] });
    } else if (target.matches("[data-select-member]")) bridge("toggleMember", { path:target.dataset.selectMember, selected:target.checked });
    else if (target.matches("[data-track-cell]")) commitTrackCell(target);
    else if (target.matches("[data-tree-value], [data-tree-key]")) commitTreeEditor(target.closest("[data-tree-editor]"));
    else if (target.matches("[data-basic='packageTitle']")) bridge("setPackageTitle", { value:target.value });
    else if (target.matches("[data-basic='consoleName']")) bridge("setConsole", { value:target.value });
    else if (target.matches("[data-raw-editor]")) {
      const scope = target.dataset.rawEditor;
      bridge(scopeToAction(scope), { value:target.value });
    } else if (target.closest("[data-editor]")) commitObjectEditor(target.closest("[data-editor]").dataset.editor);
  });

  document.addEventListener("input", event => {
    if (event.target.id === "collection-filter") renderCollections();
    else if (event.target.id === "member-filter") renderMembers();
  });
  document.addEventListener("click", event => {
    const header = event.target.closest("th[data-sort]");
    if (header) {
      const key = header.dataset.sort;
      if (sort.key === key) sort.direction *= -1; else sort = { key, direction:1 };
      renderMembers();
    }
  });
  document.addEventListener("keydown", event => {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "f") { event.preventDefault(); $("#collection-filter").focus(); }
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") { const field = $("#member-filter"); if (field) { event.preventDefault(); field.focus(); } }
    if (mainView === "members" && event.key === " " && document.activeElement?.closest("tr[data-track-row]")) { event.preventDefault(); const path = document.activeElement.closest("tr[data-track-row]").dataset.trackRow, paths = new Set(state.selectedMemberPaths); paths.has(path) ? paths.delete(path) : paths.add(path); bridge("selectMembers", { paths:[...paths] }); selectionAnchorPath = path; }
  });

  window.UACMan = { render };
})();
