#!/usr/bin/env node
/**
 * After `changeset version`, copy semver from package.json into Version.xcconfig
 * and bump CURRENT_PROJECT_VERSION by 1 for each release.
 */
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const pkgPath = join(root, "package.json");
const xcPath = join(root, "GitPersona", "Version.xcconfig");

const pkg = JSON.parse(readFileSync(pkgPath, "utf8"));
const version = String(pkg.version ?? "").trim();
if (!/^\d+\.\d+\.\d+/.test(version)) {
  console.error(`sync-version-xcconfig: invalid package.json version: ${version}`);
  process.exit(1);
}

let xc = readFileSync(xcPath, "utf8");
xc = xc.replace(/^MARKETING_VERSION = .*$/m, `MARKETING_VERSION = ${version}`);

const curMatch = xc.match(/^CURRENT_PROJECT_VERSION = (\d+)\s*$/m);
const cur = curMatch ? parseInt(curMatch[1], 10) : 1;
const next = Number.isFinite(cur) ? cur + 1 : 1;
xc = xc.replace(/^CURRENT_PROJECT_VERSION = .*$/m, `CURRENT_PROJECT_VERSION = ${next}`);

writeFileSync(xcPath, xc, "utf8");
console.log(`Version.xcconfig → MARKETING_VERSION ${version}, CURRENT_PROJECT_VERSION ${next}`);
