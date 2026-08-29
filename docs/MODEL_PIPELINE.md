# Actor Model and Animation Pipeline

Updated: 2026-08-29

## Runtime contract

Actor physics roots always remain at identity scale and own collision, navigation, perception, health, inventory, and weapon runtime. `VisualRoot` is an `ActorVisualAdapter3D`; its `ModelRoot/ModelPayload` child is the only replaceable model/rig payload. Scale, facing-axis, and origin corrections belong on `ModelPayload`, never on the actor root or gameplay colliders.

The adapter accepts this smallest shared semantic set. Gameplay publishes values and events; models never write gameplay state.

| Semantic | Type | Meaning |
|---|---|---|
| `planar_velocity` | `Vector2` | Actor-local right/forward velocity. |
| `speed_ratio` | `float` 0–1 | Current planar speed divided by the owning movement maximum. |
| `grounded` | `bool` | Contact state for locomotion selection. |
| `crouched` | `bool` | Player stance; guards currently remain false. |
| `aiming` | `bool` | Rooted player aim or guard attack presentation. |
| `weapon_equipped` | `bool` | Visual visibility request, not inventory authority. |
| `reloading` | `bool` | Reload presentation while combat owns the timer/transaction. |
| `dead` | `bool` | Terminal pose request sourced from health/guard state. |
| `alert_state` | `StringName` | `NORMAL`, `SUSPICIOUS`, `ALERT`, `EVASION`, `SEARCH`, or `DEAD`. |

One-shot actions are `fire`, `reload`, `damaged`, and `death`. Placeholder scenes use procedural motion. A supplied `AnimationPlayer` may map those actions to clips, and an `AnimationTree` may map semantic fields to its own parameters. Missing optional clips retain the procedural fallback; names in `required_clips` produce a stable configuration error when absent.

## Scene and socket convention

```text
Actor (CharacterBody3D, identity scale)
├── VisualRoot (ActorVisualAdapter3D, identity scale)
│   ├── ModelRoot
│   │   └── ModelPayload              # replace this scene only
│   └── Sockets
│       ├── WeaponSocket
│       │   └── MuzzleSocket
│       ├── HeadSocket
│       ├── EyesSocket
│       └── EffectOrigin
├── WeaponController                  # gameplay runtime, not visual
├── Health / Perception / Navigation  # gameplay-owned as applicable
└── CollisionShape3D
```

Consumers request sockets through `VisualRoot.get_socket(id)` with IDs `weapon`, `muzzle`, `head`, `eyes`, and `effect_origin`. No gameplay script names a skeleton bone or reaches into `ModelPayload`. A rig may use `BoneAttachment3D` internally to position proxy markers, but the adapter-facing marker paths and IDs stay unchanged across reimports. The weapon controller uses the configured muzzle marker when present and its gameplay-owned fallback marker when the entire visual child is absent.

## Blender and glTF export

- Author at real scale: one Blender unit equals one meter. A standing actor is 1.8 m tall.
- Use `+Y` up in Godot and make the exported character face Godot `-Z`. In Blender's glTF exporter use forward `-Z`, up `Y`, export scale `1.0`, and apply object transforms before skinning/export.
- Put the actor origin on the floor between the feet at `(0, 0, 0)`. Keep the armature object at identity scale/rotation. Mesh corrections that cannot be applied live under `ModelPayload` only.
- Use one armature per actor payload, deform bones only, normalized weights, no generated leaf bones, and no root-scale animation.
- Export glTF 2.0 (`.glb` preferred), selected objects only, meshes, armature, skinning, morphs only when used, animation, tangents, and material data. Do not export lights, cameras, navigation, or collision.
- Locomotion is gameplay-driven and in-place. Root translation/yaw curves are removed. A root-motion exception requires a cross-system decision and a collision/navigation test; none is currently accepted.

Clip names use lower snake case: `idle`, `walk`, `crouch`, `aim`, `fire`, `reload`, `damage`, and `death`. Locomotion clips loop cleanly; actions do not loop. Begin each clip on a neutral boundary, exclude duplicated terminal loop frames, and keep event timing out of authoritative gameplay. Clip name differences are configured on the adapter rather than referenced by player, guard, weapon, or health scripts.

## Materials, textures, and LOD

- Character target: no more than two material slots; LOD0/LOD1/LOD2 targets are 30k/15k/6k triangles. Small weapons and props target 10k/4k/1.5k.
- Character texture cap is 2048×2048 per base-color, normal, and packed ORM set; small props use 1024×1024. Base color/emission are sRGB; normal/ORM data are linear. Prefer packed occlusion/roughness/metallic channels.
- Prefer opaque or alpha-scissor materials. Transparent surfaces require an explicit readability/performance reason. Reuse materials and textures across LODs.
- Generate tangents on import, preserve normals unless visibly broken, enable mesh compression after visual comparison, and keep imported collision/navigation disabled. Gameplay collision remains authored on the actor or level root.

## Godot import and reimport checklist

1. Add the source file and its `assets/metadata/<asset_id>.json` record together. Confirm redistribution, derivative, attribution, and commercial-use terms before import.
2. Import at scale `1.0`; preserve the skeleton and animation library; disable imported collision, navigation, cameras, and lights.
3. Instance the imported payload under `ModelRoot` and keep the actor root and `VisualRoot` transforms at identity. Correct scale/orientation only on `ModelPayload`.
4. Configure required clips, optional action clip mappings, and any AnimationTree parameter paths. Run adapter validation and inspect every warning/error.
5. Check all five adapter sockets at rest, crouch, aim, fire, reload, damage, and death. Reimport must not change their public paths.
6. Verify material assignment, color space, texture resolution, transparency mode, LOD visibility, and missing external dependencies.
7. Run `tests/animation_model_pipeline_test.gd`, the owning player/guard/combat tests, and `tests/level_interaction_test.gd`. Confirm actor-root transforms, collision shapes/layers, navigation IDs, perception targets, muzzle clearance, and damage hitboxes remain unchanged.
8. Inspect a 1280×720 mission frame and motion at intended camera distances. Facing, stance, aim, alert, hit, and death must read without debug labels.
9. Re-run the checklist after every source re-export. Treat changed bone/clip/material/socket names as a reviewed interface migration, never a silent reimport.

## Current proof swap

`proof_swap_guard_model.tscn` is an original in-repository alternate silhouette with the same payload-node convention. The pipeline test swaps it at runtime while asserting that collision, navigation, perception, health, and stable socket instances do not change. It proves replacement isolation; it is not presented as final art or as a licensed external model.
