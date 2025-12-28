extends Control

@export var lantern_count: int = 5
@export var lantern_spacing: float = 40.0
@export var arc_height: float = 20.0  # How much the lanterns sag in the middle
@export var flicker_enabled: bool = true
@export var flicker_speed: float = 0.15  # Time between flicker frames

var lantern_texture: Texture2D = preload("res://sprites/lantern.png")
var lanterns: Array[Sprite2D] = []
var current_health: float = 100.0
var max_health: float = 100.0

var flicker_timer: float = 0.0
var current_flicker_frame: int = 0


func _ready():
	_create_lanterns()
	update_health(100.0, 100.0)


func _process(delta):
	if flicker_enabled:
		flicker_timer += delta
		if flicker_timer >= flicker_speed:
			flicker_timer = 0.0
			current_flicker_frame = 1 - current_flicker_frame  # Toggle between 0 and 1
			_update_flicker()


func _create_lanterns():
	# clear existing lanterns
	for lantern in lanterns:
		if lantern:
			lantern.queue_free()
	lanterns.clear()

	# calc total width
	var total_width = (lantern_count - 1) * lantern_spacing
	var start_x = -total_width / 2.0

	# create each lantern
	for i in range(lantern_count):
		var lantern = Sprite2D.new()
		lantern.texture = lantern_texture
		lantern.hframes = 2  # 2 cols (anim frames)
		lantern.vframes = 6  # 6 rows (health states)

		# position calculation with hanging arc
		var t = float(i) / float(lantern_count - 1) if lantern_count > 1 else 0.5  # normalized position 0-1
		var x_pos = start_x + i * lantern_spacing

		# parabolic: highest at edges (0 and 1), lowest in middle (0.5)
		var y_offset = 4 * arc_height * t * (1 - t)

		lantern.position = Vector2(x_pos, y_offset)

		lantern.frame = 0

		add_child(lantern)
		lanterns.append(lantern)


func update_health(new_health: float, new_max_health: float):
	current_health = clamp(new_health, 0.0, new_max_health)
	max_health = new_max_health

	var health_per_lantern = max_health / float(lantern_count)

	for i in range(lantern_count):
		if i >= lanterns.size():
			continue

		var lantern = lanterns[i]

		var lantern_min_health = i * health_per_lantern
		var lantern_max_health = (i + 1) * health_per_lantern

		var lantern_health_ratio: float

		if current_health >= lantern_max_health:
			lantern_health_ratio = 1.0
		elif current_health <= lantern_min_health:
			lantern_health_ratio = 0.0
		else:
			lantern_health_ratio = (current_health - lantern_min_health) / health_per_lantern

		var frame_row: int
		if lantern_health_ratio >= 1.0:
			frame_row = 0
		elif lantern_health_ratio >= 0.8:
			frame_row = 1
		elif lantern_health_ratio >= 0.6:
			frame_row = 2
		elif lantern_health_ratio >= 0.4:
			frame_row = 3
		elif lantern_health_ratio >= 0.2:
			frame_row = 4
		else:
			frame_row = 5  # broken

		lantern.frame = current_flicker_frame + frame_row * 2


func _update_flicker():
	update_health(current_health, max_health)
