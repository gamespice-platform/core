# GameSpice Core

Shared foundation for the gs-* family: logging, platform capability detection, filesystem handling, configurable node references, layered configuration, frame-budgeted background work, hashing, reproducible randomness, HTTP, the multiplayer transports, and addon API levels. Every other addon depends on it, and it depends on nothing.

**The distributable is `addons/gs_core/`.** `project.godot` and `examples/` exist so the addon can be opened and validated on its own.

The family-wide conventions in [family CLAUDE.md](../../CLAUDE.md#family-wide-conventions) (no autoloads, `GSNodeRef`, `GSResult`, capabilities not platforms, `GS` prefix, layered config, `GSLog` levels, `print`/`push_error`, `describe()`) are implemented here; changing one is a breaking change for every repository. The reasoning for what is specific to gs-core is in [docs/](docs/README.md).

## Read before

| Read | Before |
| --- | --- |
| [docs/README.md](docs/README.md) | the index |
| [docs/engine-traps.md](docs/engine-traps.md) | comparing a `Variant`, touching `GSWeb`, emitting from a thread, `GSLog`'s engine mirror |
| [docs/transports.md](docs/transports.md) | anything in `net/`, a platform constraint, `GSHttp` |
| [docs/addon-api.md](docs/addon-api.md) | adding to or removing from any addon's API; `requires.json`; `requires.floor.json` for a game that guards a newer level |
| [docs/randomness.md](docs/randomness.md) | anything in `random/`, or writing a seeded draw anywhere |
| [docs/camera.md](docs/camera.md) | anything in `camera/`, or any camera that is not a player's own eyes |
| [docs/loading.md](docs/loading.md) | anything in `loading/`, a loading screen, or a game shown before its world is in |

## Layout

| Path | What |
| --- | --- |
| `core/gs_content_index.gd`, `gs_content_entry.gd` | what mounted packs provide (`entries(kind)`), tagged solo or online; registered as `gs_content_index`; GameSpice Cloud fills it, catalogues read it; `examples/content_index_selftest` |
| `core/gs_error.gd`, `gs_result.gd` | failure codes (`CODE_*` is the contract); ok/value/error, where reading `.value` on a failure errors |
| `core/gs_platform.gd`, `gs_web.gd`, `web/gs_web.js` | cached capability detection; JavaScriptBridge access, safe on every platform. Nothing evaluates a string (the game origin's CSP has no `unsafe-eval`): browser calls are named functions in `gs_web.js`, which the shell loads |
| `core/gs_paths.gd` | path sanitisation (traversal refusal), atomic writes |
| `core/gs_log.gd`, `gs_log_bus.gd`, `gs_log_sink.gd` | levelled, channelled logging; its signal carrier; the rotating file sink (a Node) |
| `core/gs_registry.gd`, `gs_registry_bus.gd` | name to instance, the autoload replacement; its signal carrier |
| `core/gs_node_ref.gd` | configurable "which node". Read it first |
| `core/gs_config.gd` | layered configuration base |
| `core/gs_addon_config.gd` | `GSAddonConfig`: every addon's tuning is `cfg/addon/<addon_name>/*.yml`, all files read in name order, later keys win; `load_dir(name, defaults)`, `get_value`, `dir_for`, `describe`; folder is the name with `-` as `_`, `cfg/server/<addon>/` is the operator tier over it, `file_layers`, `apply_file` (one named yml into a typed config, server and legacy layers); the player's `user://cfg/user/addon/<addon>/` tier (`set_user_tier`, `save_user`, `reset_user`; solo and listen host only, API 18); `core/gs_cfg_legacy.gd` `GSCfgLegacy` is the warn-once shim for a moved file (removal 2026-12-31); [docs/addon-config.md](docs/addon-config.md); `examples/addon_config_selftest` |
| `core/gs_addon_config.gd` also holds `set_nested`, `is_finite_value`, `check_field`, `GSYaml.emit` | the profile classes (`GSProfileSet`/`GSProfile`/`GSProfileRuntime`, `tools/profile_check.gd`) live in the **GameSpice Profile** addon since API level 22; they use these four helpers; GameSpice Core must never name them |
| `core/gs_job.gd`, `gs_scheduler.gd`, `gs_hash_job.gd` | sliceable work, frame budget and worker pool, chunked file hashing |
| `core/gs_parallel.gd` | `GSParallel`: a fork/join on the worker pool that returns inside the tick (pure tasks, results applied in index order by the caller, `GS_PARALLEL_VERIFY=1` runs each twice); GameSpice Net's snapshot threads |
| `core/gs_hash.gd`, `gs_rate_limiter.gd`, `gs_semver.gd`, `gs_value.gd` | SHA-256/HMAC/constant-time compare/base64url; token bucket; versions that do not sort 0.10 below 0.9; total comparisons |
| `core/gs_admin_identity.gd` | `GSAdminIdentity` (API 29): the admin-only identity gate for an api with `identity(token)` and `permit(actor, flag)` hooks (GameSpice Workbench, GameSpice Radio); resolver Callable, `admin_uids`/`admin_groups`, `flags`, optional `fallback_permit`; deny by default; duck-typed, no GameSpice Auth reference; `examples/admin_identity_selftest` |
| `core/gs_native_parity.gd` | `GSNativeParity` (API 40): holds a native (GDExtension) twin to its script original, same inputs through both, bit-exact `same`, `compare` skipped when the class is absent (web) and failed under `GS_NATIVE_REQUIRED=1`, `bench`; [docs/native-twins.md](docs/native-twins.md); `examples/native_parity_selftest` |
| `core/gs_wire_doc.gd` | `GSWireDoc` (API 41): a JSON document as one network message, deflated behind both lengths; `encode`, `decode_text` (refuses empty, torn, absurd and undecompressable bytes by name), `digest`; `examples/wire_doc_selftest` |
| `core/gs_bounded_buffer.gd` | `GSBoundedBuffer` (API 42): a FIFO that cannot grow without limit: `capacity` and `max_weight` (0 = unlimited), `DROP_OLDEST` or `REFUSE`, counters, head-index storage (no front shifts), `take`/`peek`/`requeue`/`to_array`/`load_array`. |
| `core/gs_collision_audit.gd` | `GSCollisionAudit.audit(root)`: visible meshes, CSG, GridMaps and MultiMeshes with no covering collision; opt out with metadata or group `gs_no_collision`, inherited; `examples/collision_audit_selftest` |
| `core/gs_collision_sweep.gd` | `GSCollisionSweep`: rays from the drawn floor and walls into the physics world (drawn with no collision) and from standing points out (collision nothing is drawn at); counted per 2 m cell; `examples/collision_sweep_selftest`; driven by game-zombie-zone `tools/collide_probe` |
| `core/gs_addon_api.gd`, `gs_core_api.gd`, `tools/gs_requires.gd` | API levels and the refusal sentence; GameSpice Core's own level; derives or audits a game's `requires.json`, lowered by its `requires.floor.json` and extended by `requires.uses.json` (addons used through config only) |
| `tools/gs_parse_all.gd` | the parse pass in ONE process (no `class_name`): reads a list of scripts, loads each fresh, prints `PARSE> path` on stderr before it and `PARSE_FAIL path` after a failure, `PARSED n FAILED m` on stdout, exits 1 on any failure. About 10x faster than `--check-only` per file (66 scripts: 40 s against 4 s), same verdicts; gs-ci's `check.sh` uses it when present. `examples/parse_all_selftest` writes bad scripts to `user://` at run time, so no broken `.gd` is tracked |
| `tools/gs_scenario.gd`, `gs_clip_metrics.gd`, `gs_filmstrip.sh` | play-and-record: `GSScenario` loads a JSON timeline (`clips[].steps` of move, yaw, turn, buttons, events) and answers `state_at(t)`; `GSClipMetrics` scores sampled clips (foot slide, floor contact, framing, bone pop) against limits and prints a PASS/FAIL table; `gs_filmstrip.sh <movie> <prefix> --views fp,tp` makes a timestamped contact sheet and an mp4 with ffmpeg alone. `GSClipMetrics.pose_sample` (foot bones by name, sole offset from the first frame), `limits_for(path, clip)` (a thresholds file's defaults plus one clip) and `write_report` do what every capture driver repeated. A game supplies the scenario, thresholds and capture driver (game-fatal-contact, game-zombie-zone `tools/filmstrip.sh`) |
| `net/` | `gs_transport*.gd` (base with address parsing incl. bracketed IPv6, websocket, enet, auto, dual), `gs_dual_peer.gd`, `gs_udp_demux.gd`, `gs_tcp_screen.gd` (closes a TLS hello and a plain HTTP request (no Upgrade: websocket) at the plain WebSocket port, relays the rest), `gs_metered_peer.gd`, `gs_http.gd` (client), `gs_http_server.gd`/`_request.gd`/`_response.gd` (`GSHttpServer`: HTTP/1.1 on `TCPServer`, polled by the host, strict parser, limits, static dirs, optional TLS; [docs/http-server.md](docs/http-server.md)) |
| `random/` | `gs_random_stream.gd`, `_table.gd`, `_schedule.gd`, `_config.gd`, `_manager.gd` (the node a game holds; the only thing that knows the seed) |
| `camera/` | `gs_camera_probe.gd` (a swept sphere from a pivot, eased in ahead of an obstacle and out behind it), `gs_camera_boom.gd` (the `SpringArm3D` replacement built on it), `gs_camera_fade.gd` (fades characters between the camera and its focus, hides one at the camera; `bodies_fn` for characters with no collider), `gs_camera_check.gd` (flies a camera along a scripted path, armed), `gs_camera_tool.gd` (the base of every game's `tools/render_cameras.gd`), `gs_view_lens.gd` (the lens maths a held first-person model is drawn with: scale and pull-in for its own field of view), `gs_render_warmup.gd` (draws a scene's materials once out of sight so shaders compile under a loading screen), `gs_shader_group_arm.gd` (one lightmapped draw that enables Forward+'s lightmap shader group before the level's shaders exist) |
| `loading/` | `gs_load_gate.gd` (`GSLoadGate`: `hold`/`release`/`require` reasons, `freeze` nodes while held then settle them under the cover with input off (`settle_frames`, `freeze_input`, `is_settling`), `warm_up` items, a timeout that opens with a warning; finds a host by `gs_load_gate_host` metadata, else covers itself and runs `GSRenderWarmup`; registered as `gs_load_gate`), `gs_loading_cover.gd` (the stock cover), `gs_busy_indicator.gd` (`GSBusyIndicator`: bottom-right bar and "may stutter" warning, content-client binding, quota error; `hold_shown` makes the cover draw before heavy work) |
| `profile/` | `gs_hitch_log.gd` (`GSHitchLog`: frame spikes with the systems that ran in them, `frame_measured`, `top_systems`), `gs_frame_cost.gd` (`GSFrameCost`: systems report their per-frame cost; exactly one reader `take()`s per frame). GameSpice Profiler builds on both |
| `tools/idb_probe.sh`, `tools/idb_probe/` | the browser half of `web_selftest`: exports a tiny web page of this addon, writes a burst of `user://` files, closes the tab at once and counts what the next load finds; `old` (engine save only) against `new` (`GSWeb.sync_filesystem`, with the unload flush). `export` needs godot + web templates, `check` needs node + playwright-core + chromium (`PW_CORE`, `CHROMIUM`) |
| `examples/` | `capability_report`, `http_selftest`, `http_server_selftest`, `value_selftest`, `addon_api_selftest`, `dual_transport_selftest`, `randomness_selftest`, `camera_selftest`, `shader_group_arm_selftest`, `render_warmup_bench` (add_items us per material, the item_key grouping parity and the queue coverage against a property-by-property reference), `scheduler_selftest`, `parallel_selftest`, `native_parity_selftest`, `wire_doc_selftest`, `collision_audit_selftest`, `collision_sweep_selftest`, `content_index_selftest`, `load_gate_selftest`, `busy_indicator_selftest`, `parse_all_selftest`, `addon_config_selftest`, `admin_identity_selftest`, `rotation_spec_selftest`, `hitch_log_selftest`, `clip_metrics_selftest`, `web_limits_selftest`, `web_selftest` |

## Running and testing

The family's two steps ([family CLAUDE.md](../../CLAUDE.md#validating-anything)), which gs-ci runs on every push. Then every scene in `examples/`; each selftest exits non-zero on failure. `scheduler_selftest` puts real threads into one job, cancels under a worker and closes a hash job's file under it. `parallel_selftest` checks a pooled run against an inline one slot for slot, that the pool really left the calling thread, and that verify catches an order-dependent task (three verify ERROR lines on stderr are expected). `dual_transport_selftest` runs real WebSocket and ENet clients, a metered client, a query on the shared port, the server's bandwidth, the packet throttle's settings, peer timeouts, a shutdown, and a TLS ClientHello closed by the TCP screen (armed: the same hello with the screen off). **Run `capability_report` on each export target**: it reports whether that build has threads, UDP and a storage quota. A gs-core change touches every consumer: re-run `--import` in projects that link it after adding a `class_name`.

## Rules that bite

- Compare a `Variant` whose type you do not control with `GSValue.same`/`differs`, never `==`/`!=`: a mismatched-type comparison is a runtime error that leaves the condition undefined. [traps](docs/engine-traps.md#-and--are-not-total-dotvalue)
- A `JavaScriptObject` forwards every member access: read `.prop`, call `.method(…)`, never `.get(…)`/`.call(…)`. [traps](docs/engine-traps.md#a-javascriptobject-is-not-an-object)
- A signal emitted from thread-capable code is deferred to the main thread (`GSJob._emit_on_main_thread()`). [traps](docs/engine-traps.md#signals-from-worker-threads-must-be-deferred)
- One thread inside a `GSJob` at a time: steps and settles hold its lock, `cancel()` never tears down another thread's step, a job is submitted once. Never call `FileAccess.eof_reached()` on a file that may be closed: it is a null dereference, not an error. [traps](docs/engine-traps.md#one-job-one-thread-at-a-time-and-eof_reached-is-not-null-checked)
- Ask `GSPlatform` before calling something that is itself the error (`has_unique_id()` before `unique_id()`). [traps](docs/engine-traps.md#some-calls-are-the-damage)
- `GSLog` mirrors only ERROR and above into the engine; never `push_warning` a runtime condition. [traps](docs/engine-traps.md#push_warning-staples-a-backtrace-on)
- Never name `ENetMultiplayerPeer`, `WebRTCMultiplayerPeer` or another template-optional class: reach it through `ClassDB.instantiate` and `Object.call`. [transports](docs/transports.md#where-each-constraint-lives)
- Behind `GSUdpDemux` ENet sees 127.0.0.1: use `GSDualPeer.get_peer_address` for bans, limits and logs. [transports](docs/transports.md#gstransportdual)
- Behind `GSTcpScreen` WebSocket sees 127.0.0.1 too, and its sends are written inside `put_packet`, so a WebSocket send queues one deferred screen flush per frame or every packet leaves a frame late. Auto screens every plain listener, loopback too (a proxied scanner's `GET /` otherwise raises the engine's wsl_peer ERROR): the relay costs ~12 us per busy link per frame. [transports](docs/transports.md#gstransportdual)
- A `GSDualPeer` send to an ENet peer checks it still has channels: ENet emits `peer_disconnected` before dropping a peer, and a second leaver has none. [transports](docs/transports.md#gstransportdual)
- A `GSDualPeer` send to a WebSocket peer checks it is `STATE_OPEN`, broadcasts included: the engine keeps closed peers in its table (and emits `peer_disconnected` before erasing) and its broadcast does not ask. [transports](docs/transports.md#gstransportdual)
- ENet's incoming bandwidth is 0 and its peer timeouts are the transport's (30 s), not ENet's. [transports](docs/transports.md#gstransportdual)
- ENet's packet throttle deceleration is 0 on every peer: stock, a reliable burst over one long frame drops a client's commands and snapshots at the sender. [transports](docs/transports.md#gstransportdual)
- A peer wrapper connects its inner peer's signals to methods, never self-capturing lambdas. [transports](docs/transports.md#gsmeteredpeer)
- Every write to `user://` calls `GSWeb.sync_filesystem()`.
- Add to an addon's API: bump its `LEVEL`. Remove or change: raise `OLDEST` to `LEVEL`. The api file has no `class_name`. [api](docs/addon-api.md#the-rule-for-every-addon)
- A game guarding an addon's newer level names it in `requires.floor.json`, or its pack still asks for the built level and an older host refuses it before the guard runs. [floors](docs/addon-api.md#requiresfloorjson-asking-less-of-an-addon-the-game-guards)
- A seeded draw is a pure function of (key, index); derive streams by name. Splitmix constants are signed decimals, `>>` needs `_unsigned_shift`, and `String.hash()` is not a stable seed. [randomness](docs/randomness.md)
- A camera that is not a player's own eyes goes through `GSCameraProbe` (or `GSCameraBoom`), never `SpringArm3D`; characters are faded by `GSCameraFade`, never collided with; a "never inside" check flies the same path with no probe and requires it to fail. [camera](docs/camera.md)
- A suite that adds a `GSLog` sink removes it before exit: a Callable left in GSLog's static list aborts the process at teardown (heap corruption after "0 failed"). [loading](docs/loading.md#things-that-look-wrong-and-are-not)
- `GSConfig` unknown keys warn, never fail; `sensitive_keys()` blocks environment and argv.
- Set `require_type` on a `GSNodeRef` a host configures by path: a type error at boot beats a null call mid-session.

## Things deliberately not here

- **WebRTC transport.** It ships as an optional GDExtension, so it lives in [GameSpice Peer-to-Peer](../gs-peer-to-peer), which reaches every WebRTC class through `ClassDB.instantiate` so a build without the extension still compiles. `GSPlatform.has_webrtc()` probes for it.
- **DTLS for ENet.** It is configured on `ENetConnection`, not the peer; WebSocket + TLS covers the encrypted case, and no bearer secret goes over ENet.
- **Anything beyond a rotating log file.** That is [GameSpice Log](../gs-log), which registers one sink and owns everything downstream; `GSLogSink` stays here because a project whose only dependency is gs-core still needs a log file.
- **A unit-test framework.** The selftest scenes are the suites; GUT or gdUnit would still be an improvement and has no blockers.

## Open items

- GameSpice Map, GameSpice Vote, GameSpice 2D, GameSpice Team and GameSpice Procedural Generation still draw from their own generators rather than `random/`. [randomness](docs/randomness.md#addons-that-hand-rolled-a-generator)
- `GSYaml` is the family's one YAML subset reader (it refuses anchors, tags and block scalars; quote a value that starts with `*`). `GSRotationSpec` is the one rotation matcher, for GameSpice Map's maps.yml and the server's games.yml: never write a second one.
