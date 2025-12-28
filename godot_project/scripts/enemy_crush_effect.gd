extends Node2D

## The score value to display
var score_value: int = 100

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

	# animate the label
	var tween = create_tween()
	tween.set_parallel(true)

	# move up 50px over 1 second
	tween.tween_property(score_label, "position", score_label.position + Vector2(0, -50), 1.0)

	# fade out over 1 second
	tween.tween_property(score_label, "modulate:a", 0.0, 1.0)

	# cleanup when both tween and animation are done
	tween.finished.connect(_on_tween_finished)


func _on_tween_finished():
	# wait for animation to finish if it's still playing
	if death_animation and death_animation.is_playing():
		await death_animation.animation_finished
	queue_free()
