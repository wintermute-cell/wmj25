extends Node2D

# Brush drawing system for calligraphy-style ink that dries away

# Ink point data structure
class InkPoint:
	var position: Vector2
	var size: float
	var creation_time: float
	var max_lifetime: float = 2.0  # Seconds until fully dried

	func _init(pos: Vector2, sz: float, time: float):
		position = pos
		size = sz
		creation_time = time

	func get_current_size(current_time: float) -> float:
		var age = current_time - creation_time
		var life_ratio = 1.0 - (age / max_lifetime)
		return size * max(0.0, life_ratio)

	func is_dried(current_time: float) -> bool:
		return (current_time - creation_time) >= max_lifetime

# Brush settings
@export_group("Basic Brush")
## Minimum brush stroke size in pixels
@export var brush_min_size: float = 2.0
## Maximum brush stroke size in pixels
@export var brush_max_size: float = 8.0
## Distance between ink points. Lower values = smoother strokes with more points, higher values = faster but choppier
@export_range(0.1, 5.0, 0.1) var point_spacing: float = 0.8
## Color of the ink
@export var ink_color: Color = Color.BLACK

# Calligraphy pen settings
@export_group("Calligraphy Effect")
## Maximum speed value (in pixels/sec) that maps to 1.0 on the speed_to_size_curve. Speeds above this are clamped.
@export_range(500.0, 3000.0, 50.0) var max_speed_for_curve: float = 1500.0
## Minimum thickness multiplier when pen is perpendicular to movement direction
@export_range(0.0, 1.0, 0.05) var angle_variation_min: float = 0.5
## Maximum thickness multiplier when pen is parallel to movement direction
@export_range(0.0, 1.0, 0.05) var angle_variation_max: float = 1.0
## Temporal smoothing factor for size transitions. Lower = smoother but more lag, higher = more responsive but jumpier
@export_range(0.0, 1.0, 0.05) var size_smoothing: float = 0.3

## Curve that maps speed to brush size. X-axis: 0 (stopped) to 1 (max speed). Y-axis: 0 (min size) to 1 (max size)
@export var speed_to_size_curve: Curve

# Splotching settings
@export_group("Splotching")
## Legacy threshold - not used when speed_to_splotch_curve is set
@export var slow_speed_threshold: float = 400.0
## Legacy threshold - not used when speed_to_splotch_curve is set
@export var medium_speed_threshold: float = 1000.0
## Maximum number of splotches that can be added per point (0 = no splotches)
@export_range(0, 5, 1) var max_splotches_per_point: int = 2
## Minimum spread distance for splotches (as multiplier of base brush size)
@export_range(0.0, 2.0, 0.1) var splotch_min_spread: float = 0.4
## Maximum spread distance for splotches (as multiplier of base brush size)
@export_range(0.0, 2.0, 0.1) var splotch_max_spread: float = 0.8
## Minimum size for splotch particles (as multiplier of current brush size)
@export_range(0.0, 1.0, 0.05) var splotch_size_min: float = 0.6
## Maximum size for splotch particles (as multiplier of current brush size)
@export_range(0.0, 1.0, 0.05) var splotch_size_max: float = 0.95

## Curve that maps speed to splotch probability. X-axis: 0 (stopped) to 1 (max speed). Y-axis: 0 (no splotches) to 1 (always splotch)
@export var speed_to_splotch_curve: Curve

# Pooling settings
@export_group("Pooling")
## Speed threshold below which ink pooling can occur (in pixels/sec)
@export_range(10.0, 200.0, 5.0) var pool_speed_threshold: float = 50.0
## Maximum number of pools that can be added per point (0 = no pooling)
@export_range(0, 5, 1) var max_pools_per_point: int = 1
## How far pooling spreads from the stroke (as multiplier of base brush size)
@export_range(0.0, 2.0, 0.1) var pool_spread_multiplier: float = 0.8
## Minimum size for pool particles (as multiplier of current brush size)
@export_range(0.0, 1.0, 0.05) var pool_size_min: float = 0.5
## Maximum size for pool particles (as multiplier of current brush size)
@export_range(0.0, 1.0, 0.05) var pool_size_max: float = 0.9

## Curve that maps speed to pool probability. X-axis: 0 (stopped) to 1 (at pool_speed_threshold). Y-axis: 0 (no pools) to 1 (always pool)
@export var speed_to_pool_curve: Curve

# Lifting settings
@export_group("Lifting")
## Speed threshold below which lifting creates pooling effect (in pixels/sec)
@export_range(50.0, 500.0, 10.0) var lift_slow_threshold: float = 150.0
## Number of pool particles created when lifting slowly
@export_range(0, 10, 1) var lift_pool_count: int = 3
## Size multiplier for the main blob when lifting slowly
@export_range(1.0, 2.0, 0.1) var lift_size_multiplier: float = 1.3
## Spread distance for lift pools (as multiplier of base brush size)
@export_range(0.0, 2.0, 0.1) var lift_pool_spread: float = 0.5

# Stroke state
var ink_points: Array[InkPoint] = []
var is_drawing: bool = false
var last_draw_position: Vector2 = Vector2.ZERO
var last_velocity: Vector2 = Vector2.ZERO
var current_time: float = 0.0
var stroke_start_time: float = 0.0
var accumulated_distance: float = 0.0
var smoothed_angle_variation: float = 1.0  # Smoothed value to prevent jumps

func _ready():
	# Create default curves if none are set
	if speed_to_size_curve == null:
		speed_to_size_curve = Curve.new()
		# Default curve: mostly constant thickness that gradually decreases at high speed
		speed_to_size_curve.add_point(Vector2(0.0, 1.0))    # Stopped = max size
		speed_to_size_curve.add_point(Vector2(0.5, 0.95))   # Medium speed = slightly smaller
		speed_to_size_curve.add_point(Vector2(0.8, 0.85))   # Fast = noticeably smaller
		speed_to_size_curve.add_point(Vector2(1.0, 0.7))    # Very fast = thinner

	if speed_to_splotch_curve == null:
		speed_to_splotch_curve = Curve.new()
		# Default: high splotch probability when slow, low when fast
		speed_to_splotch_curve.add_point(Vector2(0.0, 1.0))    # Stopped = 100% splotch
		speed_to_splotch_curve.add_point(Vector2(0.3, 0.7))    # Slow = 70% splotch
		speed_to_splotch_curve.add_point(Vector2(0.6, 0.3))    # Medium = 30% splotch
		speed_to_splotch_curve.add_point(Vector2(1.0, 0.0))    # Fast = no splotch

	if speed_to_pool_curve == null:
		speed_to_pool_curve = Curve.new()
		# Default: high pool probability when nearly stopped
		speed_to_pool_curve.add_point(Vector2(0.0, 0.9))    # Stopped = 90% pool
		speed_to_pool_curve.add_point(Vector2(0.5, 0.5))    # Half speed = 50% pool
		speed_to_pool_curve.add_point(Vector2(1.0, 0.1))    # At threshold = 10% pool

func _process(delta: float):
	current_time += delta

	# Remove dried ink points
	ink_points = ink_points.filter(func(point): return not point.is_dried(current_time))

	# Redraw
	queue_redraw()

func _input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start new stroke
				is_drawing = true
				last_draw_position = event.position
				last_velocity = Vector2.ZERO
				stroke_start_time = current_time
				accumulated_distance = 0.0
				smoothed_angle_variation = 1.0
				# Add initial touch - small and clean
				add_ink_splatter(event.position, Vector2.ZERO, true)
			else:
				# End stroke - lift the brush
				if is_drawing:
					add_ink_splatter(event.position, last_velocity, false, true)
				is_drawing = false

	elif event is InputEventMouseMotion:
		if is_drawing:
			var current_position = event.position
			var velocity = event.velocity

			# Interpolate points between last and current position
			var distance = last_draw_position.distance_to(current_position)
			accumulated_distance += distance
			var num_points = int(distance / point_spacing)

			if num_points > 0:
				for i in range(num_points + 1):
					var t = float(i) / float(num_points) if num_points > 0 else 1.0
					var interp_pos = last_draw_position.lerp(current_position, t)
					var interp_vel = last_velocity.lerp(velocity, t)
					add_ink_splatter(interp_pos, interp_vel)

			last_draw_position = current_position
			last_velocity = velocity

func add_ink_splatter(pos: Vector2, velocity: Vector2, is_stroke_start: bool = false, is_lifting: bool = false):
	# Calligraphy effect: size varies with speed using curve
	var speed = velocity.length()

	# Normalize speed to 0-1 range for curve lookup
	var speed_normalized = clamp(speed / max_speed_for_curve, 0.0, 1.0)

	# Sample curve to get size multiplier (0 = min size, 1 = max size)
	var size_multiplier = speed_to_size_curve.sample(speed_normalized)

	# Perpendicular to movement direction gets thicker (calligraphy pen effect)
	var target_angle_variation = 1.0
	if speed > 10.0:
		# Calculate brush orientation based on velocity
		target_angle_variation = abs(sin(velocity.angle()))
		# Map to custom range
		target_angle_variation = angle_variation_min + target_angle_variation * (angle_variation_max - angle_variation_min)

	# Smooth the angle variation to prevent jumps (temporal smoothing)
	smoothed_angle_variation = lerp(smoothed_angle_variation, target_angle_variation, size_smoothing)

	# Calculate final size using curve
	var base_size = lerp(brush_min_size, brush_max_size, size_multiplier)
	var final_size = base_size * smoothed_angle_variation

	# Special handling for stroke start
	if is_stroke_start:
		# Initial touch is small and controlled, no splotching
		final_size = brush_min_size
		var point = InkPoint.new(pos, final_size, current_time)
		ink_points.append(point)
		return

	# Special handling for lifting
	if is_lifting:
		# Lifting behavior depends on speed
		if speed < lift_slow_threshold:
			# Slow lift = more pooling/blob as pen lingers
			var lift_size = base_size * lift_size_multiplier
			var point = InkPoint.new(pos, lift_size, current_time)
			ink_points.append(point)
			# Add a small pool that scales with brush size
			var pool_spread = base_size * lift_pool_spread
			for i in range(lift_pool_count):
				var offset = Vector2(randf_range(-pool_spread, pool_spread), randf_range(-pool_spread, pool_spread))
				var pool = InkPoint.new(pos + offset, lift_size * randf_range(0.7, 1.0), current_time)
				ink_points.append(pool)
		else:
			# Fast lift = clean, minimal extra ink
			var point = InkPoint.new(pos, final_size, current_time)
			ink_points.append(point)
		return

	# Add main point
	var point = InkPoint.new(pos, final_size, current_time)
	ink_points.append(point)

	# Splotching: use curve to determine probability based on speed
	if max_splotches_per_point > 0:
		var splotch_probability = speed_to_splotch_curve.sample(speed_normalized)

		# Determine number of splotches based on probability
		var num_splotches = 0
		for i in range(max_splotches_per_point):
			# Each additional splotch has progressively lower chance
			var threshold = splotch_probability * pow(0.5, i)
			if randf() < threshold:
				num_splotches += 1
			else:
				break

		for i in range(num_splotches):
			var splotch_spread = base_size * randf_range(splotch_min_spread, splotch_max_spread)
			var offset = Vector2(randf_range(-splotch_spread, splotch_spread), randf_range(-splotch_spread, splotch_spread))
			var splotch_size = final_size * randf_range(splotch_size_min, splotch_size_max)
			var splotch = InkPoint.new(pos + offset, splotch_size, current_time)
			ink_points.append(splotch)

	# Pooling when nearly stationary
	if speed < pool_speed_threshold and max_pools_per_point > 0:
		# Use curve to determine pool probability based on speed
		var pool_speed_normalized = clamp(speed / pool_speed_threshold, 0.0, 1.0)
		var pool_probability = speed_to_pool_curve.sample(pool_speed_normalized)

		# Determine number of pools based on probability
		var num_pools = 0
		for i in range(max_pools_per_point):
			# Each additional pool has progressively lower chance
			var threshold = pool_probability * pow(0.6, i)
			if randf() < threshold:
				num_pools += 1
			else:
				break

		for i in range(num_pools):
			var pool_spread = base_size * pool_spread_multiplier
			var pool_offset = Vector2(randf_range(-pool_spread, pool_spread), randf_range(-pool_spread, pool_spread))
			var pool_size = final_size * randf_range(pool_size_min, pool_size_max)
			var pool = InkPoint.new(pos + pool_offset, pool_size, current_time)
			ink_points.append(pool)

func _draw():
	# Draw all ink points
	for point in ink_points:
		var current_size = point.get_current_size(current_time)
		if current_size > 0.1:  # Only draw if visible
			# Calculate alpha based on drying
			var age = current_time - point.creation_time
			var life_ratio = 1.0 - (age / point.max_lifetime)
			var alpha = max(0.0, life_ratio)

			var color_with_alpha = Color(ink_color.r, ink_color.g, ink_color.b, alpha)

			# Draw as filled circle for pixelart look
			draw_circle(point.position, current_size, color_with_alpha)
