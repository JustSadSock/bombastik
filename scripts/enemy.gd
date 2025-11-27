extends CharacterBody3D

const DEFAULT_EXPLOSION_SCENE := preload("res://scenes/Explosion.tscn")
const DEFAULT_PROJECTILE_SCENE := preload("res://scenes/Projectile.tscn")

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
const VARIANT_STYLES := [
    {
        "body": Color(0.85, 0.48, 0.4),
        "accent": Color(1.0, 0.72, 0.42),
        "light": Color(1.05, 0.64, 0.48),
        "attachments": [
            {"type": "blade", "offset": Vector3(0.42, 0.4, 0.0)},
            {"type": "pauldron", "offset": Vector3(-0.44, 0.52, 0.0)},
        ],
    },
    {
        "body": Color(0.42, 0.6, 1.0),
        "accent": Color(0.3, 0.86, 0.9),
        "light": Color(0.42, 0.8, 1.0),
        "attachments": [
            {"type": "antenna", "offset": Vector3(0.18, 1.05, -0.16)},
            {"type": "backpack", "offset": Vector3(0.0, 0.38, 0.34)},
        ],
    },
    {
        "body": Color(0.68, 0.48, 0.9),
        "accent": Color(1.0, 0.56, 0.86),
        "light": Color(1.1, 0.68, 1.0),
        "attachments": [
            {"type": "visor_ridge", "offset": Vector3(0.0, 0.92, -0.34)},
            {"type": "shoulder_plate", "offset": Vector3(0.44, 0.48, 0.0)},
        ],
    },
]

const MELEE_VARIANTS := [
    {
        "id": "brute",
        "health": 140.0,
        "damage": 28.0,
        "speed": 5.6,
        "strafe_speed": 4.6,
        "melee_range": 2.8,
        "visual_scale": 1.2,
        "body_mesh": {"type": "box", "size": Vector3(0.96, 1.8, 0.82)},
        "head_mesh": {"type": "cylinder", "height": 0.52, "top_radius": 0.36, "bottom_radius": 0.38},
        "visor_mesh": {"type": "prism", "size": Vector3(0.32, 0.22, 0.72), "origin": Vector3(0, 1.05, -0.38)},
        "harness_mesh": {"type": "cylinder", "height": 0.54, "top_radius": 0.34, "bottom_radius": 0.36, "origin": Vector3(0, 0.6, 0)},
        "style_override": {
            "body": Color(0.78, 0.36, 0.32),
            "accent": Color(1.0, 0.48, 0.24),
            "light": Color(1.06, 0.56, 0.3),
            "attachments": [
                {"type": "pauldron", "offset": Vector3(0.52, 0.62, 0)},
                {"type": "blade", "offset": Vector3(-0.5, 0.44, -0.12)},
            ],
        },
    },
    {
        "id": "gladiator",
        "health": 155.0,
        "damage": 26.0,
        "speed": 6.2,
        "strafe_speed": 5.2,
        "melee_range": 2.9,
        "visual_scale": 1.24,
        "behavior": "charger",
        "lunge_speed": 11.0,
        "body_mesh": {"type": "cylinder", "height": 1.75, "top_radius": 0.46, "bottom_radius": 0.54},
        "head_mesh": {"type": "box", "size": Vector3(0.44, 0.52, 0.46)},
        "visor_mesh": {"type": "box", "size": Vector3(0.32, 0.2, 0.32), "origin": Vector3(0, 1.02, -0.36)},
        "harness_mesh": {"type": "capsule", "radius": 0.32, "height": 0.72, "origin": Vector3(0, 0.58, 0)},
        "style_override": {
            "body": Color(0.64, 0.44, 0.32),
            "accent": Color(1.0, 0.58, 0.32),
            "light": Color(1.08, 0.62, 0.38),
            "attachments": [
                {"type": "blade", "offset": Vector3(0.56, 0.54, -0.08)},
                {"type": "backpack", "offset": Vector3(0, 0.46, 0.44)},
            ],
        },
    },
    {
        "id": "skirmisher",
        "health": 110.0,
        "damage": 18.0,
        "speed": 7.4,
        "strafe_speed": 6.2,
        "melee_range": 2.4,
        "visual_scale": 1.1,
        "body_mesh": {"type": "prism", "size": Vector3(0.82, 1.55, 0.72)},
        "head_mesh": {"type": "cylinder", "height": 0.46, "top_radius": 0.3, "bottom_radius": 0.32},
        "visor_mesh": {"type": "prism", "size": Vector3(0.28, 0.18, 0.62), "origin": Vector3(0, 0.96, -0.34)},
        "harness_mesh": {"type": "capsule", "radius": 0.26, "height": 0.64, "origin": Vector3(0, 0.48, 0)},
        "style_override": {
            "body": Color(0.38, 0.64, 0.92),
            "accent": Color(0.32, 0.92, 0.72),
            "light": Color(0.4, 0.94, 0.88),
            "attachments": [
                {"type": "antenna", "offset": Vector3(0.2, 1.18, -0.12)},
                {"type": "visor_ridge", "offset": Vector3(0, 1.0, -0.4)},
            ],
        },
    },
    {
        "id": "lurker",
        "health": 125.0,
        "damage": 20.0,
        "speed": 6.0,
        "strafe_speed": 5.6,
        "melee_range": 2.5,
        "visual_scale": 1.08,
        "behavior": "lurker",
        "body_mesh": {"type": "prism", "size": Vector3(0.9, 1.46, 0.62)},
        "head_mesh": {"type": "capsule", "radius": 0.28, "height": 0.36},
        "visor_mesh": {"type": "torus", "inner_radius": 0.14, "outer_radius": 0.22, "ring_segments": 18, "rings": 10, "origin": Vector3(0, 0.92, -0.18)},
        "harness_mesh": {"type": "box", "size": Vector3(0.44, 0.32, 0.46), "origin": Vector3(0, 0.56, 0)},
        "style_override": {
            "body": Color(0.36, 0.58, 0.64),
            "accent": Color(0.4, 0.9, 0.88),
            "light": Color(0.5, 0.96, 0.96),
            "attachments": [
                {"type": "visor_ridge", "offset": Vector3(0, 0.92, -0.34)},
                {"type": "shoulder_plate", "offset": Vector3(-0.46, 0.52, 0)},
            ],
        },
    },
    {
        "id": "vanguard",
        "health": 125.0,
        "damage": 22.0,
        "speed": 6.4,
        "strafe_speed": 5.4,
        "melee_range": 2.6,
        "visual_scale": 1.18,
        "body_mesh": {"type": "cylinder", "height": 1.65, "top_radius": 0.42, "bottom_radius": 0.5},
        "head_mesh": {"type": "box", "size": Vector3(0.42, 0.46, 0.42)},
        "visor_mesh": {"type": "torus", "inner_radius": 0.14, "outer_radius": 0.26, "ring_segments": 20, "rings": 12, "origin": Vector3(0, 0.96, -0.2)},
        "harness_mesh": {"type": "prism", "size": Vector3(0.48, 0.32, 0.48), "origin": Vector3(0, 0.6, 0)},
        "style_override": {
            "body": Color(0.6, 0.48, 0.82),
            "accent": Color(0.78, 0.56, 1.0),
            "light": Color(1.02, 0.72, 1.1),
            "attachments": [
                {"type": "backpack", "offset": Vector3(0, 0.52, 0.4)},
                {"type": "shoulder_plate", "offset": Vector3(0.48, 0.48, 0)},
            ],
        },
    },
    {
        "id": "sentinel",
        "health": 175.0,
        "damage": 24.0,
        "speed": 5.2,
        "strafe_speed": 4.8,
        "melee_range": 3.0,
        "visual_scale": 1.32,
        "behavior": "charger",
        "lunge_speed": 12.0,
        "body_mesh": {"type": "capsule", "radius": 0.42, "height": 1.9},
        "head_mesh": {"type": "box", "size": Vector3(0.46, 0.5, 0.46)},
        "visor_mesh": {"type": "torus", "inner_radius": 0.12, "outer_radius": 0.26, "ring_segments": 20, "rings": 12, "origin": Vector3(0, 1.02, -0.2)},
        "harness_mesh": {"type": "box", "size": Vector3(0.5, 0.36, 0.52), "origin": Vector3(0, 0.62, 0)},
        "style_override": {
            "body": Color(0.32, 0.48, 0.58),
            "accent": Color(0.36, 0.8, 0.92),
            "light": Color(0.52, 0.92, 1.0),
            "attachments": [
                {"type": "pauldron", "offset": Vector3(0.58, 0.64, 0)},
                {"type": "shoulder_plate", "offset": Vector3(-0.58, 0.6, 0)},
            ],
        },
    },
    {
        "id": "phantom",
        "health": 115.0,
        "damage": 20.0,
        "speed": 7.8,
        "strafe_speed": 6.8,
        "melee_range": 2.45,
        "visual_scale": 1.06,
        "behavior": "lurker",
        "body_mesh": {"type": "capsule", "radius": 0.34, "height": 1.5},
        "head_mesh": {"type": "torus", "inner_radius": 0.12, "outer_radius": 0.2, "ring_segments": 18, "rings": 12},
        "visor_mesh": {"type": "prism", "size": Vector3(0.26, 0.16, 0.54), "origin": Vector3(0, 0.9, -0.34)},
        "harness_mesh": {"type": "prism", "size": Vector3(0.42, 0.28, 0.46), "origin": Vector3(0, 0.54, 0)},
        "style_override": {
            "body": Color(0.28, 0.44, 0.7),
            "accent": Color(0.44, 0.94, 0.96),
            "light": Color(0.62, 1.02, 1.08),
            "attachments": [
                {"type": "antenna", "offset": Vector3(0.18, 1.12, -0.2)},
                {"type": "visor_ridge", "offset": Vector3(0, 0.92, -0.36)},
            ],
        },
    },
]

const RANGED_VARIANTS := [
    {
        "id": "artillerist",
        "health": 105.0,
        "damage": 16.0,
        "speed": 5.8,
        "strafe_speed": 6.2,
        "preferred_distance": 13.5,
        "ranged_range": 21.0,
        "visual_scale": 1.15,
        "behavior": "skirmisher",
        "burst_count": 2,
        "burst_interval": 0.08,
        "body_mesh": {"type": "box", "size": Vector3(0.9, 1.5, 0.7)},
        "head_mesh": {"type": "capsule", "radius": 0.32, "height": 0.38},
        "visor_mesh": {"type": "prism", "size": Vector3(0.32, 0.2, 0.62), "origin": Vector3(0, 0.92, -0.36)},
        "harness_mesh": {"type": "cylinder", "height": 0.54, "top_radius": 0.3, "bottom_radius": 0.32, "origin": Vector3(0, 0.52, 0)},
        "style_override": {
            "body": Color(0.34, 0.58, 0.98),
            "accent": Color(0.44, 0.82, 1.0),
            "light": Color(0.42, 0.86, 1.1),
            "attachments": [
                {"type": "antenna", "offset": Vector3(0.16, 1.14, -0.2)},
                {"type": "shoulder_plate", "offset": Vector3(-0.42, 0.52, 0)},
            ],
        },
    },
    {
        "id": "marksman",
        "health": 90.0,
        "damage": 14.0,
        "speed": 6.6,
        "strafe_speed": 6.8,
        "preferred_distance": 15.0,
        "ranged_range": 22.5,
        "visual_scale": 1.08,
        "behavior": "flanker",
        "body_mesh": {"type": "prism", "size": Vector3(0.76, 1.46, 0.68)},
        "head_mesh": {"type": "cylinder", "height": 0.36, "top_radius": 0.28, "bottom_radius": 0.3},
        "visor_mesh": {"type": "box", "size": Vector3(0.28, 0.2, 0.5), "origin": Vector3(0, 0.9, -0.34)},
        "harness_mesh": {"type": "capsule", "radius": 0.24, "height": 0.5, "origin": Vector3(0, 0.48, 0)},
        "style_override": {
            "body": Color(0.28, 0.74, 0.74),
            "accent": Color(0.32, 1.0, 0.86),
            "light": Color(0.48, 1.02, 0.92),
            "attachments": [
                {"type": "visor_ridge", "offset": Vector3(0, 0.9, -0.32)},
                {"type": "blade", "offset": Vector3(0.42, 0.36, -0.1)},
            ],
        },
    },
    {
        "id": "suppressor",
        "health": 120.0,
        "damage": 18.0,
        "speed": 5.4,
        "strafe_speed": 5.8,
        "preferred_distance": 11.0,
        "ranged_range": 19.5,
        "visual_scale": 1.22,
        "behavior": "turret",
        "burst_count": 3,
        "burst_interval": 0.05,
        "body_mesh": {"type": "cylinder", "height": 1.58, "top_radius": 0.44, "bottom_radius": 0.46},
        "head_mesh": {"type": "box", "size": Vector3(0.38, 0.42, 0.4)},
        "visor_mesh": {"type": "torus", "inner_radius": 0.12, "outer_radius": 0.22, "ring_segments": 18, "rings": 12, "origin": Vector3(0, 0.92, -0.18)},
        "harness_mesh": {"type": "box", "size": Vector3(0.5, 0.34, 0.5), "origin": Vector3(0, 0.54, 0)},
        "style_override": {
            "body": Color(0.52, 0.48, 0.72),
            "accent": Color(0.78, 0.62, 1.02),
            "light": Color(0.98, 0.72, 1.06),
            "attachments": [
                {"type": "backpack", "offset": Vector3(0, 0.48, 0.38)},
                {"type": "pauldron", "offset": Vector3(-0.48, 0.58, 0)},
            ],
        },
    },
    {
        "id": "spotter",
        "health": 95.0,
        "damage": 14.0,
        "speed": 6.8,
        "strafe_speed": 7.2,
        "preferred_distance": 17.5,
        "ranged_range": 24.0,
        "visual_scale": 1.04,
        "behavior": "skirmisher",
        "burst_count": 1,
        "body_mesh": {"type": "box", "size": Vector3(0.7, 1.36, 0.6)},
        "head_mesh": {"type": "torus", "inner_radius": 0.12, "outer_radius": 0.22, "ring_segments": 16, "rings": 12},
        "visor_mesh": {"type": "prism", "size": Vector3(0.24, 0.16, 0.5), "origin": Vector3(0, 0.92, -0.34)},
        "harness_mesh": {"type": "cylinder", "height": 0.4, "top_radius": 0.26, "bottom_radius": 0.3, "origin": Vector3(0, 0.52, 0)},
        "style_override": {
            "body": Color(0.32, 0.72, 0.78),
            "accent": Color(0.42, 0.98, 0.86),
            "light": Color(0.46, 1.08, 0.96),
            "attachments": [
                {"type": "antenna", "offset": Vector3(0.18, 1.12, -0.2)},
                {"type": "visor_ridge", "offset": Vector3(0, 0.96, -0.36)},
            ],
        },
    },
    {
        "id": "warden",
        "health": 135.0,
        "damage": 20.0,
        "speed": 5.2,
        "strafe_speed": 5.5,
        "preferred_distance": 12.0,
        "ranged_range": 18.5,
        "visual_scale": 1.3,
        "behavior": "flanker",
        "burst_count": 2,
        "burst_interval": 0.06,
        "body_mesh": {"type": "prism", "size": Vector3(0.92, 1.6, 0.78)},
        "head_mesh": {"type": "cylinder", "height": 0.48, "top_radius": 0.32, "bottom_radius": 0.34},
        "visor_mesh": {"type": "box", "size": Vector3(0.32, 0.2, 0.52), "origin": Vector3(0, 1.02, -0.36)},
        "harness_mesh": {"type": "capsule", "radius": 0.3, "height": 0.7, "origin": Vector3(0, 0.64, 0)},
        "style_override": {
            "body": Color(0.46, 0.42, 0.7),
            "accent": Color(0.76, 0.52, 1.02),
            "light": Color(0.96, 0.66, 1.14),
            "attachments": [
                {"type": "backpack", "offset": Vector3(0, 0.58, 0.46)},
                {"type": "pauldron", "offset": Vector3(0.54, 0.62, 0)},
            ],
        },
    },
    {
        "id": "grenadier",
        "health": 140.0,
        "damage": 22.0,
        "speed": 5.6,
        "strafe_speed": 5.8,
        "preferred_distance": 16.0,
        "ranged_range": 20.0,
        "visual_scale": 1.2,
        "behavior": "turret",
        "burst_count": 1,
        "body_mesh": {"type": "box", "size": Vector3(0.92, 1.52, 0.8)},
        "head_mesh": {"type": "capsule", "radius": 0.34, "height": 0.42},
        "visor_mesh": {"type": "prism", "size": Vector3(0.32, 0.2, 0.54), "origin": Vector3(0, 0.96, -0.34)},
        "harness_mesh": {"type": "cylinder", "height": 0.6, "top_radius": 0.32, "bottom_radius": 0.34, "origin": Vector3(0, 0.52, 0)},
        "style_override": {
            "body": Color(0.46, 0.38, 0.46),
            "accent": Color(0.8, 0.58, 0.32),
            "light": Color(1.0, 0.66, 0.34),
            "attachments": [
                {"type": "backpack", "offset": Vector3(0, 0.56, 0.5)},
                {"type": "shoulder_plate", "offset": Vector3(-0.46, 0.52, 0)},
            ],
        },
    },
    {
        "id": "drifter",
        "health": 100.0,
        "damage": 16.0,
        "speed": 7.2,
        "strafe_speed": 7.5,
        "preferred_distance": 18.0,
        "ranged_range": 23.0,
        "visual_scale": 1.1,
        "behavior": "flanker",
        "burst_count": 3,
        "burst_interval": 0.06,
        "body_mesh": {"type": "prism", "size": Vector3(0.82, 1.48, 0.66)},
        "head_mesh": {"type": "torus", "inner_radius": 0.12, "outer_radius": 0.22, "ring_segments": 16, "rings": 12},
        "visor_mesh": {"type": "box", "size": Vector3(0.26, 0.18, 0.46), "origin": Vector3(0, 0.9, -0.32)},
        "harness_mesh": {"type": "capsule", "radius": 0.26, "height": 0.56, "origin": Vector3(0, 0.52, 0)},
        "style_override": {
            "body": Color(0.32, 0.62, 0.82),
            "accent": Color(0.46, 1.0, 0.88),
            "light": Color(0.58, 1.06, 0.98),
            "attachments": [
                {"type": "visor_ridge", "offset": Vector3(0, 0.96, -0.34)},
                {"type": "antenna", "offset": Vector3(0.18, 1.08, -0.2)},
            ],
        },
    },
]

@export_enum("melee", "ranged") var attack_type := "melee"
@export var speed := 6.0
@export var strafe_speed := 4.5
@export var health := 90.0
@export var damage := 18.0
@export var attack_cooldown := 1.2
@export var attack_windup := 0.35
@export var melee_range := 2.3
@export var ranged_range := 16.0
@export var preferred_ranged_distance := 9.5
@export var projectile_scene: PackedScene = DEFAULT_PROJECTILE_SCENE
@export var explosion_scene: PackedScene = DEFAULT_EXPLOSION_SCENE
@export var projectile_spread := 0.03
@export var projectile_speed := 40.0
@export var stagger_time := 0.2
@export var death_fade_time := 1.1
@export var eye_height := 1.1
@export var idle_sway_speed := 2.7
@export var idle_sway_amount := 0.06

var target: Node3D

var attack_timer := 0.0
var cooldown_timer := 0.0
var stagger_timer := 0.0
var is_attacking := false
var is_dead := false
var base_visual_height := 0.0
var strafe_jitter := Vector3.ZERO
var jitter_timer := 0.0
var rng := RandomNumberGenerator.new()
var chosen_variant := {}
var variant_behavior := "standard"
var burst_count := 1
var burst_interval := 0.0
var lunge_speed := 0.0
var roam_timer := 0.0
var roam_offset := Vector3.ZERO

@onready var visual: Node3D = $Visual
@onready var health_label: Label3D = $HealthLabel
@onready var muzzle: Marker3D = $Visual/Muzzle
@onready var hitbox: CollisionShape3D = $CollisionShape3D
@onready var glow: OmniLight3D = $Visual/Glow
@onready var body_mesh: MeshInstance3D = $Visual/Body
@onready var head_mesh: MeshInstance3D = $Visual/Head
@onready var accent_meshes: Array = [$Visual/Visor, $Visual.get_node_or_null("Joints"), $Visual.get_node_or_null("Harness")]

func _ready():
    add_to_group("enemies")
    rng.randomize()
    floor_snap_length = max(floor_snap_length, 0.6)
    explosion_scene = explosion_scene if explosion_scene else DEFAULT_EXPLOSION_SCENE
    projectile_scene = projectile_scene if projectile_scene else DEFAULT_PROJECTILE_SCENE
    base_visual_height = visual.position.y
    _apply_variant_profile()
    update_health_label()

func _physics_process(delta):
    if is_dead:
        return
    if not target:
        _idle_sway(delta)
        return

    cooldown_timer = max(0.0, cooldown_timer - delta)
    stagger_timer = max(0.0, stagger_timer - delta)
    jitter_timer = max(0.0, jitter_timer - delta)
    roam_timer = max(0.0, roam_timer - delta)

    var to_target = (target.global_transform.origin - global_transform.origin)
    var dir = to_target.normalized()
    var distance = to_target.length()
    look_at(target.global_transform.origin, Vector3.UP)

    if not is_on_floor():
        velocity.y = max(velocity.y - gravity * delta, -25.0)
    else:
        velocity.y = -4.0

    if is_attacking:
        attack_timer -= delta
        if attack_timer <= 0.0:
            _finish_attack(distance, dir)
        return

    if stagger_timer > 0.0:
        velocity = Vector3.ZERO
        move_and_slide()
        _idle_sway(delta)
        return

    _choose_movement(dir, distance)
    move_and_slide()
    _idle_sway(delta)

    if cooldown_timer <= 0.0:
        if attack_type == "melee" and distance <= melee_range:
            _start_attack()
        elif attack_type == "ranged" and distance <= ranged_range:
            _start_attack()

func _choose_movement(dir: Vector3, distance: float):
    if jitter_timer <= 0.0:
        jitter_timer = rng.randf_range(0.7, 1.4)
        var lateral := Vector3(-dir.z, 0, dir.x) * rng.randf_range(-0.9, 0.9)
        strafe_jitter = lateral.normalized() * rng.randf_range(0.4, 1.0)
    if roam_timer <= 0.0 and variant_behavior == "lurker":
        roam_timer = rng.randf_range(0.6, 1.4)
        roam_offset = Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0))

    if attack_type == "ranged":
        var desired_dir = dir
        var speed_scale := 1.0
        match variant_behavior:
            "flanker":
                desired_dir = (strafe_jitter + Vector3.ZERO).normalized()
                speed_scale = 1.05
            "skirmisher":
                desired_dir = (dir + strafe_jitter * 1.2).normalized()
                speed_scale = 0.95
            "turret":
                desired_dir = Vector3.ZERO
                speed_scale = 0.15
            _:
                desired_dir = dir
                speed_scale = 1.0
        if distance < preferred_ranged_distance - 1.0:
            desired_dir = -dir
            speed_scale = 0.9
        elif distance > preferred_ranged_distance + 1.5:
            desired_dir = dir
            speed_scale = max(speed_scale, 1.0)
        else:
            desired_dir = (desired_dir + strafe_jitter * 0.7).normalized()
            speed_scale = max(speed_scale, 0.85)
        velocity.x = desired_dir.x * strafe_speed * speed_scale
        velocity.z = desired_dir.z * strafe_speed * speed_scale
    else:
        var angled := (dir + strafe_jitter * 0.6 + roam_offset * 0.4).normalized()
        var chase_speed := speed * 1.05
        if variant_behavior == "charger" and distance > melee_range * 0.8:
            chase_speed *= 1.15
        elif variant_behavior == "lurker" and distance < melee_range * 1.5:
            angled = (strafe_jitter - dir * 0.4).normalized()
            chase_speed *= 0.9
        velocity.x = angled.x * chase_speed
        velocity.z = angled.z * chase_speed

func _idle_sway(delta: float):
    var sway := sin(Time.get_ticks_msec() / 1000.0 * idle_sway_speed) * idle_sway_amount
    visual.position.y = lerp(visual.position.y, base_visual_height + sway, 8.0 * delta)

func _start_attack():
    is_attacking = true
    attack_timer = attack_windup
    cooldown_timer = attack_cooldown
    _animate_attack_windup()

func _finish_attack(distance: float, dir: Vector3):
    is_attacking = false
    if attack_type == "melee":
        if distance <= melee_range + 0.6 and target and target.has_method("take_damage"):
            target.take_damage(damage)
        if lunge_speed > 0.0 and is_on_floor():
            var dash_dir := dir
            velocity.x = dash_dir.x * lunge_speed
            velocity.z = dash_dir.z * lunge_speed
    else:
        if burst_count > 1 and burst_interval > 0.0:
            for i in range(burst_count):
                var wait := burst_interval * i
                await get_tree().create_timer(wait).timeout
                _fire_projectile(dir)
        else:
            _fire_projectile(dir)
    _animate_attack_release()

func _animate_attack_windup():
    if not visual:
        return
    var tween := create_tween()
    var dip := -16.0 if attack_type == "melee" else -9.0
    tween.tween_property(visual, "rotation_degrees:x", dip, attack_windup * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(visual, "rotation_degrees:x", 0.0, attack_windup * 0.3).set_trans(Tween.TRANS_LINEAR)

func _animate_attack_release():
    if not visual:
        return
    var tween := create_tween()
    if attack_type == "melee":
        tween.tween_property(visual, "position:z", visual.position.z - 0.32, 0.18).set_trans(Tween.TRANS_QUAD)
        tween.parallel().tween_property(visual, "rotation_degrees:x", 12.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    else:
        tween.tween_property(visual, "rotation_degrees:z", rng.randf_range(-6.0, 6.0), 0.18).set_trans(Tween.TRANS_CUBIC)
        tween.parallel().tween_property(visual, "rotation_degrees:x", 7.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(visual, "rotation_degrees", Vector3.ZERO, 0.28).set_trans(Tween.TRANS_LINEAR)
    tween.parallel().tween_property(visual, "position:z", 0.0, 0.2).set_trans(Tween.TRANS_SINE)

func _fire_projectile(dir: Vector3):
    if projectile_scene == null:
        return
    var spawn_dir = dir
    if muzzle:
        var target_pos = target.global_transform.origin + Vector3(0, 1.4, 0)
        spawn_dir = (target_pos - muzzle.global_transform.origin).normalized()
    spawn_dir += Vector3(
        randf_range(-projectile_spread, projectile_spread),
        randf_range(-projectile_spread, projectile_spread),
        randf_range(-projectile_spread, projectile_spread)
    )
    spawn_dir = spawn_dir.normalized()
    var projectile = projectile_scene.instantiate()
    var spawn_origin := muzzle.global_transform.origin if muzzle else global_transform.origin + Vector3(0, eye_height, 0)
    var spawn_basis := Basis.looking_at(spawn_dir, Vector3.UP)
    projectile.global_transform = Transform3D(spawn_basis, spawn_origin)
    projectile.set("velocity", spawn_dir * projectile_speed)
    projectile.set("damage", damage)
    projectile.set("creator", self)
    projectile.set("explosion_scene", explosion_scene)
    get_tree().current_scene.add_child(projectile)

func update_health_label():
    if not health_label:
        return
    health_label.text = str(round(health))

func take_damage(amount: float):
    if is_dead:
        return
    health = clamp(health - amount, 0.0, 999.0)
    stagger_timer = max(stagger_timer, stagger_time)
    update_health_label()
    _animate_hurt()
    if health <= 0.0:
        die()

func _animate_hurt():
    if not visual:
        return
    var tween := create_tween()
    tween.tween_property(visual, "scale", visual.scale * 0.94, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(visual, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_SINE)

func die():
    if is_dead:
        return
    is_dead = true
    set_physics_process(false)
    velocity = Vector3.ZERO
    if hitbox:
        hitbox.disabled = true
    if health_label:
        health_label.text = "✖"
        health_label.modulate = Color(1, 0.4, 0.3)
    _animate_death()
    if explosion_scene:
        var explosion = explosion_scene.instantiate()
        explosion.global_transform.origin = global_transform.origin
        get_tree().current_scene.add_child(explosion)
    await get_tree().create_timer(death_fade_time).timeout
    queue_free()

func _animate_death():
    if not visual:
        return
    var tween := create_tween()
    tween.tween_property(visual, "rotation_degrees:z", 30.0, death_fade_time * 0.4).set_trans(Tween.TRANS_BACK)
    tween.tween_property(visual, "position:y", visual.position.y - 0.8, death_fade_time * 0.6).set_trans(Tween.TRANS_SINE)
    tween.parallel().tween_property(visual, "scale", visual.scale * 0.1, death_fade_time).set_ease(Tween.EASE_IN)

func _apply_variant_profile():
    var pool: Array = RANGED_VARIANTS if attack_type == "ranged" else MELEE_VARIANTS
    chosen_variant = pool[rng.randi_range(0, pool.size() - 1)]

    health = chosen_variant.get("health", health)
    damage = chosen_variant.get("damage", damage)
    speed = chosen_variant.get("speed", speed)
    strafe_speed = chosen_variant.get("strafe_speed", strafe_speed)
    melee_range = chosen_variant.get("melee_range", melee_range)
    ranged_range = chosen_variant.get("ranged_range", ranged_range)
    preferred_ranged_distance = chosen_variant.get("preferred_distance", preferred_ranged_distance)
    attack_windup = chosen_variant.get("attack_windup", attack_windup)
    attack_cooldown = chosen_variant.get("attack_cooldown", attack_cooldown)
    burst_count = chosen_variant.get("burst_count", 1)
    burst_interval = chosen_variant.get("burst_interval", 0.0)
    lunge_speed = chosen_variant.get("lunge_speed", 0.0)
    variant_behavior = chosen_variant.get("behavior", "standard")
    _configure_roaming()
    idle_sway_amount = max(idle_sway_amount, 0.04)
    _apply_variant_geometry(chosen_variant)
    _apply_variant_style(chosen_variant.get("style_override"))
    update_health_label()

func _configure_roaming():
    if variant_behavior == "lurker":
        roam_timer = rng.randf_range(0.8, 1.8)
        roam_offset = Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
    else:
        roam_timer = 0.0
        roam_offset = Vector3.ZERO

func _apply_variant_geometry(variant: Dictionary):
    var scale_multiplier: float = variant.get("visual_scale", 1.15)
    visual.scale = Vector3.ONE * scale_multiplier
    _assign_mesh(body_mesh, variant.get("body_mesh", {}))
    _assign_mesh(head_mesh, variant.get("head_mesh", {}))
    if $Visual.has_node("Visor"):
        _assign_mesh($Visual/Visor, variant.get("visor_mesh", {}))
    if $Visual.has_node("Joints"):
        _assign_mesh($Visual/Joints, variant.get("harness_mesh", {}))
    if $Visual.has_node("Harness"):
        _assign_mesh($Visual/Harness, variant.get("harness_mesh", {}))
    if muzzle and variant.has("muzzle_height"):
        muzzle.position.y = variant.get("muzzle_height")
    eye_height = max(1.35, variant.get("eye_height", eye_height * scale_multiplier))
    if hitbox and hitbox.shape is CapsuleShape3D:
        var capsule: CapsuleShape3D = hitbox.shape
        capsule.radius = 0.55 * scale_multiplier
        capsule.height = 1.5 * scale_multiplier
    if health_label:
        var target_height: float = 2.2 * scale_multiplier
        health_label.position.y = target_height

func _apply_variant_style(style_override: Dictionary = {}):
    var style: Dictionary = style_override if not style_override.is_empty() else VARIANT_STYLES[rng.randi_range(0, VARIANT_STYLES.size() - 1)]
    _tint_mesh(body_mesh, style.get("body", Color.WHITE))
    _tint_mesh(head_mesh, style.get("body", Color.WHITE))
    accent_meshes.clear()
    var visor := $Visual.get_node_or_null("Visor")
    var harness := $Visual.get_node_or_null("Harness")
    if harness == null:
        harness = $Visual.get_node_or_null("Joints")
    if visor:
        accent_meshes.append(visor)
    if harness:
        accent_meshes.append(harness)
    var has_accent := style.has("accent")
    var accent_color: Color = style.get("accent", Color.WHITE)
    for mesh in accent_meshes:
        if mesh:
            var tint := accent_color if has_accent else _get_mesh_color(mesh)
            _tint_mesh(mesh, tint)
    if glow:
        glow.light_color = style.get("light", glow.light_color)
        glow.light_energy = 1.0 + rng.randf_range(-0.1, 0.3)
    _spawn_attachments(style.get("attachments", []), style.get("accent", Color(0.9, 0.9, 0.9)))

func _tint_mesh(mesh: MeshInstance3D, color: Color):
    if not mesh:
        return
    var mat: BaseMaterial3D
    if mesh.material_override and mesh.material_override is BaseMaterial3D:
        mat = mesh.material_override.duplicate()
    else:
        mat = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.emission_enabled = true
    mat.emission = color * 0.35
    mesh.material_override = mat

func _get_mesh_color(mesh: MeshInstance3D) -> Color:
    if not mesh:
        return Color.WHITE
    if mesh.material_override and mesh.material_override is BaseMaterial3D:
        return mesh.material_override.albedo_color
    if mesh.mesh:
        var surface_mat := mesh.mesh.surface_get_material(0)
        if surface_mat is BaseMaterial3D:
            return surface_mat.albedo_color
    return Color.WHITE

func _spawn_attachments(attachments: Array, accent: Color):
    for data in attachments:
        if not data is Dictionary:
            continue
        var mesh_instance := MeshInstance3D.new()
        mesh_instance.mesh = _build_attachment_mesh(data.get("type", ""))
        mesh_instance.material_override = StandardMaterial3D.new()
        mesh_instance.material_override.albedo_color = accent
        mesh_instance.material_override.emission_enabled = true
        mesh_instance.material_override.emission = accent * 0.4
        mesh_instance.position = data.get("offset", Vector3.ZERO)
        mesh_instance.rotation_degrees = Vector3(rng.randf_range(-8, 8), rng.randf_range(0, 360), rng.randf_range(-8, 8))
        if mesh_instance.mesh:
            visual.add_child(mesh_instance)

func _assign_mesh(node: MeshInstance3D, data: Dictionary):
    if node == null:
        return
    var new_mesh := _build_variant_mesh(data)
    if new_mesh:
        node.mesh = new_mesh
    if data.has("origin"):
        node.position = data.get("origin")
    if data.has("rotation_degrees"):
        node.rotation_degrees = data.get("rotation_degrees")
    if data.has("scale"):
        node.scale = data.get("scale")

func _build_variant_mesh(data: Dictionary) -> Mesh:
    if data.is_empty():
        return null
    match data.get("type"):
        "box":
            var box := BoxMesh.new()
            box.size = data.get("size", Vector3.ONE)
            return box
        "prism":
            var prism := PrismMesh.new()
            prism.size = data.get("size", Vector3.ONE)
            return prism
        "cylinder":
            var cylinder := CylinderMesh.new()
            cylinder.height = data.get("height", 1.0)
            cylinder.top_radius = data.get("top_radius", 0.35)
            cylinder.bottom_radius = data.get("bottom_radius", 0.35)
            cylinder.radial_segments = data.get("segments", 18)
            return cylinder
        "capsule":
            var capsule := CapsuleMesh.new()
            capsule.radius = data.get("radius", 0.32)
            capsule.height = data.get("height", 0.6)
            capsule.radial_segments = data.get("segments", 12)
            return capsule
        "torus":
            var torus := TorusMesh.new()
            torus.inner_radius = data.get("inner_radius", 0.12)
            torus.outer_radius = data.get("outer_radius", 0.24)
            torus.ring_segments = data.get("ring_segments", 12)
            torus.rings = data.get("rings", 10)
            return torus
        _:
            return null

func _build_attachment_mesh(kind: String) -> Mesh:
    match kind:
        "blade":
            var prism := PrismMesh.new()
            prism.size = Vector3(0.16, 0.16, 0.8)
            return prism
        "pauldron":
            var box := BoxMesh.new()
            box.size = Vector3(0.44, 0.32, 0.4)
            return box
        "antenna":
            var cylinder := CylinderMesh.new()
            cylinder.height = 0.5
            cylinder.top_radius = 0.05
            cylinder.bottom_radius = 0.07
            return cylinder
        "backpack":
            var box2 := BoxMesh.new()
            box2.size = Vector3(0.48, 0.56, 0.3)
            return box2
        "visor_ridge":
            var ridge := PrismMesh.new()
            ridge.size = Vector3(0.38, 0.18, 0.5)
            return ridge
        "shoulder_plate":
            var plate := CylinderMesh.new()
            plate.height = 0.32
            plate.top_radius = 0.32
            plate.bottom_radius = 0.36
            return plate
        _:
            var default_box := BoxMesh.new()
            default_box.size = Vector3(0.28, 0.28, 0.28)
            return default_box
