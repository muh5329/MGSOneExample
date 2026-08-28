# Build Step 05 — Weapons and Combat

## Assignment

One agent/chat owns weapon definitions, equip/use behavior, firing, ammunition requests, hit resolution, impact events, and combat test targets. It consumes camera, inventory, and damage contracts.

## Objective

Implement a small, data-driven firearm loop that feels deliberate in first-person aim, remains consistent from fixed-camera contexts, and can damage any compliant receiver.

## Scope

- Weapon definition resource: ID, display data, damage, range, fire interval, capacity, ammo type, accuracy/spread, and feedback hooks.
- One vertical-slice pistol; optional second weapon only after the pistol is complete.
- Equip/unequip and weapon-state machine.
- First-person aim/fire, dry fire, cadence, ammo consumption, and reload rules.
- Hitscan query, layer filtering, self-exclusion, hit context, and impact event.
- Optional simple aim assist for controller if required by playtesting.
- Weapon sandbox with static and moving damage receivers.

## Non-Goals

- Large arsenal, ballistics simulation, attachments, advanced recoil patterns, melee combo system, or enemy AI behavior.
- Direct mutation of health or inventory internals.

## Dependencies

- Build Step 00 input/collision contracts.
- Build Step 03 aim-ray contract.
- Build Step 06 inventory/ammo API.
- Build Step 07 damage receiver contract.
- Build Step 11 feedback hooks.

## Public Boundary

- Inputs: equip request, fire/reload input, aim origin/direction, inventory ammo operations, owner collision identity, and control state.
- Outputs: weapon/equip state, magazine/reserve snapshot, shot/dry-fire/reload/impact events, and damage submissions.
- UI listens to state/events; it does not poll weapon child nodes.

## Activities

1. Define immutable weapon data separately from per-instance runtime state.
2. Implement a small explicit state machine: holstered, equipping, ready, firing cooldown, reloading, and disabled.
3. Connect camera aim ray and validate muzzle/near-wall behavior so shots cannot originate through solid cover.
4. Implement hitscan collision filtering and a typed hit context including instigator, position, normal, direction, and damage tags.
5. Use inventory transactions for ammo consumption/refill; define cancellation behavior when equipment changes.
6. Emit feedback events for animation, sound, VFX, camera impulse, controller vibration, and UI.
7. Add controller-friendly tuning only if it preserves player intent and can be disabled.
8. Test rapid input, no ammo, reload interruption, target death, pause, weapon switch, and checkpoint restore.

## Deliverables

- Weapon resource/type and pistol implementation.
- Hitscan/damage integration and event hooks.
- Combat sandbox and regression checks.
- Updated shared docs and handoff.

## Acceptance Criteria

- Fire rate and ammo accounting remain correct under spam, low frame rate, pause, and equipment changes.
- Shot direction matches the public aim ray and never hits the owner.
- Near-wall firing cannot damage targets through a wall between muzzle/player and aim line.
- Any compliant player/enemy/test receiver accepts the same damage context.
- UI, audio, animation, and VFX can subscribe without weapon-specific node paths.
- Data additions do not require editing the core firing logic.

## Handoff

Document weapon data fields, runtime state API, ammo transaction calls, collision masks, damage context, events, and sandbox controls.

## Critic Review

- Is aiming/shooting trustworthy at close walls and camera transitions?
- Can inputs duplicate shots or ammunition transactions?
- Is the data/runtime split clear enough for more weapons?
- Does controller support help without silently steering shots?
- Has weapon code taken ownership of health, UI, camera, or inventory state?

