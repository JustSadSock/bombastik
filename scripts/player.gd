extends CharacterBody3D

signal died

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

const DEFAULT_PROJECTILE_SCENE := preload("res://scenes/Projectile.tscn")
const DEFAULT_EXPLOSION_SCENE := preload("res://scenes/Explosion.tscn")

@export var speed := 10.0
@export var sprint_multiplier := 1.6
@export var crouch_multiplier := 0.6
@export var jump_velocity := 4.5
@export var slide_speed := 16.0
@export var slide_duration := 0.55
@export var step_height := 0.8
@export var step_check_distance := 0.65
@export var coyote_time := 0.18
@export var camera_sensitivity := 0.002
@export var head_bob_speed := 6.0
@export var head_bob_amount := 0.02
@export var camera_shake := 0.035
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
var weapon_fire_tween: Tween
var is_dead := false
var wants_recap_mouse := true
var force_move_input := Vector2.ZERO
var slide_time := 0.0
var slide_direction := Vector3.ZERO
var coyote_timer := 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var muzzle: Marker3D = $Head/Muzzle
@onready var weapon_mesh: Node3D = $Head/WeaponMesh
@onready var fire_audio: AudioStreamPlayer3D = $Head/FireAudio
@onready var hurt_audio: AudioStreamPlayer3D = $Head/HurtAudio
@onready var step_audio: AudioStreamPlayer3D = $Head/StepAudio
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready():
    rng.randomize()
    health = max_health
    projectile_scene = projectile_scene if projectile_scene else DEFAULT_PROJECTILE_SCENE
    explosion_scene = explosion_scene if explosion_scene else DEFAULT_EXPLOSION_SCENE
    floor_snap_length = max(floor_snap_length, step_height)
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    weapon_rest_position = weapon_mesh.position
    update_hud()

func set_weapons(list: Array):
    weapons = list.duplicate()
    current_weapon_index = 0
    update_hud()

func _input(event):
    if is_dead:
        return
    if event is InputEventMouseMotion:
        rotate_y(-event.relative.x * camera_sensitivity)
        head.rotate_x(-event.relative.y * camera_sensitivity)
        head.rotation_degrees.x = clamp(head.rotation_degrees.x, -80, 80)
    if event is InputEventMouseButton and event.pressed:
        recapture_mouse()
        if event.button_index == MOUSE_BUTTON_LEFT:
            shoot()
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    if event.is_pressed() and (event.is_action("fire") or event.is_action("jump") or event.is_action("move_forward")
            or event.is_action("move_backward") or event.is_action("move_left") or event.is_action("move_right")):
        recapture_mouse()

func _unhandled_input(event):
    if is_dead:
        return
    if event is InputEventKey:
        _sync_fallback_move(event)
    if event.is_action_pressed("fire"):
        recapture_mouse()
        shoot()
    if event.is_action_pressed("jump") and (is_on_floor() or coyote_timer > 0.0):
        velocity.y = jump_velocity
        coyote_timer = 0.0
        recapture_mouse()

func _notification(what):
    if is_dead:
        return
    if what == NOTIFICATION_WM_MOUSE_ENTER or what == NOTIFICATION_APPLICATION_FOCUS_IN:
        if wants_recap_mouse:
            recapture_mouse()

func _physics_process(delta):
    if is_dead:
        return
    if not is_on_floor():
        velocity.y -= gravity * delta
        coyote_timer = max(0.0, coyote_timer - delta)
    else:
        coyote_timer = coyote_time
    if Input.is_action_just_pressed("jump") and (is_on_floor() or coyote_timer > 0.0):
        velocity.y = jump_velocity
        coyote_timer = 0.0
    var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    if input_dir == Vector2.ZERO and force_move_input != Vector2.ZERO:
        input_dir = force_move_input.normalized()
    var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    var is_crouching = Input.is_action_pressed("crouch")
    if Input.is_action_just_pressed("crouch") and is_on_floor() and direction.length() > 0.1 and slide_time <= 0.0:
        start_slide(direction)
    var target_speed = speed * (sprint_multiplier if Input.is_action_pressed("sprint") and not is_crouching else 1.0)
    if slide_time > 0.0:
        var slide_ratio = slide_time / slide_duration
        velocity.x = slide_direction.x * slide_speed * slide_ratio
        velocity.z = slide_direction.z * slide_speed * slide_ratio
        slide_time = max(0.0, slide_time - delta)
        is_crouching = true
    else:
        if is_crouching:
            target_speed *= crouch_multiplier
        velocity.x = direction.x * target_speed
        velocity.z = direction.z * target_speed
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = jump_velocity
        coyote_timer = 0.0
    elif Input.is_action_just_pressed("jump") and coyote_timer > 0.0:
        velocity.y = jump_velocity
        coyote_timer = 0.0
    apply_step_assist(direction)
    move_and_slide()
    apply_crouch(delta, is_crouching)
    apply_headbob(delta, direction)

func _process(delta):
    if is_dead:
        return
    if cooldown > 0.0:
        cooldown = max(0.0, cooldown - delta)
    if Input.is_action_just_pressed("switch_next"):
        switch_weapon(1)
    elif Input.is_action_just_pressed("switch_prev"):
        switch_weapon(-1)
    if Input.is_action_pressed("fire"):
        shoot()

func recapture_mouse():
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    wants_recap_mouse = Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED

func _sync_fallback_move(event: InputEventKey):
    var dir_map := {
        KEY_W: Vector2(0, -1),
        KEY_S: Vector2(0, 1),
        KEY_A: Vector2(-1, 0),
        KEY_D: Vector2(1, 0),
        KEY_UP: Vector2(0, -1),
        KEY_DOWN: Vector2(0, 1),
        KEY_LEFT: Vector2(-1, 0),
        KEY_RIGHT: Vector2(1, 0),
    }
    if not dir_map.has(event.keycode):
        return
    var delta: Vector2 = dir_map[event.keycode]
    if event.pressed:
        force_move_input += delta
        recapture_mouse()
    else:
        force_move_input -= delta
    force_move_input.x = clamp(force_move_input.x, -1.0, 1.0)
    force_move_input.y = clamp(force_move_input.y, -1.0, 1.0)

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
    animate_weapon_fire(data)
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
    projectile.set("tint", weapon_data.get("projectile_color", Color(1.0, 0.9, 0.7)))
    projectile.set("shape_data", weapon_data.get("projectile_mesh", {}))
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
    if is_dead:
        return
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
    if is_dead:
        return
    is_dead = true
    force_move_input = Vector2.ZERO
    emit_signal("died")
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    queue_free()

func apply_crouch(delta: float, is_crouching: bool):
    var target_height = 1.0 if is_crouching else 1.5
    head.position.y = lerp(head.position.y, target_height, 10.0 * delta)
    var shape: CapsuleShape3D = collision_shape.shape
    if shape:
        shape.height = lerp(shape.height, 1.2 if is_crouching else 1.8, 8.0 * delta)

func apply_step_assist(direction: Vector3):
    if not is_on_floor():
        return
    if direction.length() < 0.1:
        return
    var motion = direction.normalized() * step_check_distance
    var low_origin := global_transform.translated(Vector3(0, 0.05, 0))
    if test_move(low_origin, motion):
        var raised := global_transform.translated(Vector3(0, step_height, 0))
        if not test_move(raised, motion):
            global_transform = raised
            velocity.y = 0.0

func apply_headbob(delta: float, _direction: Vector3):
    var horizontal_speed = Vector2(velocity.x, velocity.z).length()
    if is_on_floor() and horizontal_speed > 0.5:
        bob_time += delta * head_bob_speed * clamp(horizontal_speed / speed, 0.6, 2.0)
        var bob_offset = sin(bob_time) * head_bob_amount
        weapon_mesh.position = weapon_mesh.position.lerp(weapon_rest_position + Vector3(0, bob_offset, 0), 8.0 * delta)
        weapon_mesh.rotation.z = lerp(weapon_mesh.rotation.z, sin(bob_time * 2.0) * head_bob_amount * 1.8, 8.0 * delta)
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
    head.rotation.x = clamp(head.rotation.x - 0.006, deg_to_rad(-80), deg_to_rad(80))

func animate_weapon_fire(data: Dictionary):
    if not weapon_mesh:
        return
    if weapon_fire_tween:
        weapon_fire_tween.kill()
    weapon_fire_tween = create_tween()
    var style: String = data.get("fire_style", "pistol")
    match style:
        "burst":
            weapon_fire_tween.tween_property(weapon_mesh, "position:z", weapon_rest_position.z - 0.06, 0.06).set_trans(Tween.TRANS_BACK)
            weapon_fire_tween.parallel().tween_property(weapon_mesh, "rotation_degrees:y", -8.0, 0.05)
        "kick":
            weapon_fire_tween.tween_property(weapon_mesh, "position", weapon_rest_position + Vector3(0.02, -0.06, -0.1), 0.08).set_trans(Tween.TRANS_BACK)
            weapon_fire_tween.parallel().tween_property(weapon_mesh, "rotation_degrees:x", -10.0, 0.08)
        "heavy":
            weapon_fire_tween.tween_property(weapon_mesh, "position", weapon_rest_position + Vector3(-0.02, -0.04, -0.12), 0.12).set_trans(Tween.TRANS_SINE)
            weapon_fire_tween.parallel().tween_property(weapon_mesh, "rotation_degrees:z", 6.0, 0.12)
        "beam":
            weapon_fire_tween.tween_property(weapon_mesh, "position", weapon_rest_position + Vector3(0.0, 0.02, -0.04), 0.05).set_trans(Tween.TRANS_SINE)
            weapon_fire_tween.parallel().tween_property(weapon_mesh, "rotation_degrees:z", 4.0, 0.06)
        _:
            weapon_fire_tween.tween_property(weapon_mesh, "position:z", weapon_rest_position.z - 0.04, 0.05).set_trans(Tween.TRANS_BACK)
            weapon_fire_tween.parallel().tween_property(weapon_mesh, "rotation_degrees:x", -6.0, 0.06)
    weapon_fire_tween.tween_property(weapon_mesh, "position", weapon_rest_position, 0.12).set_trans(Tween.TRANS_SINE)
    weapon_fire_tween.parallel().tween_property(weapon_mesh, "rotation_degrees", Vector3.ZERO, 0.12).set_trans(Tween.TRANS_SINE)

func start_slide(direction: Vector3):
    slide_direction = direction.normalized()
    if slide_direction == Vector3.ZERO:
        slide_direction = -head.global_transform.basis.z.normalized()
    slide_time = slide_duration
