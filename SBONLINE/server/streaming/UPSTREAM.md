# SPCBOY streaming decoder

The VGM decoder bridge and vendored libvgm source in this directory are copied
from the VGMMan `VGMBoy` project at commit
`faea097a1522ec1ddc8071a47134271ab783f193`. The bridge source is from
`VGMBoy/Sources/CLibVGM`; the dependency source is from
`VGMBoy/vendor/libvgm`.

Archive/member preparation uses VGMBoy's `VGMBoyArchiveCore` through the
`vgmboy-prepare` Linux executable. The verified Ubuntu 24.04 x86_64 runtime was
built from `8fac4a25d82cc493adf1c0819611b55e148c37c8` by workflow run
`40188183483`. The ignored deployment artifact is
`ops/server/artifacts/vgmboy-prepare-linux.tar.gz`; it includes Swift runtime
libraries and SOURCE_REVISION. Versioned runtime directories live outside the
app release under `/opt/precalc-admin/lib/vgmboy-prepare/`, with an atomically
replaced wrapper at `/opt/precalc-admin/bin/vgmboy-prepare`.

The Django adapter supplies configured archive-tool paths, a bounded lifetime
and output limit, and request-owned scratch. For manifest-less Master `.uac`
files that are Zstandard-compressed tar archives, its SBO-owned compatibility
path streams only the catalog-selected member through the configured `zstd`
and `tar` tools. It writes no persistent extracted tracks.
Package a new helper artifact for VGMBoy preparation changes; do not assume
native or hosted builds update each other automatically. The decoder source
revision above is independent of this preparation runtime.

The vendored CMake helper gates package-registry registration on
`CMAKE_EXPORT_PACKAGE_REGISTRY`, which is disabled by this standalone build.

`spcboy-stream` emits signed 16-bit, 44.1 kHz stereo PCM to stdout. It uses
libvgm for VGM/VGZ and libgme for admitted chip-music formats. Its final argument marks Long Play;
when enabled, the explicit stream duration overrides decoder-native end
signals, with VGM tracks restarting at the beginning if they have no loop
point. Tracks with a native loop keep one decoder and follow that loop; an
unexpected native-loop EOF is an error, never a whole-file restart.
One absolute output fade spans restarts; decoder-local fades are disabled
for Long Play. Zero-duration musical policy is resolved to a bounded remaining
web-session window before invoking this executable. The web application pipes that PCM to FFmpeg and sends AAC-LC at the owner-configured global bitrate as an ADTS byte stream (`audio/aac`), with no MP4 container and no byte-range support. The stream handler strips exactly the first complete ADTS frame from each encoder as priming before accounting or delivery. MediaSource generates timestamps for the remaining ADTS frames. The same encoder remains active across native loop boundaries. It sends the result directly to the active browser request. It does not write rendered AAC tracks to disk.
