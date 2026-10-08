# Project 2612 Set Profile

Apply the [Base Set Profile](BASE-SET-PROFILE.md) and the source-format
profile for each package. Record only reusable Project 2612 rules here.

## Scope

- **Collection** — Historic Sega VGM collection covering multiple platforms
  and source formats.
- **Format profiles** — Apply the applicable source-format procedure to each
  package. Do not list unrecognized source fields here.
- **First-pass eligibility** — This completeness-targeted set may use an
  ID-confirmed-only batch. Keep unmatched source items in AudioMan's set
  report until a later identity pass; do not infer exclusion from missing ID.

## Source Authority

- **Package fields** — Set **Set Collection** to `Project 2612`; use the
  source-record's platform-specific name as **Set Name** and its current
  listing as **Set URL**. Preserve the original and archive links as **Set
  Legacy URL** and **Set Archive URL** when applicable. Keep complete source
  locations and identifiers in `sources[]`.
- **Membership** — Do not infer set membership from title or content overlap.

## Identity Enrichment

- **Release identity** — Apply the Base Set Profile's positive, unique match
  rule. Keep platform-specific identity limits in the relevant dated review
  report.

## VGMRIPS Overlap Filter

- **Sega consolidation** — VGMRIPS is the primary managed source when Sega
  packages overlap. In a consolidated UAC output, omit Project 2612 playable
  contributions only after the current VGMRIPS package has the same complete
  stream-hash multiset and Project 2612's distinct TXT metadata has been
  harvested for source-attributed aggregation. Keep every Project 2612 source
  archive and its source-set inventory unchanged. This filters only the
  duplicated playable contribution; it does not collapse source notes into
  VGMRIPS tags or remove Project 2612 provenance.
- **Text structure** — Keep package headers, notes, and history separate from
  tracklist tables. Track names, order, lengths, and loop lengths are source
  evidence, not package tags; retain them in the tracklist record and do not
  promote them to UAC tags automatically.
- **Review boundary** — A partial stream overlap, changed track order or
  playlist queue, mixed VGM container versions, unique attachment, or
  unresolved metadata difference stays visible for review. Matching stream
  hashes prove playable-byte identity; they do not prove that playlists,
  curation, or package metadata are redundant.

## Set Procedures

- **Format coverage** — Apply the matching source-format profile to each
  package; keep reader-to-UAC mapping rules in those profiles.

## Required Checks

- **Source linkage** — Verify that each package links to the source record
  used to create it.
