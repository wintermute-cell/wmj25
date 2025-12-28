extends CharacterBody2D

## Player character with WASD controls
## Collides with paint-masked wall sections

## Movement speed in pixels/second
@export var speed: float = 150.0

## Speed penalty while painting (0.5 = 50% speed)
@export var painting_speed_penalty: float = 0.5

## Maximum health
@export var max_health: float = 100.0

## Time between camera shakes when taking damage
@export var damage_shake_cooldown: float = 0.3

## Distance player must move before spawning next dust particle
@export var dust_spawn_distance: float = 50.0

var health: float = 100.0
var last_damage_shake_time: float = -999.0  # Track last shake time
var distance_since_last_dust: float = 0.0
var last_position: Vector2

const DUST_TRAIL = preload("res://scenes/dust_trail.tscn")

signal health_changed(current_health: float, max_health: float)

# coll layers
const WALL_LAYER = 1
const PLAYER_LAYER = 2


func _ready():
	collision_layer = 1 << (PLAYER_LAYER - 1)  # L2
	collision_mask = 1 << (WALL_LAYER - 1)  # coll with walls (L1)

	health = max_health
	health_changed.emit(health, max_health)

	# player group for enemy targeting
	add_to_group("player")

	# initialize position tracking for dust particles
	last_position = global_position


func _physics_process(delta: float):
	var input_dir = Input.get_vector("left", "right", "up", "down")

	var is_painting = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	# lower speed if painting
	var current_speed = speed
	if is_painting:
		current_speed *= painting_speed_penalty

	velocity = input_dir * current_speed

	move_and_slide()

	# check if player would is out of bounds, and clamp position
	var viewport_rect = get_viewport_rect()
	var player_size_half = get_node("Sprite2D").texture.get_size() / 2
	position.x = clamp(
		position.x, 0 + player_size_half.x, viewport_rect.size.x - player_size_half.x
	)
	position.y = clamp(
		position.y, 0 + player_size_half.y, viewport_rect.size.y - player_size_half.y
	)

	# spawn dust trail particles when moving
	if velocity.length() > 0:
		var distance_moved = global_position.distance_to(last_position)
		distance_since_last_dust += distance_moved

		if distance_since_last_dust >= dust_spawn_distance:
			spawn_dust_particle()
			distance_since_last_dust = 0.0

	last_position = global_position


func take_damage(amount: float):
	health -= amount
	health = max(health, 0.0)  # clamp to 0
	health_changed.emit(health, max_health)

	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_damage_shake_time >= damage_shake_cooldown:
		CameraShake.add_trauma(0.3)
		last_damage_shake_time = current_time

	if health <= 0:
		GameManager.sound_player_died()
		die()


func die():
	print("Player died!")
	# TODO: impl death behavior (particle, game over, etc..)
	queue_free()


func spawn_dust_particle():
	var dust = DUST_TRAIL.instantiate()
	dust.global_position = global_position
	dust.z_index = -5  # render behind player but in front of background
	# add to parent so it stays in the world and doesn't follow player
	get_parent().add_child(dust)
	# trigger one-shot particle emission
	var particles = dust.get_node("Particles")
	if particles:
		particles.emitting = true
