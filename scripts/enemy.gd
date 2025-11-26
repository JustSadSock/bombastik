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
    _apply_variant_style()
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

    if attack_type == "ranged":
        var desired_dir = dir
        var speed_scale := 1.0
        if distance < preferred_ranged_distance - 1.0:
            desired_dir = -dir
            speed_scale = 0.9
        elif distance > preferred_ranged_distance + 1.5:
            desired_dir = dir
            speed_scale = 1.0
        else:
            desired_dir = (dir + strafe_jitter).normalized()
            speed_scale = 0.85
        velocity.x = desired_dir.x * strafe_speed * speed_scale
        velocity.z = desired_dir.z * strafe_speed * speed_scale
    else:
        var angled := (dir + strafe_jitter * 0.6).normalized()
        velocity.x = angled.x * speed
        velocity.z = angled.z * speed * 1.05

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
    var spawn_basis := Basis()
    spawn_basis = spawn_basis.looking_at(spawn_dir, Vector3.UP)
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
    tween.parallel().tween_property(visual, "modulate:a", 0.0, death_fade_time).set_ease(Tween.EASE_IN)

func _apply_variant_style():
    var style = VARIANT_STYLES[rng.randi_range(0, VARIANT_STYLES.size() - 1)]
    _tint_mesh(body_mesh, style.get("body", Color.WHITE))
    _tint_mesh(head_mesh, style.get("body", Color.WHITE))
    for mesh in accent_meshes:
        if mesh:
            _tint_mesh(mesh, style.get("accent", _get_mesh_color(mesh)))
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
