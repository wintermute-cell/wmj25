extends Node

## Trauma-based camera shake system that can be triggered from anywhere
## Usage: CameraShake.add_trauma(0.3) to add shake

## Maximum rotation in degrees
@export var max_angle: float = 15.0

## Maximum offset in pixels
@export var max_offset: Vector2 = Vector2(100, 75)

## How fast trauma recovers (0-1 per second)
@export var trauma_decay_rate: float = 1.0

## Shake exponent (2 or 3 recommended). Higher = more subtle at low trauma
@export var trauma_power: float = 2.0

## Current trauma level (0-1)
var trauma: float = 0.0

## Reference to the active camera we're shaking
var active_camera: Camera2D = null

## Noise generators for smooth shake
var noise_angle: FastNoiseLite
var noise_offset_x: FastNoiseLite
var noise_offset_y: FastNoiseLite

## Time accumulator for noise sampling
var noise_time: float = 0.0

## Speed of noise sampling
var noise_speed: float = 50.0


func _ready():
	# Initialize noise generators with different seeds
	noise_angle = FastNoiseLite.new()
	noise_angle.seed = randi()
	noise_angle.frequency = 0.5

	noise_offset_x = FastNoiseLite.new()
	noise_offset_x.seed = randi()
	noise_offset_x.frequency = 0.5

	noise_offset_y = FastNoiseLite.new()
	noise_offset_y.seed = randi()
	noise_offset_y.frequency = 0.5


func _process(delta: float):
	# Decay trauma linearly
	if trauma > 0:
		trauma = max(trauma - trauma_decay_rate * delta, 0)

	# Apply shake if we have an active camera
	if active_camera and trauma > 0:
		apply_shake()
	elif active_camera:
		# Reset camera when no trauma
		reset_camera()


func apply_shake():
	# Calculate shake intensity (trauma^power)
	var shake = pow(trauma, trauma_power)

	# Sample noise using time (compatible with pause/slow-motion)
	# Using get_process_delta_time() ensures compatibility with Engine.time_scale
	noise_time += get_process_delta_time() * noise_speed

	# Get noise values (-1 to 1)
	var angle_noise = noise_angle.get_noise_1d(noise_time)
	var offset_x_noise = noise_offset_x.get_noise_1d(noise_time)
	var offset_y_noise = noise_offset_y.get_noise_1d(noise_time)

	# Apply shake formula
	var angle = max_angle * shake * angle_noise
	var offset_x = max_offset.x * shake * offset_x_noise
	var offset_y = max_offset.y * shake * offset_y_noise

	# Apply to camera (preserving base camera position)
	active_camera.rotation_degrees = angle
	active_camera.offset = Vector2(offset_x, offset_y)


func reset_camera():
	if active_camera:
		active_camera.rotation_degrees = 0
		active_camera.offset = Vector2.ZERO


## Add trauma to the shake system (0-1 scale)
func add_trauma(amount: float):
	trauma = clamp(trauma + amount, 0.0, 1.0)


## Set the camera that should be shaken
func set_camera(camera: Camera2D):
	active_camera = camera
	if active_camera:
		reset_camera()


## Clear current camera reference
func clear_camera():
	if active_camera:
		reset_camera()
	active_camera = null
