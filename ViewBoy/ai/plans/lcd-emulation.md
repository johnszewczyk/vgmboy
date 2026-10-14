# LCD Emulation Plan

## Product Goal

Keep a convincing reflective dot matrix while giving the user useful control
over pixel strength. Readability controls operate within the display model;
they do not silently disable the matrix or replace bitmap text with DOM text.
ViewBoy remains a responsive music interface, with its existing native catalog
and playback boundaries.

## First Pass

Implemented: a separate spatial LCD model; a four-tone tinted LCD method;
polarity-aware grayscale mapping; Contrast Boost; a component-derived fractional
aperture; optional classic gutters; cached device-cell colors; and responsive
Display cards. The old 3x mask admitted only four ink pixels out of nine. The
component reference admits about 82.26% of the area at every supported dot size,
avoiding the coarse scaling artifact while retaining visible matrix edges.

Direct, 8, and 16 methods remain available. Their matrix setting and dot pitch
stay independent of the output mode. Existing explicitly saved matrix-off
preferences are retained; new installations enable the component aperture.

## Primary Source Register

| Source | Established fact | Modeling use and boundary |
| --- | --- | --- |
| [Nintendo Game Boy specifications](https://www.nintendo.com/en-gb/Hardware/Nintendo-History/Game-Boy/Game-Boy-627031.html) | STN matrix, 160x144, four shades | Supports a four-state display model. ViewBoy's responsive grid remains distinct from the physical resolution. |
| [Nintendo US5184830A](https://patents.google.com/patent/US5184830A/en), Fig.4 and LCD description | Common/segment driver chain, intersecting electrodes, separate intensity control and buffer; examples LH5076F/LH5077F | Contrast control belongs in the drive/optical path rather than in layout. The patent supplies architecture, not measured optical response or an exact production bill of materials. |
| [Nintendo US4398804A](https://patents.google.com/patent/US4398804A/en), Fig.2 and description | Reflective TN cell, crossed polarizers, electrodes, reflector; energized regions block light | Guides separation of substrate/illumination and electrode state. This earlier TN patent is not a DMG STN calibration. Spacer/Newton-ring construction does not justify inventing a screen-texture effect. |
| [Displaytech 128128A v1.1](https://docs.rs-online.com/6412/0900766b806dda0d.pdf), p2 | Dot 0.39x0.39 mm, pitch 0.43x0.43 mm; 1/64 duty, 1/9 bias | Aperture side/pitch ratio is used in code. Resolution, bias and duty are component-specific and must not be assigned to the Game Boy. |
| Same datasheet, p9 optical table and diagrams, visually inspected | At Vop=13.8 V, Ta=25 C: normal-temperature Tr=331 ms, Tf=91 ms; wide-temperature variant Tr=167 ms, Tf=66 ms. Yellow/green contrast ratio 14 | Future optional component response profile. These are rise/fall measurements with the document's waveform definitions, not instantaneous delay, assumed time constants, or DMG values. |

No complete original Game Boy panel electro-optical specification or usable
Sharp LH5076F/LH5077F datasheet was obtained. Public high-level Nintendo specs
and the patent are sufficient for architecture, not physical calibration.
Component fallback values retain their source and measurement conditions.

## Next Stages

1. **Temporal cell response.** Add an optional component profile with separate
   rise/fall envelopes and a perceptual instant mode. Retarget transitions from
   the currently visible cell state, advance by elapsed time rather than frame
   count, and retain the common FPS cap. Resolve waveform/time-constant mapping
   against the datasheet definition before fitting an exponential. Keep stable
   screens asleep; bound dirty regions and prove partial/full update parity.
2. **Drive and contrast transfer.** Add a normalized selected/unselected RMS
   drive model with a documented optical transfer curve. Keep real contrast
   voltage, supply voltage, bias and duty absent until sourced. The user-facing
   Contrast Boost remains an explicit readability adjustment and does not claim
   to emulate a voltage knob numerically.
3. **Reflector and polarizer layers.** Add bounded illumination and viewing-angle
   controls after validating the selected profile. Preserve opaque framebuffer
   output; illumination does not secretly dilute only the text. Do not introduce
   crosstalk, shadow displacement or aging coefficients as measured DMG facts.
4. **Hardware calibration.** Obtain a traceable original-panel specification or
   measure a known unit under fixed light, angle, temperature and voltage.
   Record aperture, reflectance levels, temporal response, and unit variation.
   Compare stationary text, scrolling rows, selections and both polarities.

## Acceptance Boundaries

- Black ink on a light substrate is readable with the matrix on. Inverse ink
  also works; every semantic tone moves in the chosen polarity.
- Switching methods, boost or optical profiles preserves pixel pitch, frame
  layout, hit targets, and matrix preference.
- Device scales 2 through 6 retain the selected physical aperture ratio.
- Compare the packaged app at the user's real window size, not only a large
  browser preview. Verify settings persistence after relaunch.
- Calibration claims require a named source or measured fixture; passing a
  renderer test proves the implementation, not original-hardware fidelity.
