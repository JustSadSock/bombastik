extends Node3D

@export var lifetime := 0.8

func _ready():
    var t := Timer.new()
    t.wait_time = lifetime
    t.one_shot = true
    add_child(t)
    t.timeout.connect(queue_free)
    t.start()
