# Platforms

Set one canonical package-level value in structural `game.console`. Platform
names are identity, not a repeated per-track tag. Match only complete,
unambiguous source labels; do not infer a platform from a title, filename,
directory, chip list, or partial text match.

## Canonical Names

| Platform | Aliases |
| --- | --- |
| Nintendo NES | NES; Nintendo NES; Nintendo Entertainment System; Famicom; Family Computer; NES / Famicom; Nintendo Entertainment System / Famicom; Nintendo Entertainment System / Family Computer |
| Nintendo SNES | SNES; Super NES; Super Nintendo; Super Nintendo Entertainment System; Super Famicom |
| Nintendo Game Boy | GB; Game Boy; Gameboy; Nintendo Game Boy |
| Nintendo Game Boy Color | GBC; Game Boy Color; Gameboy Color; Nintendo Game Boy Color |
| Nintendo Game Boy Advance | GBA; Game Boy Advance; Gameboy Advance; Nintendo Game Boy Advance |
| Nintendo 64 | N64; Nintendo 64; Ultra 64 |
| Nintendo Family Computer Disk System | FDS; Famicom Disk System; Family Computer Disk System; Nintendo Famicom Disk System; Nintendo Family Computer Disk System |
| Dendy | Dendy |
| NEC TurboGrafx-16 | TurboGrafx; TurboGrafx-16; PC Engine; PC-Engine |
| MSX | MSX Home Computer |
| Sega Master System | Master System; Sega Mark III; Mark III |
| Sega Game Gear | Game Gear |
| Sega Genesis | Sega Mega Drive; Mega Drive; Genesis |
| Sega CD | Sega Mega CD; Mega-CD; MegaCD; SegaCD |
| Sega 32X | 32X; Mega 32X; Super 32X |
| Sega Pico | Pico |
| Sega SG-1000 | SG-1000; Game 1000 |
| Sega SC-3000 | SC-3000; Computer 3000 |
| Othello Multivision | Othello Multivision |
| Sony PlayStation | PlayStation; PlayStation 1; PS1; PSX; Sony PlayStation |
| NEOGEO | NEOGEO; NeoGeo; Neo Geo; Neo-Geo; Neo•Geo; optional `SNK`, `SNK-`, or `SNK -` prefix |
| NEOGEO MVS | NEOGEO MVS; NeoGeo MVS; Neo Geo MVS; Neo-Geo MVS; Neo•Geo MVS; optional `SNK`, `SNK-`, or `SNK -` prefix |
| NEOGEO AES | NEOGEO AES; NeoGeo AES; Neo Geo AES; Neo-Geo AES; Neo•Geo AES; optional `SNK`, `SNK-`, or `SNK -` prefix |
| NEOGEO CD | NEOGEO CD; NeoGeo CD; Neo Geo CD; Neo-Geo CD; Neo•Geo CD; optional `SNK`, `SNK-`, or `SNK -` prefix |
| NEOGEO Pocket | NEOGEO Pocket; NeoGeo Pocket; Neo Geo Pocket; Neo-Geo Pocket; Neo•Geo Pocket; optional `SNK`, `SNK-`, or `SNK -` prefix |
| NEOGEO Pocket Color | NEOGEO Pocket Color; NeoGeo Pocket Color; Neo Geo Pocket Color; Neo-Geo Pocket Color; Neo•Geo Pocket Color; optional `SNK`, `SNK-`, or `SNK -` prefix |

Use the canonical name exactly as written. NES/Famicom and Family
Computer/NES are regional aliases for the same console. Do not collapse FDS,
Game Boy Color, or Game Boy Advance into another Nintendo platform. If a source
does not establish one approved platform, or a package combines distinct
platforms without one package-level identity, hold it for review rather than
inventing an alias. Treat source-labeled Dendy as its own Famicom-clone platform,
not as a Nintendo NES alias. For VGM GD3 only, normalize the documented NES
misspellings `Nintendo Enterainment System`, `Nintendo Entertaiment System`,
and `Nintendo Entertainemnt System` to `Nintendo NES`; do not preserve those
misspellings in the UAC structural console or English GD3 System field.
For NES VGM packages, use the concise canonical value `Nintendo NES` in
`game.console`, the platform folder, playlist-facing console display, and the
English GD3 System field. Treat exact `Nintendo Entertainment System`,
`Family Computer`, and `Famicom` English GD3 values as aliases; trim accidental
leading or trailing whitespace before matching. Preserve Japanese System and
other GD3 values. Keep FDS, Vs. System, Dendy, and genuinely mixed packages
distinct or in review rather than flattening them into Nintendo NES.

For the SNK family, use the official `NEOGEO` spelling. Keep the named
hardware variants `NEOGEO MVS`, `NEOGEO AES`, `NEOGEO CD`, `NEOGEO Pocket`,
and `NEOGEO Pocket Color` distinct; do not collapse them into generic
`NEOGEO`.
Alias matching is case-insensitive and exact after trimming surrounding
whitespace; punctuation variants and the optional SNK prefix do not change the
hardware identity.
SNK's [official catalogue](https://neogeomuseum.snk-corp.co.jp/english/catalogue/index.php)
uses `NEOGEO` and distinguishes MVS Cartridge, NEOGEO ROM-cart, and NEOGEO CD;
SNK's [Pocket Color page](https://www.snk-corp.co.jp/us/games/ngpcs/index.html)
uses `NEOGEO POCKET COLOR`. `AES` remains an explicit archive hardware
qualifier when the source identifies that version.
Normalize only exact, unambiguous aliases in structural `game.console`, the
platform folder, and VGM English GD3 System. A label that combines NEOGEO with
another platform (for example, `B System / Neo Geo`) is composite and stays in
review unless set evidence resolves it. Preserve the original source labels in
the unchanged source archive and source metadata.

## Format Exceptions

VGM/VGZ supports many platforms. Apply the VGM profile's exact Sega GD3 alias
mapping; preserve other populated labels as read. Hold missing, mixed, or
ambiguous labels for review.
