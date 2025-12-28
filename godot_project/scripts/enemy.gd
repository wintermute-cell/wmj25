extends CharacterBody2D


enum EnemyType {BASIC, DASHER}


# preload particle effect
const CRUSH_PARTICLES = preload("res://enemy_crush_particles.tscn")

## speed in px/second
@export var speed: float = 75.0
@export var enemy_type: int = EnemyType.BASIC
## damage dealt per second when overlapping
@export var damage_per_second: float = 18.0

## crush margin as a percentage of collision radius (0.3 = 30% extra range)
@export_range(0.0, 2.0, 0.1) var crush_margin_multiplier: float = 0.3

## ref to player node (autofound if not set)
@export var player: CharacterBody2D


# player overlap detection (via Area2D child)
var player_detection_area: Area2D
var is_touching_player: bool = false

@onready var dash_timer: Timer = $DashTimer
var dash_cooldown: float = 5.0
var dash_duration: float = 0.5
var dash_speed: float = 200.0
var dasher_base_speed: float = 50.0
var is_dashing: bool = false
var last_direction: Vector2 = Vector2.ZERO

# coll layers
const WALL_LAYER = 1
const PLAYER_LAYER = 2
const ENEMY_LAYER = 3


func _ready():
	# set up coll layers
	collision_layer = 1 << (ENEMY_LAYER - 1) # L3
	collision_mask = 1 << (WALL_LAYER - 1) # coll with walls (L1)

	# add to enemies group for crunch signal
	add_to_group("enemies")


	# set up dash timer for dasher enemies
	dash_timer.connect("timeout", dash_towards_player)
	if (enemy_type == EnemyType.DASHER):
		dash_timer.wait_time = dash_cooldown
		dash_timer.one_shot = false
		dash_timer.start(dash_cooldown)


	# set up player detection area
	player_detection_area = get_node_or_null("DetectionArea")
	if player_detection_area and player_detection_area is Area2D:
		player_detection_area.collision_layer = 1 << (ENEMY_LAYER - 1) # L3
		player_detection_area.collision_mask = 1 << (PLAYER_LAYER - 1) # detect player on L2

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
		var direction: Vector2
		if not is_dashing:
			direction = (player.global_position - global_position).normalized()
		else:
			direction = last_direction
		velocity = direction * speed
		last_direction = direction
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
	# check if this enemy overlaps with any of the new collision polygons
	for polygon in new_polygons:
		if does_enemy_overlap_polygon(polygon):
			crunch()
			return


func change_enemy_type(new_type: int):
	if new_type == 1:
		enemy_type = EnemyType.DASHER
		speed = 50.0
		damage_per_second = 30.0
		scale = Vector2.ONE * 2.0


func dash_towards_player():
	if player != null and is_instance_valid(player):
		is_dashing = true
		speed = dash_speed
		GameManager.start_playing_enemy_dash()
		await get_tree().create_timer(dash_duration).timeout
		speed = dasher_base_speed
		dash_timer.wait_time = dash_cooldown
		is_dashing = false


func does_enemy_overlap_polygon(polygon: PackedVector2Array) -> bool:
	# get enemy's collision shape radius
	var collision_shape = get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		# fallback to point check if no collision shape
		return Geometry2D.is_point_in_polygon(global_position, polygon)

	var radius = 0.0
	if collision_shape.shape is CircleShape2D:
		radius = collision_shape.shape.radius
	elif collision_shape.shape is CapsuleShape2D:
		radius = collision_shape.shape.radius
	else:
		# unsupported shape, use point check
		return Geometry2D.is_point_in_polygon(global_position, polygon)

	# add margin to make crushing more forgiving
	var crush_margin = radius * crush_margin_multiplier

	# check if center is inside polygon
	if Geometry2D.is_point_in_polygon(global_position, polygon):
		return true

	# check if enemy circle overlaps with polygon
	# method: check if any polygon edge is within (radius + margin) of enemy center
	for i in range(polygon.size()):
		var p1 = polygon[i]
		var p2 = polygon[(i + 1) % polygon.size()]

		# find closest point on edge to enemy center
		var closest = Geometry2D.get_closest_point_to_segment(global_position, p1, p2)
		var distance = global_position.distance_to(closest)

		# if edge is close enough, enemy overlaps
		if distance <= (radius + crush_margin):
			return true

	return false


func crunch():
	var points = 100 # TODO: calc based on enemy type

	# spawn crush effect
	var effect = CRUSH_PARTICLES.instantiate()
	effect.global_position = global_position
	effect.score_value = points
	get_parent().add_child(effect)

	GameManager.add_score(points)

	GameManager.sound_enemy_died()
	# add camera shake on death
	CameraShake.add_trauma(0.3)

	queue_free()
