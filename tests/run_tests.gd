extends SceneTree

var _failures: Array = []

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var game := await _build_game_with_level()
    _test_layout_readability(game)
    await _test_conveyors(game)
    await _test_presses(game)
    await _test_robotic_arms(game)
    _test_furnaces(game)
    _test_fx_pooling(game)

    if _failures.is_empty():
        print("All factory hazard tests passed")
        quit()
        return

    for failure in _failures:
        push_error(failure)
    quit(1)

func _build_game_with_level() -> Node3D:
    var main_scene: PackedScene = load("res://scenes/Main.tscn")
    var game: Node3D = main_scene.instantiate()
    get_root().add_child(game)
    await self.process_frame
    if game.has_method("generate_level"):
        game.generate_level()
    await self.process_frame
    return game

func _test_layout_readability(game: Node3D) -> void:
    var level: Node3D = game.get_node_or_null("Level")
    if level == null:
        _failures.append("Level root missing from generated scene")
        return

    var halls := []
    var corridors := []
    for child in level.get_children():
        if child.name.ends_with("Hall") or child.name.ends_with("Atrium"):
            halls.append(child)
        elif child.name.contains("Link") or child.name.contains("Spine") or child.name.contains("Spur"):
            corridors.append(child)

    if halls.size() < 3:
        _failures.append("Expected multiple halls for large-battle readability, found %d" % halls.size())
    if corridors.size() < 3:
        _failures.append("Expected multiple narrow corridors, found %d" % corridors.size())

    for hall in halls:
        var size: Vector3 = _extract_box_size(hall)
        if min(size.x, size.z) < 20.0:
            _failures.append("Hall %s is too small for large engagements (size: %s)" % [hall.name, size])

    for corridor in corridors:
        var size: Vector3 = _extract_box_size(corridor)
        if min(size.x, size.z) > 15.0:
            _failures.append("Corridor %s is too wide to read as a choke (size: %s)" % [corridor.name, size])

func _extract_box_size(node: Node) -> Vector3:
    for child in node.get_children():
        if child is MeshInstance3D:
            var mesh: Mesh = child.mesh
            if mesh is BoxMesh:
                return (mesh as BoxMesh).size
    return Vector3.ZERO

func _test_conveyors(game: Node3D) -> void:
    var level: Node3D = game.get_node_or_null("Level")
    if level == null:
        _failures.append("Cannot find Level root for conveyor tests")
        return

    var expected := {
        "AssemblyBelt": Vector3(1, 0, 0),
        "SmelterBelt": Vector3(-1, 0, 0),
        "AtriumLoop": Vector3(0, 0, -1),
    }

    for name in expected.keys():
        var belt: Node3D = level.get_node_or_null(name)
        if belt == null:
            _failures.append("Missing conveyor %s" % name)
            continue

        var area := _find_first_child_of_class(belt, "Area3D")
        if area == null:
            _failures.append("Conveyor %s lacks Area3D accelerator" % name)
        else:
            var dir: Vector3 = area.gravity_direction.normalized()
            if dir.distance_to(expected[name].normalized()) > 0.05:
                _failures.append("Conveyor %s gravity direction %s does not match expected %s" % [name, dir, expected[name].normalized()])
            if area.gravity <= 0.0 or area.gravity > 40.0:
                _failures.append("Conveyor %s gravity strength %f is out of safe boost range" % [name, area.gravity])

        var spot := _find_first_child_of_class(belt, "SpotLight3D")
        if spot == null or spot.spot_range <= 0.0:
            _failures.append("Conveyor %s missing telegraphing spotlight" % name)
        var omni := _find_first_child_of_class(belt, "OmniLight3D")
        if omni == null:
            _failures.append("Conveyor %s missing endpoint glow for exits" % name)

func _test_presses(game: Node3D) -> void:
    var level: Node3D = game.get_node_or_null("Level")
    if level == null:
        _failures.append("Cannot find Level root for press tests")
        return

    var presses := ["AtriumPress", "ShippingPress", "CoolingPress"]

    for name in presses:
        var press: Node3D = level.get_node_or_null(name)
        if press == null:
            _failures.append("Missing press %s" % name)
            continue

        var head := press.get_node_or_null("%sHead" % name)
        if head == null:
            _failures.append("Press %s lacks moving head" % name)
            continue

        var kill_area := _find_first_child_of_class(head, "Area3D")
        if kill_area == null:
            _failures.append("Press %s missing lethal Area3D" % name)
        elif kill_area.get_signal_connection_list("body_entered").is_empty():
            _failures.append("Press %s lethal area not wired to apply damage" % name)

        var nav_gate := press.get_node_or_null("%sNavGate" % name)
        if nav_gate == null:
            _failures.append("Press %s missing navigation gate" % name)
        else:
            var seen_enabled := false
            var seen_disabled := false
            for i in range(4):
                await self.create_timer(0.5).timeout
                if nav_gate.enabled:
                    seen_enabled = true
                else:
                    seen_disabled = true
            if not seen_enabled or not seen_disabled:
                _failures.append("Press %s nav gate did not toggle during cycle" % name)

        var spot := _find_first_child_of_class(press, "SpotLight3D")
        if spot == null or spot.light_energy <= 0.0:
            _failures.append("Press %s missing warning spotlight" % name)

func _test_robotic_arms(game: Node3D) -> void:
    var level: Node3D = game.get_node_or_null("Level")
    if level == null:
        _failures.append("Cannot find Level root for robotic arm tests")
        return

    var arms := ["NorthArm", "CentralArm", "SouthArm"]
    for name in arms:
        var arm := level.get_node_or_null(name)
        if arm == null:
            _failures.append("Missing robotic arm %s" % name)
            continue

        var platform := arm.get_node_or_null("%sPlatform" % name)
        if platform == null:
            _failures.append("Robotic arm %s missing platform" % name)
        else:
            var launch_area := _find_first_child_of_class(platform, "Area3D")
            if launch_area == null:
                _failures.append("Robotic arm %s lacks jump Area3D" % name)
            else:
                if launch_area.get_signal_connection_list("body_entered").is_empty():
                    _failures.append("Robotic arm %s jump Area3D not wired to boost entrants" % name)

        var start_pos: Vector3 = platform.position if platform else Vector3.ZERO
        await self.create_timer(0.8).timeout
        var moved: bool = platform and platform.position.distance_to(start_pos) > 0.1
        if not moved:
            _failures.append("Robotic arm %s platform did not move along rail tween" % name)

        var flicker_light := _find_first_child_of_class(platform, "OmniLight3D")
        if flicker_light == null:
            _failures.append("Robotic arm %s lacks readability light" % name)

func _test_furnaces(game: Node3D) -> void:
    var level: Node3D = game.get_node_or_null("Level")
    if level == null:
        _failures.append("Cannot find Level root for furnace tests")
        return

    var furnaces := ["SmelterUpdraft", "AssemblyUpdraft", "CoolingUpdraft"]
    for name in furnaces:
        var furnace := level.get_node_or_null(name)
        if furnace == null:
            _failures.append("Missing furnace %s" % name)
            continue

        var air_area := _find_first_child_of_class(furnace, "Area3D")
        if air_area == null:
            _failures.append("Furnace %s missing lift Area3D" % name)
        else:
            if air_area.gravity_direction != Vector3.UP:
                _failures.append("Furnace %s gravity direction not upward" % name)
            if air_area.gravity <= 0.0 or air_area.gravity > 30.0:
                _failures.append("Furnace %s gravity strength %f out of expected range" % [name, air_area.gravity])

        var furnace_light := _find_first_child_of_class(furnace, "OmniLight3D")
        if furnace_light == null:
            _failures.append("Furnace %s missing warning glow" % name)

func _test_fx_pooling(game: Node3D) -> void:
    var level: Node3D = game.get_node_or_null("Level")
    if level == null:
        _failures.append("Cannot find Level root for FX tests")
        return

    var spark_sets := []
    var smoke_sets := []
    for child in level.get_children():
        if child is CPUParticles3D:
            if child.amount >= 40:
                spark_sets.append(child)
            else:
                smoke_sets.append(child)

    if spark_sets.is_empty():
        _failures.append("Factory sparks not spawned for ambience")
    if smoke_sets.is_empty():
        _failures.append("Factory smoke not spawned for ambience")

    for particle in spark_sets:
        if particle.visibility_range_end > 120.0:
            _failures.append("Spark emitter %s lacks distance culling" % particle.name)
        if particle.amount > 80:
            _failures.append("Spark emitter %s uses excessive particle count %d" % [particle.name, particle.amount])

    for particle in smoke_sets:
        if particle.amount > 40:
            _failures.append("Smoke emitter %s uses excessive particle count %d" % [particle.name, particle.amount])

func _find_first_child_of_class(root: Node, target_class: String) -> Node:
    for child in root.get_children():
        if child.is_class(target_class):
            return child
        var nested := _find_first_child_of_class(child, target_class)
        if nested != null:
            return nested
    return null
