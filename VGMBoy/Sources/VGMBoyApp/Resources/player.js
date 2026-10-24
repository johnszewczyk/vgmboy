'use strict';
(() => {
  const $ = id => document.getElementById(id);
  const send = (command, value) => window.webkit?.messageHandlers?.player?.postMessage({command, value: value ?? null});
  const formatTime = value => {
    const seconds = Math.max(0, Math.floor(Number(value) || 0));
    const minutes = Math.floor(seconds / 60);
    const remainder = String(seconds % 60).padStart(2, '0');
    return minutes >= 60
      ? String(Math.floor(minutes / 60)) + ':' + String(minutes % 60).padStart(2, '0') + ':' + remainder
      : String(minutes) + ':' + remainder;
  };
  const setText = (id, value) => {
    const node = $(id);
    const next = String(value ?? '');
    if (node && node.textContent !== next) node.textContent = next;
  };
  const setRangeFill = input => {
    const minimum = Number(input.min || 0);
    const maximum = Number(input.max || 1);
    const current = Number(input.value || 0);
    const percent = maximum > minimum ? (current - minimum) * 100 / (maximum - minimum) : 0;
    input.style.setProperty('--range-percent', Math.max(0, Math.min(100, percent)) + '%');
  };
  const setControl = (id, next) => {
    const input = $(id);
    if (!input || input === document.activeElement) return;
    if (input.type === 'checkbox') input.checked = Boolean(next);
    else input.value = String(next);
    if (input.type === 'range') setRangeFill(input);
  };
  const tabs = Array.from(document.querySelectorAll('[data-page]'));
  const pages = Array.from(document.querySelectorAll('[data-page-panel]'));
  let filesKey = '';
  let frequenciesKey = '';
  let formatsKey = '';

  tabs.forEach(tab => tab.addEventListener('click', () => {
    tabs.forEach(item => item.setAttribute('aria-selected', String(item === tab)));
    pages.forEach(page => { page.hidden = page.dataset.pagePanel !== tab.dataset.page; });
  }));

  document.addEventListener('click', event => {
    const button = event.target.closest('[data-command]');
    if (!button || button.disabled) return;
    const raw = button.dataset.value;
    const commandValue = raw === undefined ? null : Number(raw);
    send(button.dataset.command, commandValue);
  });

  document.addEventListener('input', event => {
    const input = event.target;
    if (!(input instanceof HTMLInputElement)) return;
    if (input.type === 'range') setRangeFill(input);
    if (input.dataset.control === 'volume') {
      setText('volume-label', Math.round(Number(input.value) * 100) + '%');
      send('volume', Number(input.value));
    }
    if (input.dataset.control === 'seek') {
      setText('clock', formatTime(input.value) + ' / ' + formatTime(input.max));
    }
    if (input.dataset.band !== undefined) {
      const gain = Number(input.value);
      input.nextElementSibling.textContent = (gain > 0 ? '+' : '') + gain.toFixed(1) + ' dB';
    }
  });

  document.addEventListener('change', event => {
    const input = event.target;
    if (!(input instanceof HTMLInputElement || input instanceof HTMLSelectElement)) return;
    const control = input.dataset.control;
    if (control === 'volume') return;
    if (control === 'seek') {
      send('seek', Number(input.value));
      return;
    }
    if (control) {
      if (input instanceof HTMLInputElement && input.type === 'number' && !input.checkValidity()) return;
      const next = input instanceof HTMLInputElement && input.type === 'checkbox'
        ? input.checked
        : Number(input.value);
      send(control, next);
    }
    if (input.dataset.band !== undefined) {
      send('eq', {band: Number(input.dataset.band), gain: Number(input.value)});
    }
    if (input.type === 'range' || input.type === 'number') input.blur();
  });

  document.addEventListener('keydown', event => {
    if (event.code === 'Space' && !event.target.closest('input,select,button,textarea')) {
      event.preventDefault();
      send('toggle');
    }
  });

  const renderFiles = items => {
    const list = $('files');
    const rows = items.map(file => {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'file-row';
      button.dataset.command = 'file';
      button.dataset.value = String(file.index);
      button.setAttribute('role', 'listitem');
      button.setAttribute('aria-current', String(Boolean(file.selected)));
      button.title = file.name;
      const index = document.createElement('span');
      index.className = 'file-index';
      index.textContent = String(file.index + 1).padStart(2, '0');
      const name = document.createElement('span');
      name.className = 'file-name';
      name.textContent = file.name;
      button.append(index, name);
      return button;
    });
    if (!items.length) {
      const empty = document.createElement('div');
      empty.className = 'empty-state';
      empty.append(document.createTextNode('Open or drop audio files and archives to start a local session.'));
      empty.append(document.createElement('br'));
      const shortcut = document.createElement('kbd');
      shortcut.textContent = '⌘ O';
      empty.append(shortcut, document.createTextNode(' to browse.'));
      rows.push(empty);
    }
    list.replaceChildren(...rows);
    setText('file-count', String(items.length).padStart(2, '0'));
  };

  const renderBands = frequencies => {
    $('equalizer').replaceChildren(...frequencies.map((frequency, band) => {
      const row = document.createElement('div');
      row.className = 'eq-row';
      const label = document.createElement('label');
      label.htmlFor = 'band-' + band;
      label.textContent = frequency >= 1000 ? (frequency / 1000) + ' kHz' : frequency + ' Hz';
      const slider = document.createElement('input');
      slider.id = 'band-' + band;
      slider.className = 'range';
      slider.type = 'range';
      slider.min = '-12';
      slider.max = '12';
      slider.step = '0.5';
      slider.dataset.band = String(band);
      slider.setAttribute('aria-label', frequency + ' Hz gain');
      const output = document.createElement('output');
      output.textContent = '0.0 dB';
      row.append(label, slider, output);
      return row;
    }));
  };

  const renderFormats = formats => {
    $('format-list').replaceChildren(...formats.map(format => {
      const row = document.createElement('div');
      row.className = 'format-row';
      const name = document.createElement('strong');
      name.textContent = format.family;
      const extensions = document.createElement('p');
      extensions.textContent = format.extensions || 'Amiga replayer prefixes';
      const details = document.createElement('small');
      details.textContent = [
        format.tempo ? 'Tempo' : 'Native speed',
        format.longPlay ? 'Long Play' : 'Natural ending'
      ].join(' · ');
      row.append(name, extensions, details);
      return row;
    }));
  };

  window.vgm = Object.freeze({
    render(state) {
      setText('title-file', state.loaded ? state.file : 'No file open');
      setText('family-tag', state.loaded ? state.family : 'LOCAL');
      setText('filename', state.file);
      setText('path', state.path);
      setText('play-state', state.playing ? 'PLAYING' : state.ended ? 'ENDED' : state.loaded ? 'PAUSED' : 'READY');

      const play = $('play');
      play.classList.toggle('is-playing', Boolean(state.playing));
      play.setAttribute('aria-label', state.playing ? 'Pause' : 'Play');
      play.title = state.playing ? 'Pause' : 'Play';

      const duration = state.loaded ? Math.max(0, Number(state.window) || 0) : 0;
      $('position').max = String(Math.max(1, duration));
      setControl('position', state.elapsed);
      setText('clock', formatTime(state.elapsed) + ' / ' + formatTime(duration));

      document.querySelectorAll('[data-loaded]').forEach(control => { control.disabled = !state.loaded; });
      setControl('track', state.track);
      setControl('longPlay', state.longPlay);
      setControl('length', state.length);
      setControl('fade', state.fade);
      setControl('tempo', state.tempo);
      setControl('mono', state.mono);
      setControl('volume', state.volume);
      setControl('eqEnabled', state.eqEnabled);
      $('longPlay').disabled = !state.loaded || !state.supportsLongPlay;
      $('tempo').disabled = !state.loaded || !state.supportsTempo;

      const error = $('error');
      error.hidden = !state.error;
      error.querySelector('span').textContent = state.error || '';

      const selectedIndex = state.files.findIndex(file => file.selected);
      const previous = document.querySelector('[data-command="previous"]');
      const next = document.querySelector('[data-command="next"]');
      previous.disabled = !state.loaded || selectedIndex <= 0;
      next.disabled = !state.loaded || selectedIndex < 0 || selectedIndex >= state.files.length - 1;

      const nextFilesKey = JSON.stringify(state.files.map(file => [file.index, file.name, file.selected]));
      if (nextFilesKey !== filesKey) {
        filesKey = nextFilesKey;
        renderFiles(state.files);
      }

      const nextFrequenciesKey = JSON.stringify(state.frequencies);
      if (nextFrequenciesKey !== frequenciesKey) {
        frequenciesKey = nextFrequenciesKey;
        renderBands(state.frequencies);
      }
      state.gains.forEach((gain, band) => {
        const slider = $('band-' + band);
        if (!slider) return;
        setControl(slider.id, gain);
        slider.disabled = !state.eqEnabled;
        const display = (gain > 0 ? '+' : '') + Number(gain).toFixed(1) + ' dB';
        if (slider !== document.activeElement && slider.nextElementSibling.textContent !== display) {
          slider.nextElementSibling.textContent = display;
        }
      });

      const nextFormatsKey = JSON.stringify(state.formats.map(format => [format.family, format.extensions, format.tempo, format.longPlay]));
      if (nextFormatsKey !== formatsKey) {
        formatsKey = nextFormatsKey;
        renderFormats(state.formats);
      }

      const diagnostics = state.diagnostics;
      $('buffer').max = String(Math.max(1, diagnostics.capacity));
      $('buffer').value = String(diagnostics.buffered);
      setText('buffer-label', diagnostics.buffered.toLocaleString() + ' / ' + diagnostics.capacity.toLocaleString() + ' frames');
      const metrics = {
        'Output device': diagnostics.running ? 'Running' : 'Idle',
        'Output rate': diagnostics.rate.toLocaleString() + ' Hz',
        'Decoder rate': diagnostics.decoderRate.toLocaleString() + ' Hz',
        'Underruns': diagnostics.underruns.toLocaleString(),
        'Frames supplied': diagnostics.supplied.toLocaleString(),
        'Frames requested': diagnostics.requested.toLocaleString(),
        'Decoded frames': diagnostics.decoded.toLocaleString(),
        'Audible frames': diagnostics.positionFrames.toLocaleString(),
        'Generation': diagnostics.generation.toLocaleString()
      };
      if (!$('metrics').children.length) {
        Object.keys(metrics).forEach(name => {
          const term = document.createElement('dt');
          term.textContent = name;
          $('metrics').append(term, document.createElement('dd'));
        });
      }
      Object.values(metrics).forEach((metric, index) => {
        const node = $('metrics').children[index * 2 + 1];
        if (node.textContent !== String(metric)) node.textContent = String(metric);
      });
    }
  });

  send('ready');
})();
