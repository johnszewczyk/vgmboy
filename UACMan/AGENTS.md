# UACMan instructions

Read `ai/AGENTS.md`, then `ai/project-info.md`, then the routed subsystem
note. There is no root-level `project-info.md` in this component.

UACMan owns two supported boundaries: the metadata application and the current
reversible archive wrapper. `Container/README.md` records the closed SPC
successor decision; there is no supported native-container component. Keep
native tag reading in MetaMan and playback in VGMBoy/CocoaSpice. Wrapper
manifest edits must preserve payload members byte-for-byte; do not rebuild,
decompress, retag, or recompress them to change metadata.
