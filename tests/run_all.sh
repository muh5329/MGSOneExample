#!/bin/sh
set -eu

if [ -n "${GODOT_BIN:-}" ]; then
	ENGINE="$GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
	ENGINE="$(command -v godot)"
elif [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
	ENGINE=/Applications/Godot.app/Contents/MacOS/Godot
else
	echo "Godot 4.7 executable not found. Set GODOT_BIN." >&2
	exit 127
fi

for TEST in \
	smoke_test.gd \
	player_movement_test.gd \
	camera_aim_test.gd \
	level_interaction_test.gd \
	weapon_combat_test.gd \
	inventory_items_menu_test.gd \
	health_game_state_test.gd \
	enemy_ai_perception_test.gd \
	alert_radar_stealth_test.gd \
	animation_model_pipeline_test.gd \
	presentation_settings_test.gd \
	integration_release_test.gd
do
	"$ENGINE" --headless --path . --script "res://tests/$TEST"
done
