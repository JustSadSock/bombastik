extends Area3D

@export var weapon_id: String = "pistol"
@export var display_name: String = "Pistol"

func _ready():
    monitoring = true
    body_entered.connect(_on_body_entered)

func _process(delta):
    rotate_y(delta)

func _on_body_entered(body):
    if body.has_method("pickup_weapon"):
        body.pickup_weapon(weapon_id)
        queue_free()
