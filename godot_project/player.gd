extends CharacterBody2D


const SPEED = 1000.0

func _ready() -> void:
	add_to_group("Player")
	pass


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("left", "right", "up", "down").normalized()
	velocity = direction * SPEED

	move_and_slide()
	check_collisions()

	
func check_collisions() -> void:
	for i in get_slide_collision_count():
		var collisionObject = get_slide_collision(i).get_collider()
		if collisionObject.is_in_group("Walls"):
			pass
		if collisionObject.is_in_group("Enemies"):
			# collisionObject.is_colliding_with_player = true
			pass
	pass
