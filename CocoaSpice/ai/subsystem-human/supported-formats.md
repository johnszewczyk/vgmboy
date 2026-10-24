# Supported Formats

CocoaSpice admits the formats registered by its bundled VGMBoyKit playback core.
The authoritative extension list, decoder routes, upstream versions, and licenses
are maintained in [VGMBoy's README](../../../VGMBoy/README.md).

## Catalogs and Direct Imports

- A ScanSong catalog controls which library rows and subtracks appear in the
  Database browser. CocoaSpice displays its published metadata unchanged.
- Finder drops and `.m3u` files accept files that VGMBoyKit registers as playable.
  Direct imports use filename-derived display fallbacks; CocoaSpice does not read
  tags or decoder headers to enrich them.

## Archives

- Standalone files compressed with Zstandard (`.zst` or `.zstd`) are decoded as
  one media file. TAR+Zstandard archive names (`.tar.zst`, `.tar.zstd`, and
  `.tzst`) are unsupported.
- ZIP, 7z, LHA, RSN, and UAC (`.uac`) containers can contribute playable
  members to a queue. UAC reads raw or compressed manifests. For seekable UAC,
  VGMBoy decompresses only the indexed frames intersecting the selected member
  and prepares the decoder input in temporary playback storage.
- CocoaSpice keeps the original archive and member identity in its queue and
  passes both to VGMBoy. VGMBoyArchiveCore validates and prepares the member
  before VGMBoyKit decodes it; FrontendCore cache policy is separate from this
  temporary playback source.
- LHA members use the shared 7zz extraction route as 7z members. Amiga UADE files
  are admitted by their path prefix (for example `mod.title` or `med.song`),
  not by the final filename suffix, and their archive is expanded as a complete
  set so sibling data files remain available to the decoder.
