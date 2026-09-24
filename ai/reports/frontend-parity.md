# Native frontend playback parity

## Rule

Equivalent player behavior should use the same shared policy and VGMBoy command
contract. CocoaSpice, SPCBoyWK, and ViewBoy retain separate renderers, app
identities, persistence keys, and host adapters; a shared contract does not
promise pixel-identical UI.

## Current evidence and open checks

| Boundary | Current evidence | Remaining user-boundary check |
| --- | --- | --- |
| Shared policy | FrontendCore and CatalogReader package suites pass in the clean checkout recorded in `../verification/family.md`. | VGMBoy's AAC and live-output checks need working host audio services. |
| CocoaSpice | Package tests pass. | Launch the current bundle with a schema-24 catalog and exercise selection, queue, and playback through the visible UI. |
| SPCBoyWK | Package build and renderer tests pass. | Repeat the same catalog and archive fixture through the packaged WebKit player. |
| ViewBoy | Production bundle builds and renderer tests pass. | Select the same catalog and exercise a live playback fixture in the packaged app. |

No current three-app, same-fixture parity run is recorded. Compare the exact
catalog revision, selected source/member/subtrack, queue action, and observed
transport result before closing a shared-behavior gate. A package test or a
window that merely opens does not establish audio parity.

## Shared boundary

| Behavior | Shared owner | Frontend responsibility |
| --- | --- | --- |
| Catalog and playlist projection | CatalogReader | Render rows and apply explicit user sorting. |
| Archive preparation | FrontendCore | Request playback through each native bridge. |
| Decoder session, timing, and output | VGMBoy | Render status and issue named commands. |
| Queue, transitions, fade eligibility | FrontendCore | Present queue state and local animation. |
| Preferences and playlist layout policy | FrontendCore | Persist local keys and adapt shared values to each renderer. |
| Display and app identity | Each frontend | Keep native/WebKit/Metal presentation and preferences product-specific. |

[`../verification/family.md`](../verification/family.md) contains the package
results and clean checkout procedure. This report tracks the cross-app user
boundary.
