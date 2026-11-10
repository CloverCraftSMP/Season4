# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
