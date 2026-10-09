# Selection and Hover Motion

## Scope

SB2's shared animated selector for interactive items in the main app shell.

## Ownership

- `app-ui.js` tracks the hovered target, keyboard-focused target, and logical
  selections such as the active playlist row and selected sidebar row.
- `index.html` owns the single indicator element. `styles.css` owns its
  geometry transition, inverse foreground treatment, and reduced-motion rule.
- The existing `selectionAnimationEnabled` and
  `selectionAnimationMilliseconds` preferences control its transition timing.
  Keep the preference namespace and persistence contract unchanged.

## Invariants

- Keep one active indicator per WebKit view. The main view places it inside
  `.app-shell`; the standalone Options view places it inside `.options-panel`.
  This lets it travel across each view without changing either layout.
- The indicator is decorative and ignores pointer events. The current target
  is raised above it and receives the inverse text treatment; do not change the
  underlying layout or target dimensions.
- Pointer hover takes precedence over the last logical selection. Keyboard
  focus and programmatic playlist/sidebar selection update the logical target.
- Calculate target geometry from `getBoundingClientRect()` and clip it to the
  app shell and every scrolling or clipping ancestor. Reposition immediately
  during scroll, resize, and sidebar dragging so the marker stays attached.
- Preserve the playlist's separate one-pixel selected-row underline. The
  shared selector is a surface treatment and does not replace track selection
  state or change playback behavior.
- Honor the UI setting that disables selection motion and the system reduced
  motion preference.
- The main Options overlay uses the same configured motion duration for its
  top-down entrance and exit. Keep it inert and hidden from accessibility while
  closed, and restore focus to its opener when dismissed. Its stacking layer
  must cover home controls and popovers, including the volume popup, while the
  inset app title and status bars remain visible.
- Keep the standalone Options window's overlay outside the hidden main shell.
  Do not relocate its controls into `.content` when the native options-window
  flag is set.

## Files

- `Sources/SB2/Resources/index.html`
- `Sources/SB2/Resources/styles.css`
- `Sources/SB2/Resources/app-ui.js`
- `ai/subsystem-human/home.md`
- `ai/subsystem-human/options.md`
