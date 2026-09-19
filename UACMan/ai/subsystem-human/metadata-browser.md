# UAC Collection and Tag Browser

## Browse collections

The workspace has a collection rail, sortable member grid, and full-width
metadata workspace. Its top action bar opens a collection or package and exposes
Revert and Save; those actions stay available while the grid scrolls.

Choose **Open Collection** and select a folder. UACMan recursively lists
regular `.uac` files beneath it, ordered by the package title in each manifest.
The filter above the collection list searches title, system, package ID, and
relative path. Each row shows its system, playable-member and total-member
counts, and path. Unreadable package manifests
remain visible in an error disclosure with the path and reader error.

This is a live filesystem view, not a saved database or media-library manager.
UACMan reads the bounded UAC manifest and validates wrapper/seek-table
structure; it does not decompress or extract TAR/audio payloads to populate the
list. Finder displays UACMan's document icon for `.uac` files. Hidden files and
symbolic links are skipped. Choose **Open UAC** to open a single package
without scanning its parent folder.

Selecting a package opens every member in the center grid, including playable
streams, artwork, cue sheets, and documentation. The checkbox column selects
members independently of the active row. The member filter above the table searches all visible metadata values, role,
format, filename, and path. The Tracks page builds dense scalar tag columns from
playable members; attachments and structured metadata stay out of the audio rows
and are shown in their scoped pages.
Selecting a package uses six explicit pages. **Tracks** is the primary view: it
filters to playable audio members and presents scalar tags as editable fixed-width
columns, one compact row per track. Its heading line carries the shown/audio count
and the right-aligned filter; clicking any column header sorts the visible rows.
The first column is checkbox-only, with an all/none checkbox in its header. The
Track column is the display track number;
the source filename remains available as a tooltip and in the scoped track page.
Track columns size themselves from the longest loaded header or value and ease
to the new width over 200 ms. In **Meta Tags**, Example shows the shared value
when all uses agree and `Varies · N values` otherwise; structured values remain
compact `Object · N` or `List · N` entries.
Attachments never appear as fake audio rows. **Package tags** contains set-level
fields and a separate attachment list. **Track Tags** contains only the selected
track's fields. **Technical** is a dedicated table for hashes, source facts, and
diagnostics. **Meta Tags** inventories top-level names and renames them throughout
the package draft, including Package or All Tracks creation and deletion. **Tree** is a plain folding dictionary for
the set and tracks, with scalar `key : value` rows editable in place and the same
compact Key/Value/Type table treatment as Tracks. Technical fields stay on the
Technical page; structured objects and lists
are represented by counts until a scoped editor is chosen. Raw JSON is available
only through the collapsed advanced editor. This keeps a set-level image or
document attached to the set rather than repeating it on every track. Hovering
the path reveals its exact stored UAC member path. UACMan lists assets and their
metadata; it does not yet preview image bytes inside the compressed payload.
When a single UAC is opened directly, the library rail collapses automatically;
it returns when a collection is opened. The last existing UAC or collection path
is restored on launch when no command-line document was supplied.

The shared game metadata can include a `set` object with `collection`, `name`,
and `url` for the source set and its official distributor. The complete source
records remain in the manifest's Sources section. UACMan only adds this summary
when the source records resolve to one set and a known URL; it does not guess
when provenance is incomplete or conflicting.

## Editing and import

Per-field edits use typed rows: **Add column** creates a text, number, boolean,
or JSON field, and removing a row removes that manifest field. A collapsed
**Open JSON editor** escape hatch remains available for advanced or nested
edits. Save reopens and
verifies the wrapper, then preserves the compressed payload byte-for-byte.
Revert discards unsaved manifest changes.
Saving refuses to overwrite a package that changed on disk after it was opened.

For SPC packages, native ID666/xID6 harvesting reads embedded members through
MetaMan and requires a seekable `tar+zstd-seekable` payload. It retains ordered
duplicate tags, technical facts, diagnostics, and raw-block byte counts in
per-track metadata. Original ID666/xID6 bytes remain inside the unchanged SPC
member; they are not duplicated in the manifest. The default import fills
missing fields. Replacing existing values is explicit and remains reversible
before Save. Shared soundtrack facts are promoted only when every inspected
track has the same non-empty value.

MetaMan remains the command-line tool and MetaManCore owns format parsing.
UACMan is part of the VGMMan project and presents the UAC-specific collection
and tag workflow; downstream projects such as AudioMan may call its CLI but do
not own the application or wrapper. UACMan does not provide playback.

## Files

- `Application/Sources/UACManApp/ContentView.swift`
- `Application/Sources/UACManApp/UACManWebWorkspace.swift`
- `Application/Sources/UACManApp/Resources/index.html`
- `Application/Sources/UACManApp/Resources/workspace.css`
- `Application/Sources/UACManApp/Resources/workspace.js`
- `Application/Sources/UACManApp/UACManModel.swift`
- `Application/Sources/UACManApp/ZstandardCLIManifestCodec.swift`
- `Application/Sources/UACManCore/UACCollectionScanner.swift`
- `Application/Sources/UACManCore/UACManifestEditor.swift`
- `Application/Sources/UACManCore/SPCMetadataHarvester.swift`
- `Application/Sources/UACManCore/SPCMetadataProjection.swift`
- `Application/Resources/Info.plist`
- `Application/DocumentIcon/UACDocumentIcon.png`
- `Application/DocumentIcon/build_icns.py`
- `Application/DocumentIcon/UACDocumentIcon.icns`
- `Application/launch.sh`
