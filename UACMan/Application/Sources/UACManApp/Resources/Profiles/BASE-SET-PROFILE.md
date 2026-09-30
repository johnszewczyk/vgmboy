# Base Set Profile

Apply this profile to a collection conversion together with the procedure for
each source format. It defines shared set provenance, metadata-harvest stages,
and identity confidence.

## Source authority

- Record the set name and authoritative source URL or release reference.
- Keep original source packages in source-state outside derived UAC payloads;
  link each UAC package to its source through `sources[]`.
- Record hashes at their actual byte scope with algorithm, size, and profile.
  Keep source-archive hashes separate from member integrity and playable-payload
  hashes. Use the nested hash model for repeated records.
- Matching hashes prove byte identity only. They do not establish shared
  provenance, set membership, authority, or game identity.

## Two-pass harvest

1. **Source pass:** map populated, recognized source-format fields through the
   format profile. Keep only selected canonical UAC fields. Do not enrich from
   scraped databases during this pass.
2. **Identity pass:** match the known game title against the authoritative game
   database. Add a release **Game ID** and selected database metadata only after
   a positive, unique identity match; record the enrichment source in
   provenance.

The source pass is useful on its own. An unresolved release is normal. Keep the
known base game title in `game.title`, but omit **Game ID** while the release,
region, or revision is uncertain. Do not quarantine a package solely because
the second pass has not resolved it.

## Region and uncertainty

- Preserve a region explicitly stated by the source as package **Region**.
- If region has been reviewed and remains unknown, use **Region** = `--` to
  state that the uncertainty is known. `--` means unknown; it is not a region
  code or a release identifier.
- A base-title or region match alone does not establish a release ID. Do not
  add a candidate ID or an ID-based filename suffix until the identity pass
  confirms one unique release. Use the known title and source-supported facts
  for the package name.
