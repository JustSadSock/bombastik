extends Node3D
## Demonstration of advanced 3D modeling capabilities in Godot
## This scene showcases procedural mesh generation, materials, and composition

func _ready():
	_build_showcase_object()
	print("=== 3D Showcase Object Created ===")
	print("This demonstrates:")
	print("- Composite mesh generation using SurfaceTool")
	print("- Multiple primitive types (box, cylinder, sphere, torus, prism, capsule)")
	print("- Advanced materials with PBR properties")
	print("- Procedural texturing via code")
	print("- Animated light effects")
	print("- Dynamic mesh assembly")

func _build_showcase_object() -> void:
	var showcase := Node3D.new()
	showcase.name = "ShowcaseObject"
	add_child(showcase)

	# Create the main complex mech-like structure
	_create_mech_body(showcase)
	_create_mech_head(showcase)
	_create_mech_arms(showcase)
	_create_mech_legs(showcase)
	_create_decorative_elements(showcase)
	_create_lighting_effects(showcase)
	_create_animated_parts(showcase)

func _create_mech_body(parent: Node3D) -> void:
	var body := MeshInstance3D.new()
	body.name = "MechBody"

	# Build composite mesh for the torso
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Main torso - a box
	var torso_box := BoxMesh.new()
	torso_box.size = Vector3(1.2, 1.6, 0.8)
	tool.append_from(torso_box, 0, Transform3D.IDENTITY)

	# Chest plate - prism
	var chest_prism := PrismMesh.new()
	chest_prism.size = Vector3(0.9, 0.5, 0.6)
	tool.append_from(chest_prism, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.4, -0.5)))

	# Shoulder mounts - cylinders
	var shoulder_cyl := CylinderMesh.new()
	shoulder_cyl.height = 0.3
	shoulder_cyl.top_radius = 0.25
	shoulder_cyl.bottom_radius = 0.3
	shoulder_cyl.radial_segments = 24
	tool.append_from(shoulder_cyl, 0, Transform3D(Basis.IDENTITY, Vector3(0.7, 0.6, 0)))
	tool.append_from(shoulder_cyl, 0, Transform3D(Basis.IDENTITY, Vector3(-0.7, 0.6, 0)))

	# Back power core - torus
	var back_torus := TorusMesh.new()
	back_torus.inner_radius = 0.15
	back_torus.outer_radius = 0.35
	back_torus.ring_segments = 24
	back_torus.rings = 16
	tool.append_from(back_torus, 0, Transform3D(Basis.from_euler(Vector3(PI/2, 0, 0)), Vector3(0, 0.2, 0.5)))

	# Waist joint - capsule
	var waist_capsule := CapsuleMesh.new()
	waist_capsule.radius = 0.35
	waist_capsule.height = 0.5
	waist_capsule.radial_segments = 24
	tool.append_from(waist_capsule, 0, Transform3D(Basis.IDENTITY, Vector3(0, -0.9, 0)))

	body.mesh = tool.commit()
	body.material_override = _create_metallic_material(Color(0.2, 0.25, 0.35), 0.3, 0.7)
	parent.add_child(body)

func _create_mech_head(parent: Node3D) -> void:
	var head := MeshInstance3D.new()
	head.name = "MechHead"

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Main head - box
	var head_box := BoxMesh.new()
	head_box.size = Vector3(0.5, 0.4, 0.45)
	tool.append_from(head_box, 0, Transform3D.IDENTITY)

	# Visor - prism
	var visor := PrismMesh.new()
	visor.size = Vector3(0.42, 0.15, 0.3)
	tool.append_from(visor, 0, Transform3D(Basis.IDENTITY, Vector3(0, -0.05, -0.25)))

	# Antenna - cylinder
	var antenna := CylinderMesh.new()
	antenna.height = 0.4
	antenna.top_radius = 0.02
	antenna.bottom_radius = 0.04
	antenna.radial_segments = 12
	tool.append_from(antenna, 0, Transform3D(Basis.IDENTITY, Vector3(0.18, 0.35, -0.1)))
	tool.append_from(antenna, 0, Transform3D(Basis.IDENTITY, Vector3(-0.18, 0.35, -0.1)))

	# Ear sensors - spheres (using capsule with small height)
	var ear := CapsuleMesh.new()
	ear.radius = 0.08
	ear.height = 0.16
	ear.radial_segments = 16
	tool.append_from(ear, 0, Transform3D(Basis.from_euler(Vector3(0, 0, PI/2)), Vector3(0.32, 0.05, 0)))
	tool.append_from(ear, 0, Transform3D(Basis.from_euler(Vector3(0, 0, PI/2)), Vector3(-0.32, 0.05, 0)))

	head.mesh = tool.commit()
	head.position = Vector3(0, 1.2, 0)
	head.material_override = _create_metallic_material(Color(0.15, 0.2, 0.3), 0.25, 0.8)
	parent.add_child(head)

	# Add glowing visor overlay
	var visor_glow := MeshInstance3D.new()
	visor_glow.name = "VisorGlow"
	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.38, 0.08, 0.02)
	visor_glow.mesh = visor_mesh
	visor_glow.position = Vector3(0, 1.12, -0.28)
	visor_glow.material_override = _create_emissive_material(Color(0.2, 0.8, 1.0), 2.5)
	parent.add_child(visor_glow)

func _create_mech_arms(parent: Node3D) -> void:
	for side in [1, -1]:
		var arm_group := Node3D.new()
		arm_group.name = "Arm" + ("Right" if side > 0 else "Left")
		arm_group.position = Vector3(side * 0.8, 0.4, 0)

		# Upper arm
		var upper_arm := MeshInstance3D.new()
		upper_arm.name = "UpperArm"
		var upper_tool := SurfaceTool.new()
		upper_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

		var arm_cyl := CylinderMesh.new()
		arm_cyl.height = 0.6
		arm_cyl.top_radius = 0.12
		arm_cyl.bottom_radius = 0.15
		arm_cyl.radial_segments = 18
		upper_tool.append_from(arm_cyl, 0, Transform3D.IDENTITY)

		# Armor plate
		var armor := BoxMesh.new()
		armor.size = Vector3(0.18, 0.35, 0.22)
		upper_tool.append_from(armor, 0, Transform3D(Basis.IDENTITY, Vector3(side * 0.08, 0.1, 0)))

		upper_arm.mesh = upper_tool.commit()
		upper_arm.material_override = _create_metallic_material(Color(0.25, 0.3, 0.4), 0.35, 0.65)
		arm_group.add_child(upper_arm)

		# Elbow joint
		var elbow := MeshInstance3D.new()
		elbow.name = "Elbow"
		var elbow_mesh := TorusMesh.new()
		elbow_mesh.inner_radius = 0.06
		elbow_mesh.outer_radius = 0.14
		elbow_mesh.ring_segments = 18
		elbow_mesh.rings = 12
		elbow.mesh = elbow_mesh
		elbow.position = Vector3(0, -0.35, 0)
		elbow.rotation = Vector3(PI/2, 0, 0)
		elbow.material_override = _create_metallic_material(Color(0.4, 0.35, 0.3), 0.4, 0.5)
		arm_group.add_child(elbow)

		# Lower arm
		var lower_arm := MeshInstance3D.new()
		lower_arm.name = "LowerArm"
		var lower_tool := SurfaceTool.new()
		lower_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

		var forearm := CylinderMesh.new()
		forearm.height = 0.55
		forearm.top_radius = 0.1
		forearm.bottom_radius = 0.08
		forearm.radial_segments = 18
		lower_tool.append_from(forearm, 0, Transform3D.IDENTITY)

		# Wrist guard
		var wrist := CapsuleMesh.new()
		wrist.radius = 0.12
		wrist.height = 0.2
		wrist.radial_segments = 16
		lower_tool.append_from(wrist, 0, Transform3D(Basis.IDENTITY, Vector3(0, -0.22, 0)))

		lower_arm.mesh = lower_tool.commit()
		lower_arm.position = Vector3(0, -0.7, 0)
		lower_arm.material_override = _create_metallic_material(Color(0.22, 0.28, 0.38), 0.3, 0.7)
		arm_group.add_child(lower_arm)

		# Hand/Weapon
		var hand := MeshInstance3D.new()
		hand.name = "Hand"
		var hand_tool := SurfaceTool.new()
		hand_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

		# Palm
		var palm := BoxMesh.new()
		palm.size = Vector3(0.15, 0.12, 0.18)
		hand_tool.append_from(palm, 0, Transform3D.IDENTITY)

		# Fingers (prisms)
		var finger := PrismMesh.new()
		finger.size = Vector3(0.03, 0.18, 0.04)
		for i in range(4):
			var x_offset: float = -0.05 + i * 0.035
			hand_tool.append_from(finger, 0, Transform3D(Basis.IDENTITY, Vector3(x_offset, -0.14, -0.05)))

		# Weapon barrel for right arm
		if side > 0:
			var barrel := CylinderMesh.new()
			barrel.height = 0.5
			barrel.top_radius = 0.04
			barrel.bottom_radius = 0.06
			barrel.radial_segments = 16
			hand_tool.append_from(barrel, 0, Transform3D(Basis.from_euler(Vector3(PI/2, 0, 0)), Vector3(0, 0, -0.35)))

		hand.mesh = hand_tool.commit()
		hand.position = Vector3(0, -1.1, 0)
		hand.material_override = _create_metallic_material(Color(0.18, 0.22, 0.32), 0.25, 0.8)
		arm_group.add_child(hand)

		parent.add_child(arm_group)

func _create_mech_legs(parent: Node3D) -> void:
	for side in [1, -1]:
		var leg_group := Node3D.new()
		leg_group.name = "Leg" + ("Right" if side > 0 else "Left")
		leg_group.position = Vector3(side * 0.35, -1.2, 0)

		# Upper leg / thigh
		var thigh := MeshInstance3D.new()
		thigh.name = "Thigh"
		var thigh_tool := SurfaceTool.new()
		thigh_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

		var thigh_cyl := CylinderMesh.new()
		thigh_cyl.height = 0.6
		thigh_cyl.top_radius = 0.18
		thigh_cyl.bottom_radius = 0.14
		thigh_cyl.radial_segments = 20
		thigh_tool.append_from(thigh_cyl, 0, Transform3D.IDENTITY)

		# Thigh armor
		var thigh_armor := PrismMesh.new()
		thigh_armor.size = Vector3(0.24, 0.4, 0.16)
		thigh_tool.append_from(thigh_armor, 0, Transform3D(Basis.IDENTITY, Vector3(side * 0.06, 0.05, -0.12)))

		thigh.mesh = thigh_tool.commit()
		thigh.material_override = _create_metallic_material(Color(0.24, 0.28, 0.38), 0.3, 0.65)
		leg_group.add_child(thigh)

		# Knee joint
		var knee := MeshInstance3D.new()
		knee.name = "Knee"
		var knee_tool := SurfaceTool.new()
		knee_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

		var knee_sphere := CapsuleMesh.new()
		knee_sphere.radius = 0.14
		knee_sphere.height = 0.2
		knee_sphere.radial_segments = 20
		knee_tool.append_from(knee_sphere, 0, Transform3D.IDENTITY)

		# Knee cap
		var knee_cap := PrismMesh.new()
		knee_cap.size = Vector3(0.14, 0.16, 0.1)
		knee_tool.append_from(knee_cap, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.12)))

		knee.mesh = knee_tool.commit()
		knee.position = Vector3(0, -0.4, 0)
		knee.material_override = _create_metallic_material(Color(0.35, 0.32, 0.28), 0.4, 0.5)
		leg_group.add_child(knee)

		# Lower leg / shin
		var shin := MeshInstance3D.new()
		shin.name = "Shin"
		var shin_tool := SurfaceTool.new()
		shin_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

		var shin_cyl := CylinderMesh.new()
		shin_cyl.height = 0.7
		shin_cyl.top_radius = 0.12
		shin_cyl.bottom_radius = 0.1
		shin_cyl.radial_segments = 18
		shin_tool.append_from(shin_cyl, 0, Transform3D.IDENTITY)

		# Shin guard
		var shin_guard := BoxMesh.new()
		shin_guard.size = Vector3(0.16, 0.45, 0.12)
		shin_tool.append_from(shin_guard, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -0.1)))

		shin.mesh = shin_tool.commit()
		shin.position = Vector3(0, -0.85, 0)
		shin.material_override = _create_metallic_material(Color(0.2, 0.24, 0.34), 0.28, 0.72)
		leg_group.add_child(shin)

		# Foot
		var foot := MeshInstance3D.new()
		foot.name = "Foot"
		var foot_tool := SurfaceTool.new()
		foot_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

		# Main foot
		var foot_box := BoxMesh.new()
		foot_box.size = Vector3(0.22, 0.12, 0.4)
		foot_tool.append_from(foot_box, 0, Transform3D.IDENTITY)

		# Toe cap
		var toe := PrismMesh.new()
		toe.size = Vector3(0.2, 0.1, 0.15)
		foot_tool.append_from(toe, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.22)))

		# Heel
		var heel := CylinderMesh.new()
		heel.height = 0.08
		heel.top_radius = 0.06
		heel.bottom_radius = 0.08
		heel.radial_segments = 12
		foot_tool.append_from(heel, 0, Transform3D(Basis.IDENTITY, Vector3(0, -0.08, 0.12)))

		foot.mesh = foot_tool.commit()
		foot.position = Vector3(0, -1.3, -0.08)
		foot.material_override = _create_metallic_material(Color(0.18, 0.2, 0.28), 0.35, 0.6)
		leg_group.add_child(foot)

		parent.add_child(leg_group)

func _create_decorative_elements(parent: Node3D) -> void:
	# Jetpack on the back
	var jetpack := MeshInstance3D.new()
	jetpack.name = "Jetpack"
	var jp_tool := SurfaceTool.new()
	jp_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Main body
	var jp_body := BoxMesh.new()
	jp_body.size = Vector3(0.6, 0.8, 0.3)
	jp_tool.append_from(jp_body, 0, Transform3D.IDENTITY)

	# Thrusters
	var thruster := CylinderMesh.new()
	thruster.height = 0.35
	thruster.top_radius = 0.12
	thruster.bottom_radius = 0.08
	thruster.radial_segments = 20
	jp_tool.append_from(thruster, 0, Transform3D(Basis.IDENTITY, Vector3(0.18, -0.5, 0)))
	jp_tool.append_from(thruster, 0, Transform3D(Basis.IDENTITY, Vector3(-0.18, -0.5, 0)))

	# Fuel tanks (capsules)
	var tank := CapsuleMesh.new()
	tank.radius = 0.1
	tank.height = 0.5
	tank.radial_segments = 16
	jp_tool.append_from(tank, 0, Transform3D(Basis.IDENTITY, Vector3(0.25, 0.15, 0.12)))
	jp_tool.append_from(tank, 0, Transform3D(Basis.IDENTITY, Vector3(-0.25, 0.15, 0.12)))

	# Decorative rings
	var ring := TorusMesh.new()
	ring.inner_radius = 0.1
	ring.outer_radius = 0.16
	ring.ring_segments = 20
	ring.rings = 14
	jp_tool.append_from(ring, 0, Transform3D(Basis.from_euler(Vector3(PI/2, 0, 0)), Vector3(0, 0.35, -0.15)))

	jetpack.mesh = jp_tool.commit()
	jetpack.position = Vector3(0, 0.2, 0.55)
	jetpack.material_override = _create_metallic_material(Color(0.28, 0.32, 0.4), 0.32, 0.68)
	parent.add_child(jetpack)

	# Thruster glow
	for i in [-1, 1]:
		var glow := MeshInstance3D.new()
		glow.name = "ThrusterGlow" + str(i)
		var glow_mesh := CylinderMesh.new()
		glow_mesh.height = 0.15
		glow_mesh.top_radius = 0.08
		glow_mesh.bottom_radius = 0.1
		glow_mesh.radial_segments = 16
		glow.mesh = glow_mesh
		glow.position = Vector3(i * 0.18, -0.55, 0.55)
		glow.material_override = _create_emissive_material(Color(1.0, 0.5, 0.2), 3.0)
		parent.add_child(glow)

	# Shoulder emblems
	for side in [1, -1]:
		var emblem := MeshInstance3D.new()
		emblem.name = "Emblem" + ("Right" if side > 0 else "Left")
		var emblem_mesh := TorusMesh.new()
		emblem_mesh.inner_radius = 0.06
		emblem_mesh.outer_radius = 0.14
		emblem_mesh.ring_segments = 24
		emblem_mesh.rings = 16
		emblem.mesh = emblem_mesh
		emblem.position = Vector3(side * 0.72, 0.65, -0.18)
		emblem.rotation = Vector3(0, side * PI/6, 0)
		emblem.material_override = _create_emissive_material(Color(0.9, 0.7, 0.2), 1.5)
		parent.add_child(emblem)

func _create_lighting_effects(parent: Node3D) -> void:
	# Main spotlight from visor
	var visor_light := SpotLight3D.new()
	visor_light.name = "VisorLight"
	visor_light.light_color = Color(0.3, 0.8, 1.0)
	visor_light.light_energy = 2.0
	visor_light.spot_range = 8.0
	visor_light.spot_angle = 25.0
	visor_light.position = Vector3(0, 1.1, -0.3)
	visor_light.rotation = Vector3(-0.1, 0, 0)
	parent.add_child(visor_light)

	# Ambient glow around power core
	var core_light := OmniLight3D.new()
	core_light.name = "CoreLight"
	core_light.light_color = Color(0.2, 0.6, 1.0)
	core_light.light_energy = 1.5
	core_light.omni_range = 3.0
	core_light.position = Vector3(0, 0.2, 0.5)
	parent.add_child(core_light)

	# Thruster lights
	for i in [-1, 1]:
		var thruster_light := OmniLight3D.new()
		thruster_light.name = "ThrusterLight" + str(i)
		thruster_light.light_color = Color(1.0, 0.6, 0.3)
		thruster_light.light_energy = 1.8
		thruster_light.omni_range = 2.0
		thruster_light.position = Vector3(i * 0.18, -0.5, 0.55)
		parent.add_child(thruster_light)

func _create_animated_parts(parent: Node3D) -> void:
	# Create rotating radar dish on shoulder
	var radar := MeshInstance3D.new()
	radar.name = "RadarDish"
	var radar_tool := SurfaceTool.new()
	radar_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Dish base
	var dish_base := CylinderMesh.new()
	dish_base.height = 0.08
	dish_base.top_radius = 0.02
	dish_base.bottom_radius = 0.06
	dish_base.radial_segments = 16
	radar_tool.append_from(dish_base, 0, Transform3D.IDENTITY)

	# Dish
	var dish := TorusMesh.new()
	dish.inner_radius = 0.02
	dish.outer_radius = 0.18
	dish.ring_segments = 24
	dish.rings = 8
	radar_tool.append_from(dish, 0, Transform3D(Basis.from_euler(Vector3(-PI/4, 0, 0)), Vector3(0, 0.12, 0.08)))

	radar.mesh = radar_tool.commit()
	radar.position = Vector3(0.55, 0.85, -0.1)
	radar.material_override = _create_metallic_material(Color(0.5, 0.52, 0.58), 0.2, 0.85)
	radar.set_meta("animated", true)
	parent.add_child(radar)

func _process(delta: float) -> void:
	# Animate rotating parts
	var showcase := get_node_or_null("ShowcaseObject")
	if showcase:
		var radar := showcase.get_node_or_null("RadarDish")
		if radar:
			radar.rotate_y(delta * 2.5)

		# Subtle bobbing animation for the whole mech
		showcase.position.y = sin(Time.get_ticks_msec() * 0.001 * 1.5) * 0.03

		# Pulsing lights
		var core_light := showcase.get_node_or_null("CoreLight") as OmniLight3D
		if core_light:
			core_light.light_energy = 1.2 + sin(Time.get_ticks_msec() * 0.003) * 0.5

## Material creation helpers

func _create_metallic_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	mat.metallic_specular = 0.6

	# Add subtle ambient occlusion effect
	mat.ao_enabled = true
	mat.ao_light_affect = 0.3

	# Normal detail for surface texture feel
	mat.detail_enabled = false

	return mat

func _create_emissive_material(color: Color, emission_strength: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = emission_strength
	mat.metallic = 0.1
	mat.roughness = 0.2

	# Make it look like a light source
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	return mat

## Public interface for external access

func get_showcase_info() -> Dictionary:
	return {
		"name": "Advanced Mech Showcase",
		"parts_count": _count_parts(),
		"mesh_types_used": ["box", "cylinder", "capsule", "prism", "torus"],
		"material_types": ["metallic PBR", "emissive"],
		"lighting": ["SpotLight3D", "OmniLight3D"],
		"animations": ["rotation", "bobbing", "pulsing"],
		"description": "A procedurally generated mech demonstrating advanced 3D modeling in Godot"
	}

func _count_parts() -> int:
	var showcase := get_node_or_null("ShowcaseObject")
	if showcase:
		return _count_children_recursive(showcase)
	return 0

func _count_children_recursive(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_children_recursive(child)
	return count
