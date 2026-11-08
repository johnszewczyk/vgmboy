/* Site-wide SB2 presentation preferences and one clipped selection surface. */
(() => {
  if (window.SBInterface) return;
  const defaults = { playlistFontSize: 13, sidebarFontSize: 13, rowGap: 0, motionEnabled: true, motionDuration: 200 };
  const storage = window.SBOProfileStorage;
  const preferences = { ...defaults };
  for (const [name, min, max] of [['playlistFontSize',10,20],['sidebarFontSize',10,20],['rowGap',0,32],['motionDuration',0,600]]) {
    const value = storage?.get('interface', name, defaults[name]);
    if (Number.isInteger(value)) preferences[name] = Math.max(min, Math.min(max, value));
  }
  const savedMotion = storage?.get('interface', 'motionEnabled', defaults.motionEnabled);
  if (typeof savedMotion === 'boolean') preferences.motionEnabled = savedMotion;
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
  function apply() {
    document.body.style.setProperty('--sb-playlist-font-size', `${preferences.playlistFontSize}px`);
    document.body.style.setProperty('--sb-sidebar-font-size', `${preferences.sidebarFontSize}px`);
    document.body.style.setProperty('--sb-row-gap', `${preferences.rowGap}px`);
    document.body.dataset.sbMotion = preferences.motionEnabled && !reducedMotion.matches ? 'on' : 'off';
    document.body.style.setProperty('--site-motion-duration', `${preferences.motionEnabled && !reducedMotion.matches ? preferences.motionDuration : 0}ms`);
    for (const control of document.querySelectorAll('[data-sb-preference]')) {
      const value = preferences[control.dataset.sbPreference];
      if (control.type === 'checkbox') control.checked = value;
      else if (control.getAttribute('role') === 'switch') {
        control.setAttribute('aria-checked', String(value));
        control.textContent = value ? 'Yes' : 'No';
        control.classList.toggle('is-enabled', Boolean(value));
      } else control.value = String(value);
    }
    document.dispatchEvent(new Event('sb:interface-changed'));
  }
  document.addEventListener('change', event => {
    const control = event.target.closest('[data-sb-preference]');
    if (!control) return;
    const name = control.dataset.sbPreference;
    const value = control.type === 'checkbox' ? control.checked : Number(control.value);
    if (!(name in defaults)) return;
    if (typeof defaults[name] === 'number' && (!Number.isInteger(value) || value < Number(control.min) || value > Number(control.max))) { apply(); return; }
    preferences[name] = value;
    storage?.set('interface', name, value);
    apply();
  });
  document.addEventListener('click', event => {
    const control = event.target.closest('[data-sb-preference][role="switch"]');
    if (!control) return;
    const name = control.dataset.sbPreference;
    if (!(name in defaults) || typeof defaults[name] !== 'boolean') return;
    const value = control.getAttribute('aria-checked') !== 'true';
    preferences[name] = value;
    storage?.set('interface', name, value);
    apply();
  });
  const marker = document.createElement('span');
  marker.className = 'sb-selection';
  marker.setAttribute('aria-hidden','true');
  document.body.append(marker);
  const selector = 'button:not(:disabled):not(.mobile-nav-scrim):not(.site-player-drawer-scrim), .spcboy-system > summary, .spcboy-game > summary, .topnav a, .spcboy-search-wrap, .profile-tabs a';
  let target = null;
  let logicalTarget = null;
  let frame = 0;
  function setTarget(next) {
    target?.classList.remove('sb-selection-current');
    target = next;
    target?.classList.add('sb-selection-current');
    schedule();
  }
  function position(instant = false) {
    frame = 0;
    if (!target?.isConnected || !target.getClientRects().length || target.closest('[inert],[hidden]')) { marker.classList.remove('is-ready'); return; }
    const rect = target.getBoundingClientRect();
    let left = Math.max(0,rect.left), top = Math.max(0,rect.top), right = Math.min(innerWidth,rect.right), bottom = Math.min(innerHeight,rect.bottom);
    for (let parent = target.parentElement; parent; parent = parent.parentElement) {
      const style = getComputedStyle(parent), clip = parent.getBoundingClientRect();
      if (/(auto|scroll|hidden|clip)/.test(style.overflowX)) { left = Math.max(left,clip.left); right = Math.min(right,clip.right); }
      if (/(auto|scroll|hidden|clip)/.test(style.overflowY)) { top = Math.max(top,clip.top); bottom = Math.min(bottom,clip.bottom); }
    }
    if (right <= left || bottom <= top) { marker.classList.remove('is-ready'); return; }
    marker.classList.toggle('is-instant', instant || !marker.classList.contains('is-ready'));
    marker.style.width = `${right-left}px`;
    marker.style.height = `${bottom-top}px`;
    marker.style.borderRadius = getComputedStyle(target).borderRadius;
    marker.style.transform = `translate3d(${left}px,${top}px,0)`;
    marker.classList.add('is-ready');
  }
  function schedule() { if (!frame) frame = requestAnimationFrame(() => position()); }
  document.addEventListener('pointerover', event => {
    if (event.pointerType === 'touch') return;
    const next = event.target.closest(selector);
    if (next !== target) setTarget(next);
  });
  document.addEventListener('pointerout', event => {
    if (!event.relatedTarget || !event.relatedTarget.closest?.(selector)) setTarget(logicalTarget);
  });
  document.addEventListener('focusin', event => {
    const next = event.target.closest(selector);
    logicalTarget = next;
    setTarget(next);
  });
  document.addEventListener('click', event => {
    const next = event.target.closest(selector);
    logicalTarget = next;
    setTarget(next);
  });
  document.addEventListener('scroll', () => position(true), { capture: true, passive: true });
  window.addEventListener('resize', () => position(true), { passive: true });
  document.addEventListener('site:pageleave', () => {
    if (logicalTarget?.matches('.topnav a[data-nav-key]')) {
      setTarget(logicalTarget);
      return;
    }
    logicalTarget = null;
    setTarget(null);
  });
  document.addEventListener('site:navigated', () => {
    apply();
    const currentLink = document.querySelector('.topnav a[data-nav-key][aria-current="page"]');
    if (!currentLink) return;
    logicalTarget = currentLink;
    setTarget(currentLink);
  });
  document.addEventListener('sb:interface-changed', schedule);
  reducedMotion.addEventListener('change', apply);
  window.SBInterface = { duration: () => preferences.motionEnabled && !reducedMotion.matches ? preferences.motionDuration : 0 };
  apply();
  const initialPageLink = document.querySelector('.topnav a[data-nav-key][aria-current="page"]');
  if (initialPageLink) {
    logicalTarget = initialPageLink;
    setTarget(initialPageLink);
  }
})();
