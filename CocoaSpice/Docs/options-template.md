# Options

> CocoaSpice options interface model.
>
> This template preserves the active CocoaSpice page order, visible wording, control types, formatting, defaults, and dynamic-value positions. Text in quotation marks and code spans is UI copy. `{{...}}` marks a runtime value or implementation binding; it is not literal user-facing text.

## Navigation

**Navigation title:** `Options`

### Sidebar sections

| Section | Items | System image |
| --- | --- | --- |
| `CocoaSpice` | `Database` | `cylinder.split.1x2` |
| `CocoaSpice` | `Interface` | `paintbrush` |
| `CocoaSpice` | `Windows` | `macwindow.on.rectangle` |
| `VGMBoy` | `Audio` | `speaker.wave.2` |
| `VGMBoy` | `Diagnostics` | `waveform.path.ecg` |
| `VGMBoy` | `Playback` | `waveform` |

### Detail titles

| Owner | Page title |
| --- | --- |
| `CocoaSpice` | `CocoaSpice / Database` |
| `CocoaSpice` | `CocoaSpice / Interface` |
| `CocoaSpice` | `CocoaSpice / Windows` |
| `VGMBoy` | `VGMBoy / Audio` |
| `VGMBoy` | `VGMBoy / Diagnostics` |
| `VGMBoy` | `VGMBoy / Playback` |

## Shared visual and control format

- Detail pages are vertically stacked sections with `16` points of spacing.
- The detail scroll area has `20` points of padding.
- Page titles use `title3`, semibold, white text, with `20` points of horizontal padding, `18` points above, and `4` points below.
- Each card has a `headline` title in white, a divider immediately below the title, `14` points between its internal rows, `16` points of content padding, a `10`-point corner radius, and a dark fill equivalent to RGB `40 / 255` for each channel.
- Help/subtext uses an `11`-point system font in the secondary color. Primary labels use white or the platform default label color as defined by the page source.
- Checkboxes use the native checkbox style: `[ ]` unchecked, `[x]` checked.
- Duration fields use a dark translucent rounded rectangle, a one-point white translucent stroke, monospaced text, right alignment, and a width of `72` points.
- Timing fields use a numeric text field, a width of `58` points, and the suffix `ms`.
- Tempo fields use a rounded-border text field, a width of `72` points, and the placeholder `1`.
- Path bars use a monospaced `11`-point font, one line, middle truncation, selectable text, a folder icon button, and the accessibility label `Browse`.
- Menu pickers use the menu style with their labels hidden. Bordered action buttons use regular control size; equal-width action buttons share the available row width.

---

## `VGMBoy / Playback`

### Long Play

**Control:** [ ] `Enable extended playback`

> Set the target duration used when Long Play is enabled.

**Control:** `[text field: 3:00]`  
**Placeholder:** `0:00`  
**Format:** `m:ss`, monospaced, right-aligned, width `72`  
**Range:** minimum `0:30` (`30` seconds)

**Label:** `Unknown-length default`

> Used when a decoder provides no natural duration and Long Play is off.

**Control:** `[text field: 2:30]`  
**Placeholder:** `0:00`  
**Format:** `m:ss`, monospaced, right-aligned, width `72`  
**Range:** minimum `0:01` (`1` second)  
**Default:** `2:30` (`150` seconds)

### End Fade

**Control:** [x] `Enable Fade Out`

> Applies to metadata-timed playback and Long Play. Turning it off lets tracks use their native ending.

**Control:** `[text field: 0:06]`  
**Placeholder:** `0:06`  
**Format:** `m:ss`, monospaced, right-aligned, width `72`  
**Default:** `0:06` (`6` seconds)

**Control:** [ ] `Enable Faded Skip`

> Next and Previous fade the live track for the configured 6-second fade out before advancing. Press again to skip immediately.

### Play Speed

> Fractions and decimals are accepted and snap to 1/32 increments.

| Control | Detail | Value field | Default |
| --- | --- | --- | --- |
| [ ] `libgme` | `SPC, NSF/NSFE, GBS, HES, KSS, AY, and SAP` | `[text field: 1]` | `1×` |
| [ ] `libvgm` | `GYM, S98, VGM, VGZ, and DRO` | `[text field: 1]` | `1×` |

**Tempo field format:** placeholder `1`, rounded-border style, width `72`.  
**Accepted input:** fractions and decimals.  
**Quantization:** `1/32` increments.

---

## `VGMBoy / Diagnostics`

### Transport

| Label | Value |
| --- | --- |
| `Output` | `{{model.playbackDiagnostics.outputHealth.rawValue.capitalized}}` |
| `Underruns` | `{{model.playbackDiagnostics.underrunCount}}` |

### Buffer

| Label | Value |
| --- | --- |
| `Buffer` | `{{bufferedMilliseconds}} ms • {{bufferPercent}}%` |
| `Source Clips` | `{{clippedSampleCount}}` |

### Decoder

| Label | Value |
| --- | --- |
| `Decoder` | `{{decoderFamily}}`, or `—` |
| `Rates` | `{{decoderSampleRate}} / {{sampleRate}} Hz` |
| `Decoded / Audible` | `{{decodedFrames}} / {{audiblePositionFrames}} frames` |
| `Tempo` | `{{tempo formatted to 3 fractional places}}×` |

> Output detects when the source node stops receiving render requests while CocoaSpice thinks it is playing. It cannot detect a Bluetooth radio, codec, or speaker failure after Core Audio. Counters reset for each new track.

---

## `VGMBoy / Audio`

### Volume

> Applies to CocoaSpice playback only. Volume keys control macOS system volume.

**Control:** `[slider: 0–100%]`  
**Binding:** `0...1`, step `0.01`  
**Readout:** `{{rounded app volume × 100}}%`

### Mono

**Control:** [ ] `Enable Mono`

> Mix left and right channels, then play the same signal through both speakers.

### Equalizer

**Control:** [ ] `Enable Equalizer`

> Ten parametric bands apply to every playback format.

| Band | Control | Range | Step | Readout format |
| --- | --- | --- | --- | --- |
| `31` | `[slider]` | `-12...12 dB` | `0.5 dB` | `%+.1f` |
| `62` | `[slider]` | `-12...12 dB` | `0.5 dB` | `%+.1f` |
| `125` | `[slider]` | `-12...12 dB` | `0.5 dB` | `%+.1f` |
| `250` | `[slider]` | `-12...12 dB` | `0.5 dB` | `%+.1f` |
| `500` | `[slider]` | `-12...12 dB` | `0.5 dB` | `%+.1f` |
| `1k` | `[slider]` | `-12...12 dB` | `0.5 dB` | `%+.1f` |
| `2k` | `[slider]` | `-12...12 dB` | `0.5 dB` | `%+.1f` |
| `4k` | `[slider]` | `-12...12 dB` | `0.5 dB` | `%+.1f` |
| `8k` | `[slider]` | `-12...12 dB` | `0.5 dB` | `%+.1f` |
| `16k` | `[slider]` | `-12...12 dB` | `0.5 dB` | `%+.1f` |

**Button:** `Reset`

### AAC Export

**Label:** `Export Folder`

**Path bar:** `{{model.aacExportDirectoryPath}}`  
**Path format:** selectable, monospaced `11`-point text, middle truncation  
**Button:** folder icon, accessibility label `Browse`

> Playlist Export AAC writes a finite VGMBoy render here. New installs default to Downloads.

---

## `CocoaSpice / Interface`

### Interface Style

> Controls text in both the database sidebar and playlist.

**Picker label:** `Font Size`  
**Control:** `[menu: 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18]`  
**Default:** `12`

**Picker label:** `Font Color`  
**Control:** `[menu: Primary, Secondary, Tertiary]`  
**Default:** `Primary`

**Control:** [ ] `Monospace Font`

> Use system fixed-width font in Sidebar and Playlist.

**Button:** `Reset`  
**Reset values:** font size `12`, font color `Primary`, monospace font off.

### Playlist Options

**Control:** [x] `Enable Column Auto-size`

> Automatically resize columns for content width on selection.

**Default:** on.

### Animations

**Control:** [x] `Auto-Resize`

> Duration for automatic playlist column resizing.

**Control:** `[numeric text field: 200] ms`  
**Placeholder:** `200`  
**Range:** `0...1000` ms  
**Enabled when:** `Auto-Resize` is on  
**Default:** enabled, `200` ms

**Control:** [x] `Selection Bar`

> Duration for playlist and sidebar selection movement.

**Control:** `[numeric text field: 200] ms`  
**Placeholder:** `200`  
**Range:** `0...1000` ms  
**Enabled when:** `Selection Bar` is on  
**Default:** enabled, `200` ms

### Sidebar Options

**Control:** [ ] `Group by Console`

> Sort game list into consoles using metadata and parent folders in Database view.

**Control:** [ ] `Prefer Folders over Metadatas`

> Use the scanned archive or file's parent console folder before embedded console metadata when grouping games.

**Control:** [ ] `Hide File Extensions`

> Hide extensions in Files view without changing the scanned filename or playback path.

**Label:** `Files Disclosure Gap`

> Space between folder triangles and names in Files view, measured in points.

**Control:** `[numeric text field: 6]`  
**Placeholder:** `6`  
**Format:** rounded to whole points  
**Default:** `6` points

**Label:** `Files Child Indent`

> Extra indent for each Files-view child level, measured in points. Default 8 pt is roughly one character at the default font size.

**Control:** `[numeric text field: 8]`  
**Placeholder:** `8`  
**Format:** rounded to whole points  
**Default:** `8` points

### Library Behavior

**Control:** [ ] `Playlist Follows Cursor`

> Game-list selection replaces the playlist; Files view queues only on double-click or Return.

**Control:** [ ] `Double-Click Enqueues`

> Double-click only adds items to the playlist.

### Interface control formatting

- Checkboxes use the native checkbox appearance.
- Font-size values are presented in a menu and constrained to `6...18`.
- Font color values are presented in a menu as `Primary`, `Secondary`, and `Tertiary`.
- Animation fields are right-aligned numeric fields with the suffix `ms`.

---

## `CocoaSpice / Database`

### Local Files

**Control:** [ ] `Use Local Files`

> Browse one folder directly. The database library is disabled while this is on.

**Path bar:** `{{selected local folder path}}`  
**Empty state:** `No local folder selected`  
**Button:** folder icon, accessibility label `Browse`

**Default:** off.

### Favorites

**Label:** `Order`

> Historical preserves the order favorites were added. Alphabetical changes display only.

**Control:** `[menu: Historical, Alphabetical]`  
**Default:** `Historical`

### Database

**Path bar:** `{{model.configuredLibraryDatabasePath}}`  
**Button:** folder icon, accessibility label `Browse`

> CocoaSpice reads this schema-23 catalog. ScanSong owns scan paths, scanning, link checks, and cleanup.

**Buttons, in order:** `Use Default` · `Reload Library` · `Show in Finder`

**Disabled state:** this card is disabled and displayed at `0.55` opacity while `Use Local Files` is on.

### Cache

**Path bar:** `{{ZipArchiveSupport.cacheDirectoryURL.path}}`  
**Button:** folder icon, accessibility label `Browse`

**Control:** [x] `Enable Cache`

> Decompressed files can be retained to reduce load time.

> Usage: `{{model.archiveCacheSummaryText}}`

**Control:** `[menu: {{ArchiveCachePolicy.supportedLimits}}]`  
**Supported limits:** `2 GB`, `4 GB`, `8 GB`, `16 GB`  
**Default:** enabled, `2 GB`  
**Enabled when:** `Enable Cache` is on

**Buttons, in order:** `Use Default` · `Clear Cache` · `Show in Finder`

**Clear state:** `Clear Cache` is disabled while clearing.

---

## `CocoaSpice / Windows`

### Always on Top

**Control:** [ ] `Main Window`

> Keep main window on top of other apps.

**Control:** [ ] `Options Window`

> Keep options window on top of main window.

### Window Layout

> Restore the default size and centered position for CocoaSpice windows.

**Button:** `Reset`

---

## Markdown control legend

| Markdown model | Native interface equivalent |
| --- | --- |
| `[ ] Label` | Unchecked checkbox toggle |
| `[x] Label` | Checked checkbox toggle |
| `[text field: value]` | Text input with current/default value |
| `[numeric text field: value]` | Numeric text input |
| `[menu: values]` | Picker/menu |
| `[slider: value]` | Slider with a live readout |
| `{{value}}` | Runtime value or source binding, not literal UI copy |
| `**Button:** \`Label\`` | Button with exact visible title |
| `> text` | Help/subtext shown below a control or card heading |
