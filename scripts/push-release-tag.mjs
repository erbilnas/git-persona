#!/usr/bin/env node
/**
 * Create and push annotated tag v<package.json version> (publish step for Changesets).
 */
import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const pkg = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
const version = String(pkg.version ?? "").trim();
if (!/^\d+\.\d+\.\d+/.test(version)) {
  console.error(`push-release-tag: invalid package.json version: ${version}`);
  process.exit(1);
}
const tag = `v${version}`;

function git(args, opts = {}) {
  execFileSync("git", args, { cwd: root, stdio: "inherit", ...opts });
}

try {
  execFileSync("git", ["rev-parse", "-q", "--verify", `refs/tags/${tag}`], {
    cwd: root,
    stdio: "pipe",
  });
  console.log(`Tag ${tag} already exists; skipping push.`);
  process.exit(0);
} catch {
  /* tag does not exist */
}

git(["tag", "-a", tag, "-m", `Release ${tag}`]);
git(["push", "origin", tag]);
console.log(`Pushed ${tag}`);
