extends Control

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var audio_quit: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var audio_menumusic: AudioStreamPlayer = AudioStreamPlayer.new()


func _ready():
	audio_quit.stream = preload("res://audio/quit.mp3")
	audio_quit.bus = "Soundeffects"
	audio_menumusic.stream = preload("res://audio/menumusic.mp3")
	audio_menumusic.bus = "MusicSlider"
	add_child(audio_menumusic)
	add_child(audio_quit)
	audio_menumusic.play()

	# web build: hide quit button
	if OS.has_feature("web"):
		quit_button.visible = false

	# conn buttons
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# make sure game is unpaused when returning to menu
	get_tree().paused = false


func _on_start_pressed():
	audio_menumusic.stop()
	# disable btn to prevent double-clicks
	start_button.disabled = true
	GameManager.start_game()


func _on_quit_pressed():
	audio_menumusic.stop()
	audio_quit.play()
	await get_tree().create_timer(1.5).timeout
	get_tree().quit()
