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
    var weapon_data := _get_weapon_data()
    var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")
    if mesh_instance:
        mesh_instance.mesh = _build_mesh(weapon_data.get("pickup_mesh", {}), weapon_id)
        var mat := StandardMaterial3D.new()
        var color: Color = weapon_data.get("pickup_color", Color(1.0, 0.9, 0.4))
        mat.albedo_color = color
        mat.emission_enabled = true
        mat.emission = color * 0.6
        mat.roughness = 0.3
        mesh_instance.material_override = mat
        mesh_instance.scale = Vector3.ONE * 0.8
    var label: Label3D = get_node_or_null("Label3D")
    if display_name.is_empty():
        display_name = weapon_data.get("name", weapon_id.capitalize())
    if label:
        label.text = display_name

func _build_mesh(data: Dictionary, id: String) -> Mesh:
    if data.has("type"):
        if data.get("type") == "composite":
            return _compose_mesh(data.get("parts", []))
        return _build_primitive_mesh(data)
    match id:
        "rifle":
            var fallback_prism := PrismMesh.new()
            fallback_prism.size = Vector3(0.9, 0.25, 0.35)
            return fallback_prism
        "shotgun":
            var fallback_box := BoxMesh.new()
            fallback_box.size = Vector3(0.65, 0.3, 0.55)
            return fallback_box
        "rocket":
            var fallback_cylinder := CylinderMesh.new()
            fallback_cylinder.height = 0.9
            fallback_cylinder.top_radius = 0.14
            fallback_cylinder.bottom_radius = 0.2
            return fallback_cylinder
        "laser":
            var fallback_capsule := CapsuleMesh.new()
            fallback_capsule.radius = 0.16
            fallback_capsule.height = 0.75
            return fallback_capsule
        _:
            var default_box := BoxMesh.new()
            default_box.size = Vector3(0.38, 0.26, 0.52)
            return default_box

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
            var transform := _part_transform(part)
            for surface in range(piece.get_surface_count()):
                tool.append_from(piece, surface, transform)
    return tool.commit()

func _part_transform(part: Dictionary) -> Transform3D:
    var origin: Vector3 = part.get("origin", Vector3.ZERO)
    var rotation_deg: Vector3 = part.get("rotation_degrees", Vector3.ZERO)
    var scale: Vector3 = part.get("scale", Vector3.ONE)
    var basis := Basis.from_euler(rotation_deg * (PI / 180.0))
    basis = basis.scaled(scale)
    return Transform3D(basis, origin)

func _get_weapon_data() -> Dictionary:
    for data in WeaponData.WEAPONS:
        if data.get("id") == weapon_id:
            return data
    return {}
