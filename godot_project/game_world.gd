extends Node2D

var wall_scene = preload("res://wall.tscn")


# Called when the node enters the wall_scene tree for the first time.
func _ready() -> void:
	spawn_walls()
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func spawn_walls() -> void:
	var world_size = get_viewport().get_visible_rect().size
	for i in range(7):
		var wall_instance = wall_scene.instantiate()
		var wall_position = Vector2(randi() % int(world_size.x) * 2 - int(world_size.x), randi() % int(world_size.y) * 2 - int(world_size.y))
		var random_number = randi() % 2
		var wall_scale
		if random_number == 0:
			wall_scale = Vector2(randi() % 5 + 1, 0.5)
		else:
			wall_scale = Vector2(0.5, randi() % 5 + 1)

		var wall_transform = Transform2D(0, wall_scale, 0, wall_position)
		wall_instance.transform = wall_transform
		add_child(wall_instance)
