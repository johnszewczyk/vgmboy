# Canonical UAC System Names

UAC has one shared system identity: `game.console`. Store it once at package
scope. It is a structural UAC field, not an ordinary tag.

Do not also write the same system as a `System`, `Platform`, or `Console` tag,
or as `game.metadata.system`. This keeps every profile and consumer on one
field and one spelling.

## Approved names

| System | Canonical `game.console` | Source labels that identify the same system | Profiles |
| --- | --- | --- | --- |
| Nintendo Entertainment System | `Nintendo NES` | NES; Nintendo Entertainment System; Famicom; Family Computer | NSF / NSFE; VGM when the GD3 system names this system |
| Super Nintendo Entertainment System | `Nintendo SNES` | SNES; Super NES; Super Nintendo; Super Nintendo Entertainment System; Super Famicom | SPC; VGM when the GD3 system names this system |
| Nintendo Game Boy | `Nintendo Game Boy` | GB; Game Boy; Gameboy; Nintendo Game Boy | GBS; VGM when the GD3 system names this system |
| Sony PlayStation | `Sony PlayStation` | PlayStation; PlayStation 1; PS1; PSX; Sony PlayStation | PlayStation disc audio; VGM when the GD3 system names this system |

Use the canonical value exactly as written, including capitalization. Apply an
alias only when the complete source label clearly identifies one approved
system. Do not infer a system from a game title, filename, directory, chip
list, or partial text match. Preserve the source member unchanged.

If the source does not establish one approved system, or a package combines
systems without a single package-level identity, hold it for review. Do not
write `Unknown`, `Multi-system`, or an ad hoc alias into `game.console`, and do
not move the system into per-track `System` or `Platform` tags.

## Profile assignments

- SPC: `Nintendo SNES`.
- NSF and NSFE: `Nintendo NES`.
- GBS: `Nintendo Game Boy`.
- PlayStation CD-XA and Red Book audio: `Sony PlayStation`.
- VGM/VGZ: normalize the populated GD3 English/original system label using
  the approved aliases above. A system without an approved mapping requires
  review before packaging.
