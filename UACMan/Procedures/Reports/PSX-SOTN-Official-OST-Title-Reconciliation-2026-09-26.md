# SOTN PSX XA titles reconciled to the official soundtrack

Date: 2026-09-26

## Authority and method

The official English soundtrack track titles and order are the title authority for the 34 score streams in the Redump USA UAC. The title list is the 34-track MusicBrainz release used by the existing duration-candidate report: [Castlevania: Symphony of the Night](https://musicbrainz.org/release/c3c27d0f-73df-4aec-a6b4-cd332e063648).

JoshW's `!tags.m3u` identifies the PSX stream references and their game-facing labels. Those labels were used as crosswalk evidence, not retained as the canonical title when they differ from the official OST. The UAC contains 34 score XA streams after excluding the three movie streams and Konami logo stream. The one-to-one title reconciliation uses direct title matches and translations first, then the official track order and duration evidence to resolve remaining streams.

Duration matches are supporting evidence. They are not treated as standalone proof because loop-body duration can differ from the soundtrack recording. Two cases have especially useful runtime evidence: `XA_STR1-0437_3c03.xa` is 36.48 seconds and matches the 37-second *Metamorphosis 2*; `XA_STR1-0455_4603.xa` is 45.12 seconds and matches the 48-second *Metamorphosis 3*. JoshW's playlist points both Transformation 2 and 3 labels at the former stream, so the otherwise-unlabeled latter stream is assigned the missing third transformation by elimination.

## Crosswalk

| OST # | Official OST title | UAC stream | JoshW/game-facing title | Basis |
|---:|---|---|---|---|
| 1 | Metamorphosis 1 | `XA_STR1-0397_3203.xa` | Transformation No.1 | Title translation |
| 2 | Prologue | `XA_STR1-0079_1403.xa` | Prologue | Exact title |
| 3 | Dance of Illusions | `XA_STR1-0035_0a03.xa` | Dance of Illusions | Exact title |
| 4 | Moonlight Nocturne | `XA_STR1-0043_1e06[us].xa` | Symphony of the Night | 1:45.39 runtime; alternate title association |
| 5 | Prayer | `XA_STR1-0245_2804.xa` | Prayer | Exact title |
| 6 | Dracula's Castle | `XA_STR1-0134_1401.xa` | Dracula's Castle | Exact title |
| 7 | Dance of Gold | `XA_STR1-0056_1404.xa` | Golden Dance | Title translation |
| 8 | Marble Gallery | `XA_STR1-0075_0a01.xa` | Marble Gallery | Exact title |
| 9 | Tower of Mist | `XA_STR1-0002_0002.xa` | Tower of Evil Mist | Title variant |
| 10 | Nocturne | `XA_STR1-0015_1406.xa` | Nocturne | Exact title |
| 11 | Wood Carving Partita | `XA_STR1-0380_2800.xa` | Wood-Carved Partita | Title variant |
| 12 | Door of Holy Spirits | `XA_STR1-0070_0a02.xa` | Gate of Holy Spirits | Title variant |
| 13 | Festival of Servants | `XA_STR1-0003_0003.xa` | The Festival of Servants | Exact title variant |
| 14 | Land of Benediction | `XA_STR1-0010_0a06.xa` | Land of Benediction | Exact title |
| 15 | Requiem for the Gods | `XA_STR1-0081_1400.xa` | Requiem of the Gods | Title variant |
| 16 | Crystal Teardrop | `XA_STR1-0001_0001.xa` | Crystal Teardrops | Title variant |
| 17 | Abandoned Pit | `XA_STR1-0250_1e02.xa` | Abandoned Pit | Exact title |
| 18 | Rainbow Cemetery | `XA_STR1-0179_1e00.xa` | Rainbow's Cemetery | Title variant |
| 19 | Silence | `XA_STR1-0006_0006.xa` | Silence | Exact title |
| 20 | Lost Painting | `XA_STR1-0000_0000.xa` | The Lost Portrait | Translation variant |
| 21 | Dance of Pales | `XA_STR1-0101_1402.xa` | Waltz of the Pearls | Remaining title by elimination; weakest association |
| 22 | Curse Zone | `XA_STR1-0033_0a00.xa` | Cursed Sanctuary | Title association |
| 23 | Enchanted Banquet | `XA_STR1-0114_1e04.xa` | Demonic Banquet | Title association |
| 24 | Wandering Ghosts | `XA_STR1-0112_1e03.xa` | Wandering Ghosts | Exact title |
| 25 | The Tragic Prince | `XA_STR1-0232_1e01.xa` | The Tragic Prince | Exact title |
| 26 | Door to the Abyss | `XA_STR1-0257_2803.xa` | Gates of Hell | Title association; duration is consistent within 1.5 seconds |
| 27 | Heavenly Doorway | `XA_STR1-0422_2802.xa` | Gates of Heaven | Title association |
| 28 | Death Ballad | `XA_STR1-0317_3204.xa` | The Poetic Ballad of Death | Title variant |
| 29 | Blood Relations | `XA_STR1-0005_0005.xa` | Strange Bloodlines | Title association |
| 30 | Metamorphosis 2 | `XA_STR1-0437_3c03.xa` | Transformation No.2 / Transformation No.3 | JoshW shared reference; 36.48 seconds matches the OST's 37 seconds |
| 31 | Finale Toccata | `XA_STR1-0042_0a05.xa` | The Final Toccata | Title variant |
| 32 | Black Banquet | `XA_STR1-0249_1405.xa` | Black Banquet | Exact title |
| 33 | Metamorphosis 3 | `XA_STR1-0455_4603.xa` | No title in JoshW playlist | Remaining transformation stream; 45.12 seconds matches the OST's 48 seconds |
| 34 | I Am the Wind | `XA_STR1-0408_1e05.xa` | I am the Wind | Official capitalization |

## Applied metadata scope

For each of the 34 XA score members, `metadata.title` and the standard `TITLE` tag use the official OST title above. Existing source-facing titles remain documented in this report. The obsolete per-track `OST_TITLE_CANDIDATES` and `OST_TITLE_STATUS` fields are removed from all 38 XA members, including movie/logo cues that are outside the 34-track OST. The report carries the crosswalk and its evidence instead. Source streams, loop objects, other metadata, pack metadata, and the Redbook APE member are outside this title pass.

## Review note

The *Dance of Pales* ↔ `Waltz of the Pearls` assignment is the least directly supported row. It is the sole unmatched official OST title after the other 33 score streams are reconciled. Confirm this row during the next listening/tag review.
