## What does this change?

<!-- A sentence or two is plenty, e.g. "Adds Dynamic FPS for the Standard and Ultra profiles". -->

## Checklist

- [ ] Added a line under `## [Unreleased]` in `CHANGELOG.md` (`mise run mod:add` does this for you)
- [ ] Mods that only players need are `side = "client"`
- [ ] Heavy visual mods are in a flavor in `unsup.toml`
- [ ] Tested it: on staging, or locally with `mise run server:run`

<!-- Don't worry about index.toml or TOML formatting: a bot fixes those on PRs automatically. -->
