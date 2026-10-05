#!/usr/bin/env node

// Validate routed project-info documents by required concepts and working
// links. Specialized headings and additional sections are valid.
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const rootInfo = path.join(root, "project-info.md");
const failures = [];

function parseInlineLinks(markdown) {
  const source = markdown.replace(
    /^(```|~~~)[^\n]*\n[\s\S]*?^\1[ \t]*$/gm,
    "",
  );
  const links = [];
  for (let cursor = 0; cursor < source.length - 2; cursor += 1) {
    if (source[cursor] !== "]" || source[cursor + 1] !== "(") continue;

    let start = cursor + 2;
    while (/\s/.test(source[start] || "")) start += 1;
    let end = start;
    if (source[start] === "<") {
      start += 1;
      end = start;
      while (end < source.length && source[end] !== ">") {
        if (source[end] === "\\") end += 1;
        end += 1;
      }
    } else {
      let depth = 0;
      while (end < source.length) {
        const character = source[end];
        if (character === "\\") {
          end += 2;
          continue;
        }
        if (character === "(") depth += 1;
        if (character === ")") {
          if (depth === 0) break;
          depth -= 1;
        }
        if (/\s/.test(character) && depth === 0) break;
        end += 1;
      }
    }
    const target = source.slice(start, end).trim();
    if (target) links.push(target);
  }
  return links;
}

function checkLocalLinks(file, contents) {
  for (const target of parseInlineLinks(contents)) {
    if (/^(?:[a-z][a-z0-9+.-]*:|\/\/)/i.test(target) || target.startsWith("#")) continue;
    if (/^\/Users\//.test(target)) {
      failures.push(`${path.relative(root, file)}: host-specific absolute link ${target}`);
      continue;
    }
    if (target.startsWith("/")) continue;

    let localTarget = target.split(/[?#]/, 1)[0];
    try {
      localTarget = decodeURIComponent(localTarget);
    } catch {
      failures.push(`${path.relative(root, file)}: invalid encoded link ${target}`);
      continue;
    }
    if (!localTarget) continue;
    const resolved = path.resolve(path.dirname(file), localTarget);
    if (!fs.existsSync(resolved)) {
      failures.push(`${path.relative(root, file)}: missing link target ${target}`);
    }
  }
}

function checkProjectInfo(file) {
  if (!fs.existsSync(file)) {
    failures.push(`${path.relative(root, file)}: missing project-info route`);
    return;
  }
  const contents = fs.readFileSync(file, "utf8");
  const headings = [...contents.matchAll(/^## (.+)$/gm)].map((match) => match[1].trim());
  const hasHeading = (pattern) => headings.some((heading) => pattern.test(heading));
  const hasIntro = /^# .+\n\s*\n[^#\s][^\n]*/.test(contents);
  const routeName = path.relative(root, file);

  if (!hasHeading(/^(?:Product|Project)$/i) && !hasIntro) {
    failures.push(`${routeName}: add a product heading or a short identity paragraph`);
  }
  if (!hasHeading(/^(?:Major Components|Components|Boundaries)$/i)) {
    failures.push(`${routeName}: add a components or ownership-boundaries section`);
  }
  if (!hasHeading(/^(?:Task Routing|Routes|Routing)$/i)) {
    failures.push(`${routeName}: add a task-routing section`);
  }
  if (!hasHeading(/^(?:Local Rules|Boundaries)$/i)) {
    failures.push(`${routeName}: add a local-rules or boundaries section`);
  }
  checkLocalLinks(file, contents);
}

if (!fs.existsSync(rootInfo)) {
  failures.push("project-info.md: missing family entry route");
} else {
  const familyContents = fs.readFileSync(rootInfo, "utf8");
  for (const target of parseInlineLinks(familyContents)) {
    const match = target.match(/^([A-Za-z0-9_-]+)\/AGENTS\.md$/);
    if (!match) continue;
    const component = match[1];
    const intake = path.join(root, component, "AGENTS.md");
    const aiIntake = path.join(root, component, "ai/AGENTS.md");
    const projectInfo = path.join(root, component, "ai/project-info.md");
    for (const requiredPath of [intake, aiIntake, projectInfo]) {
      if (!fs.existsSync(requiredPath)) {
        failures.push(`${path.relative(root, requiredPath)}: missing routed component intake`);
      }
    }
    if (fs.existsSync(projectInfo)) checkProjectInfo(projectInfo);
  }
  checkProjectInfo(rootInfo);
  checkLocalLinks(rootInfo, familyContents);
}

if (failures.length) {
  for (const failure of failures) console.error(failure);
  console.error(`Checked routed VGMMan project-info files; ${failures.length} issue(s) found.`);
  process.exitCode = 1;
} else {
  console.log("Checked routed VGMMan project-info files and local links; no issues found.");
}
