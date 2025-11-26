extends Area3D

@export var weapon_id: String = "pistol"
@export var display_name: String = "Pistol"

const WeaponData = preload("res://scripts/weapon_data.gd")

func _ready():
    monitoring = true
    body_entered.connect(_on_body_entered)
    _apply_visuals()

func _process(delta):
    rotate_y(delta)

func _on_body_entered(body):
    if body.has_method("pickup_weapon"):
        body.pickup_weapon(weapon_id)
        queue_free()

func _apply_visuals():
    var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")
    if mesh_instance:
        mesh_instance.mesh = _build_mesh(weapon_id)
        var mat := StandardMaterial3D.new()
        var color: Color = _get_weapon_data().get("pickup_color", Color(1.0, 0.9, 0.4))
        mat.albedo_color = color
        mat.emission_enabled = true
        mat.emission = color * 0.6
        mat.roughness = 0.3
        mesh_instance.material_override = mat
        mesh_instance.scale = Vector3.ONE * 0.8
    var label: Label3D = get_node_or_null("Label3D")
    if display_name.is_empty():
        display_name = _get_weapon_data().get("name", weapon_id.capitalize())
    if label:
        label.text = display_name

func _build_mesh(id: String) -> Mesh:
    match id:
        "rifle":
            var prism := PrismMesh.new()
            prism.size = Vector3(0.9, 0.25, 0.35)
            return prism
        "shotgun":
            var box := BoxMesh.new()
            box.size = Vector3(0.65, 0.3, 0.55)
            return box
        "rocket":
            var cylinder := CylinderMesh.new()
            cylinder.height = 0.9
            cylinder.top_radius = 0.14
            cylinder.bottom_radius = 0.2
            return cylinder
        "laser":
            var capsule := CapsuleMesh.new()
            capsule.radius = 0.16
            capsule.height = 0.75
            return capsule
        _:
            var default_box := BoxMesh.new()
            default_box.size = Vector3(0.38, 0.26, 0.52)
            return default_box

func _get_weapon_data() -> Dictionary:
    for data in WeaponData.WEAPONS:
        if data.get("id") == weapon_id:
            return data
    return {}
