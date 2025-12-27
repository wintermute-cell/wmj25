extends CanvasLayer
## Pause menu overlay for the game scene

@onready var container: Control = $Container
@onready var resume_button: Button = $Container/CenterContainer/Panel/VBoxContainer/ResumeButton
@onready var restart_button: Button = $Container/CenterContainer/Panel/VBoxContainer/RestartButton
@onready var menu_button: Button = $Container/CenterContainer/Panel/VBoxContainer/MenuButton


func _ready():
	layer = 98

	# start hidden
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # work even when paused

	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)


func _input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC
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
