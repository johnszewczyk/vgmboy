"use strict";

const indexes = new Map();
const SEARCH_BATCH_SIZE = 768;

function normalizeQuery(value) {
  return String(value || "").trim().toLowerCase().split(/\s+/).filter(Boolean).join(" ");
}

function nextTask() {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

function beginSearch(index, message) {
  const searchGeneration = ++index.searchGeneration;
  const request = {
    revision: message.revision,
    requestID: message.requestID,
    query: normalizeQuery(message.query)
  };
  if (!index.complete) {
    index.pendingSearch = request;
    return;
  }
  void search(index, request, searchGeneration);
}

async function search(index, request, searchGeneration) {
  const terms = request.query ? request.query.split(" ") : [];
  const candidates = index.matches && request.query.startsWith(index.query)
    ? index.matches
    : index.records;
  const matches = [];
  const consoleCounts = new Map();

  for (let offset = 0; offset < candidates.length; offset += SEARCH_BATCH_SIZE) {
    if (index.searchGeneration !== searchGeneration || index.revision !== request.revision) return;
    const end = Math.min(candidates.length, offset + SEARCH_BATCH_SIZE);
    for (let candidateIndex = offset; candidateIndex < end; candidateIndex += 1) {
      const record = candidates[candidateIndex];
      if (!terms.every((term) => record.searchText.includes(term))) continue;
      matches.push(record);
      if (record.consoleName) {
        consoleCounts.set(record.consoleName, (consoleCounts.get(record.consoleName) || 0) + 1);
      }
    }
    if (end < candidates.length) await nextTask();
  }

  if (index.searchGeneration !== searchGeneration || index.revision !== request.revision) return;
  index.query = request.query;
  index.matches = matches;
  self.postMessage({
    type: "results",
    scope: index.scope,
    revision: request.revision,
    requestID: request.requestID,
    ids: matches.map((record) => record.id),
    consoleCounts: [...consoleCounts]
  });
}

self.addEventListener("message", (event) => {
  const message = event.data || {};
  const scope = String(message.scope || "catalog");
  if (message.type === "index-start") {
    const previous = indexes.get(scope);
    indexes.set(scope, {
      scope,
      revision: message.revision,
      records: [],
      complete: false,
      query: "",
      matches: null,
      searchGeneration: (previous?.searchGeneration || 0) + 1,
      pendingSearch: null
    });
    return;
  }

  const index = indexes.get(scope);
  if (!index || index.revision !== message.revision) return;

  if (message.type === "index-batch") {
    if (Array.isArray(message.records)) index.records.push(...message.records);
    return;
  }

  if (message.type === "index-complete") {
    index.complete = true;
    self.postMessage({ type: "ready", scope, revision: index.revision });
    if (index.pendingSearch) {
      const pending = index.pendingSearch;
      index.pendingSearch = null;
      beginSearch(index, pending);
    }
    return;
  }

  if (message.type === "search") {
    beginSearch(index, message);
  }
});
