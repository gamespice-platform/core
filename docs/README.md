# GameSpice Core docs

| File | Subject |
| --- | --- |
| [engine-traps.md](engine-traps.md) | `GSValue`, `JavaScriptObject`, worker-thread signals, one thread per job and `eof_reached()`, `unique_id`, why `GSLog` mirrors only ERROR, the `HTTPRequest` resume bug |
| [transports.md](transports.md) | Platform constraints, `GSTransportDual` and the UDP demux, the ENet fixes, `GSMeteredPeer`, `GSHttp` |
| [http-server.md](http-server.md) | `GSHttpServer`: what it is and is not, limits and status codes, routes, static files, TLS, secrets |
| [addon-api.md](addon-api.md) | `GSAddonApi`, the per-addon `LEVEL`/`OLDEST` rule, `requires.json` |
| [randomness.md](randomness.md) | `random/`: the (key, index) idea, the mixer's three traps, who still hand-rolls a generator |
| [camera.md](camera.md) | `camera/`: why not `SpringArm3D`, the look-ahead sweep, fading people instead of colliding with them, the armed check |
| [loading.md](loading.md) | `loading/`: `GSLoadGate` (holds, requirements, freezing, the timeout), who covers the screen, `GSLoadingCover`, older shells |
| [addon-config.md](addon-config.md) | `GSAddonConfig`: `cfg/addon/<addon>/*.yml`, the roots, the layers, secrets |
| [gs-profile-split.md](gs-profile-split.md) | Done at API level 22: the profile classes moved to the GameSpice Profile addon, class names kept; what was skipped and why |
| [profile.md](profile.md) | `profile/`: `GSHitchLog`, naming a lag spike from the frame split and counters |
| [native-twins.md](native-twins.md) | `GSNativeParity`: shipping a native twin behind a script original, the parity suite, skips and `GS_NATIVE_REQUIRED` |
