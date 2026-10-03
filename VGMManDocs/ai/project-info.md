# Project Info

## Product

VGMManDocs is the VGMMan family's native macOS viewer and editor for published
project Markdown. AppKit hosts a local WKWebView; no remote web server is
required to browse the documentation. The repository's DocMan intake and
engineering notes remain in each owner's routed `ai/` locations.

## Major Components

- `Sources/VGMManDocs/` owns the AppKit window, WKWebView bridge, Markdown
  directory access, and recursive file watcher.
- `Sources/VGMManDocs/Resources/` owns the dark documentation site, drawer,
  tree navigation, and bundled Marked renderer.
- `Docs/md/<SubAppName>/` is the canonical source tree for published Markdown.

## Task Routing

- Viewer and editor behavior: [viewer.md](subsystem-human/viewer.md).
- Markdown storage, safe paths, save conflicts, and live refresh:
  [document-storage.md](subsystem-agent/document-storage.md).

## Local Rules

- Keep each published document under `Docs/md/<SubAppName>/`; the first folder
  names the VGMMan component that owns its content.
- Keep DocMan intake and engineering notes in their routed project locations.
- Do not add a nested Git repository. VGMMan owns commits for this package.
- Preserve Markdown source. The viewer renders source at runtime and editor
  saves write Markdown files back to the same tree.

## Human Docs

- `Docs/md/` is the published content rendered by the app.
- `ai/subsystem-human/` describes how VGMManDocs itself behaves.
