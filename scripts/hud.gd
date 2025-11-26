extends CanvasLayer

signal restart_requested

@onready var weapon_label: Label = $MarginContainer/VBoxContainer/WeaponLabel
@onready var cooldown_bar: ProgressBar = $MarginContainer/VBoxContainer/CooldownBar
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var health_value: Label = $MarginContainer/VBoxContainer/HealthContainer/HealthValue
@onready var crosshair: Label = $Crosshair
@onready var damage_flash: ColorRect = $DamageFlash
@onready var status_panel: Control = $Status
@onready var status_label: Label = $Status/Panel/VBoxContainer/StatusLabel
@onready var restart_button: Button = $Status/Panel/VBoxContainer/RestartButton

func _ready():
    add_to_group("hud")
    if restart_button:
        restart_button.pressed.connect(_on_restart_pressed)

func update_weapon_label(weapons: Array, index: int, cooldown: float):
    if weapons.is_empty():
        weapon_label.text = "No weapon"
        cooldown_bar.value = 0
        return
    var weapon = weapons[index]
    weapon_label.text = weapon.get("name", "Weapon")
    cooldown_bar.max_value = 1.0
    cooldown_bar.value = clamp(1.0 - cooldown, 0.0, 1.0)

func update_health(current: float, max_health: float):
    health_bar.max_value = max_health
    health_bar.value = current
    if health_value:
        health_value.text = str(int(current)) + " / " + str(int(max_health))

func flash_damage():
    if damage_flash == null:
        return
    damage_flash.modulate.a = 0.6
    var tween = create_tween()
    tween.tween_property(damage_flash, "modulate:a", 0.0, 0.4)

func show_status(message: String, allow_restart := false):
    if status_panel == null:
        return
    status_panel.visible = true
    status_label.text = message
    restart_button.visible = allow_restart

func hide_status():
    if status_panel == null:
        return
    status_panel.visible = false

func _on_restart_pressed():
    emit_signal("restart_requested")
