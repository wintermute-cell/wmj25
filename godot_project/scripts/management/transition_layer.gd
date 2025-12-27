extends CanvasLayer
## Handles screen transitions (fades, wipes, etc.)

signal transition_finished

@onready var color_rect: ColorRect = $ColorRect
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready():
	layer = 100
	color_rect.color.a = 0.0


func transition_out():
	"""Fade to black"""
	print("[TransitionLayer] Playing fade_out")
	animation_player.play("fade_out")
	await animation_player.animation_finished
	print("[TransitionLayer] fade_out finished")
	transition_finished.emit()


func transition_in():
	"""Fade from black"""
	print("[TransitionLayer] Playing fade_in")
	animation_player.play("fade_in")
	await animation_player.animation_finished
	print("[TransitionLayer] fade_in finished")
	transition_finished.emit()
