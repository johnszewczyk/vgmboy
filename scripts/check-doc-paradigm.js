#!/usr/bin/env node

// Keep active onboarding routes in DocMan's canonical project-info shape.
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const required = ["Product", "Major Components", "Task Routing", "Local Rules", "Human Docs"];
const components = [
  "CatalogReader", "VGMBoy", "FrontendCore", "MetaMan", "UACMan",
  "ScanSong", "CocoaSpice", "SPCBoyWK", "ViewBoy",
];
const paths = ["project-info.md", ...components.map((name) => path.join(name, "ai", "project-info.md"))];

let failures = 0;
for (const file of paths) {
  if (!fs.existsSync(path.join(root, file))) {
    console.error(`${file}: required onboarding route is missing`);
    failures += 1;
    continue;
  }
  const contents = fs.readFileSync(path.join(root, file), "utf8");
  const headings = [...contents.matchAll(/^## (.+)$/gm)].map((match) => match[1]);
  if (JSON.stringify(headings) !== JSON.stringify(required)) {
    console.error(`${file}: expected sections ${required.join(" → ")}; found ${headings.join(" → ")}`);
    failures += 1;
  }
  if (/\/Users\/[^/]+\//.test(contents)) {
    console.error(`${file}: host-specific absolute path in an onboarding route`);
    failures += 1;
  }
}

console.log(`Checked ${paths.length} active project-info routes; ${failures} paradigm violations.`);
if (failures > 0) process.exitCode = 1;
