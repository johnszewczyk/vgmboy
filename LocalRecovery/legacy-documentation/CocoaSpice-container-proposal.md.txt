# UAC Container and Archive Boundary

## Purpose

This document records the container boundary agreed for CocoaSpice,
SPCBoyWK, ScanSong, and VGMBoy. The goal is predictable intake and playback
without making either frontend own a decoder or inventing a second archive
engine.

## The important distinction

Zstandard (`.zst`/`.zstd`) is a compression codec, not a ZIP-like archive
format. A plain Zstandard frame normally has no member listing and does not
carry a reliable user-facing filename. A single-file payload therefore uses
an explicit basename convention when the original filename is available:

```text
track.vgm.zst   ->   track.vgm
song.flac.zstd  ->   song.flac
```

The inner suffix is the playable format identifier. ScanSong admits a
standalone Zstandard file only when that suffix is registered as a playable
format. A bare `file.zst` with no inferable playable suffix is rejected rather
than guessed or published as an opaque track.

This convention is not required for ZIP files because ZIP has an internal
member name and listing. It is needed here because standalone Zstandard does
not provide that archive layer.

## UAC per-game package

The larger opportunity is not to invent a replacement audio encoding. UAC is
the selected name for a per-game package that preserves the original playable
files while making catalog metadata available without opening a decoder. Its
binary contract lives in
[`FrontendCore/ai/subsystem-agent/uac-format.md`](../FrontendCore/ai/subsystem-agent/uac-format.md).

The package conversion should therefore be lossless at the member level:

```text
original.nsf  ->  game.uac containing the original.nsf bytes
```

Unpacking the UAC must reproduce the complete original `.nsf` byte for
byte. The packer must not normalize, merge, rewrite, or translate NSF, SPC,
VGM, QSF, or other source formats. A `.nsf` remains an NSF; it is simply a
named payload member inside the UAC. Multi-file sets retain every original
file, including dependency files such as `miniqsf` libraries, rather than
creating a synthetic replacement file.

UAC starts with a standard Zstandard skippable frame containing a bounded,
uncompressed manifest. A normal Zstandard frame follows, containing one ordinary
TAR archive. Zstandard-aware consumers skip the metadata frame and continue
decoding the TAR frame, so the existing `zstd -dc | tar` path reads UAC without
an intermediate payload copy or custom playback decompressor. The manifest is
readable without decompressing the TAR frame. It groups variants under one
logical game and lists the preserved members. A manifest entry can contain:

- original basename and format extension
- raw payload size and BLAKE3 identity
- game, track, author, system, comment, timing, loop, and fade metadata
- track ordinal and total track count
- decoder/backend and dependency relationships
- metadata provenance and generator version

The top-level transformation ledger records required set changes by operation
class and retains the source-member hash/path, output-member hash/path,
tool/version, timestamp, and rationale. Repacking and packaging are distinct
operations; this is the trace of how the annual member differs from its
source-state record.

ScanSong can catalog declared members and metadata without extraction or decoder
startup. CocoaSpice can list tracks from the manifest, then stream the
Zstandard TAR through its existing selected-member extractor. This keeps the
container simple and broadly tool-readable, but selected-member extraction
still scans/decompresses the TAR stream; UAC v1 does not promise random access.

The manifest is the fast catalog view, not a substitute for source truth. The
raw-member hash and extraction-size checks must remain authoritative. Metadata
can be regenerated from the preserved source if a future scanner improves its
interpretation; a metadata-only correction rewrites the skippable frame and
copies the compressed TAR frame unchanged, with provenance recorded.

The extension is `.uac`; it is a collection format owned by this project
family, not a claim that it is an industry-wide standard.

## Container taxonomy and precedence

| Input | Meaning | Listing | Materialization |
| --- | --- | --- | --- |
| `track.ext` | Ordinary playable file | Not applicable | Pass the file to VGMBoy |
| `set.zip`, `set.7z`, `set.rsn` | Multi-member archive | Tool listing | Selected member or complete set, as required by VGMBoy |
| `set.tar` | Multi-member TAR | TAR listing | Selected member or complete set |
| `set.tar.zst`, `set.tar.zstd`, `set.tzst` | TAR compressed with Zstandard | Decompress into TAR listing/extraction stream | Selected member or complete set |
| `track.ext.zst`, `track.ext.zstd` | One payload compressed with Zstandard | One implicit member from the basename | Decompress that one payload |
| `game.uac` | One-game package with variants and indexed metadata | Read uncompressed UAC manifest | Existing Zstandard-to-TAR selected-member or complete-set path |

Detection must check TAR+Zstandard names before the standalone suffix. Thus
`set.tar.zst` and `set.tar.zstd` can never fall through to standalone handling.
The same rule applies in ScanSong discovery, CocoaSpice dropped-file listing,
and shared playback materialization.

## Ownership and data flow

1. ScanSong owns catalog discovery, archive intake, native metadata inspection,
   and schema-23 publication. For a standalone Zstandard source it
   materializes one payload into disposable scan scratch, then inspects the
   extracted file using the normal registered format route.
2. CocoaSpice and SPCBoyWK own presentation, queue behavior, and frontend
   adapters. They do not access playback codecs or duplicate archive engines.
3. FrontendCore owns UAC frame/manifest validation and encoding, shared archive
   taxonomy, command routing, cache-backed playback materialization, path
   validation, and the selected-member versus complete-set boundary.
4. VGMBoy owns format admission at playback, decoder access, timing, fade, and
   output. The frontends pass VGMBoy a normal extracted file path, never a
   decoder-specific archive implementation.

For `track.ext.zst`, the catalog identity remains the source archive plus its
implicit member name (`track.ext`). At playback, the shared materializer runs
Zstandard once into the configured disposable or durable cache and returns
that extracted path to VGMBoy. CocoaSpice and SPCBoyWK therefore use the same
materialization machinery and the same format-specific playback requirement.

## Dependency boundary

A standalone Zstandard file contains one payload. It cannot satisfy a format
whose playback requirement is a complete decoder/dependency set, such as a
PSF/USF family that needs sibling libraries. Those requests must fail
explicitly; they must not silently invoke a fallback or pretend that the
single payload is a complete archive.

This does not change LongPlay, natural duration, fade, or decoder policy.
Those remain VGMBoy concerns after the extracted file reaches the shared
playback core.

## Streaming decision

The current implementation intentionally materializes standalone Zstandard
payloads. This is the smallest correct boundary because VGMBoy currently
opens a playable path, not an arbitrary decompression stream. Large payloads
must be decompressed somewhere before path-based playback; small payloads do
not justify a second streaming/cache protocol.

TAR+Zstandard and UAC share the existing stream topology (`zstd -dc` into TAR)
for listing and selected extraction. A future decoder-streaming design would need an
explicit VGMBoy stream/file-descriptor contract, bounded output handling,
cancellation, cache policy, and format-specific seek requirements. It should
not be introduced by treating standalone `.zst` as a fake ZIP archive.

## Safety and cleanliness rules

- Preserve TAR+Zstandard behavior and precedence.
- Validate source/member paths and reject traversal or symlink escapes.
- Enforce the scanner's expanded-size and member-count limits.
- Keep extraction cancellable and remove failed scratch output.
- Never invent a playable row for an unknown standalone `.zst`.
- Never stage or commit `.DS_Store`, editor swap files, build output, caches,
  or other generated junk.

## Current implementation status

`UACContainerCore` reads and writes the bounded Zstandard skippable-frame
manifest prefix while preserving a supplied TAR+Zstandard payload byte-for-byte.
ArchiveMaterializationCore recognizes `.uac` and routes it through the existing
Zstandard-to-TAR selected-member and complete-set paths. CocoaSpice lists
members from the manifest and derives an incremental-scan signature from its
SHA-256. AudioMan still needs the set packer/provenance mapping, and ScanSong
still needs direct UAC manifest ingestion before the end-to-end annual-set
workflow is complete. Standalone Zstandard materialization remains a separate
single-payload path.

The compatibility premise is defined by the [Zstandard frame format](https://github.com/facebook/zstd/blob/dev/doc/zstd_compression_format.md):
compliant decoders skip skippable frames and continue with the next frame.
