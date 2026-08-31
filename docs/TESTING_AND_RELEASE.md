# Testing and Release

Updated: 2026-08-31

## Commands

Run every contract suite from the repository root:

```sh
tests/run_all.sh
```

Set `GODOT_BIN` when Godot is not on `PATH`. The runner falls back to `/Applications/Godot.app/Contents/MacOS/Godot` and stops on the first nonzero result. The current 12 suites cover foundation, movement, camera, level/interaction, combat, inventory, health/game state, guard perception, alert/radar, animation/model replacement, presentation/settings, and integrated release wiring.

Clean import and export-pack checks:

```sh
godot --headless --path . --editor --quit-after 3
tests/run_all.sh
godot --headless --path . --export-pack "macOS" build/ShadowCircuit.pck
```

## Debug and stress tools

- F3 toggles the debug overlay only in debug builds with the development `DebugConfig`. It displays FPS/object counts, room/zone/checkpoint, player stance/speed/noise/control, camera mode/aim/obstruction, alert timers/suspicion, feedback pools, and sanitized G1–G4 state.
- Guard world cones/rays/path and alert/radar telemetry share the same global debug gate. `release_debug_config.tres` disables all of them.
- `presentation_stress_test_room.tscn` emits repeated shots, impacts, alerts, menu cues, damage, doors, pickups, and objectives. `presentation_settings_test.gd` asserts active voices/effects never exceed declared caps and restart leaves zero transient feedback nodes.
- Timing-sensitive AI uses explicit `advance_runtime(delta)` seams and deterministic search points in its owning suites. Navigation-server scheduling and a hands-on full mission remain intentionally nondeterministic/manual.

## Release evidence

- Engine/build: Godot `4.7.stable.official.5b4e0cb0f`, Shadow Circuit `0.1.0`, Compatibility renderer, macOS preset.
- Automated run on 2026-08-31: all 12 suites passed in 4.08 seconds on a MacBook Pro Mac16,8, Apple M4 Pro (12 CPU / 16 GPU cores), 24 GB RAM.
- Export pack: `build/ShadowCircuit.pck` generated successfully from the checked-in preset. Release exclusions remove tests, labs, plans/docs, and progress captures. A full `.dmg` export on this host stops at the documented environment prerequisite because the Godot 4.7 `macos.zip` export template is not installed; the checked-in arm64 texture-compression setting is valid.
- Automated performance evidence proves bounded feedback pools and stable repeated subsystem cycles; it does not substitute for a rendered 60 fps worst-encounter capture.

## Manual release checklist

Record PASS/FAIL, build commit, operator, duration, and evidence for each run:

1. Stealth success playthrough A from `VERTICAL_SLICE.md`, under 10 minutes and never DETECTED.
2. Detected-recovery playthrough B, including ALERT → EVASION → SEARCH and progression during alert.
3. CP1 death/restart playthrough C, checking health, magazine/reserve, ration, K1, D1, objective, guard starts, and NORMAL alert.
4. Keyboard/mouse-only and controller-only traversal of gameplay, both inventory panels, pause/settings, remap conflict, back/resume, death, and completion.
5. 1280×720 minimum target plus ultrawide: no HUD/radar/prompt/menu clipping at text scale 0.8, 1.0, and 1.5.
6. Effects maximum and reduced-motion/flash variants: aim, silhouettes, radar, alert labels, and navigation remain readable.
7. Every camera zone in both directions, first-person near-wall rejection, rapid modal switching, multiple alert cycles, and repeated CP1 restarts.
8. Rendered worst encounter on named hardware sustains the 60 fps target without growing node/resource counts.
9. Exported app launches outside the editor, completes all three playthroughs, and contains no visible debug/test presentation.

Automated status is green. The three canonical hands-on playthroughs, rendered frame-pacing capture, ultrawide inspection, and signed/notarized `.app`/`.dmg` remain manual release-candidate gates rather than silently claimed passes.
