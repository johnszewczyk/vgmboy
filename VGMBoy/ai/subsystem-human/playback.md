# Playback

VGMBoy's command line (`vgmboy-cli`) and standalone WebKit application (`VGMBoy`)
play original game-music files through one native audio core. The app uses a
charcoal/cyan two-pane interface: session files and compact transport controls on
the left, with Player, Audio, Diagnostics and Formats pages on the right. Its
bottom status bar keeps playback time, seek and volume visible across pages.
Command-O adds local audio files or archives to the current session; dropping
files onto the window replaces that session. Both routes accept the formats
listed below, including NSF, GBS, PSF, SPC, and GSF, and expand archives only
into playable entries recognized by the shared format registry. The archive
core prepares those entries without a catalog. The first accepted item in the
resulting batch starts playing, and Previous/Next move through the local
session. Supported archive containers are UAC, ZIP, 7z, LHA, RSN, and TAR.
Standalone `.zst` and `.zstd` files are also supported; TAR+Zstandard archives
are not. Archive tools must be available on the host: `7zz` for ZIP/7z/LHA,
`lsar` and `unar` for RSN, `bsdtar` for TAR, and `zstd` for standalone
Zstandard files and applicable UAC payloads.
The subsong field uses a one-based source index. Show in Finder locates the
selected source.

Player exposes Long Play, pre-fade seconds, fade and decoder-supported tempo.
Changing timing preserves pause intent and position. The position slider uses a
seek window, not a claimed metadata-derived total duration. Audio provides output
volume, mono and ten-band EQ. Diagnostics shows actual native output/buffer/frame
counters; Decoder formats uses VGMBoyKit's authoritative capability registry.

The app has no catalog or persistent playlist database. WebKit presents bundled
local controls; VGMBoyKit retains decoding, DSP, timing and the audio device.

## Play

`vgmboy-cli play <path>` plays a file through the core's own audio output and reports the system,
title, and track window. Supported options:

- `--track <n>` selects a subsong (0-based) when the file has several.
- `--long-play` plays a manual window instead of the tagged length.
- `--play-ms <n>` and `--fade-ms <n>` set the pre-fade window and fade duration in milliseconds.
- `--tempo <n>` changes playback speed for families that support it (libgme, libvgm).

## Supported Formats

- Chip music (libgme): `.ay`, `.gbs`, `.hes`, `.kss`, `.nsf`, `.nsfe`, `.spc`
- Commodore 64 (libsidplayfp): `.sid` (exposes every declared subtune as a
  playlist track and selects the requested subtune on playback)
- Atari XL (ASAP): `.sap` (TYPE B, C, D, and S; native speed)
- Sega/console logs (libvgm): `.vgm`, `.vgz`, `.gym`, `.s98`, `.dro`
- Tracker modules (libopenmpt): `.669`, `.dmf`, `.far`, `.it`, `.mod`, `.mptm`, `.mtm`, `.okt`,
  `.ptm`, `.s3m`, `.stm`, `.ult`, and `.xm`
- Standard audio: AVFoundation handles `.aac`, `.aif`, `.aiff`, `.caf`, `.flac`, `.m4a`, `.mp3`,
  `.wav`, and `.wave`; bundled FFmpeg handles `.ape`, `.mp2`, and `.tak`
- Streamed game audio (vgmstream): `.adp`, `.adpcm`, `.adx`, `.at3`, `.bik`, `.bk2`, `.fsb`, `.vag`,
  `.xvag`, `.xmd`, `.aifc`, `.ogg`, and the other registered stream/bank extensions
- Nintendo 64 (lazyusf): `.usf`, `.miniusf` — needs its companion `.usflib` files beside it
- Game Boy Advance (Highly Complete): `.gsf`, `.minigsf` — miniGSF needs its companion `.gsflib` files beside it
- Nintendo DS (2sf2wav): `.2sf`, `.mini2sf` — mini2SF needs its companion library files beside it
- Nintendo DS legacy WAV payloads: `SWAV` payloads and recognized headerless `_NN.wav` signed PCM
- PlayStation / PlayStation 2 (Play!): `.psf`, `.minipsf`, `.psf2`, `.minipsf2`

Long play, fade, and seek work across all families. Tempo is available only where the decoder
supports it.

Formats with decoder-provided timing use that natural duration. Formats without timing use the
shared unknown-duration default plus fade unless the caller explicitly enables Long Play. The
default unknown-duration value is 2:30 and can be changed by the frontend.

VGMBoyKit also exposes an in-process `PlaybackController` for native app hosts. It owns the
decoder, transport, timing, and ten-band EQ; a host keeps its own playlist, repeat/shuffle policy,
catalog, and macOS media-key integration.

## AAC Export

Hosts can ask VGMBoyKit for a finite offline AAC render. The core writes real ADTS `.aac` output
from a separately decoded session, so exporting does not pause, record, or otherwise disturb live
playback. The host supplies its display filename and folder; VGMBoy sanitizes the name and appends a
number rather than overwriting an existing file.

## Audio Output

- Playback, pause, stop, seeking, and track changes use one persistent macOS audio endpoint.
- Short output transitions fade cleanly at the device boundary; pausing or choosing the next track
  does not repeatedly reopen the system audio device.
- Pausing leaves the endpoint alive but stops ring consumption, so a paused session does not create
  synthetic underrun growth while its producer is intentionally stopped.

## Files

- [VGMBoyCommand.swift](../../Sources/vgmboy/VGMBoyCommand.swift)
- [PlayerViewModel.swift](../../Sources/VGMBoyApp/PlayerViewModel.swift)
- [ContentView.swift](../../Sources/VGMBoyApp/ContentView.swift)
