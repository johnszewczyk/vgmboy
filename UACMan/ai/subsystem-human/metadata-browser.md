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

The workspace has six explicit pages in this order: **Files**, **Pack Tags**,
**Tracks**, **Track Tags**, **New Tag**, and **Tag Analyzer**. **Tracks**
is the wide canonical giga-table: every header and value is a boxed field, and
its horizontal scroll belongs to the workspace surface rather than a nested
table window. **Files** lists every stored package member, including playable
streams, artwork, cue sheets, and documentation. Its filename field edits the
manifest's displayed/original filename while the stored TAR path remains
immutable. Each row's **Tags Count** column is numeric. A fixed-width **⌕**
column is blank for binary members and shows a magnifier for supported text
attachments. The button opens a read-only viewer for recognized UTF-8 or UTF-16
text (including JSON, Markdown, and cue sheets), limited to the first 4 MiB.
Pack Tags' attachment table uses the same canonical **⌕** column and viewer.
All page tables use the same rounded canonical frame and inset. The **Track Tags** page provides two
independent scroll panes, each containing the canonical field-grid table: a
three-column tagged-file table on the left and an exhaustive metadata table on
the right. They share the same cells and geometry, with no merged
sidebar/content bar. The left table is a compact, auto-height canonical table;
its frame does not fill the page when it has only a few rows. **New Tag** pairs a
scrollable canonical track list with checkboxes and a canonical draft table.
The target selector applies the new string tag to **All Tracks**, **Selected
Tracks**, or the **Package**. Search filters the track list without clearing
checkbox selections. Batch track additions are applied atomically and refused
if the tag already exists on any target track. **Pack Tags** contains the
package-level tag table, a final inline draft row marked with **＋**, and the
attachments table. Each table title is part of its own canonical grid rather
than a separate decorative section heading. Non-string
values in Pack Tags and Track Tags use `[Nested Tags]` to open an animated,
full-width inserted canonical subtable. Only the wide Tracks giga-table uses a
dimmed popup for structured JSON, so its row geometry remains fixed.
When a single UAC is opened directly, the library rail collapses automatically;
it returns when a collection is opened. The last existing UAC or collection path
is restored on launch when no command-line document was supplied.

**Tag Analyzer** (Beta) is a separate workspace page that works with or without
an open package. **Browse** selects a folder and immediately scans
its regular `.uac` packages recursively. The selected folder path is restored
when UACMan launches again. The app-bar search filters package filenames in the
current analyzer results; matching tag names and their pack/track counts update
with the filter.

The analyzer lists exact tag field names from package metadata, package
extensions, every member's metadata, and member extensions; extension names are
shown with the `extension.` namespace. Its canonical numbered table shows the
number of matching packs and playable tracks for each field. A pack counts once
per field even when that field appears in multiple places in its manifest.
Matches are by exact field name, not by value, so one field such as **Source
RSN** can match multiple packages with different values. Opening a matched-pack
count expands an animated canonical table with each package filename, track
count, and a **Tag Fields** expander. Each pack row opens another animated
canonical table with **#**, **Track**, **Tag Name**, **Tag Value**, **✓**, and
**×** columns. Track filenames occupy their own cells; package-level fields
show **Package** in the Track column. Both nested tables use the shared title
row and close control. The parent table's **×** action removes every occurrence
of that tag name from playable tracks in packages matching the current filename
filter. It asks for confirmation, reports progress, and rewrites each affected
package manifest once; package-level fields are not targets.

The ✓ action updates one manifest field; the nested × removes that one field
after confirmation. Both preserve the archive's compressed members. Progress
reports folder discovery and package reads, and **Cancel** stops the scan. Cancelling
clears the incomplete list. Unreadable folders or packages are reported, and
their presence marks the result as potentially incomplete.

The shared game metadata may use flat camelCase set fields such as `setName`,
`setUrl`, and `setCollection` for a concise source-set summary. The complete
source records remain in the manifest's Sources section. UACMan does not require
camelCase or reject other key casing: metadata maps preserve arbitrary
case-sensitive JSON keys, while camelCase remains the convention for shared
fields. Nested values remain available when they carry real structure, but a
simple set summary should not be nested needlessly.

## Editing and import

Pack Tags edits use canonical table rows; its final draft row adds a
package-level string tag, and existing rows can be renamed, edited, submitted,
or deleted. The **New Tag** page adds one string tag to a chosen package or
track scope; selected-track mode requires at least one checked track.
Structured values remain editable through the small-table inserted
subtable or the giga-table popup, using canonical title and action rows.
Malformed JSON is rejected without closing or submitting the popup or
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
- `Application/AppIcon/UACManAppIcon.png`
- `Application/AppIcon/build_app_icns.py`
- `Application/AppIcon/UACManAppIcon.icns`
- `Application/launch.sh`
