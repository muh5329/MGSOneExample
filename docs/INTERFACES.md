# Subsystem Interfaces

Updated: 2026-08-29

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

- `GameState` is the sole pause/mission-phase authority. `set_paused(bool) -> bool` atomically updates `SceneTree.paused`, emits `pause_changed(bool)`, and transitions the public `MissionPhase` enum; direct `set_phase(PAUSED)` calls are rejected so phase and tree pause cannot diverge.
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

- `player` identifies the player. Restart consumers use `checkpoint_reset_targets` for nodes exposing `reset_transient_state(checkpoint_id)` and `checkpoint_disposable` for ephemeral nodes removed on restart; later guards/alerts register only when implemented.
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
- Successful W1 shots emit one `NoiseEvent3D` through `EventBus` with category `gunshot` and loudness 30. `InventoryComponent` is the accepted W1 equipment and A1 reserve source through the unchanged ammo transaction boundary.

### Inventory, items, and equipment panels

- Entry point: the player's `Inventory` child from `scenes/components/inventory_component.tscn`; focused lab: `scenes/levels/inventory_test_room.tscn`. Immutable W1/A1/I1/K1 definitions in `data/inventory/` provide stable ID, label, kind/panel, order, maximum quantity, selectable state, and weapon/ammo/effect/access references.
- `InventoryComponent.TransactionCode` is `SUCCESS`, `PARTIAL`, `INVALID_REQUEST`, `UNKNOWN_ENTRY`, `CAPACITY_REACHED`, `NOT_OWNED`, `NOT_SELECTABLE`, `CONTROL_LOCKED`, `RECIPIENT_UNAVAILABLE`, `EFFECT_REJECTED`, or `SNAPSHOT_INVALID`. Every request returns a copied result dictionary with `code`, `accepted`, `entry_id`, `requested`, `changed`, `current`, and visible `reason`.
- Quantity API is `add_entry`, `remove_entry`, `get_count`, `has_entry`, `get_remaining_capacity`, and `can_add`. W1 capacity is 1, A1 reserve capacity 24, I1 capacity 1, and persistent K1 capacity 1. Values clamp without becoming negative; a partial pickup retains its unaccepted world quantity and a rejected pickup remains untouched.
- Equipment API is `request_equip_weapon`, `request_unequip_weapon`, `request_equip_item`, and `request_quick_use(recipient)`. Equipment IDs are cleared if their quantity reaches zero. Inventory supplies `get_ammo_count`/`take_ammo` to combat but does not own the equipped weapon's magazine or timing state.
- Item recipients expose `can_receive_item_effect(effect_id, amount) -> bool` optionally and `receive_item_effect(effect_id, amount, context) -> bool` necessarily. I1 requests `heal` for 50; inventory consumes it only after the recipient accepts, and reports `FULL_HEALTH` without doing health arithmetic itself. `has_access_level(LEVEL_1)` is the shared non-consuming K1 door query.
- Read-only display methods are `get_selection_snapshot(panel)` and `get_display_snapshot`; definitions remain in order at zero quantity. Signals are `transaction_completed`, `inventory_changed`, `equipped_weapon_changed`, `equipped_item_changed`, `item_use_requested`, and `item_used`.
- `get_checkpoint_snapshot` contains `quantities`, `equipped_weapon_id`, `equipped_item_id`, and the combat-owned `weapon_runtime`; `restore_checkpoint_snapshot` validates the entire payload before mutation. Build 07 owns when these snapshots are captured/restored.
- `InventoryPanels` opens while Q/LB or E/RB is held, uses `ui_up`/`ui_down` with deterministic held repeat, commits selection on release, and quick-uses with G/Y. An open panel exits aim, sets only the player `MENU` lock, cancels reload through the weapon control gate, disables interaction input, and restores those gates on close. Pause/death/completion/restart close without committing; panels do not pause the world or mutate quantities.

### Health, mission phases, checkpoints, and outcome

- Entry points are `HealthComponent` in `scenes/components/health_component.tscn`, the player's `%Health` child/damage hitbox, and `MissionStateCoordinator` in `scenes/components/mission_state_coordinator.tscn`. The integrated lab is `scenes/levels/health_game_state_test_room.tscn`.
- `HealthComponent` exposes `maximum_health`, `current_health`, `is_dead`, `damage_enabled`, and `invulnerability_remaining`. `receive_damage(amount, HitContext3D)`, `heal(amount, source)`, `can_receive_item_effect`, and `receive_item_effect` return success without mutating invalid, invulnerable, full-health, or dead targets. Lethal state is committed before observers run, and `died` emits once per life.
- Health signals are `health_changed(previous, current, maximum)`, `damaged(applied, context)`, `healed(applied, source)`, `died(context)`, `revived(current, maximum)`, and `invulnerability_changed(active, remaining)`. `get_checkpoint_snapshot(force_full_health)`, `validate_checkpoint_snapshot`, and `restore_checkpoint_snapshot` are the stable health boundary.
- The player forwards `receive_damage`, `can_receive_item_effect`, and `receive_item_effect` to `%Health`; hitscan finds that receiver by walking from the layer-4 `DamageHitbox` to the player root. I1 heals 50 through the same item-effect seam and is not consumed on rejection.
- `GameState.MissionPhase` transitions are explicit: `INITIALIZING → PLAYING`; `PLAYING → PAUSED | PLAYER_DEAD | COMPLETED`; `PAUSED → PLAYING` only through `set_paused(false)`; `PLAYER_DEAD → RESTARTING`; and `RESTARTING → PLAYING` or `PLAYER_DEAD` on a failed restore. `COMPLETED` is terminal until `reset_for_new_mission`. Invalid requests return false and emit `transition_rejected(current, requested, reason)`.
- The mission coordinator registers unique marker, checkpoint, door, and pickup IDs. CP0 is `CP0_INSERTION`; CP1 is `CP1_SWITCH_ENTRY` and activates only after D1 is unlocked. Duplicate/missing IDs and invalid payloads emit `snapshot_failure(checkpoint_id, subsystem, stable_id, reason)`.
- Snapshot version 1 contains `checkpoint_id`, player `Transform3D` and stance, a full-health restart snapshot, the inventory/equipment/weapon-runtime snapshot, objective completion/consumption, all registered door and pickup states keyed by stable ID, and transient policy `RESET_TO_AUTHORED_STATE`. CP captures are in-memory only; CP1 records the first valid crossing and repeated activation does not overwrite it.
- Restore validates the complete payload before mutation, enters `RESTARTING`, emits `transient_reset_requested`, resets `checkpoint_reset_targets`, removes `checkpoint_disposable` nodes, restores objective → doors → pickups → inventory/weapon → player transform/stance/health → camera, enters `PLAYING`, and then releases terminal controls. UI panels close without committing; aim/reload are cancelled; future guards and alerts must reset to authored patrol/NORMAL through the transient contract.
- Player death enters `PLAYER_DEAD` once, exits pause if necessary, applies the `DEATH` movement lock, disables combat/inventory/interaction, and automatically requests restart after 1.5 seconds. Snapshot validation failure leaves the player dead and reports the exact subsystem/ID rather than partially restoring.
- O1 completion and X1 extraction are separate. O1 succeeds only during `PLAYING` while alive and opens D2; X1 rejects until O1 is complete. Successful extraction enters `COMPLETED`, disables further player damage and controls, and emits `mission_completed` once.
- Persistence exclusions are deliberate: no disk save, campaign state, mid-checkpoint health deficit, transient cooldown/reload time, alert/suspicion, projectiles/effects, or live guard state is serialized. Guards/alerts own their authored reset implementation in Builds 08–09.

### Level and interaction

- Mission entry point: `scenes/levels/substation_6.tscn`. Runtime room nodes expose the exact `R0_DRAINAGE`–`R6_CONTROL` IDs through the `mission_rooms` group and `room_id` metadata; `room_volumes` emit room entry without owning global mission state.
- `Interactable3D` exposes `interaction_id`, `get_prompt(actor)`, `is_available(actor)`, `get_unavailable_reason(actor)`, `get_interaction_priority()`, `get_world_anchor()`, `hold_duration`, and `interact(actor)`. Optional callables supply availability, reason, and prompt decisions without coupling the component to inventory.
- `InteractionFocus3D` queries only layers 5 and 7 inside 2.0 m. It resolves overlap by priority descending, anchor distance ascending, then lexical interaction ID; hold interactions emit normalized progress and apply only the player's `SCRIPTED` lock plus the camera interaction gate.
- `Door3D` owns open/closed/locked state. `set_access_query(Callable)` supplies an external `(actor, access_level) -> bool` decision; `set_locked`/`set_open` synchronize visible state, world/perception collision, and the doorway `NavigationLink3D`. Locked interactions expose their reason rather than silently failing.
- `MissionMarker3D` emits `mission_event(event_id, actor, payload)` for the placed pickup, objective, and extraction IDs. `MissionTrigger3D` emits checkpoint/room events. The level does not mutate inventory or complete mission phases.
- `MissionStateCoordinator` is the production objective/checkpoint/extraction owner. The former `GrayboxMissionHarness` script is retained only as an unused historical lab aid; Substation 6 no longer instantiates it.
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
