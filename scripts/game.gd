extends Node3D

const WeaponData = preload("res://scripts/weapon_data.gd")

const DEFAULT_TILE_SCENE := preload("res://scenes/LevelTile.tscn")
const DEFAULT_PLAYER_SCENE := preload("res://scenes/Player.tscn")
const DEFAULT_ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const DEFAULT_PICKUP_SCENE := preload("res://scenes/WeaponPickup.tscn")

@export var grid_size := Vector2i(6, 6)
@export var tile_size := 12.0
@export var tile_scene: PackedScene = DEFAULT_TILE_SCENE
@export var player_scene: PackedScene = DEFAULT_PLAYER_SCENE
@export var enemy_scene: PackedScene = DEFAULT_ENEMY_SCENE
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
            if rng.randf() < 0.12 and not (x == grid_size.x / 2.0 and y == grid_size.y / 2.0):
                continue
            var tile = tile_scene.instantiate()
            tile.position = Vector3(x * tile_size, 0, y * tile_size)
            level_root.add_child(tile)
            floor_positions.append(tile.global_transform.origin)

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
    for i in range(8):
        var enemy = enemy_scene.instantiate()
        enemy.target = player
        var enemy_position = get_random_floor_position() + Vector3(0, 0.5, 0)
        enemy_root.add_child(enemy)
        enemy.global_transform.origin = enemy_position

func get_random_floor_position() -> Vector3:
    if floor_positions.is_empty():
        return Vector3.ZERO
    return floor_positions[rng.randi_range(0, floor_positions.size() - 1)]

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
