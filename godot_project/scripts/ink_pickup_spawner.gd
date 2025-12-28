extends Node2D

## Spawns ink pickups at regular intervals within the screen bounds

## Ink pickup scene to spawn
@export var ink_pickup_scene: PackedScene

## Time between spawns (seconds)
@export var spawn_interval: float = 15.0

## Margin from screen edges where pickups can spawn
@export var spawn_margin: float = 40.0

## Reference to the viewport for screen bounds
@export var viewport: SubViewport

## Maximum number of pickups allowed on the map at once
@export var max_pickups: int = 2

# Internal state
var time_until_next_spawn: float = 0.0
var spawn_parent: Node
var active_pickups: Array[Node] = []  # Track spawned pickups


func _ready():
	# find spawn parent (where pickups will be added)
	if viewport:
		spawn_parent = viewport
	else:
		spawn_parent = get_parent()

	# preload pickup scene if not set
	if ink_pickup_scene == null:
		# will be set from the scene editor
		push_warning("InkPickupSpawner: No ink_pickup_scene set!")

	# schedule first spawn
	time_until_next_spawn = spawn_interval


func _process(delta: float):
	# Clean up invalid pickup references
	active_pickups = active_pickups.filter(func(pickup): return is_instance_valid(pickup))

	time_until_next_spawn -= delta

	if time_until_next_spawn <= 0:
		spawn_pickup()
		time_until_next_spawn = spawn_interval


func spawn_pickup():
	if ink_pickup_scene == null or spawn_parent == null:
		return

	# Don't spawn if we're at max capacity
	if active_pickups.size() >= max_pickups:
		return

	var pickup = ink_pickup_scene.instantiate()
	pickup.global_position = get_random_spawn_position()
	spawn_parent.add_child(pickup)
	active_pickups.append(pickup)


func get_random_spawn_position() -> Vector2:
	if viewport == null:
		return Vector2.ZERO

	var screen_size = viewport.size

	# spawn within screen bounds with margin
	var x = randf_range(spawn_margin, screen_size.x - spawn_margin)
	var y = randf_range(spawn_margin, screen_size.y - spawn_margin)

	return Vector2(x, y)


func reset():
	time_until_next_spawn = spawn_interval
	active_pickups.clear()
