extends CharacterBody3D

@export var speed := 6.0
@export var health := 60.0
@export var damage := 10.0
@export var explosion_scene: PackedScene

var target: Node3D

func _ready():
    add_to_group("enemies")

func _physics_process(delta):
    if not target:
        return
    var to_target = (target.global_transform.origin - global_transform.origin)
    var dir = to_target.normalized()
    velocity = dir * speed
    move_and_slide()
    look_at(target.global_transform.origin, Vector3.UP)
    if to_target.length() < 1.8 and target.has_method("take_damage"):
        target.take_damage(damage * delta)

func take_damage(amount: float):
    health -= amount
    if health <= 0:
        die()

func die():
    if explosion_scene:
        var explosion = explosion_scene.instantiate()
        explosion.global_transform.origin = global_transform.origin
        get_tree().current_scene.add_child(explosion)
    queue_free()
