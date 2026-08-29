# Decision Log

Keep only decisions that affect more than one subsystem. Newest entries first.

## 2026-08-29 — Health, Checkpoint, and Mission Authority

- `HealthComponent` is the reusable damage/heal authority; lethal state commits before signals, death emits once per life, and the player forwards combat and item-effect requests without duplicating health arithmetic.
- `GameState` enforces the only legal mission-phase table and synchronizes pause with `SceneTree.paused`; mission owners request death, restart, and completion rather than directly assigning phases.
- Checkpoints are validated versioned dictionaries keyed by authored IDs, never node-path serialization. CP health intentionally normalizes to full for restart; inventory/equipment/weapon magazine, K1, door, pickup, and objective state persist exactly.
- Restart validates before mutation, resets transient group consumers, restores persistent subsystem-owned snapshots in documented order, resets camera/UI/combat gates, then returns to play. Builds 08–09 must register guard/alert authored resets rather than expanding the snapshot with live AI internals.
- O1 completion and X1 extraction remain distinct, with alive/PLAYING gates and terminal duplicate protection. No disk saves, live alert/guard state, or transient projectiles/effects are in Build 07 scope.

## 2026-08-28 — Inventory and Equipment Integration Contract

- Per-player `InventoryComponent` is the single authority for registered quantities and equipped entry IDs; immutable definitions preserve selection order even at zero quantity. Weapon magazine/timers remain combat-owned and are composed into inventory checkpoint snapshots rather than duplicated.
- Pickups transact before changing world state, retain any partial-capacity remainder, and emit mission compatibility events only for accepted quantities. K1 is a non-consuming access query and I1 consumes only after an explicitly supplied effect recipient accepts healing.
- Hold panels are presentation/request clients: opening exits aim and applies only the `MENU`/weapon/interaction gates; releasing commits selection, while cancel, pause, death, completion, and restart close without committing.
- Build 07 owns production health and snapshot timing through the accepted item-effect and inventory snapshot interfaces; Build 12 may replace the panel visuals without changing transaction authority or controls.

## 2026-08-28 — Weapons and Combat Integration Contract

- `WeaponDefinition` resources are immutable tuning/display inputs; `WeaponController` alone owns per-instance magazine, timed state, shot sequence, and checkpoint snapshot state.
- Reloading uses the narrow `get_ammo_count`/`take_ammo` transaction boundary and consumes reserve only when the reload completes. Equipment changes, control loss, pause, and checkpoint restore cancel without speculative consumption.
- Player hitscan uses the camera-owned aim ray, canonical layers 1/4, recursive owner exclusion, and a separate world-only aim-origin-to-muzzle clearance query. Damage is submitted only through `receive_damage(amount, HitContext3D)`.
- Combat presentation is event-driven through definition-owned feedback IDs; the weapon does not locate HUD, audio, animation, VFX, vibration, or camera nodes. Gunshots additionally publish typed global noise.
- The graybox harness temporarily supplies W1/A1 transactions only to prove mission integration. Build 06 replaces that source through the same ammo interface, and Build 07 adopts the hit-context receiver contract.

## 2026-08-28 — Level and Interaction Integration Contract

- Substation 6 keeps the locked seven-room topology and exact content budget. Primitive room shells, cover footprints, camera zones, navigation surfaces, patrol markers, and mission placements are generated from one typed level owner so collision and scale do not drift from presentation.
- Interaction decisions are injected through callables and events: the level never reads inventory dictionaries or completes mission phases. The temporary graybox harness proves the route and is explicitly replaceable by Builds 06–07.
- Doors are the single state authority for their panel, layers 1/6 collision, and navigation link. Camera handoffs cover every connection and stay centered on authored opaque thresholds.
- Navigation is authored as cover-subtracted walkable polygons with door gaps, not inferred from visible meshes. Future art may replace visuals but must preserve documented pivots, collision footprints, 4.0 m openings, and sightlines.

## 2026-08-28 — Camera and Aim Integration Contract

- One `GameplayCameraRig` owns the current gameplay camera. Authored mathematical volumes select by priority, preserve the current equal-priority overlap, and use lexical zone ID only as a final deterministic tie-break.
- First-person aim is contextual and rooted: equipment/modal/interaction owners provide narrow gates, the camera sets only the player's AIM lock, and zone changes wait until aim exits.
- Weapons consume camera-owned origin/direction APIs rather than camera node paths. Settings are resource-backed now and may gain persistence later without changing this boundary.
- Level-authored angles and occluded handoffs are the first obstruction solution; runtime pull-in and near-wall rejection are safety nets, not replacements for valid mission framing.

## 2026-08-28 — Player Movement Integration Contract

- Camera-relative direction latches the supplied camera basis while movement input remains held; camera transitions affect the next input gesture after neutral, avoiding an involuntary reversal.
- Movement locks are a composable bitmask owned by the player motor. Aim, menus, death, and scripted consumers set and clear only their own reason.
- Hearing receives normalized, periodic `NoiseEvent3D` events derived from actual grounded speed, stance, and a surface multiplier; input presses alone never produce noise.
- Player body origin stays at the feet with a 0.4 m capsule radius, 1.8 m standing height, and 1.2 m crouched height so level and camera owners can author consistent clearances.

## 2026-08-28 — Vertical Slice Locked

- The authoritative mission is the seven-room `Substation 6` route in `VERTICAL_SLICE.md`, with four guards, one pistol, one ration, one access level, ten camera zones, and two checkpoints.
- First-person aim roots translation; it allows bounded look, defers camera-zone transitions, and exits for modal UI.
- Detection is recoverable: the global sequence is ALERT → EVASION → SEARCH → NORMAL, and alerts never lock progression.
- Access card, unlocked security door, completed objective, and inventory are checkpoint state; transient alert/guard suspicion resets.

## 2026-08-28 — Foundation Contracts Pinned

- Pin engine version `4.7.stable.official.5b4e0cb0f`, Compatibility renderer, 60 Hz physics, 1280×720 reference viewport, and a 60 fps desktop target.
- Use only two initial autoloads: `GameState` for global mission/pause authority and `EventBus` for typed noise routing. Settings waits for a persistence consumer.
- Canonical input names and seven 3D collision layers live in `project.godot` and are published in `INTERFACES.md`.
- Debug presentation requires both a debug build and an enabled `DebugConfig`; release configuration defaults off.
- Commit engine-generated `.uid` sidecars, never `.godot/`; do not manually invent or transplant resource UIDs.

## 2026-08-28 — Greenfield Recovery

- Treat the current workspace as greenfield because only generated `.godot` cache files remain.
- Target Godot 4.x; the foundation owner pins the exact engine version.
- Use primitive graybox art first and keep visual replacement independent of game logic.
- Use typed GDScript and signal/interface boundaries by default.
- Require keyboard/mouse and controller support for the vertical slice.
- Maintain original/licensed content for any distributed build; references guide mechanics and mood only.
