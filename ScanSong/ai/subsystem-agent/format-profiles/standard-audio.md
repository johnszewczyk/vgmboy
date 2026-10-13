# Format profile: `standard-audio`

Parent playback plugin: `standard-audio`. This page groups the subformats admitted by that plugin and records their ScanSong route, metadata source, and format-specific boundaries. The shared registry matrix, route inventory, and scanner contracts remain in [format-accommodations.md](../format-accommodations.md).

## AVFoundation-backed audio subformats

`.aif`, `.aiff`, `.flac`, `.m4a`, `.mp3`, `.ogg`, and `.wav` are one-track
standard audio. MetaManCore prefers `AVAudioFile`'s exact decoded frame count
and sample rate for duration, then falls back to `AVURLAsset`. It retains
AVFoundation common tags and directly parses FLAC Vorbis comments, preserving
their order, duplicate/unknown keys, and source block. The convenience
projection retains the former album/title/artist/comment precedence; ScanSong
adapts the common fields and retains ordered tags in schema 25. No game-music timing model is invented
for ordinary audio. AVFoundation remains an OS framework dependency, not a
bundled playback decoder.
