# UAC wrapper

This component owns the current `.uac` package format: a versioned metadata
envelope with original members in a TAR payload compressed as seekable
Zstandard frames. It is reversible and does not replace the contained audio
formats.

- Swift package target: `UACWrapperCore`.
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
python3 -B -m unittest discover -s Wrapper/python/tests
swift test --package-path Wrapper
```

Typical reversible workflow:

```sh
python3 -B Wrapper/python/uacman.py pack <variant-directory> recipe.json <new-game>.uac
python3 -B Wrapper/python/uacman.py inspect <new-game>.uac --verify
python3 -B Wrapper/python/uacman.py unpack <new-game>.uac <new-output-directory>
```

For creation-time SPC metadata, build `UACManMetadataCLI` from the project
root and pass it with `--harvest-spc-metadata`. For another MetaMan-supported
single-track format, use `--harvest-format-metadata vgm <UACManMetadataCLI>`
(or `vgz`; SID is also supported);
the option can be repeated for additional extensions. The reader is MetaManCore;
the wrapper consumes its structured projection and does not edit source tags.
The current single-track directory harvester rejects track-aware results
instead of flattening them into one member record. Use new output paths,
inspect the recipe/source mapping, and round-trip into a separate directory
before promotion.

For bulk `.tar.zst` conversion, pass the same helper with `--metadata-cli` and
add `--metadata-format vgm` (or `vgz`) to `pack-source-tree`. Formats
absent from an input package are skipped without starting a reader process.

Native SPC replacement work is closed. `Container/` keeps the former research
and state-profile prototype as historical material; this wrapper remains the
active route for preserving original members with richer metadata.
