# SNESMusic.org SPC tag and hash preview

**Status: applied and verified.** The earlier eight-hash Current/Initial proposal is withdrawn. The source archive is represented by exactly four package-level **Source .rsn Hashes**. The later hash-record enrichment retained algorithm, digest, byte size, scope, and profile inside those four items. Package payload and member hashes were verified unchanged.

## Scope audit

- Audited `1,519` UAC packages and `34,917` SPC tracks under `/Users/john/Downloads/audio/JohnS/SNESMusicOrg`.
- Each package has one linked source RSN and exactly four source-file hashes: BLAKE3-256, CRC32, SHA-1, and MD5. The prior Initial list duplicated those same values in all 1,519 packages; the applied package metadata has one four-item source list.
- Each SPC track already has exactly four `playable-payload` records in its member hash collection. The tag view should label that group **Stream Hashes**; the member records remain the hashes of files actually contained in the UAC.
- `Source Encoding` is present on all `34,917` source parses as `Windows-1252`.
- Header-byte-derived revision is SPC v.30 on `34,916` tracks and SPC v.10 on `1`. All textual SPC headers say v.30; the known disagreement is `RPG Maker 2.uac` → `19-Frozen Wasteland.spc`, which stays in the mixed-version review folder.
- The packages already contain `1,532` `.txt`/HTML members as package asset members; all `1,519` packages have at least one. No track attachment is proposed.
- Exact package before/after tags are in [packages.tsv](/Users/john/Downloads/Code/AudioMan/batches/snesmusicorg-spc-metadata-2026-09-23/packages.tsv). Exact per-track before/after tags and the four Stream Hashes are in [tracks.tsv](/Users/john/Downloads/Code/AudioMan/batches/snesmusicorg-spc-metadata-2026-09-23/tracks.tsv).
- Exact source-hash record attribute enrichment is in [source-hash-record-attributes.tsv](/Users/john/Downloads/Code/AudioMan/batches/snesmusicorg-spc-metadata-2026-09-23/source-hash-record-attributes.tsv).

## Package-level tags

Use the explicitly requested Title Case fields. For `super castlevania iv.uac`, the package proposal is:

```json
{
  "Set Name": "SNESMusic.org",
  "Set URL": "https://snesmusic.org/v2/torrent.php",
  "Source RSN": "scv4.rsn",
  "Source .rsn Hashes": [
    {
      "Algorithm": "BLAKE3-256",
      "Digest": "bf8d7b06dde398a986c353f0337a9a45a133734b6b7fd3f073766bb2190815c5",
      "Byte Size": 93025,
      "Scope": "source-rsn-file",
      "Profile": "audioman-source-file-v1"
    },
    {
      "Algorithm": "CRC32",
      "Digest": "3F05F8E0",
      "Byte Size": 93025,
      "Scope": "source-rsn-file",
      "Profile": "audioman-source-file-v1"
    },
    {
      "Algorithm": "SHA-1",
      "Digest": "1f3a8ad5069f2799ba585868529e25beaf8f6d97",
      "Byte Size": 93025,
      "Scope": "source-rsn-file",
      "Profile": "audioman-source-file-v1"
    },
    {
      "Algorithm": "MD5",
      "Digest": "6ff6480ffea8f8e31ed2b54b8bcb418f",
      "Byte Size": 93025,
      "Scope": "source-rsn-file",
      "Profile": "audioman-source-file-v1"
    }
  ]
}
```

`Source .rsn Hashes` has exactly four items for the complete `scv4.rsn` file. Each hash item includes its algorithm, digest, byte size, scope, and profile. No Current/Initial split is used. All package source records retain the RSN name/path linkage.

## Track-level tags and hashes

For `00-Konami Logo.spc`, the additional source-derived fields and hash group are:

```json
{
  "Source Encoding": "Windows-1252",
  "Sub-Container Version": "SPC v.30",
  "Stream Hashes": [
    {
      "Algorithm": "BLAKE3-256",
      "Digest": "f92e233f82408be32a4500c7b5e3aa63f4c40f5655a931e804c62afb4ebef20a"
    },
    {
      "Algorithm": "CRC32",
      "Digest": "331C2D61"
    },
    {
      "Algorithm": "SHA-1",
      "Digest": "4e9c963451e38ceb5375e506df0ec1d5d73cee06"
    },
    {
      "Algorithm": "MD5",
      "Digest": "2af8b6ca887fabe7aaf3a69b809a4cc1"
    }
  ]
}
```

**Stream Hashes** is the existing four-item playable-payload hash set for that SPC member. It remains associated with that file in the set. Use **Sub-Container Version** as `SPC v.30` from the revision byte; the one v.10 track is reported with the package already routed to review because its textual header says v.30.

Source tags are projected under Title Case names, including **Artist**, **Publisher**, and **Dumper**; `Copyright Year` becomes **Year**, and **Album** is used only when the SPC contains an Album tag (otherwise the source Game tag becomes **Game Title**). **Developer: Konami** is included only for this package as directly specified earlier; it is not inferred or generalized. SPC ID666/xID6 bytes are not rewritten. Included text members stay as package-level assets.

## Proposed manifest-only relocation

- Add **Source RSN** and **Source .rsn Hashes** to package metadata, using the source record and its four file-hash values.
- Replace the nested `game.metadata.set` object with the requested flat **Set Name** (`SNESMusic.org`) and **Set URL** fields.
- Remove `sources[].packageBlake3`, `sources[].extensions.audioman.currentChecksums`, `sources[].extensions.audioman.initialChecksums`, and `sources[].extensions.audioman.initialSourceInventoryBLAKE3` after transferring the one four-hash set. Keep non-hash source identity/path fields and the inventory run ID.
- Project each SPC parser's **Source Encoding** value onto that track and show the four member `playable-payload` records as **Stream Hashes**. Do not duplicate stream digests as free-standing ordinary metadata values.
- Keep the source SPC bytes, included text assets, all member hashes, payload bytes, package filenames, and database rows unchanged.

The applied result is manifest-only: it retains all SPC/text member bytes and four Stream Hashes per SPC track. Songbase was subsequently indexed from these package hashes and per-track Sub-Container Version tags.
