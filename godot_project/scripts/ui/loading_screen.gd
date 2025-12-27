extends CanvasLayer
## Loading screen shown during scene transitions

@export var progress_bar: ProgressBar
@export var loading_label: Label


func _ready():
	layer = 99

	SceneLoader.loading_started.connect(_on_loading_started)
	SceneLoader.loading_progress.connect(_on_loading_progress)
	SceneLoader.loading_finished.connect(_on_loading_finished)

	visible = false


func _on_loading_started(scene_path: String):
	print("[LoadingScreen] Loading started, making visible")
	visible = true
	if progress_bar:
		progress_bar.value = 0.0
	if loading_label:
		loading_label.text = "Loading..."


func _on_loading_progress(progress: float):
	if progress_bar:
		progress_bar.value = progress * 100.0


func _on_loading_finished():
	if progress_bar:
		progress_bar.value = 100.0
	# hide immediately
	print("[LoadingScreen] Hiding loading screen")
	visible = false
