extends Control

@export var ink_levels: int = 15  # Number of ink level frames
@export var warning_blink_speed: float = 0.3  # Time between warning blink frames
@export var splash_frame_duration: float = 0.1  # Duration of each splash animation frame
@export var splash_total_duration: float = 1.0  # How long to show splash animation in seconds
@export var ink_pickup_threshold: float = 5.0  # Minimum ink increase to trigger splash animation

@onready var ink_sprite: Sprite2D = $InkSprite
@onready var warning_sprite: Sprite2D = $WarningSprite
@onready var splash_sprite: Sprite2D = $SplashSprite

var current_ink: float = 100.0
var max_ink: float = 100.0
var previous_ink: float = 100.0

var warning_blink_timer: float = 0.0
var current_warning_frame: int = 0

var is_showing_splash: bool = false
var splash_timer: float = 0.0
var splash_elapsed: float = 0.0  # Total time splash has been showing
var current_splash_frame: int = 0


func _ready():
	# Hide warning and splash sprites initially
	if warning_sprite:
		warning_sprite.visible = false
	if splash_sprite:
		splash_sprite.visible = false

	update_ink(100.0, 100.0)


func _process(delta):
	# Always update the ink level display (unless showing warning)
	if current_ink > max_ink * 0.1 or is_showing_splash:
		_update_ink_level()

	# Handle warning blink when ink is below 10%
	if current_ink <= max_ink * 0.1 and not is_showing_splash:
		warning_blink_timer += delta
		if warning_blink_timer >= warning_blink_speed:
			warning_blink_timer = 0.0
			current_warning_frame = 1 - current_warning_frame  # Toggle between 0 and 1
			_update_warning_blink()

	# Handle splash animation (loops for a limited duration)
	if is_showing_splash:
		splash_elapsed += delta
		splash_timer += delta

		# Check if splash duration has expired
		if splash_elapsed >= splash_total_duration:
			stop_splash_animation()
		else:
			# Animate through frames
			if splash_timer >= splash_frame_duration:
				splash_timer = 0.0
				current_splash_frame = (current_splash_frame + 1) % 3  # Loop through 0, 1, 2
				_update_splash_frame()


func update_ink(new_ink: float, new_max_ink: float):
	previous_ink = current_ink
	current_ink = clamp(new_ink, 0.0, new_max_ink)
	max_ink = new_max_ink

	# Check if ink increased significantly (pickup collected)
	var ink_increase = current_ink - previous_ink
	if ink_increase >= ink_pickup_threshold:
		_start_splash_animation()

	# Always update the ink level display
	_update_ink_level()


func _update_ink_level():
	if not ink_sprite:
		return

	# Show ink sprite (unless warning is active)
	if current_ink > max_ink * 0.1:
		ink_sprite.visible = true
		if warning_sprite:
			warning_sprite.visible = false

	# Calculate which frame to show based on ink ratio
	var ink_ratio = current_ink / max_ink if max_ink > 0 else 0.0

	# Map ratio to frame index (inverted since frames descend)
	# 1.0 = frame 0 (full), 0.0 = frame 14 (empty)
	var frame_index = int((1.0 - ink_ratio) * (ink_levels - 1))
	frame_index = clamp(frame_index, 0, ink_levels - 1)

	ink_sprite.frame = frame_index


func _update_warning_blink():
	if not warning_sprite:
		return

	# Keep ink sprite visible, show warning sprite on top
	if ink_sprite:
		ink_sprite.visible = true
	warning_sprite.visible = true

	warning_sprite.frame = current_warning_frame


func _start_splash_animation():
	is_showing_splash = true
	splash_timer = 0.0
	splash_elapsed = 0.0  # Reset the total elapsed time
	current_splash_frame = 0
	if splash_sprite:
		splash_sprite.visible = true


func stop_splash_animation():
	is_showing_splash = false
	if splash_sprite:
		splash_sprite.visible = false


func _update_splash_frame():
	if not splash_sprite:
		return

	# Splash overlays the ink sprite (don't hide anything)
	splash_sprite.frame = current_splash_frame
