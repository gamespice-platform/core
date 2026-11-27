[![Core - GameSpice addon](docs/banner.png)](https://moddingcommunity.com/a/24-gs-core)

The shared foundation of the [GameSpice](https://github.com/gamespice-platform) family for Godot 4.7+. It holds the small pieces every other addon needs: results and errors, logging, configuration, platform checks, paths, hashing, an HTTP client, a transport layer, reproducible randomness and a loading gate. It is the layer under [GameSpice Server](https://github.com/gamespice-platform/server), [GameSpice Auth](https://github.com/gamespice-platform/auth) and [GameSpice Cloud](https://github.com/gamespice-platform/cloud).

This is the base GameSpice addon, MIT licensed and built with Claude Code. It has headless tests under `examples/`, such as `capability_report` and `randomness_selftest`. Every game in [Zee's Games](https://zeesgames.com) is built on it and runs on live servers.

It targets desktop (Windows, macOS, Linux), mobile (Android, iOS) and the web from one codebase. Browser limits are handled in the code, not hidden.

## Install

1. Copy `addons/gs_core/` into your project.
2. Enable gs-core in *Project > Project Settings > Plugins*.
3. Run `godot --headless --path . --import` once so the `GS*` classes register.

The plugin only registers inspector types. Every class is available by its `class_name` whether the plugin is enabled or not. Starting a new game? Begin from [GameSpice Game Template](https://github.com/gamespice-platform/game-template).

## First steps

1. Return failures as a `GSResult` and branch on its `GSError.CODE_*`, never on the message.
2. Log through `GSLog`, with a `CHANNEL` constant per file.
3. Run the example scene under [Test](#test) on every platform you ship to.

## What is in it

| Class | What it does |
| --- | --- |
| `GSResult`, `GSError` | The return type of everything that can fail. `CODE_*` values are stable. Reading `.value` on a failure raises an error instead of returning a default. |
| `GSPlatform` | Cached checks for threads, UDP, listening, pack mounting and storage. Ask about capabilities, not platform names. |
| `GSNodeRef` | An inspector-editable description of which node: relative, absolute, group, registry, ancestor or descendant by type, or create if missing. Replaces hardcoded scene paths. |
| `GSConfig` | Layered configuration with key discovery and protection for secret keys. |
| `GSScheduler`, `GSJob` | Long work in slices. Worker threads where they exist, a per-frame time budget where they do not. |
| `GSTransport` | Swappable multiplayer transport. WebSocket serves browser and native clients from one listener. ENet is lighter but does not work in browsers. `GSTransportAuto` picks one and logs why. |
| `GSHttp` | An `HTTPRequest` client with retries, jittered backoff, `Retry-After`, resumable downloads and connection pooling. Works in the browser. |
| `GSLog`, `GSLogSink` | Levelled, channelled logging with structured fields, rotating files and UDP forwarding. [GameSpice Log](https://github.com/gamespice-platform/log) adds more sinks. |
| `GSPaths` | Path cleaning that refuses traversal instead of repairing it, atomic writes and web filesystem flushing. |
| `GSHash` | SHA-256, HMAC, constant-time comparison, base64url and secure random tokens. |
| `GSRandomStream` and related | Randomness another machine can reproduce. A draw depends only on a key and an index, so peers that draw in a different order still agree. `GSRandomTable` does weighted picks, `GSRandomSchedule` does events in ticks, and `GSRandomManager` hands out named streams. See [docs/randomness.md](docs/randomness.md). |
| `GSLoadGate`, `GSLoadingCover` | Holds the screen until the game is ready to be seen. See [docs/loading.md](docs/loading.md). |

`GSLog` mirrors only ERROR and above into Godot's own output (`mirror_min_level`). A debug build adds a backtrace to every mirrored line, and a recoverable warning would then look like a crash.

## Configuration layers

Every addon reads settings in the same order, weakest first:

| Layer | Where |
| --- | --- |
| Addon defaults | The addon's schema, then `cfg/addon/<addon>/` |
| Game | `cfg/game/<game>/<addon>/` |
| Server operator | `cfg/server/addon/<addon>/`, then `cfg/server/game/<game>/<addon>/` |
| Environment | `GS_*` variables |
| Command line | `--flag` arguments |
| Runtime | For example a console `set` |

The folder name is the addon name with `-` written as `_`. Secrets are read from files only. A key marked sensitive is refused from the environment and the command line. Add `cfg/*` to your export preset's `include_filter`, or the files are missing from exported builds. See [docs/addon-config.md](docs/addon-config.md).

## Design notes

| Rule | Why |
| --- | --- |
| No autoloads. | An autoload reserves a global name, fixes the start order and cannot be created twice. Use `GSRegistry` for lookup and place nodes yourself. |
| No hardcoded scene paths. | Anything that needs a host node exports a `GSNodeRef`. |
| Browser limits are real. | There is no UDP, no `HTTPClient`, no threads by default, the filesystem needs explicit flushes, and a resource pack cannot be unmounted. See [docs/transports.md](docs/transports.md#where-each-constraint-lives). |

More notes are in the [docs index](docs/README.md).

## Test

```bash
godot --headless --path . --import
godot --headless --path . res://examples/capability_report.tscn
godot --headless --path . res://examples/randomness_selftest.tscn
```

Worker caps are settings: `GSParallel.auto_max` (default 8, 0 = unlimited) and `GSScheduler.auto_thread_max` (default 4, 0 = unlimited); negatives are refused with an error.

The first scene prints what the build can do. The second checks the randomness code. Both run offline. The capability report shows quickly that a web export has no threads or that a device reports no storage quota, which changes how gs-cloud behaves. The `examples/` folder holds more self-tests.

## Used by

Every game in the collection vendors it, since every other addon sits on top of it:

- [Fatal Contact](https://zeesgames.com/fatal-contact)
- [Airdrift](https://zeesgames.com/airdrift)
- [Playlot](https://zeesgames.com/playlot)
- [Hungario](https://zeesgames.com/hungario)
- [Buses From Hell](https://zeesgames.com/buses-from-hell)
- [Smash Copter](https://zeesgames.com/smash-copter)
- [Zombie Zone](https://zeesgames.com/zombie-zone)
- [Hide n Seek](https://zeesgames.com/hide-n-seek)
- [Prop Hunt](https://zeesgames.com/prop-hunt)
- [Murder Mystery](https://zeesgames.com/murder-mystery)
- [Deathrun](https://zeesgames.com/deathrun)
- [Wipeout](https://zeesgames.com/wipeout)
- [Dangerous Delivery](https://zeesgames.com/dangerous-delivery)
- [Look At Me](https://zeesgames.com/look-at-me)

The whole collection is at [zeesgames.com](https://zeesgames.com).

## Licence

MIT. See [LICENSE](LICENSE). Only the TMC back-end web infrastructure is not open source.
