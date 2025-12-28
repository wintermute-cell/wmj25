extends CanvasLayer
## Pause menu overlay for the game scene

@onready var container: Control = $Container
@onready var resume_button: Button = $Container/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ResumeButton
@onready var restart_button: Button = $Container/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RestartButton
@onready var menu_button: Button = $Container/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MenuButton
@onready var music_volume_slider: HSlider = $Container/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MCMusic/MusicSettings/MusicVolumeSlider
@onready var soundeffects_volume_slider: HSlider = $Container/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MCSoundeffects/SoundEffectSettings/SoundeffectsVolumeSlider

func _ready():
	# connect signals for volume sliders
	music_volume_slider.value_changed.connect(func(value):
		GameManager.set_music_volume(value)
	)
	soundeffects_volume_slider.value_changed.connect(func(value):
		GameManager.set_soundeffects_volume(value, true)
	)


	layer = 98

	# start hidden
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS # work even when paused

	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)


func _input(event):
	if event.is_action_pressed("ui_cancel"): # ESC
		if visible:
			_on_resume_pressed()
		else:
			_show_pause_menu()


func _show_pause_menu():
	visible = true
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	GameManager.pause_game()


func _hide_pause_menu():
	visible = false
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameManager.resume_game()


func _on_resume_pressed():
	_hide_pause_menu()


func _on_restart_pressed():
	_hide_pause_menu()
	GameManager.restart_game()


func _on_menu_pressed():
	_hide_pause_menu()
	GameManager.return_to_menu()
