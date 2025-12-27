extends CharacterBody2D

var speed = 400
var is_colliding_with_player = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("Enemies")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_colliding_with_player:
		return
	velocity = search_player() * speed
	move_and_slide()


func search_player() -> Vector2:
	var playerPosition = get_node("/root/GameWorld/Player").position
	var directionToPlayer = (playerPosition - position).normalized()
	return directionToPlayer
