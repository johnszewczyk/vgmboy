# Native frontend playback parity

## Rule

Equivalent player behavior should use the same shared policy and VGMBoy command
contract. CocoaSpice, SPCBoyWK, and ViewBoy retain separate renderers, app
identities, persistence keys, and host adapters; a shared contract does not
promise pixel-identical UI.

## Current evidence — 2026-09-16

| Boundary | Evidence | Remaining gap |
| --- | --- | --- |
| Shared policy | FrontendCore: 84 tests pass. VGMBoy shared playback tests: 68/72 pass. | Four host-dependent AudioToolbox/live-output assertions remain unresolved; see `verification.md`. |
| CocoaSpice | 58 package tests pass. | A new packaged UI/playback check was not performed in this run. |
| SPCBoyWK | Package build passes; syntax checks and all 65 renderer/transport tests pass. | This run did not repeat a live archive fixture through the visible player. |
| ViewBoy | Production app bundle builds; syntax checks and all 22 renderer/transport tests pass; window opened with library and transport controls visible. | No catalog was selected and no audio fixture was played. |
| ScanSong / LaunchPad | ScanSong package tests pass; its release app bundle builds/signature verifies; the running UI shows the schema-23 catalog. LaunchPad rebuild succeeds and all 16 configuration paths/build scripts validate. | LaunchPad refreshed-window automation timed out; no row-driven launch was repeated because ScanSong was already running. |

## Shared boundary

| Behavior | Shared owner | Frontend responsibility |
| --- | --- | --- |
| Catalog and playlist projection | CatalogReader | Render rows and apply explicit user sorting. |
| Archive preparation | FrontendCore | Request playback through each native bridge. |
| Decoder session, timing, and output | VGMBoy | Render status and issue named commands. |
| Queue, transitions, fade eligibility | FrontendCore | Present queue state and local animation. |
| Preferences and playlist layout policy | FrontendCore | Persist local keys and adapt shared values to each renderer. |
| Display and app identity | Each frontend | Keep native/WebKit/Metal presentation and preferences product-specific. |

`verification.md` contains the package results and commands. This document
tracks the cross-app user boundary only; it is not a run log.
