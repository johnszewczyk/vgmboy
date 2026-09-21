# UAC Collection and Tag Browser

## Browse collections

The workspace has a collection rail, sortable member grid, and full-width
metadata workspace. The compact app header owns page navigation, collection and
package actions, and the Tracks/Files search field. The open package filename
and path live in the left side of the universal status bar.

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

Selecting a package opens its playable tracks in the primary **Tracks** view.
The member filter searches visible metadata values, role, format, filename, and
path. Tracks stays an inline field grid: scalar cells edit in place and structured
cells open a centered plain-text `[Nested Tags]` popup so the wide table remains
easy to navigate. Batch tag edits live in
the **Track Tags** browser, so Tracks does not carry a separate checkbox
selection model. The Tracks table includes both the display track number and the
literal source filename as its first two columns. Scalar values are editable;
structured values show a stable `[Nested Tags]` placeholder and open as plain
text in a popup. Aggregate rows with different structured values remain
read-only until a single value is unambiguous.

The workspace has four explicit pages in this order: **Files**, **Pack Tags**,
**Tracks**, and **Track Tags**. Pages have no secondary page heading. **Tracks**
is the wide canonical giga-table: every header and value is a boxed field, and
its horizontal scroll belongs to the workspace surface rather than a nested
table window. **Files** lists every stored package member, including playable
streams, artwork, cue sheets, and documentation. Its filename field edits the
manifest's displayed/original filename while the stored TAR path remains
immutable. Each row's **Tags** column is a numeric count, and recognized text
members open in a compact canonical popup. All four page tables use the same
rounded canonical frame and inset. The **Track Tags** page provides two
independent scroll panes, each containing the canonical field-grid table: a
three-column tagged-file table on the left and an exhaustive metadata table on
the right. They share the same cells and geometry, with no merged
sidebar/content bar and no separate new-tag form. The left table is a compact,
auto-height canonical table; its frame does not fill the page when it has only a
few rows. **Pack Tags** contains package-level metadata and all attachments using
the same field-grid cells and add interface as the tag workspace. Non-string
values in Pack Tags and Track Tags use `[Nested Tags]` to open an animated,
full-width inserted canonical subtable. Only the wide Tracks giga-table uses a
dimmed popup for structured JSON, so its row geometry remains fixed.
When a single UAC is opened directly, the library rail collapses automatically;
it returns when a collection is opened. The last existing UAC or collection path
is restored on launch when no command-line document was supplied.

The shared game metadata may use flat camelCase set fields such as `setName`,
`setUrl`, and `setCollection` for a concise source-set summary. The complete
source records remain in the manifest's Sources section. UACMan does not require
camelCase or reject other key casing: metadata maps preserve arbitrary
case-sensitive JSON keys, while camelCase remains the convention for shared
fields. Nested values remain available when they carry real structure, but a
simple set summary should not be nested needlessly.

## Editing and import

Per-field edits use typed rows: **Add column** creates a text, number, boolean,
or JSON field, and removing a row removes that manifest field. A centered
`[Nested Tags]` popup and its **Open JSON editor** escape hatch remain
available for advanced or nested edits. The giga-table popup title row carries
the tag name, header ✓ submits the full JSON value, and header × closes it.
Small-table inserted subtables use the same title/action row inside the parent
table. Malformed JSON is rejected without closing or submitting the popup or
subtable.
The table headers are ordinary rows rather than sticky overlays. Native macOS
title-bar controls remain visible for the UACMan window.
An aggregate row is read-only when it combines
different source values. Save reopens and
verifies the wrapper, then preserves the compressed payload byte-for-byte.
Files cannot be physically removed or have their stored TAR paths renamed in
this payload-preserving editor; those operations require a separate repack
workflow.
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
