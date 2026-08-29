# Substation 6 Graybox Metrics

Updated: 2026-08-28

## Entry and authoring model

- Mission entry scene: `res://scenes/levels/substation_6.tscn`; the bootstrap loads it by default.
- Geometry, collision, navigation rectangles, mission placements, patrol points, guard bindings, and camera volumes are authored in `scripts/levels/substation_6.gd`. Visible boxes and collision bodies are separate nodes even when they share a metric definition.
- Focus/access behavior can be exercised alone in `res://scenes/levels/interaction_test_room.tscn`. The movement and camera labs remain separate regression scenes.

## Metric kit

| Element | Metric | Contract |
|---|---:|---|
| Player/guard clearance radius | 0.40 m body; 0.48 m nav footprint | Cover-subtracted navigation leaves at least the expanded footprint. |
| Standing/crouched height | 1.80 / 1.20 m | All intended routes are standing-clear; low cover is not a crawl route. |
| Door/corridor clear width | 4.0 m | Supports two character radii, turning room, and a stable fixed-camera threshold. |
| Wall/door height | 3.0 m | Full perception blocker; replacement art preserves the footprint/pivot. |
| Waist cover | 1.0–1.3 m | R0 pipe and corridor rails communicate cover without blocking the camera handoff. |
| Full occluder | 2.4–2.9 m | Cargo, pipe banks, divider, and transformers occupy layers 1 and 6. |
| Interaction range / objective hold | 2.0 m / 1.25 s | Focus uses anchor distance; terminal hold applies the scripted movement lock. |
| Camera handoff blend | 0.30–0.40 s | Z1, Z4, and Z5 transitions sit on authored opaque cover. |

Functional color language is teal for safe/control space, blue for yard traversal, amber for access/maintenance, red for electrical hazard/pressure, green-emissive for interactables, and red-emissive for locked doors.

## Coordinates and spawns

Room centers in X/Z meters: R0 `(-41, 0)`, R1 `(-10, 0)`, R2 `(-10, 24)`, R3 `(20, 0)`, R4 `(20, 22)`, R5 `(20, -24)`, and R6 `(-10, -28)`. Connections preserve the 8/6/7/6/8/10/9 m graybox corridors needed to exercise the intended route choices.

- Checkpoint spawns: `CP0_INSERTION (-46, 0, 0)` and `CP1_SWITCH_ENTRY (20, 0, -16)`.
- Debug spawns: one named `R*_DEBUG` marker in every room. All nine markers are in `debug_spawn_points` and expose `spawn_id`/`spawn_kind` metadata.
- Guard route groups: `G1` yard clockwise, `G2` maintenance U-loop, `G3` switch perimeter, and `G4` transformer crossing. Wait metadata is 2.0 s on G1 P1 and 1.5 s on G2 P4.
- Tactical radar map data is derived from the same authored wall partitions, corridor rails, and cover footprints used to build Substation 6. It is value-only, north-up, local to a 22 m radius, and intentionally omits dynamic door truth until a later HUD pass adds an approved dynamic-map seam.

## Navigation maintenance

There is no editor-baked artifact to become stale. `_build_navigation()` creates the checked-in polygon definitions at scene startup, subtracts expanded cover rectangles, and leaves 1.5 m gaps bridged only by each door's `NavigationLink3D`. To change geometry:

1. Update the visible/collision metric and its navigation footprint together in `substation_6.gd`.
2. Preserve a 4.0 m authored opening and position the door pivot at the gap center.
3. Run `godot --headless --path . --script res://tests/level_interaction_test.gd`; it verifies polygon coverage, link/collision state, and a live CP0-to-O1 path.
4. Run `godot --headless --path . --script res://tests/enemy_ai_perception_test.gd`, then exercise the affected route with the 0.4 m player and guard capsules before accepting art replacement.

Intentionally inaccessible geometry is limited to the outside of room shells, the tops/interiors of cargo/pipe/transformer occluders, the R4 locker shell, and the R6 console back. The R5 trench is currently a readable low-route floor treatment, not a crouch-only depression; future art may deepen it only if both capsule and camera tests remain green.
