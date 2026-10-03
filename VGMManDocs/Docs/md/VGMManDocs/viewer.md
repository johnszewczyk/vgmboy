# VGMManDocs

VGMManDocs is a native macOS documentation reader and editor for this
repository's published Markdown.

## Content Location

Published source files live at `Docs/md/<SubAppName>/`. The first directory
identifies the owning VGMMan project. Nested folders are shown as nested tree
branches.

## Local Rendering

The app loads its shell from its packaged resources and reads Markdown from the
checked-out source tree. It renders content in WKWebView, so local documents do
not depend on Safari's certificate handling or a remote website.

## Editing and Refresh

The editor drawer shows the exact Markdown source. Saves are written back to
that file and are rejected if its contents changed since editing started. A
filesystem watcher refreshes the index and selected document after external
changes.
