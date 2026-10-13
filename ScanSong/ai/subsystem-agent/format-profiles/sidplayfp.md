# Format profile: `sidplayfp`

Parent playback plugin: `sidplayfp`. This page groups the subformats admitted by that plugin and records their ScanSong route, metadata source, and format-specific boundaries. The shared registry matrix, route inventory, and scanner contracts remain in [format-accommodations.md](../format-accommodations.md).

## .sid — PSID/RSID metadata and song rows

`.sid` metadata is read by MetaManCore; libsidplayfp remains VGMBoy's playback
dependency. It validates the complete v1 (`0x76`-byte) or v2+ (`0x7C`-byte)
header before reading the PSID/RSID fixed fields: title at `0x16`,
author at `0x36`, and released text at `0x56`, preserving the raw header and
technical identity/address/song-count facts. The source field called
`released` is retained as copyright/release text, not misrepresented as a full
date. ScanSong projects each declared SID song as a catalog row, preserving its
zero-based native track index and release text in the comment field. VGMBoy
selects each row's one-based PSID/RSID song number through libsidplayfp.

SID files do not carry a standard finite play duration. The reader therefore
does not infer seconds from the v2 extension bytes: `0x76` begins flags and
other technical fields, not PAL/NTSC lengths. The former direct reader treated
those bytes as durations and used overlapping title offsets for author and
released text; MetaMan fixes both parsing errors. The raw header remains
available through `MetadataDocument`; schema 25 retains source tags, but not
those additional technical facts. See the [PSID/RSID format description](https://github.com/TheCodeTherapy/sid-player/blob/master/SIDspec.md).
