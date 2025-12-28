extends Control

@export var bar_width: float = 200.0
@export var bar_height: float = 20.0
@export var bar_color: Color = Color(0.2, 0.2, 0.2, 0.8)  # Dark gray background
@export var ink_color: Color = Color(0.9, 0.9, 0.9, 1.0)  # White ink fill
@export var border_color: Color = Color(0.1, 0.1, 0.1, 1.0)  # Black border
@export var border_width: float = 2.0

var current_ink: float = 100.0
var max_ink: float = 100.0


func _ready():
	custom_minimum_size = Vector2(bar_width, bar_height)
	update_ink(100.0, 100.0)


func update_ink(new_ink: float, new_max_ink: float):
	current_ink = clamp(new_ink, 0.0, new_max_ink)
	max_ink = new_max_ink
	queue_redraw()


func _draw():
	var ink_ratio = current_ink / max_ink if max_ink > 0 else 0.0

	draw_rect(Rect2(Vector2.ZERO, Vector2(bar_width, bar_height)), bar_color)

	# ink fill
	var fill_width = bar_width * ink_ratio
	if fill_width > 0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(fill_width, bar_height)), ink_color)

	# border
	draw_rect(Rect2(Vector2.ZERO, Vector2(bar_width, bar_height)), border_color, false, border_width)
