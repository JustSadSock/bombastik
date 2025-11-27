extends Node3D

const WeaponData = preload("res://scripts/weapon_data.gd")

const DEFAULT_PLAYER_SCENE := preload("res://scenes/Player.tscn")
const DEFAULT_ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const DEFAULT_RANGED_ENEMY_SCENE := preload("res://scenes/RangedEnemy.tscn")
const DEFAULT_PICKUP_SCENE := preload("res://scenes/WeaponPickup.tscn")

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
var height_noise := FastNoiseLite.new()
var menu_controller: Node
var pending_settings := {
    "sensitivity": 0.002,
    "master_volume": 1.0,
}

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
        child.queue_free()
    for child in pickup_root.get_children():
        child.queue_free()
    for child in enemy_root.get_children():
        child.queue_free()
    if is_instance_valid(player):
        player.queue_free()

func generate_level():
    height_map = _build_flat_height_map()
    height_range = Vector2(0.0, 8.0)
    _build_flat_floor()
    _add_boundary_walls(height_range)
    _record_flat_spawns()

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
    var base = Color(0.07, 0.1, 0.14)
    var mid = Color(0.12, 0.18, 0.24)
    var high = Color(0.24, 0.36, 0.46)
    var accent = Color(0.22, 0.58, 0.92)
    var tint = base.lerp(mid, height_factor).lerp(high, abs(sin((x + y) * 0.23)) * 0.65)
    mat.albedo_color = tint
    mat.metallic = 0.12
    mat.roughness = 0.48
    mat.clearcoat = 0.08
    mat.emission_enabled = true
    mat.emission = tint * 0.06 + accent * 0.02
    return mat

func _decorate_tile(tile: Node3D, height_offset: float, x: int, y: int):
    var roll = rng.randf()
    if roll < 0.14:
        var light := OmniLight3D.new()
        light.light_color = Color(0.25, 0.6 + rng.randf() * 0.2, 1.0)
        light.light_energy = 1.1
        light.omni_range = 12.0
        light.shadow_enabled = true
        light.position = Vector3(rng.randf_range(-tile_size * 0.28, tile_size * 0.28), 0.9 + height_offset * 0.2, rng.randf_range(-tile_size * 0.28, tile_size * 0.28))
        tile.add_child(light)
    elif roll < 0.3:
        var console := MeshInstance3D.new()
        var console_mesh := BoxMesh.new()
        console_mesh.size = Vector3(0.8, 0.7, 0.5)
        console.mesh = console_mesh
        var console_mat := StandardMaterial3D.new()
        console_mat.albedo_color = Color(0.14, 0.18, 0.22)
        console_mat.metallic = 0.26
        console_mat.roughness = 0.32
        console_mat.emission_enabled = true
        console_mat.emission = Color(0.2, 0.65, 0.9) * 0.4
        console.material_override = console_mat
        console.position = Vector3(rng.randf_range(-tile_size * 0.26, tile_size * 0.26), 0.35, rng.randf_range(-tile_size * 0.26, tile_size * 0.26))
        console.rotation_degrees = Vector3(rng.randf_range(-4, 4), rng.randf_range(0, 180), 0)
        tile.add_child(console)
    elif roll < 0.46:
        var pylon := MeshInstance3D.new()
        var pylon_mesh := CylinderMesh.new()
        pylon_mesh.height = 2.6
        pylon_mesh.top_radius = 0.14
        pylon_mesh.bottom_radius = 0.18
        pylon.mesh = pylon_mesh
        var pylon_mat := StandardMaterial3D.new()
        pylon_mat.albedo_color = Color(0.1, 0.12, 0.16)
        pylon_mat.metallic = 0.3
        pylon_mat.roughness = 0.38
        pylon.material_override = pylon_mat
        pylon.position = Vector3(rng.randf_range(-tile_size * 0.32, tile_size * 0.32), pylon_mesh.height * 0.5, rng.randf_range(-tile_size * 0.32, tile_size * 0.32))
        tile.add_child(pylon)

        var cap := MeshInstance3D.new()
        var cap_mesh := SphereMesh.new()
        cap_mesh.radius = 0.24
        cap_mesh.height = 0.18
        cap.mesh = cap_mesh
        var cap_mat := StandardMaterial3D.new()
        cap_mat.albedo_color = Color(0.18, 0.6, 0.86)
        cap_mat.emission_enabled = true
        cap_mat.emission = Color(0.18, 0.7, 1.0) * 0.6
        cap.material_override = cap_mat
        cap.position = pylon.position + Vector3(0, pylon_mesh.height * 0.5 + 0.18, 0)
        tile.add_child(cap)

func _maybe_add_cover(tile: Node3D):
    if rng.randf() > cover_chance:
        return
    var obstacle := StaticBody3D.new()
    obstacle.name = "Cover"
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(rng.randf_range(1.3, 1.9), rng.randf_range(0.9, 1.8), rng.randf_range(1.3, 1.9))
    mesh_instance.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.16, 0.2, 0.25)
    mat.metallic = 0.18
    mat.roughness = 0.44
    mat.emission_enabled = true
    mat.emission = Color(0.12, 0.38, 0.8) * 0.22
    mesh_instance.material_override = mat
    obstacle.add_child(mesh_instance)

    var accent := MeshInstance3D.new()
    var accent_mesh := BoxMesh.new()
    accent_mesh.size = Vector3(mesh.size.x * 0.9, 0.12, mesh.size.z * 0.9)
    accent.mesh = accent_mesh
    var accent_mat := StandardMaterial3D.new()
    accent_mat.albedo_color = Color(0.22, 0.6, 0.86)
    accent_mat.emission_enabled = true
    accent_mat.emission = Color(0.3, 0.7, 1.0) * 0.5
    accent.material_override = accent_mat
    accent.position = Vector3(0, mesh.size.y * 0.5 + accent_mesh.size.y * 0.5, 0)
    obstacle.add_child(accent)

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
    mat.albedo_color = Color(0.14, 0.18, 0.24)
    mat.roughness = 0.4
    mat.metallic = 0.24
    mesh_instance.material_override = mat
    platform.add_child(mesh_instance)

    var trim := MeshInstance3D.new()
    var trim_mesh := BoxMesh.new()
    trim_mesh.size = Vector3(plateau_size.x * 0.92, 0.16, plateau_size.y * 0.92)
    trim.mesh = trim_mesh
    var trim_mat := StandardMaterial3D.new()
    trim_mat.albedo_color = Color(0.22, 0.58, 0.86)
    trim_mat.emission_enabled = true
    trim_mat.emission = Color(0.22, 0.6, 0.92) * 0.6
    trim.material_override = trim_mat
    trim.position.y = mesh.size.y * 0.5 + trim_mesh.size.y * 0.5
    platform.add_child(trim)

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
    ramp_mat.albedo_color = Color(0.18, 0.26, 0.32)
    ramp_mat.roughness = 0.48
    ramp_mat.metallic = 0.18
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

    var rail_height := plateau_height * 0.6 + 0.6
    for side in [-1, 1]:
        var rail := MeshInstance3D.new()
        var rail_mesh := CylinderMesh.new()
        rail_mesh.height = plateau_size.y * 0.9
        rail_mesh.top_radius = 0.05
        rail_mesh.bottom_radius = 0.05
        rail.mesh = rail_mesh
        var rail_mat := StandardMaterial3D.new()
        rail_mat.albedo_color = Color(0.12, 0.16, 0.22)
        rail_mat.metallic = 0.34
        rail_mat.roughness = 0.36
        rail.material_override = rail_mat
        rail.rotation_degrees = Vector3(0, 0, 90)
        rail.position = Vector3(plateau_size.x * 0.5 * side, rail_height, 0)
        platform.add_child(rail)

        var rail_light := OmniLight3D.new()
        rail_light.light_color = Color(0.22, 0.68, 1.0)
        rail_light.light_energy = 0.6
        rail_light.omni_range = 10.0
        rail_light.position = rail.position + Vector3(0, 0.2, 0)
        platform.add_child(rail_light)

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
