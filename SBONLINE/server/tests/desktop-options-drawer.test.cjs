// Regression checks for the redesigned SBONLINE desktop options & EQ drawer.
const { readFileSync } = require('node:fs');
const assert = require('node:assert/strict');
const { test } = require('node:test');

const serverDir = `${__dirname}/..`;
const baseHtml = readFileSync(`${serverDir}/templates/accounts/base.html`, 'utf8');
const sbThemeCss = readFileSync(`${serverDir}/static/accounts/sb-theme.css`, 'utf8');
const sitePlayerJs = readFileSync(`${serverDir}/static/accounts/site-player.js`, 'utf8');

test('desktop options drawer imports mobile card, switch, and segmented EQ design', () => {
  assert.match(baseHtml, /class="sbo-drawer-eq-toolbar"[^>]*aria-label="Equalizer Presets"/);
  assert.match(baseHtml, /data-equalizer-mode="off"/);
  assert.match(baseHtml, /data-equalizer-mobile-profile="\{\{ forloop\.counter0 \}\}"/);
  assert.match(baseHtml, /data-equalizer-mobile-save>Save to Preset 1</);
  assert.match(baseHtml, /id="site-player-volume-value"[^>]*>100%</);
  assert.match(baseHtml, /id="spcboy-equalizer-enabled"[^>]*hidden/);

  assert.match(sbThemeCss, /--sb-drawer-card:\s*#181d22;/);
  assert.match(sbThemeCss, /--sb-drawer-accent:\s*#38aaff;/);
  assert.match(sbThemeCss, /#spcboy-settings-panel \.spcboy-settings-group[\s\S]*border-radius:\s*10px/);
  assert.match(sbThemeCss, /#spcboy-settings-panel \.sbo-drawer-eq-toolbar/);
  assert.match(sbThemeCss, /#spcboy-settings-panel \.sbo-drawer-eq-btn:is\(\.is-active,\[aria-pressed="true"\]\)/);
  assert.match(sbThemeCss, /#spcboy-settings-panel \.spcboy-long-play-toggle:is\(\.is-enabled,\[aria-checked="true"\]\)/);
});

test('desktop speed validation error is visible and decimal fractions are allowed', () => {
  assert.doesNotMatch(baseHtml, /id="spcboy-speed"[^>]*pattern=/);
  assert.match(baseHtml, /<span class="spcboy-setting-error" id="spcboy-speed-error"/);
  assert.match(sbThemeCss, /#spcboy-settings-panel \.spcboy-setting-error:not\(:empty\)/);
});

test('site-player syncs segmented OFF/1/2/3 EQ toolbar and percentage volume badge', () => {
  assert.match(sitePlayerJs, /volumeValue\.textContent = `\$\{percent\}%`;/);
  assert.match(sitePlayerJs, /equalizerModeButtons\.forEach\(\(button\) =>/);
  assert.match(sitePlayerJs, /const isActive = isOff \? !equalizerEnabled : \(equalizerEnabled && Number\(mode\) === selectedEqualizerPresetIndex\);/);
  assert.match(sitePlayerJs, /if \(!equalizerEnabled\) setEqualizerEnabled\(true\);/);
  assert.match(sitePlayerJs, /animateEqualizerBandSliders/);

  const catalogWorkspaceHtml = readFileSync(`${serverDir}/templates/accounts/partials/spcboy_catalog_workspace.html`, 'utf8');
  assert.match(baseHtml, /<h3 id="spcboy-play-speed-heading">Slow Play<\/h3>/);
  assert.match(baseHtml, /<strong>Slow Play<\/strong>/);
  assert.match(catalogWorkspaceHtml, /aria-label="Slow Play disabled"/);
  assert.match(sitePlayerJs, /updateBooleanSettingsToggle\(speedEnabledToggle,\s*playbackSpeedEnabled,\s*"Slow Play"\)/);
});
