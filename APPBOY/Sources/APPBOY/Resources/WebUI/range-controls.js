/* Shared native-range enhancement and fill-position math for WebKit frontends. */
(() => {
  const SELECTOR = 'input[type="range"][data-vgm-range-slider], .range-slider > input[type="range"]';
  const clamp = value => Math.max(0, Math.min(100, value));
  const boundsFor = input => ({
    minimum: input.min === '' ? 0 : Number(input.min),
    maximum: input.max === '' ? 100 : Number(input.max)
  });
  const percentFor = input => {
    const { minimum, maximum } = boundsFor(input);
    const value = Number.isFinite(Number(input.value)) ? Number(input.value) : minimum;
    return maximum > minimum ? clamp((value - minimum) * 100 / (maximum - minimum)) : 0;
  };

  function setPercent(input, percent) {
    if (!(input instanceof HTMLInputElement) || input.type !== 'range') return false;
    const target = input.closest('.range-slider') || input;
    const value = clamp(Number(percent) || 0);
    target.style.setProperty('--range-percent', `${value.toFixed(2)}%`);
    return true;
  }

  function sync(input) {
    if (!(input instanceof HTMLInputElement) || input.type !== 'range') return false;
    const { minimum, maximum } = boundsFor(input);
    setPercent(input, percentFor(input));
    const zero = input.closest('.range-slider')?.querySelector('.range-slider-zero');
    if (zero && maximum > minimum) {
      const zeroPercent = clamp((0 - minimum) * 100 / (maximum - minimum));
      zero.style.left = `${zeroPercent.toFixed(2)}%`;
      zero.hidden = minimum > 0 || maximum < 0;
    }
    return true;
  }

  function enhance(root = document) {
    const inputs = [];
    if (root instanceof HTMLInputElement && root.matches(SELECTOR)) inputs.push(root);
    root.querySelectorAll?.(SELECTOR).forEach(input => inputs.push(input));
    for (const input of inputs) {
      let shell = input.closest('.range-slider');
      if (!shell) {
        shell = document.createElement('span');
        shell.className = 'range-slider';
        input.before(shell);
        shell.append(input);
      }
      if (!shell.querySelector('.range-slider-track')) {
        const track = document.createElement('span');
        track.className = 'range-slider-track';
        track.setAttribute('aria-hidden', 'true');
        const fill = document.createElement('span');
        fill.className = 'range-slider-fill';
        const thumb = document.createElement('span');
        thumb.className = 'range-slider-thumb';
        track.append(fill, thumb);
        shell.append(track);
      }
      if (input.hasAttribute('data-vgm-range-zero') && !shell.querySelector('.range-slider-zero')) {
        const zero = document.createElement('span');
        zero.className = 'range-slider-zero';
        zero.setAttribute('aria-hidden', 'true');
        shell.querySelector('.range-slider-track')?.prepend(zero);
      }
      if (input.dataset.vgmRangeControlBound !== 'true') {
        input.addEventListener('input', () => sync(input));
        input.addEventListener('change', () => sync(input));
        input.dataset.vgmRangeControlBound = 'true';
      }
      sync(input);
    }
    return inputs;
  }

  window.VGMRangeControls = Object.freeze({ enhance, setPercent, sync });
  enhance(document);
})();
