# SNESMusic.org source-set profile

This is a per-set provenance and identity contract for the historic
SNESMusic.org SPC soundtrack archive. SPC field extraction and header review
are defined in [`../SPC.md`](../SPC.md). This collection is not a VGM subset,
and its original RSNs are source-state evidence rather than UAC members.

## Source authority and linkage

- Set Name: `SNESMusic.org`.
- Set URL: `https://snesmusic.org/v2/torrent.php`.
- Keep each original `.rsn` intact in source-state; do not embed it in the UAC.
- Each package identifies its **Source RSN** by original name and source path.
- Package metadata contains exactly four **Source .rsn Hashes** for the
  source archive: BLAKE3-256, CRC32/ISO-HDLC, SHA-1, and MD5. Each item keeps
  its digest, byte size, scope, and profile. Do not create Current/Initial
  catalogs for the same RSN.
- Each SPC track has four `uac-playable-payload-v1` checksums over the complete
  byte-identical SPC file. Display that list as **Stream Hashes**, with
  **Stream BLAKE3-256**, **Stream CRC32**, **Stream SHA-1**, and **Stream MD5**.
- The original SPC bytes preserve ID666/xID6 tags. Do not edit those source
  tags. Do not show an opaque **Native Metadata** tag; report parser findings
  in the conversion report.

## Game identity and names

- Resolve the canonical Game ID using AudioMan's canonical-game database, whose
  release records come from the No-Intro SNES DAT. When one high-confidence
  Nintendo SNES DAT ID is established, surface its four-digit value as the
  package-level **Game ID** tag. Keep this separate from package `game.title`,
  track **Game Title**, **Album**, and **OST Title** until their values are
  reconciled. Do not assign a Game ID from a multi-ID, medium-confidence, or
  unmatched result.
- Recommended package filename: `<Canonical No-Intro Title> [<GameID>].uac`.
  Keep the SPC member filename as `NN-Track Name.spc`; the prefix is the
  visible track sequence, not the package GameID.
- If no unique GameID is established, place the package in
  `Review/Unidentified Games/Nintendo SNES/` and preserve the source RSN link.
  A plausible title match or shared hash alone does not resolve release,
  region, or revision identity.
- Track tags use populated source values with Title Case display labels. Keep
  **Album**, **Game Title**, and **OST Title** as separate fields. Use **Album**
  only when the source has a distinct Album field; never create it by relabeling
  `OST Title`. Keep source **Game Title** values and list multiplicity intact
  until the later reconciliation pass.
- Route packages with list-valued **Game Title** entries or per-track
  **Game Title** variation to `Review/Game Title Conflicts/Nintendo SNES/`.
  Preserve every value as stored; do not flatten a list or promote a value.
- Preserve **Artist**, **Publisher**, and **Dumper** as those tag names.
  **Copyright Year** maps to canonical **Year** without changing SPC source
  bytes. Preserve a source **Date** as Date. Do not derive Year from Date.
- Map a populated source **OST Disc** value to the UAC track tag **Disc Number**;
  retain its value exactly. The original SPC bytes continue to contain the
  source field.
- Do not infer Developer from Publisher. Add Developer only when separately
  established by the user or an authoritative source.
- Package `game.title`, package **Game ID**, member **Game Title**, **Album**,
  and xID6 **OST Title** are distinct fields. Keep their current values
  separate until the [discrepancy report](../Reports/SNESMusicOrg-Album-GameTitle-Discrepancy-2026-09-24.md)
  is reviewed and an explicit mapping is adopted. Current indexed manifests
  have no literal member **Album** field; do not synthesize one from **OST
  Title**.

## Minimal fields and exceptions

- Track projection: Title, Game Title, distinct source Album when present,
  OST Title, Artist, Publisher, Developer when present, Dumper, Track Number,
  Disc Number (from OST Disc), OST Track, Format, Year, Date,
  and Comment when populated. Add explicit timing or other source-backed
  fields only when meaningful.
- Record **Format** on every SPC track using the version read from that
  track's header, including repeated `SPC v.30`. Every valid version is
  ordinary track metadata; a `SPC v.10` value is not an exceptional tag.
  Keep each member's value. If a package contains multiple valid versions,
  report the distribution and route that package to the mixed-version review
  path. Review malformed, unreadable, or contradictory headers separately.
- Do not emit Formats Scanned, schema version, a verbose container-version
  inventory, or an opaque Native Metadata field as ordinary tags.
- Keep **Set Name**, **Set URL**, **Source RSN**, and **Source .rsn Hashes** at the
  package/source boundary, not duplicated on every track.

## SNESMusic.org builder requirements

The set-specific builder must read the canonical game mapping from AudioMan
and refuse to assign a package GameID when the mapping is absent or ambiguous.
It must generate the ID-based package name, emit a proposed-tag report before
writing package changes, preserve the source SPC bytes, project only the
approved track fields, and attach four source-RSN hashes plus four playable
checksums per SPC. It must validate existing hash scope/profile
before reuse and fail the build on missing algorithms, malformed or
unreadable SPC headers, contradictory version evidence, an unreviewed
mixed-version package, or unresolved release identity. Valid per-track version
tags remain present on packages in the review path.

## Provenance limits

SNESMusic.org is a historic source collection. Preserve this source-state link
even when normalized SPC payloads match files found in other collections.
Record exact hash relationships, but do not claim one collection derives from
another without direct provenance evidence. Apply the same source-state and
four-hash principles to other historically authoritative collections under
their own set profiles; do not copy SNES-specific RSN fields to unrelated
formats.

## Current identity review note

The Super Castlevania IV title currently links to five No-Intro candidates:
2611 (Europe), 2612 (USA), 3852 (USA, Anniversary Collection), 3861 (Europe,
Virtual Console), and 3862 (USA, Virtual Console). Until another source-backed
fact disambiguates the original RSN, keep this package's canonical GameID and
ID-based filename unresolved.
