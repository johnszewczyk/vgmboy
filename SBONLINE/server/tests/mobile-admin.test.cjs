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
  assert.match(mobileShellHtml, /\{% if request\.user\.is_superuser %\}<button type="button" class="spcboy-mobile-nav-btn" data-mobile-app-page="admin">Admin<\/button>\{% endif %\}/);
  assert.match(mobileShellHtml, /id="spcboy-mobile-screen-admin"/);
  assert.match(mobileShellHtml, /class="spcboy-mobile-card"[\s\S]*Site Controls/);
  assert.match(mobileShellHtml, /class="spcboy-mobile-card"[\s\S]*Invitations/);
  assert.match(mobileShellHtml, /class="spcboy-mobile-card"[\s\S]*Accounts/);
});

test('spcboy.js integrates nav and admin page switching and spcboy-mobile.css styles admin cards in mobile theme', () => {
  assert.match(spcboyJs, /\["playing", "library", "gallery", "recent", "favorites", "sound", "detail", "nav", "admin"\]/);
  assert.match(spcboyJs, /else if \(nextPage === "admin"\) void loadMobileAdmin\(\);/);
  assert.match(mobileCss, /\.spcboy-mobile-admin-item\s*\{/);
  assert.match(mobileCss, /\.spcboy-mobile-admin-code\s*\{/);
  assert.match(mobileCss, /#spcboy-mobile-app \.spcboy-mobile-vnav > :is\(a, button\)/);
});
