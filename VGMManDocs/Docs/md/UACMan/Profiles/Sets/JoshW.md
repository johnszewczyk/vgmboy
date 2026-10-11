# JoshW SNES Set Profile

Apply the [Base Set Profile](BASE-SET-PROFILE.md) and the
[Nintendo SNES SPC profile](../SPC.md). Keep actual coverage, metadata
comparisons, and exceptions in AudioMan's JoshW SNES UAC report.

## Scope

- **Collection** — JoshW's Nintendo SNES SPC collection.
- **Format profiles** — SPC only; a package contains SPC tracks and preserved
  non-audio source documents. Keep lossy audio out of the lossless SPC UAC
  pass and record any mixed SPC/lossy source packages for separate review.
- **First-pass eligibility** — Build a source-faithful UAC for each source
  package with SPC members. Do not require a positive Game ID to preserve a
  source package; unresolved identity remains explicit until AudioMan confirms
  it.

## Source Authority

- **Source** — Use **Set Name** `JoshW` and **Set URL**
  `https://spc.joshw.info/` on each package.
- **Original packages** — Keep source `.7z` archives outside the UAC payload.
  Link each package through `sources[]`, using the existing source-state
  identity when available. Do not invent a `Source .7z Hashes` tag or copy the
  source archive into the UAC.
- **Track hashes** — Keep the four standard **Stream Hashes** for every SPC
  member. Do not add a second set of checksum tags.
- **Documents** — Preserve source-provided TXT, M3U, and other useful
  non-audio files as package assets. Surface a document field only when its
  label and value have an unambiguous, useful mapping; retain the original
  document as evidence.
- **Package credits** — Use package-level **Dumper** or **Taggers** only for
  clearly labeled source credits. Preserve SPC-native track **Dumper** values
  at track scope. Do not add **Downloaded From** or blank tags.

## Identity Enrichment

- **Identity source** — Use AudioMan's stored SPC stream identities and the
  canonical No-Intro Nintendo SNES database.
- **Match rule** — Reuse existing positive stream-to-game links first. For
  remaining packages, compare every normalized title word and intersect the
  candidate roots. Once one No-Intro game root is supported, store that
  canonical title string as package **Game ID**, even when release, region, or
  revision is unresolved. Keep numeric DAT IDs in AudioMan only. If the root
  itself is ambiguous, omit **Game ID** and leave the package for review.
- **Filename** — Name identified packages from their canonical game title.
  Append a known region only when needed to distinguish packages in the set;
  never put `(--)` in the filename.

## Set Procedures

- **Native tags** — Apply the SPC profile's Title Case field mapping without
  rewriting the SPC bytes or their embedded ID666/xID6 tags.
- **Japanese game title** — When a populated source tag explicitly gives the
  Japanese game-title alias (often marked `(J)` in the source title), preserve
  that exact value as **Game Title (JP)** at the same track scope. Do not
  derive it from a filename or canonical title, replace **Album**, or create a
  blank tag.
- **SPC version** — Store each member's actual version as **Format** (for
  example, `SPC v.30` or `SPC v.10`). Preserve mixed versions and report them;
  do not normalize header versions.
- **Duplicates** — Compare complete stream-hash multisets, member metadata,
  source documents, source authority, and identity evidence. A 1:1 stream match
  does not establish that one source has better metadata; retain the more
  complete source package in the master and keep distinct content or verified
  source-tag improvements traceable to their origin.
- **Unusual packages** — Keep unusually small, SFX-like, lossy, or mixed-format
  candidates visible for individual review. Do not silently discard tracks or
  infer that a short package is complete.

## Required Checks

- **Source link** — Confirm every UAC's source reference resolves to the
  correct source-state package record.
- **Track coverage** — Account for each SPC member and each retained source
  document; list exclusions such as lossy members in the per-set report.
- **Metadata** — Confirm Title Case tags, nonblank source-backed values,
  per-track Format, and four Stream Hashes on each SPC.
- **Package** — Verify UAC integrity and compare each packaged SPC with the
  source member bytes. Keep the source archives outside the UAC.
