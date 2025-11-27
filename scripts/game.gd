extends Node3D

const WeaponData = preload("res://scripts/weapon_data.gd")

const DEFAULT_PLAYER_SCENE := preload("res://scenes/Player.tscn")
const DEFAULT_ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const DEFAULT_RANGED_ENEMY_SCENE := preload("res://scenes/RangedEnemy.tscn")
const DEFAULT_PICKUP_SCENE := preload("res://scenes/WeaponPickup.tscn")
const FIRE_LOOP := preload("res://audio/fire_sine.tres")
const HURT_TONE := preload("res://audio/hurt_sine.tres")
const STEP_TONE := preload("res://audio/step_sine.tres")

@export var grid_size := Vector2i(20, 20)
@export var tile_size := 6.5
@export var tile_height_variation := 1.2
@export var cover_chance := 0.18
@export var vertical_feature_chance := 0.22
@export var auto_start := false
@export var player_scene: PackedScene = DEFAULT_PLAYER_SCENE
@export var enemy_scene: PackedScene = DEFAULT_ENEMY_SCENE
@export var ranged_enemy_scene: PackedScene = DEFAULT_RANGED_ENEMY_SCENE
@export var pickup_scene: PackedScene = DEFAULT_PICKUP_SCENE

var floor_positions: Array = []
var spawn_positions: Array = []
var height_map: Array = []
var height_range := Vector2.ZERO
var player: Node3D
var rng := RandomNumberGenerator.new()
var game_over := false
var hazard_prefabs := {}
var height_noise := FastNoiseLite.new()
var menu_controller: Node
var pending_settings := {
    "sensitivity": 0.002,
    "master_volume": 1.0,
}
var particle_pool := {}
var pool_root: Node3D

@onready var level_root: Node3D = $Level
@onready var pickup_root: Node3D = $Pickups
@onready var enemy_root: Node3D = $Enemies
@onready var hud = $HUD
@onready var menu = $Menu

func _ready():
    rng.randomize()
    height_noise.seed = randi()
    height_noise.frequency = 0.07
    height_noise.fractal_octaves = 3
    pool_root = Node3D.new()
    pool_root.name = "Pool"
    add_child(pool_root)
    _ensure_default_input()
    player_scene = player_scene if player_scene else DEFAULT_PLAYER_SCENE
    enemy_scene = enemy_scene if enemy_scene else DEFAULT_ENEMY_SCENE
    ranged_enemy_scene = ranged_enemy_scene if ranged_enemy_scene else DEFAULT_RANGED_ENEMY_SCENE
    pickup_scene = pickup_scene if pickup_scene else DEFAULT_PICKUP_SCENE
    if hud and hud.has_signal("restart_requested"):
        hud.restart_requested.connect(restart_requested)
    if auto_start:
        start_round()
    else:
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _ensure_default_input():
    _ensure_action("move_forward", [_key(KEY_W), _key(KEY_UP), _joy_axis(1, -1.0)])
    _ensure_action("move_backward", [_key(KEY_S), _key(KEY_DOWN), _joy_axis(1, 1.0)])
    _ensure_action("move_left", [_key(KEY_A), _key(KEY_LEFT), _joy_axis(0, -1.0)])
    _ensure_action("move_right", [_key(KEY_D), _key(KEY_RIGHT), _joy_axis(0, 1.0)])
    _ensure_action("jump", [_key(KEY_SPACE), _joy_button(0)])
    _ensure_action("fire", [_mouse_button(MOUSE_BUTTON_LEFT), _mouse_button(MOUSE_BUTTON_RIGHT)])
    _ensure_action("switch_next", [_key(KEY_Q), _mouse_button(MOUSE_BUTTON_WHEEL_UP)])
    _ensure_action("switch_prev", [_key(KEY_E), _mouse_button(MOUSE_BUTTON_WHEEL_DOWN)])
    _ensure_action("sprint", [_key(KEY_SHIFT)])
    _ensure_action("crouch", [_key(KEY_CTRL), _key(KEY_C)])

func _ensure_action(action_name: String, events: Array):
    if not InputMap.has_action(action_name):
        InputMap.add_action(action_name)
    if InputMap.action_get_events(action_name).is_empty():
        for event in events:
            if event:
                InputMap.action_add_event(action_name, event)

func _key(code: int) -> InputEventKey:
    var ev := InputEventKey.new()
    ev.keycode = code
    ev.physical_keycode = code
    return ev

func _mouse_button(index: int) -> InputEventMouseButton:
    var ev := InputEventMouseButton.new()
    ev.button_index = index
    return ev

func _joy_button(index: int) -> InputEventJoypadButton:
    var ev := InputEventJoypadButton.new()
    ev.button_index = index
    return ev

func _joy_axis(axis: int, sign: float) -> InputEventJoypadMotion:
    var ev := InputEventJoypadMotion.new()
    ev.axis = axis
    ev.axis_value = sign
    return ev

func _make_looping_player(stream: AudioStream, volume_db := -8.0, pitch_scale := 1.0, max_distance := 40.0, autoplay := true) -> AudioStreamPlayer3D:
    var player := AudioStreamPlayer3D.new()
    player.stream = stream
    player.volume_db = volume_db
    player.pitch_scale = pitch_scale
    player.max_distance = max_distance
    player.autoplay = autoplay
    return player

func _add_light_flicker(light: Light3D, base_energy: float, variance: float, period := 0.75):
    if not light:
        return
    light.light_energy = base_energy
    var flicker := create_tween().set_loops()
    flicker.tween_property(light, "light_energy", base_energy + variance, period * rng.randf_range(0.45, 0.8)).set_trans(Tween.TRANS_SINE)
    flicker.tween_property(light, "light_energy", base_energy - variance * 0.6, period * rng.randf_range(0.45, 0.8)).set_trans(Tween.TRANS_SINE)

func _cache_prefab(key: String, root: Node3D):
    var prefab := PackedScene.new()
    if prefab.pack(root) == OK:
        hazard_prefabs[key] = prefab

func _stash_pooled_particles(node: CPUParticles3D):
    var key: String = node.get_meta("pool_key", "")
    if key.is_empty():
        node.queue_free()
        return
    if not particle_pool.has(key):
        particle_pool[key] = []
    node.emitting = false
    node.visible = false
    node.reparent(pool_root)
    particle_pool[key].append(node)

func _get_pooled_particles(key: String, builder: Callable) -> CPUParticles3D:
    var stash: Array = particle_pool.get(key, [])
    if not stash.is_empty():
        var node: CPUParticles3D = stash.pop_back()
        node.visible = true
        return node
    var created: CPUParticles3D = builder.call()
    created.set_meta("pool_key", key)
    return created

func start_round():
    game_over = false
    get_tree().paused = false
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    clear_game()
    generate_level()
    spawn_player()
    spawn_pickups()
    spawn_enemies()
    if hud and hud.has_method("hide_status"):
        hud.hide_status()
    if menu_controller and menu_controller.has_method("sync_after_start"):
        menu_controller.sync_after_start()

func clear_game():
    floor_positions.clear()
    spawn_positions.clear()
    height_map.clear()
    for child in level_root.get_children():
        if child is CPUParticles3D:
            _stash_pooled_particles(child)
        else:
            child.queue_free()
    for child in pickup_root.get_children():
        child.queue_free()
    for child in enemy_root.get_children():
        child.queue_free()
    if is_instance_valid(player):
        player.queue_free()

func generate_level():
    height_map = _build_flat_height_map()
    height_range = Vector2(0.0, 9.5)
    _build_factory_blockout()
    _add_boundary_walls(height_range)
    if floor_positions.is_empty():
        _record_flat_spawns()
    if spawn_positions.is_empty():
        spawn_positions.append(_choose_center_spawn())

func _build_flat_height_map() -> Array:
    var heights: Array = []
    for x in range(grid_size.x):
        heights.append([])
        for y in range(grid_size.y):
            heights[x].append(0.0)
    return heights

func _record_flat_spawns():
    floor_positions.clear()
    spawn_positions.clear()
    var center := Vector3(grid_size.x * tile_size * 0.5, 0.0, grid_size.y * tile_size * 0.5)
    floor_positions.append(center + Vector3(0, 0.55, 0))
    spawn_positions.append(center + Vector3(0, 0.9, 0))

func _build_flat_floor():
    var floor_body := StaticBody3D.new()
    floor_body.name = "FlatFloor"

    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    var length_x := grid_size.x * tile_size
    var length_z := grid_size.y * tile_size
    var thickness := 1.0
    mesh.size = Vector3(length_x, thickness, length_z)
    mesh_instance.mesh = mesh
    mesh_instance.material_override = preload("res://materials/tile_material.tres")
    mesh_instance.position = Vector3(length_x * 0.5, -thickness * 0.5, length_z * 0.5)
    floor_body.add_child(mesh_instance)

    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = mesh.size
    collider.shape = shape
    collider.position = mesh_instance.position
    floor_body.add_child(collider)

    level_root.add_child(floor_body)

func _build_factory_blockout():
    var playfield := Vector2(grid_size.x * tile_size, grid_size.y * tile_size)
    var floor_material := _make_factory_floor_material()
    var accent_material := _make_accent_material(Color(1.0, 0.38, 0.14), 1.55)
    var secondary_material := _make_accent_material(Color(0.76, 0.34, 0.2), 0.9)

    _create_floor_plate("BaseFloor", playfield + Vector2(10, 10), Vector3(playfield.x * 0.5, -0.4, playfield.y * 0.5), floor_material, 1.2)

    var halls := [
        {"name": "AssemblyHall", "center": Vector3(playfield.x * 0.26, 0, playfield.y * 0.3), "size": Vector2(34, 24)},
        {"name": "SmelterHall", "center": Vector3(playfield.x * 0.72, 0, playfield.y * 0.32), "size": Vector2(32, 22)},
        {"name": "ShippingHall", "center": Vector3(playfield.x * 0.3, 0, playfield.y * 0.76), "size": Vector2(36, 24)},
        {"name": "CoolingHall", "center": Vector3(playfield.x * 0.74, 0, playfield.y * 0.74), "size": Vector2(30, 22)},
        {"name": "CentralAtrium", "center": Vector3(playfield.x * 0.5, 0, playfield.y * 0.54), "size": Vector2(34, 26)},
    ]

    var walkable_regions: Array = []
    var nav_blockers: Array = []

    for hall in halls:
        _create_floor_plate(hall["name"], hall["size"], hall["center"], floor_material, 0.55)
        _register_zone_positions(hall["center"], hall["size"], 4)
        _decorate_hall_edges(hall["center"], hall["size"], accent_material)
        _scatter_supports(hall["center"], hall["size"], 2, secondary_material)
        walkable_regions.append(_rect_from_center_size(hall["center"], hall["size"]))

    var corridors := [
        {"name": "CentralSpine", "center": Vector3(playfield.x * 0.5, 0, playfield.y * 0.55), "size": Vector2(78, 10)},
        {"name": "NorthLink", "center": Vector3(playfield.x * 0.5, 0, playfield.y * 0.32), "size": Vector2(18, 8)},
        {"name": "SouthLink", "center": Vector3(playfield.x * 0.5, 0, playfield.y * 0.78), "size": Vector2(18, 8)},
        {"name": "EastSpur", "center": Vector3(playfield.x * 0.68, 0, playfield.y * 0.54), "size": Vector2(12, 34)},
        {"name": "WestSpur", "center": Vector3(playfield.x * 0.32, 0, playfield.y * 0.54), "size": Vector2(12, 34)},
    ]

    for corridor in corridors:
        _build_corridor(corridor, floor_material, accent_material)
        walkable_regions.append(_rect_from_center_size(corridor["center"], corridor["size"]))

    var conveyor_defs := [
        {"name": "AssemblyBelt", "center": Vector3(playfield.x * 0.26, 0.05, playfield.y * 0.3), "size": Vector2(22, 6), "dir": Vector3(1, 0, 0), "speed": 26.0},
        {"name": "SmelterBelt", "center": Vector3(playfield.x * 0.72, 0.05, playfield.y * 0.32), "size": Vector2(20, 6), "dir": Vector3(-1, 0, 0), "speed": 22.0},
        {"name": "AtriumLoop", "center": Vector3(playfield.x * 0.5, 0.05, playfield.y * 0.54), "size": Vector2(14, 8), "dir": Vector3(0, 0, -1), "speed": 18.0, "damage": 6.0},
    ]

    var press_defs := [
        {"name": "AtriumPress", "center": Vector3(playfield.x * 0.5, 0, playfield.y * 0.6), "size": Vector2(8, 8), "depth": 2.4, "cycle": 1.6},
        {"name": "ShippingPress", "center": Vector3(playfield.x * 0.3, 0, playfield.y * 0.78), "size": Vector2(6, 8), "depth": 2.0, "cycle": 1.9},
        {"name": "CoolingPress", "center": Vector3(playfield.x * 0.74, 0, playfield.y * 0.74), "size": Vector2(6, 6), "depth": 1.8, "cycle": 1.7},
    ]

    var arm_defs := [
        {"name": "NorthArm", "start": Vector3(playfield.x * 0.3, 1.2, playfield.y * 0.22), "end": Vector3(playfield.x * 0.7, 1.2, playfield.y * 0.22), "lift": 8.0},
        {"name": "CentralArm", "start": Vector3(playfield.x * 0.22, 1.4, playfield.y * 0.52), "end": Vector3(playfield.x * 0.22, 1.4, playfield.y * 0.86), "lift": 7.2},
        {"name": "SouthArm", "start": Vector3(playfield.x * 0.58, 1.2, playfield.y * 0.82), "end": Vector3(playfield.x * 0.82, 1.2, playfield.y * 0.64), "lift": 9.0},
    ]

    var furnace_defs := [
        {"name": "SmelterUpdraft", "center": Vector3(playfield.x * 0.72, 0, playfield.y * 0.42), "radius": 2.4, "height": 10.0, "force": 22.0},
        {"name": "AssemblyUpdraft", "center": Vector3(playfield.x * 0.24, 0, playfield.y * 0.38), "radius": 2.2, "height": 9.0, "force": 19.0},
        {"name": "CoolingUpdraft", "center": Vector3(playfield.x * 0.64, 0, playfield.y * 0.64), "radius": 2.6, "height": 11.0, "force": 24.0},
    ]

    for press_def in press_defs:
        nav_blockers.append(_rect_from_center_size(press_def["center"], press_def["size"] * 0.9))
    for furnace_def in furnace_defs:
        nav_blockers.append(_rect_from_center_size(furnace_def["center"], Vector2(furnace_def["radius"] * 2.0, furnace_def["radius"] * 1.8)))

    _add_conveyor_accelerators(playfield, accent_material, secondary_material, conveyor_defs)
    _add_press_lanes(playfield, accent_material, press_defs)
    _add_robotic_arm_rails(playfield, accent_material, arm_defs)
    _add_updraft_furnaces(playfield, accent_material, secondary_material, furnace_defs)
    _add_factory_fx(playfield)
    _build_navigation_layout(walkable_regions, nav_blockers)

func _make_factory_floor_material() -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.12, 0.17, 0.22)
    mat.metallic = 0.26
    mat.roughness = 0.44
    mat.emission_enabled = true
    mat.emission = Color(0.08, 0.1, 0.14)
    mat.emission_energy_multiplier = 1.1
    return mat

func _make_accent_material(color: Color, emission_strength := 1.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.12
    mat.roughness = 0.42
    mat.emission_enabled = true
    mat.emission = color * 0.7
    mat.emission_energy_multiplier = emission_strength
    return mat

func _create_floor_plate(name: String, size: Vector2, center: Vector3, material: StandardMaterial3D, thickness := 0.6):
    var body := StaticBody3D.new()
    body.name = name

    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(size.x, thickness, size.y)
    mesh_instance.mesh = mesh
    mesh_instance.material_override = material
    mesh_instance.position = Vector3(0, -thickness * 0.5, 0)
    body.add_child(mesh_instance)

    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = mesh.size
    collider.shape = shape
    collider.position = mesh_instance.position
    body.add_child(collider)

    body.position = center
    level_root.add_child(body)

func _build_corridor(definition: Dictionary, floor_material: StandardMaterial3D, accent_material: StandardMaterial3D):
    var size: Vector2 = definition.get("size", Vector2(16, 8))
    var center: Vector3 = definition.get("center", Vector3.ZERO)
    var name: String = definition.get("name", "Corridor")
    var thickness: float = definition.get("thickness", 0.4)

    _create_floor_plate(name, size, center, floor_material, thickness)
    _register_zone_positions(center, size * 0.6, 2)
    _add_corridor_guardrails(center, size, accent_material)

func _register_zone_positions(center: Vector3, size: Vector2, count := 3):
    var half_x := size.x * 0.5
    var half_z := size.y * 0.5
    for i in range(count):
        var offset := Vector3(
            rng.randf_range(-half_x * 0.6, half_x * 0.6),
            0.0,
            rng.randf_range(-half_z * 0.6, half_z * 0.6)
        )
        var spot := center + offset
        floor_positions.append(spot + Vector3(0, 0.55, 0))
        spawn_positions.append(spot + Vector3(0, 0.9, 0))

func _add_corridor_guardrails(center: Vector3, size: Vector2, material: StandardMaterial3D):
    var wall_height := 4.6
    var wall_thickness := 0.7
    var half_x := size.x * 0.5
    var half_z := size.y * 0.5
    var horizontal := size.x >= size.y

    if horizontal:
        _create_wall_strip(Vector3(size.x + wall_thickness * 2.0, wall_height, wall_thickness), Vector3(center.x, wall_height * 0.5, center.z - half_z - wall_thickness * 0.5), material)
        _create_wall_strip(Vector3(size.x + wall_thickness * 2.0, wall_height, wall_thickness), Vector3(center.x, wall_height * 0.5, center.z + half_z + wall_thickness * 0.5), material)
    else:
        _create_wall_strip(Vector3(wall_thickness, wall_height, size.y + wall_thickness * 2.0), Vector3(center.x - half_x - wall_thickness * 0.5, wall_height * 0.5, center.z), material)
        _create_wall_strip(Vector3(wall_thickness, wall_height, size.y + wall_thickness * 2.0), Vector3(center.x + half_x + wall_thickness * 0.5, wall_height * 0.5, center.z), material)

    for i in range(2):
        var light := OmniLight3D.new()
        light.light_color = Color(1.0, 0.46, 0.26)
        light.light_energy = 2.2
        light.omni_range = max(size.x, size.y) * 0.6
        var direction := i * 2 - 1
        var offset := Vector3(direction * min(4.5, half_x * 0.6), 1.6, 0) if horizontal else Vector3(0, 1.6, direction * min(4.5, half_z * 0.6))
        light.position = center + offset
        level_root.add_child(light)


func _add_conveyor_accelerators(playfield: Vector2, accent_material: StandardMaterial3D, tread_material: StandardMaterial3D, conveyor_defs: Array):
    for def in conveyor_defs:
        _create_conveyor_belt(def, accent_material, tread_material)

func _create_conveyor_belt(def: Dictionary, accent_material: StandardMaterial3D, tread_material: StandardMaterial3D):
    var name: String = def.get("name", "Conveyor")
    var center: Vector3 = def.get("center", Vector3.ZERO)
    var size: Vector2 = def.get("size", Vector2(18, 6))
    var direction: Vector3 = def.get("dir", Vector3.FORWARD)
    var speed: float = def.get("speed", 18.0)
    var damage: float = def.get("damage", 0.0)

    var root := Node3D.new()
    root.name = name
    root.position = center

    var base := StaticBody3D.new()
    var base_mesh := BoxMesh.new()
    base_mesh.size = Vector3(size.x, 0.45, size.y)
    var base_instance := MeshInstance3D.new()
    base_instance.mesh = base_mesh
    base_instance.material_override = accent_material
    base_instance.position = Vector3.ZERO
    base_instance.visibility_range_begin = 10.0
    base_instance.visibility_range_end = 160.0
    base_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DEPENDENCIES
    base.add_child(base_instance)

    var base_collision := CollisionShape3D.new()
    var base_shape := BoxShape3D.new()
    base_shape.size = base_mesh.size
    base_collision.shape = base_shape
    base_collision.position = base_instance.position
    base.add_child(base_collision)
    root.add_child(base)

    var tread := MeshInstance3D.new()
    var tread_mesh := BoxMesh.new()
    tread_mesh.size = Vector3(size.x * 0.96, 0.08, size.y * 0.92)
    tread.mesh = tread_mesh
    var tread_mat := StandardMaterial3D.new()
    tread_mat.albedo_color = tread_material.albedo_color.darkened(0.25)
    tread_mat.metallic = tread_material.metallic
    tread_mat.roughness = 0.32
    tread_mat.emission_enabled = true
    tread_mat.emission = tread_material.albedo_color * 0.4
    tread_mat.emission_energy_multiplier = 1.4
    tread.material_override = tread_mat
    tread.position = Vector3(0, 0.28, 0)
    tread.visibility_range_begin = 10.0
    tread.visibility_range_end = 150.0
    tread.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DEPENDENCIES
    root.add_child(tread)

    var arrow := MeshInstance3D.new()
    var arrow_mesh := BoxMesh.new()
    arrow_mesh.size = Vector3(1.4, 0.04, size.y * 0.2)
    arrow.mesh = arrow_mesh
    arrow.material_override = tread_material
    arrow.position = Vector3(0, 0.35, -size.y * 0.26 if direction.z > 0 else size.y * 0.26)
    arrow.rotation_degrees.y = rad_to_deg(atan2(direction.x, direction.z))
    arrow.visibility_range_begin = 8.0
    arrow.visibility_range_end = 120.0
    root.add_child(arrow)

    var belt_spot := SpotLight3D.new()
    belt_spot.light_color = Color(1.0, 0.42, 0.26)
    belt_spot.light_energy = 3.0
    belt_spot.spot_angle = 46.0
    belt_spot.spot_range = max(size.x, size.y) * 0.9
    belt_spot.position = Vector3(0, 3.0, 0)
    belt_spot.look_at(direction.normalized() * 3.0, Vector3.UP)
    _add_light_flicker(belt_spot, 3.0, 0.9, 0.7)
    root.add_child(belt_spot)

    var conveyor_audio := _make_looping_player(FIRE_LOOP, -9.0, 0.75, 48.0)
    conveyor_audio.position = Vector3(0, 1.4, 0)
    root.add_child(conveyor_audio)

    var area := Area3D.new()
    area.name = "%s_Area" % name
    area.gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
    area.gravity_direction = direction.normalized()
    area.gravity = speed
    area.priority = 2
    var shape := BoxShape3D.new()
    shape.size = Vector3(size.x * 0.95, 1.2, size.y * 0.95)
    var collider := CollisionShape3D.new()
    collider.shape = shape
    collider.position = Vector3(0, 0.75, 0)
    area.add_child(collider)
    if damage > 0.0:
        area.body_entered.connect(func(body):
            if body and body.has_method("take_damage"):
                body.take_damage(damage)
        )
    root.add_child(area)

    var end_light := OmniLight3D.new()
    end_light.light_color = Color(1.0, 0.52, 0.22)
    end_light.light_energy = 2.0
    end_light.omni_range = max(size.x, size.y) * 0.8
    end_light.position = Vector3(direction.normalized().x * size.x * 0.5, 1.2, direction.normalized().z * size.y * 0.5)
    root.add_child(end_light)

    _cache_prefab(name, root)
    level_root.add_child(root)

func _add_press_lanes(playfield: Vector2, accent_material: StandardMaterial3D, press_defs: Array):
    for def in press_defs:
        _create_press(def, accent_material)

func _create_press(def: Dictionary, accent_material: StandardMaterial3D):
    var name: String = def.get("name", "Press")
    var center: Vector3 = def.get("center", Vector3.ZERO)
    var size: Vector2 = def.get("size", Vector2(6, 6))
    var depth: float = def.get("depth", 2.0)
    var cycle: float = def.get("cycle", 1.8)

    var root := Node3D.new()
    root.name = name
    root.position = center

    var frame := StaticBody3D.new()
    var frame_mesh := BoxMesh.new()
    frame_mesh.size = Vector3(size.x * 0.8, 3.4, size.y * 0.8)
    var frame_instance := MeshInstance3D.new()
    frame_instance.mesh = frame_mesh
    var frame_material := StandardMaterial3D.new()
    frame_material.albedo_color = Color(0.16, 0.2, 0.22)
    frame_material.metallic = 0.18
    frame_material.roughness = 0.44
    frame_instance.material_override = frame_material
    frame_instance.position = Vector3(0, frame_mesh.size.y * 0.5, 0)
    frame_instance.visibility_range_begin = 12.0
    frame_instance.visibility_range_end = 140.0
    frame_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DEPENDENCIES
    frame.add_child(frame_instance)

    var frame_collider := CollisionShape3D.new()
    var frame_shape := BoxShape3D.new()
    frame_shape.size = frame_mesh.size
    frame_collider.shape = frame_shape
    frame_collider.position = frame_instance.position
    frame.add_child(frame_collider)
    root.add_child(frame)

    var head := StaticBody3D.new()
    head.name = "%sHead" % name
    var head_mesh := BoxMesh.new()
    head_mesh.size = Vector3(size.x * 0.65, 0.8, size.y * 0.65)
    var head_instance := MeshInstance3D.new()
    head_instance.mesh = head_mesh
    head_instance.material_override = accent_material
    head_instance.position = Vector3(0, 3.5, 0)
    head_instance.visibility_range_begin = 10.0
    head_instance.visibility_range_end = 120.0
    head_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DEPENDENCIES
    head.add_child(head_instance)

    var head_collider := CollisionShape3D.new()
    var head_shape := BoxShape3D.new()
    head_shape.size = head_mesh.size
    head_collider.shape = head_shape
    head_collider.position = head_instance.position
    head.add_child(head_collider)

    var kill_area := Area3D.new()
    kill_area.monitoring = true
    kill_area.monitorable = true
    var kill_shape := BoxShape3D.new()
    kill_shape.size = Vector3(head_mesh.size.x * 0.8, depth + head_mesh.size.y * 0.5, head_mesh.size.z * 0.8)
    var kill_collider := CollisionShape3D.new()
    kill_collider.shape = kill_shape
    kill_collider.position = Vector3(0, -kill_shape.size.y * 0.5, 0)
    kill_area.add_child(kill_collider)
    kill_area.body_entered.connect(_apply_lethal_damage)
    head.add_child(kill_area)

    var warning_light := OmniLight3D.new()
    warning_light.light_color = Color(1.0, 0.44, 0.16)
    warning_light.light_energy = 1.4
    warning_light.omni_range = max(size.x, size.y) * 2.4
    warning_light.position = Vector3(0, head_instance.position.y + 0.4, 0)
    root.add_child(warning_light)

    var press_spot := SpotLight3D.new()
    press_spot.light_color = Color(1.0, 0.28, 0.16)
    press_spot.light_energy = 3.6
    press_spot.spot_angle = 48.0
    press_spot.spot_range = max(size.x, size.y) * 1.4
    press_spot.position = Vector3(0, 4.0, 0)
    press_spot.look_at(Vector3(0, 2.0, 0), Vector3.UP)
    _add_light_flicker(press_spot, 3.6, 1.2, 0.62)
    root.add_child(press_spot)

    var hydraulic_hum := _make_looping_player(FIRE_LOOP, -8.0, 0.55, 36.0)
    hydraulic_hum.position = Vector3(0, 1.4, 0)
    root.add_child(hydraulic_hum)

    var slam_clang := _make_looping_player(HURT_TONE, -4.5, 0.9, 28.0, false)
    slam_clang.position = Vector3(0, 1.0, 0)
    root.add_child(slam_clang)
    _add_light_flicker(warning_light, warning_light.light_energy, 1.0, 0.7)

    var press_nav := _make_local_nav_region("%sNavGate" % name, Rect2(-size.x * 0.35, -size.y * 0.35, size.x * 0.7, size.y * 0.7))
    root.add_child(press_nav)

    var press_tween := create_tween().set_loops()
    press_tween.tween_property(head, "position:y", 0.4 + depth * 0.1, cycle * 0.32).set_delay(0.2)
    press_tween.tween_callback(func(): press_nav.enabled = true)
    press_tween.tween_callback(func(): warning_light.light_energy = 3.2)
    press_tween.tween_callback(func(): slam_clang.play())
    press_tween.tween_property(head, "position:y", -depth, cycle * 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    press_tween.tween_callback(func(): press_nav.enabled = false)
    press_tween.tween_callback(func(): warning_light.light_energy = 1.2)
    press_tween.tween_property(head, "position:y", 3.5, cycle * 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
    press_tween.tween_interval(0.1)

    root.add_child(head)
    _cache_prefab(name, root)
    level_root.add_child(root)

func _add_robotic_arm_rails(playfield: Vector2, accent_material: StandardMaterial3D, arm_defs: Array):
    for def in arm_defs:
        _create_robotic_arm(def, accent_material)

func _create_robotic_arm(def: Dictionary, accent_material: StandardMaterial3D):
    var name: String = def.get("name", "RoboArm")
    var start: Vector3 = def.get("start", Vector3.ZERO)
    var end: Vector3 = def.get("end", Vector3.ZERO)
    var lift_force: float = def.get("lift", 8.0)

    var root := Node3D.new()
    root.name = name
    var mid := (start + end) * 0.5
    root.position = mid

    var rail := MeshInstance3D.new()
    var rail_mesh := BoxMesh.new()
    var span := end - start
    rail_mesh.size = Vector3(span.length(), 0.3, 0.5)
    rail.mesh = rail_mesh
    rail.position = Vector3.ZERO
    rail.look_at(span)
    var rail_material := StandardMaterial3D.new()
    rail_material.albedo_color = Color(0.18, 0.21, 0.25)
    rail_material.metallic = 0.2
    rail_material.roughness = 0.36
    rail.material_override = rail_material
    rail.visibility_range_begin = 16.0
    rail.visibility_range_end = 160.0
    rail.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DEPENDENCIES
    root.add_child(rail)

    var arm := StaticBody3D.new()
    arm.name = "%sPlatform" % name
    var pad := MeshInstance3D.new()
    var pad_mesh := CylinderMesh.new()
    pad_mesh.top_radius = 0.9
    pad_mesh.bottom_radius = 1.0
    pad_mesh.height = 0.5
    pad.mesh = pad_mesh
    pad.material_override = accent_material
    pad.position = Vector3.ZERO
    pad.visibility_range_begin = 12.0
    pad.visibility_range_end = 130.0
    pad.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
    arm.add_child(pad)

    var pad_collision := CollisionShape3D.new()
    var pad_shape := CylinderShape3D.new()
    pad_shape.radius = pad_mesh.bottom_radius
    pad_shape.height = pad_mesh.height
    pad_collision.shape = pad_shape
    pad_collision.position = Vector3.ZERO
    arm.add_child(pad_collision)

    var launch_area := Area3D.new()
    var launch_shape := CylinderShape3D.new()
    launch_shape.radius = pad_mesh.bottom_radius * 0.95
    launch_shape.height = 1.6
    var launch_collider := CollisionShape3D.new()
    launch_collider.shape = launch_shape
    launch_collider.position = Vector3(0, 0.9, 0)
    launch_area.add_child(launch_collider)
    launch_area.body_entered.connect(func(body):
        if body is CharacterBody3D:
            var vel: Vector3 = body.velocity
            vel.y = max(vel.y, lift_force)
            body.velocity = vel
    )
    arm.add_child(launch_area)
    root.add_child(arm)

    var tween := create_tween().set_loops()
    var duration: float = max(2.6, span.length() * 0.14)
    arm.position = start - mid
    var arc_sound := _make_looping_player(STEP_TONE, -6.0, 1.2, 28.0, false)
    arc_sound.position = Vector3(0, 1.0, 0)
    root.add_child(arc_sound)
    tween.tween_property(arm, "position", end - mid + Vector3(0, 0.2, 0), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.tween_callback(func(): arc_sound.play())
    tween.tween_property(arm, "position", start - mid, duration * 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.tween_callback(func(): arc_sound.play())
    tween.tween_interval(0.35)

    var light := OmniLight3D.new()
    light.light_color = Color(1.0, 0.42, 0.26)
    light.light_energy = 1.6
    light.omni_range = 8.0
    light.position = Vector3(0, 1.1, 0)
    arm.add_child(light)
    _add_light_flicker(light, light.light_energy, 0.6, 0.55)

    var arc_particles := CPUParticles3D.new()
    arc_particles.amount = 18
    arc_particles.lifetime = 0.4
    arc_particles.preprocess = 0.2
    arc_particles.emitting = true
    arc_particles.one_shot = false
    arc_particles.direction = Vector3(0.2, 1.0, 0)
    arc_particles.gravity = Vector3(0, -1.4, 0)
    arc_particles.spread = 0.8
    arc_particles.initial_velocity_min = 6.0
    arc_particles.initial_velocity_max = 10.0
    arc_particles.scale_amount_min = 0.05
    arc_particles.scale_amount_max = 0.18
    arc_particles.color = Color(1.0, 0.56, 0.34, 0.8)
    arc_particles.position = Vector3(0, 0.7, 0)
    arc_particles.visibility_range_begin = 10.0
    arc_particles.visibility_range_end = 90.0
    arm.add_child(arc_particles)

    var travel_spot := SpotLight3D.new()
    travel_spot.light_color = Color(1.0, 0.36, 0.2)
    travel_spot.light_energy = 2.8
    travel_spot.spot_range = span.length() * 1.2
    travel_spot.spot_angle = 36.0
    travel_spot.position = Vector3(0, 3.6, 0)
    travel_spot.look_at(Vector3(0, 1.0, 0) + span.normalized(), Vector3.UP)
    _add_light_flicker(travel_spot, travel_spot.light_energy, 0.8, 0.68)
    root.add_child(travel_spot)

    _cache_prefab(name, root)
    level_root.add_child(root)

func _add_updraft_furnaces(playfield: Vector2, accent_material: StandardMaterial3D, secondary_material: StandardMaterial3D, furnace_defs: Array):
    for def in furnace_defs:
        _create_furnace(def, accent_material, secondary_material)

func _create_furnace(def: Dictionary, accent_material: StandardMaterial3D, secondary_material: StandardMaterial3D):
    var name: String = def.get("name", "Furnace")
    var center: Vector3 = def.get("center", Vector3.ZERO)
    var radius: float = def.get("radius", 2.2)
    var height: float = def.get("height", 10.0)
    var force: float = def.get("force", 18.0)

    var root := Node3D.new()
    root.name = name
    root.position = center

    var stack := MeshInstance3D.new()
    var stack_mesh := CylinderMesh.new()
    stack_mesh.top_radius = radius * 0.85
    stack_mesh.bottom_radius = radius
    stack_mesh.height = height
    stack.mesh = stack_mesh
    var stack_mat := StandardMaterial3D.new()
    stack_mat.albedo_color = Color(0.14, 0.16, 0.18)
    stack_mat.metallic = 0.14
    stack_mat.roughness = 0.38
    stack_mat.emission_enabled = true
    stack_mat.emission = Color(1.0, 0.46, 0.2) * 0.14
    stack_mat.emission_energy_multiplier = 1.1
    stack.material_override = stack_mat
    stack.position = Vector3(0, stack_mesh.height * 0.5, 0)
    stack.visibility_range_begin = 14.0
    stack.visibility_range_end = 180.0
    stack.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DEPENDENCIES
    root.add_child(stack)

    var furnace_light := OmniLight3D.new()
    furnace_light.light_color = Color(1.0, 0.36, 0.16)
    furnace_light.light_energy = 3.0
    furnace_light.omni_range = height * 0.9
    furnace_light.position = Vector3(0, height * 0.45, 0)
    _add_light_flicker(furnace_light, furnace_light.light_energy, 1.4, 0.64)
    root.add_child(furnace_light)

    var siren := _make_looping_player(HURT_TONE, -12.0, 0.58, 60.0)
    siren.position = Vector3(0, height * 0.6, 0)
    root.add_child(siren)

    var heat_rumble := _make_looping_player(FIRE_LOOP, -8.5, 0.92, 46.0)
    heat_rumble.position = Vector3(0, 0.6, 0)
    root.add_child(heat_rumble)

    var air_area := Area3D.new()
    air_area.gravity_space_override = Area3D.SPACE_OVERRIDE_COMBINE_REPLACE
    air_area.gravity_direction = Vector3.UP
    air_area.gravity = force
    var air_shape := CylinderShape3D.new()
    air_shape.radius = radius * 0.72
    air_shape.height = height * 0.9
    var air_collider := CollisionShape3D.new()
    air_collider.shape = air_shape
    air_collider.position = Vector3(0, air_shape.height * 0.5, 0)
    air_area.add_child(air_collider)
    root.add_child(air_area)

    var cap := StaticBody3D.new()
    var cap_mesh := BoxMesh.new()
    cap_mesh.size = Vector3(radius * 1.6, 0.6, radius * 1.6)
    var cap_instance := MeshInstance3D.new()
    cap_instance.mesh = cap_mesh
    cap_instance.material_override = secondary_material
    cap_instance.position = Vector3(0, height + 0.3, 0)
    cap.add_child(cap_instance)

    var cap_collider := CollisionShape3D.new()
    var cap_shape := BoxShape3D.new()
    cap_shape.size = cap_mesh.size
    cap_collider.shape = cap_shape
    cap_collider.position = cap_instance.position
    cap.add_child(cap_collider)
    root.add_child(cap)

    var platform := StaticBody3D.new()
    platform.name = "%sPlatform" % name
    var platform_mesh := BoxMesh.new()
    platform_mesh.size = Vector3(radius * 1.8, 0.5, radius * 1.1)
    var platform_instance := MeshInstance3D.new()
    platform_instance.mesh = platform_mesh
    platform_instance.material_override = accent_material
    platform_instance.position = Vector3(radius * 1.2, height * 0.8, 0)
    platform.add_child(platform_instance)
    var platform_collider := CollisionShape3D.new()
    var platform_shape := BoxShape3D.new()
    platform_shape.size = platform_mesh.size
    platform_collider.shape = platform_shape
    platform_collider.position = platform_instance.position
    platform.add_child(platform_collider)
    root.add_child(platform)

    floor_positions.append(center + platform_instance.position + Vector3(0, 0.6, 0))
    spawn_positions.append(center + platform_instance.position + Vector3(0, 0.95, 0))

    var flame := CPUParticles3D.new()
    flame.amount = 90
    flame.lifetime = 1.2
    flame.one_shot = false
    flame.emitting = true
    flame.preprocess = 0.4
    flame.gravity = Vector3(0, 0, 0)
    flame.direction = Vector3(0, 1, 0)
    flame.initial_velocity_min = force * 0.3
    flame.initial_velocity_max = force * 0.42
    flame.scale_amount_min = 0.4
    flame.scale_amount_max = 0.8
    flame.color = Color(1.0, 0.46, 0.2, 0.85)
    flame.position = Vector3(0, 0.4, 0)
    root.add_child(flame)

    _cache_prefab(name, root)
    level_root.add_child(root)

func _subtract_rect(rect: Rect2, hole: Rect2) -> Array:
    var remaining: Array = []
    var intersection := rect.intersection(hole)
    if not intersection.has_area():
        remaining.append(rect)
        return remaining

    var top_height := intersection.position.y - rect.position.y
    if top_height > 0.1:
        remaining.append(Rect2(rect.position.x, rect.position.y, rect.size.x, top_height))

    var bottom_y := intersection.position.y + intersection.size.y
    var bottom_height := (rect.position.y + rect.size.y) - bottom_y
    if bottom_height > 0.1:
        remaining.append(Rect2(rect.position.x, bottom_y, rect.size.x, bottom_height))

    var left_width := intersection.position.x - rect.position.x
    if left_width > 0.1:
        remaining.append(Rect2(rect.position.x, intersection.position.y, left_width, intersection.size.y))

    var right_x := intersection.position.x + intersection.size.x
    var right_width := (rect.position.x + rect.size.x) - right_x
    if right_width > 0.1:
        remaining.append(Rect2(right_x, intersection.position.y, right_width, intersection.size.y))

    return remaining

func _build_navigation_layout(walkable_regions: Array, blockers: Array):
    var safe_rects: Array = []
    for region in walkable_regions:
        var slices := [region]
        for block in blockers:
            var next_slices := []
            for slice in slices:
                next_slices.append_array(_subtract_rect(slice, block))
            slices = next_slices
        safe_rects.append_array(slices)

    if safe_rects.is_empty():
        return

    var nav_mesh := NavigationMesh.new()
    var vertices := PackedVector3Array()

    for rect in safe_rects:
        var base_index := vertices.size()
        vertices.append(Vector3(rect.position.x, 0.35, rect.position.y))
        vertices.append(Vector3(rect.position.x + rect.size.x, 0.35, rect.position.y))
        vertices.append(Vector3(rect.position.x + rect.size.x, 0.35, rect.position.y + rect.size.y))
        vertices.append(Vector3(rect.position.x, 0.35, rect.position.y + rect.size.y))
        nav_mesh.add_polygon(PackedInt32Array([base_index, base_index + 1, base_index + 2, base_index + 3]))

    nav_mesh.vertices = vertices

    var region := NavigationRegion3D.new()
    region.name = "FactoryNav"
    region.navigation_mesh = nav_mesh
    region.navigation_layers = 1
    level_root.add_child(region)

func _make_local_nav_region(name: String, rect: Rect2) -> NavigationRegion3D:
    var nav_mesh := NavigationMesh.new()
    var vertices := PackedVector3Array([
        Vector3(rect.position.x, 0.32, rect.position.y),
        Vector3(rect.position.x + rect.size.x, 0.32, rect.position.y),
        Vector3(rect.position.x + rect.size.x, 0.32, rect.position.y + rect.size.y),
        Vector3(rect.position.x, 0.32, rect.position.y + rect.size.y),
    ])
    nav_mesh.vertices = vertices
    nav_mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))

    var region := NavigationRegion3D.new()
    region.name = name
    region.navigation_mesh = nav_mesh
    region.navigation_layers = 1
    return region

func _add_factory_fx(playfield: Vector2):
    var fx_positions := [
        Vector3(playfield.x * 0.18, 0.2, playfield.y * 0.62),
        Vector3(playfield.x * 0.58, 0.2, playfield.y * 0.28),
        Vector3(playfield.x * 0.82, 0.2, playfield.y * 0.62),
    ]

    for pos in fx_positions:
        var sparks := _get_pooled_particles("factory_sparks", func():
            var p := CPUParticles3D.new()
            p.amount = 60
            p.lifetime = 0.8
            p.one_shot = false
            p.preprocess = 0.3
            p.direction = Vector3(0.1, 1.0, 0)
            p.spread = 0.7
            p.initial_velocity_min = 5.0
            p.initial_velocity_max = 9.0
            p.gravity = Vector3(0, -1.0, 0)
            p.scale_amount_min = 0.08
            p.scale_amount_max = 0.2
            p.color = Color(1.0, 0.54, 0.26, 0.9)
            return p
        )
        sparks.reparent(level_root)
        sparks.amount = 60
        sparks.position = pos
        sparks.emitting = true
        sparks.visible = true

        var smoke := _get_pooled_particles("factory_smoke", func():
            var p := CPUParticles3D.new()
            p.amount = 22
            p.lifetime = 2.6
            p.one_shot = false
            p.preprocess = 0.4
            p.direction = Vector3(0, 1, 0)
            p.initial_velocity_min = 1.2
            p.initial_velocity_max = 2.5
            p.gravity = Vector3(0, -0.8, 0)
            p.scale_amount_min = 0.8
            p.scale_amount_max = 1.4
            p.color = Color(0.15, 0.16, 0.18, 0.6)
            return p
        )
        smoke.reparent(level_root)
        smoke.amount = 22
        smoke.position = pos + Vector3(0.4, 0.1, 0)
        smoke.emitting = true
        smoke.visible = true

func _apply_lethal_damage(body: Node):
    if body and body.has_method("take_damage"):
        body.take_damage(9999.0)

func _create_wall_strip(size: Vector3, position: Vector3, material: StandardMaterial3D):
    var wall := StaticBody3D.new()
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.material_override = material
    mesh_instance.position = Vector3.ZERO
    wall.add_child(mesh_instance)

    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collider.shape = shape
    collider.position = Vector3.ZERO
    wall.add_child(collider)

    wall.position = position
    level_root.add_child(wall)

func _decorate_hall_edges(center: Vector3, size: Vector2, accent_mat: StandardMaterial3D):
    var rim_height := 2.8
    var rim_thickness := 0.6
    var half_x := size.x * 0.5
    var half_z := size.y * 0.5

    _create_wall_strip(Vector3(size.x, rim_height, rim_thickness), Vector3(center.x, rim_height * 0.5, center.z - half_z + rim_thickness * 0.5), accent_mat)
    _create_wall_strip(Vector3(size.x, rim_height, rim_thickness), Vector3(center.x, rim_height * 0.5, center.z + half_z - rim_thickness * 0.5), accent_mat)
    _create_wall_strip(Vector3(rim_thickness, rim_height, size.y), Vector3(center.x - half_x + rim_thickness * 0.5, rim_height * 0.5, center.z), accent_mat)
    _create_wall_strip(Vector3(rim_thickness, rim_height, size.y), Vector3(center.x + half_x - rim_thickness * 0.5, rim_height * 0.5, center.z), accent_mat)

func _scatter_supports(center: Vector3, size: Vector2, count: int, accent: StandardMaterial3D):
    var half_x := size.x * 0.5
    var half_z := size.y * 0.5
    for i in range(count):
        var pillar := StaticBody3D.new()
        pillar.name = "Support_%s" % i
        var mesh_instance := MeshInstance3D.new()
        var mesh := CylinderMesh.new()
        mesh.top_radius = 0.55
        mesh.bottom_radius = 0.62
        mesh.height = rng.randf_range(3.2, 4.6)
        mesh_instance.mesh = mesh
        mesh_instance.material_override = accent
        mesh_instance.position = Vector3(0, mesh.height * 0.5, 0)
        pillar.add_child(mesh_instance)

        var collider := CollisionShape3D.new()
        var shape := CylinderShape3D.new()
        shape.radius = mesh.bottom_radius
        shape.height = mesh.height
        collider.shape = shape
        collider.position = mesh_instance.position
        pillar.add_child(collider)

        var offset := Vector3(
            rng.randf_range(-half_x * 0.7, half_x * 0.7),
            0.0,
            rng.randf_range(-half_z * 0.7, half_z * 0.7)
        )
        pillar.position = center + offset
        level_root.add_child(pillar)

func _rect_from_center_size(center: Vector3, size: Vector2) -> Rect2:
    return Rect2(center.x - size.x * 0.5, center.z - size.y * 0.5, size.x, size.y)

func _create_wall_segment(root: Node3D, size: Vector3, wall_position: Vector3, wall_material: StandardMaterial3D):
    var wall := StaticBody3D.new()
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.material_override = wall_material
    mesh_instance.position.y = size.y * 0.5
    wall.add_child(mesh_instance)

    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collider.shape = shape
    collider.position.y = size.y * 0.5
    wall.add_child(collider)

    wall.position = wall_position
    root.add_child(wall)

func _add_boundary_walls(range: Vector2):
    var boundary := Node3D.new()
    boundary.name = "Boundary"

    var max_height: float = max(range.y + 4.0, 8.0) * 3.0
    var thickness := tile_size * 0.6
    var length_x := grid_size.x * tile_size + thickness * 2.0
    var length_z := grid_size.y * tile_size + thickness * 2.0
    var center_x := grid_size.x * tile_size * 0.5
    var center_z := grid_size.y * tile_size * 0.5

    var wall_material := StandardMaterial3D.new()
    wall_material.albedo_color = Color(0.14, 0.18, 0.22)
    wall_material.roughness = 0.52
    wall_material.metallic = 0.04

    _create_wall_segment(boundary, Vector3(length_x, max_height, thickness), Vector3(center_x, 0, -thickness * 0.5), wall_material)
    _create_wall_segment(boundary, Vector3(length_x, max_height, thickness), Vector3(center_x, 0, grid_size.y * tile_size + thickness * 0.5), wall_material)
    _create_wall_segment(boundary, Vector3(thickness, max_height, length_z), Vector3(-thickness * 0.5, 0, center_z), wall_material)
    _create_wall_segment(boundary, Vector3(thickness, max_height, length_z), Vector3(grid_size.x * tile_size + thickness * 0.5, 0, center_z), wall_material)

    var ceiling := StaticBody3D.new()
    ceiling.name = "Ceiling"
    var ceiling_mesh := BoxMesh.new()
    ceiling_mesh.size = Vector3(length_x, thickness, length_z)
    var ceiling_instance := MeshInstance3D.new()
    ceiling_instance.mesh = ceiling_mesh
    ceiling_instance.position = Vector3(center_x, max_height + thickness * 0.5, center_z)
    ceiling_instance.material_override = wall_material
    var ceiling_collider := CollisionShape3D.new()
    var ceiling_shape := BoxShape3D.new()
    ceiling_shape.size = ceiling_mesh.size
    ceiling_collider.shape = ceiling_shape
    ceiling_collider.position = ceiling_instance.position
    ceiling.add_child(ceiling_instance)
    ceiling.add_child(ceiling_collider)
    boundary.add_child(ceiling)

    level_root.add_child(boundary)

func _blur_heights(values: Array, passes: int) -> Array:
    var current := values.duplicate(true)
    var kernel := [[1.0, 2.0, 1.0], [2.0, 4.0, 2.0], [1.0, 2.0, 1.0]]
    var kernel_sum := 0.0
    for row in kernel:
        for weight in row:
            kernel_sum += weight
    for i in range(passes):
        var blurred: Array = []
        for x in range(grid_size.x):
            blurred.append([])
            for y in range(grid_size.y):
                var acc := 0.0
                for ox in range(-1, 2):
                    for oy in range(-1, 2):
                        var nx = clamp(x + ox, 0, grid_size.x - 1)
                        var ny = clamp(y + oy, 0, grid_size.y - 1)
                        acc += current[nx][ny] * kernel[ox + 1][oy + 1]
                blurred[x].append(acc / kernel_sum)
        current = blurred
    return current

func _soften_gradients(values: Array, max_delta: float, passes: int) -> Array:
    var current := values.duplicate(true)
    for i in range(passes):
        var softened: Array = []
        for x in range(grid_size.x):
            softened.append([])
            for y in range(grid_size.y):
                var base_height: float = current[x][y]
                var total := base_height * 2.0
                var count := 2.0
                for ox in range(-1, 2):
                    for oy in range(-1, 2):
                        if ox == 0 and oy == 0:
                            continue
                        var nx = clamp(x + ox, 0, grid_size.x - 1)
                        var ny = clamp(y + oy, 0, grid_size.y - 1)
                        var neighbour_height: float = current[nx][ny]
                        var limited_height = clamp(neighbour_height, base_height - max_delta, base_height + max_delta)
                        total += limited_height
                        count += 1.0
                softened[x].append(total / count)
        current = softened
    return current

func _build_height_map() -> Array:
    var heights: Array = []
    for x in range(grid_size.x):
        heights.append([])
        for y in range(grid_size.y):
            var slow_waves = sin(x * 0.09) * 0.4 + cos(y * 0.08) * 0.36
            var base = height_noise.get_noise_2d(x * 0.16, y * 0.16) * tile_height_variation * 0.95
            var dunes = height_noise.get_noise_2d((x + 19) * 0.26, (y - 11) * 0.26) * tile_height_variation * 0.55
            var micro = height_noise.get_noise_2d((x - 37) * 0.72, (y + 7) * 0.72) * tile_height_variation * 0.15
            heights[x].append(base + dunes * 0.6 + micro * 0.3 + slow_waves * 0.5)

    heights = _blur_heights(heights, 4)
    heights = _shape_edges(heights)
    var max_step := tile_height_variation * 0.28
    heights = _soften_gradients(heights, max_step, 3)
    return heights

func _shape_edges(heights: Array) -> Array:
    var shaped: Array = []
    var rim_height: float = tile_height_variation * 3.2
    var inner_radius: float = float(min(grid_size.x, grid_size.y)) * 0.42
    for x in range(grid_size.x):
        shaped.append([])
        for y in range(grid_size.y):
            var original: float = heights[x][y]
            var center := Vector2(grid_size.x - 1, grid_size.y - 1) * 0.5
            var dist: float = Vector2(x, y).distance_to(center)
            var edge_distance: float = float(min(min(x, grid_size.x - 1 - x), min(y, grid_size.y - 1 - y)))
            var rim_factor: float = clamp(1.0 - edge_distance / max(1.0, inner_radius * 0.38), 0.0, 1.0)
            var basin_factor: float = clamp(dist / max(1.0, inner_radius), 0.0, 1.0)
            var sculpted: float = original + rim_factor * rim_height - basin_factor * rim_height * 0.25
            shaped[x].append(sculpted)
    return shaped

func _sample_height(heights: Array, ix: int, iy: int) -> float:
    var sx = clamp(ix, 0, grid_size.x - 1)
    var sy = clamp(iy, 0, grid_size.y - 1)
    return heights[sx][sy]

func _generate_floor_mesh(heights: Array) -> ArrayMesh:
    var vertex_columns := grid_size.x + 1
    var vertex_rows := grid_size.y + 1
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()

    for y in range(vertex_rows):
        for x in range(vertex_columns):
            var height = _sample_height(heights, x, y)
            vertices.append(Vector3(x * tile_size, height, y * tile_size))

            var left = _sample_height(heights, x - 1, y)
            var right = _sample_height(heights, x + 1, y)
            var down = _sample_height(heights, x, y - 1)
            var up = _sample_height(heights, x, y + 1)
            var normal := Vector3(left - right, 2.0, down - up).normalized()
            normals.append(normal)

            uvs.append(Vector2(float(x) / max(1, vertex_columns - 1), float(y) / max(1, vertex_rows - 1)))

    var indices := PackedInt32Array()
    for y in range(vertex_rows - 1):
        for x in range(vertex_columns - 1):
            var top_left := y * vertex_columns + x
            var top_right := top_left + 1
            var bottom_left := top_left + vertex_columns
            var bottom_right := bottom_left + 1

            indices.append_array([top_left, bottom_left, top_right])
            indices.append_array([top_right, bottom_left, bottom_right])

    var mesh := ArrayMesh.new()
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh

func _calculate_height_range(heights: Array) -> Vector2:
    var min_height := INF
    var max_height := -INF
    for column in heights:
        for value in column:
            min_height = min(min_height, value)
            max_height = max(max_height, value)
    return Vector2(min_height, max_height)

func _sample_height_interpolated(heights: Array, world_position: Vector3) -> float:
    var gx = clamp(world_position.x / tile_size, 0.0, grid_size.x - 1.001)
    var gy = clamp(world_position.z / tile_size, 0.0, grid_size.y - 1.001)
    var x0 = int(floor(gx))
    var y0 = int(floor(gy))
    var x1 = clamp(x0 + 1, 0, grid_size.x - 1)
    var y1 = clamp(y0 + 1, 0, grid_size.y - 1)
    var tx = gx - float(x0)
    var ty = gy - float(y0)

    var h00 = heights[x0][y0]
    var h10 = heights[x1][y0]
    var h01 = heights[x0][y1]
    var h11 = heights[x1][y1]
    var hx0 = lerp(h00, h10, tx)
    var hx1 = lerp(h01, h11, tx)
    return lerp(hx0, hx1, ty)

func _is_walkable_tile(heights: Array, x: int, y: int, max_slope := 1.6) -> bool:
    if x <= 0 or y <= 0 or x >= grid_size.x - 1 or y >= grid_size.y - 1:
        return false
    var h: float = heights[x][y]
    for ox in range(-1, 2):
        for oy in range(-1, 2):
            if ox == 0 and oy == 0:
                continue
            if abs(heights[x + ox][y + oy] - h) > max_slope:
                return false
    return true

func _record_floor_spot(height_offset: float, x: int, y: int):
    var base_position := Vector3(x * tile_size, height_offset, y * tile_size)
    floor_positions.append(base_position + Vector3(0, 0.55, 0))
    if _is_walkable_tile(height_map, x, y):
        spawn_positions.append(base_position + Vector3(0, 0.9, 0))

func _choose_center_spawn() -> Vector3:
    var center := Vector3(grid_size.x * tile_size * 0.5, 0.0, grid_size.y * tile_size * 0.5)
    var base_height := _sample_height_interpolated(height_map, center)
    if spawn_positions.is_empty():
        return Vector3(center.x, base_height + 1.4, center.z)
    var closest: Vector3 = spawn_positions[0]
    var best_distance := INF
    for spot in spawn_positions:
        var dist: float = Vector2(spot.x - center.x, spot.z - center.z).length()
        if dist < best_distance:
            best_distance = dist
            closest = spot
    var corrected_height := _sample_height_interpolated(height_map, closest)
    return Vector3(closest.x, corrected_height + 1.4, closest.z)

func _tint_tile(tile: Node, height_offset: float, x: int, y: int):
    var mesh_instance: MeshInstance3D = tile.get_node_or_null("MeshInstance3D")
    if mesh_instance:
        mesh_instance.material_override = _make_tile_material(height_offset, x, y)

func _prepare_tile_visuals(tile: Node, height_offset: float, x: int, y: int):
    var mesh_instance: MeshInstance3D = tile.get_node_or_null("MeshInstance3D")
    if mesh_instance:
        mesh_instance.visible = false
    var collision_shape: CollisionShape3D = tile.get_node_or_null("CollisionShape3D")
    if collision_shape:
        collision_shape.disabled = true
    _tint_tile(tile, height_offset, x, y)

func _make_tile_material(height_offset: float, x: int, y: int) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    var height_factor: float = clamp((height_offset / max(0.01, tile_height_variation)) * 0.5 + 0.5, 0.0, 1.0)
    var base = Color(0.14, 0.18, 0.2)
    var mid = Color(0.18, 0.26, 0.32)
    var high = Color(0.26, 0.34, 0.42)
    var tint = base.lerp(mid, height_factor).lerp(high, abs(sin((x + y) * 0.23)) * 0.6)
    mat.albedo_color = tint
    mat.metallic = 0.08
    mat.roughness = 0.55
    mat.emission_enabled = true
    mat.emission = tint * 0.08
    return mat

func _decorate_tile(tile: Node3D, height_offset: float, x: int, y: int):
    var roll = rng.randf()
    if roll < 0.12:
        var light := OmniLight3D.new()
        light.light_color = Color(0.4 + rng.randf() * 0.2, 0.6 + rng.randf() * 0.3, 0.9)
        light.light_energy = 0.8
        light.omni_range = 10.0
        light.position = Vector3(rng.randf_range(-tile_size * 0.28, tile_size * 0.28), 0.6 + height_offset * 0.2, rng.randf_range(-tile_size * 0.28, tile_size * 0.28))
        tile.add_child(light)
    elif roll < 0.26:
        var strut := MeshInstance3D.new()
        var mesh := PrismMesh.new()
        mesh.size = Vector3(0.6, 0.4, 1.4)
        strut.mesh = mesh
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.18, 0.22, 0.28)
        mat.roughness = 0.4
        mat.metallic = 0.2
        strut.material_override = mat
        strut.position = Vector3(rng.randf_range(-tile_size * 0.3, tile_size * 0.3), 0.25, rng.randf_range(-tile_size * 0.3, tile_size * 0.3))
        strut.rotation_degrees = Vector3(0, rng.randf_range(0, 180), rng.randf_range(-8, 8))
        tile.add_child(strut)
    elif roll < 0.42:
        var ribs := MeshInstance3D.new()
        var rib_mesh := TorusMesh.new()
        rib_mesh.inner_radius = 0.32
        rib_mesh.outer_radius = 0.62
        rib_mesh.ring_segments = 18
        rib_mesh.rings = 12
        ribs.mesh = rib_mesh
        var rib_mat := StandardMaterial3D.new()
        rib_mat.albedo_color = Color(0.12, 0.16, 0.2)
        rib_mat.emission_enabled = true
        rib_mat.emission = Color(0.12, 0.34, 0.46) * 0.12
        ribs.material_override = rib_mat
        ribs.position = Vector3(0, 0.02, 0)
        ribs.rotation_degrees = Vector3(90, rng.randf_range(0, 360), 0)
        tile.add_child(ribs)

func _maybe_add_cover(tile: Node3D):
    if rng.randf() > cover_chance:
        return
    var obstacle := StaticBody3D.new()
    obstacle.name = "Cover"
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(rng.randf_range(1.2, 1.8), rng.randf_range(0.8, 1.6), rng.randf_range(1.2, 1.8))
    mesh_instance.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.28, 0.34, 0.4)
    mat.roughness = 0.6
    mesh_instance.material_override = mat
    obstacle.add_child(mesh_instance)

    var shape := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = mesh.size
    shape.shape = box_shape
    shape.position.y = mesh.size.y * 0.5
    obstacle.add_child(shape)

    obstacle.position = Vector3(
        rng.randf_range(-tile_size * 0.35, tile_size * 0.35),
        mesh.size.y * 0.5,
        rng.randf_range(-tile_size * 0.35, tile_size * 0.35)
    )
    obstacle.rotation_degrees.y = rng.randf_range(0, 360)
    tile.add_child(obstacle)

func _maybe_add_vertical_feature(tile: Node3D):
    if rng.randf() > vertical_feature_chance:
        return
    var plateau_height := rng.randf_range(1.4, 3.4)
    var plateau_size := Vector2(rng.randf_range(2.6, 4.2), rng.randf_range(2.6, 4.2))
    var platform := StaticBody3D.new()
    platform.name = "Plateau"

    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(plateau_size.x, 0.5, plateau_size.y)
    mesh_instance.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.2, 0.26, 0.32)
    mat.roughness = 0.55
    mesh_instance.material_override = mat
    platform.add_child(mesh_instance)

    var shape := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = mesh.size
    shape.shape = box_shape
    shape.position.y = mesh.size.y * 0.5
    platform.add_child(shape)

    platform.position = Vector3(
        rng.randf_range(-tile_size * 0.35, tile_size * 0.35),
        plateau_height,
        rng.randf_range(-tile_size * 0.35, tile_size * 0.35)
    )
    platform.rotation_degrees.y = rng.randf_range(0, 360)

    var ramp := MeshInstance3D.new()
    var ramp_mesh := PrismMesh.new()
    ramp_mesh.size = Vector3(plateau_size.x * 0.6, plateau_height, 0.8)
    ramp.mesh = ramp_mesh
    var ramp_mat := StandardMaterial3D.new()
    ramp_mat.albedo_color = Color(0.24, 0.3, 0.36)
    ramp_mat.roughness = 0.55
    ramp.material_override = ramp_mat
    ramp.position = Vector3(0, -plateau_height * 0.5, plateau_size.y * 0.5 + 0.6)
    ramp.rotation_degrees.x = -90.0
    platform.add_child(ramp)

    for i in range(3):
        var stair_mesh := MeshInstance3D.new()
        var stair_shape := BoxMesh.new()
        stair_shape.size = Vector3(plateau_size.x * 0.4, plateau_height / 3.0, 0.7)
        stair_mesh.mesh = stair_shape
        stair_mesh.position = Vector3(0, -plateau_height * 0.5 + stair_shape.size.y * 0.5 + i * stair_shape.size.y, plateau_size.y * 0.5 + 0.8)
        stair_mesh.material_override = ramp_mat
        platform.add_child(stair_mesh)

        var stair_collision := CollisionShape3D.new()
        var stair_box := BoxShape3D.new()
        stair_box.size = stair_shape.size
        stair_collision.shape = stair_box
        stair_collision.position = stair_mesh.position
        platform.add_child(stair_collision)

    tile.add_child(platform)
    floor_positions.append(platform.global_transform.origin + Vector3(0, 0.55, 0))
    spawn_positions.append(platform.global_transform.origin + Vector3(0, 0.9, 0))

func spawn_player():
    player = player_scene.instantiate()
    add_child(player)
    player.global_transform.origin = _choose_center_spawn()
    if player.has_method("apply_settings"):
        player.apply_settings(pending_settings)
    player.set_weapons(WeaponData.WEAPONS)
    if player.has_signal("died"):
        player.died.connect(_on_player_died)
    if hud and hud.has_method("update_health"):
        hud.update_health(player.max_health, player.max_health)

func spawn_pickups():
    pass

func spawn_enemies():
    pass

func _spawn_enemy(scene: PackedScene):
    if scene == null:
        return
    var enemy = scene.instantiate()
    enemy.target = player
    var enemy_position = get_random_floor_position(tile_size * 2.5) + Vector3(0, 0.5, 0)
    enemy_root.add_child(enemy)
    enemy.global_transform.origin = enemy_position

func get_random_floor_position(min_distance := 0.0) -> Vector3:
    var pool := spawn_positions if not spawn_positions.is_empty() else floor_positions
    if pool.is_empty():
        return Vector3.ZERO
    var attempts := 0
    while attempts < 12:
        var candidate: Vector3 = pool[rng.randi_range(0, pool.size() - 1)]
        candidate.y = _sample_height_interpolated(height_map, candidate) + 0.9
        if not is_instance_valid(player) or min_distance <= 0.0:
            return candidate
        if candidate.distance_to(player.global_transform.origin) >= min_distance:
            return candidate
        attempts += 1
    var fallback: Vector3 = pool[0]
    fallback.y = _sample_height_interpolated(height_map, fallback) + 0.9
    return fallback

func _unhandled_input(event):
    var wants_pause: bool = event.is_action_pressed("ui_cancel")
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        wants_pause = true
    if not game_over and wants_pause:
        if menu_controller and menu_controller.has_method("show_menu"):
            menu_controller.show_menu(true, true)
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        get_tree().paused = true
        return
    if not game_over:
        return
    if event is InputEventKey and event.pressed and (event.keycode == KEY_R or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
        restart_requested()

func _on_player_died():
    game_over = true
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    for enemy in enemy_root.get_children():
        enemy.target = null
    if hud and hud.has_method("show_status"):
        hud.show_status("Вы погибли. Нажмите кнопку ниже, чтобы сыграть снова.", true)

func restart_requested():
    if not game_over:
        return
    start_round()

func set_menu_controller(menu_ref: Node):
    menu_controller = menu_ref

func apply_settings(settings: Dictionary):
    pending_settings.merge(settings, true)
    if is_instance_valid(player) and player.has_method("apply_settings"):
        player.apply_settings(pending_settings)

func begin_game(settings: Dictionary):
    apply_settings(settings)
    start_round()

func resume_game():
    get_tree().paused = false
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    if menu_controller and menu_controller.has_method("hide_menu"):
        menu_controller.hide_menu()
