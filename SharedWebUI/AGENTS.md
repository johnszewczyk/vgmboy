# Shared WebKit UI controls

This directory owns portable DOM control behavior and structural styling used
by multiple VGMMan WebKit frontends. App layouts, labels, commands, and theme
variables remain in their owning apps. Do not move SwiftUI, AppKit, or Canvas
presentation here.

The checked-in app resource copies are Swift Package bundle inputs. Edit the
canonical source in this directory, then run
`python3 SharedWebUI/sync-range-controls.py`; use `--check` to detect drift.
