# Decoder Update Verification

## Current working-tree evidence

- libsidplayfp 3.1.2 is the linked Homebrew formula. The Bionic Commando USA
  SID from the High Voltage SID collection was extracted to a temporary file;
  VGMBoy's SID fixture test enumerated both subtunes and rendered nonzero PCM.
- vgmstream r2168 (`d9875b1fff307e4759dfb85e49e3d5e6fb196f7c`) uses the
  checked-in FFmpeg system-link compatibility patch. Playback dependencies and
  scanner plugins built on this host; the scanner read the Resident Evil 2
  `main00.ldat` fixture with its `.ldat.txth` companion.
- VGMBoy's package suite passed with its GameCube fixture test enabled. The
  temporary fixture set contained ADP, AGSC, DSP, H4M, LDAT, LOGG, RSF, THP,
  and TXTP members extracted from the local JoshW GameCube archives. Each
  opened and rendered nonzero PCM. An independent old/new bridge comparison
  found the same reported sample rates, track counts, and play lengths for
  these nine examples. This does not establish sample-identical audio or cover
  the full vgmstream format inventory.
- The full VGMBoy run passed 76 tests with the SID and GameCube fixtures
  enabled; unrelated optional fixture tests remained skipped. This was a dirty
  working-tree run, not a clean checkout or packaged-app interaction test.
- Homebrew FFmpeg 9.0.2_1 and libsidplayfp 3.1.2 link on this host, but their
  bottles produced macOS 27 deployment warnings against the macOS 26 target.
  macOS 26 compatibility and packaged audible playback remain unverified.
