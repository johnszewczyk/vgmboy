# CocoaSpice faded skip bypassed by playlist activation

**Status:** Source-level regression fixed; audible behavior still needs live playback verification.

## Symptom

With Faded Skip enabled, Previous and Next used the configured fade, but
activating a playlist row or pressing Return replaced the current track
immediately. An activation made during an existing fade could also cancel the
frontend fade task while the output ramp was in progress.

## Cause

Faded Skip policy already lived in the shared playback queue/transport layers.
`PlayerViewModel` called that policy from its adjacent-track route, while
`PlaylistTableView.activateRow`, Return, and the row transport action went
straight to `requestPlayback`. The playlist entry points therefore bypassed
the shared decision boundary. The behavior came from a missing frontend route,
not from a second decoder or audio implementation.

## Resolution

Manual playlist targets and Previous/Next now pass through one
`requestFadedTrackChange` path. It retains the exact selected row as the fade
target and starts it after the configured fade. Disabled, paused, and
out-of-window requests continue through immediate playback replacement. The
toolbar now presents Previous, Stop, Play/Pause, Next in that order; Stop
cancels an outstanding fade and retires the current transport session.

SPCBoy WK's playlist activation now carries its exact target through the
existing queued-fade completion gate. Its Stop control clears both the pending
skip and its timer before stopping playback.

## Verification

Package builds and JavaScript syntax checks are the source-level checks for
this change. They do not establish that a live audio device audibly completes
the fade or that the packaged toolbar renders correctly.
