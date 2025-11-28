extends Node
## Unit tests for weapon_data.gd
## This script tests the static weapon data defined in weapon_data.gd

## Reference the weapons data directly from the resource script
var WEAPONS: Array

func _ready():
	# Load the weapon data script and access its WEAPONS constant
	var weapon_script = load("res://scripts/weapon_data.gd")
	WEAPONS = weapon_script.WEAPONS
	run_all_tests()

func run_all_tests():
	print("=== Running Weapon Data Tests ===")
	test_weapons_array_not_empty()
	test_all_weapons_have_required_fields()
	test_weapon_values_are_valid()
	test_weapon_ids_are_unique()
	test_weapon_meshes_have_valid_structure()
	print("=== All Tests Passed ===")

func test_weapons_array_not_empty():
	assert(WEAPONS.size() > 0, "WEAPONS array should not be empty")
	print("[PASS] test_weapons_array_not_empty")

func test_all_weapons_have_required_fields():
	var required_fields := ["id", "name", "damage", "fire_rate", "projectile_speed"]
	for weapon in WEAPONS:
		for field in required_fields:
			assert(weapon.has(field), "Weapon missing required field: " + field)
	print("[PASS] test_all_weapons_have_required_fields")

func test_weapon_values_are_valid():
	for weapon in WEAPONS:
		assert(weapon.get("damage", 0.0) > 0.0, "Damage should be positive: " + weapon.get("id", "unknown"))
		assert(weapon.get("fire_rate", 0.0) > 0.0, "Fire rate should be positive: " + weapon.get("id", "unknown"))
		assert(weapon.get("projectile_speed", 0.0) > 0.0, "Projectile speed should be positive: " + weapon.get("id", "unknown"))
		assert(weapon.get("spread", 0.0) >= 0.0, "Spread should be non-negative: " + weapon.get("id", "unknown"))
	print("[PASS] test_weapon_values_are_valid")

func test_weapon_ids_are_unique():
	var seen_ids := {}
	for weapon in WEAPONS:
		var weapon_id: String = weapon.get("id", "")
		assert(not seen_ids.has(weapon_id), "Duplicate weapon ID found: " + weapon_id)
		seen_ids[weapon_id] = true
	print("[PASS] test_weapon_ids_are_unique")

func test_weapon_meshes_have_valid_structure():
	for weapon in WEAPONS:
		if weapon.has("pickup_mesh"):
			var mesh_data: Dictionary = weapon.get("pickup_mesh")
			assert(mesh_data.has("type"), "Pickup mesh should have type: " + weapon.get("id", "unknown"))
			if mesh_data.get("type") == "composite":
				assert(mesh_data.has("parts"), "Composite mesh should have parts: " + weapon.get("id", "unknown"))
				assert(mesh_data.get("parts", []).size() > 0, "Composite mesh parts should not be empty: " + weapon.get("id", "unknown"))
		if weapon.has("weapon_model"):
			var model_data: Dictionary = weapon.get("weapon_model")
			assert(model_data.has("type"), "Weapon model should have type: " + weapon.get("id", "unknown"))
	print("[PASS] test_weapon_meshes_have_valid_structure")
