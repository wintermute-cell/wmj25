extends Control

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton


func _ready():
	# web build: hide quit button
	if OS.has_feature("web"):
		quit_button.visible = false

	# conn buttons
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# make sure game is unpaused when returning to menu
	get_tree().paused = false


func _on_start_pressed():
	# disable btn to prevent double-clicks
	start_button.disabled = true
	GameManager.start_game()


func _on_quit_pressed():
	get_tree().quit()
