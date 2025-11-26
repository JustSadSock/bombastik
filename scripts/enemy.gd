extends CharacterBody3D

const DEFAULT_EXPLOSION_SCENE := preload("res://scenes/Explosion.tscn")
const DEFAULT_PROJECTILE_SCENE := preload("res://scenes/Projectile.tscn")

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

@onready var visual: Node3D = $Visual
@onready var health_label: Label3D = $HealthLabel
@onready var muzzle: Marker3D = $Visual/Muzzle
@onready var hitbox: CollisionShape3D = $CollisionShape3D

func _ready():
    add_to_group("enemies")
    explosion_scene = explosion_scene if explosion_scene else DEFAULT_EXPLOSION_SCENE
    projectile_scene = projectile_scene if projectile_scene else DEFAULT_PROJECTILE_SCENE
    base_visual_height = visual.position.y
    update_health_label()

func _physics_process(delta):
    if is_dead:
        return
    if not target:
        _idle_sway(delta)
        return

    cooldown_timer = max(0.0, cooldown_timer - delta)
    stagger_timer = max(0.0, stagger_timer - delta)

    var to_target = (target.global_transform.origin - global_transform.origin)
    var dir = to_target.normalized()
    var distance = to_target.length()
    look_at(target.global_transform.origin, Vector3.UP)

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
            desired_dir = (dir + Vector3(-dir.z, 0, dir.x) * 0.5).normalized()
            speed_scale = 0.7
        velocity = desired_dir * strafe_speed * speed_scale
    else:
        velocity = dir * speed

func _idle_sway(delta: float):
    var sway := sin(Time.get_ticks_msec() / 1000.0 * idle_sway_speed) * idle_sway_amount
    visual.position.y = lerp(visual.position.y, base_visual_height + sway + eye_height, 6.0 * delta)

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
    tween.tween_property(visual, "rotation_degrees:x", -12.0, attack_windup * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(visual, "rotation_degrees:x", 0.0, attack_windup * 0.2).set_trans(Tween.TRANS_LINEAR)

func _animate_attack_release():
    if not visual:
        return
    var tween := create_tween()
    tween.tween_property(visual, "rotation_degrees:x", 10.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(visual, "rotation_degrees:x", 0.0, 0.25).set_trans(Tween.TRANS_LINEAR)

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
    projectile.global_transform.origin = muzzle.global_transform.origin if muzzle else global_transform.origin + Vector3(0, eye_height, 0)
    projectile.look_at(projectile.global_transform.origin + spawn_dir, Vector3.UP)
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
