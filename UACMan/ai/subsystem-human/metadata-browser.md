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

Selecting a package opens its playable tracks in the primary **Tracks** view.
The member filter searches visible metadata values, role, format, filename, and
path. Tracks stays an inline field grid: scalar cells edit in place and structured
cells open a centered plain-text Multiple Values popup so the wide table remains
easy to navigate. Batch tag edits live in
the **Track Tags** browser, so Tracks does not carry a separate checkbox
selection model. The Tracks table includes both the display track number and the
literal source filename as its first two columns. Scalar values are editable;
structured values show a stable Multiple Values placeholder and open as plain
text in a popup. Aggregate rows with different structured values remain
read-only until a single value is unambiguous.

The workspace has four explicit pages in this order: **Files**, **Pack Tags**,
**Tracks**, and **Track Tags**. Sub-pages keep their identity in the compact
app header and do not add a second page heading. **Tracks** is the wide canonical
array-style field grid: every header and value is a boxed field, and its
horizontal scroll belongs to the workspace surface rather than a nested table
window. **Files** lists every stored package member, including playable streams,
artwork, cue sheets, and documentation. Its filename field edits the
manifest's displayed/original filename while the stored TAR path remains
immutable. Each row's **Tags** column is a numeric count. The **Track Tags** page
provides a canonical table sidebar and an exhaustive canonical table for editing
that file's metadata/extensions; the sidebar uses the same cells and geometry,
has no extra inset padding, and has no separate new-tag form. Structured values
slide down as full-width, left-aligned child tables inserted beneath the source
row, without indenting the parent table. **Pack Tags** contains package-level metadata and all attachments
using the same field-grid cells, with the same add interface as the tag
workspace. Pack Tags and the selected-file Track Tags table use the inserted
child-table treatment; the master Tracks grid uses the centered text popup
because of its width. UACMan lists assets and their metadata. The Files page can preview recognized text
members directly from the seekable payload, including JSON, Markdown, CUE, and
similar documents; it does not extract or edit them yet, and it does not preview
binary image bytes.
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
Multiple Values popup
**Open JSON editor** escape hatch remains available for advanced or nested
edits. Pack Tags and the selected-file Track Tags table use canonical child
subtables inserted at the parent table's level. Each child table has the same
key/value/✓/× action columns as its parent: the header ✓ submits all current
rows, each row ✓ submits the edited structured value, and the header × closes
the child table. The wide Tracks grid uses a plain centered editable JSON
popup for structured values so nested JSON cannot change the giga-table's row
geometry; malformed JSON is rejected without closing or submitting the popup.
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
