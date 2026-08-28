# Build Step 07 — Health, Damage, Checkpoints, and Mission State

## Assignment

One agent/chat owns reusable health/damage reception, player death, healing, mission state, checkpoint snapshots, restart, pause authority, and objective outcome transitions.

## Objective

Make damage and recovery predictable across actors, and guarantee that death/restart and mission completion cannot leave subsystems in contradictory states.

## Scope

- Reusable health/damage receiver with invulnerability/dead guards and typed hit context.
- Player health, healing, damage feedback events, death sequence, and control lock.
- Mission phases: initializing, playing, paused, player dead, completed, and restarting.
- Checkpoint activation, snapshot contents, deterministic restore order, and restart UX.
- Objective completion and extraction validation.
- Reset contract for transient guards, alerts, doors, pickups, projectiles/effects, UI, and cameras.

## Non-Goals

- Full disk save/load, multiple save slots, persistent campaign state, enemy decision-making, or final death screen art.

## Dependencies

- Build Step 00 bootstrap/pause conventions.
- Build Step 04 checkpoint/objective/extraction events.
- Build Step 05 damage context.
- Build Step 06 inventory snapshot/use API.
- Builds 08–09 guard/alert reset contracts.

## Public Boundary

- Health accepts damage/heal requests and exposes current/max/dead plus change/damaged/died events.
- Game state is the single authority for pause, death, completion, and restart transitions.
- Checkpoint snapshots use stable IDs and subsystem-owned capture/restore methods, not raw node serialization.
- Mission objective completion and extraction are distinct; extraction succeeds only when requirements are met.

## Activities

1. Implement health with clamping, duplicate-death protection, optional invulnerability window, and contextual damage events.
2. Define player damage/death sequencing and how menus, aim, movement, camera, HUD, and alerts respond.
3. Implement mission phase transitions with explicit permitted transitions and signals.
4. Define checkpoint scope: player transform/health, inventory/equipment, objective flags, pickup/door state, guard state policy, and global alert reset policy.
5. Implement capture and restore in a documented order that avoids transient events corrupting restored state.
6. Make checkpoint identifiers stable and validate missing/duplicate IDs.
7. Implement objective completion and extraction/end state.
8. Test damage bursts, healing at bounds, simultaneous death/objective, pause nesting, restart during alerts, and repeated restarts.

## Deliverables

- Reusable health component and player integration hooks.
- Mission state coordinator and checkpoint service.
- Death/restart and objective/extraction flow.
- Focused tests and updated shared docs.

## Acceptance Criteria

- Health stays within bounds and death fires exactly once.
- Damage after death and healing invalid targets cannot corrupt state.
- There is one authoritative pause/mission phase visible to all consumers.
- Repeated checkpoint restarts reproduce the documented state without duplicates or stale alerts.
- Simultaneous objective/damage events resolve deterministically.
- The mission cannot complete before its objective requirement.
- Snapshot failures report stable IDs and affected subsystem clearly.

## Handoff

Document health/damage methods, mission transition table, checkpoint snapshot schema and restore order, reset responsibilities, and known persistence exclusions.

## Critic Review

- Can health, mission phase, UI, and player controls disagree during transitions?
- Does restart truly clear transient AI/combat/camera/menu state?
- Are checkpoint snapshots based on stable identifiers rather than fragile paths?
- Can duplicate events cause multiple deaths, rewards, or completions?
- Is the scope honest about what is reset versus persisted?

