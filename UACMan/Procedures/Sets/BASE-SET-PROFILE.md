# Base Set Profile

Shared rules for every collection conversion. Apply this profile alongside
the procedure for each member's source format.

## Scope

- **Purpose** — Define shared set provenance, metadata-harvest stages, and
  identity confidence.
- **Format mappings** — Keep source-field recognition and UAC mappings in
  each member format profile.

## Source Authority

- **Source reference** — Record the set name and authoritative source URL or
  release reference.
- **Original packages** — Keep source packages in source-state outside derived
  UAC payloads; link each UAC package through `sources[]`.
- **Hash scope** — Record each hash with its actual byte scope, algorithm,
  size, and profile. Keep source-archive hashes separate from member
  integrity and playable-payload hashes.
- **Hash meaning** — Matching hashes prove byte identity only. They do not
  prove shared provenance, set membership, source authority, or game identity.

## Identity Enrichment

- **Source pass** — Map populated, recognized source fields through the format
  profile. Keep selected canonical UAC fields; do not add database enrichment.
- **Identity pass** — Match the known title against an authoritative game
  database. Add a release Game ID and selected database fields only after a
  positive, unique match; record the enrichment source in provenance.
- **Unresolved release** — This is normal after the source pass. Keep the
  known base title in `game.title`, omit Game ID while release, region, or
  revision is uncertain, and do not quarantine solely because identity remains
  unresolved.

## Set Procedures

- **Known region** — Preserve a region explicitly stated by the source as
  package Region.
- **Reviewed unknown region** — Use `Region: --` when review confirms the
  region is unknown. `--` records known uncertainty; it is not a region code
  or release identifier.
- **Candidate releases** — A title or region match alone does not establish a
  release ID. Do not add a candidate ID or ID-based filename suffix until one
  unique release is confirmed; otherwise use the known title and
  source-supported facts in the package name.

## Required Checks

- **Source linkage** — Confirm source references identify the authority and
  original package used for each derived UAC.
- **Hash accounting** — Keep hash records scoped to the exact bytes they
  identify; do not use byte identity as proof of provenance or game identity.
- **Identity review** — Record confirmed IDs and database enrichment sources;
  leave ambiguous candidates unresolved.
