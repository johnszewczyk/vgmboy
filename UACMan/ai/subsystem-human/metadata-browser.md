# UAC Collection and Tag Browser

## Browse collections

The workspace has a collection rail, sortable member grid, and full-width
metadata workspace. The compact app header owns page navigation, collection and
package actions, and the Tracks/Files search field. The open package filename
and path live in the left side of the universal status bar.

Choose **Open Collection** and select a folder. UACMan recursively lists
regular `.uac` files beneath it, ordered by the package title in each manifest.
The filter above the collection list searches title, platform, package ID, and
relative path. Each row shows its platform, playable-member and total-member
counts, and path. Unreadable package manifests
remain visible in an error disclosure with the path and reader error.

This is a live filesystem view, not a saved database or media-library manager.
UACMan reads the bounded UAC manifest and validates wrapper/seek-table
structure; it does not decompress or extract TAR/audio payloads to populate the
list. Finder displays macOS's generic document icon for `.uac` files. Hidden files and
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
**Tracks**, **Track Tags**, **New Tag**, and **Tag Analyzer**. UAC conversion
profiles are published and edited in the VGMManDocs [UACMan Profiles]
(../../../VGMManDocs/Docs/md/UACMan/Profiles/README.md); they are not part of
the package editor.
**Tracks**
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
scrollable canonical track list with canonical-cell selection controls and a
canonical tag editor. Track selection cells show **−** when clear and **✓**
when selected. The target selector applies a string tag to **All Tracks**,
**Selected Tracks**, or the **Package**. When a collection is loaded, each
collection entry also has a separate selection control; choose **Selected
Packages** to edit package-level tags across those packages. Its **Operation**
supports **Set value**, **Fill missing**, or **Remove**. Search filters the
track list without clearing track or package selections. Track tag additions
are applied atomically and refused if the tag already exists on any target
track. Collection package edits are staged until **Save changes** and can be
discarded with **Revert changes**. **Pack Tags** contains the
package-level tag table, a final inline draft row marked with **＋**, and the
attachments table. Structural package attachment references remain in the
manifest but do not appear as tag rows; their member files appear in the
attachments table. A `.txt` document is labeled **Text File** there. Each table
title is part of its own canonical grid rather than a separate decorative
section heading. Non-string
values in Pack Tags and Track Tags use `[Nested Tags]` to open the recursive
canonical JSON table. The **Nested Tables** option controls how those tables
appear: **Staircase** aligns each child table with its parent’s second column,
**Seamless** keeps the current flush inline look, **Spaced** adds blank space
around an inline table, and **Pop-up** centers it over a dimmed, scrollable
window-sized layer. Arrays and objects reuse the same table at every depth;
JSON-encoded strings remain strings when saved. The wide Tracks giga-table
keeps its own dimmed popup for structured JSON so its row geometry remains
fixed.
When a single UAC is opened directly, the library rail collapses automatically;
it returns when a collection is opened. The last existing UAC or collection path
is restored on launch when no command-line document was supplied.

## Appearance options

Choose **Options…** from the app menu or press **⌘,** to open the native
appearance window. The **System**, **Light**, and **Dark** controls immediately
set the workspace appearance; System follows macOS. Light and dark palettes
can be edited separately, and each color accepts 3/6 digit hex, an RGB triplet,
or a CSS named color. The table title-bar background has its own color setting.
The same window adjusts interface and table font sizes, the corner radii of
table frames and cells, and the display style for nested tables. These
preferences are stored in UACMan's local app preferences; they are not written
to UAC manifests.

**Tag Analyzer** (Beta) is a separate workspace page that works with or without
an open package. **Browse** selects and saves a folder path. The magnifier
button starts scanning its regular `.uac` packages recursively. The selected
folder path is restored when UACMan launches again. The app-bar search filters package filenames in the
current analyzer results; matching tag names and their pack/track counts update
with the filter.

The analyzer lists tag field names from package metadata, package extensions,
every member's metadata, and member extensions. Structural package attachment
references are not tags and do not appear in this list; extension names are
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
row, which folds the table when clicked. Any nested row can unfold another
canonical table,
without a fixed nesting depth. Multiple unfolds on one row nest in their
declared order; opening a deeper level opens its ancestors, and closing a table
closes its unfolded descendants. The parent table's **×** action removes every
occurrence of that tag name from playable tracks in packages matching the
current filename filter. It asks for confirmation, reports progress, and
rewrites each affected package manifest once; package-level fields are not
targets.

When a field value is a JSON array or object, its **Tag Value** cell shows
`[Nested Tags]` and opens the same nested canonical table pattern. A string
containing a JSON array or object opens the same way and remains a string when
saved. Each level can contain scalars, arrays, and objects, with no designed
nesting-depth limit. The expanded title shows the full path and child count;
the parent cell keeps the `[Nested Tags]` label and the standard fold control.
Use **＋** to add a string,
**123** to add a JSON scalar, **{}** to add an object, **[]** to add an array,
and **×** to remove an entry.
These edits stay in the field editor until its **✓** saves the whole value.

The ✓ action updates one manifest field; the nested × removes that one field
after confirmation. Both preserve the archive's compressed members. Progress
reports folder discovery and package reads, and **×** stops the scan. Cancelling
clears the incomplete list. Unreadable folders or packages are reported, and
their presence marks the result as potentially incomplete.

New projected and authored tag names are stored in Title Case. Standard UAC
structure keeps its contract spelling for attachment references such as
`game.metadata.cue_sheet`. Package set facts use the direct Title Case tags
**Set Collection**, **Set Name**, and **Set URL**, with optional **Set Legacy
URL**, **Set Archive URL**, and **Set Date**. The Tag Analyzer reports the
exact stored tag name, including legacy casing, so it can audit old manifests
without rewriting them.

## Editing and import

Pack Tags edits use canonical table rows; its final draft row adds a
package-level string tag, and existing rows can be renamed, edited, submitted,
or deleted. Press **Enter** in a single-line editable text field to invoke
that row's normal **✓** action. This applies to editable tag rows, file-tag
rows, nested-value rows, Tag Analyzer matches, and the New Tag draft. Disabled
and read-only fields do not submit; multiline JSON editors keep Enter for line
breaks. The **New Tag** page
adds one string tag to a chosen package or track scope; selected-track mode
requires at least one selected track. With a collection open, selected-package
mode edits only the package metadata map in
each selected `.uac` manifest. **Set value** adds or replaces the named field,
**Fill missing** preserves existing non-empty values, and **Remove** deletes
that package field. These changes share the normal Save/Revert controls; saving
reopens and validates each changed package and preserves every compressed
payload.
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

The GUI treats the UAC manifest as the complete source of displayed metadata.
Opening a package, selecting a member, and browsing a collection read manifest
records only; the GUI does not inspect or parse member contents. Source-format
metadata is read by the separate UACMan command-line tooling through MetaMan
before packages are created or converted.

MetaMan remains the command-line tool and MetaManCore owns format parsing.
UACMan is part of the VGMMan project and presents the UAC-specific collection
and tag workflow; downstream projects such as AudioMan may call its CLI but do
not own the application or wrapper. UACMan does not provide playback.

## Files

- `Application/Sources/UACManApp/ContentView.swift`
- `Application/Sources/UACManApp/UACManApp.swift`
- `Application/Sources/UACManApp/UACManOptionsView.swift`
- `Application/Sources/UACManApp/UACManWebWorkspace.swift`
- `Application/Sources/UACManApp/Resources/index.html`
- `Application/Sources/UACManApp/Resources/workspace.css`
- `Application/Sources/UACManApp/Resources/workspace.js`
- `Application/Sources/UACManApp/UACManModel.swift`
- `Application/Sources/UACManApp/ZstandardCLIManifestCodec.swift`
- `Application/Sources/UACManCore/UACCollectionScanner.swift`
- `Application/Sources/UACManCore/UACManSkinPreferences.swift`
- `Application/Sources/UACManCore/UACManifestEditor.swift`
- `Application/Sources/UACManCore/SPCMetadataHarvester.swift`
- `Application/Sources/UACManCore/SPCMetadataProjection.swift`
- `Application/Resources/Info.plist`
- `Application/AppIcon/UACManAppIcon.png`
- `Application/AppIcon/build_app_icns.py`
- `Application/AppIcon/UACManAppIcon.icns`
- `Application/launch.sh`
