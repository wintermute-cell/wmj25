extends CanvasLayer


@onready var container: Control = $Container
@onready var restart_button: Button = $Container/CenterContainer/VBoxContainer/CenterContainer2/VBoxContainer/RestartButton
@onready var menu_button: Button = $Container/CenterContainer/VBoxContainer/CenterContainer2/VBoxContainer/MenuButton
@onready var score_label: Label = $Container/CenterContainer/VBoxContainer/VBoxContainer/CenterContainer3/ScoreLabel


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)


	score_label.text = "Score: %d" % GameManager.current_score

func _on_restart_pressed():
	# Don't unpause - keep game paused during scene transition
	visible = false
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameManager.restart_game()


func _on_menu_pressed():
	# Don't unpause - keep game paused during scene transition
	visible = false
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameManager.return_to_menu()
