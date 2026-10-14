import assert from 'node:assert/strict';
import test from 'node:test';

const listeners = new Map();
const canvas = {
  style: {}, focus() {}, addEventListener: (name, callback) => listeners.set(name, callback),
  getBoundingClientRect: () => ({ left: 0, top: 0, width: parseFloat(canvas.style.width), height: parseFloat(canvas.style.height) }),
  getContext: () => ({
    createImageData: (width, height) => ({ width, height, data: new Uint8ClampedArray(width * height * 4) }),
    putImageData: (image) => { canvas.image = image; },
  }),
};
const status = {};
const options = new Map();
const savedNativePreferences = [];
let windowWidth = 1200;
const windowListeners = new Map();
globalThis.window = globalThis;
globalThis.devicePixelRatio = 2;
globalThis.addEventListener = (name, callback) => windowListeners.set(name, callback);
globalThis.document = {
  documentElement: { dataset: {}, style: { setProperty() {} } },
  querySelector: (name) => name === '#lcd' ? canvas : name === '#screen-window'
    ? { getBoundingClientRect: () => ({ width: windowWidth, height: 1000 }) } : status,
};
globalThis.localStorage = { getItem: (key) => options.get(key) ?? null, setItem: (key, value) => options.set(key, value) };
globalThis.requestAnimationFrame = (callback) => setImmediate(() => callback(performance.now() + 1000));
globalThis.cancelAnimationFrame = clearImmediate;
globalThis.viewBoy = {
  frontendSettingsLoad: async () => ({ selectionAnimationEnabled: false, autoResizeAnimationEnabled: false }),
  frontendSettingsSave: async (preferences) => { savedNativePreferences.push(structuredClone(preferences)); },
  nativePlaybackInit: async () => {}, nativePlaybackAudioConfig: async () => {},
  nativePlaybackState: async () => ({ transport_state: 'stopped' }), favoritesList: async () => [],
  databaseGames: async () => ({ games: [], groups: [] }), playlistTabsLoad: async () => null,
  playlistTabsSave: async () => {},
  playlistTabsReduce: async ({ state, action }) => ({ orderedIDs: [...state.orderedIDs, action.id], activeID: action.id }),
};
const tick = () => new Promise(setImmediate);

test('LCD controls change actual canvas pixels while preserving matrix, layout, and polarity', async () => {
  const { hitTargetSnapshot, lcdDotSizeSnapshot, lcdDeviceDotSnapshot, lcdPanelSnapshot, optionsContentSnapshot, optionsStyleSnapshot, selectionBandSnapshot, bitmapFontSnapshot, choiceControlLayoutSnapshot, volumeControlSnapshot, equalizerAnimationSnapshot, framebufferShadeSnapshot, spacingReadoutLayoutSnapshot } =
    await import('../Sources/ViewBoy/Resources/yoga-app.js');
  await tick(); await tick();
  globalThis.ViewBoy.dispatch('optionsPage:DISPLAY');
  await tick();
  const click = (name, xFraction = 0.5) => {
    const target = hitTargetSnapshot().find((item) => item.name === name);
    assert.ok(target, `visible control: ${name}`);
    const rect = canvas.getBoundingClientRect();
    const size = lcdDotSizeSnapshot().devicePixelsPerDot;
    listeners.get('click')({ clientX: (target.box.x + target.box.width * xFraction) * rect.width / (canvas.width / size),
      clientY: (target.box.y + target.box.height / 2) * rect.height / (canvas.height / size), preventDefault() {} });
  };
  const edit = (name, value) => {
    click(name);
    for (const key of value) listeners.get('keydown')({ key, preventDefault() {}, stopPropagation() {} });
    listeners.get('keydown')({ key: 'Enter', preventDefault() {}, stopPropagation() {} });
  };
  assert.ok(selectionBandSnapshot().height >= bitmapFontSnapshot('MICRO').height + 2,
    'page highlight has room for glyphs and both borders');
  const initial = lcdDotSizeSnapshot();
  assert.equal(initial.pixelGaps, true, 'new installs keep the matrix enabled');
  assert.equal(lcdPanelSnapshot().matrixProfile, 'STN');
  assert.equal(lcdPanelSnapshot().colors[0], '#000000');
  assert.ok(lcdDeviceDotSnapshot().flat().some((color) => color === '#000000'));
  const before = [...canvas.image.data];
  click('CONTRAST BOOST +');
  assert.equal(lcdPanelSnapshot().contrastBoost, 5);
  assert.notDeepEqual([...canvas.image.data], before, 'boost reaches the real packed ImageData renderer');
  assert.deepEqual(lcdDotSizeSnapshot(), initial, 'contrast does not resize or disable the matrix');
  click('APERTURE CLASSIC APERTURE');
  const classicBefore = lcdDeviceDotSnapshot();
  click('CONTRAST BOOST +');
  assert.notDeepEqual(lcdDeviceDotSnapshot(), classicBefore, '1 PX boost reaches saturated black device cells');
  assert.equal(lcdPanelSnapshot().matrixProfile, 'CLASSIC');
  assert.deepEqual(lcdDotSizeSnapshot(), initial, '1 PX boost preserves pitch and enabled matrix');
  click('APERTURE STN APERTURE');
  click('CONTRAST BOOST -');
  const slider = () => hitTargetSnapshot().find((item) => item.name === 'CONTRAST BOOST SLIDER');
  const pointer = (box, fraction) => {
    const rect = canvas.getBoundingClientRect();
    const size = lcdDotSizeSnapshot().devicePixelsPerDot;
    return { pointerId: 1, button: 0, clientX: (box.x + 3 + fraction * (box.width - 7)) * rect.width / (canvas.width / size),
      clientY: (box.y + box.height / 2) * rect.height / (canvas.height / size), preventDefault() {} };
  };
  const trackBox = { ...slider().box };
  listeners.get('pointerdown')(pointer(trackBox, 0.5));
  assert.equal(lcdPanelSnapshot().contrastBoost, 50);
  assert.equal(JSON.parse(options.get('ViewBoy.displayOptions')).lcdContrastBoost, 5, 'drag preview is not persisted');
  listeners.get('pointermove')(pointer(trackBox, 1));
  assert.equal(lcdPanelSnapshot().contrastBoost, 100);
  assert.deepEqual(slider().box, trackBox, 'percentage changes never shift the slider');
  listeners.get('pointercancel')({});
  assert.equal(lcdPanelSnapshot().contrastBoost, 5, 'cancel restores the pre-drag value');
  listeners.get('pointerdown')(pointer(trackBox, 0.25));
  listeners.get('pointerup')(pointer(trackBox, 0.75));
  assert.equal(JSON.parse(options.get('ViewBoy.displayOptions')).lcdContrastBoost, 75, 'completed drag persists');
  listeners.get('click')(pointer(trackBox, 0.75)); // Consume the native click after pointerup.
  const key = (code, shiftKey = false) => listeners.get('keydown')({ code, key: code, shiftKey, preventDefault() {}, stopPropagation() {} });
  key('Home'); assert.equal(lcdPanelSnapshot().contrastBoost, 0);
  key('ArrowRight'); assert.equal(lcdPanelSnapshot().contrastBoost, 1);
  key('ArrowRight', true); assert.equal(lcdPanelSnapshot().contrastBoost, 11);
  key('End'); assert.equal(lcdPanelSnapshot().contrastBoost, 100);
  key('Home'); for (let i = 0; i < 5; i++) key('ArrowRight');
  key('Escape');
  assert.equal(choiceControlLayoutSnapshot().find((row) => row.title === 'PIXEL METHOD').label, 'METHOD');
  for (const method of ['DIRECT', '8 SHADE', '16 SHADE', 'STN LCD']) {
    click(`PIXEL METHOD ${method}`);
    assert.deepEqual(lcdDotSizeSnapshot(), initial, `${method} retains the matrix geometry`);
    const preview = optionsStyleSnapshot().find((item) => item.kind === 'preview');
    assert.equal(preview.label, 'PREVIEW');
    const count = method === '8 SHADE' ? 8 : method === '16 SHADE' ? 16 : 4;
    assert.equal(preview.toneCount, count);
    const strip = optionsStyleSnapshot().find((item) => item.kind === 'tone-strip').box;
    const tones = Array.from({ length: count }, (_, i) => framebufferShadeSnapshot(
      strip.x + 1 + (strip.width - 2) * (i + 0.5) / count, strip.y + strip.height / 2));
    assert.equal(new Set(tones).size, count, 'the single unbroken preview strip paints every tone');
    const buttons = hitTargetSnapshot().filter((item) => item.name.startsWith('PIXEL METHOD '));
    assert.equal(buttons.length, 4);
    assert.ok(Math.max(...buttons.map((item) => item.box.width)) - Math.min(...buttons.map((item) => item.box.width)) <= 1,
      'labeled method buttons have equal widths');
  }
  const originalBackground = lcdPanelSnapshot().colors[3];
  edit('BG CSS COLOR INPUT', 'not-a-color');
  assert.equal(lcdPanelSnapshot().colors[3], originalBackground, 'invalid input preserves the palette');
  listeners.get('keydown')({ key: 'Escape', preventDefault() {}, stopPropagation() {} });
  edit('BG CSS COLOR INPUT', '111111');
  edit('PIXEL CSS COLOR INPUT', 'DDDDDD');
  const inverse = lcdPanelSnapshot().colors;
  assert.ok(parseInt(inverse[0].slice(1), 16) > parseInt(inverse[1].slice(1), 16));
  assert.ok(parseInt(inverse[1].slice(1), 16) > parseInt(inverse[2].slice(1), 16));
  assert.equal(inverse[3], '#111111');
  assert.equal(lcdDotSizeSnapshot().pixelGaps, true);
  click('APERTURE STN APERTURE');
  assert.deepEqual(lcdDotSizeSnapshot(), initial);
  assert.equal(JSON.parse(options.get('ViewBoy.displayOptions')).lcdContrastBoost, 5);
  click('FONT STANDARD 5X7');
  windowWidth = 700;
  windowListeners.get('resize')?.();
  await tick();
  assert.equal(lcdDotSizeSnapshot().devicePixelsPerDot, initial.devicePixelsPerDot);
  assert.ok(selectionBandSnapshot().height >= bitmapFontSnapshot('STANDARD').height + 2,
    'Standard page highlight does not strike through the label');
  const viewport = optionsContentSnapshot().viewport;
  const cards = optionsStyleSnapshot().filter((item) => item.kind === 'group');
  assert.ok(cards.every(({ box }) => box.x >= viewport.x && box.x + box.width <= viewport.x + viewport.width),
    'narrow Display cards remain within the clipped pane');
  assert.deepEqual(cards.map((card) => card.name), ['LCD PALETTE', 'SCREEN PROFILE', 'INTERFACE', 'LAYOUT SPACING', 'MOTION'],
    'interface settings share one card');
  const paletteCard = cards.find((item) => item.name === 'LCD PALETTE').box;
  const profileCard = cards.find((item) => item.name === 'SCREEN PROFILE').box;
  assert.equal(profileCard.x, paletteCard.x, 'cards stack at narrow widths');
  assert.ok(profileCard.y >= paletteCard.y + paletteCard.height, 'stacked cards do not overlap');
  const choices = choiceControlLayoutSnapshot();
  const aperture = choices.find((row) => row.title === 'APERTURE').controls;
  const font = choices.find((row) => row.title === 'FONT').controls;
  assert.equal(aperture.x, font.x);
  assert.equal(aperture.width, font.width, 'two-way selectors share the same columns');
  assert.ok(aperture.y < font.y, 'like selectors are ordered alphabetically');
  const boostBox = hitTargetSnapshot().find((item) => item.name === 'CONTRAST BOOST SLIDER').box;
  assert.equal(boostBox.width, paletteCard.width - 8, 'contrast slider uses the whole card content width');
  const motionReadouts = spacingReadoutLayoutSnapshot().filter((item) => ['ANIMATION DURATION', 'ANIMATION FPS CAP'].includes(item.title));
  assert.equal(motionReadouts[0].box.x, motionReadouts[1].box.x, 'numeric value columns align within Motion');
  assert.equal(motionReadouts[0].box.width, motionReadouts[1].box.width);
  click('ANIMATION FPS CAP +');
  assert.equal(JSON.parse(options.get('ViewBoy.displayOptions')).animationFPS, 70);
  const fpsBox = hitTargetSnapshot().find((item) => item.name === 'ANIMATION FPS CAP').box;
  assert.equal(fpsBox.width, boostBox.width, 'FPS uses the same full-width gauge style');
  click('QUEUE');
  const queueChoices = choiceControlLayoutSnapshot();
  assert.deepEqual(queueChoices.map((row) => row.title), ['RANDOM', 'REPEAT']);
  assert.equal(queueChoices[0].controls.x, queueChoices[1].controls.x);
  assert.equal(queueChoices[0].controls.width, queueChoices[1].controls.width);
  assert.ok(queueChoices[0].controls.width < queueChoices[0].row.width * 0.65, 'wide Queue fields stay bounded');
  click('AUDIO');
  const output = optionsStyleSnapshot().find((item) => item.kind === 'group' && item.name === 'OUTPUT').box;
  assert.equal(volumeControlSnapshot().gaugeBox.width, output.width - 8, 'volume is a separate full-width row');
  const volumeBox = volumeControlSnapshot().gaugeBox;
  const dragAudio = (box, fraction) => {
    // The exact common gauge bounds are inset two dots on either side.
    const point = pointer(box, fraction);
    const rect = canvas.getBoundingClientRect();
    const size = lcdDotSizeSnapshot().devicePixelsPerDot;
    point.clientX = (box.x + 2 + fraction * (box.width - 5)) * rect.width / (canvas.width / size);
    return point;
  };
  const savedBeforeVolume = savedNativePreferences.length;
  listeners.get('pointerdown')(dragAudio(volumeBox, 0.5));
  assert.equal(volumeControlSnapshot().value, 0.5);
  assert.equal(savedNativePreferences.length, savedBeforeVolume, 'audio drag preview does not save');
  listeners.get('pointercancel')({});
  assert.equal(volumeControlSnapshot().value, 1, 'cancel leaves the native volume unchanged');
  listeners.get('pointerdown')(dragAudio(volumeBox, 0.2));
  listeners.get('pointerup')(dragAudio(volumeBox, 0.4));
  listeners.get('click')(dragAudio(volumeBox, 0.4));
  await tick();
  assert.equal(savedNativePreferences.at(-1).appVolume, 0.4, 'completed volume gesture persists');
  key('End'); await tick();
  assert.equal(volumeControlSnapshot().value, 1);
  const band = () => equalizerAnimationSnapshot()[0];
  const eqBox = hitTargetSnapshot().find((item) => item.name === 'EQ 31 HZ').box;
  listeners.get('pointerdown')(dragAudio(eqBox, 1));
  const maximum = band();
  assert.equal(maximum.gain, 12);
  assert.equal(maximum.fillWidth, maximum.bounds.right - maximum.bounds.left + 1);
  assert.equal(framebufferShadeSnapshot(maximum.bounds.right, eqBox.y + 1), 0, 'maximum fills the final track pixel');
  assert.equal(maximum.tickXs[0], maximum.bounds.left);
  assert.equal(maximum.tickXs.at(-1), maximum.bounds.right);
  listeners.get('pointercancel')({});
  assert.equal(band().gain, 0);
  assert.equal(framebufferShadeSnapshot(band().bounds.right, eqBox.y + 1), 3, 'cancel clears the previous fill');
  listeners.get('pointerdown')(dragAudio(eqBox, 0.5));
  listeners.get('pointerup')(dragAudio(eqBox, 1));
  listeners.get('click')(dragAudio(eqBox, 1));
  await tick();
  assert.equal(savedNativePreferences.at(-1).equalizerBandGains[0], 12);
  key('Home'); await tick();
  assert.equal(band().gain, 0);
  windowWidth = 640;
  windowListeners.get('resize')?.();
  click('DISPLAY'); click('DOT SIZE +'); click('AUDIO');
  const audioViewport = optionsContentSnapshot().viewport;
  const narrowBars = hitTargetSnapshot().filter((item) => /^EQ .* HZ$/.test(item.name));
  assert.ok(narrowBars.every(({ box }) => box.width > 0 && box.x >= audioViewport.x
    && box.x + box.width <= audioViewport.x + audioViewport.width), 'narrow EQ bars fit the pane');
  assert.ok(narrowBars.every(({ box }) => box.x === narrowBars[0].box.x && box.width === narrowBars[0].box.width),
    'all ten bands keep identical columns');
  windowWidth = 1600; windowListeners.get('resize')?.();
  click('DISPLAY');
  click('ANIMATIONS', 0.05);
  const motionFrames = [];
  globalThis.requestAnimationFrame = (callback) => { const id = setImmediate(() => {}); motionFrames.push({ callback, id }); return id; };
  click('QUEUE');
  const moving = selectionBandSnapshot();
  assert.ok(moving.duration > 0, 'page selection retains one animated marker');
  const quarter = selectionBandSnapshot(moving.startedAt + moving.duration / 4);
  const start = selectionBandSnapshot(moving.startedAt).animatedY;
  assert.ok(Math.abs((quarter.animatedY - start) / (quarter.targetY - start) - 0.607220362) < 1e-6,
    'sidebar animation uses SB2 timing');
  const frame = motionFrames.shift();
  clearImmediate(frame.id);
  frame.callback(moving.startedAt + moving.duration / 4);
  assert.equal(framebufferShadeSnapshot(quarter.x + quarter.width - 2, Math.floor(quarter.animatedY) + 2), 2,
    'animation paints the moving shaded bar into the actual framebuffer');
  windowListeners.get('pagehide')?.();
});
