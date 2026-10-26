# PSF-Style Tag Family Profile

Apply the [UAC Base Profile](BASE-UAC-PROFILE.md). The generic PSF-style
reader parses the bounded [TAG] footer. Platform-specific readers may add
stronger container checks; see [MetaMan format layouts](../../MetaMan/format-layouts.md).

## Scope

- **Reader** — psf-family in MetaManCore.
- **Extensions** — PSF, PSF2, SSF, USF, 2SF and supported mini variants.
- **Source members** — One physical PSF-style file per member; dependencies are
  handled by the concrete format profile.
- **Coverage** — Shared UTF-8 tag footer and length/fade projection. The
  generic reader does not establish game identity, validate every platform
  payload, or resolve library dependencies.
- **Status** — Mapping documented. Fixture and package approval remain separate.

## Field Mapping

| Source Tag | UAC Tag | UAC Coded Tag | Tag Notes |
| --- | --- | --- | --- |
| PSF-family title | Title | `members[].metadata["Title"]` | Preserve authored value; omit empty values. |
| PSF-family game | Game Title | `game.metadata["Game Title"]` | Not No-Intro Game ID. Match DAT identity separately. |
| PSF-family artist | Artist | `members[].metadata["Artist"]` | Use Album Artist only when evidence establishes package-wide scope. |
| PSF-family album | Album | `members[].metadata["Album"]` | Preserve populated value. |
| PSF-family date | Date | `members[].metadata["Date"]` | Preserve populated value. |
| PSF-family year | Year | `members[].metadata["Year"]` | Keep only when distinct from Date. |
| PSF-family genre | Genre | `members[].metadata["Genre"]` | Preserve populated value. |
| PSF-family comment | Comment | `members[].metadata["Comment"]` | Preserve populated value. |
| PSF-family copyright | Copyright | `members[].metadata["Copyright"]` | Preserve populated value. |
| PSF-family psfby or encodedby | Encoded By | `members[].metadata["Encoded By"]` | Prefer psfby when both are present. |
| PSF-family length | Play Length (ms) | `members[].metadata["Play Length (ms)"]` | Convert positive authored seconds to milliseconds. |
| PSF-family fade | Fade Length (ms) | `members[].metadata["Fade Length (ms)"]` | Convert positive authored seconds to milliseconds. |

## Application Behavior

- **Package structure** — Keep one physical PSF file per member. Represent
  subsongs as ordered playlist entries only when the source or a format profile
  provides them.
- **Platform rules** — Use each format profile for structural platform names
  and payload/dependency behavior. Do not use a generic PSF reader result as
  identity authorization.
- **USF** — Follow the existing [USF profile](USF.md) for its additional
  source and container rules.

## Format Procedures

- **Footer location** — Accept tags only at the exact computed source end.
  Preserve tagless inputs without inventing fields.
- **Dependencies** — A generic [TAG] footer is not proof that required library
  members are present or valid.

## Required Checks

- **Format-specific payload** — Use the reader and package checks for the
  concrete extension, including any library chain.
- **Tags** — Compare tag footer values with UAC scope and ensure raw native
  bytes remain unchanged.
- **Package review** — Confirm visible fields and playlist behavior in UACMan
  and the applicable consumer before approving conversion.

## Reader Reference

- [PSFMetadataReader.swift](../../../../../MetaMan/Sources/MetaManCore/PSFMetadataReader.swift)
