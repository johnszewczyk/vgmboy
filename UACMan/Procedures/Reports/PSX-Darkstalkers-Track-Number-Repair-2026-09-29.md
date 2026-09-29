# Darkstalkers PSX physical track numbering repair — 2026-09-29

## Final package

`audio/Derived/Export/PlayStation/Darkstalkers - The Night Warriors (US)/UAC/Darkstalkers - The Night Warriors (US).uac`

The 45 CD-DA members now use filenames and direct **Track Number** values
`02`–`46`, matching the physical audio tracks in the byte-exact Redump CUE.
The data track 01 is not an audio member. UACMan's row index and playlist order
remain 1–45; they are display/order positions, not disc track tags.

The package metadata carries **Game ID**, **Region**, **Set Name**, and
**Set URL**. **Set Collection** was removed from the tag surface; collection
context remains in the Redump source record. The repeated single-disc
**Disc Number** value was omitted. Track members keep **Album**, **Platform**,
**Format**, and **Track Number** as direct Title Case fields. The source APEs
contain no useful titles or credits, so those fields remain absent.

## Preservation and verification

The 45 APE payloads are byte-identical to the previous verified members under
their new paths. The CUE and Redump verification TSV are byte-identical. The
archive source hashes and published BIN/CUE checksums remain at their existing
source/attachment locations; no per-track payload hash catalog was added.

`uacman inspect --verify` passed. A complete unpack verified all 48 members,
and a byte comparison confirmed the 45 APE streams, CUE, and verification TSV.
