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
  window.SBPresentation = Object.freeze({ columns, mergeOrder });
})();
