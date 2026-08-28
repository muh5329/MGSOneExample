# Build Step 10 — Animation and External Model Pipeline

## Assignment

One agent/chat owns visual actor shells, animation parameter contracts, placeholder motion, import presets, model-replacement rules, and validation of externally generated 3D assets.

## Objective

Make primitive actors readable now and ensure later models, rigs, weapons, and props can replace them without changing gameplay logic, collision, navigation, or stable scene interfaces.

## Scope

- Primitive player/guard visual shells with clear facing, stance, aim, hit, and death readability.
- Animation-tree parameter contract driven by gameplay state.
- Placeholder clips or procedural motion for idle, walk, crouch, aim, fire, reload, damage, and death.
- Visual-root convention separating mesh/rig scale and orientation from actor physics.
- External model standards: units, axes, origin, scale, skeleton, clip names, materials, texture budgets, LOD, and licensing metadata.
- Import/reimport checklist and one proof-of-swap asset if a licensed model is available.

## Non-Goals

- Generating final copyrighted character likenesses, high-end motion capture, facial animation, cinematic animation, or changing gameplay colliders to fit every mesh detail.

## Dependencies

- Builds 02, 05, 07, and 08 animation parameters/events.
- Build Step 04 environment metrics and pivot conventions.
- Build Step 11 animation event feedback needs.

## Public Boundary

- Gameplay publishes semantic parameters/events such as planar speed, stance, aim, fire, reload, damaged, dead, and alert state.
- Visual adapters translate semantics into animation tree parameters and may not alter authoritative gameplay state.
- Actor root owns physics; replaceable visual root owns mesh, skeleton, animation player/tree, and attachments.

## Activities

1. Inventory required player/guard/weapon/prop states and define the smallest shared semantic parameter set.
2. Create highly legible primitive silhouettes and facing indicators for graybox testing.
3. Create an animation adapter that tolerates missing optional clips and reports configuration errors clearly.
4. Define attachment sockets for weapon, muzzle, head/eyes, and effect origins without making weapons depend on a named skeleton bone.
5. Document Blender/export and Godot import settings for scale, axes, root motion policy, materials, textures, and clip boundaries.
6. Decide root motion policy; default locomotion remains gameplay-driven unless a specific exception is accepted.
7. Test mesh/rig replacement while preserving actor root, collider, navigation avoidance, perception targets, and attachments.
8. Record source/license metadata for every external asset.

## Deliverables

- Placeholder visual scenes and animation adapter/contract.
- Model/animation import guide and checklist.
- Attachment socket conventions and proof-of-swap verification.
- Updated shared docs and handoff.

## Acceptance Criteria

- Primitive actors communicate facing, stance, movement, aiming, alert, damage, and death at gameplay camera distance.
- Removing or replacing the visual child does not break physics or game logic.
- External asset scale/orientation is correct without changing actor-root scale.
- Missing optional animation fails gracefully; required animation/config errors are obvious.
- Weapon/effect sockets survive model replacement through adapter configuration.
- Every distributed asset has source/license information.

## Handoff

Document semantic animation parameters, visual-root scene contract, attachment sockets, import presets, root-motion decision, validation steps, and asset-license location.

## Critic Review

- Can every important gameplay state be read from the intended camera distance?
- Are mesh scale/orientation corrections isolated under the visual root?
- Does any gameplay code depend on clip names, bones, or model hierarchy?
- Can a reimport silently break sockets, clips, materials, or collision?
- Is licensing/provenance recorded for every external asset?

