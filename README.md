# Custom Loadout

The loadout screen gets four slots instead of one perk: Perk, Sidearm, Grenades and Equipment. The Saber can be picked as a sidearm.

A mod for HELLDIVERS (2015), packaged for [ObsidianModManager](https://github.com/Alomare/ObsidianModManager).

## Install

Download `custom-loadout-<version>.zip` from the latest [release](../../releases/latest) and drop it onto Obsidian's mod list, then deploy.

## Updates

`mod/obsidian.json` names this repository as its `source`, so Obsidian shows an update button for it and offers each newer release.

## Releasing a new version

1. Replace the files in `mod/` with the new build.
2. Raise `version` in `mod/obsidian.json` and add a `## <version>` section to `CHANGELOG.md`.
3. Commit and push to `main`. (Pushing a tag `v<version>` works too.)

When `main` has a version with no release yet, the Release workflow zips `mod/` as `custom-loadout-<version>.zip` and publishes the release. Never change the mod `id`.
