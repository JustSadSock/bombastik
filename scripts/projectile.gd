extends Area3D

@export var velocity: Vector3 = Vector3.ZERO
@export var damage: float = 10.0
@export var explosive: bool = false
@export var lifespan: float = 4.0
var explosion_scene: PackedScene
var creator: Node

func _ready():
    body_entered.connect(_on_body_entered)
    monitoring = true

func _process(delta):
    global_translate(velocity * delta)
    lifespan -= delta
    if lifespan <= 0:
        explode()

func _on_body_entered(body):
    if body == creator:
        return
    if body.has_method("take_damage"):
        body.take_damage(damage)
    explode()

func explode():
    if explosive and explosion_scene:
        var explosion = explosion_scene.instantiate()
        explosion.global_transform.origin = global_transform.origin
        get_tree().current_scene.add_child(explosion)
    queue_free()
