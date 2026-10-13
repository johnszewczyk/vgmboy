# Format profile: `mdx`

Parent playback plugin: `mdx`. This page groups the subformats admitted by that plugin and records their ScanSong route, metadata source, and format-specific boundaries. The shared registry matrix, route inventory, and scanner contracts remain in [format-accommodations.md](../format-accommodations.md).

## .mdx — sequence and dependency handling

`.mdx` is a one-track logical X68000 sequence. MetaManCore owns its clear
Shift-JIS title, PDX-reference metadata, and bounded timing walk over
uncompressed MML. It simulates sequencer time only; it does not render or
synthesize audio. The current timing policy caps F1 loops at three traversals,
uses the driver's five-tick fade, and refuses timing walks beyond 1,200
seconds. ScanSong retains the VGMBoy-built `vgmboy-mdx-inspect` executable to
fail closed when mdxmini cannot open the module with its required dependency,
but never uses its reported duration. LZX-compressed bodies still receive
header metadata and player validation, but MetaMan reports timing unavailable
until it has a direct bounded LZX decoder. Dependency names are decoded using
the legacy Shift-JIS convention, with UTF-8 fallback for hand-authored files.
PDX remains dependency data, not a playable source row.

PDX is native X68000 sample-bank data, not an archive and not an alternate MDX
encoding. SMP and PCM companions, plus an explicitly referenced MDX sidecar,
are dependency data in this path rather than automatically being new scan
sources. When an MDX declares a dependency, ScanSong looks for a
case-insensitive local sibling first, including compressed `.zst`/`.zstd`
forms, then optionally uses a deterministic root-scoped index for `.pdx`,
`.smp`, `.pcm`, and `.mdx`: nearest shared folder, uncompressed before
compressed, and lexical path order. It never searches outside the supplied
scan root.

The dependency reader infers `.pdx` only when the MDX reference is
extensionless. Explicit alternate references such as `NOS.SMP`, `THRICE.PCM`,
or `KONAMI.MDX` are preserved verbatim (apart from case-insensitive filesystem
matching), so they are not turned into false names such as `NOS.SMP.PDX`.

For `name.MDX.zst`, the decompressed MDX is placed in disposable scratch and
the matching dependency is materialized beside it before the inspector starts.
Standalone compressed PDX, SMP, and PCM companions are suppressed from
discovery. A declared but missing dependency
is an explicit MDX failure. The inspector checks the materialized scratch
directory before launching mdxmini and includes the declared name in the
failure (`Required MDX dependency is missing: name.`); it is not a successful
metadata row with an unknown dependency. Failures are recorded per declaring
module, so issue reports must deduplicate dependency names before treating their
counts as a bank inventory; several modules may legitimately share one bank.

The VGMBoy/mdxmini boundary also handles the inner X68000 LZX 0.32/0.42 form.
For MDX, the clear title and dependency header are preserved while only the
compressed sequence body is decoded. For PDX, a whole-file LZX stream is
decoded before the native sample-bank table is parsed. This is a lossless
scratch-layer accommodation: the outer `.zst` and original MDX/PDX payloads
are never rewritten. A legacy leading backslash in a PDX basename is treated
as a same-directory reference; absolute and traversal spellings remain unsafe.
