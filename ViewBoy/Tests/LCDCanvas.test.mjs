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
  nativePlaybackInit: async () => {}, nativePlaybackAudioConfig: async () => {},
  nativePlaybackState: async () => ({ transport_state: 'stopped' }), favoritesList: async () => [],
  databaseGames: async () => ({ games: [], groups: [] }), playlistTabsLoad: async () => null,
  playlistTabsSave: async () => {},
  playlistTabsReduce: async ({ state, action }) => ({ orderedIDs: [...state.orderedIDs, action.id], activeID: action.id }),
};
const tick = () => new Promise(setImmediate);

test('LCD controls change actual canvas pixels while preserving matrix, layout, and polarity', async () => {
  const { hitTargetSnapshot, lcdDotSizeSnapshot, lcdDeviceDotSnapshot, lcdPanelSnapshot, optionsContentSnapshot, optionsStyleSnapshot, selectionBandSnapshot, bitmapFontSnapshot } =
    await import('../Sources/ViewBoy/Resources/yoga-app.js');
  await tick(); await tick();
  globalThis.ViewBoy.dispatch('optionsPage:DISPLAY');
  await tick();
  const click = (name) => {
    const target = hitTargetSnapshot().find((item) => item.name === name);
    assert.ok(target, `visible control: ${name}`);
    const rect = canvas.getBoundingClientRect();
    const size = lcdDotSizeSnapshot().devicePixelsPerDot;
    listeners.get('click')({ clientX: (target.box.x + target.box.width / 2) * rect.width / (canvas.width / size),
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
  for (const method of ['DIRECT', '8 SHADE', '16 SHADE', 'STN LCD']) {
    click(`PIXEL METHOD ${method}`);
    assert.deepEqual(lcdDotSizeSnapshot(), initial, `${method} retains the matrix geometry`);
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
  windowListeners.get('pagehide')?.();
});
