# Code Map

Updated: 2026-08-29

## Runtime entry points

- `project.godot` — project configuration, semantic inputs, autoloads, and collision-layer names.
- `scenes/core/bootstrap.tscn` + `scripts/core/bootstrap.gd` — main entry point, camera-lab bootstrap, and explicit initial-level failure reporting.
- `scenes/actors/player.tscn` + `scripts/actors/player_controller.gd` — reusable capsule player, camera-relative motor, stance/aim semantics, control locks, root-owned combat/health, damage hitbox forwarding, animation outputs, and movement noise.
- `scenes/actors/guard.tscn` + `scripts/actors/guard_actor.gd` — reusable guard body composing navigation, perception, health/damage, explicit local decision states, telegraphed damage requests, alert report/broadcast seams, snapshots, authored reset, and model-independent animation outputs.
- `scripts/visual/actor_visual_adapter_3d.gd` + `scenes/visuals/*.tscn` — semantic player/guard presentation adapter, procedural placeholder poses, stable weapon/muzzle/head/eyes/effect sockets, required/optional animation validation, swappable model payloads, and the original proof-swap guard.
- `docs/MODEL_PIPELINE.md` + `assets/metadata/` — Blender/glTF/import/reimport rules, root-motion decision, clip/material/texture/LOD budgets, socket checklist, and source/license provenance records.
- `scripts/stealth/guard_perception_3d.gd`, `patrol_route_3d.gd`, and `guard_debug_draw_3d.gd` — cone/sample/raycast sight, typed-event hearing, suspicion/memory, patrol wait/look data, and toggleable cones/rays/path/state debug; tuning is `data/guards/default_guard_config.tres`.
- `scenes/components/alert_coordinator.tscn` + `scripts/stealth/alert_coordinator.gd` — sole facility-alert authority, validated/deduplicated position reports, bounded shared knowledge, guard broadcasts, ALERT/EVASION/SEARCH recovery timers, feedback hooks, telemetry, and transient reset.
- `scenes/ui/tactical_radar.tscn` + `scripts/ui/tactical_radar.gd` — player-centered north-up world conversion, approved wall segments, exact/coarse/intermittent guard contacts, cone restrictions, clamp/cull policy, disabled/jammed/hidden non-leakage, and debug telemetry.
- `data/player/default_player_movement_config.tres` — player speed, acceleration, body, slope, gravity, and noise tuning.
- `scenes/camera/gameplay_camera_rig.tscn` + `scripts/camera/gameplay_camera_rig.gd` — sole gameplay-camera owner, deterministic zone handoff/blending, contextual aim, aim rays, obstruction response, impulses, and debug output.
- `scripts/camera/camera_zone_3d.gd` + `camera_zone_data.gd` — authored mathematical camera volumes and reusable framing/priority/blend data.
- `data/camera/default_camera_aim_settings.tres` — mouse/controller look, inversion, limits, FOV, zone hysteresis, and obstruction tuning.
- `scenes/components/weapon_controller.tscn` + `scripts/combat/weapon_controller.gd` — data-driven firearm runtime, explicit equip/fire/reload states, ammo transactions, camera-ray hitscan, owner/wall safety, damage submissions, snapshots, and feedback events.
- `scripts/combat/weapon_definition.gd` + `hit_context_3d.gd` — immutable firearm tuning/display data and the shared typed damage-submission context; W1 data is `data/weapons/w1_service_pistol.tres`.
- `scenes/levels/combat_test_room.tscn` — focused static/moving receiver sandbox with loaded W1, 12 reserve rounds, cover, diagnostics, reticle, and event-driven camera impulse.
- `scenes/components/inventory_component.tscn` + `scripts/inventory/inventory_component.gd` — authoritative entry quantities, capacity transactions, equipment, ammo source, item-effect requests, access checks, display snapshots, and checkpoint composition.
- `scripts/inventory/inventory_entry_definition.gd` + `data/inventory/*.tres` — immutable W1/A1/I1/K1 inventory metadata, ordering, capacities, effect, and access data.
- `scenes/components/inventory_pickup_3d.tscn` + `scenes/ui/inventory_panels.tscn` — success-only partial-capacity pickups and hold-to-select keyboard/controller weapon/item panels.
- `scenes/levels/inventory_test_room.tscn` — focused panel, ration-recipient, transaction, equipment, and snapshot lab.
- `scenes/components/health_component.tscn` + `scripts/health/health_component.gd` — reusable bounded damage/heal receiver with typed context, optional invulnerability, duplicate-death protection, item-effect support, and checkpoint state.
- `scenes/components/mission_state_coordinator.tscn` + `scripts/core/mission_state_coordinator.gd` — stable-ID CP0/CP1 capture/restore, death/restart orchestration, transient reset routing, objective state, and extraction validation.
- `scenes/levels/health_game_state_test_room.tscn` — integrated Build 07 lab over Substation 6 with live health, checkpoint, phase, ration, death/restart, objective, and extraction feedback.
- `scenes/levels/enemy_ai_test_room.tscn` — focused Build 08 occlusion, noise-diversion, suspicion, pursuit/search, combat-telegraph, and debug lab.
- `scenes/levels/camera_aim_test_room.tscn` — focused camera/aim regression lab; `locomotion_test_room.tscn` remains the movement lab and uses the shared rig.
- `scenes/levels/substation_6.tscn` + `scripts/levels/substation_6.gd` — current bootstrap level; seven-room mission graybox, modular collision/occlusion geometry, approved radar segments, ten camera zones, authored navigation, patrol/spawn markers, exact mission-object placements, alert coordination, and tactical-radar binding.
- `scenes/components/interactable_3d.tscn`, `interaction_focus_3d.tscn`, `door_3d.tscn`, and `mission_marker_3d.tscn` — reusable deterministic interaction, hold, door-state, and mission-event seams.
- `scenes/levels/interaction_test_room.tscn` — isolated focus/access/door lab; camera and locomotion labs remain available for subsystem regression.
- `scripts/core/game_state.gd` — explicit mission transition table and sole synchronized pause authority (`GameState` autoload).
- `scripts/core/event_bus.gd` + `noise_event.gd` — typed global noise-routing seam (`EventBus` autoload).
- `data/debug/*.tres` — debug-on development and debug-off release configurations.
- `tests/smoke_test.gd` — headless foundation contract/startup validation.
- `tests/player_movement_test.gd` — player direction, camera-basis, lock, noise, collider, and blocked-uncrouch checks.
- `tests/camera_aim_test.gd` — zone priority/hysteresis, blend/defer behavior, aim gates/locks/limits, center ray, pause, fallback, and camera ownership checks.
- `tests/level_interaction_test.gd` — exact mission budget/IDs, camera coverage, occlusion layers, navigation route/link behavior, deterministic focus, access denial, and graybox progression seams.
- `tests/weapon_combat_test.gd` — definition, state/cadence, aim direction, owner exclusion, near-wall, damage context/death, feedback/noise, dry fire, reload cancellation/transaction, pause, and restore checks.
- `tests/inventory_items_menu_test.gd` — capacities, failures, duplicate/partial pickups, equipment/reload, ration/access, stable ordering, menu locks/repeat, pause/death, and exact snapshot checks.
- `tests/health_game_state_test.gd` — health bounds/invulnerability/death, phase legality, pause consistency, stable-ID snapshots, repeated restarts, transient resets, objective ordering, and extraction checks.
- `tests/enemy_ai_perception_test.gd` — cone/verticality, solid occlusion, step-independent suspicion, crouch range, event hearing, report/state recovery, attack telegraph, death/pause/reset, radar boundary, and exact mission-guard checks.
- `tests/alert_radar_stealth_test.gd` — report validation/deduplication, simultaneous observers, reporter death, sight hold, recovery/reacquisition, pause/reset, shared-information expiry, north-up conversion, contact restrictions/bounds, radar non-leakage, and exact mission integration.
- `tests/animation_model_pipeline_test.gd` — semantic presentation inputs, procedural state readability, stable sockets, optional fallback/required errors, proof model swap, and visual-removal gameplay isolation.
- `docs/VERTICAL_SLICE.md` — authoritative mission flow, placements, tuning, and acceptance scripts.

## Layout

```text
project.godot            # Godot 4.7 project and shared contracts
assets/                 # source-controlled original/licensed content
data/                   # Resource definitions and tuning data
scenes/
  actors/               # player and guards
  components/           # reusable gameplay components
  levels/               # mission and test rooms
  ui/                   # HUD, menus, settings
  visuals/              # replaceable actor visual roots and model payloads
scripts/
  actors/
  camera/
  combat/
  core/
  health/
  interaction/
  inventory/
  stealth/
  ui/
  visual/
tests/                  # headless tests and focused verification scenes
docs/                   # concise cross-agent truth
plans/                  # subsystem ownership briefs
```

## Run, test, and export

From the repository root, with the pinned Godot binary on `PATH`:

```sh
godot --path .
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --export-debug "macOS" build/ShadowCircuit.dmg
```

Use `godot --headless --path . --editor --quit-after 2` for a clean import check. Export requires matching templates. See the root `README.md` for the macOS application-bundle command.

## Recovery Note

Any deleted prototype names found only inside `.godot/` remain generated-cache artifacts and are not dependencies.
