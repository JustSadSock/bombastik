extends Node
## Unit tests for enemy.gd constants and variants
## This script tests the static variant data defined in enemy.gd

## Store references to the enemy data constants
var VARIANT_STYLES: Array
var MELEE_VARIANTS: Array
var RANGED_VARIANTS: Array

func _ready():
	# Load the enemy script and access its constants
	var enemy_script = load("res://scripts/enemy.gd")
	VARIANT_STYLES = enemy_script.VARIANT_STYLES
	MELEE_VARIANTS = enemy_script.MELEE_VARIANTS
	RANGED_VARIANTS = enemy_script.RANGED_VARIANTS
	run_all_tests()

func run_all_tests():
	print("=== Running Enemy Tests ===")
	test_variant_styles_not_empty()
	test_melee_variants_have_required_fields()
	test_ranged_variants_have_required_fields()
	test_variant_values_are_valid()
	test_variant_meshes_have_valid_types()
	print("=== All Enemy Tests Passed ===")

func test_variant_styles_not_empty():
	assert(VARIANT_STYLES.size() > 0, "VARIANT_STYLES should not be empty")
	print("[PASS] test_variant_styles_not_empty")

func test_melee_variants_have_required_fields():
	var required := ["id", "health", "damage", "speed"]
	for variant in MELEE_VARIANTS:
		for field in required:
			assert(variant.has(field), "Melee variant missing field: " + field)
	print("[PASS] test_melee_variants_have_required_fields")

func test_ranged_variants_have_required_fields():
	var required := ["id", "health", "damage", "speed", "preferred_distance", "ranged_range"]
	for variant in RANGED_VARIANTS:
		for field in required:
			assert(variant.has(field), "Ranged variant missing field: " + field + " in " + variant.get("id", "unknown"))
	print("[PASS] test_ranged_variants_have_required_fields")

func test_variant_values_are_valid():
	for variant in MELEE_VARIANTS:
		assert(variant.get("health", 0.0) > 0.0, "Melee health should be positive")
		assert(variant.get("damage", 0.0) > 0.0, "Melee damage should be positive")
		assert(variant.get("speed", 0.0) > 0.0, "Melee speed should be positive")
	for variant in RANGED_VARIANTS:
		assert(variant.get("health", 0.0) > 0.0, "Ranged health should be positive")
		assert(variant.get("damage", 0.0) > 0.0, "Ranged damage should be positive")
		assert(variant.get("speed", 0.0) > 0.0, "Ranged speed should be positive")
		assert(variant.get("ranged_range", 0.0) > 0.0, "Ranged range should be positive")
	print("[PASS] test_variant_values_are_valid")

func test_variant_meshes_have_valid_types():
	var valid_types := ["box", "prism", "cylinder", "capsule", "torus", "cone"]
	for variant in MELEE_VARIANTS + RANGED_VARIANTS:
		if variant.has("body_mesh"):
			var mesh_type: String = variant.get("body_mesh").get("type", "")
			assert(mesh_type in valid_types, "Invalid body mesh type: " + mesh_type)
		if variant.has("head_mesh"):
			var mesh_type: String = variant.get("head_mesh").get("type", "")
			assert(mesh_type in valid_types, "Invalid head mesh type: " + mesh_type)
	print("[PASS] test_variant_meshes_have_valid_types")
