extends CanvasLayer

@onready var weapon_label: Label = $MarginContainer/VBoxContainer/WeaponLabel
@onready var cooldown_bar: TextureProgressBar = $MarginContainer/VBoxContainer/CooldownBar
@onready var health_bar: TextureProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var crosshair: Label = $Crosshair

func _ready():
    add_to_group("hud")

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
