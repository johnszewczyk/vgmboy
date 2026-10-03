# Closed native SPC investigation

Status: closed by design decision. The project will not convert existing SPCs
into a derived event stream or require per-game emulator capture. No improvement
to provenance, playback fidelity, or preservation follows from that conversion
when the existing SPC member is the only source artifact.

The supported path is the reversible UAC wrapper: retain the original SPC bytes,
harvest its metadata through MetaMan, and keep metadata independently readable
in the UAC manifest. The earlier true-stream prototype and beta proposal were
closed and removed from the maintained package. No native SPC conversion or
playback implementation is supported.

The UAC wrapper also supports MetaMan's common projection for VGM and VGZ,
including GD3 metadata for Sega Mega Drive/Genesis logs. For NSF, NSFE, and
GBS, the wrapper records each MetaMan track as an ordered subsong entry that
points into the unchanged original member. The wrapper retains original member
bytes for every format.

No custom SPC compression scheme is approved. Solid compression already offers
cross-file dictionary reuse; the earlier eight-fixture measurements are
historical and do not establish a set-wide size claim. They do not justify a
custom transform or change the reversible-wrapper decision.
