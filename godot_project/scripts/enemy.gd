extends CharacterBody2D


enum EnemyType {BASIC, DASHER, SPRINTER}


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
var is_dashing: bool = false
var last_direction: Vector2 = Vector2.ZERO
var sprinter_move_away: bool = false

# coll layers
const WALL_LAYER = 1
const PLAYER_LAYER = 2
const ENEMY_LAYER = 3

const DASHER_SPEED: float = 50.0
const DASH_SPEED: float = 200.0

const SPRINTER_SPEED_NORMAL: float = 80.0
const SPRINTER_SPEED_SPRINTING: float = 200.0


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
	# set up sprinter timers
	$SprinterDamageTimer.timeout.connect(sprinter_damage_timer_timeout)
	$SprinterMoveAwayTimer.timeout.connect(sprinter_move_away_timer_timeout)
	$SprinterMoveSlowTimer.timeout.connect(sprinter_move_slow_timer_timeout)
	

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


func _process(delta: float) -> void:
	# animation
	if enemy_type == EnemyType.BASIC:
		$AnimatedSpriteBasic.play()
	elif enemy_type == EnemyType.DASHER:
		$AnimatedSpriteDasher.play()
	elif enemy_type == EnemyType.SPRINTER:
		$AnimatedSpriteSprinter.play()
	

func _physics_process(delta: float):
	# chase player if exists
	if player != null and is_instance_valid(player):
		var direction: Vector2
		# normal behavior
		if is_dashing:
			direction = last_direction
		# sprinter behaviour
		elif enemy_type == EnemyType.SPRINTER and sprinter_move_away:
			direction = (global_position - player.global_position).normalized()
		# dasher behavior
		else:
			direction = (player.global_position - global_position).normalized()

		velocity = direction * speed
		last_direction = direction
	else:
		velocity = Vector2.ZERO

	# flip sprite based on movement direction
	if velocity.x < 0:
		$AnimatedSpriteBasic.flip_h = true
		$AnimatedSpriteDasher.flip_h = true
		$AnimatedSpriteSprinter.flip_h = true
	elif velocity.x >= 0:
		$AnimatedSpriteBasic.flip_h = false
		$AnimatedSpriteDasher.flip_h = false
		$AnimatedSpriteSprinter.flip_h = false


	var distanc_to_player: float = 100000.0 # arbitrary large value
	# sprinter speed adjustment
	if player != null and is_instance_valid(player):
		distanc_to_player = player.global_position.distance_to(global_position)
	if enemy_type == EnemyType.SPRINTER:
		if distanc_to_player < 200 && $SprinterAliveTimer.is_stopped():
			speed = SPRINTER_SPEED_SPRINTING
		else:
			speed = SPRINTER_SPEED_NORMAL


	# move with collision
	move_and_slide()

	# dmg player if touching
	if is_touching_player and player != null and player.has_method("take_damage"):
		player.take_damage(damage_per_second * delta, enemy_type)


func _on_body_entered(body: Node2D):
	if body == player or body.is_in_group("player"):
		is_touching_player = true
		if enemy_type == EnemyType.SPRINTER and $SprinterDamageTimer.is_stopped() and $SprinterMoveAwayTimer.is_stopped() and $SprinterMoveSlowTimer.is_stopped() and sprinter_move_away == false:
			print("start sprinter damage timer")
			$SprinterDamageTimer.start()


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
		speed = DASHER_SPEED
		damage_per_second = 30.0
		$AnimatedSpriteBasic.hide()
		$AnimatedSpriteDasher.show()
		$AnimatedSpriteSprinter.hide()

	elif new_type == 2:
		enemy_type = EnemyType.SPRINTER
		speed = SPRINTER_SPEED_SPRINTING
		damage_per_second = 25.0
		$AnimatedSpriteBasic.hide()
		$AnimatedSpriteDasher.hide()
		$AnimatedSpriteSprinter.show()

# dash behaviour (kinda wonky)
func dash_towards_player():
	if player != null and is_instance_valid(player):
		is_dashing = true
		speed = DASH_SPEED
		GameManager.start_playing_enemy_dash()
		await get_tree().create_timer(dash_duration).timeout
		speed = DASHER_SPEED
		dash_timer.wait_time = dash_cooldown
		is_dashing = false

# sprinter behaviour
func sprinter_damage_timer_timeout():
	sprinter_move_away = true
	$SprinterMoveAwayTimer.start()
	print("moveing away")
func sprinter_move_away_timer_timeout():
	sprinter_move_away = false
	speed = 30
	print("moveing slow")
	$SprinterMoveSlowTimer.start()
func sprinter_move_slow_timer_timeout():
	speed = SPRINTER_SPEED_SPRINTING

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
	var base_points = 100 # TODO: calc based on enemy type

	# Register kill and get combo multiplier
	var combo_data = GameManager.register_kill()
	var multiplier = combo_data.multiplier

	# Calculate final score with multiplier
	var final_points = int(base_points * multiplier)

	# spawn crush effect (score only, no combo text)
	var effect = CRUSH_PARTICLES.instantiate()
	effect.global_position = global_position
	effect.score_value = final_points
	effect.multiplier = 1.0 # Don't show combo text on individual enemies
	get_parent().add_child(effect)

	GameManager.add_score(final_points)

	GameManager.sound_enemy_died()

	# award ult charge to player
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node and player_node.has_method("add_ult_charge"):
		player_node.add_ult_charge(player_node.ult_charge_per_kill)

	# add camera shake on death
	CameraShake.add_trauma(0.5)

	queue_free()
