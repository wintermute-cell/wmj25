extends Node2D

## Auto-cleanup dust trail particle effect

@onready var particles: CPUParticles2D = $Particles


func _ready():
	# wait for particles to finish, then cleanup
	if particles:
		particles.finished.connect(queue_free)
