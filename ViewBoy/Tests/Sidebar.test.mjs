import assert from 'node:assert/strict';
import test from 'node:test';

const listeners = new Map();
let windowWidth = 1000;
const canvas = {
  style: {}, focus() {}, setPointerCapture() {}, addEventListener: (name, fn) => listeners.set(name, fn),
  getBoundingClientRect: () => ({ left: 0, top: 0, width: parseFloat(canvas.style.width), height: parseFloat(canvas.style.height) }),
  getContext: () => ({ createImageData: (width, height) => ({ width, height, data: new Uint8ClampedArray(width * height * 4) }), putImageData() {} }),
};
const options = new Map([['ViewBoy.displayOptions', JSON.stringify({ font: 'STANDARD', pixelShadeMode: 'DIRECT' })]]);
const events = new Map();
globalThis.window = globalThis;
globalThis.devicePixelRatio = 2;
globalThis.addEventListener = (name, fn) => events.set(name, fn);
globalThis.document = {
  documentElement: { dataset: {}, style: { setProperty() {} } },
  querySelector: (name) => name === '#lcd' ? canvas : name === '#screen-window'
    ? { getBoundingClientRect: () => ({ width: windowWidth, height: 1000 }) } : {},
};
globalThis.localStorage = { getItem: (key) => options.get(key) ?? null, setItem: (key, value) => options.set(key, value) };
globalThis.requestAnimationFrame = (callback) => setImmediate(() => callback(performance.now() + 1000));
globalThis.cancelAnimationFrame = clearImmediate;
const filename = 'A complete long song filename.gbs';
globalThis.viewBoy = {
  frontendSettingsLoad: async () => ({ sidebarMode: 'paths', selectionAnimationEnabled: false, autoResizeAnimationEnabled: false }),
  frontendSettingsSave: async () => {}, nativePlaybackInit: async () => {}, nativePlaybackAudioConfig: async () => {},
  nativePlaybackState: async () => ({ transport_state: 'stopped' }), favoritesList: async () => [],
  databaseGames: async () => ({ games: [], groups: [] }), playlistTabsLoad: async () => null,
  playlistTabsSave: async () => {}, playlistTabsReduce: async ({ state, action }) => action.kind === 'close'
    ? { orderedIDs: state.orderedIDs.filter((id) => id !== action.id), activeID: state.activeID }
    : { orderedIDs: [...state.orderedIDs, action.id], activeID: action.id },
  databaseFileTree: async () => [{ kind: 'folder', name: 'ROOT', path: '/root', children: [
    { kind: 'folder', name: 'PARENT', path: '/root/parent', children: [
      { kind: 'folder', name: 'CHILD', path: '/root/parent/child', children: [
        { kind: 'file', name: filename, path: '/root/parent/child/song.gbs' },
      ] },
    ] },
  ] }],
};
const tick = () => new Promise(setImmediate);

test('sidebar depth uses one character, labels retain their right budget, and width gestures persist safely', async () => {
  const { hitTargetSnapshot, lcdDotSizeSnapshot, bitmapFontSnapshot, optionsStyleSnapshot, optionsContentSnapshot, choiceControlLayoutSnapshot, framebufferShadeSnapshot } =
    await import('../Sources/ViewBoy/Resources/yoga-app.js');
  for (let i = 0; i < 8; i++) await tick();
  const target = (name, page = false) => { const value = hitTargetSnapshot().find((item) => item.name === name && (!page || item.optionPage)); assert.ok(value, name); return value; };
  const point = (box, x = box.x + box.width / 2, detail = 1) => {
    const rect = canvas.getBoundingClientRect();
    const size = lcdDotSizeSnapshot().devicePixelsPerDot;
    return { clientX: x * rect.width / (canvas.width / size),
      clientY: (box.y + box.height / 2) * rect.height / (canvas.height / size), pointerId: 1, button: 0, detail, preventDefault() {} };
  };
  const click = (name) => listeners.get('click')(point(target(name).box));
  click('PARENT'); click('CHILD');
  const rows = ['ROOT', 'PARENT', 'CHILD', filename].map((name) => target(name));
  const advance = rows[0].glyphAdvance;
  for (let i = 1; i < rows.length; i++) assert.equal(rows[i].textInset - rows[i - 1].textInset, advance);
  assert.equal(rows[3].textRightInset, 4, 'depth does not consume the trailing margin');
  assert.equal(rows[3].textCapacity, Math.floor((rows[3].box.width - rows[3].textInset - 4 + 1) / advance));
  assert.ok(rows[3].textCapacity > Math.floor((rows[3].box.width - rows[3].textInset * 2 + 1) / advance), 'deep labels gain usable characters');
  listeners.get('pointermove')(point(rows[3].box));
  assert.equal(canvas.title, filename, 'hover retains the full source name');
  assert.equal(JSON.parse(options.get('ViewBoy.displayOptions')).renderingMode, 'DIRECT', 'legacy Direct mode migrates');
  assert.equal(JSON.parse(options.get('ViewBoy.displayOptions')).paletteMode, 'COLOR');
  const initialCapacity = rows[3].textCapacity;
  const splitter = target('SIDEBAR WIDTH').box;
  listeners.get('pointerdown')(point(splitter));
  listeners.get('pointermove')(point(splitter, splitter.x + 120));
  assert.ok(target(filename).textCapacity > initialCapacity);
  assert.equal(JSON.parse(options.get('ViewBoy.displayOptions')).sidebarWidthFraction, null, 'preview is not persisted');
  listeners.get('pointercancel')({});
  assert.equal(target(filename).textCapacity, initialCapacity);
  listeners.get('pointerdown')(point(splitter));
  listeners.get('pointermove')(point(splitter, splitter.x + 120));
  listeners.get('pointerup')(point(splitter, splitter.x + 120));
  listeners.get('click')(point(splitter, splitter.x + 120)); // consume click after drag
  assert.ok(JSON.parse(options.get('ViewBoy.displayOptions')).sidebarWidthFraction > 0.3);
  const capacity = target(filename).textCapacity;
  assert.ok(capacity >= filename.length, 'widening reveals the full long filename');
  listeners.get('click')(point(target('SIDEBAR WIDTH').box, undefined, 2));
  assert.equal(JSON.parse(options.get('ViewBoy.displayOptions')).sidebarWidthFraction, null);
  assert.equal(target(filename).textCapacity, initialCapacity, 'double click restores adaptive width');

  globalThis.ViewBoy.dispatch('optionsPage:DISPLAY');
  const headers = optionsStyleSnapshot().filter((item) => item.headerRole);
  assert.deepEqual(headers.map((item) => item.headerRole), ['navigation', 'content']);
  assert.ok(headers.every((item) => item.fillShade === 2));
  assert.equal(headers[0].box.y, headers[1].box.y);
  assert.equal(headers[0].box.height, headers[1].box.height);
  const checkSectionSpacing = (gap) => {
    const styles = optionsStyleSnapshot();
    const pageHeader = styles.find((item) => item.headerRole === 'content').box;
    const navHeader = styles.find((item) => item.headerRole === 'navigation').box;
    const palette = styles.find((item) => item.kind === 'group' && item.name === 'LCD PALETTE').box;
    const profile = styles.find((item) => item.kind === 'group' && item.name === 'SCREEN PROFILE').box;
    const paletteTitle = styles.find((item) => item.kind === 'title' && item.name === 'LCD PALETTE').box;
    const preview = styles.find((item) => item.kind === 'preview').box;
    const toolbar = hitTargetSnapshot().find((item) => item.sidebarAction).box;
    assert.equal(palette.y - pageHeader.y - pageHeader.height, gap * 2, 'pane header has a section gap');
    assert.equal(toolbar.y - navHeader.y - navHeader.height, gap * 2, 'navigation header follows the same rule');
    assert.equal(profile.y - palette.y - palette.height, gap * 2, 'stacked cards have a section gap');
    assert.equal(preview.y - paletteTitle.y - paletteTitle.height, gap * 2, 'card header has a section gap');
    assert.equal(preview.x, palette.x, 'section rows share the header edge');
    assert.equal(preview.width, palette.width, 'section rows use the full width');
    const lastControl = target('PIXEL MATRIX GAPS').box;
    assert.equal(profile.y + profile.height - lastControl.y - lastControl.height, 0, 'sections have no dialog padding');
  };
  checkSectionSpacing(4);
  const headerBefore = headers[0].box.height;
  click('UI BUTTON PAD +');
  assert.equal(optionsStyleSnapshot().find((item) => item.headerRole === 'navigation').box.height, headerBefore + 2,
    'button padding affects Options immediately');
  const cardBefore = optionsStyleSnapshot().find((item) => item.kind === 'group' && item.name === 'LCD PALETTE').box;
  const sliderBefore = target('CONTRAST BOOST SLIDER').box;
  click('UI CHROME GAP +');
  const cardAfter = optionsStyleSnapshot().find((item) => item.kind === 'group' && item.name === 'LCD PALETTE').box;
  const sliderAfter = target('CONTRAST BOOST SLIDER').box;
  assert.equal(sliderAfter.x - cardAfter.x, 0, 'gauge stays aligned with the unframed section');
  checkSectionSpacing(5);
  const pageBefore = target('QUEUE', true).box.y - target('LIBRARY', true).box.y;
  click('TEXT LINE GAP +');
  assert.equal(target('QUEUE', true).box.y - target('LIBRARY', true).box.y, pageBefore + 1, 'line gap affects Options links');
  const pitch = lcdDotSizeSnapshot().devicePixelsPerDot;
  click('RESET SPACING');
  const saved = JSON.parse(options.get('ViewBoy.displayOptions'));
  assert.deepEqual([saved.uiButtonPadDots, saved.uiChromeGapDots, saved.textLineGapDots], [4, 4, 1]);
  assert.equal(lcdDotSizeSnapshot().devicePixelsPerDot, pitch);
  windowWidth = 1600;
  events.get('resize')();
  const wideCards = optionsStyleSnapshot().filter((item) => item.kind === 'group');
  const widePalette = wideCards.find((item) => item.name === 'LCD PALETTE').box;
  const wideInterface = wideCards.find((item) => item.name === 'INTERFACE').box;
  assert.equal(wideInterface.x, widePalette.x, 'wide Options remains one simple column');
  assert.ok(wideInterface.y > widePalette.y + widePalette.height);
  for (const choice of choiceControlLayoutSnapshot()) {
    assert.ok(choice.controls.width <= choice.row.width / 2 + 1, 'compact selectors fill at most the right half');
    assert.equal(choice.controls.x + choice.controls.width, choice.row.x + choice.row.width);
  }
  windowWidth = 1000;
  events.get('resize')();
  for (let i = 0; i < 3; i++) click('UI BUTTON PAD -');
  const font = bitmapFontSnapshot('STANDARD');
  assert.equal(target('FONT STANDARD 5X7').box.height, font.height + 4, 'one-dot padding still reserves borders outside the glyph');
  const viewport = optionsContentSnapshot().viewport;
  assert.ok(optionsStyleSnapshot().filter((item) => item.kind === 'group').every(({ box }) =>
    box.x >= viewport.x && box.x + box.width <= viewport.x + viewport.width));
  click('UI BUTTON PAD +'); click('UI BUTTON PAD +');
  click('UI CHROME GAP +'); click('UI CHROME GAP +'); click('UI CHROME GAP +');
  click('DOT SIZE +');
  windowWidth = 840;
  events.get('resize')();
  click('BUTTONS SYMBOLS');
  for (const name of ['PREVIOUS', 'NEXT']) {
    const box = target(name).box;
    const ink = [];
    for (let y = Math.ceil(box.y + 1); y < box.y + box.height - 1; y++) {
      for (let x = Math.ceil(box.x + 1); x < box.x + box.width - 1; x++) {
        if (framebufferShadeSnapshot(x, y) === 0) ink.push({ x, y });
      }
    }
    assert.ok(ink.length > 0);
    const center = (Math.min(...ink.map((p) => p.x)) + Math.max(...ink.map((p) => p.x)) + 1) / 2;
    assert.ok(Math.abs(center - (box.x + box.width / 2)) <= 1, `${name} bitmap is centered`);
  }
  click('OPTIONS');
  for (let i = 0; i < 13; i++) { click('[+]'); await tick(); }
  const closeButtons = hitTargetSnapshot().filter((item) => item.playlistTabClose);
  assert.ok(closeButtons.length >= 12, 'exercise crowded tabs');
  for (const close of closeButtons) {
    const owner = hitTargetSnapshot().find((item) => item.reorderKind === 'tab' && item.reorderKey === close.playlistTabId);
    assert.ok(close.box.x >= owner.box.x + 1 && close.box.x + close.box.width <= owner.box.x + owner.box.width - 1,
      JSON.stringify({ close: close.box, owner: owner.box }));
    assert.equal(close.box.width, close.box.height, 'close target remains square');
    const left = Math.round(close.box.x + close.box.width / 2 - 3.5);
    const top = Math.round(close.box.y + close.box.height / 2 - 3.5);
    assert.equal(framebufferShadeSnapshot(left, top), 0, 'close frame is centered and fully visible');
    assert.equal(framebufferShadeSnapshot(left + 3, top + 3), 0, 'center of bitmap X is present');
    assert.equal(framebufferShadeSnapshot(left + 6, top + 6), 0, 'far corner of close frame is not clipped');
    let centerInk = 0;
    for (let y = 1; y < 6; y++) for (let x = 1; x < 6; x++) {
      if (framebufferShadeSnapshot(left + x, top + y) === 0) centerInk++;
    }
    assert.equal(centerInk, 5, 'minimal X has exactly five ink dots inside the empty box');
    assert.notEqual(framebufferShadeSnapshot(left + 1, top + 1), 0, 'X stays separated from the frame');
  }
  const closedId = closeButtons[0].playlistTabId;
  listeners.get('click')(point(closeButtons[0].box));
  await tick();
  assert.ok(!hitTargetSnapshot().some((item) => item.playlistTabClose && item.playlistTabId === closedId && item.interactive),
    'the painted close target closes its own tab');
  events.get('pagehide')?.();
});
