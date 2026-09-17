# MetaMan instructions

Read [`ai/AGENTS.md`](ai/AGENTS.md), then
[`ai/project-info.md`](ai/project-info.md), then the focused format or API note
identified there.

- `MetaManCore` is the product boundary. Keep the CLI thin; apps must be able
  to import the library without spawning a process.
- The core must not depend on ScanSong, VGMBoy, CocoaSpice, or playback
  decoders. A supported format is a complete metadata reader: tags, source
  facts, and available timing are read from its file data, with no hidden
  decoder fallback or half-extracted format state.
- Preserve ordered duplicate tags, unknown keys, source bytes, and diagnostics
  when the format permits. Normalized common fields are additive projections,
  not replacements for raw data.
- Reading and writing are separate capabilities. Do not imply safe write
  support until a format-specific writer preserves unknown fields and has
  round-trip coverage.
- Decoder-based comparisons belong in test-only oracle tests. Record
  intentional correctness improvements separately; do not inherit a decoder
  defect merely to achieve byte-for-byte behavioral parity.
- Keep format layouts, supported facts, and methodology in
  `FORMAT-LAYOUTS.md`; keep the README as an entry point. GYM is not an
  extraction target.
