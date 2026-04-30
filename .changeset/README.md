# Changesets

Add a changeset before merging user-visible work:

```bash
npm install
npm run changeset
```

Commit the generated file under `.changeset/` with your PR.

When it lands on `main`, [`.github/workflows/changesets.yml`](.github/workflows/changesets.yml) opens a **Version packages** PR. After you merge that PR, the workflow tags `v<semver>` and pushes it so the **Build DMG** workflow can ship a GitHub Release.

`npm run version-packages` (run by the bot) bumps `package.json`, updates `CHANGELOG.md`, syncs `GitPersona/Version.xcconfig` (`MARKETING_VERSION` + `CURRENT_PROJECT_VERSION`), and removes consumed changesets.
