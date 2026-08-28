# Build Step 03 — Camera and First-Person Aim

## Assignment

One agent/chat owns all camera modes, camera-zone selection, transitions, aim ray origin/direction, and visual obstruction policy.

## Objective

Deliver readable fixed top-down/isometric framing for exploration and a reliable contextual first-person aiming mode without camera conflicts or disorientation.

## Scope

- Camera rig and fixed camera-zone resources/volumes.
- Zone priority, handoff, blend timing, and fallback camera behavior.
- Player tracking within constrained framing where the design requires it.
- Obstruction response: authored angles first, with fade/cutaway/near clipping only if needed.
- Enter/exit first-person aim, look limits, sensitivity, inversion, recenter behavior, and reticle ray.
- Camera shake/impulse hook owned here but driven by other systems.
- Debug display for active zone and aim ray.

## Non-Goals

- Weapon firing, damage, player locomotion, final reticle UI, or level art.
- Unrestricted third-person orbit camera.

## Dependencies

- Build Step 00 input/settings conventions.
- Build Step 01 room and control decisions.
- Build Step 02 player position/facing and control-mode boundary.
- Build Step 04 authored camera volumes and occluder geometry.

## Public Boundary

- Inputs: tracked actor transform, aim request, settings, authored zone data, and optional shake impulses.
- Outputs: active camera mode, view basis, aim origin/direction, transition state, and reticle visibility request.
- Only the camera subsystem sets `Camera3D.current` during gameplay.

## Activities

1. Define a camera-zone data shape: transform/framing, priority, blend, bounds, aim allowance, and optional look target.
2. Implement deterministic zone selection when volumes overlap or the player crosses quickly.
3. Implement blends that preserve player readability and settle exactly on the authored transform.
4. Define and implement first-person entry/exit, including what happens near walls, in doors, during alerts, and while menus open.
5. Compute a weapon-independent aim ray and expose it through a stable API.
6. Add mouse/controller sensitivity, dead zone, inversion, pitch/yaw limits, and settings hooks.
7. Add obstruction tests and decide which problems require level-authoring fixes versus runtime behavior.
8. Test camera ownership under pause, death, checkpoint reload, and scene transition.

## Deliverables

- Reusable camera rig, zone component/resource, and example zones.
- First-person aim mode and stable ray contract.
- Camera test scene covering transitions and obstructions.
- Updated shared docs and handoff.

## Acceptance Criteria

- Every playable space has a deterministic fallback camera.
- No overlap or rapid boundary crossing causes camera flicker or ownership warnings.
- The player remains visible and traversal intent remains legible in exploration.
- First-person aim enters/exits consistently and its ray matches the center/reticle.
- Camera settings work for keyboard/mouse and controller.
- Weapons can aim without knowing camera node paths.
- Pause, death, and reload never leave the wrong camera active.

## Handoff

Document zone authoring, priorities, mode API, aim-ray contract, settings keys, and level-design constraints.

## Critic Review

- Are fixed angles cinematic without making movement ambiguous?
- Can overlapping volumes or fast motion produce rapid cuts?
- Does first-person mode clip through walls or reveal unintended geometry?
- Is aim authority unambiguous between camera, player, and weapon?
- Are obstruction fixes robust or hiding poor camera placement?

