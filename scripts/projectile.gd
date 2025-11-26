extends Area3D

@export var velocity: Vector3 = Vector3.ZERO
@export var damage: float = 10.0
@export var explosive: bool = false
@export var lifespan: float = 4.0
@export var tint: Color = Color(1.0, 0.9, 0.7)
var explosion_scene: PackedScene
var creator: Node

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var trail: CPUParticles3D = $Trail

func _ready():
    body_entered.connect(_on_body_entered)
    _apply_tint()
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

func _apply_tint():
    if mesh_instance:
        mesh_instance.modulate = tint
        if mesh_instance.material_override:
            var mat := mesh_instance.material_override.duplicate()
            if mat is BaseMaterial3D:
                mat.albedo_color = tint
                mat.emission_enabled = true
                mat.emission = tint * 0.55
            mesh_instance.material_override = mat
    if trail:
        trail.modulate = tint
