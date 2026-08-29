# Shared Source Provenance

This file records the source identity available in the VGMBoy checkout. A tree digest is the
SHA-256 of the sorted per-file SHA-256 records for that source directory, excluding `.git` metadata.
It is a local snapshot identity, not a substitute for an upstream commit.

| Source | Upstream identity | VGMBoy snapshot digest | Notes |
| --- | --- | --- | --- |
| `libvgm` | `867223e7c33d63de115d1ab955f784c44f19040a` | submodule commit | [ValleyBell/libvgm](https://github.com/ValleyBell/libvgm) |
| `lazyusf2` | `421f00bcaa1988b8e1825e91780129f24fbd1aa0` | submodule commit | [kode54/lazyusf2](https://gitlab.com/kode54/lazyusf2) |
| `Play!` | `50aedca2639521bc498ace0b2be1ea012801a86a` | submodule commit | [jpd002/Play-](https://github.com/jpd002/Play-) |
| `vgmstream` | `807b4948cfc1de0cd90e377e9c56f74664c54a1c` | submodule commit | [vgmstream/vgmstream](https://github.com/vgmstream/vgmstream), plus the VGMBoy compatibility patch |
| `aosdk` | `e359a6e5154b2ba8499fb1f24a1f5f8a18538a61` | submodule commit | [nmlgc/aosdk](https://github.com/nmlgc/aosdk), plus the tracked QSF lifecycle patch in `patches/aosdk-qsf-lifecycle.patch` |
| `mGBA` | `0.11.0`; upstream revision not recorded in the inherited snapshot | `b7b71f64dab500433f3662b818e3521cf67524dcdee1a9952c1f555629ff55c0` | [mgba-emu/mgba](https://github.com/mgba-emu/mgba); used by the Highly Complete bridge |
| `2sf2wav` | DeSmuME `0.9.9 svn 4608`; independent upstream repository not recorded | `c3e329f9cf72881d25dabb03b9a89ebd4125ca9bd6d44c26f642589c622a9fb7` | GPL source snapshot used by the 2SF bridge |
| `PSFLib` | Independent upstream revision not recorded in the inherited snapshot | `c3adb7ea371fbeeedc68b3747c314419b52d9cb46aa0d75f177f428bcdb7d021` | Compiled with lazyusf2 for PSF-family dependency resolution |
| `mdxmini` | `003531a471c1955f4ed4357d0e2a6cba809c34a0` | vendored source snapshot | [mistydemeo/mdxmini](https://github.com/mistydemeo/mdxmini), GPL-2.0-or-later, with case-insensitive PDX lookup compatibility patch |

The submodule commits are pinned in `.gitmodules` and the Git tree. Compatibility changes for
upstream gitlinks are applied to disposable build copies from `patches/`; the vendor checkouts
remain upstream-readable. The three ordinary source snapshots should receive an upstream commit
or release tag if their source is refreshed.
