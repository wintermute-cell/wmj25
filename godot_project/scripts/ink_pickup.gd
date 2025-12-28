extends Area2D

## Amount of ink to restore when picked up
@export var ink_amount: float = 30.0

## Visual settings
@export var pickup_color: Color = Color(0.8, 0.8, 0.8, 1.0)
@export var pickup_radius: float = 8.0
@export var pulse_speed: float = 2.0
@export var pulse_amount: float = 0.2

## Spawn animation settings
@export var spawn_slide_distance: float = 20.0
@export var spawn_duration: float = 0.4
@export var smoke_animation_duration: float = 0.5

var time_alive: float = 0.0
var is_spawning: bool = true

# collision layers
const PICKUP_LAYER = 5
const PLAYER_LAYER = 2

# node references
@onready var pickup_visual: Node2D = $PickupVisual
@onready var smoke_sprite: Sprite2D = $SmokeSprite


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

	# start spawn animation
	_play_spawn_animation()


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


func _play_spawn_animation():
	# disable collision during spawn
	monitoring = false
	monitorable = false

	# set initial state - pickup starts above and transparent
	pickup_visual.position.y = -spawn_slide_distance
	pickup_visual.modulate.a = 0.0

	# smoke sprite starts invisible
	smoke_sprite.modulate.a = 0.0
	smoke_sprite.frame = 0

	# create tween for pickup slide and fade
	var tween = create_tween()
	tween.set_parallel(true)

	# slide down
	tween.tween_property(pickup_visual, "position:y", 0.0, spawn_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# fade in
	tween.tween_property(pickup_visual, "modulate:a", 1.0, spawn_duration).set_ease(Tween.EASE_IN)

	# animate smoke frames
	tween.tween_method(_animate_smoke_frame, 0, 12, smoke_animation_duration).set_ease(Tween.EASE_OUT)

	# fade out smoke
	tween.tween_property(smoke_sprite, "modulate:a", 1.0, smoke_animation_duration * 0.2).set_ease(Tween.EASE_IN)
	tween.chain().tween_property(smoke_sprite, "modulate:a", 0.0, smoke_animation_duration * 0.8).set_ease(Tween.EASE_OUT)

	# when animation completes, enable collision and mark as no longer spawning
	tween.chain().tween_callback(_on_spawn_complete)


func _animate_smoke_frame(frame_float: float):
	smoke_sprite.frame = int(frame_float)


func _on_spawn_complete():
	is_spawning = false
	monitoring = true
	monitorable = true


func _on_body_entered(body: Node2D):
	# don't allow pickup during spawn animation
	if is_spawning:
		return

	if body.is_in_group("player"):
		# find the brush in the scene and add ink to it
		var brush = get_tree().get_first_node_in_group("brush")
		if brush and brush.has_method("add_ink"):
			brush.add_ink(ink_amount)
			GameManager.start_playing_ink_pickup()
			queue_free()
