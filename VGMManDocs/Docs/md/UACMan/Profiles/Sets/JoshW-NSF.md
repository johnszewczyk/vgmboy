# JoshW NSF Set Profile

Apply the [Base Set Profile](BASE-SET-PROFILE.md) and the
[Nintendo Sound Format profile](../NSF.md). This is an input rule for the
JoshW NSF source only; actual coverage and exceptions belong in AudioMan's
per-set reports.

## Scope

- **Collection** — The NSF catalog at `https://nsf.joshw.info/`, covering
  Nintendo NES and Famicom Disk System source packages.
- **Format** — `.nsf` only. Exclude `.nsfe` from this pass, even when both
  formats occur in one outer archive. Do not combine NSFE songs with NSF
  songs.
- **Package selection** — Use one source package per distinct archive. If an
  identical archive is staged in more than one platform folder, create only
  one UAC and use the folder matching its verified platform.
- **Readiness** — Profile proposed; hold UAC creation until NSF M3U parsing,
  authored timing, version display, Stream Hashes, and UACMan visibility meet
  the format profile.

## Source Authority

- **Package fields** — Set Name is `JoshW`; Set URL is
  `https://nsf.joshw.info/`. Keep both at package scope.
- **Source archive** — Preserve the original `.7z` source-state archive on
  EXT. The staged Garden copy may use ZIP DEFLATE-8. Do not bundle the outer
  `.7z` inside UAC or expose its archive hash as a track/file hash tag.
- **Source linkage** — Link the UAC to the exact source archive through
  `sources[]`. Reuse its stored identity only after current archive/member
  content is matched. Do not infer provenance from shared NSF bytes alone.
- **Companion data** — Keep the M3U files that resolve to the selected NSF,
  plus useful source text, as byte-exact package attachments. Hold ambiguous
  playlists, IPS patches, or documents that describe both NSF and NSFE rather
  than applying or dropping them.
- **Platform** — Use the approved canonical aliases in
  [`PLATFORMS.md`](../PLATFORMS.md). Hold FDS UAC output until Famicom Disk
  System has an approved platform alias; do not label it Nintendo NES based
  only on the NSF signature.

## Identity and Naming

- **Game Title** — Preserve the NSF header game name under Game Title. Keep
  this source title distinct from a canonical Game ID.
- **Game ID** — Add a No-Intro Game ID only after AudioMan verifies one
  release. A unique title root does not prove region or revision.
- **Region** — Keep a source-backed Region when known. Use `Region: --` only
  after review confirms it is unresolved. Put a known region in the filename
  only to distinguish packages that would otherwise collide; never put `--`
  in the filename.
- **Filename** — Use the confirmed canonical game title when identified.
  Keep unresolved packages in the source name until the identity review gives
  a safe canonical name.

## Set Procedures

- **NSF source tags** — Apply the NSF format mappings for Game Title,
  Album Artist, Copyright, Comment, Composer, Dumper, Taggers, Developer,
  Publisher, Year/Date, per-track Title, and authored timing. Omit blank,
  placeholder, and generated-tool values.
- **Member hashes** — Keep the four standard compact hashes for each physical
  NSF payload in UAC Stream Hashes. Hash once per NSF, not once per song. Do
  not create duplicate checksum tags or place outer `.7z` hashes in Stream
  Hashes.
- **Source documents** — Preserve relevant playlists and source notes. Do not
  mine freeform text into tags unless the NSF format profile names an
  unambiguous useful field.
- **Review status** — Use `Status: Mixed Versions` only for a package with
  verified mixed NSF versions. Use `Status: Corrupt` only for a confirmed
  critical header/data fault. Omit Status otherwise; never add `Good`.

## Required Checks

- Confirm the source archive and member records match the current staged
  bytes, and record the exact `.nsf` selected for the UAC.
- Confirm every playlist row resolves to that NSF and an in-range song,
  including fractional time precision, escaped commas, loop starts, fades,
  and cross-playlist conflicts.
- Confirm all source-backed values use Title Case tags, no blank or generated
  tags appear, and source M3Us/text remain attached.
- Verify the physical NSF appears once, its four hashes are visible in
  Stream Hashes, and the package contains no NSFE member.
