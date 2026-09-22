#!/usr/bin/env node

// Check current project documentation without depending on a rendered site or
// scanning vendored, archived, or historical material.
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const root = path.resolve(process.argv[2] || path.resolve(__dirname, ".."));
const files = execFileSync("git", ["ls-files", "--cached", "--others", "--exclude-standard", "-z", "--", "*.md"], {
  cwd: root,
  encoding: "utf8",
}).split("\0").filter(Boolean).filter((file) =>
  !file.startsWith("SPCBoy/") &&
  !file.startsWith("LocalRecovery/") &&
  !file.includes("/vendor/") &&
  !file.includes("/Docs/archive/")
);

let checked = 0;
let workspaceLinks = 0;
const broken = [];
for (const file of files) {
  const markdown = fs.readFileSync(path.join(root, file), "utf8");
  const links = markdown.matchAll(/\]\((?:<([^>]+)>|([^\s)]+))(?:\s+"[^"]*")?\)/g);
  for (const match of links) {
    const target = match[1] || match[2];
    if (/^(?:[a-z][a-z0-9+.-]*:|#)/i.test(target)) continue;
    const pathname = target.split("#", 1)[0];
    if (!pathname) continue;
    let decoded;
    try {
      decoded = decodeURIComponent(pathname);
    } catch {
      decoded = pathname;
    }
    const resolved = path.resolve(root, path.dirname(file), decoded);
    const line = markdown.slice(0, match.index).split("\n").length;
    if (path.isAbsolute(decoded)) {
      broken.push(`${file}:${line}: ${target}`);
      continue;
    }
    if (resolved !== root && !resolved.startsWith(`${root}${path.sep}`)) {
      if (decoded.startsWith("../DocMan/")) {
        workspaceLinks += 1;
        if (fs.existsSync(path.resolve(root, "../DocMan")) && !fs.existsSync(resolved)) {
          broken.push(`${file}:${line}: ${target}`);
        }
      } else {
        broken.push(`${file}:${line}: ${target}`);
      }
      continue;
    }
    checked += 1;
    if (!fs.existsSync(resolved)) {
      broken.push(`${file}:${line}: ${target}`);
    }
  }
}

for (const item of broken) console.error(item);
console.log(`Checked ${checked} repository links in ${files.length} current Markdown files; ${broken.length} invalid; ${workspaceLinks} optional workspace links.`);
if (broken.length > 0) process.exitCode = 1;
