# Metadata Browser

## Display

Open a `.uac` package to browse its SPC members in a sortable playlist-style
table. Columns show title, artist, album, year, genre, length, and original
filename; missing metadata is shown as an em dash. Search covers those common
tags as well as names and paths. Selecting a row opens its detail inspector,
including original path, extensions, and identity hashes. The inspector keeps
shared soundtrack/game metadata separate from track-specific metadata.

The table's checkbox column is for multi-track batch selection and is
independent of the active detail row. The exhaustive arbitrary-field and raw
JSON editors remain available in the inspector; the raw JSON disclosure is
labeled beta.

## Editing and import

Metadata maps have a key/value editor with Text and JSON values, plus an
"Exhaustive JSON · beta" view for nested or unusual structures. Game/member
extensions remain editable as JSON. Batch Edit supports setting a field,
filling only missing values, find-and-replace within a field, or removing a
field from the selected tracks. Save and Revert apply to the whole unsaved
manifest draft.

Harvest Tags reads SPC ID666/xID6 through MetaMan. It retains ordered duplicate
tags, technical facts, diagnostics, and raw-block byte counts in per-track
metadata. Original ID666/xID6 bytes stay inside the unchanged SPC member and
are not duplicated in the manifest. Track-specific projections stay on each
member; shared soundtrack facts are promoted only when every inspected track
has the same non-empty value. The default import fills missing fields.
Replacing existing values is an explicit, reversible-before-save action.

Harvesting currently requires a seekable `tar+zstd-seekable` UAC. Neither
harvesting nor metadata editing changes native SPC member bytes. Save rewrites
the manifest only and verifies that the compressed payload is preserved
byte-for-byte.

## Files

- `Application/Sources/UACManApp/ContentView.swift`
- `Application/Sources/UACManApp/MetadataObjectEditor.swift`
- `Application/Sources/UACManApp/UACManModel.swift`
- `Application/Sources/UACManCore/SPCMetadataHarvester.swift`
- `Application/Sources/UACManCore/SPCMetadataProjection.swift`
