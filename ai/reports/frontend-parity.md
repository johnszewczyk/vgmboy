# Native frontend playback parity

## Rule

Equivalent player behavior should use the same shared policy and VGMBoy command
contract. CocoaSpice, SB2, and ViewBoy retain separate renderers, app
identities, persistence keys, and host adapters; shared contracts do not promise
pixel-identical UI. SPCBoyWK is retired and is not an active parity target.

## Current source boundaries

| Behavior | Shared owner | Frontend responsibility |
| --- | --- | --- |
| Catalog and playlist projection | CatalogReader | Render rows and measure them with frontend fonts. |
| Playlist sorting | `CatalogPlaylistPresentationCore.CatalogPlaylistSorting` | Submit current row records and retain selection while applying ordered IDs. |
| Catalog grouping and search | `CatalogBrowserCore` | Render projected groups and map matching IDs into the sidebar. |
| Playlist-tab order transitions | `FrontendCore.PlaylistTabsPersistenceCore` | Adapt local tab payloads, storage, focus, and final-tab behavior. |
| Archive preparation | FrontendCore | Request playback through each native bridge. |
| Decoder session, timing, and output | VGMBoy | Render status and issue named commands. |
| Queue, transitions, fade eligibility | FrontendCore | Present queue state and local animation. |
| Preferences and playlist layout policy | FrontendCore | Persist local keys and adapt shared values to each renderer. |
| Display and app identity | Each frontend | Keep each app's host, screen renderer, and preferences product-specific. |

## Verification status

This update aligned source ownership and routed ViewBoy playlist sorting,
console grouping, and catalog search through shared policies. It also added the
shared tab-order reducer to CocoaSpice, SB2, and ViewBoy. Package builds,
packaged-app launches, same-catalog interaction checks, and live playback were
not run for this update, so runtime parity remains open.

Compare the exact catalog revision, selected source/member/subtrack, queue
action, and observed transport result before closing a shared-behavior gate. A
package build or a window that merely opens does not establish audio parity.

[`../verification/family.md`](../verification/family.md) contains prior package
results and the clean-checkout procedure. Those historical results do not
verify the source changes in this update.
