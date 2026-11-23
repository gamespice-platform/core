# Which addon API a build has: `GSAddonApi`

**A delivered pack's scripts compile against the HOST's addons**, so a pack written against a newer addon than the client shell or server has does not fail with a sentence: it fails to parse mid-load, with an identifier that "is not declared in the current scope". `GSAddonApi` turns that into "This game needs GameSpice Net API level 3 or newer; this server has level 2.", asked before a single script in the pack is loaded (GameSpice Cloud asks between download and mount; GameSpice Server Deploy's installer asks before switching versions).

## A level, not the release version

The tag's semver is honest only in a release: gs-ci stamps it into `plugin.cfg`, but a developer checkout is a symlink whose `plugin.cfg` says 0.1.0 whatever it holds, `plugin.cfg` is not a resource so an exported build does not carry it, and a tag moves for a bug fix that changes no API ("needs 0.4.1" would refuse a 0.4.0 host that runs the pack perfectly). A level committed in the addon's own source is the same number in all three places.

## The rule, for every addon

- `addons/<addon>/<addon>_api.gd` holds `const LEVEL` and `const OLDEST`, with **no `class_name`**, so sixty addons do not add sixty globals. GameSpice Core's is `gs_core_api.gd`.
- **Bump `LEVEL` when you add anything a game could call**, and write what the level added in the file's comment.
- **Raise `OLDEST` to the new `LEVEL` when you remove or change something a game could have called**: every pack built before that no longer compiles.
- An addon with no api file is at level 1, the level everything was at when the scheme began.

## `requires.json`

A pack says what it needs at its root: `{"format": 1, "addons": {"gs_net": 3}}`. Nobody keeps it by hand: `addons/gs_core/tools/gs_requires.gd` derives it from the game's own files (every global class declared under `res://addons/<x>/` that a script, scene or resource names, and every literal `res://addons/<x>/` path) at the levels the building checkout has. "Built against" is conservative on purpose. gs-ci's `package.sh --pack` writes it into the pack; a game that commits its own keeps control of it and the release audits it instead (`--check`), failing on an addon used and not declared or a level above what the build has.

## An addon the game reaches only behind a presence check stays out

`derive` does not require an addon that every file naming it reaches by a literal `res://addons/<x>/` path handed to `load()` in a script that also asks `ResourceLoader.exists`, `FileAccess.file_exists`, `DirAccess.dir_exists_absolute`, `GSAddonApi.installed` or `GSAddonApi.build_level` (`derive_optional` lists them, and `gs_requires.gd` says so on stderr). A global class name, a `preload()`, or a scene or resource naming the path is compile-time and keeps it required. Comments are ignored, so a doc comment naming a class does not count. The check is per file: a script testing one path and loading another is the author's promise. This is how mg-dangerous-delivery uses natural-disasters for lightning when it is linked and runs on a shell that has no such addon. No API level change: `derive_optional` is tooling, and an older gs-core only over-requires, which refuses rather than misruns.

## `requires.uses.json`: an addon used through config only

`derive` finds addons from class names and `res://addons/<x>/` paths in scripts and scenes. A game that reaches an addon only through config (a pack list in `cfg/`) shows no such name, so its `requires.json` would omit it and `floor_audit` would refuse a floor on it as unused. The game commits `requires.uses.json` at its root, `{"format": 1, "uses": ["fc_weapons"]}`; `derive` counts each installed name as used (API level 24). Names that are not installed are skipped like any other.

## `requires.floor.json`: asking less of an addon the game guards

"Built against" is wrong in one case: a game that asks the host first (`GSAddonApi.build_level("gs_ui") >= 2`) and keeps an older path for an older host. Its derived `requires.json` still asks for level 2, so the older host refuses the pack before the guard runs, and the older path is dead code. Such a game commits `requires.floor.json` at its root, the same shape as `requires.json`, naming only the guarded addons at the lowest level its older path runs on: `{"format": 1, "addons": {"gs_ui": 1}}`. `gs_requires.gd` lowers those addons to their floors when it writes or prints (`apply_floors`) and derives every other addon as before, so the list still keeps itself. Committing a whole `requires.json` instead would also work, but it is audited only for addons missing or overstated, never understated, so it goes silently stale low the first time the game calls a newer API unguarded.

`floor_audit` fails the run on a floor nothing backs: an addon the game no longer uses, a floor above the build's level, a floor below the build's `OLDEST` (a host at the build's own level would then refuse the pack), and a floor below the build's level with no file asking the host for that addon's level (`build_level("x")` or `level_of("x")`, found by `guarded()`). `gs_requires.gd --pin NAME=N` (repeatable; gs-cloud's `publish_pack.sh` passes the host `addons.lock` levels) judges floors against the pinned level instead of the linked head, so a head a level past its pinned tag does not fail a floor at the pinned level; an unguarded floor below the pin, or one above it, still fails. No API level change: it is tooling. A game also runs `floor_audit` in its own suite, so a removed guard fails there before a release does. The floor cannot prove each newer call is behind the guard; that remains the game's promise, and the guard's suite (both levels) is where it is tested. A committed `requires.json` wins over a floor file. Needs gs-core API level 4 where the pack is built (gs-ci resolves a game's addons at main); an older gs-core ignores the file and the pack asks for the built levels, which an older host refuses rather than misruns.

`overrides` exists because a client and a server in one process share one set of addon files, so "an older client" can only be a claim. `examples/addon_api_selftest.tscn` asserts the sentences, not just `CODE_VERSION`.

## What each level added
- 2: GSTransportDual, GSDualPeer, GSUdpDemux (WebSocket + ENet in one server).
- 3: GSMeteredPeer (any MultiplayerPeer, counted per channel; what net_stat draws).
- 4: GSAddonApi.FLOOR_FILE, apply_floors, floor_audit, guarded, and parse's file_name (a game asking less of an addon whose newer API it guards).
- 5: camera/: GSCameraProbe, GSCameraBoom, GSCameraFade (cameras that stay out of the level and fade the people between them and what they look at).
- 6: GSCollisionAudit (visible level geometry nothing collides with; `gs_no_collision` opt-out).
- 7: GSTcpScreen, GSTransportDual.tls_hello_screen / TlsHelloScreen / is_loopback_bind, GSDualPeer.screen (a TLS ClientHello at a plain WebSocket listener closed at once).
- 8: GSRenderWarmup (draws a scene's materials once, out of sight, so shaders compile under a cover).
- 9: GSContentIndex, GSContentEntry (what mounted packs provide, tagged by session: solo or online).
- 10: loading/: GSLoadGate, GSLoadingCover (the game is not ready to be seen yet: holds, requirements, frozen nodes, a cover a host can claim).
- 11: GSParallel (a fork/join on the worker pool that returns inside the tick: pure tasks, results in index order, a verify mode that runs them twice).
- 12: GSYaml (the YAML subset reader), GSRotationSpec (maps.yml / games.yml: rotations, wildcards, layering, `commands:`), GSCommandNames (renames, aliases, collision skip).
- 13: GSAddonConfig (cfg/addons/<name>/*.yml: every file read in name order over defaults, then environment, then command line).
- 14: GSHttpServer, GSHttpRequest, GSHttpResponse (net/: a small HTTP/1.1 server, desktop and server only).
- 15: GSCfgLegacy (old cfg path read through a warn-once shim until 2026-12-31), GSAddonConfig.folder_name / file_layers and the cfg/server/<addon>/ operator tier; an addon name's `-` is now `_` in its cfg/addons folder.
- 16: GSAddonConfig.apply_file (one named yml through the addon, server and legacy layers, applied by the caller).
- 17: GSAddonConfig.merge (public), config_root, GSAddonConfig.game and the cfg/game/<game>/<addon>/ tier; the operator tier is now cfg/server/addons/<addon>/ (the old cfg/server/<addon>/ is read through GSCfgLegacy: old paths are read-only compat, which is why OLDEST stays 1). Also in 17: GSAddonConfig.replace_aware_layers; GSProfileSet reads tier first (schema < addon < game < server legacy < server/addons < server/game, roots res then user); GSProfileRuntime saves to <root>/server/game/<game>/ or server/addons/<addon>/ (server/<kind>/ with neither).
- 18: GSAddonConfig user tier (cfg/user/addons/<addon>/ in user://, solo and listen host only): set_user_tier, user_tier_enabled, user_file, user_paths, save_user, reset_user; GSProfileSet.set_user_tier switches both.
- 19: GSAddonConfig.tier_dirs and apply_overrides (public; GSMapConfig no longer calls the private ones).
- 20: GSHttp max_bytes on get_bytes, request and download_to_file (a per-call body_size_limit).
- 21: cfg directory names are singular (cfg/addon/, cfg/game/, cfg/server/addon/, cfg/server/game/, user/addon/); the plural names are read through GSCfgLegacy until 2026-12-31, the singular file winning whole.
- 22: the profile classes (GSProfileSet, GSProfile, GSProfileRuntime, tools/profile_check.gd) moved to the GameSpice Profile addon, class names unchanged: a project that used them now needs GameSpice Profile (same class names, so OLDEST stays 1). New here for it: GSYaml.emit, GSAddonConfig.set_nested, is_finite_value and check_field (the schema check save_user uses). GSAddonConfig.set_user_tier no longer touches GSProfileSet; that set reads the same flag.
- 23: GSCollisionSweep (drawn floor and walls against the physics world, and collision nothing is drawn at).
- 24: GSAddonApi.USES_FILE and declared_uses: derive() counts addons a project names in requires.uses.json (use through config only), so a floor on them is not refused as "does not use".
- 25: camera/: GSViewLens (the first-person model lens maths: vertical_from_horizontal_4_3, lens_scale, apply).
- 26: profile/: GSFrameCost (systems report their per-frame cost: now, add, add_usec, take, reset); GSHitchLog.frame_measured, top_systems and a hitch's `systems`.
- 27: GSLoadGate.cover_slice_msec and slice_msec(base_ms): a wider per-frame budget for work held under the cover.
- 28: GSWeb.sync_failures, flush_filesystem (a failed IndexedDB save is counted, logged and retried) and has_new_sync_failures.
- 29: core/GSAdminIdentity (the admin-only identity gate hoisted from GameSpice Workbench: resolver, admin_uids, admin_groups, flags, fallback_permit; authenticate and permit are the hooks).
- 30: profile/: GSFrameCost.trace, span, take_events, add_query and take_queries (nested spans and physics queries per system); GSSpaceQuery (cast_motion, rest_info, ray, shape, point, collide_shape, move_and_collide, body_test_motion: counted and timed while GSFrameCost is enabled); a GSHitchLog frame record's `queries`, `events` and `usec`.
- 31: GSAddonConfig.register_former_game, game_names and former_games (a renamed game's old `cfg/game/<old>/` tiers and rotation keys still apply).
- 32: capture/GSShotGate.wait_lifted (a screenshot tool awaits the load cover lifting, with a timeout, instead of a fixed number of seconds).
- 33: GSWeb.fetch_bytes / can_fetch_bytes and GSHttp.web_whole_body_fetch (web downloads held in memory are read whole by the browser, not one chunk per frame).
- 34: GSAddonApi.pinned_levels and floor_audit's `pinned` argument (a floor is judged against the level of the version the live shell pins, from addons.lock, not the linked head).
- 35: GSParallel.auto_max / set_auto_max and GSScheduler.auto_thread_max (the automatic worker caps 8 and 4 are settings, 0 = no cap); GSScheduler.thread_count has no upper limit.
- 36: GSLog.CHANNEL_PREFIX (`gs`). (The legacy channel mapping, display_channel, is gone at 43.)
- 37: GSConfig.gs_env (an environment variable by its full name). (The former-prefix fallback, gs_env_name, is gone at 43.)
- 38: GSRenderWarmup.follow_camera / cancel() / is_running(); GSLoadGate.warm_survives_close (a hold mid-warm-up no longer cancels the warm-up, so every item is drawn).
- 39: GSLoadGate.mute_audio (default on) / is_audio_muted(): the Master bus is muted while the gate is closed (loading, map change, settling, warming) and restored when it opens.
- 40: GSNativeParity (core/gs_native_parity.gd): holds a native twin to its script original, same inputs through both, bit-exact compare, skipped when the native class is absent (web), bench(); docs/native-twins.md.
- 41: GSWireDoc (core/gs_wire_doc.gd): a JSON document as one message (text deflated behind both lengths): `encode(doc, sort_keys)`, `decode_text(bytes, what, max_size)` (every refusal named, no engine error), `digest`; what games hand-wrote in each map or course document.
- 42: GSBoundedBuffer (core/gs_bounded_buffer.gd): one bounded FIFO with a head index (no front shifts), `capacity` and `max_weight` (0 = unlimited), `Policy.DROP_OLDEST` or `REFUSE`, counters (`dropped`, `refused`, `dropped_weight`, `high_water`), `take`, `peek`, `requeue`, `to_array`, `load_array`; replaces the log queue, the telemetry queue and the report outbox.
- 43: OLDEST 43. The Dot to GS rename without aliases: every class, channel and environment variable has one name; GSLog.display_channel, GSConfig.gs_env_name and deprecated_env_warned are removed, so a pack built before 43 must be rebuilt.
- 44: GSBusyIndicator (bottom-right progress bar, status, "the game may stutter" warning, quota error with a clear-downloads button; stays up until frames are steady), GSLoadGate.hold_shown (hold, then wait a frame so the cover is drawn before heavy work) / watch_content / busy_indicator / indicator.
- 45: GSWeb.heap_bytes (the WebAssembly heap size through a named function in gs_web.js, 0 off-web).
