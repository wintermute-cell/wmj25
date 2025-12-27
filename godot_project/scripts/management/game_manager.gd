extends Node
## Singleton for managing game state and scene transitions

const MAIN_MENU_PATH = "res://scenes/main_menu.tscn"
const GAME_PATH = "res://scenes/brush_testing.tscn"

enum GameState { MENU, PLAYING, PAUSED, LOADING }
var current_state: GameState = GameState.MENU


func _ready():
	# ensure we start in the correct state
	if get_tree().current_scene:
		var scene_path = get_tree().current_scene.scene_file_path
		if scene_path == GAME_PATH:
			current_state = GameState.PLAYING


func start_game():
	if current_state == GameState.LOADING:
		return
	current_state = GameState.LOADING
	SceneLoader.load_scene(GAME_PATH)


func return_to_menu():
	if current_state == GameState.LOADING:
		return
	current_state = GameState.LOADING
	SceneLoader.load_scene(MAIN_MENU_PATH)


func restart_game():
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
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true


func resume_game():
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false
