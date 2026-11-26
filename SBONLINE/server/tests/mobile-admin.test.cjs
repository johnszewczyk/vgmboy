const { readFileSync } = require('node:fs');
const assert = require('node:assert/strict');
const { test } = require('node:test');

const serverDir = `${__dirname}/..`;
const desktopNavHtml = readFileSync(`${serverDir}/templates/accounts/partials/desktop_site_navigation.html`, 'utf8');
const mobileShellHtml = readFileSync(`${serverDir}/templates/accounts/partials/spcboy_mobile_shell.html`, 'utf8');
const mobileCss = readFileSync(`${serverDir}/static/accounts/spcboy-mobile.css`, 'utf8');
const spcboyJs = readFileSync(`${serverDir}/static/accounts/spcboy.js`, 'utf8');

test('desktop navigation stays untouched and mobile nav exposes nested Nav screen with superuser-only Admin', () => {
  assert.doesNotMatch(desktopNavHtml, /data-nav-key="admin"/);
  assert.match(mobileShellHtml, /<button type="button" class="spcboy-mobile-nav-btn" data-mobile-app-page="nav">Nav<\/button>/);
  assert.match(mobileShellHtml, /id="spcboy-mobile-screen-nav"/);
  assert.match(mobileShellHtml, /\{% if request\.user\.is_superuser %\}<button type="button" class="spcboy-mobile-vnav-item" data-mobile-app-page="admin"><svg class="site-ui-icon" aria-hidden="true"><use href="#site-icon-settings"><\/use><\/svg><span>Admin Console<\/span><\/button>\{% endif %\}/);
  assert.match(mobileShellHtml, /id="spcboy-mobile-screen-admin"/);
  assert.match(mobileShellHtml, /class="spcboy-mobile-card"[\s\S]*Site Controls/);
  assert.match(mobileShellHtml, /class="spcboy-mobile-card"[\s\S]*Invitations/);
  assert.match(mobileShellHtml, /class="spcboy-mobile-card"[\s\S]*Accounts/);
});

test('spcboy.js integrates nav and admin page switching and spcboy-mobile.css styles admin cards in mobile theme', () => {
  assert.match(spcboyJs, /\["playing", "library", "recent", "favorites", "sound", "nav", "admin"\]/);
  assert.match(spcboyJs, /else if \(nextPage === "admin"\) void loadMobileAdmin\(\);/);
  assert.match(mobileCss, /\.spcboy-mobile-admin-item\s*\{/);
  assert.match(mobileCss, /\.spcboy-mobile-admin-code\s*\{/);
  assert.match(mobileCss, /#spcboy-mobile-app \.spcboy-mobile-vnav > :is\(a, button\)/);
});

test('unified admin page, persistent sign-in on device, and dead page navigation removal', () => {
  const drawerNavHtml = readFileSync(serverDir + '/templates/accounts/partials/drawer_navigation.html', 'utf8');
  const loginHtml = readFileSync(serverDir + '/templates/accounts/login.html', 'utf8');
  const accountsHtml = readFileSync(serverDir + '/templates/accounts/accounts.html', 'utf8');
  const adminCss = readFileSync(serverDir + '/static/accounts/admin.css', 'utf8');
  const adminJs = readFileSync(serverDir + '/static/accounts/admin.js', 'utf8');
  const settingsPy = readFileSync(serverDir + '/precalc_admin/settings.py', 'utf8');

  // Navigations have no dead Listening or Site details links
  assert.doesNotMatch(desktopNavHtml, /playback_history|Listening/);
  assert.doesNotMatch(drawerNavHtml, /playback_history|Listening|site-icon-database/);
  assert.doesNotMatch(mobileShellHtml, /playback_history|Listening/);

  // Login page has "Save sign-in on this device"
  assert.match(loginHtml, /name="remember_me"[^>]*checked/);
  assert.match(loginHtml, /Save sign-in on this device/);
  assert.match(adminCss, /\.login-remember-label\s*\{/);
  assert.match(adminJs, /remember_me/);
  assert.match(settingsPy, /SESSION_COOKIE_AGE\s*=\s*365\s*\*\s*86_400/);

  // Accounts page integrates droplet and server telemetry
  assert.match(accountsHtml, /Droplet status/);
  assert.match(accountsHtml, /Private admin backups/);
  assert.match(accountsHtml, /Monthly transfer/);
  assert.match(accountsHtml, /account-card-grid/);
});
