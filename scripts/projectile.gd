extends Area3D

@export var velocity: Vector3 = Vector3.ZERO
@export var damage: float = 10.0
@export var explosive: bool = false
@export var lifespan: float = 4.0
@export var tint: Color = Color(1.0, 0.9, 0.7)
@export var shape_data: Dictionary = {}
var explosion_scene: PackedScene
var creator: Node

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var trail: CPUParticles3D = $Trail

func _ready():
    body_entered.connect(_on_body_entered)
    _apply_shape()
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
        var mat: BaseMaterial3D
        if mesh_instance.material_override and mesh_instance.material_override is BaseMaterial3D:
            mat = mesh_instance.material_override.duplicate()
        else:
            mat = StandardMaterial3D.new()
        mat.albedo_color = tint
        mat.emission_enabled = true
        mat.emission = tint * 0.55
        mesh_instance.material_override = mat
    if trail:
        var particle_material: ParticleProcessMaterial
        if trail.process_material and trail.process_material is ParticleProcessMaterial:
            particle_material = trail.process_material.duplicate()
        else:
            particle_material = ParticleProcessMaterial.new()
        particle_material.color = tint
        trail.process_material = particle_material

func _apply_shape():
    if not mesh_instance:
        return
    var mesh := _build_mesh(shape_data)
    if mesh:
        mesh_instance.mesh = mesh

func _build_mesh(data: Dictionary) -> Mesh:
    if not data.has("type"):
        return null
    if data.get("type") == "composite":
        return _compose_mesh(data.get("parts", []))
    return _build_primitive_mesh(data)

func _build_primitive_mesh(data: Dictionary) -> Mesh:
    match data.get("type"):
        "box":
            var box := BoxMesh.new()
            box.size = data.get("size", Vector3.ONE * 0.25)
            return box
        "capsule":
            var capsule := CapsuleMesh.new()
            capsule.radius = data.get("radius", 0.12)
            capsule.height = data.get("height", 0.6)
            capsule.radial_segments = data.get("segments", 12)
            return capsule
        "cylinder":
            var cylinder := CylinderMesh.new()
            cylinder.height = data.get("height", 0.6)
            cylinder.top_radius = data.get("top_radius", 0.12)
            cylinder.bottom_radius = data.get("bottom_radius", 0.12)
            cylinder.radial_segments = data.get("segments", 12)
            return cylinder
        "sphere":
            var sphere := SphereMesh.new()
            sphere.radius = data.get("radius", 0.18)
            sphere.radial_segments = data.get("segments", 10)
            sphere.rings = data.get("rings", 8)
            return sphere
        "cone":
            var cone := CylinderMesh.new()
            cone.height = data.get("height", 0.72)
            cone.top_radius = data.get("top_radius", 0.02)
            cone.bottom_radius = data.get("bottom_radius", 0.2)
            cone.radial_segments = data.get("segments", 16)
            return cone
        "torus":
            var torus := TorusMesh.new()
            torus.inner_radius = data.get("inner_radius", 0.08)
            torus.outer_radius = data.get("outer_radius", 0.18)
            torus.ring_segments = data.get("ring_segments", 16)
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
        var mesh := _build_primitive_mesh(part)
        if mesh:
            var part_transform := _part_transform(part)
            for surface in range(mesh.get_surface_count()):
                tool.append_from(mesh, surface, part_transform)
    return tool.commit()

func _part_transform(part: Dictionary) -> Transform3D:
    var origin: Vector3 = part.get("origin", Vector3.ZERO)
    var rotation_deg: Vector3 = part.get("rotation_degrees", Vector3.ZERO)
    var scale: Vector3 = part.get("scale", Vector3.ONE)
    var part_basis := Basis.from_euler(rotation_deg * (PI / 180.0))
    part_basis = part_basis.scaled(scale)
    return Transform3D(part_basis, origin)
