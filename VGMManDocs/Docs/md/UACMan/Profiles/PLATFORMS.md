# Platforms

Set one canonical package-level value in structural `game.console`. Platform
names are identity, not a repeated per-track tag. Match only complete,
unambiguous source labels; do not infer a platform from a title, filename,
directory, chip list, or partial text match.

## Canonical Names

| Platform | Aliases |
| --- | --- |
| Nintendo NES | NES; Nintendo Entertainment System; Famicom; Family Computer |
| Nintendo SNES | SNES; Super NES; Super Nintendo; Super Nintendo Entertainment System; Super Famicom |
| Nintendo Game Boy | GB; Game Boy; Gameboy; Nintendo Game Boy |
| Nintendo Game Boy Color | GBC; Game Boy Color; Gameboy Color; Nintendo Game Boy Color |
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

Use the canonical name exactly as written. If a source does not establish one
approved platform, or a package combines platforms without one package-level
identity, hold it for review rather than inventing an alias.

## Format Exceptions

VGM/VGZ supports many platforms. Apply the VGM profile's exact Sega GD3 alias
mapping; preserve other populated labels as read. Hold missing, mixed, or
ambiguous labels for review.
