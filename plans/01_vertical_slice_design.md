# Build Step 01 — Vertical Slice Design

## Assignment

One design/integration agent owns the authoritative mission specification and tuning targets. This plan produces buildable constraints, not a broad design wishlist.

## Objective

Define a compact mission whose sequence exercises movement, camera, interaction, inventory, combat, stealth, alerts, health, checkpoints, and extraction in 5–10 minutes.

## Scope

- Mission premise, start, objective, extraction, success, failure, and restart behavior.
- Room-by-room flow and intended stealth/combat opportunities.
- Exact player control map across exploration, first-person aim, menus, and pause.
- Initial tuning targets for movement, health, damage, detection, alert phases, inventory, and ammo.
- Content budget: room count, guard count, weapon count, items, door/access levels, camera zones, and checkpoints.
- Scope exclusions and deferral list.

## Non-Goals

- Final narrative, cinematics, boss battle, codecs, multiple floors, or full-game content.
- Pixel-perfect reproduction of an existing copyrighted level.
- Implementation beyond disposable diagrams/test data.

## Dependencies

- Coordinate engine/input feasibility with Build Step 00.

## Mission Skeleton

1. **Insertion:** safe area teaches movement and fixed camera transition.
2. **First Patrol:** one guard and cover teach cone/radar reading.
3. **Supply Detour:** player collects pistol, ammo, and ration.
4. **Security Hall:** door needs an access item found through a risky detour.
5. **Alert Arena:** two guards and connected cover support evade, search, or combat.
6. **Objective Room:** interact with a terminal/package to complete the mission objective.
7. **Extraction:** return by a shortened route or reach a newly opened exit.

## Activities

1. Draw a simple room/connection diagram with traversal distances and camera-zone boundaries.
2. Place every guard, patrol loop, pickup, door, objective, checkpoint, hiding opportunity, and fail-safe.
3. Specify expected first-run timing for each beat.
4. Define the control map, including whether aiming roots the player, permits strafing, or transitions contextually.
5. Define the intended states and player feedback for suspicion, detection, alert, evasion, search, and normal.
6. Create an initial tuning table with units and rationale; mark numbers as targets rather than hard-coded constants.
7. Write explicit exclusions to protect the slice from feature creep.
8. Define three playthrough scripts: stealth success, detected recovery, and death/checkpoint restart.

## Deliverables

- Mission flow and room-connection diagram in project-native Markdown or an original image asset.
- Control scheme and mode-transition rules.
- Tuning/content budget table.
- Three end-to-end acceptance scripts.
- Updated shared docs and handoff.

## Acceptance Criteria

- Every planned subsystem is exercised by at least one mission beat.
- Stealth is possible without relying on perfect timing or hidden information.
- Detection does not automatically make the mission unwinnable.
- Required pickup/access-item placement cannot soft-lock progression.
- The content budget is small enough for one polished vertical slice.
- Camera transitions and first-person aim are specified for every room type.

## Handoff

Provide the authoritative room list, entity counts, tuning table, controls, and playthrough scripts. Any unresolved design choice must name the subsystem it blocks.

## Critic Review

- Does this mission prove the game loop or merely enumerate mechanics?
- Is the critical path readable to a first-time player?
- Are stealth, recovery, combat, and restart all deliberately supported?
- Are there any progression items, doors, or alerts that can create a soft lock?
- Which feature can be cut with the least damage if the schedule contracts?

