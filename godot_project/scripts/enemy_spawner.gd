extends Node2D

## Enemy spawning system with configurable difficulty progression

## Enemy scene to spawn
@export var enemy_scene: PackedScene

## Minimum time between spawns (seconds) - at max difficulty
@export var min_spawn_interval: float = 0.5

## Maximum time between spawns (seconds) - at start
@export var max_spawn_interval: float = 3.0

## Time to reach maximum difficulty (seconds)
@export var difficulty_ramp_duration: float = 120.0

## Curve controlling difficulty progression over time (0.0 to 1.0)
## X axis: normalized time (0 = start, 1 = difficulty_ramp_duration)
## Y axis: difficulty (0 = easy/slow spawns, 1 = hard/fast spawns)
@export var difficulty_curve: Curve

## Distance from screen edge to spawn enemies
@export var spawn_margin: float = 32.0

## Reference to the viewport for screen bounds
@export var viewport: SubViewport

# Internal state
var elapsed_time: float = 0.0
var time_until_next_spawn: float = 0.0
var spawn_parent: Node


func _ready():
	# default curve if none provided
	if difficulty_curve == null:
		difficulty_curve = Curve.new()
		difficulty_curve.add_point(Vector2(0.0, 0.0))
		difficulty_curve.add_point(Vector2(1.0, 1.0))

	# find spawn parent (where enemies will be added)
	if viewport:
		spawn_parent = viewport
	else:
		spawn_parent = get_parent()

	# preload enemy scene if not set
	if enemy_scene == null:
		enemy_scene = preload("res://scenes/enemy.tscn")

	# schedule first spawn
	time_until_next_spawn = max_spawn_interval


func _process(delta: float):
	elapsed_time += delta
	time_until_next_spawn -= delta

	if time_until_next_spawn <= 0:
		spawn_enemy()
		time_until_next_spawn = get_current_spawn_interval()


func spawn_enemy():
	if enemy_scene == null or spawn_parent == null:
		return

	var enemy = enemy_scene.instantiate()
	# change enemy type for variety
	var enemy_type_roll: int = 100 # default value to avoid changing type before time is elapsed to 30 seconds
	if elapsed_time > 30.0:
		enemy_type_roll = randi() % 30
	if elapsed_time > 60.0:
		enemy_type_roll = randi() % 25
	if elapsed_time > 90.0:
		enemy_type_roll = randi() % 15

	print("Enemy type roll: %d" % enemy_type_roll)

	if enemy_type_roll < 6:
		enemy_type_roll = 1 # DASHER
	elif enemy_type_roll < 8:
		enemy_type_roll = 2 # SPRINTER
	else:
		enemy_type_roll = 0 # BASIC

	enemy.change_enemy_type(enemy_type_roll)


	enemy.global_position = get_random_spawn_position()
	spawn_parent.add_child(enemy)


func get_current_spawn_interval() -> float:
	# calculate difficulty based on elapsed time
	var normalized_time = clamp(elapsed_time / difficulty_ramp_duration, 0.0, 1.0)
	var difficulty = difficulty_curve.sample(normalized_time)

	# lerp from max to min interval based on difficulty
	return lerp(max_spawn_interval, min_spawn_interval, difficulty)


func get_random_spawn_position() -> Vector2:
	if viewport == null:
		return Vector2.ZERO

	var screen_size = viewport.size
	var spawn_pos = Vector2.ZERO

	# 0=top, 1=right, 2=bottom, 3=left
	var side = randi() % 4

	match side:
		0: # top
			spawn_pos.x = randf_range(0, screen_size.x)
			spawn_pos.y = - spawn_margin
		1: # right
			spawn_pos.x = screen_size.x + spawn_margin
			spawn_pos.y = randf_range(0, screen_size.y)
		2: # bottom
			spawn_pos.x = randf_range(0, screen_size.x)
			spawn_pos.y = screen_size.y + spawn_margin
		3: # left
			spawn_pos.x = - spawn_margin
			spawn_pos.y = randf_range(0, screen_size.y)

	return spawn_pos


func reset():
	elapsed_time = 0.0
	time_until_next_spawn = max_spawn_interval
