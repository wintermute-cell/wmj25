extends Node
## async scene loading with progress tracking

signal loading_started(scene_path: String)
signal loading_progress(progress: float)
signal loading_finished

## min time (in seconds) to show loading screen
@export var min_loading_time := 2.0

var is_loading := false
var target_scene_path := ""
var loading_start_time := 0.0


func load_scene(scene_path: String):
	if is_loading:
		push_warning("Already loading a scene, ignoring request")
		return

	print("[SceneLoader] Starting to load: ", scene_path)
	is_loading = true
	target_scene_path = scene_path

	print("[SceneLoader] Starting transition out")
	TransitionLayer.transition_out()
	await TransitionLayer.transition_finished
	print("[SceneLoader] Transition out complete")

	# show loading screen and track start time
	loading_start_time = Time.get_ticks_msec() / 1000.0
	loading_started.emit(scene_path)

	print("[SceneLoader] Revealing loading screen")
	TransitionLayer.transition_in()
	await TransitionLayer.transition_finished

	# threaded loading
	var status = ResourceLoader.load_threaded_request(scene_path)
	if status != OK:
		push_error("Failed to start loading scene: " + scene_path)
		is_loading = false
		return

	await _poll_loading()

	# get the loaded scene
	var packed_scene = ResourceLoader.load_threaded_get(scene_path)
	if packed_scene == null:
		push_error("Failed to load scene: " + scene_path)
		is_loading = false
		return

	# ensure minimum loading time has elapsed before switching scenes
	var elapsed_time = (Time.get_ticks_msec() / 1000.0) - loading_start_time
	var remaining_time = min_loading_time - elapsed_time
	if remaining_time > 0:
		print("[SceneLoader] Waiting additional ", remaining_time, " seconds")
		await get_tree().create_timer(remaining_time).timeout

	print("[SceneLoader] Fading to black")
	TransitionLayer.transition_out()
	await TransitionLayer.transition_finished

	# hide loading screen behind black
	loading_finished.emit()

	# switch scenes hidden behind black
	print("[SceneLoader] Switching to new scene")
	_change_to_scene(packed_scene)

	# wait 1 frame for scene to init
	await get_tree().process_frame

	# transition in
	TransitionLayer.transition_in()
	await TransitionLayer.transition_finished

	is_loading = false
	GameManager.on_scene_loaded(scene_path)


func _poll_loading():
	var progress = []
	while true:
		var status = ResourceLoader.load_threaded_get_status(target_scene_path, progress)

		if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Invalid resource path")
			return
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Loading failed")
			return
		elif status == ResourceLoader.THREAD_LOAD_LOADED:
			loading_progress.emit(1.0)
			return
		elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			loading_progress.emit(progress[0])
			await get_tree().process_frame
		else:
			await get_tree().process_frame


func _change_to_scene(packed_scene: PackedScene):
	# clean up old scene
	var old_scene = get_tree().current_scene
	if old_scene:
		# clear current_scene ref first, then free immediately
		get_tree().current_scene = null
		old_scene.free()

	# instance and add new scene
	var new_scene = packed_scene.instantiate()
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
