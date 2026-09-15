# UACMan instructions

Read `ai/project-info.md`, then `ai/AGENTS.md`, then the routed subsystem
note. There is no root-level `project-info.md` in this component.

UACMan owns three distinct boundaries: the metadata application, the current
reversible archive wrapper, and a reserved future native-container component.
Keep native tag reading in MetaMan and playback in VGMBoy/CocoaSpice. Wrapper
manifest edits must preserve payload members byte-for-byte; do not rebuild,
decompress, retag, or recompress them to change metadata.
