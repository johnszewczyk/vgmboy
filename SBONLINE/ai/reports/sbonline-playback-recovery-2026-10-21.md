# SBONLINE playback recovery

## Findings and changes

The inspected live tab had reached the existing 60-minute page playback limit.
All transport controls were disabled; the status asked for a reload but offered
no action. Fresh-page playback worked for Stage 1 (1941) and Opening Demo
(Cyberbots), reaching 6.9 and 8.6 seconds respectively without media errors.
This identifies the inspected tab's failure; it does not prove that every
reported failure had the same cause.

- Expiry now exposes Reload player in the status bar and repurposes the Play
  control as a reload action. The server-enforced session limit remains intact.
- Play retries recreate failed media resources. Replaying an ended resource
  reloads it from the beginning.
- EQ context resume and media Play are requested together, preserving the click
  gesture instead of waiting for WebKit's resume promise first.
- Normal track-switch AbortErrors and obsolete source errors cannot overwrite
  the new track status. Unexpected early EOF keeps the track with a retry message;
  normal EOF compares the absolute position, including any stream offset.

## Verification

- Seven Node regression checks passed with `node --test
  private-admin/tests/site-player.test.cjs`. JavaScript syntax, Django system
  check, and whitespace checks passed.
- A disposable local HTTP fixture returned 503 for the first media request and
  a valid WAV for the next request. Clicking Play retried the resource and
  reached 15.1 seconds, readyState 4, with no media error.
- The local expiry fixture shortened only its served JavaScript deadline. Both
  reload controls appeared, the transport action remained enabled, and clicking
  the status action returned the page to Ready with the recovery action hidden.
- Production deployment completed successfully, with the existing HSTS preload
  warning only. Cyberbots Opening Demo reached 30.72 seconds with EQ and finite
  Long Play enabled (`longPlay=180`), readyState 4, no media error, and the
  expected 3:00 clock. Pause and resume immediately returned Paused and Playing.

Code checkpoint: `5af9827`.

## Deployment recovery

The initial release exposed an infrastructure issue: setup deleted the CMake
build directory on every release, including UI changes. During a full emulator
rebuild the 512 MiB host had only 16 MiB available, no swap, and later load 7.87;
SSH and HTTPS became intermittently unresponsive. A provider reboot did not
restore access; a subsequent power cycle restored the host. The updated setup preserves the build cache and executable
permissions, and provisions a 512 MiB root-only swap reserve on hosts below
1 GiB RAM. The droplet plan is unchanged. This reduces the earlier GBA capacity
estimate's free-space headroom by 536,870,912 bytes.

A disposable rsync/chmod fixture verified that updated source replaces old
source, stale source is deleted, and the cached decoder remains executable.
Shell syntax checks passed.

The resumed release completed. The service is active, the decoder is executable,
and swap is active with 30.5 MiB used at the final check. Available disk measured
2,620,579,840 bytes (2.62 GB), still sufficient for the previously measured
494,670,440-byte compressed GBA set. No paid host resize was performed. These
capacity figures do not enable GSF decoding.

Infrastructure checkpoint: `3bc8cfe`.

## SFII Guile I native-loop investigation

The reported track is Arcade (Capcom), Street Fighter II: The World Warrior,
U.S.A. (Guile) I. The hosted catalog maps it to `10 U.S.A. (Guile) I.vgm`.
Its recorded end is sample 3,131,958 (71.019456 seconds), with an intro of
245,316 samples (5.562721 seconds) and a loop of 2,886,642 samples
(65.456735 seconds). A temporary event-instrumented bridge rendered 180 seconds
and reported native loop events at samples 3,131,958 and 6,018,600, with no END
event. The source's native loop is present and followed by libvgm.

The Safari access log showed ten completed requests for that exact track and
playback ID between 15:27:03 and 15:33:27, all with `longPlay=540` and no source
offset, with differently sized responses. These are repeated fresh HTTP streams,
not native VGM loop events. Request Range headers were not in that access log,
so the precise Safari reason for re-requesting remains unconfirmed. A local
Safari probe demonstrated an initial `Range: bytes=0-1` request followed by a
non-range request. The native Safari check was interrupted by concurrent user
activity; it is not evidence of a complete successful loop test.

Release `42deb2c` changes delivery from unindexed ADTS to AAC in timestamped
fragmented MP4, emits one-second fragments on the same encoder, and explicitly
advertises `Accept-Ranges: none` for generated audio. No per-track encoded files
are stored. This addresses the transport/timeline hypothesis without changing
the source loop. It also prevents the VGM wrapper from reopening a looped source
if that decoder unexpectedly terminates; such termination is now an error.
Sources without a native loop retain the existing whole-file-repeat fallback.

`streaming/tests/check_native_loop.py` uses a synthetic VGM with distinct intro
and loop pitches. It verified multiple seams without intro replay, absolute
offset playback, exact PCM frame counts, and continuous fragmented-MP4 packet
timestamps. The decoder built, Django check passed, and all seven browser-player
regression checks passed.

Technical reference: [WebKit's media streaming and fragmented MP4 model](https://docs.webkit.org/Deep%20Dive/Modules/MediaSourceExtensions.html).
This release uses a direct media URL, not a MediaSource/Web Audio replacement.

Post-release, the live in-app browser played Guile I with 3:00 Long Play at 2x.
At 123.32 seconds it was still Playing, readyState 4, with no media error. It
subsequently completed the full duration and advanced to Guile II. The server
recorded exactly one completed Chrome Guile I request for that run (2,948,743
bytes, HTTP 200), confirming it did not reconnect from the beginning at the
loop seams. This is Chromium playback verification, not a completed audible
Safari reproduction. Original speed and Long Play preferences were restored.

## Volume continuity

A second confirmed interruption path was the volume input listener: every
adjustment scheduled `restartCurrentStream`, discarding the audio buffer and
reconstructing decoder position. Release `ca831f1` uses the existing Web Audio
output gain for volume, multiplies it by EQ headroom, and smooths transitions
over 35 ms. Supported browsers now request full-level encoded audio and preserve
the source URL and decoder on volume adjustments. Browsers without a working
audio graph retain the previous server-volume fallback.

Nine Node checks passed, including combined volume/EQ headroom and a check that
volume updates do not schedule a stream restart. Native loop/packet-timestamp,
JavaScript syntax, Django, and whitespace checks also passed.

The volume release completed through the normal deployment command. The live
player loaded `site-player.js?v=20261021-seamless-1`, played Guile I, changed
volume from 100% to 15%, and retained the exact media source URL. Playback time
continued from 7.66 to 23.88 seconds, readyState stayed 4, status stayed Playing,
and no media error was reported. Volume was restored to 100%, speed to 1/1,
Long Play to Off, and playback stopped. Screenshot:
`/tmp/sbonline-guile-stream-fixed.png`.

The existing Safari tab needs a full reload to use the new client-side volume
logic. A Safari listen across Guile I's loop is still needed to confirm the
reported browser-specific symptom is resolved; the completed live loop test
above was in Chromium. Both deployments completed with only the existing HSTS
preload warning.

## Safari direct-stream and document recovery correction

A fresh native Safari reload reproduced failure on Giga Wing / Title Theme
with the fragmented MP4 response. HTTP 200 alone did not prove browser decoding.
Delivery now uses one continuous 128 kbps MP3 encoder, with no Xing seek index;
native source-loop decoding is unchanged. Safari started that same track and
reached 23 seconds. Reload restored the displayed position at 25 seconds and
retained the queue. User navigation then ended that Safari observation.

The player now saves metadata-only playback state in account/tab sessionStorage
for 24 hours (500 queued/history entries maximum), then constructs a fresh media
URL and playback ID using the new document token after reload/login. No signed
URL or private source path is persisted. Browser autoplay denial offers Play at
the saved position. The client hour limit uses initialization wall-clock time;
server token expiry and monthly quotas remain enforced. Authentication failures
offer Sign in, preserving the account-scoped saved state through the redirect.
Media errors no longer leave the transport mislabeled Pause.

Eleven Node checks pass, including paused/playing restoration with new
credentials, bounded metadata, and queue/position preservation. A live Chromium
run restored Guile I at 37 seconds after reload; the browser required a Play
gesture to resume. A real sign-out/passkey-sign-in cycle was not performed.

## 2026-10-22 AAC and Demitri checkpoint

AAC now uses MediaSource/ManagedMediaSource rather than a direct growing MP4
URL. It retains one encoder across loops, bounds append chunks to 64 KiB and
applies buffer backpressure/eviction. MP3 fallback remains available. Owner
profile exposes codec/AAC bitrate, plus a separate AAC trial link. Site preference
remains MP3 pending the post-fix cross-browser check.

Native Safari played Darkstalkers / DEMITRI Stage (Romania) to 6:27 with 9-minute
Long Play, beyond the reported 3:35 failure. Screenshot:
`/tmp/sbonline-aac-demitri-safari.png`. The initial Chromium AAC trial ended early
at 136.32 seconds of 180. Standalone decoder output was exactly 180 seconds
(exit 0), and standalone fragmented-MP4 duration was 180.023 seconds (encoder
exit 0). Recent server requests show repeated fresh MP3 requests without offsets;
no service restart occurred around the morning failures.

The accounting code could falsely return zero after eight compare/update races
between same-account streams. The common path now uses one atomic conditional
increment; the partial final-quota chunk retains the guarded path. This fixes a
confirmed failure path but has not yet conclusively tied that race to the observed
Chromium EOF. Six Django checks and eleven existing JS checks pass. Latest
release also bounds coalesced network appends; a complete post-fix Chromium
Long Play run and AAC promotion remain pending. User requests pausing at 1%
remaining in either usage window; latest check showed weekly 2%, five-hour 80%.
