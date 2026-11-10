# Contributing to CloverCraft

## Prerequisites
You do **not** need to install Java, Packwiz, or Unsup manually. We use `mise` to manage all of our tooling automatically.

1. Install [mise](https://mise.jdx.dev/).
2. Clone this repository.
3. Open a terminal in the project folder and run `mise install`.

## Modifying the Pack

### 1. Adding/Updating Mods
**Do not drag `.jar` files into the `mods/` folder.** We use Packwiz to manage dependencies.
* To add a mod: `packwiz modrinth add <mod_name>` (add `--client` if it's a client-only mod).
* To update all mods: Run `mise run packwiz:update-mods`.
* After editing any file in the pack, run `mise run packwiz:refresh` (the pre-commit hook does this for you).

### 2. Server vs Client Mods
If you add a client-side only mod (like Iris, Xaero's Minimap, or Voxy), you must ensure `packwiz` knows it shouldn't go to the server. 
Open the mod's `.pw.toml` file and ensure it says:
```toml
side = "client"
```

### 3. Managing Flavors

If you add heavy visual mods, map them to our unsup flavor groups. Open unsup.toml and link the mod to the appropriate flavor.

## Testing Locally

We use two terminals to test the pack spinning up a local web server for emulating a hosted pack.

### Terminal 1 (Web Server):
Run `mise run packwiz:serve`. This spins up the local packwiz server so the client/server can download mods. Leave this running!

### Terminal 2 (Game Server):
* To test the server: `mise run server:run`
* To test the client: `mise run pack:unsup-prism` and drop the generated zip from `build/` on your Prism instance, launch that whenever you want to test the client from then on.
* To run the same checks as CI: `mise run ci:check` and `mise run ci:run` (boots the server headlessly and checks it comes up).

## Release Pipeline

**Do not manually edit version numbers or hashes** in config files. We use placeholders (e.g. `@modpack_version@`) which are automatically injected during release.

To trigger a new release, simply push a new Git tag:

```sh
git tag v1.0.0
git push origin v1.0.0
```

The Release workflow validates the tagged commit, builds the clients, backs up and deploys the production server, and publishes a GitHub release using the matching `CHANGELOG.md` section as its notes.