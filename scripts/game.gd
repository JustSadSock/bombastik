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

func _ready():
    rng.randomize()
    tile_scene = tile_scene if tile_scene else DEFAULT_TILE_SCENE
    player_scene = player_scene if player_scene else DEFAULT_PLAYER_SCENE
    enemy_scene = enemy_scene if enemy_scene else DEFAULT_ENEMY_SCENE
    pickup_scene = pickup_scene if pickup_scene else DEFAULT_PICKUP_SCENE
    generate_level()
    spawn_player()
    spawn_pickups()
    spawn_enemies()

func generate_level():
    floor_positions.clear()
    var level_root = $Level
    for child in level_root.get_children():
        child.queue_free()
    for x in range(grid_size.x):
        for y in range(grid_size.y):
            if rng.randf() < 0.12 and not (x == grid_size.x / 2 and y == grid_size.y / 2):
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

func spawn_pickups():
    var container = $Pickups
    for data in WeaponData.WEAPONS:
        if data.get("id") == "pistol":
            continue
        var pickup = pickup_scene.instantiate()
        pickup.weapon_id = data.get("id")
        pickup.display_name = data.get("name")
        var position = get_random_floor_position() + Vector3(0, 0.5, 0)
        pickup.global_transform.origin = position
        var label = pickup.get_node_or_null("Label3D")
        if label:
            label.text = data.get("name")
        container.add_child(pickup)

func spawn_enemies():
    var container = $Enemies
    for i in range(8):
        var enemy = enemy_scene.instantiate()
        enemy.target = player
        enemy.global_transform.origin = get_random_floor_position() + Vector3(0, 0.5, 0)
        container.add_child(enemy)

func get_random_floor_position() -> Vector3:
    if floor_positions.is_empty():
        return Vector3.ZERO
    return floor_positions[rng.randi_range(0, floor_positions.size() - 1)]
