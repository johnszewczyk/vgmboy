# ScanSong Improvement Evidence

## Contract and Package

- `swift build --package-path ScanSong --product ScanSongApp` passes with the
  default Swift build system (Xcode Swift 6.4, arm64 macOS 27 SDK).
- `swift test --package-path ScanSong --filter 'ignoredFileType|catalogBatchTallies|inspectorProcessRunner|sharedScheduler|checkpointProgress|multiRootScan|incrementalRescan|linkTesting'`
  passes all 11 selected tests. These cover saved empty preferences, batch
  tallies for empty/disabled/detached/missing/failed paths, cancellation permits,
  inspector limits, checkpoint progress, and incremental reuse.
- `python3 ScanSong/scripts/check-format-doc-consistency.py` passes for 16
  playback families and 45 scanner routes. `bash -n ScanSong/build-app.sh`
  passes.
- The default build's `ScanSongApp` and `scansong` products have distinct
  filesystem identities. Running `scansong plugins` returns 45 JSONL events
  with contract `scansong-jsonl`, version 1, and sequences 0 through 44.
  An unknown command returns a JSONL `session.fatal` diagnostic and exit 64.

## Package and Visible UI

- `ScanSong/build-app.sh` completes the release bundle, helper staging, and
  strict deep signature verification. dSYM generation requires execution
  outside the filesystem sandbox on this host.
- An isolated copy of the release bundle uses a separate verification bundle
  identifier and preferences. Its release executable initially matches the
  built bundle byte for byte; only its identity plist and signature differ.
- The release UI shows all six ignored-type checkboxes unchecked after saving
  an empty selection, quitting, and relaunching.
- A disposable schema-25 catalog at
  `/tmp/scansong-improvements-ui-a9ae26b/Library.sqlite` completes a 2,000-file
  synthetic WAV scan. After expanding that fixture to 20,000 files, Cancel Scan
  returns to enabled controls and visibly reports retained completed source
  checkpoints. The intermediate cancelling label is too brief to capture in
  the UI observation; the final cancelled state is verified.

## Limits

- The WAV inputs contain synthetic bytes and exercise scanner orchestration,
  UI progress, and cancellation; they establish no playback or native metadata
  fidelity.
- Batch tally correctness is tested. The change reduces tally statements from
  one per attached root to one; no elapsed-time speedup is claimed.
- The main collection catalog was opened read-only for startup observation;
  scan and preference mutations used the isolated verification app and catalog.
