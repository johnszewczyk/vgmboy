# SBONLINE instructions

In the `Code/` workspace, start with [DocMan](../../DocMan/AGENTS.md) and its
`project-info.md`, then read the VGMMan family route at
[`../AGENTS.md`](../AGENTS.md) and [`../project-info.md`](../project-info.md).
Continue with `ai/AGENTS.md`, `ai/project-info.md`, and the focused SBONLINE
note for the task.

SBONLINE is the hosted SPCBOY web-player project. Keep it separate from SB2's
macOS app and bundle identity. Its production Django app, player assets,
account/social features, stream adapter, and release source live under
`server/` and `ops/server/` in this project. `prototypes/mobile/` remains a
sample-only design fixture; production mobile UI belongs in `server/`.
Follow `ai/subsystem-agent/integration-boundaries.md` before changing server or
release behavior.

VGMMan is the only Git repository for family work. Do not initialize a nested
repository here. Deployment uploads a VGMMan-built release to the existing
webspace; do not make the rented host's previous app checkout a source of truth
or retain old app files as a rollback copy.
