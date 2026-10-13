# Format profile: `ffmpeg-audio`

Parent playback plugin: `ffmpeg-audio`. This page groups the subformats admitted by that plugin and records their ScanSong route, metadata source, and format-specific boundaries. The shared registry matrix, route inventory, and scanner contracts remain in [format-accommodations.md](../format-accommodations.md).

The playback parent also lists `.mp2` and `.tak`; neither currently has a ScanSong route.

## .ape — Monkey's Audio

`.ape` is a native lossless audio container, not an archive and not a
multi-track module. `MetaManCore` validates the APE descriptor, stream
parameters, seek-table extent, frame offsets, and payload bounds. It derives
duration from the container's sample-block count and rate, retains ordered
APEv2 text tags and leading ID3v2 common tags, and exposes both original tag
blocks for unknown or binary values. An absent title falls back to the source
stem. ScanSong adapts the common fields and retains ordered tags in schema 25; it
never starts FFmpeg or an audio decoder. VGMBoy keeps its independent
`CFFmpeg` bridge for APE playback; ScanSong no longer builds or bundles an
FFmpeg inspection helper. The original APE bytes remain the catalog source;
no transcode is performed.
