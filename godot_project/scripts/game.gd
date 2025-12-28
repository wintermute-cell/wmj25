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

var ghost_texture: Texture2D = preload("res://test_360p_bg_ghost.png")
var normal_texture: Texture2D = preload("res://test_360p_bg_normal.png")


func _ready():
	GameManager.score_changed.connect(_on_score_changed)
	# initialize display at start
	_on_score_changed(GameManager.current_score)

	if player:
		player.health_changed.connect(_on_health_changed)

	if brush:
		brush.ink_changed.connect(_on_ink_changed)

	if enemy_spawner:
		enemy_spawner.reset()

	if ink_pickup_spawner:
		ink_pickup_spawner.reset()

	setup_background_shader()

	# Connect camera to shake system
	if camera:
		CameraShake.set_camera(camera)


func _exit_tree():
	# Clean up camera reference when scene exits
	CameraShake.clear_camera()


func setup_background_shader():
	if background == null:
		push_error("Background not found!")
		return

	var shader_material: ShaderMaterial = background.material
	if shader_material == null:
		push_error("Background sprite needs a ShaderMaterial with the reveal shader!")
		return

	shader_material.set_shader_parameter("ghost_texture", normal_texture)
	shader_material.set_shader_parameter("normal_texture", ghost_texture)

	print("Background reveal shader configured successfully")


func _on_score_changed(new_score: int):
	score_label.text = "Score: %d" % new_score


func _on_health_changed(current_health: float, max_health: float):
	if health_bar and health_bar.has_method("update_health"):
		health_bar.update_health(current_health, max_health)


func _on_ink_changed(current_ink: float, max_ink: float):
	if ink_bar and ink_bar.has_method("update_ink"):
		ink_bar.update_ink(current_ink, max_ink)
