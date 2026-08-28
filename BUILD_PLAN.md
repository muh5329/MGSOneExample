# Metal Gear Solid–Style Vertical Slice Build Plan

## Purpose

Build a small, playable Godot 4 vertical slice that captures the systemic feel of the original *Metal Gear Solid*: fixed top-down/isometric exploration, contextual first-person aiming, stealth, guards with visible perception cones, weapons, inventory items, rations, alerts, and a compact industrial infiltration level.

The first pass uses primitive geometry, simple materials, and placeholder audio. External 3D models can replace placeholders later without changing gameplay contracts. The project should reproduce mechanics and pacing while using original or properly licensed content for anything distributed.

## Definition of the Vertical Slice

One 5–10 minute mission in a compact industrial facility:

1. Start unseen in an exterior insertion area.
2. Learn movement, cover, camera behavior, and radar.
3. Collect a weapon, ammunition, and a ration.
4. Bypass or fight patrolling guards.
5. Trigger and survive or evade an alert.
6. Use an access item to reach the objective.
7. Complete the objective and reach an extraction/end trigger.
8. Restart from a checkpoint after death.

The slice is complete only when this loop works in an exported build with keyboard/mouse and controller.

## Shared Technical Direction

- Engine: Godot 4.x, with the exact version pinned by the foundation owner.
- Language: typed GDScript unless a documented decision says otherwise.
- World: 3D scenes, `CharacterBody3D` actors, primitive meshes, authored collision, and navigation regions.
- Architecture: reusable scenes and resources, signal-driven communication, and explicit interfaces documented in [`docs/INTERFACES.md`](docs/INTERFACES.md).
- Input: actions, never raw key checks in gameplay code.
- Content: data-driven weapons, items, and tuning values where practical.
- Quality: each subsystem supplies an isolated test scene or automated test plus an integration checklist.
- Coordination: every agent reads [`docs/README.md`](docs/README.md) and updates the shared handoff documents before finishing.

## Dependency Order

```text
Foundation + Slice Definition
            |
     Core Contracts/Input
       /      |       \
  Movement  Camera   Level Blockout
       \      |       /
       Interaction + Game State
          /          \
    Weapons/Combat   Inventory/Menu
          \          /
      Health/Damage/Checkpoints
                |
      Enemy AI + Perception
                |
       Alert/Radar/Stealth
                |
    Animation/Models + Audio/VFX + UI
                |
       Test, Integrate, Polish, Export
```

Agents may work in parallel once their documented dependencies and interface contracts are stable. If a dependency is missing, use a minimal test double rather than privately recreating another agent's subsystem.

## Build Step 00 — Project Foundation

Create the runnable Godot project, folder conventions, input actions, autoload boundaries, test conventions, debug build policy, and a minimal CI/headless validation path.

Owner brief: [`plans/00_project_foundation.md`](plans/00_project_foundation.md)

## Build Step 01 — Vertical Slice Design

Lock the mission flow, spatial beats, success/failure conditions, control map, tuning targets, and scope limits so every subsystem builds toward the same playable experience.

Owner brief: [`plans/01_vertical_slice_design.md`](plans/01_vertical_slice_design.md)

## Build Step 02 — Player Movement and Stance

Implement responsive camera-relative locomotion, rotation, collision, crouch, wall handling, animation parameters, and movement noise output.

Owner brief: [`plans/02_player_movement.md`](plans/02_player_movement.md)

## Build Step 03 — Camera and First-Person Aim

Implement fixed cinematic camera zones, smooth transitions, obstruction handling, contextual first-person view, aim input, and clean ownership of camera mode.

Owner brief: [`plans/03_camera_and_aim.md`](plans/03_camera_and_aim.md)

## Build Step 04 — Level Geometry and Interaction

Block out the facility with reusable primitives, collision, navigation, doors, pickups, objective triggers, cover affordances, camera volumes, and interaction prompts.

Owner brief: [`plans/04_level_and_interaction.md`](plans/04_level_and_interaction.md)

## Build Step 05 — Weapons and Combat

Build weapon data, equip/unequip, aiming, hitscan fire, ammunition, reload behavior, impacts, and a damage contract that both player and enemies can use.

Owner brief: [`plans/05_weapons_and_combat.md`](plans/05_weapons_and_combat.md)

## Build Step 06 — Inventory, Items, and Menus

Build weapon/item inventories, selection menus, ration consumption, access items, pickups, contextual usability rules, and pause/input behavior.

Owner brief: [`plans/06_inventory_items_menu.md`](plans/06_inventory_items_menu.md)

## Build Step 07 — Health, Damage, Checkpoints, and Mission State

Own health, healing, death, checkpoint snapshots, restarts, objective state, pause state, and clean transitions between gameplay outcomes.

Owner brief: [`plans/07_health_and_game_state.md`](plans/07_health_and_game_state.md)

## Build Step 08 — Enemy AI and Perception

Build guard patrol, cone-based vision with occlusion, hearing, suspicion, investigation, pursuit, search, combat, return-to-post behavior, and debugging visuals.

Owner brief: [`plans/08_enemy_ai_and_perception.md`](plans/08_enemy_ai_and_perception.md)

## Build Step 09 — Alert, Radar, and Stealth Feedback

Coordinate global alert phases, guard broadcasts, cooldown/search rules, radar contacts and cones, radar restrictions, and player-facing stealth feedback.

Owner brief: [`plans/09_alert_radar_stealth.md`](plans/09_alert_radar_stealth.md)

## Build Step 10 — Animation and External Model Pipeline

Define placeholder actor rigs and animation contracts now, then document a safe import/replacement pipeline for externally generated characters, weapons, and props.

Owner brief: [`plans/10_animation_and_models.md`](plans/10_animation_and_models.md)

## Build Step 11 — Audio, VFX, and Game Feel

Add footsteps, weapon and alert feedback, pickup/menu sounds, impact VFX, detection feedback, and a restrained retro presentation without obscuring gameplay.

Owner brief: [`plans/11_audio_vfx_gamefeel.md`](plans/11_audio_vfx_gamefeel.md)

## Build Step 12 — HUD, Accessibility, and Settings

Present health, equipped gear, ammunition, radar, alerts, prompts, pause/settings, remapping, sensitivity, volume, subtitles/readability options, and controller focus.

Owner brief: [`plans/12_hud_accessibility_settings.md`](plans/12_hud_accessibility_settings.md)

## Build Step 13 — Testing and Debug Tooling

Create contract tests, gameplay verification scenes, deterministic AI scenarios, debug overlays, smoke tests, performance captures, and regression checklists.

Owner brief: [`plans/13_testing_and_debug.md`](plans/13_testing_and_debug.md)

## Build Step 14 — Integration, Balance, and Release

Integrate the mission end to end, tune systems together, fix boundary defects, validate performance and controls, export a clean build, and document known limitations.

Owner brief: [`plans/14_integration_and_release.md`](plans/14_integration_and_release.md)

## Milestones

### Milestone A — Graybox Walkthrough

Foundation, mission graybox, movement, cameras, doors, and objective flow work with no combat required.

### Milestone B — Combat Sandbox

Weapons, damage, inventory, health, pickups, and one test guard work in isolated and integrated rooms.

### Milestone C — Stealth Loop

Multiple guards patrol, see and hear the player, coordinate alerts, search, return to patrol, and appear correctly on radar.

### Milestone D — Feature-Complete Slice

All mission beats, death/restart, menus, controller support, audio/VFX, and debug-off presentation work from start to finish.

### Milestone E — Release Candidate

Acceptance tests pass, blockers are closed, performance targets are met, licensing is checked, and an exported build is verified on target hardware.

## Global Definition of Done

- The full mission can be completed stealthily and after detection.
- Player can walk, crouch, collide, aim in first person, fire, reload, change equipment, collect and consume items, take damage, heal, die, and restart.
- Guards use occluded vision cones and hearing, communicate alert state, search meaningfully, and recover without soft-locking.
- UI and radar agree with authoritative gameplay state.
- Keyboard/mouse and controller are fully usable, including menus.
- No subsystem depends on undocumented node paths or another agent's private implementation.
- Automated/headless checks and the manual release checklist pass.
- The project runs from a clean checkout/import, not from `.godot` cache artifacts.
- `docs/STATUS.md`, `docs/CODE_MAP.md`, `docs/INTERFACES.md`, `docs/DECISIONS.md`, and `docs/HANDOFF.md` reflect the delivered state.

## Agent Workflow

1. Read all files listed in [`docs/README.md`](docs/README.md).
2. Claim exactly one subsystem plan and record ownership in `docs/STATUS.md`.
3. Confirm dependencies and public contracts before editing shared integration files.
4. Work inside the subsystem's owned paths; avoid drive-by refactors.
5. Validate the subsystem in isolation and at its documented integration boundary.
6. Update the concise shared docs and add a handoff entry.
7. Run the subsystem critic checklist and record remaining risks honestly.

## Critic Review

Before calling the overall plan complete, a critic who did not implement the final integration must answer:

- Does the slice feel like one coherent stealth game rather than disconnected demos?
- Is every global acceptance criterion demonstrated in a clean exported build?
- Are camera, controls, menus, combat, AI, and alert state free of ownership conflicts?
- Can the mission be completed through stealth and recovered after detection without a soft lock?
- Are perception cones honest, occluded, and consistent with radar feedback?
- Can external models replace primitives without rewriting game logic or collision contracts?
- Are shared docs short, current, and sufficient for a new agent to diagnose the project in minutes?
- Are all third-party assets and references licensed and credited appropriately?
- Which three defects most threaten player comprehension, stealth fairness, or release stability?

The critic records findings in `docs/CRITIC_REPORT.md`. Any blocker reopens the owning subsystem plan.
