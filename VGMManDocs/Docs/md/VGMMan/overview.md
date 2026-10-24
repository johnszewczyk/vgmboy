# VGMMan

VGMMan is the project family for tools that inspect, catalog, present, and play
video-game music. Each app has its own interface and release boundary, while
shared packages own catalog access, frontend policy, metadata reading, and
playback.

## Projects

- [VGMBoy](../VGMBoy/plugin-catalog.md) owns playback routing, decoder
  integration, timing, and audio output.
- [MetaMan](../MetaMan/format-layouts.md) reads source metadata without
  depending on playback decoders.
- UACMan browses and edits reversible `.uac` package manifests.
- CocoaSpice, SB2, and ViewBoy are maintained player applications. SPCBoyWK is
  retired; its source is preserved in Git history and a local recovery ZIP.
- VGMManDocs presents this Markdown library from the local filesystem.

The application repository is organized as one Git family. Its subdirectories
are package boundaries; VGMMan is the repository root.
