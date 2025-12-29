extends Node2D

## The score value to display
var score_value: int = 100

## Combo multiplier (1.0 = no combo)
var multiplier: float = 1.0

## Number of kills in combo
var kill_count: int = 1

## References
@onready var particles: CPUParticles2D = $CPUParticles2D
@onready var score_label: Label = $ScoreLabel
@onready var death_animation: AnimatedSprite2D = $DeathAnimation


func _ready():
	# set the score text
	score_label.text = str(score_value)

	# start particles
	particles.emitting = true

	# play death animation
	if death_animation:
		death_animation.play("death")

	# create combo label if there's a multiplier
	if multiplier > 1.0:
		create_combo_label()

	# animate the label
	var tween = create_tween()
	tween.set_parallel(true)

	# move up 50px over 1 second
	tween.tween_property(score_label, "position", score_label.position + Vector2(0, -50), 1.0)

	# fade out over 1 second
	tween.tween_property(score_label, "modulate:a", 0.0, 1.0)

	# cleanup when both tween and animation are done
	tween.finished.connect(_on_tween_finished)


func create_combo_label():
	# Create a larger, more prominent label for the combo text
	var combo_label = Label.new()
	combo_label.text = "COMBO x%.1f" % multiplier
	combo_label.position = Vector2(-50, -40)  # Position above the score
	combo_label.z_index = 10

	# Style the combo label
	combo_label.add_theme_font_size_override("font_size", 24)
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))  # Gold color
	combo_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	combo_label.add_theme_constant_override("outline_size", 4)

	add_child(combo_label)

	# Animate the combo label
	var combo_tween = create_tween()
	combo_tween.set_parallel(true)

	# Scale in and then out
	combo_tween.tween_property(combo_label, "scale", Vector2(1.5, 1.5), 0.3)
	combo_tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.3).set_delay(0.3)

	# Move up more dramatically
	combo_tween.tween_property(combo_label, "position", combo_label.position + Vector2(0, -70), 1.0)

	# Fade out
	combo_tween.tween_property(combo_label, "modulate:a", 0.0, 1.0)


func _on_tween_finished():
	# wait for animation to finish if it's still playing
	if death_animation and death_animation.is_playing():
		await death_animation.animation_finished
	queue_free()
