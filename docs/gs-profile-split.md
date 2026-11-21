# Plan: splitting the profile classes out of GameSpice Core

Status: GameSpice Core side done (API level 22) and the `gs-profile` repository exists with the classes; consumers' `requires` and the family lists are still to do. Below is the plan, then what was done differently.

## Why

`GSProfileSet`, `GSProfile` and `GSProfileRuntime` (see [profiles.md](profiles.md)) are a per-entity config system with its own tiers, `extends`, folders and validation. Only the entity addons use them (gs-npc, gs-weapon, gs-player-class, gs-npc-ai-director, gs-menu, gs-spawn, gs-ui, gs-console, gs-net, gs-workbench), and gs-core is the foundation every addon requires. Each addition to the profile system is an API bump for the whole family. A separate `gs-profile` addon would let it version on its own.

## Constraints

- Class names stay: `GSProfileSet`, `GSProfile`, `GSProfileRuntime`. `class_name` is global, so every consumer keeps compiling without an edit.
- The cfg paths and file formats do not change.
- GameSpice Core itself uses the profile classes in places (`GSAddonConfig` callers, selftests); GameSpice Core must not require GameSpice Profile, since GameSpice Profile would require GameSpice Core.

## Steps

1. Create `gs-profile` with the three scripts, `docs/profiles.md` and the profile selftest, moved with `git mv`-style history kept by a subtree split. It requires gs-core at the API level that has `GSAddonConfig.merge` (17).
2. In GameSpice Core, leave the three files as shims for one release cycle: the same `class_name` cannot exist in two addons, so the shim is the move itself. The files are deleted from GameSpice Core in the same release that GameSpice Profile ships, and GameSpice Core's `gs_core_api.gd` raises its level.
3. Each consumer addon adds GameSpice Profile to its `requires` (its `gs_*_api.gd` floor and `provides.json`/`requires.json`), and `gs-bootstrap/projects.tsv` and GameSpice Server Deploy's `addons.yml` gain the new row.
4. A game that uses a profile-based addon gets GameSpice Profile through that addon's requirement; there is nothing to change in its code.
5. Deprecation: for one release GameSpice Core keeps a `GSCoreProfileCompat` check that logs once (`GSCfgLegacy`-style warn-once) when a project has the profile classes but not GameSpice Profile in the addon list. Remove it on the date set in that release's notes.

## Order and risk

- Do the move in one pass: GameSpice Profile, GameSpice Core, then the ten consumers' requirements, because a project that has two copies of a global class fails to parse.
- Run every consumer's suite and `./game.sh test` in the reference game after the import cache is rebuilt (`--import`), since a moved `class_name` leaves a stale cache.
- Roll back by restoring the three files in GameSpice Core; nothing else changes.

## What was done

- `gs-profile` was built by filtering gs-core's history to the profile paths (`git filter-branch`, no `git subtree`, since the paths are scattered), so `git log` there goes back through the gs-core commits. Layout `addons/gs_profile/{core,tools}`, level 1, requires gs-core >= 21.
- No shim: the files were deleted from GameSpice Core in the same change (step 2's "shim is the move itself").
- `GSAddonConfig.save_user(..., schema)` and `set_user_tier` used the profile classes. gs-core now carries what they needed as public helpers: `GSYaml.emit`, `GSAddonConfig.set_nested`, `is_finite_value` and `check_field`. `GSProfileSet.user_tier_enabled` is now a property that reads `GSAddonConfig.user_tier_enabled`, so one call switches both.
- GameSpice Core's API level is 22; OLDEST stays 1 because the class names are unchanged.
- Step 5 (`GSCoreProfileCompat`) is skipped on purpose: the classes no longer exist in GameSpice Core, so a project with a consumer and no GameSpice Profile fails to parse with `Identifier "GSProfileSet" not declared`, loudly and before any warn-once could run; a check that cannot name the classes has nothing to look for.

## Still to do (other repositories)

- Each consumer addon (gs-npc, gs-weapon, gs-player-class, gs-npc-ai-director, gs-menu, gs-spawn, gs-ui, gs-console, gs-net, gs-workbench) requires gs-profile (`gs_profile: 1` in its `requires.floor.json`).
- `gs-bootstrap/projects.tsv`, gs-server-deploy's `addons.yml` and `repo_url()` rows, and gs-ci's `scripts/check-profiles.sh`, which still runs `addons/gs_core/tools/profile_check.gd` (now `addons/gs_profile/tools/profile_check.gd`).
- Any selftest outside gs-core that names `GSProfileSet.user_tier_enabled`, and `--import` in every consumer.
