# UACMan instructions

Read `project-info.md`, then `ai/AGENTS.md`, then `ai/project-info.md`, and
follow the specific human or agent subsystem route for the task.

Keep UACMan a package browser/editor, not a player or native-format parser.
Use FrontendCore for UAC binary parsing and payload-preserving rewrites. Never
rebuild, decompress, retag, or recompress payload members for a manifest edit.
