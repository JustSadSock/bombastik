extends Node3D

const WeaponData = preload("res://scripts/weapon_data.gd")

const DEFAULT_TILE_SCENE := preload("res://scenes/LevelTile.tscn")
const DEFAULT_PLAYER_SCENE := preload("res://scenes/Player.tscn")
const DEFAULT_ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const DEFAULT_RANGED_ENEMY_SCENE := preload("res://scenes/RangedEnemy.tscn")
const DEFAULT_PICKUP_SCENE := preload("res://scenes/WeaponPickup.tscn")

@export var grid_size := Vector2i(14, 14)
@export var tile_size := 6.5
@export var tile_height_variation := 1.2
@export var cover_chance := 0.18
@export var vertical_feature_chance := 0.22
@export var auto_start := false
@export var tile_scene: PackedScene = DEFAULT_TILE_SCENE
@export var player_scene: PackedScene = DEFAULT_PLAYER_SCENE
@export var enemy_scene: PackedScene = DEFAULT_ENEMY_SCENE
@export var ranged_enemy_scene: PackedScene = DEFAULT_RANGED_ENEMY_SCENE
@export var pickup_scene: PackedScene = DEFAULT_PICKUP_SCENE

var floor_positions: Array = []
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
    tile_scene = tile_scene if tile_scene else DEFAULT_TILE_SCENE
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
    for child in level_root.get_children():
        child.queue_free()
    for child in pickup_root.get_children():
        child.queue_free()
    for child in enemy_root.get_children():
        child.queue_free()
    if is_instance_valid(player):
        player.queue_free()

func generate_level():
    var heights := _build_height_map()
    for x in range(grid_size.x):
        for y in range(grid_size.y):
            var tile = tile_scene.instantiate()
            var height_offset = heights[x][y]
            tile.position = Vector3(x * tile_size, height_offset, y * tile_size)
            tile.rotation_degrees.y = rng.randf_range(-1.2, 1.2)
            _tint_tile(tile, height_offset, x, y)
            level_root.add_child(tile)
            floor_positions.append(tile.global_transform.origin + Vector3(0, 0.55, 0))
            _maybe_add_cover(tile)
            _maybe_add_vertical_feature(tile)
            _decorate_tile(tile, height_offset, x, y)

func _build_height_map() -> Array:
    var heights: Array = []
    for x in range(grid_size.x):
        heights.append([])
        for y in range(grid_size.y):
            var primary = height_noise.get_noise_2d(x, y) * tile_height_variation * 0.75
            var ridges = height_noise.get_noise_2d(x * 0.35, y * 0.35) * tile_height_variation * 0.4
            var waves = sin(x * 0.32) * 0.12 + cos(y * 0.28) * 0.1
            heights[x].append(primary + ridges + waves)
    for i in range(2):
        var smoothed: Array = []
        for x in range(grid_size.x):
            smoothed.append([])
            for y in range(grid_size.y):
                var acc: float = float(heights[x][y]) * 3.0
                var count: float = 3.0
                for ox in range(-1, 2):
                    for oy in range(-1, 2):
                        var nx = x + ox
                        var ny = y + oy
                        if nx < 0 or ny < 0 or nx >= grid_size.x or ny >= grid_size.y or (ox == 0 and oy == 0):
                            continue
                        acc += heights[nx][ny]
                        count += 1.0
                smoothed[x].append(acc / count)
        heights = smoothed
    return heights

func _tint_tile(tile: Node, height_offset: float, x: int, y: int):
    var mesh_instance: MeshInstance3D = tile.get_node_or_null("MeshInstance3D")
    if mesh_instance:
        mesh_instance.material_override = _make_tile_material(height_offset, x, y)

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

func spawn_player():
    player = player_scene.instantiate()
    add_child(player)
    player.global_transform.origin = Vector3(grid_size.x * tile_size * 0.5, 2.0, grid_size.y * tile_size * 0.5)
    if player.has_method("apply_settings"):
        player.apply_settings(pending_settings)
    player.set_weapons(WeaponData.WEAPONS)
    if player.has_signal("died"):
        player.died.connect(_on_player_died)
    if hud and hud.has_method("update_health"):
        hud.update_health(player.max_health, player.max_health)

func spawn_pickups():
    for data in WeaponData.WEAPONS:
        if data.get("id") == "pistol":
            continue
        var pickup = pickup_scene.instantiate()
        pickup.weapon_id = data.get("id")
        pickup.display_name = data.get("name")
        var pickup_position = get_random_floor_position() + Vector3(0, 0.5, 0)
        var label = pickup.get_node_or_null("Label3D")
        if label:
            label.text = data.get("name")
        pickup_root.add_child(pickup)
        pickup.global_transform.origin = pickup_position

func spawn_enemies():
    var melee_count := 6
    var ranged_count := 4
    for i in range(melee_count):
        _spawn_enemy(enemy_scene)
    for i in range(ranged_count):
        _spawn_enemy(ranged_enemy_scene)

func _spawn_enemy(scene: PackedScene):
    if scene == null:
        return
    var enemy = scene.instantiate()
    enemy.target = player
    var enemy_position = get_random_floor_position(tile_size * 2.5) + Vector3(0, 0.5, 0)
    enemy_root.add_child(enemy)
    enemy.global_transform.origin = enemy_position

func get_random_floor_position(min_distance := 0.0) -> Vector3:
    if floor_positions.is_empty():
        return Vector3.ZERO
    var attempts := 0
    while attempts < 12:
        var candidate = floor_positions[rng.randi_range(0, floor_positions.size() - 1)]
        if not is_instance_valid(player) or min_distance <= 0.0:
            return candidate
        if candidate.distance_to(player.global_transform.origin) >= min_distance:
            return candidate
        attempts += 1
    return floor_positions[0]

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
