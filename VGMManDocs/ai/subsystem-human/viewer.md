# Viewer

## Scope

VGMManDocs displays published Markdown stored in the app's `Docs/md/` tree.

## Navigation

The left sidebar groups files under their first path folder, such as
`ViewBoy/` or `UACMan/`. Nested folders appear as collapsible tree branches.
Selecting a Markdown file displays its formatted content in the main pane.
Groups and nested folders open and close with a 250 ms ease transition.

## Reading

The viewer uses a dark color scheme and renders headings, paragraphs, lists,
tables, quotes, links, images, and fenced code from the original Markdown.
Selecting an in-site Markdown link opens that document in the viewer.

## Editing

Choose **Edit Markdown** to open the editor drawer from the right. The drawer
contains the selected document's plain Markdown source and opens or closes with
a 205 ms ease transition. **Save** writes the source file. If another process
changes that file after it was opened, VGMManDocs reports a conflict and
requires reloading before another save can replace the current version.

## Live Updates

Changes made to Markdown files under `Docs/md/` update the document tree and
the selected page while the app is open. A dirty editor draft stays visible;
the app reports when its source has changed on disk.

## Files

- `Sources/VGMManDocs/Resources/index.html`
- `Sources/VGMManDocs/Resources/app.css`
- `Sources/VGMManDocs/Resources/app.js`
