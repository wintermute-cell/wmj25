extends CharacterBody2D

## Player character with WASD controls
## Collides with paint-masked wall sections

## Movement speed in pixels/second
@export var speed: float = 150.0

## Speed penalty while painting (0.5 = 50% speed)
@export var painting_speed_penalty: float = 0.5

## Maximum health
@export var max_health: float = 100.0

var health: float = 100.0

# coll layers
const WALL_LAYER = 1
const PLAYER_LAYER = 2


func _ready():
	collision_layer = 1 << (PLAYER_LAYER - 1) # L2
	collision_mask = 1 << (WALL_LAYER - 1) # coll with walls (L1)

	health = max_health

	# player group for enemy targeting
	add_to_group("player")


func _physics_process(delta: float):
	var input_dir = Input.get_vector("left", "right", "up", "down")

	var is_painting = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	# lower speed if painting
	var current_speed = speed
	if is_painting:
		current_speed *= painting_speed_penalty

	velocity = input_dir * current_speed

	move_and_slide()


func take_damage(amount: float):
	health -= amount
	if health <= 0:
		GameManager.sound_player_died()
		die()


func die():
	print("Player died!")
	# TODO: impl death behavior (particle, game over, etc..)
	queue_free()
