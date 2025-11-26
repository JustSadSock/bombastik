extends Node3D

const WeaponData = preload("res://scripts/weapon_data.gd")

const DEFAULT_TILE_SCENE := preload("res://scenes/LevelTile.tscn")
const DEFAULT_PLAYER_SCENE := preload("res://scenes/Player.tscn")
const DEFAULT_ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const DEFAULT_RANGED_ENEMY_SCENE := preload("res://scenes/RangedEnemy.tscn")
const DEFAULT_PICKUP_SCENE := preload("res://scenes/WeaponPickup.tscn")

@export var grid_size := Vector2i(10, 10)
@export var tile_size := 6.0
@export var tile_height_variation := 0.45
@export var cover_chance := 0.18
@export var tile_scene: PackedScene = DEFAULT_TILE_SCENE
@export var player_scene: PackedScene = DEFAULT_PLAYER_SCENE
@export var enemy_scene: PackedScene = DEFAULT_ENEMY_SCENE
@export var ranged_enemy_scene: PackedScene = DEFAULT_RANGED_ENEMY_SCENE
@export var pickup_scene: PackedScene = DEFAULT_PICKUP_SCENE

var floor_positions: Array = []
var player: Node3D
var rng := RandomNumberGenerator.new()
var game_over := false

@onready var level_root: Node3D = $Level
@onready var pickup_root: Node3D = $Pickups
@onready var enemy_root: Node3D = $Enemies
@onready var hud = $HUD

func _ready():
    rng.randomize()
    tile_scene = tile_scene if tile_scene else DEFAULT_TILE_SCENE
    player_scene = player_scene if player_scene else DEFAULT_PLAYER_SCENE
    enemy_scene = enemy_scene if enemy_scene else DEFAULT_ENEMY_SCENE
    ranged_enemy_scene = ranged_enemy_scene if ranged_enemy_scene else DEFAULT_RANGED_ENEMY_SCENE
    pickup_scene = pickup_scene if pickup_scene else DEFAULT_PICKUP_SCENE
    if hud and hud.has_signal("restart_requested"):
        hud.restart_requested.connect(restart_requested)
    start_round()

func start_round():
    game_over = false
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    clear_game()
    generate_level()
    spawn_player()
    spawn_pickups()
    spawn_enemies()
    if hud and hud.has_method("hide_status"):
        hud.hide_status()

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
    for x in range(grid_size.x):
        for y in range(grid_size.y):
            var tile = tile_scene.instantiate()
            var height_offset = rng.randf_range(-tile_height_variation, tile_height_variation)
            tile.position = Vector3(x * tile_size, height_offset, y * tile_size)
            tile.rotation_degrees.y = rng.randf_range(-4.0, 4.0)
            level_root.add_child(tile)
            floor_positions.append(tile.global_transform.origin + Vector3(0, 0.55, 0))
            _maybe_add_cover(tile)

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

func spawn_player():
    player = player_scene.instantiate()
    add_child(player)
    player.global_transform.origin = Vector3(grid_size.x * tile_size * 0.5, 2.0, grid_size.y * tile_size * 0.5)
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
