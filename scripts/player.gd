extends CharacterBody3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

const DEFAULT_PROJECTILE_SCENE := preload("res://scenes/Projectile.tscn")
const DEFAULT_EXPLOSION_SCENE := preload("res://scenes/Explosion.tscn")

@export var speed := 10.0
@export var sprint_multiplier := 1.6
@export var crouch_multiplier := 0.6
@export var jump_velocity := 4.5
@export var camera_sensitivity := 0.002
@export var head_bob_speed := 7.5
@export var head_bob_amount := 0.045
@export var camera_shake := 0.08
@export var projectile_scene: PackedScene = DEFAULT_PROJECTILE_SCENE
@export var explosion_scene: PackedScene = DEFAULT_EXPLOSION_SCENE
@export var max_health := 100.0

var weapons := []
var current_weapon_index := 0
var cooldown := 0.0
var rng := RandomNumberGenerator.new()
var health := 100.0
var bob_time := 0.0
var damage_shake_time := 0.0
var weapon_rest_position := Vector3.ZERO

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var muzzle: Marker3D = $Head/Muzzle
@onready var weapon_mesh: MeshInstance3D = $Head/WeaponMesh
@onready var fire_audio: AudioStreamPlayer3D = $Head/FireAudio
@onready var hurt_audio: AudioStreamPlayer3D = $Head/HurtAudio
@onready var step_audio: AudioStreamPlayer3D = $Head/StepAudio
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready():
    rng.randomize()
    health = max_health
    projectile_scene = projectile_scene if projectile_scene else DEFAULT_PROJECTILE_SCENE
    explosion_scene = explosion_scene if explosion_scene else DEFAULT_EXPLOSION_SCENE
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    weapon_rest_position = weapon_mesh.position
    update_hud()

func set_weapons(list: Array):
    weapons = list.duplicate()
    current_weapon_index = 0
    update_hud()

func _unhandled_input(event):
    if event is InputEventMouseMotion:
        rotate_y(-event.relative.x * camera_sensitivity)
        head.rotate_x(-event.relative.y * camera_sensitivity)
        head.rotation_degrees.x = clamp(head.rotation_degrees.x, -80, 80)
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
    if not is_on_floor():
        velocity.y -= gravity * delta
    var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    var is_crouching = Input.is_action_pressed("crouch")
    var target_speed = speed * (sprint_multiplier if Input.is_action_pressed("sprint") and not is_crouching else 1.0)
    if is_crouching:
        target_speed *= crouch_multiplier
    velocity.x = direction.x * target_speed
    velocity.z = direction.z * target_speed
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = jump_velocity
    move_and_slide()
    apply_crouch(delta, is_crouching)
    apply_headbob(delta, direction)

func _process(delta):
    if cooldown > 0.0:
        cooldown = max(0.0, cooldown - delta)
    if Input.is_action_just_pressed("switch_next"):
        switch_weapon(1)
    elif Input.is_action_just_pressed("switch_prev"):
        switch_weapon(-1)
    if Input.is_action_pressed("fire"):
        shoot()

func switch_weapon(step: int):
    if weapons.is_empty():
        return
    current_weapon_index = wrapi(current_weapon_index + step, 0, weapons.size())
    update_hud()

func shoot():
    if weapons.is_empty():
        return
    var data: Dictionary = weapons[current_weapon_index]
    var rate = 1.0 / max(0.01, data.get("fire_rate", 2.0))
    if cooldown > 0.0:
        return
    cooldown = rate
    var pellets = data.get("pellets", 1)
    for i in range(pellets):
        var spread = data.get("spread", 0.0)
        var dir = -head.global_transform.basis.z
        dir = (dir + Vector3(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread), rng.randf_range(-spread, spread))).normalized()
        spawn_projectile(dir, data)
    if fire_audio:
        fire_audio.play()
    apply_recoil()
    update_hud()

func spawn_projectile(direction: Vector3, weapon_data: Dictionary):
    if projectile_scene == null:
        return
    var projectile = projectile_scene.instantiate()
    projectile.global_transform.origin = muzzle.global_transform.origin
    projectile.look_at(muzzle.global_transform.origin + direction)
    projectile.set("velocity", direction * weapon_data.get("projectile_speed", 40.0))
    projectile.set("damage", weapon_data.get("damage", 10.0))
    projectile.set("explosive", weapon_data.get("explosive", false))
    projectile.set("explosion_scene", explosion_scene)
    projectile.set("creator", self)
    projectile.scale = Vector3.ONE * weapon_data.get("projectile_scale", 0.2)
    get_tree().current_scene.add_child(projectile)

func pickup_weapon(weapon_id: String):
    for i in weapons.size():
        if weapons[i].get("id", "") == weapon_id:
            current_weapon_index = i
            update_hud()
            return
    update_hud()

func update_hud():
    var hud = get_tree().get_first_node_in_group("hud")
    if hud:
        hud.update_weapon_label(weapons, current_weapon_index, cooldown)
        hud.update_health(health, max_health)

func take_damage(amount: float):
    health = clamp(health - amount, 0.0, max_health)
    update_hud()
    damage_shake_time = 0.25
    if hurt_audio:
        hurt_audio.play()
    var hud = get_tree().get_first_node_in_group("hud")
    if hud and hud.has_method("flash_damage"):
        hud.flash_damage()
    if health <= 0:
        die()

func die():
    queue_free()

func apply_crouch(delta: float, is_crouching: bool):
    var target_height = 1.0 if is_crouching else 1.5
    head.position.y = lerp(head.position.y, target_height, 10.0 * delta)
    var shape: CapsuleShape3D = collision_shape.shape
    if shape:
        shape.height = lerp(shape.height, 1.2 if is_crouching else 1.8, 8.0 * delta)

func apply_headbob(delta: float, _direction: Vector3):
    var horizontal_speed = Vector2(velocity.x, velocity.z).length()
    if is_on_floor() and horizontal_speed > 0.5:
        bob_time += delta * head_bob_speed * clamp(horizontal_speed / speed, 0.6, 2.0)
        var bob_offset = sin(bob_time) * head_bob_amount
        weapon_mesh.position = weapon_mesh.position.lerp(weapon_rest_position + Vector3(0, bob_offset, 0), 10.0 * delta)
        weapon_mesh.rotation.z = lerp(weapon_mesh.rotation.z, sin(bob_time * 2.0) * head_bob_amount * 2.5, 8.0 * delta)
        if step_audio and not step_audio.playing and fmod(bob_time, PI) < 0.1:
            step_audio.play()
    else:
        bob_time = 0.0
        weapon_mesh.position = weapon_mesh.position.lerp(weapon_rest_position, 10.0 * delta)
        weapon_mesh.rotation.z = lerp(weapon_mesh.rotation.z, 0.0, 10.0 * delta)

    if damage_shake_time > 0.0:
        damage_shake_time = max(0.0, damage_shake_time - delta)
        var shake_strength = camera_shake * (damage_shake_time / 0.25)
        camera.position = Vector3(
            randf_range(-shake_strength, shake_strength),
            randf_range(-shake_strength, shake_strength),
            0
        )
    else:
        camera.position = camera.position.lerp(Vector3.ZERO, 12.0 * delta)

func apply_recoil():
    head.rotation.x = clamp(head.rotation.x - 0.01, deg_to_rad(-80), deg_to_rad(80))
