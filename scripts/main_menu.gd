extends Control

@export var default_sensitivity := 0.002
@export var default_master_volume := 1.0
@export var default_music_volume := 0.45

@onready var game = get_parent()
@onready var start_button: Button = %StartButton
@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var settings_panel: VBoxContainer = %SettingsPanel
@onready var master_slider: HSlider = %MasterVolume
@onready var music_slider: HSlider = %MusicVolume
@onready var sensitivity_slider: HSlider = %Sensitivity
@onready var master_value: Label = %MasterValue
@onready var music_value: Label = %MusicValue
@onready var sensitivity_value: Label = %SensitivityValue
@onready var menu_music: AudioStreamPlayer = $MenuMusic

var settings := {}

func _ready():
    process_mode = Node.PROCESS_MODE_ALWAYS
    settings = {
        "master_volume": default_master_volume,
        "music_volume": default_music_volume,
        "sensitivity": default_sensitivity,
    }
    _connect_buttons()
    _hydrate_controls()
    _apply_audio_settings()
    if game and game.has_method("set_menu_controller"):
        game.set_menu_controller(self)
    if menu_music:
        menu_music.stream = _build_music_loop()
        menu_music.volume_db = linear_to_db(settings["music_volume"])
        menu_music.play()

func _connect_buttons():
    start_button.pressed.connect(_on_start_pressed)
    resume_button.pressed.connect(_on_resume_pressed)
    settings_button.pressed.connect(_toggle_settings)
    quit_button.pressed.connect(_on_quit_pressed)
    master_slider.value_changed.connect(_on_master_volume_changed)
    music_slider.value_changed.connect(_on_music_volume_changed)
    sensitivity_slider.value_changed.connect(_on_sensitivity_changed)

func _hydrate_controls():
    resume_button.disabled = true
    settings_panel.visible = false
    master_slider.value = settings["master_volume"]
    music_slider.value = settings["music_volume"]
    sensitivity_slider.value = settings["sensitivity"]
    _refresh_value_labels()

func _apply_audio_settings():
    AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(settings["master_volume"]))
    if menu_music:
        menu_music.volume_db = linear_to_db(settings["music_volume"])

func _refresh_value_labels():
    master_value.text = str(round(settings["master_volume"] * 100.0)) + "%"
    music_value.text = str(round(settings["music_volume"] * 100.0)) + "%"
    sensitivity_value.text = str(settings["sensitivity"]).pad_decimals(4)

func _on_start_pressed():
    if game and game.has_method("begin_game"):
        game.begin_game(settings)
    hide_menu()
    resume_button.disabled = false

func _on_resume_pressed():
    if game and game.has_method("resume_game"):
        game.resume_game()
    hide_menu()

func _toggle_settings():
    settings_panel.visible = not settings_panel.visible

func _on_quit_pressed():
    get_tree().quit()

func _on_master_volume_changed(value):
    settings["master_volume"] = clamp(value, 0.0, 1.0)
    _refresh_value_labels()
    _apply_audio_settings()
    if game and game.has_method("apply_settings"):
        game.apply_settings(settings)

func _on_music_volume_changed(value):
    settings["music_volume"] = clamp(value, 0.0, 1.0)
    _refresh_value_labels()
    _apply_audio_settings()

func _on_sensitivity_changed(value):
    settings["sensitivity"] = value
    _refresh_value_labels()
    if game and game.has_method("apply_settings"):
        game.apply_settings(settings)

func show_menu(paused := false, allow_resume := false):
    visible = true
    settings_panel.visible = false
    if paused:
        resume_button.disabled = not allow_resume
    else:
        resume_button.disabled = true
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    if menu_music and not menu_music.playing:
        menu_music.play()

func hide_menu():
    visible = false
    settings_panel.visible = false
    if menu_music:
        menu_music.stop()

func sync_after_start():
    resume_button.disabled = false

func _build_music_loop() -> AudioStream:
    var sample := AudioStreamWAV.new()
    sample.mix_rate = 44100
    sample.format = AudioStreamWAV.FORMAT_16_BITS
    sample.stereo = false
    sample.loop_mode = AudioStreamWAV.LOOP_FORWARD
    var duration := 2.8
    var length := int(duration * sample.mix_rate)
    var data := PackedByteArray()
    data.resize(length * 2)
    var freqs := [180.0, 240.0, 320.0]
    for i in length:
        var t = float(i) / sample.mix_rate
        var value := 0.0
        for f in freqs:
            value += sin(TAU * f * t) * 0.35
        value /= freqs.size()
        value *= 0.45
        data.encode_s16(i * 2, int(clamp(value, -1.0, 1.0) * 32767))
    sample.data = data
    sample.loop_begin = 0
    sample.loop_end = length
    return sample
