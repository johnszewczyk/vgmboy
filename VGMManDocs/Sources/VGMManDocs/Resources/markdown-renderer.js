/* Raw HTML is displayed as text. Markdown links are normalized before they
   reach WKWebView so document links stay inside the local reader. */
(function () {
  function escapeAttribute(value) {
    return String(value).replaceAll("&", "&amp;").replaceAll('"', "&quot;").replaceAll("<", "&lt;");
  }

  function escapeHTML(value) {
    return String(value).replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
  }

  function plainText(html) {
    const node = document.createElement("div");
    node.innerHTML = html;
    return (node.textContent || "").trim();
  }

  let current = { documentFileURL: "", markdownRootURL: "", projectRootURL: "" };
  const renderer = new marked.Renderer();
  const renderTable = renderer.table;
  renderer.table = function (token) {
    return `<div class="table-scroll" role="region" tabindex="0" aria-label="Scrollable table">\n${renderTable.call(this, token)}</div>\n`;
  };
  renderer.html = ({ text }) => `<pre class="raw-html"><code>${escapeHTML(text)}</code></pre>\n`;
  renderer.heading = (token) => {
    const inner = marked.parseInline(token.text);
    const label = plainText(inner).toLowerCase().replace(/[^\p{L}\p{N}]+/gu, "-").replace(/^-|-$/g, "") || "section";
    const count = headingCount.get(label) || 0;
    const id = count === 0 ? label : `${label}-${count}`;
    headingCount.set(label, count + 1);
    return `<h${token.depth} id="${id}">${inner}</h${token.depth}>\n`;
  };
  renderer.link = ({ href, title, text }) => {
    const label = text ?? "";
    const safeTitle = title ? ` title="${escapeAttribute(title)}"` : "";
    if (!href) return `<span>${label}</span>`;
    if (href.startsWith("#")) {
      return `<a href="${escapeAttribute(href)}" data-anchor="${escapeAttribute(href.slice(1))}"${safeTitle}>${label}</a>`;
    }
    if (/^(https?:|mailto:)/i.test(href)) {
      return `<a href="${escapeAttribute(href)}" data-external-link="${escapeAttribute(href)}"${safeTitle}>${label}</a>`;
    }
    if (/^[a-z][a-z0-9+.-]*:/i.test(href) || href.startsWith("//")) {
      return `<span>${label}</span>`;
    }
    try {
      const target = new URL(href, current.documentFileURL);
      const root = new URL(current.markdownRootURL);
      if (target.protocol === "file:" && target.pathname.startsWith(root.pathname) && /\.md$/i.test(target.pathname)) {
        const relative = decodeURIComponent(target.pathname.slice(root.pathname.length));
        return `<a href="#" data-document-link="${escapeAttribute(relative)}" data-anchor="${escapeAttribute(target.hash.slice(1))}"${safeTitle}>${label}</a>`;
      }
      const projectRoot = new URL(current.projectRootURL);
      if (target.protocol === "file:" && target.pathname.startsWith(projectRoot.pathname)) {
        return `<a href="${escapeAttribute(target.href)}" data-local-link="true"${safeTitle}>${label}</a>`;
      }
    } catch (_) {}
    return `<span>${label}</span>`;
  };
  renderer.image = ({ href, title, text }) => {
    if (!href || /^(?:[a-z][a-z0-9+.-]*:|\/\/)/i.test(href)) return "";
    try {
      const target = new URL(href, current.documentFileURL);
      const root = new URL(current.projectRootURL);
      if (target.protocol !== "file:" || !target.pathname.startsWith(root.pathname)) return "";
      const titleAttribute = title ? ` title="${escapeAttribute(title)}"` : "";
      return `<img src="${escapeAttribute(target.href)}" alt="${escapeAttribute(text || "")}"${titleAttribute} loading="lazy">`;
    } catch (_) { return ""; }
  };
  const parser = new marked.Marked({ gfm: true, breaks: false, renderer });
  let headingCount = new Map();

  globalThis.vgmManDocsRenderMarkdown = (markdown, context) => {
    current = context || current;
    headingCount = new Map();
    return parser.parse(String(markdown));
  };
})();
