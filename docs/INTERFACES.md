# Subsystem Interfaces

Updated: 2026-08-28

This is the shared contract ledger. Foundation names below are accepted. Agents may refine signatures, but must update all consumers and this file in the same change.

## Accepted Foundation Contracts

### Input

- Movement: `move_left`, `move_right`, `move_forward`, `move_back`.
- First-person look: `look_left`, `look_right`, `look_up`, `look_down`; mouse motion is analog camera input handled by the camera owner.
- Gameplay: `aim`, `fire`, `reload`, `crouch`, `interact`, `weapon_menu`, `item_menu`, `quick_use`, `pause`.
- UI: `ui_accept`, `ui_cancel`, `ui_left`, `ui_right`, `ui_up`, `ui_down`, `ui_focus_next`, `ui_focus_prev`.
- Development only: `debug_toggle`; runtime debug presentation must additionally require `OS.is_debug_build()` and an enabled debug resource.
- Gameplay code reads actions, not raw keys/buttons. Defaults in `project.godot` cover keyboard/mouse and a standard controller. The authoritative mode behavior is in `VERTICAL_SLICE.md`.

### Pause and global services

- `GameState` is the sole pause/mission-phase authority. `set_paused(bool)` updates `SceneTree.paused`, emits `pause_changed(bool)`, and transitions the public `MissionPhase` enum.
- Always-interactive menu roots use `PROCESS_MODE_ALWAYS`; gameplay remains pausable/inheritable.
- `EventBus.emit_noise(NoiseEvent3D)` emits `noise_emitted(event)`. `NoiseEvent3D` contains source, world position, nonnegative loudness, and category. Perception consumes the signal; producers do not locate guards.
- No settings autoload exists yet. Build Step 12 may add one when persistence has a real consumer.

### Collision layers and query masks

| Layer | Name | Ownership/use |
|---:|---|---|
| 1 | `world` | Solid authored environment; character bodies query it. |
| 2 | `player_body` | Player physical body. |
| 3 | `enemy_body` | Guard physical bodies. |
| 4 | `damageable_hitbox` | Query-only hurtboxes for player/guards/targets. |
| 5 | `interaction_query` | Query-only interactable targets. |
| 6 | `perception_blocker` | Opaque sight blockers; solid walls normally occupy layers 1 and 6. |
| 7 | `pickup` | Query-only pickup targets. |

Canonical masks: player body `1|3`, enemy body `1|2`, hitscan `1|4`, interaction focus `5|7`, and perception ray `4|6`. Query-only targets use mask 0 unless their subsystem documents a deliberate overlap requirement.

### Groups and resource identity

- `player` is the only global group with a current consumer. Add `guards`, `damageable`, `interactable`, `camera_zones`, or `checkpoint_targets` with the first real consumer rather than speculatively.
- Commit Godot-generated `.uid` sidecars for source scripts/resources. Do not hand-author, copy, or renumber UIDs; resolve moves through the editor or update all path consumers in the same change.

### Player movement

- Entry point: `scenes/actors/player.tscn`; root type is `PlayerController` (`CharacterBody3D`) on layer 2 with mask `1|3`.
- Camera owners call `set_camera_basis(Basis)`. A basis is latched from movement start until the stick/keys return to neutral, so a fixed-camera transition cannot reverse held input.
- Modal owners call `set_control_lock(PlayerController.ControlLock.*, bool)` for `MENU`, `DEATH`, `SCRIPTED`, or `AIM`; locks compose and any active lock immediately clears planar velocity. `set_control_enabled(bool)` is the simple external gate.
- Stance owners call `request_crouch(bool)` or `request_stance(Stance)` and inspect the returned success value. Standing is rejected when a shape query finds insufficient clearance.
- Public state is inherited `velocity` plus `facing_direction`, `grounded`, `stance`, `speed_ratio`, `movement_noise_intensity`, and `control_enabled`.
- Signals are `stance_changed`, `control_enabled_changed`, `movement_noise_changed`, `movement_noise_emitted(NoiseEvent3D)`, and model-independent `animation_parameters_updated(local_planar_velocity, speed_ratio, grounded, stance)`.
- Movement noise is normalized from actual grounded planar speed, stance, and `surface_noise_multiplier`; periodic events use category `player_movement` and also route through `/root/EventBus` when present.
- Default capsule is radius 0.4 m, 1.8 m standing and 1.2 m crouched. Default speed/acceleration/deceleration/turn are 4.5 m/s standing, 2.6 m/s crouched, 24/30 m/s², and 720°/s in `data/player/default_player_movement_config.tres`.

### Camera and first-person aim

- Entry point: `scenes/camera/gameplay_camera_rig.tscn`; `GameplayCameraRig` owns the only current gameplay `Camera3D`. Call `set_tracked_actor(Node3D)` after instantiation and `reset_camera_state()` after a checkpoint/scene reset.
- `CameraZone3D` nodes use `CameraZoneData` resources with `zone_id`, priority, blend duration, mathematical volume size, aim allowance, camera/look offsets, tracking extents, and FOV. Highest priority wins; the current zone wins equal-priority overlap; otherwise lexical `zone_id` is the stable tie-break. The latest zone is deferred while aiming.
- Equipment calls `set_weapon_equipped(bool)`. Modal and interaction owners call `set_modal_active(bool)` and `set_interaction_active(bool)`; either exits aim. `request_aim(bool)` returns success and rejects entry with a public reason when no weapon is equipped, the zone disallows aim, a modal/interaction is active, or the forward near-wall check is blocked.
- `CameraMode` is `EXPLORATION` or `AIM`. Entering aim calls the player's `set_aim_movement_locked(true)`, preserves stance, captures entry facing, and clamps yaw to ±70° and pitch to -45°/+35° by default. Exit unlocks only the aim reason, restores the exploration camera, and applies the latest deferred zone.
- Weapons call `get_aim_origin()`, `get_aim_direction()`, or `get_aim_ray(max_distance)`. The ray dictionary has `origin`, normalized `direction`, and `end`; `query_aim_hit(max_distance, collision_mask)` is optional convenience, and weapons should pass the canonical hitscan mask `1|4`.
- Public state/signals are `mode`, `active_zone`, `is_transitioning`, `aim_is_obstructed`, `mode_changed`, `active_zone_changed`, `transition_state_changed`, `aim_rejected`, `aim_obstruction_changed`, and `reticle_visibility_requested`. Other systems may drive `add_camera_impulse(...)` but never set `Camera3D.current`.
- `CameraAimSettings` owns `exploration_fov`, `aim_fov`, `aim_near_plane`, mouse/controller sensitivity, controller dead zone, horizontal/vertical inversion, yaw/pitch limits, near-wall distance, minimum zone hold, obstruction margin, and minimum camera distance. Build Step 12 may persist/modify this resource through a settings service without changing the rig API.
- Authored angles are the primary obstruction solution. Runtime exploration rays may pull the camera toward its look target; first-person entry rejects a blocked origin and active aim reports near obstruction. No automatic transparency/cutaway policy exists.

### Weapons and combat

- Entry point: the player's `WeaponController` child from `scenes/components/weapon_controller.tscn`; the focused lab is `scenes/levels/combat_test_room.tscn`. W1 tuning lives in `data/weapons/w1_service_pistol.tres` as a `WeaponDefinition`, separate from runtime magazine/state.
- `WeaponDefinition` fields are weapon/display IDs, description/icon, damage, maximum range, fire interval, spread, damage tags, magazine capacity, ammo type, equip/reload duration, automatic flag, feedback IDs, gunshot loudness, and camera-impulse suggestion. Adding another definition does not change firing code.
- Runtime states are `HOLSTERED`, `EQUIPPING`, `READY`, `FIRING_COOLDOWN`, `RELOADING`, and `DISABLED`. External owners call `request_equip(definition, initial_magazine)`, `request_unequip`, `request_fire`, `request_reload`, `set_disabled`, `set_control_enabled`, `set_combat_owner`, `set_aim_provider`, and `set_ammo_source`.
- Player fire requires `READY`, active control, an unpaused tree, and the camera provider's AIM mode. The shot starts from the provider's public `get_aim_ray`, uses canonical mask `1|4`, recursively excludes the owner's collision objects, and first checks the world-only segment from aim origin to the authored muzzle. W1 has zero silent aim steering; its direction exactly matches the camera ray.
- Ammo sources expose `get_ammo_count(ammo_type) -> int` and `take_ammo(ammo_type, requested) -> int`. Reload checks availability on entry but calls `take_ammo` only on completion; cancellation never consumes reserve. `get_runtime_snapshot`/`restore_runtime` transfer weapon ID, magazine, and equipped state without restoring transient cooldown/reload time.
- `HitContext3D` contains instigator, weapon ID, monotonically increasing shot ID, hit position/normal, normalized direction, nonnegative damage, damage tags, and collider. A collider or ancestor is compliant when it exposes `receive_damage(amount, context)`; the weapon never mutates health fields.
- Public signals are `state_changed`, `equipped_changed`, `ammo_state_changed`, `shot_fired`, `dry_fired`, `reload_started`, `reload_completed`, `reload_cancelled`, `impact_resolved`, `damage_submitted`, and `feedback_requested`. Feedback payloads are presentation requests; listeners own animation, audio, VFX, camera impulse, vibration, and UI.
- Successful W1 shots emit one `NoiseEvent3D` through `EventBus` with category `gunshot` and loudness 30. The temporary `GrayboxMissionHarness` implements W1/A1 equip/reserve behavior only until Build 06 supplies the accepted inventory owner.

### Level and interaction

- Mission entry point: `scenes/levels/substation_6.tscn`. Runtime room nodes expose the exact `R0_DRAINAGE`–`R6_CONTROL` IDs through the `mission_rooms` group and `room_id` metadata; `room_volumes` emit room entry without owning global mission state.
- `Interactable3D` exposes `interaction_id`, `get_prompt(actor)`, `is_available(actor)`, `get_unavailable_reason(actor)`, `get_interaction_priority()`, `get_world_anchor()`, `hold_duration`, and `interact(actor)`. Optional callables supply availability, reason, and prompt decisions without coupling the component to inventory.
- `InteractionFocus3D` queries only layers 5 and 7 inside 2.0 m. It resolves overlap by priority descending, anchor distance ascending, then lexical interaction ID; hold interactions emit normalized progress and apply only the player's `SCRIPTED` lock plus the camera interaction gate.
- `Door3D` owns open/closed/locked state. `set_access_query(Callable)` supplies an external `(actor, access_level) -> bool` decision; `set_locked`/`set_open` synchronize visible state, world/perception collision, and the doorway `NavigationLink3D`. Locked interactions expose their reason rather than silently failing.
- `MissionMarker3D` emits `mission_event(event_id, actor, payload)` for the placed pickup, objective, and extraction IDs. `MissionTrigger3D` emits checkpoint/room events. The level does not mutate inventory or complete mission phases.
- `GrayboxMissionHarness` is a replaceable integration aid, not the accepted inventory/checkpoint implementation. It demonstrates K1 access, W1 aim enablement, objective-to-D2, and extraction availability solely through the public queries/events; Builds 06–07 replace it without changing level geometry.
- Navigation uses edge-connected authored regions expanded for the 0.4 m player/guard radius, subtracts cover footprints with 0.48 m clearance, and splits every door corridor across a link. Closed doors occupy layers 1 and 6 and disable their link; open doors clear both effects. `Substation6.get_mission_navigation_map()` exposes the shared map RID for route validation.

## Accepted Subsystem Boundaries

- Player movement exposes velocity, stance, movement-noise level, control-enabled state, and aim-mode requests.
- Camera owns the active view mode and exposes aim origin/direction through `GameplayCameraRig`; weapons do not inspect camera node paths.
- Interaction targets expose prompt text, availability, and an `interact(actor)` operation.
- Damage receivers accept a value plus hit context and emit health/death changes.
- Inventory owns quantities and equipment state and emits change signals; UI never mutates its dictionaries directly.
- Weapons consume inventory ammunition through a narrow inventory API and submit hits through the damage contract.
- Perception consumes observable target position, stance/visibility modifiers, and emitted noise events.
- Guards report local suspicion/detection to the alert coordinator; they do not directly control the radar or global UI.
- Alert coordinator exposes a single authoritative phase and phase changes.
- Radar reads public guard/perception snapshots and alert restrictions; it never reaches into guard state-machine internals.
- Game-state/checkpoint service owns mission phase, pause/death transitions, and checkpoint snapshots.

## Contract Change Rule

Before breaking a shared contract, record the reason in `DECISIONS.md`, identify every consumer in `CODE_MAP.md`, and coordinate the change in `STATUS.md`/`HANDOFF.md`.
