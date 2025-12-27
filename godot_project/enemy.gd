extends Area2D

var speed = 400

var is_colliding_with_player = false
var is_colliding_with_wall = false

var collision_normal = Vector2.ZERO

var last_direction = Vector2.ZERO

var collision_body: StaticBody2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("Enemies")

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_colliding_with_player:
		return
	var direction
	if is_colliding_with_wall:
		direction = find_way_around_wall(collision_body)
		position += direction * speed * delta
	else:
		direction = search_player()
	position += direction * speed * delta
	last_direction = direction
	print(direction)

func search_player() -> Vector2:
	var playerPosition = get_node("/root/GameWorld/Player").position
	var directionToPlayer = (playerPosition - position).normalized()
	return directionToPlayer

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		is_colliding_with_player = true
	if body.is_in_group("Walls"):
		body = body as StaticBody2D
		is_colliding_with_wall = true
		collision_body = body
		print(collision_normal)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		is_colliding_with_player = false
	if body.is_in_group("Walls"):
		is_colliding_with_wall = false

func find_way_around_wall(wall: StaticBody2D) -> Vector2:
	if wall == null:
		print("Wall is null")
		return Vector2.ZERO
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, wall.global_position)
	var result = space_state.intersect_ray(query)
	
	if result:
		collision_normal = result.normal
		# Move perpendicular to wall
		# return collision_normal.orthogonal()
	return Vector2.ZERO
