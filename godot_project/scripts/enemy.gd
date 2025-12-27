extends CharacterBody2D

## speed in px/second
@export var speed: float = 75.0

## damage dealt per second when overlapping
@export var damage_per_second: float = 18.0

## ref to player node (autofound if not set)
@export var player: CharacterBody2D

# player overlap detection (via Area2D child)
var player_detection_area: Area2D
var is_touching_player: bool = false

# coll layers
const WALL_LAYER = 1
const PLAYER_LAYER = 2
const ENEMY_LAYER = 3


func _ready():
	# set up coll layers
	collision_layer = 1 << (ENEMY_LAYER - 1)  # L3
	collision_mask = 1 << (WALL_LAYER - 1)  # coll with walls (L1)

	# add to enemies group for crunch signal
	add_to_group("enemies")

	# set up player detection area
	player_detection_area = get_node_or_null("DetectionArea")
	if player_detection_area and player_detection_area is Area2D:
		player_detection_area.collision_layer = 1 << (ENEMY_LAYER - 1)  # L3
		player_detection_area.collision_mask = 1 << (PLAYER_LAYER - 1)  # detect player on L2

		player_detection_area.body_entered.connect(_on_body_entered)
		player_detection_area.body_exited.connect(_on_body_exited)
	else:
		push_warning("Enemy: No DetectionArea child found, no player damage possible")

	# find player if not assigned
	if player == null:
		player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float):
	# chase player if exists
	if player != null and is_instance_valid(player):
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO

	# move with collision
	move_and_slide()

	# dmg player if touching
	if is_touching_player and player != null and player.has_method("take_damage"):
		player.take_damage(damage_per_second * delta)


func _on_body_entered(body: Node2D):
	if body == player or body.is_in_group("player"):
		is_touching_player = true


func _on_body_exited(body: Node2D):
	if body == player or body.is_in_group("player"):
		is_touching_player = false


## called by PaintCollisionManager when new collision geometry is created
func _on_new_collision_created(new_polygons: Array[PackedVector2Array]):
	# check if this enemy is inside any of the new collision polygons
	for polygon in new_polygons:
		if is_point_in_polygon(global_position, polygon):
			crunch()
			return


func is_point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	return Geometry2D.is_point_in_polygon(point, polygon)


func crunch():
	# TODO: add explo particles, score increment etc..
	queue_free()
