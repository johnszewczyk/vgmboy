# Shared WebKit range control

SB2, APPBOY, and the standalone VGMBoy test bench use this DOM control for
range sliders. It keeps the native `<input type="range">` as the focusable,
keyboard-operable control and adds a shared track, fill, and thumb for the
visual layer. Apps keep their own EQ row layout, outputs, commands, and theme.

Mark an EQ input with `data-vgm-range-slider`; the shared script wraps it and
creates the track and thumb. Add `data-vgm-range-zero` when a center marker is
useful. The script also binds existing `.range-slider > input[type="range"]`
controls so their fill follows user input.

App styles can set these variables on `.range-slider`:

- `--range-height`, `--range-track-height`, `--range-track-border`,
  `--range-track-background`, and `--range-track-shadow`
- `--range-fill-color`, `--range-zero-color`, `--range-thumb-size`,
  `--range-thumb-background`, and `--range-thumb-shadow`
- `--range-fill-transition`, `--range-thumb-transition`, and
  `--range-focus-shadow`

The script exposes `window.VGMRangeControls` with `enhance(root)`, `sync(input)`,
and `setPercent(input, percent)` methods. It is loaded from each app's local
SwiftPM resources under that app's WebKit content policy.

Edit these canonical files, then copy the bundle inputs with:

```sh
python3 SharedWebUI/sync-range-controls.py
```

Check copies without modifying them with `--check`.
