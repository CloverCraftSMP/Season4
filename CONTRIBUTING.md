# Contributing to CloverCraft

- **Just want to suggest a mod or report a bug?** [Open an issue](../../issues/new/choose) and fill in the form.
- **Changing a config file?** You can do it [in your browser](#editing-in-your-browser).
- **Adding mods or testing locally?** Follow [Setting up](#setting-up) first.

## Words you'll see

| Word | What it means |
|------|---------------|
| **packwiz** | The tool that keeps track of the mods. Each mod is a small `.pw.toml` file in `mods/` that says where to download it from. |
| **unsup** | The updater built into players launchers. It downloads the pack and keeps it up to date. |
| **Side** | Who needs a mod: `client` (players only), `server` (server only) or `both`. |
| **Flavor** | An option players pick when they first install, like the graphics profile, the LOD renderer or the map mod. Set in `unsup.toml`. |
| **Channel** | Which version of the pack: `local` (your computer), `staging` (the test server) or `prod` (the real server). |
| **PR** (pull request) | A proposed change that someone reviews before it goes into the pack. |

## Where things live

| Path | What's in it |
|------|--------------|
| `mods/`, `resourcepacks/` | One `.pw.toml` file per mod or resource pack. Don't put `.jar` files here. |
| `config/` | Config files sent to players **and** the server. These overwrite whatever is there on every update. |
| `config/yosbr/` | Default **player** settings (keybinds, video settings, mod options). These are only applied on first install, so players own changes are kept. |
| `unsup.toml` | The install options players pick (flavors), and which mods belong to each. |
| `mods/luckperms/toml-storage/groups/` | Server ranks and permissions (LuckPerms). After changing `communityrep`, `staff` or `dev`, run `mise run perms:offduty`. Never edit `offduty.toml` by hand. |
| `CHANGELOG.md` | What changed in each release. Add a line under `## [Unreleased]` for anything you change. |

**Don't edit by hand:** `index.toml` and the `hash` in `pack.toml` (generated), the version number (filled in on release) and the `staging`/`prod` branches (created automatically).

## Editing in your browser

For config changes, the changelog, or `unsup.toml`, you don't need to install anything:

1. Open the file on GitHub and click the pencil icon.
2. Make your change, then click **Commit changes** and choose **Create a new branch and start a pull request**.
3. Fill in the PR form and submit.

A bot then formats the files and updates `index.toml` on your PR for you, and the checks boot a real server with your change.

## Setting up

You need [git](https://git-scm.com/downloads) and [mise](https://mise.jdx.dev/getting-started.html). mise installs everything else (Java, packwiz and so on).

```sh
git clone https://github.com/CloverCraftSMP/Season4.git
cd Season4
mise run setup
```

`mise tasks` lists every command available.

## Adding a mod

```sh
mise run mod:add sodium
```

You can use the Modrinth slug (the end of the mod's page URL) or the whole link. It will:

1. Download the mod's info and any mods it depends on.
2. Ask whether players, the server or both need it.
3. Ask who should get it: everyone, only the higher graphics profiles, or content creators.
4. Add a line to the changelog.

Then commit and open a PR. Mods can only come from Modrinth. **Never drop `.jar` files into `mods/`.**

### Picking the side

- `client`: anything you only see or hear, like shaders, particles, HUD, minimaps, sounds, menus.
- `server`: admin and server tools, like LuckPerms, backups, server performance.
- `both`: anything that adds blocks, items, mobs, or changes gameplay.

If a `client` mod ends up on the server it can crash it, so the checks will usually catch that.

### Flavors (`unsup.toml`)

Mods **not** listed under `[metafile]` go to everyone. To limit a mod to some options, add a line using its file name (without `.pw.toml`):

```toml
clover-mod = { flavors = ["ultra", "standard"] }
```

| Flavor | Who gets it |
|--------|-------------|
| `ultra` / `standard` / `lite` | Graphics profiles. Heavy visuals go in `ultra` only; medium ones in `ultra` and `standard`. |
| `voxy` / `dh` | Players who chose that LOD renderer. |
| `xaeros-minimap` / `xaeros` / `hoofprint` | Players who chose that map option. |
| `creator` | Content creators (Flashback, Axiom). |

`mise run ci:check` will complain if you mistype a mod name here.

### Updating mods

A bot opens an **Automated Mod Updates** PR every 6 hours when there are updates. Check that its server boot check is green, then merge it. To update by hand: `mise run packwiz:update-mods`.

## Testing locally

You need two terminals:

1. **Terminal 1:** `mise run packwiz:serve` hosts the pack on your computer. Leave it running.
2. **Terminal 2:**
   - Server: `mise run server:run` starts a server you can join at `localhost`.
   - Client: `PACKDEV_CHANNEL=local mise run pack:unsup-prism` builds a Prism Launcher instance in `build/`. Import it into Prism once, and it updates itself from Terminal 1 each time you launch it.

`mise run ci:check` and `mise run ci:run` run the same checks as GitHub.

## Testing on staging

Ask a developer to deploy your branch, or if you have access: go to **Actions -> Deploy Staging -> Run workflow**, pick your branch and run it. Staff are pinged on Discord when it's up.

## Commits

Commit messages follow [conventional commits](https://www.conventionalcommits.org/), e.g. `feat: add dynamic fps`, `fix: lower voice chat distance`, `chore: update mods`. The git hook checks this for you.

## Releasing (developers)

**Don't edit version numbers or hashes by hand.** Placeholders like `@modpack_version@` are filled in during release.

Make sure `## [Unreleased]` in `CHANGELOG.md` lists the changes, then push a tag:

```sh
git tag v4.1.0
git push origin v4.1.0
```

The Release workflow validates the tagged commit and refuses to release if `[Unreleased]` is empty. It then builds the clients, backs up and deploys the production server, publishes a GitHub release with the `[Unreleased]` entries as its notes, announces it on Discord, and commits `CHANGELOG.md` to `main` with those entries moved under `## [X.Y.Z] - <date>`. Pull afterwards before editing the changelog again.
