# CocoaSpice / SPCBoyWK Parity

## Rule

Equivalent features use the same shared policy and VGMBoy command contract.
AppKit and WebKit may render or adapt that contract differently; neither
frontend may recreate its behavioral implementation.

## Current evidence

| Level | Current result | Not yet proven |
| --- | --- | --- |
| Contract | FrontendCore: 102 tests. SPCBoyWK renderer/transport: 64 tests, including typed start, timing/tempo, audio, seek/ramp, queue, and fade contracts. | Real UI behavior. |
| Package | CocoaSpice: 58 tests; six opt-in archive fixtures skip without their configured paths. SPCBoyWK release package and bundled renderer pass its 64 tests. VGMBoy runs 79 tests but reports four issues in two audio-dependent tests; see `verification.md`. | RE2/AAC, Toki, Doom, Amiga, and real UAC SPC archive fixtures; explanation for the VGMBoy audio-test failures. |
| Packaged UI | SPCBoyWK launches and loads the Cosmo Gangs catalog with twelve archive VGM rows in shared natural order. | Repeatable row/toolbar automation. |
| Live fixture | Native Playback → Next starts an archive-backed VGM and the visible clock advances. | Seek, fade interruption, natural end, repeat, and non-VGM fixtures. |

Local certificate trust may report `CSSMERR_TP_NOT_TRUSTED` even when the
locally packaged app launches. Treat that as a signing-environment condition,
not parity evidence.

## Shared-boundary matrix

| Behavior | Shared owner | Frontend responsibility |
| --- | --- | --- |
| Catalog and playlist projection | CatalogReader | Render rows and explicit user sorting. |
| Archive preparation | FrontendCore | Request playback through the typed bridge. |
| Timing, decoder session, output | VGMBoy | Render status and issue named commands. |
| Queue, transitions, fade eligibility | FrontendCore | Present queue state and local animation only. |
| Preferences and playlist layout policy | FrontendCore | Persist/adapt local settings and render controls; consume the shared header-minimum padding contract. |
| Selection | Shared playlist identity | Render one local selection indicator; clear it on playlist replacement. |

## Current verification priorities

1. Reproduce and explain the two current VGMBoy audio-test failures.
2. Add the missing real archive fixtures.
3. Exercise seek, fade interruption, natural completion, repeat, and non-VGM
   playback in the packaged app.
4. Improve WebKit accessibility automation without changing playlist behavior.

Use `verification.md` for how to run and classify verification. This document
contains only the current state; Git retains prior investigations and run data.
