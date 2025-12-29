extends Control

@export_range(0.0, 1.0) var initial_reveal_percent: float = 0.2  # how much visible at start
@export var unroll_duration: float = 0.8  # how long to unroll

@onready var tutorial_sprite: TextureRect = $CenterContainer/TutorialSprite
@onready var shader_material: ShaderMaterial = tutorial_sprite.material

var is_unrolling: bool = false
var can_dismiss: bool = false  # prevent immediate dismissal from menu click


func _ready():
	print("Tutorial ready, shader_material: ", shader_material != null)

	# start with only initial percent visible
	if shader_material:
		shader_material.set_shader_parameter("reveal_percent", initial_reveal_percent)
	else:
		print("WARNING: No shader material on tutorial sprite!")

	# pause the game
	get_tree().paused = true

	# start unroll animation
	unroll_scroll()

	# allow dismissal after brief delay to avoid menu click
	await get_tree().create_timer(0.3, true, false, true).timeout
	can_dismiss = true


func _input(event):
	if not can_dismiss:
		return

	# dismiss on any key press or mouse button
	if event is InputEventKey and event.pressed:
		dismiss()
	elif event is InputEventMouseButton and event.pressed:
		dismiss()


func unroll_scroll():
	is_unrolling = true

	if not shader_material:
		# fallback if no shader
		print("No shader material, dismissing tutorial")
		dismiss()
		return

	# animate from initial percent to 100%
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # continue during pause
	tween.tween_method(
		set_reveal_percent,
		initial_reveal_percent,
		1.0,
		unroll_duration
	)
	tween.finished.connect(func(): is_unrolling = false)


func set_reveal_percent(percent: float):
	if shader_material:
		shader_material.set_shader_parameter("reveal_percent", percent)


func dismiss():
	print("Tutorial dismissed")
	# mark tutorial as shown
	GameManager.tutorial_shown = true

	# roll back up to initial percent
	await roll_back()

	# unpause game
	get_tree().paused = false

	# remove self
	queue_free()


func roll_back():
	if not shader_material:
		return

	# get current reveal percent
	var current_percent = shader_material.get_shader_parameter("reveal_percent")

	# animate back to initial percent
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # continue during pause
	tween.tween_method(
		set_reveal_percent,
		current_percent,
		initial_reveal_percent,
		unroll_duration
	)
	await tween.finished
