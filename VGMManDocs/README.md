# VGMManDocs

VGMManDocs is the family's native macOS documentation viewer. It presents
Markdown from `Docs/md/<SubAppName>/` in a dark WKWebView interface, watches
that tree for file changes, and provides an in-app Markdown editor.

Build and open it with `./launch.sh`. The LaunchPad entry builds the packaged
app with `./build.sh` and opens `.build/VGMManDocs.app`.

Start with [`AGENTS.md`](AGENTS.md), [`ai/project-info.md`](ai/project-info.md),
and the routed notes under `ai/`. Published Markdown is indexed from `Docs/md/`.
