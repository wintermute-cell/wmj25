extends Control

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var audio_test: AudioStreamPlayer = AudioStreamPlayer.new()


func _ready():
	audio_test.stream = preload("res://audio/quit.mp3")
	audio_test.bus = "Soundeffects"
	add_child(audio_test)
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
	audio_test.play()
	await get_tree().create_timer(1.5).timeout
	get_tree().quit()
