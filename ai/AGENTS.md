# AGENTS

## Scope

Document current package ownership and invariants. FrontendCore has no user-
facing UI, so its default routes are agent engineering notes.

## Engineering Rules

- Keep targets UI-neutral: do not import AppKit, SwiftUI, WebKit, or Electron.
- Do not add catalog writes, scanner orchestration, decoder implementations, or
  audio-device ownership.
- Prefer typed values and injected operations over frontend-specific models,
  persistence keys, executable paths, or presentation errors.
- Preserve independent tests for every public target.
- Keep migration plans and parity ledgers in the VGMMan coordination directory,
  not in `project-info.md`.

