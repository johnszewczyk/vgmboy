# ScanSong

ScanSong is the VGMMan family’s source inspector and schema-24 catalog writer.
It has a reusable `ScanSongKit`, a JSONL CLI (`scansong`), and a native macOS
catalog-management app. Player apps read the published catalog; they do not
scan or modify it.

ScanSong discovers loose sources and supported archives, resumes complete
source/archive checkpoints, and publishes each refreshed source atomically. A
failed refresh retains the last known-good catalog rows. UAC scans trust the
bounded package manifest and do not expand or inspect the enclosed audio/TAR
payload.

## Build and run

```sh
./build-app.sh
./launch.sh
swift test --disable-sandbox
swift run scansong plugins
swift run scansong probe --recursive --strict /path/to/folder
```

`launch.sh` builds a fresh release app before opening it. The app can select an
existing schema-24 catalog or create a new one, attach scan roots, scan or resume
roots, inspect per-path logs, and check or clean links. **Clean Links** removes
inactive catalog records only after confirmation; it never deletes source
files. A normal scan reuses completed matching work; Deep Scan forces
reinspection.

The native window keeps catalog and path work off its UI actor. Scan Status
shows the current phase and elapsed time; its source meter is determinate only
when the scan has a meaningful total. Archive, publication, and cleanup phases
keep an activity indicator and current detail visible. UI progress sampling
does not pace the worker.

The writer upgrades a schema-23 catalog to 24 by adding the optional
`tracks.track_number` column. Player readers require schema 24; other legacy
and unrelated databases are rejected.

The `scansong` CLI writes versioned JSONL events to stdout; errors and required
unsupported adapters return a nonzero status. `probe` is dry-run and `scan`
writes only the catalog path supplied to it.

## Ownership and routes

MetaMan owns direct format metadata readers. ScanSong adapts their ordered
results into schema 24, owns scanner-specific archive/source handling, and
bundles VGMBoy-built inspection helpers only where required. It does not invoke
player apps or link the playback kit.

Read [AGENTS.md](AGENTS.md), then [`ai/project-info.md`](ai/project-info.md).
The focused inspection, archive, and failure contracts are in
[`ai/subsystem-agent/format-accommodations.md`](ai/subsystem-agent/format-accommodations.md);
the native operation boundary is in
[`ai/subsystem-agent/operation-presentation.md`](ai/subsystem-agent/operation-presentation.md);
user-visible app behavior is in `ai/subsystem-human/`. The authoritative
plugin/dependency matrix is
[`../VGMBoy/Docs/plugin-catalog.md`](../VGMBoy/Docs/plugin-catalog.md), and the
native metadata reader map is [`../MetaMan/FORMAT-LAYOUTS.md`](../MetaMan/FORMAT-LAYOUTS.md).
