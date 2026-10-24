# AGENTS

Read this file, then `ai/AGENTS.md`, then `ai/project-info.md`, then the narrow
agent subsystem note routed by the task.

FrontendCore contains UI-neutral policy and services. Keep catalog writing in
ScanSong, playback/export archive preparation, decoding, and audio in VGMBoy,
and presentation in the consuming app. FrontendCore retains durable archive
cache policy and cache-backed browsing/artwork adapters.

