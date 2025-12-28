extends Node
## Singleton for managing game state and scene transitions

const MAIN_MENU_PATH = "res://scenes/main_menu.tscn"
const GAME_PATH = "res://scenes/game.tscn"

enum GameState {MENU, PLAYING, PAUSED, LOADING}
var current_state: GameState = GameState.MENU

var current_score: int = 0
signal score_changed(new_score: int)

@onready var audio_start_game: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var audio_click_menu_item: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var audio_ingame_music: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var audio_brush_stroke_double: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var audio_brush_stroke_single: AudioStreamPlayer = AudioStreamPlayer.new()

@onready var audio_player_dead: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var audio_enemy_dead2: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var audio_enemy_dead3: AudioStreamPlayer = AudioStreamPlayer.new()

@onready var audio_item_pickup: AudioStreamPlayer = AudioStreamPlayer.new()


var ingame_music_position: float = 0.0


func _ready():
	load_audio()
	# ensure we start in the correct state
	if get_tree().current_scene:
		var scene_path = get_tree().current_scene.scene_file_path
		if scene_path == GAME_PATH:
			current_state = GameState.PLAYING


func start_game():
	current_score = 0
	audio_start_game.play()
	start_ingame_music()

	if current_state == GameState.LOADING:
		return
	current_state = GameState.LOADING
	SceneLoader.load_scene(GAME_PATH)


func return_to_menu():
	audio_start_game.stop() # just in case its still playing
	ingame_music_position = 0.0
	audio_ingame_music.stop()
	if current_state == GameState.LOADING:
		return
	current_state = GameState.LOADING
	SceneLoader.load_scene(MAIN_MENU_PATH)


func restart_game():
	current_score = 0
	audio_ingame_music.stop()
	ingame_music_position = 0.0
	audio_start_game.play()
	start_ingame_music()
	if current_state == GameState.LOADING:
		return
	current_state = GameState.LOADING
	SceneLoader.load_scene(GAME_PATH)


func on_scene_loaded(scene_path: String):
	# update state based on which scene loaded
	if scene_path == MAIN_MENU_PATH:
		current_state = GameState.MENU
	elif scene_path == GAME_PATH:
		current_state = GameState.PLAYING


func pause_game():
	ingame_music_position = audio_ingame_music.get_playback_position()
	audio_ingame_music.stop()
	audio_click_menu_item.play()
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true


func resume_game():
	resume_ingame_music()
	audio_click_menu_item.play()
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false


func add_score(points: int):
	current_score += points
	score_changed.emit(current_score)


#########################################################################
## Audio Management
#########################################################################
func load_audio():
	set_music_volume(0.5)
	set_soundeffects_volume(0.5)

	audio_start_game.stream = preload("res://audio/newgame.mp3")
	audio_start_game.bus = "Soundeffects"
	add_child(audio_start_game)

	# UI click sound
	audio_click_menu_item.stream = preload("res://audio/chime.mp3")
	audio_click_menu_item.bus = "Soundeffects"
	add_child(audio_click_menu_item)

	# ingame music
	audio_ingame_music.stream = preload("res://audio/music.mp3")
	audio_ingame_music.bus = "Reverb"
	add_child(audio_ingame_music)

	#########################################################################
	# ingame sound effects
	audio_player_dead.stream = preload("res://audio/dead.mp3")
	audio_player_dead.bus = "Soundeffects"
	add_child(audio_player_dead)

	audio_enemy_dead2.stream = preload("res://audio/breaking2.mp3")
	audio_enemy_dead2.bus = "Soundeffects"
	add_child(audio_enemy_dead2)
	audio_enemy_dead3.stream = preload("res://audio/breaking3.mp3")
	audio_enemy_dead3.bus = "Soundeffects"
	add_child(audio_enemy_dead3)


	audio_brush_stroke_double.stream = preload("res://audio/stroke1.mp3")
	audio_brush_stroke_double.bus = "Brushstrokes"
	add_child(audio_brush_stroke_double)

	audio_brush_stroke_single.stream = preload("res://audio/strokesingle.mp3")
	audio_brush_stroke_single.bus = "Brushstrokes"
	add_child(audio_brush_stroke_single)


func set_music_volume(volume: float):
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Music"), volume)


func set_soundeffects_volume(volume: float, replay_click: bool = false):
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Soundeffects"), volume)
	if replay_click:
		audio_click_menu_item.play()


##################
# Playback control
func start_ingame_music():
	await audio_start_game.finished
	audio_ingame_music.play(ingame_music_position)


func resume_ingame_music():
	audio_ingame_music.play(ingame_music_position)


func sound_player_died():
	audio_player_dead.play()

func sound_enemy_died():
	var r = randi() % 2
	if r == 0:
		audio_enemy_dead2.play()
	else:
		audio_enemy_dead3.play()


######
# brush sounds
var brush_stroke_playing: bool = false


func start_playing_brush_stroke():
	brush_stroke_playing = true
	while brush_stroke_playing:
		var r = randi() % 2
		if r == 0:
			audio_brush_stroke_single.play()
			await audio_brush_stroke_single.finished
		else:
			audio_brush_stroke_double.play()
			await audio_brush_stroke_double.finished


func stop_playing_brush_stroke():
	brush_stroke_playing = false


func play_brush_stroke_double():
	audio_brush_stroke_double.play()


func play_brush_stroke_single():
	audio_brush_stroke_single.play()
