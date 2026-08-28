# Build Step 06 — Inventory, Items, and Menus

## Assignment

One agent/chat owns inventory data and transactions, weapon/item selection interfaces, pickups, ration use, access items, equipment state, and inventory menu interaction.

## Objective

Provide fast, readable equipment management in the style of dual weapon/item panels while keeping inventory authoritative, testable, and independent from UI layout.

## Scope

- Item and weapon inventory entries keyed by stable IDs.
- Quantity/capacity operations with explicit success/failure results.
- Equipped weapon and equipped item state.
- Weapon panel, item panel, quick-use, controller focus, and input-repeat behavior.
- Pistol/ammo pickup, ration pickup/use, and one access/progression item.
- Context rules: full inventory, full health, locked door access, death, pause, and cutscene/control lock.
- Signals/snapshots for HUD and checkpoint system.

## Non-Goals

- Weapon firing, health arithmetic, door implementation, save-file serialization, or final UI art.
- A full RPG inventory grid, crafting, dropping, item durability, or dozens of items.

## Dependencies

- Build Step 00 input/pause conventions.
- Build Step 05 weapon/ammo API.
- Build Step 07 healing/checkpoint API.
- Build Step 04 pickup/door interaction contract.
- Build Step 12 shared UI/readability conventions.

## Public Boundary

- Inventory provides add/remove/has/count/capacity/equip/use requests and immutable display snapshots.
- Item effects call narrow recipient interfaces; they do not search the scene tree.
- Menus submit requests to inventory and render results; they do not directly edit quantities.
- Pickups consume themselves only after a successful transaction.

## Activities

1. Define item/weapon data resources with stable IDs, labels, icons/placeholders, capacities, and effect references.
2. Implement transactional quantity and equipment operations with clear result codes.
3. Implement selection ordering that remains stable as quantities reach zero.
4. Build left/right inventory panels with tap/hold behavior only if the design specifies it; otherwise prioritize a simple reliable panel.
5. Implement ration use through the health API, including full-health rejection and optional equipped quick-use.
6. Implement access-item possession checks for doors without consuming the item unless design explicitly requires it.
7. Implement pickup interaction, full-capacity feedback, respawn/checkpoint policy, and duplicate prevention.
8. Test controller focus, rapid open/close, switching during reload, death, pause nesting, and checkpoint restore.

## Deliverables

- Inventory/item data and authoritative runtime component/service.
- Weapon/item selection panels and pickup components.
- Pistol/ammo, ration, and access-item content definitions.
- Inventory test scene/tests and updated shared docs.

## Acceptance Criteria

- Quantities never become negative or exceed capacity.
- Failed pickup/use operations do not delete the world pickup or consume an item.
- Equipped state cannot reference an unavailable definition or invalid quantity state.
- Rations heal through the health contract and never exceed maximum health.
- Access checks agree between menu, inventory, and doors.
- Menus are fully operable by keyboard and controller and restore gameplay input cleanly.
- Checkpoint snapshots can reproduce inventory and equipment exactly.

## Handoff

Document IDs, definitions, transaction results, menu controls, pause/input behavior, signals, checkpoint snapshot shape, and pickup authoring steps.

## Critic Review

- Is inventory the single source of truth, or can UI/world state diverge?
- Can rapid menu/input transitions duplicate or lose items?
- Are rejection reasons visible and understandable to the player?
- Do controller focus and selection ordering remain stable at zero quantity?
- Have item effects become tightly coupled to player or level node paths?

