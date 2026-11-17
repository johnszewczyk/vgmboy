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
  assert.doesNotMatch(baseHtml, /data-equalizer-mobile-save|Save to Preset/);
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
  assert.match(sitePlayerJs, /if \(!equalizerEnabled\) setEqualizerEnabled\(true(?:,\s*\{\s*deferRestart:\s*true\s*\})?\);/);
  assert.match(sitePlayerJs, /animateEqualizerBandSliders/);

  const catalogWorkspaceHtml = readFileSync(`${serverDir}/templates/accounts/partials/spcboy_catalog_workspace.html`, 'utf8');
  assert.match(baseHtml, /<h3 id="spcboy-play-speed-heading">Slow Play<\/h3>/);
  assert.match(baseHtml, /<strong>Slow Play<\/strong>/);
  assert.match(catalogWorkspaceHtml, /aria-label="Slow Play disabled"/);
  assert.match(sitePlayerJs, /updateBooleanSettingsToggle\(speedEnabledToggle,\s*playbackSpeedEnabled,\s*"Slow Play"\)/);
});

test('desktop Interface drawer exposes desktop font/spacing controls and hides them on mobile', () => {
  const sbInterfaceJs = readFileSync(`${serverDir}/static/accounts/sb-interface.js`, 'utf8');
  const sbMobileCss = readFileSync(`${serverDir}/static/accounts/sb-mobile.css`, 'utf8');
  const mobileShellHtml = readFileSync(`${serverDir}/templates/accounts/partials/spcboy_mobile_shell.html`, 'utf8');

  assert.match(baseHtml, /<strong>Track text size<\/strong><span>Playlist track row font size \(px\)\.<\/span>/);
  assert.match(baseHtml, /<strong>Game list text size<\/strong><span>Library list font size \(px\)\.<\/span>/);
  assert.doesNotMatch(baseHtml, /Mobile track text size|Mobile game list text size/);

  assert.match(sbInterfaceJs, /setProperty\('--sb-playlist-font-size'/);
  assert.match(sbInterfaceJs, /setProperty\('--sb-sidebar-font-size'/);
  assert.match(sbInterfaceJs, /setProperty\('--sb-row-gap'/);
  assert.match(sbInterfaceJs, /setProperty\('--site-motion-duration'/);
  assert.doesNotMatch(sbInterfaceJs, /--sb-mobile-playlist-font-size|--sb-mobile-sidebar-font-size/);

  assert.match(sbMobileCss, /:is\(#spcboy-mobile-tab-interface,\s*#spcboy-settings-page-interface\)\s*\{\s*display:\s*none\s*!important;\s*\}/);
  assert.doesNotMatch(mobileShellHtml, /data-sb-preference=/);
});

test('playback options order is Long Play, Slow Play, Fade Out, EQ OFF resets faders to 0, topbar is eliminated on desktop player, and avatars are removed', () => {
  const mobileShellHtml = readFileSync(`${serverDir}/templates/accounts/partials/spcboy_mobile_shell.html`, 'utf8');
  const spcboyHtml = readFileSync(`${serverDir}/templates/accounts/spcboy.html`, 'utf8');
  const profileHtml = readFileSync(`${serverDir}/templates/accounts/profile.html`, 'utf8');
  const sbonlineCss = readFileSync(`${serverDir}/static/accounts/sbonline.css`, 'utf8');
  const spcboyJs = readFileSync(`${serverDir}/static/accounts/spcboy.js`, 'utf8');

  // Playback options order: Long Play -> Slow Play -> Fade Out
  const desktopLongPlayIdx = baseHtml.indexOf('id="spcboy-long-play-heading"');
  const desktopSlowPlayIdx = baseHtml.indexOf('id="spcboy-play-speed-heading"');
  const desktopFadeOutIdx = baseHtml.indexOf('id="spcboy-fade-out-heading"');
  assert.ok(desktopLongPlayIdx > 0 && desktopSlowPlayIdx > desktopLongPlayIdx && desktopFadeOutIdx > desktopSlowPlayIdx);

  const mobileLongPlayIdx = mobileShellHtml.indexOf('id="spcboy-mobile-long-play"');
  const mobileSlowPlayIdx = mobileShellHtml.indexOf('id="spcboy-mobile-speed-enabled"');
  const mobileFadeOutIdx = mobileShellHtml.indexOf('id="spcboy-mobile-faded-skip"');
  assert.ok(mobileLongPlayIdx > 0 && mobileSlowPlayIdx > mobileLongPlayIdx && mobileFadeOutIdx > mobileSlowPlayIdx);

  // EQ OFF moves sliders to default (0.0) positions on desktop and mobile
  assert.match(sitePlayerJs, /const gain = equalizerEnabled \? \(equalizerBandGains\[index\] \|\| 0\) : 0;/);
  assert.match(sitePlayerJs, /animateEqualizerBandSliders\(flatGains,\s*async\s*\(\)\s*=>\s*\{\s*await setEqualizerEnabled\(false\);/);
  assert.match(spcboyJs, /const gains = eqEnabled \? rawGains : Array\(10\)\.fill\(0\);/);
  assert.match(spcboyJs, /animateMobileFaders\(Array\(10\)\.fill\(0\)/);

  // Desktop top-most toolbar eliminated on spcboy-body, settings button nested in playlist heading, queue button discarded
  assert.match(sbonlineCss, /body\.spcboy-body\s*\{[\s\S]*--site-navigation-height:\s*0px;/);
  assert.match(sbonlineCss, /body\.spcboy-body \.topbar\s*\{\s*display:\s*none\s*!important;\s*\}/);
  assert.match(sitePlayerJs, /if \(playlistHeading && !mobileControlsQuery\.matches\)\s*\{\s*playlistHeading\.append\(actionsSlot\);/);
  assert.match(baseHtml, /id="site-player-queue-toggle"[^>]*hidden/);
  assert.match(sbThemeCss, /\.sbonline-site \.site-player-queue-toggle\s*\{\s*display:\s*none\s*!important;\s*\}/);

  // Intuitive fold/unfold icon & toggle
  assert.match(spcboyHtml, /id="icon-fold-all"[^>]*><path d="m7 4 5 5 5-5M4 12h16M7 20l5-5 5 5"/);

  // Compact single-row drawer header, in-drawer Admin tab, & profile picture removal
  assert.match(baseHtml, /class="spcboy-settings-header-main"/);
  assert.match(baseHtml, /id="spcboy-mobile-tab-admin"[^>]*data-settings-page-target="admin"/);
  assert.match(baseHtml, /id="spcboy-settings-page-admin"[^>]*data-settings-page="admin"/);
  assert.match(sitePlayerJs, /async function loadDrawerAdmin\(\)/);
  assert.doesNotMatch(baseHtml, /drawer-identity-avatar/);
  assert.doesNotMatch(profileHtml, /avatar-cropper|avatar-source/);
});
