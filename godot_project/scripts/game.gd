extends Node2D

@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var health_bar = $CanvasLayer/LanternHealthBar
@onready var ink_bar = $CanvasLayer/InkBar
@onready var player: CharacterBody2D = $CanvasLayer/SubViewportContainer/SubViewport/Player
@onready var brush = $CanvasLayer/SubViewportContainer/SubViewport/Brush
@onready var enemy_spawner: Node2D = $EnemySpawner
@onready var ink_pickup_spawner: Node2D = $InkPickupSpawner
@onready var background: Sprite2D = $CanvasLayer/SubViewportContainer/SubViewport/Background
@onready var camera: Camera2D = $CanvasLayer/SubViewportContainer/SubViewport/Camera2D

# var ghost_texture: Texture2D = preload("res://test_360p_bg_ghost.png")
# var normal_texture: Texture2D = preload("res://test_360p_bg_normal.png")


func _ready():
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.combo_achieved.connect(_on_combo_achieved)
	# init display at start
	_on_score_changed(GameManager.current_score)

	if player:
		player.health_changed.connect(_on_health_changed)
		player.ult_charge_changed.connect(_on_ult_charge_changed)

	if brush:
		brush.ink_changed.connect(_on_ink_changed)

	if enemy_spawner:
		enemy_spawner.reset()

	if ink_pickup_spawner:
		ink_pickup_spawner.reset()

	setup_background_shader()

	# reset cursor to 0 charge for new game
	GameManager.set_ult_charge_percent(0.0)

	# connect camera to shake system
	if camera:
		CameraShake.set_camera(camera)

	# show tutorial on first game after fade in completes
	if not GameManager.tutorial_shown:
		await TransitionLayer.transition_finished
		show_tutorial()


func show_tutorial():
	print("show_tutorial called")
	var tutorial_scene = preload("res://scenes/tutorial.tscn")
	var tutorial_instance = tutorial_scene.instantiate()
	print("Tutorial instance created: ", tutorial_instance)
	# add to canvas layer so it appears on top
	$CanvasLayer.add_child(tutorial_instance)
	print("Tutorial added to scene tree")


func _exit_tree():
	# cleanup camera ref when scene exits
	CameraShake.clear_camera()


func setup_background_shader():
	if background == null:
		push_error("Background not found!")
		return

	var shader_material: ShaderMaterial = background.material
	if shader_material == null:
		push_error("Background sprite needs a ShaderMaterial with the reveal shader!")
		return

	# shader_material.set_shader_parameter("ghost_texture", normal_texture)
	# shader_material.set_shader_parameter("normal_texture", ghost_texture)

	print("Background reveal shader configured successfully")


func _on_score_changed(new_score: int):
	score_label.text = "%d" % new_score


func _on_health_changed(current_health: float, max_health: float):
	if health_bar and health_bar.has_method("update_health"):
		health_bar.update_health(current_health, max_health)


func _on_ink_changed(current_ink: float, max_ink: float):
	if ink_bar and ink_bar.has_method("update_ink"):
		ink_bar.update_ink(current_ink, max_ink)


func _on_ult_charge_changed(current_charge: float, max_charge: float):
	var charge_percent = (current_charge / max_charge) * 100.0
	GameManager.set_ult_charge_percent(charge_percent)


func _on_combo_achieved(multiplier: float, kill_count: int):
	# create large combo popup at center of viewport
	var combo_label = Label.new()
	combo_label.text = "COMBO x%.1f" % multiplier
	combo_label.z_index = 100

	# pos at center of viewport
	var viewport_size = get_viewport_rect().size
	combo_label.position = Vector2(viewport_size.x / 2 - 100, viewport_size.y / 2 - 50)

	# style the combo label (large and prominent)
	combo_label.add_theme_font_size_override("font_size", 48)
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))  # gold
	combo_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	combo_label.add_theme_constant_override("outline_size", 8)

	# add to canvas layer so it appears on top
	$CanvasLayer.add_child(combo_label)

	# animate the label
	var tween = create_tween()
	tween.set_parallel(true)

	# scale pulse effect
	combo_label.scale = Vector2(0.5, 0.5)
	tween.tween_property(combo_label, "scale", Vector2(1.5, 1.5), 0.2)
	tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.3).set_delay(0.2)

	# fade out
	tween.tween_property(combo_label, "modulate:a", 0.0, 0.5).set_delay(0.8)

	# cleanup
	tween.finished.connect(func(): combo_label.queue_free())
