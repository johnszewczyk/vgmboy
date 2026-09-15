# Shared Source Provenance

This file records the source identity checked into the VGMMan family repository. A tree digest is
the SHA-256 of the sorted, per-file SHA-256 records for repository-tracked files under the named
directory, excluding `.git` metadata. It fingerprints the exact checked-in source snapshot; it is
not a substitute for an upstream revision where one is known. Compatibility patches are separate
inputs under `VGMBoy/patches/`.

| Source | Upstream identity | Checked-in source SHA-256 | Notes |
| --- | --- | --- | --- |
| `libvgm` | `867223e7c33d63de115d1ab955f784c44f19040a` | `745dd264f520bc3814c39c9b8455e59e893d2d24a270c3f3d2a261af247337b0` | [ValleyBell/libvgm](https://github.com/ValleyBell/libvgm) |
| `lazyusf2` | `421f00bcaa1988b8e1825e91780129f24fbd1aa0` | `9a7c1c47d2f57c56cd32e8a920c589a7c6b4f06075214e56edc9aa115f50c8f0` | [kode54/lazyusf2](https://gitlab.com/kode54/lazyusf2) |
| `Play!` | `50aedca2639521bc498ace0b2be1ea012801a86a` | `e9ae6c4e998725fc7ba402cd6c2c1ea3ec20210b5443ac474078a2dd9aed251c` | [jpd002/Play-](https://github.com/jpd002/Play-); required nested source included |
| `vgmstream` | `807b4948cfc1de0cd90e377e9c56f74664c54a1c` | `03e6faa4b00c2d3d7ec2367cf523f34e00611d15d8187ec51db50bbfafa3804f` | [vgmstream/vgmstream](https://github.com/vgmstream/vgmstream); compatibility patch remains separate |
| `aosdk` | `e359a6e5154b2ba8499fb1f24a1f5f8a18538a61` | `148dd78f273a056da67e80596d603ab001adaf96c9e1c68cf731d486922190b7` | [nmlgc/aosdk](https://github.com/nmlgc/aosdk); QSF lifecycle patch remains separate |
| `highly_quixotic` | `d730174d436e8cabca90fabdb3ad4ddf614d31cc` | `91732a4d37b2acf32323e2d960ddab0916910c0c8d666fa07d1f1d5637373b42` | [kode54/highly_quixotic](https://gitlab.com/kode54/highly_quixotic) |
| `mGBA` | `0.11.0`; upstream revision not recorded | `27e65466e606a38b0098e94e4636dab2e5028b0d5bb0341f7b59a4ea630b3cbe` | [mgba-emu/mgba](https://github.com/mgba-emu/mgba); used by the Highly Complete playback bridge |
| `2sf2wav` | DeSmuME `0.9.9 svn 4608`; independent upstream revision not recorded | `24728d8692a2115b89fd4c97efc6acd415e1515c19051483c6b55618b848d19c` | GPL source snapshot used by the 2SF bridge |
| `PSFLib` | Independent upstream revision not recorded | `5cacd2dbf72a1be9aa2807143f57c516951b83a9863de891c25b0240b2af0a01` | Compiled with lazyusf2 for PSF-family dependency resolution |
| `psflib-qsf` | `3bea757c8b45c5e68da1b5a7b736ad960a06a124` | `6185be166b72cad6860e6f3bb935afff26dbd47f75980840e88ed9fd287f4f61` | [kode54/psflib](https://gitlab.com/kode54/psflib); QSF support |
| `mdxmini` | `003531a471c1955f4ed4357d0e2a6cba809c34a0` | `866bac50ce0325152f5c4c00dfc2e1b7e5caccaae81ca2af854a9de3226e7c1d` | [mistydemeo/mdxmini](https://github.com/mistydemeo/mdxmini); GPL-2.0-or-later |
| `zxtune` | `c93e81d081685ea2c7cd21fe0077e93d84b4d88d` | `163526dcd19c65808623f1115d5c62e7ab878bf4f794ec191d2f566ee8e33a5a` | [vitamin-caig/zxtune](https://github.com/vitamin-caig/zxtune); LGPL-3.0; focused AY-family build |
| `psgplay` | `f2028e94e5f6c7b3b38c9f7b5e2e0e1939613c06` | `bf09f5b024f46b4a40f5ce6f4091bdf304ffe74325b526ef52edc0c2666d84b7` | [frno7/psgplay](https://github.com/frno7/psgplay); required nested source included |

All listed source is stored as regular files in this repository. The recorded upstream commit
identifies the source base where available; the SHA-256 covers the exact checked-in directory.
Compatibility patches are separately versioned under `VGMBoy/patches/` and applied to disposable
build copies where required. Missing upstream revisions remain explicitly marked rather than
being inferred from a local snapshot hash.
