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

## Ultimate ability duration in seconds
@export var ult_duration: float = 5.0

## Ult charge gained per enemy kill
@export var ult_charge_per_kill: float = 20.0

## Maximum ult charge
@export var max_ult_charge: float = 100.0

var health: float = 100.0
var last_damage_shake_time: float = -999.0 # Track last shake time
var distance_since_last_dust: float = 0.0
var last_position: Vector2
var ult_charge: float = 0.0
var is_ult_active: bool = false
var ult_time_remaining: float = 0.0
var e_key_was_pressed: bool = false # for edge detection

const DUST_TRAIL = preload("res://scenes/dust_trail.tscn")

signal health_changed(current_health: float, max_health: float)
signal ult_charge_changed(current_charge: float, max_charge: float)
signal ult_activated()
signal ult_deactivated()

# coll layers
const WALL_LAYER = 1
const PLAYER_LAYER = 2


func _ready():
	collision_layer = 1 << (PLAYER_LAYER - 1) # L2
	collision_mask = 1 << (WALL_LAYER - 1) # coll with walls (L1)

	health = max_health
	health_changed.emit(health, max_health)

	ult_charge = 0.0
	ult_charge_changed.emit(ult_charge, max_ult_charge)

	# player group for enemy targeting
	add_to_group("player")

	# set player z_index so it renders on top of dust particles
	z_index = 1

	# initialize position tracking for dust particles
	last_position = global_position


func _physics_process(delta: float):
	# ult activation (E key)
	var e_key_is_pressed = Input.is_physical_key_pressed(KEY_E)
	if e_key_is_pressed and not e_key_was_pressed:
		if is_ult_active:
			deactivate_ultimate()
		elif ult_charge >= max_ult_charge:
			activate_ultimate()
	e_key_was_pressed = e_key_is_pressed

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

	# ult timer (use unscaled delta since Engine.time_scale affects delta)
	if is_ult_active:
		ult_time_remaining -= delta / Engine.time_scale
		if ult_time_remaining <= 0:
			deactivate_ultimate()


func take_damage(amount: float):
	GameManager.play_player_hit()
	health -= amount
	health = max(health, 0.0) # clamp to 0
	health_changed.emit(health, max_health)

	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_damage_shake_time >= damage_shake_cooldown:
		CameraShake.add_trauma(0.4)
		last_damage_shake_time = current_time

	if health <= 0:
		GameManager.sound_player_died()
		die()


func die():
	# cleanup ult if active
	if is_ult_active:
		Engine.time_scale = 1.0
		is_ult_active = false

	print("Player died!")
	# TODO: impl death behavior (particle, game over, etc..)
	queue_free()


func spawn_dust_particle():
	var dust = DUST_TRAIL.instantiate()
	dust.global_position = global_position
	dust.z_index = 0 # render at default layer (player is at z_index 1)
	# add to parent so it stays in the world and doesn't follow player
	get_parent().add_child(dust)
	# trigger one-shot particle emission
	var particles = dust.get_node("Particles")
	if particles:
		particles.emitting = true


func add_ult_charge(amount: float):
	ult_charge = min(ult_charge + amount, max_ult_charge)
	ult_charge_changed.emit(ult_charge, max_ult_charge)


func activate_ultimate():
	if is_ult_active or ult_charge < max_ult_charge:
		return

	is_ult_active = true
	ult_charge = 0.0
	ult_time_remaining = ult_duration
	ult_charge_changed.emit(ult_charge, max_ult_charge)

	Engine.time_scale = 0.1
	ult_activated.emit()

	print("Ultimate activated! Duration: %.1f seconds" % ult_duration)


func deactivate_ultimate():
	if not is_ult_active:
		return

	is_ult_active = false
	ult_time_remaining = 0.0

	Engine.time_scale = 1.0
	ult_deactivated.emit() # triggers final crush

	print("Ultimate deactivated!")


func _exit_tree():
	# cleanup time scale on scene exit
	if is_ult_active:
		Engine.time_scale = 1.0
