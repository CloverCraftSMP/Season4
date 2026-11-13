# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Fancymenu title screen
- Nether and end blocking

### Changed
- Players are now hidden from squaremap web viewer

## [4.0.4] - 2026-11-13

### Added
- Builders option in the installer: Litematica, Syncmatica (share schematics on the server) and Axiom.
- Redstoners option in the installer: MiniHUD, Litematica and Syncmatica.
- Tweakeroo as its own optional toggle in the installer.
- New installs also list the auth server (`auth.clovercraftsmp.com`), used to link a Discord account to a Minecraft account.
- The installer now preselects sensible options on first launch: Standard graphics, no LODs, Xaero's Minimap, and no creator, builder or redstone tools.

### Changed
- High contrast block outline is now off by default for new installs.

### Fixed
- Surveyor and Clover now properly generates structures and loot

## [4.0.3] - 2026-11-11

### Added
- Hoofprint is now available as a map option.
- Chunksmith pregenerates the world and sends its LOD data to players using Voxy or Distant Horizons, so distant terrain shows without exploring it first.
- MixinTrace Reborn, which lists the mixins involved in a crash report.
- Redstone Tweaks resource pack.
- New installs have the CloverCraft server in their server list.
- Issue forms for suggesting mods and reporting problems.
- Contributor tooling: `mise run setup` for first-time setup, and `mise run mod:add` to add a mod with its side, flavor and changelog entry.
- A bot that fixes TOML formatting and `index.toml` on pull requests, so configs can be edited straight from GitHub.
- `ci:check` now catches typos in `unsup.toml` and an out-of-date offduty group.
- `mise run motd:generate` builds the server list MOTDs from `config/MiniMOTD/quotes.txt`, centred to the pixel and checked to fit.

### Removed
- Chunky, replaced by Chunksmith (`/chunky` still works as an alias).

### Changed
- Reworked server permissions. Essential Commands and Open Parties and Claims now follow LuckPerms ranks.
- The `offduty` rank now removes all staff, community rep and developer powers.
- Players are sorted in the tab list by rank.
- Production deploys back up the server before publishing the new pack, so a failed backup no longer leaves players on a newer pack than the server.

## [4.0.2] - 2026-11-11

### Changed
- Updated some server configs

## [4.0.1-beta.03] - 2026-11-10

### Added
- Added `CONTRIBUTING.md` and basic project documentation.
- Basic QOL mods and performance mods.
- Tag production releases, pushing a `vX.Y.Z` tag builds the client pack, boots a ci server on the tagged commit, takes a backup of prod, deploys the `prod` branch, then publishes releases.
- CI now fails on more edge cases.
- Releases refuse to run with an empty `[Unreleased]` changelog, use it as the release notes, then move it under the new version on `main` automatically.
- Crash Assistant now ships with a generated `modlist.json`, so crash reports accurately show which mods a player added, removed or changed compared to the pack.
- Discord notifications: staff get pinged when staging or prod is deployed or restarted (and when a deploy or release fails), and players get a release announcement with the changelog and download links.

### Changed
- Swapped to Packwiz from Pakku for modpack management.
- `mise run build:clients` takes an explicit channel and directory, a stripped version like `4.0.0` no longer points clients at the local server.
- Reworked all workflows
- Deploys now push with `--force-with-lease` and keep the server's `unsup.ini` in sync.
- Pre-release backups stay on the Pterodactyl panel instead of also being downloaded into CI, and the deploy now waits for the backup to actually complete.
- Client artifacts no longer include the version in their filename (`unsup-prod.mrpack`, `prism-unsup-prod.zip`, `modpack-prod.mrpack`), so release downloads have stable names.
