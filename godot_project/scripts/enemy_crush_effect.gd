extends Node2D

## The score value to display
var score_value: int = 100

## References
@onready var particles: CPUParticles2D = $CPUParticles2D
@onready var score_label: Label = $ScoreLabel


func _ready():
	# set the score text
	score_label.text = str(score_value)

	# start particles
	particles.emitting = true

	# animate the label
	var tween = create_tween()
	tween.set_parallel(true)

	# move up 50px over 1 second
	tween.tween_property(score_label, "position", score_label.position + Vector2(0, -50), 1.0)

	# fade out over 1 second
	tween.tween_property(score_label, "modulate:a", 0.0, 1.0)

	# cleanup when done
	tween.finished.connect(queue_free)
