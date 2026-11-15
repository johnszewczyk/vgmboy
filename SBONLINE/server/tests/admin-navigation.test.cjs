const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const { test } = require('node:test');

const serverDir = `${__dirname}/..`;
const desktopNavHtml = readFileSync(`${serverDir}/templates/accounts/partials/desktop_site_navigation.html`, 'utf8');
const drawerNavHtml = readFileSync(`${serverDir}/templates/accounts/partials/drawer_navigation.html`, 'utf8');
const accountsHtml = readFileSync(`${serverDir}/templates/accounts/accounts.html`, 'utf8');
const siteNavJs = readFileSync(`${serverDir}/static/accounts/site-navigation.js`, 'utf8');
const adminJs = readFileSync(`${serverDir}/static/accounts/admin.js`, 'utf8');

test('desktop navigation includes superuser Admin link and site-navigation keeps it active across admin routes', () => {
  assert.match(desktopNavHtml, /if request\.user\.is_superuser/);
  assert.match(desktopNavHtml, /data-nav-key="admin"/);
  assert.match(drawerNavHtml, /action="\{% url 'logout' %\}"/);
  assert.match(accountsHtml, /toggle_user/);
  assert.match(accountsHtml, /create_passkey_recovery_invite/);
  assert.match(accountsHtml, /delete_user/);

  assert.match(siteNavJs, /pathname\.includes\("\/accounts"\)\s*\|\|\s*pathname\.includes\("\/usage"\)\s*\|\|\s*pathname\.includes\("\/site-log"\)\s*\|\|\s*pathname\.includes\("\/server"\)\)\s*return "admin";/);
});

test('admin.js delegates copy buttons and rebinds passkey controls after PJAX navigation', async () => {
  const listeners = {};
  const copied = [];
  const statusNode = { textContent: '' };
  const inputEl = { id: 'invite-code-1', value: 'ABCD1234', focus() {}, select() {} };
  const button = {
    dataset: { copyTarget: 'invite-code-1' },
    closest: (selector) => (selector === '.accounts-section, .invite-result, .login-password-result, main.page-shell'
      ? { querySelector: (sel) => (sel === '.copy-status' ? statusNode : null) }
      : button),
  };

  const context = vm.createContext({
    window: { isSecureContext: true, matchMedia: () => null, PublicKeyCredential: function () {} },
    navigator: {
      clipboard: { writeText: async (value) => copied.push(value) },
      credentials: { create() {}, get() {} },
    },
    document: {
      documentElement: { dataset: {} },
      body: { classList: { contains: () => true } },
      querySelector: () => null,
      querySelectorAll: () => [],
      getElementById: (id) => (id === 'invite-code-1' ? inputEl : null),
      addEventListener: (type, handler) => {
        listeners[type] ||= [];
        listeners[type].push(handler);
      },
    },
    atob: (s) => Buffer.from(s, 'base64').toString('binary'),
    btoa: (s) => Buffer.from(s, 'binary').toString('base64'),
    Uint8Array,
    Promise,
  });

  vm.runInContext(adminJs, context);
  assert.equal(typeof listeners.click?.[0], 'function');
  assert.equal(typeof listeners['site:navigated']?.[0], 'function');

  await listeners.click[0]({ target: { closest: () => button } });
  await new Promise((r) => setTimeout(r, 10));
  assert.deepEqual(copied, ['ABCD1234']);
  assert.equal(statusNode.textContent, 'Copied to clipboard.');
});
