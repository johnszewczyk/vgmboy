# Markdown Storage and Rendering

## Scope

This note defines the ownership and filesystem boundary for the Markdown
viewer, editor, and live updates.

## Ownership

- `Docs/md/<SubAppName>/` is the canonical source for published content.
- Swift owns directory enumeration, Markdown reads and writes, version checks,
  and filesystem notifications.
- The WKWebView owns presentation and sends named requests through one narrow
  message handler.
- The bundled Marked parser owns Markdown-to-HTML conversion. Keep its license
  beside the vendored source.

## Invariants

- Resolve every requested path beneath the canonical `Docs/md/` root; reject
  absolute paths, traversal, and symlinks that escape that root.
- Only `.md` files appear in the document tree or are accepted by the editor.
- Render raw HTML as literal text and allow only safe link schemes. Markdown
  documents are local content, not trusted executable HTML.
- Internal Markdown links stay in the viewer. External web/email links and
  repository-local file references are opened through their native handlers.
- Save by comparing the source content hash supplied when editing began with
  the current on-disk hash. A mismatch must not overwrite the newer content.
- Write accepted edits atomically to the original Markdown path.
- Watch the source tree recursively. Debounce filesystem event bursts before
  rebuilding the visible index.

## Failure Boundaries

- Missing or unreadable files return an explicit bridge error; they do not
  produce empty successful documents.
- A version mismatch is a conflict and leaves disk contents untouched.
- The directory watcher may report multiple events for one save; rendering
  refreshes must remain idempotent.

## Files

- `Sources/VGMManDocs/main.swift`
- `Sources/VGMManDocs/MarkdownDirectory.swift`
- `Sources/VGMManDocs/MarkdownDirectoryWatcher.swift`
- `Sources/VGMManDocs/Resources/marked.min.js`
- `Sources/VGMManDocs/Resources/markdown-renderer.js`
