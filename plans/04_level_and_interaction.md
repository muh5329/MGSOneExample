# Build Step 04 — Level Geometry and Interaction

## Assignment

One agent/chat owns the graybox mission, reusable environment pieces, navigation/collision authoring, doors, pickups placement, objective/extraction triggers, and the generic interaction contract.

## Objective

Turn the approved mission design into a readable primitive-geometry facility where movement, camera, stealth, combat, navigation, and progression can be validated at correct scale.

## Scope

- Modular floors, walls, doors, rails, crates, ducts, stairs/ramps, and cover primitives.
- Collision, navigation regions/links, occlusion surfaces, lighting, and room identifiers.
- Camera-zone placement in coordination with the camera owner.
- Generic interactable component, focus/query rules, prompts, and disabled/locked states.
- Doors, access-controlled doors, pickups, objective terminal/item, checkpoint volumes, and extraction trigger.
- Debug spawn points and isolated room/test variants.

## Non-Goals

- Final meshes/materials, full inventory logic, weapon behavior, guard state machines, or UI presentation.
- Reproducing an original commercial level one-to-one.

## Dependencies

- Build Step 00 collision/navigation conventions.
- Build Step 01 mission layout and metrics.
- Builds 02–03 player dimensions and camera zones.
- Builds 06–09 progression, pickups, checkpoint, AI, and radar contracts.

## Public Boundary

- Interactable exposes prompt, availability/reason, priority, world anchor, and `interact(actor)`.
- Door exposes authoritative open/closed/locked state and navigation/occlusion consequences.
- Level emits objective/checkpoint/extraction events but does not own inventory or mission rules.

## Activities

1. Establish a metric kit based on player capsule, guard turning space, door width, cover height, and camera near plane.
2. Build the critical path and alternate stealth routes before decorating.
3. Author collision separately from visible primitives and test all seams.
4. Bake/configure guard navigation and validate patrol routes, chases, and door boundaries.
5. Place camera zones and verify all room transitions with the camera owner.
6. Implement focus selection and the shared interaction component.
7. Implement doors and connect lock decisions to inventory through the public query API.
8. Place pickups, checkpoints, objective, extraction, and safe recovery points according to the mission specification.
9. Add functional lighting/material color language for walkable space, cover, hazards, locked doors, and interactables.
10. Profile sightline cost and overdraw early; primitives still need sensible batching and lights.

## Deliverables

- Playable graybox level plus reusable environment/interactable scenes.
- Navigation and camera-zone authoring.
- Mission object placements and debug spawn points.
- Metric/style note and updated shared docs.

## Acceptance Criteria

- The critical path and optional detour are traversable at intended player/guard scale.
- No collision seam, invisible wall, or navigation gap blocks an intended route.
- Guards can reach all chase/search locations that players can legally occupy.
- Doors update collision, navigation, and perception blocking consistently.
- Interaction focus is deterministic when targets overlap.
- All progression states have a visible response and cannot soft-lock the slice.
- Every camera view communicates exits and important cover.

## Handoff

Document level entry scene, room IDs, spawn points, navigation rebake steps, metric kit, interactable contract, and any intentionally inaccessible geometry.

## Critic Review

- Does the graybox genuinely support stealth choices or only a corridor firefight?
- Are camera, navigation, collision, and perception blockers spatially consistent?
- Can any door or pickup state permanently block progression?
- Are dimensions proven with player and guard actors rather than visual guesswork?
- Will external art replacement preserve pivots, collision, doors, and sightlines?

