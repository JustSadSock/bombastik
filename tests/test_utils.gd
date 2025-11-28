extends Node
## Unit tests for utility functions

func _ready():
	run_all_tests()

func run_all_tests():
	print("=== Running Utility Tests ===")
	test_clamp_values()
	test_vector_operations()
	test_color_operations()
	test_math_helpers()
	print("=== All Utility Tests Passed ===")

func test_clamp_values():
	# Test clamping like used in player.gd and enemy.gd
	assert(clamp(150.0, 0.0, 100.0) == 100.0, "Clamp should cap at max")
	assert(clamp(-10.0, 0.0, 100.0) == 0.0, "Clamp should cap at min")
	assert(clamp(50.0, 0.0, 100.0) == 50.0, "Clamp should keep value in range")
	print("[PASS] test_clamp_values")

func test_vector_operations():
	# Test vector normalization like used throughout the project
	var v := Vector3(3, 0, 4)
	var normalized := v.normalized()
	assert(abs(normalized.length() - 1.0) < 0.001, "Normalized vector should have length 1")

	# Test zero vector handling
	var zero_vec := Vector3.ZERO
	var zero_normalized := zero_vec.normalized()
	assert(zero_normalized.length() == 0.0, "Zero vector normalized should be zero")

	print("[PASS] test_vector_operations")

func test_color_operations():
	# Test color interpolation like used in materials
	var c1 := Color(0.0, 0.0, 0.0)
	var c2 := Color(1.0, 1.0, 1.0)
	var mid := c1.lerp(c2, 0.5)
	assert(abs(mid.r - 0.5) < 0.01, "Color lerp should work correctly")
	assert(abs(mid.g - 0.5) < 0.01, "Color lerp should work correctly")
	assert(abs(mid.b - 0.5) < 0.01, "Color lerp should work correctly")
	print("[PASS] test_color_operations")

func test_math_helpers():
	# Test wrapi like used in weapon switching
	assert(wrapi(5, 0, 3) == 2, "wrapi should wrap around")
	assert(wrapi(-1, 0, 3) == 2, "wrapi should wrap negative values")
	assert(wrapi(0, 0, 3) == 0, "wrapi should keep value at min")

	# Test deg_to_rad and rad_to_deg
	assert(abs(deg_to_rad(180.0) - PI) < 0.001, "deg_to_rad should convert correctly")
	assert(abs(rad_to_deg(PI) - 180.0) < 0.001, "rad_to_deg should convert correctly")

	# Test lerp
	assert(abs(lerp(0.0, 10.0, 0.5) - 5.0) < 0.001, "lerp should interpolate correctly")

	print("[PASS] test_math_helpers")
