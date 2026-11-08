// Exercise the shipped desktop column layout without a browser or account.
const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { test } = require('node:test');

const source = readFileSync(`${__dirname}/../static/accounts/spcboy.js`, 'utf8');
const layout = source.slice(source.indexOf('  function updatePlaylistColumnLayout()'), source.indexOf('  function syncPlaylistHeaderScroll()'));

function fixture({ view = 'all', rowValues = [], columnWidths = {} } = {}) {
  const definitions = [
    { id: 'index', label: '#', weight: 0.15 },
    { id: 'title', label: 'TITLE', weight: 1.45 },
    { id: 'game', label: 'GAME', weight: 1.05 },
    { id: 'timestamp', label: 'DATE/TIME', weight: 1 },
  ];
  const order = definitions.map(({ id }) => id);
  const headers = new Map(definitions.map(column => [column.id, {
    dataset: { column: column.id, label: column.label },
    hidden: false,
    style: {},
    getBoundingClientRect: () => ({ height: 14 }),
  }]));
  const rows = rowValues.map(values => {
    const cells = new Map(definitions.map(column => [column.id, {
      dataset: { column: column.id },
      textContent: values[column.id] || '',
      hidden: false,
      style: {},
    }]));
    return {
      getClientRects: () => [{}],
      querySelector: selector => cells.get(selector.match(/data-column="([^"]+)/)[1]),
      querySelectorAll: () => [...cells.values()],
      cells,
    };
  });
  const style = new Map();
  const playlistContent = {
    clientWidth: 900,
    scrollLeft: 0,
    querySelectorAll: () => rows,
  };
  const headCells = {
    querySelector: selector => headers.get(selector.match(/data-column="([^"]+)/)[1]),
  };
  const context = vm.createContext({
    page: { isConnected: true },
    isDesktop: () => true,
    playlistPane: { hidden: false },
    playlistContent,
    playlistColumnHeadCells: headCells,
    playlistColumnHead: { querySelector: () => ({ getBoundingClientRect: () => ({ height: 0 }) }) },
    playlistColumnOrder: order,
    PLAYLIST_COLUMN_DEFINITIONS: definitions,
    playlistColumnVisibility: { index: true, title: true, game: true, timestamp: true, favorite: false },
    playlistColumnWidths: columnWidths,
    view,
    library: { style: { setProperty: (key, value) => style.set(key, value) } },
    getComputedStyle: element => element === headCells ? { columnGap: '4px' }
      : element === playlistContent ? { paddingLeft: '5px' } : {},
    measurePlaylistColumnText: (_element, text) => text.length * 6,
    window: { SBPresentation: {} },
    syncPlaylistHeaderScroll() {},
  });
  vm.runInContext(layout, context);
  return { context, headers, rows, style };
}

test('empty metadata headings hide while row number and populated columns remain', () => {
  const { context, headers, rows } = fixture({ rowValues: [{ index: '1', title: 'Song', game: '—', timestamp: '-' }] });
  context.updatePlaylistColumnLayout();
  assert.equal(headers.get('index').hidden, false);
  assert.equal(headers.get('title').hidden, false);
  assert.equal(headers.get('game').hidden, true);
  assert.equal(headers.get('timestamp').hidden, true);
  assert.equal(rows[0].cells.get('game').hidden, true);
});

test('Favorites and Recent keep the Date/Time heading when timestamps are missing', () => {
  for (const view of ['favorites', 'recent']) {
    const { context, headers } = fixture({ view, rowValues: [{ index: '1', title: '', game: 'Game', timestamp: '—' }] });
    context.updatePlaylistColumnLayout();
    assert.equal(headers.get('timestamp').hidden, false, `${view} timestamp heading`);
    assert.equal(headers.get('title').hidden, true, `${view} empty title heading`);
  }
});

test('an empty playlist leaves every configured column heading visible', () => {
  const { context, headers } = fixture();
  context.updatePlaylistColumnLayout();
  for (const header of headers.values()) assert.equal(header.hidden, false);
});

test('default widths ignore track text and saved manual widths still apply', () => {
  const readWidths = options => {
    const { context, style } = fixture(options);
    context.updatePlaylistColumnLayout();
    return style.get('--sb-column-template').split(' ').map(value => Number.parseFloat(value));
  };
  const shared = { index: '1', game: 'Game', timestamp: 'Date' };
  const short = readWidths({ rowValues: [{ ...shared, title: 'Short' }] });
  const long = readWidths({ rowValues: [{ ...shared, title: 'A much longer song title' }] });
  assert.deepEqual(long, short);

  const manuallySized = readWidths({ rowValues: [{ ...shared, title: 'Short' }], columnWidths: { title: 220 } });
  assert.equal(manuallySized[1], 220);
});
