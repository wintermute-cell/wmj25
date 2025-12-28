extends Area2D

## Amount of ink to restore when picked up
@export var ink_amount: float = 30.0

## Visual settings
@export var pickup_color: Color = Color(0.8, 0.8, 0.8, 1.0)
@export var pickup_radius: float = 8.0
@export var pulse_speed: float = 2.0
@export var pulse_amount: float = 0.2

var time_alive: float = 0.0

# collision layers
const PICKUP_LAYER = 5
const PLAYER_LAYER = 2


func _ready():
	# setup collision layers
	collision_layer = 1 << (PICKUP_LAYER - 1) # Layer 5
	collision_mask = 1 << (PLAYER_LAYER - 1) # DeTEct player on Layer 2

	# connect to area entered signal for player detection
	body_entered.connect(_on_body_entered)

	# add a collision shape if not already present
	if get_child_count() == 0:
		var collision_shape = CollisionShape2D.new()
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = pickup_radius
		collision_shape.shape = circle_shape
		add_child(collision_shape)


func _process(delta: float):
	time_alive += delta
	queue_redraw()


func _draw():
	# pulsing effect
	var pulse = 1.0 + sin(time_alive * pulse_speed) * pulse_amount
	var current_radius = pickup_radius * pulse

	# draw outer glow
	draw_circle(Vector2.ZERO, current_radius + 2.0, Color(pickup_color, 0.3))

	# draw main circle
	draw_circle(Vector2.ZERO, current_radius, pickup_color)

	# draw inner highlight
	draw_circle(Vector2(-2, -2), current_radius * 0.4, Color(1, 1, 1, 0.6))


func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		# find the brush in the scene and add ink to it
		var brush = get_tree().get_first_node_in_group("brush")
		if brush and brush.has_method("add_ink"):
			brush.add_ink(ink_amount)
			GameManager.start_playing_ink_pickup()
			queue_free()
