# UAC wrapper

This component owns the current `.uac` package format within VGMMan: a versioned
metadata envelope with original members in a TAR payload compressed as
seekable Zstandard frames. It is reversible and does not replace the contained
audio formats. Regular files such as PNG scans, CUE sheets, TXT notes, and
Markdown documents are preserved and hashed as members alongside playable
streams. AudioMan is a downstream operator of this CLI, not an owner or runtime
dependency of the wrapper.

- Swift package target: `UACWrapperCore`.
- `UACContainerReader` owns framing and payload ranges; `UACManifest` contains
  the public JSON model; `UACManifestValidator` owns structural validation.
- Collection packer and inspector: `python/uacman.py`.
- Metadata harvest bridge: `../Application/Sources/UACManMetadataCLI/`, built
  from the UACMan application package using MetaManCore.
- Wrapper tests: `Tests/UACWrapperCoreTests/` and `python/tests/`.
- Binary and manifest contract: `../ai/subsystem-agent/uac-wrapper-format.md`.

From the `UACMan/` project root, run the wrapper CLI with:

```sh
python3 -B Wrapper/python/uacman.py --help
python3 -B Wrapper/python/uacman.py pack --help
python3 -B Wrapper/python/uacman.py pack-source-tree --help
python3 -B Wrapper/python/uacman.py enrich-sets <uac-collection>
python3 -B -m unittest discover -s Wrapper/python/tests
swift test --package-path Wrapper
```

Typical reversible workflow:

```sh
python3 -B Wrapper/python/uacman.py pack <variant-directory> recipe.json <new-game>.uac
python3 -B Wrapper/python/uacman.py inspect <new-game>.uac --verify
python3 -B Wrapper/python/uacman.py unpack <new-game>.uac <new-output-directory>
```

New packages use manifest version 2: a one-variant package stores members at
their source-relative paths, while packages with multiple variants namespace
members under `variants/<id>/`. Current readers still open version-1 packages;
their payloads do not need to be repacked just to remove the synthetic
`variants/original/` directory. Version-2 files require updated UAC consumers.

For creation-time SPC metadata, build `UACManMetadataCLI` from the project
root and pass it with `--harvest-spc-metadata`. For another MetaMan-supported
format, use `--harvest-format-metadata vgm <UACManMetadataCLI>` (`mdx`, SID,
NSF, NSFE, GBS, standard audio, and APE are also supported); the option can be
repeated for additional extensions. FLAC Vorbis comments and APE/ID3 tags are
retained as ordered native metadata while the original compressed audio remains intact.
Track-aware NSF-family results become ordered UAC
`subsong` playlist entries and retain their per-track MetaMan projection. Every
entry points at the same unchanged native member and records its decoder track
index. The reader is MetaManCore; the wrapper does not edit source tags. Use
new output paths, inspect the recipe/source mapping, and round-trip into a
separate directory before promotion. A successfully harvested member defaults
to UAC role `playable`; an explicit recipe role remains authoritative.

When source records identify one unambiguous distributor and set, the packer
projects it to the flat package tags `game.metadata.setCollection`, `setName`,
and `setUrl`. For
Redump packages, the `redump-disc-archive` record is authoritative over derived
output and metadata-only association records; its Archive.org download URL is
projected to the matching item details page. Existing collections can be audited
with `enrich-sets <root>`; this is a dry run by default. Add `--apply` to add the
field to matching manifests in place. The command validates each update and
copies the compressed payload byte-for-byte; unmapped, conflicting, or
otherwise already-tagged packages are left unchanged.
The one scoped refresh updates previously archived Project2612 links to current
VGMRips system pages and retains both the old Project2612 address and its
Wayback snapshot. This is a useful current directory link, not a claim that
every original Project2612 package was one-to-one migrated.

New packages also write `game.metadata.containedContainerVersions`, which
records SPC and VGM version/count groups at package level and lists formats
with mixed versions. Each SPC member exposes
`metadata.spcVersion` (from its version byte), `metadata.spcVersionByte`, and
`metadata.spcHeaderVersion` (from the signature text). The byte and signature
are reported separately because real SPCs can disagree between them; neither
is silently normalized. VGZ members are rejected by the generic packer because
their nested gzip wrapper reduces outer Zstandard compression; other
format-specific policy belongs to the caller. This
inspection does not change source bytes. Every member receives a CRC32/ISO-HDLC
hash scoped to its exact raw bytes. Playable members receive BLAKE3, CRC32,
SHA-1, and MD5 records for the playable-payload scope; for SPC this is the
complete stored file. Existing BLAKE3 member identity remains available.
AudioMan must convert VGZ to raw VGM and freshen VGM versions before
packaging when that is the selected set policy.

For bulk `.tar.zst` conversion, pass the same helper with `--metadata-cli` and
add `--metadata-format vgm` (or `nsf`, `nsfe`, `gbs`, `flac`, or `ape`) to
`pack-source-tree`. Formats absent from an input package are skipped without
starting a reader process. Other standard-audio extensions can be named the
same way.

On macOS, TAR member names and MetaMan's filesystem paths can use different
Unicode normalization forms. Bulk packaging matches those paths by canonical
Unicode equivalence, but writes the original TAR member spelling into UAC.
Distinct source names that collide after normalization fail closed.

Native SPC replacement work is closed. `Container/` keeps the former research
and state-profile prototype as historical material; this wrapper remains the
active route for preserving original members with richer metadata.
