"use strict";

const indexes = new Map();

function normalizeQuery(value) {
  return String(value || "").trim().toLowerCase().split(/\s+/).filter(Boolean).join(" ");
}

self.addEventListener("message", (event) => {
  const message = event.data || {};
  if (message.type === "index") {
    const scope = String(message.scope || "catalog");
    const records = Array.isArray(message.records) ? message.records : [];
    indexes.set(scope, { records, query: "", matches: null });
    self.postMessage({ type: "ready", scope });
    return;
  }
  if (message.type !== "search") return;

  const scope = String(message.scope || "catalog");
  const index = indexes.get(scope);
  if (!index) {
    self.postMessage({ type: "results", scope, requestID: message.requestID, ids: [] });
    return;
  }

  const query = normalizeQuery(message.query);
  const terms = query ? query.split(" ") : [];
  const candidates = index.matches && query.startsWith(index.query)
    ? index.matches
    : index.records;
  const matches = [];
  for (const record of candidates) {
    if (terms.every((term) => record.searchText.includes(term))) matches.push(record);
  }
  index.query = query;
  index.matches = matches;
  self.postMessage({
    type: "results",
    scope,
    requestID: message.requestID,
    ids: matches.map((record) => record.id)
  });
});
