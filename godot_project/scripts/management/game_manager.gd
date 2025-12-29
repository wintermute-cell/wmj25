extends Node
## Singleton for managing game state and scene transitions

const MAIN_MENU_PATH = "res://scenes/main_menu.tscn"
const GAME_PATH = "res://scenes/game.tscn"

enum GameState {MENU, PLAYING, PAUSED, LOADING}
var current_state: GameState = GameState.MENU

var current_score: int = 0
signal score_changed(new_score: int)

# Combo system
var kill_timestamps: Array[float] = []
var combo_window: float = 2.0 ## Time window in seconds for combo kills
var combo_tiers: Array[Dictionary] = [
	{"min_kills": 7, "multiplier": 3.0},
	{"min_kills": 5, "multiplier": 2.0},
	{"min_kills": 3, "multiplier": 1.5}
]
signal combo_achieved(multiplier: float, kill_count: int)


@onready var audio_ingame_music: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var audio_ambient_loop_1: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var audio_ambient_loop_2: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var audio_ambient_bees: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var audio_ambient_birds: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var audio_ambient_breath: AudioStreamPlayer = AudioStreamPlayer.new()


@onready var audio_start_game: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var audio_click_menu_item: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var audio_brush_stroke_double: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var audio_brush_stroke_single: AudioStreamPlayer = AudioStreamPlayer.new()

@onready var audio_player_dead: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var audio_enemy_dead2: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var audio_enemy_dead3: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var audio_enemy_dead_additional: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var audio_enemy_dash: AudioStreamPlayer = AudioStreamPlayer.new()

@onready var audio_ink_pickup: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var audio_score_increase: AudioStreamPlayer = AudioStreamPlayer.new()


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
	kill_timestamps.clear()
	reset_music_pitch()
	audio_start_game.play()
	start_ingame_music()
	start_ambient_sounds()

	if current_state == GameState.LOADING:
		return
	current_state = GameState.LOADING
	SceneLoader.load_scene(GAME_PATH)


func return_to_menu():
	audio_start_game.stop() # just in case its still playing
	stop_ingame_music()
	stop_ambient_sounds()
	reset_music_pitch()
	if current_state == GameState.LOADING:
		return
	current_state = GameState.LOADING
	SceneLoader.load_scene(MAIN_MENU_PATH)


func restart_game():
	current_score = 0
	kill_timestamps.clear()
	reset_music_pitch()
	stop_ingame_music()
	stop_ambient_sounds()
	ingame_music_position = 0.0
	audio_start_game.play()
	start_ingame_music()
	start_ambient_sounds()

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
	pause_ingame_music()
	stop_ambient_sounds()
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
	change_music_pitch()
	score_changed.emit(current_score)
	start_playing_score_increase()


## Register a kill and return the combo multiplier
## Returns a dictionary with: {"multiplier": float, "kill_count": int}
func register_kill() -> Dictionary:
	var current_time = Time.get_ticks_msec() / 1000.0

	# Add current kill timestamp
	kill_timestamps.append(current_time)

	# Remove timestamps outside the combo window
	var cutoff_time = current_time - combo_window
	kill_timestamps = kill_timestamps.filter(func(t): return t >= cutoff_time)

	# Count kills in window
	var kill_count = kill_timestamps.size()

	# Determine multiplier based on kill count
	var multiplier = 1.0
	for tier in combo_tiers:
		if kill_count >= tier.min_kills:
			multiplier = tier.multiplier
			break

	# Emit combo signal if we have a multiplier
	if multiplier > 1.0:
		combo_achieved.emit(multiplier, kill_count)

	return {"multiplier": multiplier, "kill_count": kill_count}


#########################################################################
## Audio Management
#########################################################################
func load_audio():
	set_music_volume(0.5)
	set_soundeffects_volume(0.5)

	audio_start_game.stream = preload("res://audio/newgame.mp3")
	audio_start_game.bus = "SoundeffectsSlider"
	add_child(audio_start_game)

	# UI click sound
	audio_click_menu_item.stream = preload("res://audio/chime.mp3")
	audio_click_menu_item.bus = "SoundeffectsSlider"
	add_child(audio_click_menu_item)

	# ingame music and ambient loops
	audio_ingame_music.stream = preload("res://audio/music_japanese_hack.ogg")
	audio_ingame_music.bus = "Reverb"
	add_child(audio_ingame_music)

	audio_ambient_loop_1.stream = preload("res://audio/ambient/ambient1.wav")
	audio_ambient_loop_1.bus = "AmbientSlider"
	add_child(audio_ambient_loop_1)

	audio_ambient_loop_2.stream = preload("res://audio/ambient/eerie_winds.wav")
	audio_ambient_loop_2.bus = "Eerie Winds"
	add_child(audio_ambient_loop_2)

	audio_ambient_bees.stream = preload("res://audio/ambient/bees.ogg")
	audio_ambient_bees.bus = "Bees"
	add_child(audio_ambient_bees)

	audio_ambient_birds.stream = preload("res://audio/ambient/birds.ogg")
	audio_ambient_birds.bus = "Birds"
	add_child(audio_ambient_birds)

	audio_ambient_breath.stream = preload("res://audio/ambient/breath.mp3")
	audio_ambient_breath.bus = "Breath"
	add_child(audio_ambient_breath)

	audio_enemy_dash.stream = preload("res://audio/dash.mp3")
	audio_enemy_dash.bus = "Dash"
	add_child(audio_enemy_dash)

	#########################################################################
	# ingame sound effects
	audio_player_dead.stream = preload("res://audio/dead.mp3")
	audio_player_dead.bus = "SoundeffectsSlider"
	add_child(audio_player_dead)

	audio_enemy_dead2.stream = preload("res://audio/breaking2.mp3")
	audio_enemy_dead2.bus = "Breaking"
	add_child(audio_enemy_dead2)
	audio_enemy_dead3.stream = preload("res://audio/breaking3.mp3")
	audio_enemy_dead3.bus = "Breaking"
	add_child(audio_enemy_dead3)
	audio_enemy_dead_additional.stream = preload("res://audio/woosch.wav")
	audio_enemy_dead_additional.bus = "Woosch"
	add_child(audio_enemy_dead_additional)

	audio_ink_pickup.stream = preload("res://audio/inkpickup.wav")
	audio_ink_pickup.bus = "Inkpickup"
	add_child(audio_ink_pickup)

	audio_score_increase.stream = preload("res://audio/score.mp3")
	audio_score_increase.bus = "Score"
	add_child(audio_score_increase)


	audio_brush_stroke_double.stream = preload("res://audio/stroke1.mp3")
	audio_brush_stroke_double.bus = "Brushstrokes"
	add_child(audio_brush_stroke_double)

	audio_brush_stroke_single.stream = preload("res://audio/strokesingle.mp3")
	audio_brush_stroke_single.bus = "Brushstrokes"
	add_child(audio_brush_stroke_single)


func set_music_volume(volume: float):
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("MusicSlider"), volume)


func set_soundeffects_volume(volume: float, replay_click: bool = false):
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("SoundeffectsSlider"), volume)
	if replay_click:
		audio_click_menu_item.play()

func set_ambient_volume(volume: float):
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("AmbientSlider"), volume)


##################
# Playback control
func start_ingame_music():
	await audio_start_game.finished
	audio_ingame_music.play(ingame_music_position)

func pause_ingame_music():
	ingame_music_position = audio_ingame_music.get_playback_position()
	audio_ingame_music.stop()

func stop_ingame_music():
	ingame_music_position = 0.0
	audio_ingame_music.stop()

func start_ambient_sounds():
	fade_in_ambient()
	audio_ambient_loop_1.play()
	do_eerie_winds()
	start_random_ambient_sounds()

func stop_ambient_sounds():
	audio_ambient_loop_1.stop()
	audio_ambient_loop_2.stop()
	stop_random_ambient_sounds()

func resume_ingame_music():
	audio_ingame_music.play(ingame_music_position)
	audio_ambient_loop_1.play()


func change_music_pitch():
	var pitch_change = current_score / 90000.0
	pitch_change = clamp(1.0 + pitch_change, 1.0, 16.0)
	AudioServer.get_bus_effect(AudioServer.get_bus_index("MusicSlider"), 0).set_pitch_scale(pitch_change)

func reset_music_pitch():
	AudioServer.get_bus_effect(AudioServer.get_bus_index("MusicSlider"), 0).set_pitch_scale(1.0)

func sound_player_died():
	audio_player_dead.play()

func sound_enemy_died():
	var r = randi() % 2
	if r == 0:
		audio_enemy_dead2.play()
	else:
		audio_enemy_dead3.play()
	var random_pitch_for_woosch = 1.0 + (randf() * 0.2) - 0.1
	AudioServer.get_bus_effect(AudioServer.get_bus_index("Woosch"), 0).set_pitch_scale(random_pitch_for_woosch)
	audio_enemy_dead_additional.play()

func start_random_ambient_sounds():
	while audio_ambient_loop_1.playing:
		var wait_time = 20 + randi() % 40
		await get_tree().create_timer(wait_time).timeout
		if not audio_ambient_loop_1.playing:
			break
		var r = randi() % 3
		if r == 0:
			play_bees()
		elif r == 1:
			# set pitch variation
			var random_pitch_for_birds = 1.0 + (randf() * 0.1) - 0.1
			AudioServer.get_bus_effect(AudioServer.get_bus_index("Birds"), 0).set_pitch_scale(random_pitch_for_birds)
			play_birds()
		elif r == 2:
			# set pitch variation
			var random_pitch_for_breath = 1.0 + (randf() * 0.2) - 0.1
			AudioServer.get_bus_effect(AudioServer.get_bus_index("Breath"), 0).set_pitch_scale(random_pitch_for_breath)
			play_breath()

func stop_random_ambient_sounds():
	stop_bees()
	stop_birds()
	stop_breath()


func play_bees():
	audio_ambient_bees.play()
func stop_bees():
	audio_ambient_bees.stop()
func play_birds():
	audio_ambient_birds.play()
func stop_birds():
	audio_ambient_birds.stop()
func play_breath():
	audio_ambient_breath.play()
func stop_breath():
	audio_ambient_breath.stop()


@onready var eerie_winds_target_volume: float = AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Eerie Winds"))

func do_eerie_winds():
	while audio_ambient_loop_1.playing:
		var wait_time = 5 + randi() % 20
		var duration = 2 + randi() % 10
		await get_tree().create_timer(wait_time).timeout
		if not audio_ambient_loop_1.playing:
			break
		audio_ambient_loop_2.play()
		await fade_in_eerie_winds()
		await get_tree().create_timer(duration).timeout
		await fade_out_eerie_winds()
		audio_ambient_loop_2.stop()

func fade_in_eerie_winds(step_duration: float = 0.2):
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Eerie Winds"), 0.0)
	var steps = 20
	for i in range(steps):
		var vol = eerie_winds_target_volume * (i + 1) / steps
		AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Eerie Winds"), vol)
		await get_tree().create_timer(step_duration).timeout

func fade_out_eerie_winds(step_duration: float = 0.2):
	var steps = 20
	for i in range(steps):
		var vol = eerie_winds_target_volume * (i + 1) / steps
		AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Eerie Winds"), eerie_winds_target_volume - vol)
		await get_tree().create_timer(step_duration).timeout

func fade_in_ambient():
	var target_volume = AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("AmbientSlider"))
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("AmbientSlider"), 0.0)
	var steps = 20
	for i in range(steps):
		var vol = target_volume * (i + 1) / steps
		AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("AmbientSlider"), vol)
		await get_tree().create_timer(0.2).timeout


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


func start_playing_score_increase():
	await get_tree().create_timer(0.2).timeout
	audio_score_increase.play()
func stop_playing_score_increase():
	audio_score_increase.stop()

func start_playing_ink_pickup():
	audio_ink_pickup.play()
func stop_playing_ink_pickup():
	audio_ink_pickup.stop()

func start_playing_enemy_dash():
	audio_enemy_dash.play()
func stop_playing_enemy_dash():
	audio_enemy_dash.stop()
