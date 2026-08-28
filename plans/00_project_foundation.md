# Build Step 00 — Project Foundation

## Assignment

One agent/chat owns the initial runnable project, conventions, shared contracts, and validation entry points. This agent may create cross-cutting skeletons but must not implement full gameplay owned by later plans.

## Objective

Produce a clean Godot 4 project that opens, runs, accepts both input families, loads a bootstrap scene, and provides stable locations and conventions for independent subsystem work.

## Scope

- Pin the Godot 4.x version and rendering backend.
- Create `project.godot`, bootstrap/main scene, folder structure, and ignore rules.
- Define semantic input actions and default keyboard/mouse/controller bindings.
- Decide minimal autoloads: game state, event/noise routing, and settings only if justified.
- Establish collision layers/masks, node groups, naming conventions, typed GDScript style, and resource UID policy.
- Create reusable test-scene conventions and one headless smoke test.
- Create a debug configuration that can show diagnostics without shipping them enabled.
- Document how to run, test, and export from a clean checkout.

## Non-Goals

- Full player, guard, weapon, inventory, UI, or level behavior.
- A large service-locator framework or speculative abstraction.
- Importing final art.

## Dependencies

- None. Coordinate control-map details with Build Step 01.

## Required Contracts

- Declare every input action needed by the master plan.
- Publish collision layer/mask meanings in `docs/INTERFACES.md`.
- Publish bootstrap and test entry points in `docs/CODE_MAP.md`.
- Prefer signals and small typed APIs over absolute node paths.
- Ensure gameplay can be paused without pausing menus that must remain interactive.

## Activities

1. Confirm the exact Godot version and record it in `docs/DECISIONS.md`.
2. Create the intended directory layout and source-control exclusions for `.godot/`, local exports, and generated imports.
3. Configure display, physics tick, stretch behavior, default environment, and a conservative desktop performance target.
4. Define input actions for movement, aim/look, fire, reload, crouch, interact, both inventory panels, quick-use, pause, and UI navigation.
5. Define shared groups such as player, guards, damageable, interactable, camera zones, and checkpoint targets only when a consumer exists.
6. Define collision layers for world, player body, enemy body, hitboxes, interaction queries, perception blockers, and pickups.
7. Add a bootstrap scene that can load a test room and report a clear failure if required scenes are missing.
8. Add a headless smoke test that validates project startup, input actions, and key shared resources.
9. Add short run/test/export instructions to the root README or `docs/CODE_MAP.md`.

## Deliverables

- Runnable Godot project and bootstrap scene.
- Input map and collision matrix.
- Minimal shared service skeletons with documented ownership.
- Smoke-test command and baseline test.
- Updated `docs/STATUS.md`, `docs/CODE_MAP.md`, `docs/INTERFACES.md`, `docs/DECISIONS.md`, and `docs/HANDOFF.md`.

## Acceptance Criteria

- A clean editor import can run the bootstrap scene without relying on stale `.godot` data.
- Keyboard/mouse and a standard controller can navigate a placeholder scene and pause UI input.
- The smoke test exits nonzero on missing required actions or scenes.
- No later subsystem must invent its own input names, collision layers, or bootstrap mechanism.
- Autoloads have clear reasons and no subsystem-specific logic.

## Handoff

List the exact Godot version, launch/test commands, input action names, collision matrix, autoloads, and extension points. Flag any provisional contract explicitly.

## Critic Review

- Can a new agent clone/import/run/test without editor-local state?
- Are input and collision conventions complete but small?
- Are autoloads truly global, or do they hide subsystem ownership?
- Does the bootstrap fail clearly instead of masking missing content?
- Is there any foundation code that prematurely implements another plan?

