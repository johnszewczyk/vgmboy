(() => {
  // Each WebView owns its pending edits; native code owns the merged document.
  function create({ snapshot, send }) {
    let baseline = null;
    let revision = 0;
    let chain = Promise.resolve();
    const pending = new Map();
    const copy = (value) => JSON.parse(JSON.stringify(value));
    const equal = (left, right) => JSON.stringify(left) === JSON.stringify(right);

    function initialize() { baseline = copy(snapshot()); }

    function save() {
      if (!baseline) return chain; // Never replace saved state with startup defaults.
      const current = copy(snapshot());
      const patch = Object.fromEntries(Object.entries(current)
        .filter(([key, value]) => !equal(value, baseline[key])));
      if (!Object.keys(patch).length) return chain;
      const token = ++revision;
      for (const [key, value] of Object.entries(patch)) {
        baseline[key] = value;
        pending.set(key, { token, value });
      }
      const operation = chain.catch(() => {}).then(() => send(patch));
      chain = operation.then(() => {
        for (const key of Object.keys(patch)) {
          if (pending.get(key)?.token === token) pending.delete(key);
        }
      }, (error) => {
        for (const key of Object.keys(patch)) {
          if (pending.get(key)?.token !== token) continue;
          pending.delete(key);
          delete baseline[key]; // The next save retries the failed fields.
        }
        throw error;
      });
      void chain.catch((error) => console.error('[SPCBoy] settings save failed', error));
      return chain;
    }

    function accept(patch) {
      if (!patch || typeof patch !== 'object') return {};
      const accepted = {};
      const current = snapshot();
      for (const [key, value] of Object.entries(patch)) {
        if (!Object.hasOwn(current, key)) continue;
        const edit = pending.get(key);
        if (edit && !equal(edit.value, value)) continue;
        // Preserve an in-progress local preview until its change event commits.
        if (!edit && baseline && Object.hasOwn(current, key)
            && !equal(current[key], baseline[key]) && !equal(current[key], value)) continue;
        if (!equal(current[key], value)) accepted[key] = value;
        if (baseline && Object.hasOwn(current, key)) baseline[key] = copy(value);
      }
      return accepted;
    }

    function applied(patch) {
      if (!baseline) return;
      const normalized = snapshot();
      for (const key of Object.keys(patch)) {
        if (Object.hasOwn(normalized, key)) baseline[key] = copy(normalized[key]);
      }
    }

    async function flush() {
      for (;;) {
        const operation = save();
        await operation;
        if (operation === chain) return;
      }
    }
    return Object.freeze({ initialize, save, accept, applied, flush });
  }
  window.SB2SettingsPersistence = Object.freeze({ create });
})();
