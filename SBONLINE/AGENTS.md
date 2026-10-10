# SBONLINE instructions

In the `Code/` workspace, start with [DocMan](../../DocMan/AGENTS.md) and its
`project-info.md`, then read the VGMMan family route at
[`../AGENTS.md`](../AGENTS.md) and [`../project-info.md`](../project-info.md).
Continue with `ai/AGENTS.md`, `ai/project-info.md`, and the focused SBONLINE
note for the task.

SBONLINE is the hosted SPCBOY web-player project. Keep it separate from SB2's
macOS app and bundle identity. The current standalone mobile concept lives in
`prototypes/mobile/`; it uses sample data and is not connected to playback.
The production pages, player assets, server adapter, account/social features,
and deployment currently live in the MathBook `private-admin/` app. Follow the
integration boundary in `ai/subsystem-agent/integration-boundaries.md` before
editing those files.

VGMMan is the only Git repository for family work. Do not initialize a nested
repository here.
