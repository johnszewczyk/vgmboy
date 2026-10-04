# Base Set Profile

Shared rules for every collection conversion. Apply this profile alongside
the procedure for each package's source format.

## Scope

- **Purpose** — Define shared set identity, package-level set fields,
  first-pass eligibility, and identity confidence.
- **Format mappings** — Keep source-field recognition and UAC mappings in
  each source-format profile.

## Source Authority

- **Package fields** — Project **Set Collection**, **Set Name**, and **Set
  URL** once per package when the set is unambiguous. Add optional **Set Legacy
  URL**, **Set Archive URL**, or **Set Date** when supported. Keep full source
  records and hashes in `sources[]`.
- **Original packages** — Keep source packages in source-state outside derived
  UAC payloads; link each UAC package through `sources[]`.
- **Hash scope** — Record each hash with its actual byte scope, algorithm,
  size, and profile. Keep source-archive hashes separate from member
  integrity and playable-payload hashes.
- **Hash meaning** — Matching hashes prove byte identity only. They do not
  prove shared provenance, set membership, source authority, or game identity.

## Identity Enrichment

- **First-pass eligibility** — Each set profile states which source items
  enter the initial harvest. A completeness-targeted set may limit a batch to
  positively identified games; a loose-file collection may include all
  source-backed items and leave identity unresolved. Keep the chosen batch
  scope explicit and do not silently exclude unmatched items.
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
  or release identifier. Never put `--` in a package filename.
- **Filename region** — Use the canonical base title as the filename when it
  is unique within the set. Add a known region suffix only to distinguish
  packages that would otherwise have the same filename. A set profile may
  explicitly keep region suffixes throughout a collection with many parallel
  regional releases; state that exception in the set profile. Keep the Region
  tag even when the filename does not show it.
- **Candidate releases** — A title or region match alone does not establish a
  release ID. Do not add a candidate ID or ID-based filename suffix until one
  unique release is confirmed; otherwise use the known title and
  source-supported facts in the package name.

## Required Checks

- **Source linkage** — Confirm source references identify the authority and
  original package used for each derived UAC.
- **Single format** — Keep each UAC package to one playable format and confirm
  the package-level **Format** field agrees with its playable members.
- **Hash accounting** — Keep hash records scoped to the exact bytes they
  identify; do not use byte identity as proof of provenance or game identity.
- **Identity review** — Record confirmed IDs and database enrichment sources;
  leave ambiguous candidates unresolved.
- **Report boundary** — Keep collection counts, unusual files, observed
  arbitrary tags, and per-item exceptions in dated AudioMan set reports. Keep
  this profile to reusable conversion rules.
