extends CharacterBody3D

signal died

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

const DEFAULT_PROJECTILE_SCENE := preload("res://scenes/Projectile.tscn")
const DEFAULT_EXPLOSION_SCENE := preload("res://scenes/Explosion.tscn")

@export var speed := 10.0
@export var sprint_multiplier := 1.6
@export var crouch_multiplier := 0.6
@export var jump_velocity := 6.2
@export var acceleration := 18.0
@export var air_acceleration := 10.0
@export var friction := 12.0
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
var weapon_base_scale := Vector3.ONE
var weapon_fire_tween: Tween
var is_dead := false
var wants_recap_mouse := true
var force_move_input := Vector2.ZERO
var slide_time := 0.0
var slide_direction := Vector3.ZERO
var coyote_timer := 0.0
var jump_buffer_time := 0.0
var jumps_used := 0
var was_on_floor := false
var was_sliding := false

var lean_tween: Tween

var sound_assets_generated := false

const MAX_JUMPS := 2

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var muzzle: Marker3D = $Head/Muzzle
@onready var weapon_mesh: Node3D = $Head/WeaponMesh
@onready var fire_audio: AudioStreamPlayer3D = $Head/FireAudio
@onready var hurt_audio: AudioStreamPlayer3D = $Head/HurtAudio
@onready var step_audio: AudioStreamPlayer3D = $Head/StepAudio
@onready var jump_audio: AudioStreamPlayer3D = $Head/JumpAudio
@onready var land_audio: AudioStreamPlayer3D = $Head/LandAudio
@onready var slide_audio: AudioStreamPlayer3D = $Head/SlideAudio
@onready var swap_audio: AudioStreamPlayer3D = $Head/SwapAudio
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready():
    rng.randomize()
    health = max_health
    projectile_scene = projectile_scene if projectile_scene else DEFAULT_PROJECTILE_SCENE
    explosion_scene = explosion_scene if explosion_scene else DEFAULT_EXPLOSION_SCENE
    floor_snap_length = max(floor_snap_length, step_height)
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    weapon_base_scale = weapon_mesh.scale
    weapon_rest_position = weapon_mesh.position
    _ensure_sounds()
    _apply_weapon_model()
    update_hud()
    was_on_floor = is_on_floor()

func set_weapons(list: Array):
    weapons = list.duplicate()
    current_weapon_index = 0
    _apply_weapon_model()
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
    if event.is_action_pressed("jump"):
        jump_buffer_time = 0.18
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
    var was_grounded = is_on_floor()
    var sliding_before = slide_time > 0.0
    if not is_on_floor():
        velocity.y -= gravity * delta
        coyote_timer = max(0.0, coyote_timer - delta)
    else:
        coyote_timer = coyote_time
        jumps_used = 0
    if Input.is_action_just_pressed("jump"):
        jump_buffer_time = 0.18
    jump_buffer_time = max(0.0, jump_buffer_time - delta)

    if jump_buffer_time > 0.0 and (is_on_floor() or coyote_timer > 0.0 or jumps_used < MAX_JUMPS - 1):
        velocity.y = jump_velocity
        coyote_timer = 0.0
        jumps_used += 1
        jump_buffer_time = 0.0
        _play_sound(jump_audio, 520.0 + 60.0 * jumps_used, 0.16, 0.55)
        _animate_air_push()
    var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    if input_dir == Vector2.ZERO and force_move_input != Vector2.ZERO:
        input_dir = force_move_input.normalized()
    var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    var is_crouching = Input.is_action_pressed("crouch")
    if Input.is_action_just_pressed("crouch") and is_on_floor() and direction.length() > 0.1 and slide_time <= 0.0:
        start_slide(direction)
    var target_speed = speed * (sprint_multiplier if Input.is_action_pressed("sprint") and not is_crouching else 1.0)
    var acceleration_value := acceleration if is_on_floor() else air_acceleration
    if slide_time > 0.0:
        var slide_ratio = slide_time / slide_duration
        velocity.x = slide_direction.x * slide_speed * slide_ratio
        velocity.z = slide_direction.z * slide_speed * slide_ratio
        slide_time = max(0.0, slide_time - delta)
        is_crouching = true
    else:
        if is_crouching:
            target_speed *= crouch_multiplier
        var target_velocity: Vector3 = direction * target_speed
        velocity.x = move_toward(velocity.x, target_velocity.x, acceleration_value * delta)
        velocity.z = move_toward(velocity.z, target_velocity.z, acceleration_value * delta)
        if direction.length() < 0.1:
            velocity.x = move_toward(velocity.x, 0.0, friction * delta)
            velocity.z = move_toward(velocity.z, 0.0, friction * delta)
    apply_step_assist(direction)
    move_and_slide()
    apply_crouch(delta, is_crouching)
    apply_headbob(delta, direction)
    if not was_grounded and is_on_floor():
        _play_sound(land_audio, 240.0, 0.18, 0.48)
        _animate_land()
    if not sliding_before and slide_time > 0.0:
        _play_sound(slide_audio, 180.0, 0.24, 0.44)
    was_on_floor = is_on_floor()
    was_sliding = slide_time > 0.0

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
    _apply_weapon_model()
    _animate_weapon_swap()
    _play_sound(swap_audio, 360.0, 0.16, 0.4)
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
        var fire_profile: Dictionary = data.get("fire_sound", {})
        _play_sound(
            fire_audio,
            fire_profile.get("freq", 520.0),
            fire_profile.get("duration", 0.12),
            fire_profile.get("amplitude", 0.65)
        )
    apply_recoil()
    animate_weapon_fire(data)
    update_hud()

func spawn_projectile(direction: Vector3, weapon_data: Dictionary):
    if projectile_scene == null:
        return
    var projectile = projectile_scene.instantiate()
    var spawn_origin := muzzle.global_transform.origin
    var projectile_basis := Basis.looking_at(direction.normalized(), Vector3.UP)
    projectile.global_transform = Transform3D(projectile_basis, spawn_origin)
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
            _apply_weapon_model()
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
        _play_sound(hurt_audio, 200.0, 0.2, 0.55)
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
            _play_sound(step_audio, 140.0, 0.08, 0.4)
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

func _animate_weapon_swap():
    if not weapon_mesh:
        return
    if lean_tween:
        lean_tween.kill()
    lean_tween = create_tween()
    lean_tween.tween_property(weapon_mesh, "rotation_degrees:y", 20.0, 0.08).set_trans(Tween.TRANS_SINE)
    lean_tween.parallel().tween_property(weapon_mesh, "position:x", weapon_rest_position.x + 0.06, 0.08)
    lean_tween.tween_property(weapon_mesh, "rotation_degrees:y", 0.0, 0.12).set_trans(Tween.TRANS_SINE)
    lean_tween.parallel().tween_property(weapon_mesh, "position:x", weapon_rest_position.x, 0.12)

func _animate_air_push():
    if not weapon_mesh:
        return
    if lean_tween:
        lean_tween.kill()
    lean_tween = create_tween()
    lean_tween.tween_property(weapon_mesh, "rotation_degrees:x", -12.0, 0.12).set_trans(Tween.TRANS_SINE)
    lean_tween.tween_property(weapon_mesh, "rotation_degrees:x", 0.0, 0.16).set_trans(Tween.TRANS_SINE)

func _animate_land():
    if not weapon_mesh:
        return
    if lean_tween:
        lean_tween.kill()
    lean_tween = create_tween()
    lean_tween.tween_property(weapon_mesh, "rotation_degrees:x", 6.0, 0.08).set_trans(Tween.TRANS_SINE)
    lean_tween.parallel().tween_property(camera, "position:y", -0.05, 0.08)
    lean_tween.tween_property(weapon_mesh, "rotation_degrees:x", 0.0, 0.1)
    lean_tween.parallel().tween_property(camera, "position", Vector3.ZERO, 0.1)

func _apply_weapon_model():
    if not weapon_mesh:
        return
    for child in weapon_mesh.get_children():
        child.queue_free()
    if weapons.is_empty():
        return
    var data: Dictionary = weapons[current_weapon_index]
    var model_data: Dictionary = data.get("weapon_model", {})
    var mesh := _build_mesh(model_data)
    if mesh:
        var instance := MeshInstance3D.new()
        instance.mesh = mesh
        var mat := StandardMaterial3D.new()
        var tint: Color = data.get("pickup_color", Color(0.9, 0.9, 0.9))
        mat.albedo_color = tint
        mat.emission_enabled = true
        mat.emission = tint * 0.4
        mat.roughness = 0.35
        instance.material_override = mat
        weapon_mesh.add_child(instance)
    var offset: Vector3 = model_data.get("offset", Vector3.ZERO)
    weapon_mesh.rotation = Vector3.ZERO
    weapon_mesh.position = Vector3(0.24, -0.25, -0.7) + offset
    var scale_mult: float = model_data.get("scale", 0.6)
    weapon_mesh.scale = weapon_base_scale * scale_mult
    weapon_rest_position = weapon_mesh.position

func _build_mesh(data: Dictionary) -> Mesh:
    if data.has("type") and data.get("type") == "composite":
        return _compose_mesh(data.get("parts", []))
    return _build_primitive_mesh(data)

func _build_primitive_mesh(data: Dictionary) -> Mesh:
    match data.get("type"):
        "box":
            var box := BoxMesh.new()
            box.size = data.get("size", Vector3(0.38, 0.24, 0.52))
            return box
        "prism":
            var prism := PrismMesh.new()
            prism.size = data.get("size", Vector3(0.9, 0.3, 0.3))
            return prism
        "cylinder":
            var cylinder := CylinderMesh.new()
            cylinder.height = data.get("height", 0.8)
            cylinder.top_radius = data.get("top_radius", 0.2)
            cylinder.bottom_radius = data.get("bottom_radius", 0.24)
            cylinder.radial_segments = data.get("segments", 18)
            return cylinder
        "capsule":
            var capsule := CapsuleMesh.new()
            capsule.radius = data.get("radius", 0.2)
            capsule.height = data.get("height", 0.8)
            capsule.radial_segments = data.get("segments", 12)
            return capsule
        "cone":
            var cone := CylinderMesh.new()
            cone.height = data.get("height", 0.82)
            cone.top_radius = data.get("top_radius", 0.08)
            cone.bottom_radius = data.get("bottom_radius", 0.3)
            cone.radial_segments = data.get("segments", 18)
            return cone
        "torus":
            var torus := TorusMesh.new()
            torus.inner_radius = data.get("inner_radius", 0.12)
            torus.outer_radius = data.get("outer_radius", 0.32)
            torus.ring_segments = data.get("ring_segments", 18)
            torus.rings = data.get("rings", 12)
            return torus
        _:
            return null

func _compose_mesh(parts: Array) -> Mesh:
    if parts.is_empty():
        return null
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for part in parts:
        var piece := _build_primitive_mesh(part)
        if piece:
            var part_transform := _part_transform(part)
            for surface in range(piece.get_surface_count()):
                tool.append_from(piece, surface, part_transform)
    return tool.commit()

func _part_transform(part: Dictionary) -> Transform3D:
    var origin: Vector3 = part.get("origin", Vector3.ZERO)
    var rotation_deg: Vector3 = part.get("rotation_degrees", Vector3.ZERO)
    var scale_vec: Vector3 = part.get("scale", Vector3.ONE)
    var part_basis := Basis.from_euler(rotation_deg * (PI / 180.0))
    part_basis = part_basis.scaled(scale_vec)
    return Transform3D(part_basis, origin)

func start_slide(direction: Vector3):
    slide_direction = direction.normalized()
    if slide_direction == Vector3.ZERO:
        slide_direction = -head.global_transform.basis.z.normalized()
    slide_time = slide_duration

func apply_settings(settings: Dictionary):
    if settings.has("sensitivity"):
        camera_sensitivity = settings.get("sensitivity")
    if settings.has("master_volume"):
        var vol: float = settings.get("master_volume")
        AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(clamp(vol, 0.0, 1.0)))
    _ensure_sounds()

func _ensure_sounds():
    if sound_assets_generated:
        return
    if fire_audio:
        fire_audio.stream = _build_tone(520.0, 0.12, 0.65)
    if hurt_audio:
        hurt_audio.stream = _build_tone(200.0, 0.2, 0.55)
    if step_audio:
        step_audio.stream = _build_tone(140.0, 0.08, 0.4)
    if jump_audio:
        jump_audio.stream = _build_tone(440.0, 0.18, 0.48)
    if land_audio:
        land_audio.stream = _build_tone(260.0, 0.2, 0.5)
    if slide_audio:
        slide_audio.stream = _build_tone(190.0, 0.22, 0.42)
    if swap_audio:
        swap_audio.stream = _build_tone(360.0, 0.16, 0.4)
    sound_assets_generated = true

func _play_sound(player: AudioStreamPlayer3D, freq: float, duration: float, amplitude: float):
    if not player:
        return
    if not player.stream:
        player.stream = _build_tone(freq, duration, amplitude)
    if not player.playing:
        player.play()
    var playback = player.get_stream_playback()
    if playback is AudioStreamGeneratorPlayback:
        _fill_generator(playback, freq, duration, amplitude)
    else:
        player.stop()
        player.play()

func _build_tone(freq: float, duration: float, amplitude: float) -> AudioStream:
    var sample := AudioStreamWAV.new()
    sample.mix_rate = 44100
    sample.format = AudioStreamWAV.FORMAT_16_BITS
    sample.stereo = false
    sample.loop_mode = AudioStreamWAV.LOOP_DISABLED
    var length := int(duration * sample.mix_rate)
    var data := PackedByteArray()
    data.resize(length * 2)
    for i in length:
        var t = float(i) / sample.mix_rate
        var value = sin(TAU * freq * t) * amplitude
        data.encode_s16(i * 2, int(clamp(value, -1.0, 1.0) * 32767))
    sample.data = data
    return sample

func _fill_generator(playback: AudioStreamGeneratorPlayback, freq: float, duration: float, amplitude: float):
    var sample_rate = playback.get_stream().mix_rate
    var frame_count = int(duration * sample_rate)
    for i in frame_count:
        var t = float(i) / sample_rate
        var sample = sin(TAU * freq * t) * amplitude
        playback.push_frame(Vector2(sample, sample))
