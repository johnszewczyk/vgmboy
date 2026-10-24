'use strict';
(() => {
  const $ = id => document.getElementById(id);
  const send = (command, value) => window.webkit?.messageHandlers.player.postMessage({command, value: value ?? null});
  const time = seconds => `${Math.floor(seconds / 60)}:${String(Math.floor(seconds % 60)).padStart(2, '0')}`;
  let sessionKey = '', frequenciesKey = '', formatsKey = '';
  function text(id, value) {
    const node = $(id), next = String(value);
    if (node.textContent !== next) node.textContent = next;
  }
  function fill(input) {
    const percent = 100 * (Number(input.value) - Number(input.min || 0)) / (Number(input.max || 1) - Number(input.min || 0));
    input.style.setProperty('--fill', `${Math.max(0, Math.min(100, percent))}%`);
  }
  function value(id, next) {
    const input = $(id);
    if (input === document.activeElement) return;
    if (input.type === 'checkbox') input.checked = Boolean(next);
    else input.value = String(next);
    if (input.type === 'range') fill(input);
  }
  document.querySelectorAll('[data-page]').forEach(button => button.addEventListener('click', () => {
    document.querySelectorAll('[data-page]').forEach(item => item.removeAttribute('aria-current'));
    button.setAttribute('aria-current', 'page');
    document.querySelectorAll('.page').forEach(page => { page.hidden = page.id !== button.dataset.page; });
    text('page-title', button.textContent.replace(/\d+/g, '').trim());
  }));
  document.addEventListener('click', event => {
    const button = event.target.closest('[data-command]');
    if (button && !button.disabled) send(button.dataset.command, button.dataset.value === undefined ? null : Number(button.dataset.value));
  });
  document.addEventListener('input', event => {
    const input = event.target;
    if (input.type === 'range') fill(input);
    if (input.dataset.control === 'volume') {
      text('volume-label', `${Math.round(input.value * 100)}%`);
      send('volume', Number(input.value));
    }
    if (input.dataset.band !== undefined) input.nextElementSibling.textContent = `${Number(input.value) > 0 ? '+' : ''}${Number(input.value).toFixed(1)}`;
  });
  document.addEventListener('change', event => {
    const input = event.target;
    if (input.dataset.control && input.dataset.control !== 'volume') {
      if (input.type === 'number' && !input.checkValidity()) return;
      send(input.dataset.control, input.type === 'checkbox' ? input.checked : Number(input.value));
    }
    if (input.dataset.band !== undefined) send('eq', {band: Number(input.dataset.band), gain: Number(input.value)});
    // Let authoritative native state update the control after an edit commits.
    if (input.type === 'range' || input.type === 'number') input.blur();
  });
  document.addEventListener('keydown', event => {
    if (event.code === 'Space' && !event.target.closest('input,select,button,textarea')) {
      event.preventDefault(); send('toggle');
    }
  });
  window.vgm = Object.freeze({render(state) {
    text('filename', state.file); text('path', state.path);
    text('family', state.family);
    text('play-state', state.playing ? 'PLAYING' : state.ended ? 'ENDED' : state.loaded ? 'PAUSED' : 'READY');
    text('play', state.playing ? 'Ⅱ' : '▶'); $('play').setAttribute('aria-label', state.playing ? 'Pause' : 'Play');
    text('clock', time(state.elapsed));
    $('position').max = state.window; value('position', state.elapsed);
    document.querySelectorAll('[data-loaded]').forEach(input => { input.disabled = !state.loaded; });
    for (const [id,key] of Object.entries({track:'track', longPlay:'longPlay', length:'length', fade:'fade', tempo:'tempo', mono:'mono', volume:'volume', eqEnabled:'eqEnabled'})) value(id, state[key]);
    $('longPlay').disabled = !state.loaded || !state.supportsLongPlay;
    $('tempo').disabled = !state.loaded || !state.supportsTempo;
    text('tempo-note', state.supportsTempo ? 'Tempo is applied by the native decoder.' : 'This decoder uses native playback speed.');
    text('volume-label', `${Math.round(state.volume * 100)}%`);
    $('error').hidden = !state.error; $('error').querySelector('span').textContent = state.error;
    const selectedFile = state.files.findIndex(file => file.selected);
    document.querySelector('[data-command="previous"]').disabled = selectedFile <= 0;
    document.querySelector('[data-command="next"]').disabled = selectedFile < 0 || selectedFile >= state.files.length - 1;
    const key = JSON.stringify(state.files.map(file => [file.index,file.name,file.selected]));
    if (key !== sessionKey) {
      sessionKey = key;
      $('files').replaceChildren(...state.files.map(file => {
        const button = document.createElement('button'); button.dataset.command = 'file'; button.dataset.value = file.index;
        button.setAttribute('role','listitem'); button.title = file.name;
        if (file.selected) button.setAttribute('aria-current','true');
        const index = document.createElement('small'); index.textContent = String(file.index + 1).padStart(2,'0');
        const label = document.createElement('span'); label.textContent = file.name;
        button.append(index,label); return button;
      }));
      $('empty').hidden = state.files.length > 0;
    }
    const frequencies = JSON.stringify(state.frequencies);
    if (frequenciesKey !== frequencies) {
      frequenciesKey = frequencies;
      $('equalizer').replaceChildren(...state.frequencies.map((frequency,band) => {
        const row = document.createElement('div'); row.className = 'eq-row';
        const label = document.createElement('label'); label.htmlFor = `band-${band}`; label.textContent = frequency >= 1000 ? `${frequency / 1000}k` : frequency;
        const slider = document.createElement('input'); slider.id = `band-${band}`; slider.type='range'; slider.min=-12; slider.max=12; slider.step=.5; slider.dataset.band=band; slider.setAttribute('aria-label',`${frequency} Hz gain`);
        row.append(label,slider,document.createElement('output')); return row;
      }));
    }
    state.gains.forEach((gain,band) => {
      value(`band-${band}`,gain); const slider = $(`band-${band}`); slider.disabled = !state.eqEnabled;
      const display = `${gain > 0 ? '+' : ''}${gain.toFixed(1)}`;
      if (slider !== document.activeElement && slider.nextElementSibling.textContent !== display) slider.nextElementSibling.textContent = display;
    });
    const formats = JSON.stringify(state.formats.map(format => [format.family,format.extensions,format.tempo,format.longPlay]));
    if (formats !== formatsKey) {
      formatsKey = formats;
      $('format-list').replaceChildren(...state.formats.map(format => {
        const row = document.createElement('div'); row.className = 'format-row';
        const title = document.createElement('strong'); title.textContent = format.family;
        const extensions = document.createElement('p'); extensions.textContent = format.extensions || 'Amiga replayer prefixes';
        const capabilities = document.createElement('small'); capabilities.textContent = [format.tempo ? 'Tempo' : 'Native speed',format.longPlay ? 'Long Play' : 'Natural ending'].join(' · ');
        row.append(title,extensions,capabilities); return row;
      }));
    }
    const d = state.diagnostics;
    $('buffer').max = Math.max(1,d.capacity); $('buffer').value = d.buffered;
    text('buffer-label', `${d.buffered.toLocaleString()} / ${d.capacity.toLocaleString()} frames`);
    const metrics = {'Output device':d.running ? 'Running' : 'Idle','Output rate':`${d.rate.toLocaleString()} Hz`,'Decoder rate':`${d.decoderRate.toLocaleString()} Hz`,'Underruns':d.underruns,'Frames supplied':d.supplied,'Frames requested':d.requested,'Decoded frames':d.decoded,'Audible frames':d.positionFrames,'Generation':d.generation};
    // Fixed metric nodes avoid replacing focused controls or the whole page per tick.
    if (!$('metrics').children.length) Object.keys(metrics).forEach(name => { const term=document.createElement('dt');term.textContent=name;$('metrics').append(term,document.createElement('dd')); });
    Object.values(metrics).forEach((metric,index) => {
      const node = $('metrics').children[index*2+1];
      if (node.textContent !== String(metric)) node.textContent = String(metric);
    });
  }});
  send('ready');
})();
