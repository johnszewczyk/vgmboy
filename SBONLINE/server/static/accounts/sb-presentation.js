/* Portable presentation only: no catalogs, playback, accounts, or preferences. */
(() => {
  function animateMove(element, before) {
    element.getAnimations().forEach(animation => animation.cancel());
    const delta = before.left - element.getBoundingClientRect().left;
    const style = getComputedStyle(element);
    const duration = parseFloat(style.getPropertyValue('--sb-motion-duration')) || 0;
    if (Math.abs(delta) > .5 && duration && document.body.dataset.sbMotion !== 'off' && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
      element.animate([{ transform: `translateX(${delta}px)` }, { transform: 'translateX(0)' }], {
        duration, easing: style.getPropertyValue('--sb-motion-ease').trim() || 'cubic-bezier(.2,0,0,1)'
      });
    }
  }
  // Use rendered text metrics: canvas alone misses transforms and font features.
  const textWidths = new Map();
  let textProbe;
  document.fonts?.addEventListener('loadingdone', () => textWidths.clear());
  function measureTexts(values, style) {
    const properties = ['fontFamily', 'fontSize', 'fontWeight', 'fontStyle', 'fontStretch',
      'fontVariant', 'fontVariantLigatures', 'fontVariantNumeric', 'fontKerning',
      'fontFeatureSettings', 'fontVariationSettings', 'letterSpacing', 'textTransform'];
    const typography = properties.map(property => style?.[property] || '');
    const prefix = JSON.stringify(typography);
    const entries = [...new Set(Array.from(values, value => String(value ?? '')))];
    const result = new Map(entries.flatMap(value => {
      const key = JSON.stringify([prefix, value]);
      return textWidths.has(key) ? [[value, textWidths.get(key)]] : [];
    }));
    const missing = entries.filter(value => !result.has(value));
    if (missing.length) {
      if (!textProbe) {
        textProbe = document.createElement('div');
        Object.assign(textProbe.style, { position: 'fixed', left: '-100000px', top: '0',
          visibility: 'hidden', pointerEvents: 'none', width: 'max-content',
          maxWidth: 'none', whiteSpace: 'pre', padding: '0', border: '0', lineHeight: 'normal' });
        textProbe.setAttribute('aria-hidden', 'true');
        document.body.append(textProbe);
      }
      properties.forEach((property, index) => { textProbe.style[property] = typography[index]; });
      // Bound temporary DOM even for a large local playlist without catalog hints.
      for (let start = 0; start < missing.length; start += 256) {
        const batch = missing.slice(start, start + 256);
        const probes = batch.map(value => {
          const span = document.createElement('div');
          span.style.width = 'max-content';
          span.textContent = value;
          return span;
        });
        textProbe.replaceChildren(...probes);
        const measured = probes.map(probe => probe.getBoundingClientRect().width);
        batch.forEach((value, index) => {
          result.set(value, measured[index]);
          if (textWidths.size >= 4096) textWidths.delete(textWidths.keys().next().value);
          textWidths.set(JSON.stringify([prefix, value]), measured[index]);
        });
      }
      textProbe.replaceChildren();
    }
    let maximum = 0;
    for (const value of entries) maximum = Math.max(maximum, result.get(value) || 0);
    return maximum;
  }
  const measureText = (value, style) => measureTexts([value], style);
  function columns(container, { selector, key, preview, commit }) {
    let dragged = null, original = [], changed = false, lastDrag = 0;
    const cells = () => [...container.querySelectorAll(selector)];
    const order = () => cells().map(key);
    function move(target, after) {
      if (!dragged || target === dragged || !target.draggable) return;
      const before = new Map(cells().map(cell => [cell, cell.getBoundingClientRect()]));
      const next = after ? target.nextSibling : target;
      if (next === dragged || dragged.nextSibling === next) return;
      container.insertBefore(dragged, next);
      changed = true;
      preview(order());
      for (const cell of cells()) if (cell !== dragged) animateMove(cell, before.get(cell));
    }
    function finish(accepted) {
      if (!dragged) return;
      if (!accepted && changed) {
        for (const id of original) container.append(cells().find(cell => key(cell) === id));
        preview(original);
      }
      dragged.classList.remove('sb-column-dragging');
      dragged = null;
      lastDrag = Date.now();
      if (accepted && changed) commit(order());
    }
    container.addEventListener('dragstart', event => {
      const cell = event.target.closest(selector);
      if (!cell?.draggable || event.target.closest('.column-resize-handle,.sb-column-handle')) return;
      dragged = cell; original = order(); changed = false;
      cell.classList.add('sb-column-dragging');
      event.dataTransfer.effectAllowed = 'move';
      event.dataTransfer.setData('text/plain', key(cell));
    });
    container.addEventListener('dragover', event => {
      if (!dragged) return;
      event.preventDefault();
      const target = event.target.closest(selector);
      if (!target) return;
      const rect = target.getBoundingClientRect();
      move(target, event.clientX > rect.left + rect.width / 2);
    });
    container.addEventListener('drop', event => { if (dragged) { event.preventDefault(); finish(true); } });
    container.addEventListener('dragend', () => finish(false));
    return { recentlyDragged: () => dragged !== null || Date.now() - lastDrag < 250 };
  }
  function mergeOrder(all, visible) {
    const set = new Set(visible); let index = 0;
    return all.map(id => set.has(id) ? visible[index++] : id);
  }
  window.SBPresentation = Object.freeze({ columns, mergeOrder, measureText, measureTexts });
})();
