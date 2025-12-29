extends Node2D

# 3 types of particles
# 1. main stroke, center line
# 2. splotches, random particles around stroke
# 3. pools, particles when moving very slowly
# 4. lift pools, particles when releasing brush slowly


class InkPoint:
	var position: Vector2
	var size: float
	var creation_time: float
	var max_lifetime: float = 2.0 # seconds until fully dried
	var is_main_stroke: bool = true # false for splotches/pools
	var rotation: float = 0.0 # rotation in radians

	func _init(
		pos: Vector2,
		sz: float,
		time: float,
		lifetime: float = 2.0,
		main_stroke: bool = true,
		rot: float = 0.0
	):
		position = pos
		size = sz
		creation_time = time
		max_lifetime = lifetime
		is_main_stroke = main_stroke
		rotation = rot

	func get_current_size(current_time: float) -> float:
		var age = current_time - creation_time
		var life_ratio = 1.0 - (age / max_lifetime)
		return size * max(0.0, life_ratio)

	func is_dried(current_time: float) -> bool:
		return (current_time - creation_time) >= max_lifetime


# brush settings
@export_group("Basic Brush")
## Minimum brush stroke size in pixels
@export var brush_min_size: float = 2.0
## Maximum brush stroke size in pixels
@export var brush_max_size: float = 6.0
## Distance between ink points. Lower values = smoother strokes with more points, higher values = faster but choppier
@export_range(0.1, 5.0, 0.1) var point_spacing: float = 1.2
## Color of the ink
@export var ink_color: Color = Color.BLACK
## Optional texture for main brush stroke. If not set, draws circles. Should be white on transparent background
@export var brush_texture: Texture2D
## Optional texture for splotches and pools. If not set, draws circles. Should be white on transparent background
@export var splotch_texture: Texture2D
## Randomly rotate splotch/pool textures for visual variety
@export var rotate_splotches: bool = true
## Lifetime for main stroke points before fully faded (in seconds)
@export_range(0.5, 5.0, 0.1) var main_stroke_lifetime: float = 1.6
## Lifetime for splotches and pools before fully faded (in seconds)
@export_range(0.5, 5.0, 0.1) var detail_lifetime: float = 2.1
## Maximum number of ink points to keep in memory. Older points are removed when limit is reached. Higher = more persistent ink but slower
@export_range(100, 10000, 100) var max_ink_points: int = 2000
## How often (in seconds) to clean up dried ink points. Lower = more accurate fading but slower, higher = better performance
@export_range(0.0, 0.5, 0.05) var cleanup_interval: float = 0.5

# Ink capacity settings
@export_group("Ink Capacity")
## Maximum ink capacity
@export_range(50.0, 500.0, 10.0) var max_ink: float = 100.0
## Ink consumed per second while painting
@export_range(1.0, 50.0, 1.0) var ink_drain_rate: float = 15.0
## Ink regenerated per second when not painting
@export_range(1.0, 30.0, 1.0) var ink_regen_rate: float = 8.0

# Speed-based size settings
@export_group("Speed to Size")
## Maximum speed value (in pixels/sec) that maps to 1.0 on the speed_to_size_curve. Speeds above this are clamped.
@export_range(500.0, 3000.0, 50.0) var max_speed_for_curve: float = 1500.0
## Curve that maps speed to brush size. X-axis: 0 (stopped) to 1 (max speed). Y-axis: 0 (min size) to 1 (max size)
@export var speed_to_size_curve: Curve
## Temporal smoothing for brush size changes. Higher = smoother transitions but more lag. 0 = instant size changes
@export_range(0.0, 1.0, 0.05) var size_smoothing: float = 0.8

# Splotching settings - irregular ink particles that appear around the stroke
@export_group("Splotching")
## Maximum number of splotch particles per stroke point. Set to 0 to completely disable splotching
@export_range(0, 5, 1) var max_splotches_per_point: int = 1
## Global splotch frequency multiplier. Lower this to reduce overall splotch density. 1.0 = normal, 0.1 = 10x less frequent, 0.01 = 100x less frequent
@export_range(0.0, 1.0, 0.01) var splotch_frequency: float = 0.38
## Curve controlling how likely splotches appear based on speed. X: 0 (stopped) to 1 (max speed). Y: 0 (never) to 1 (always). Lower the curve to reduce splotching overall
@export var speed_to_splotch_curve: Curve
## How far splotches spread from the stroke (min, as multiplier of brush size)
@export_range(0.0, 5.0, 0.1) var splotch_spread_min: float = 0.1
## How far splotches spread from the stroke (max, as multiplier of brush size)
@export_range(0.0, 5.0, 0.1) var splotch_spread_max: float = 0.5
## Size of splotch particles relative to stroke (min multiplier). Can be larger than 1.0 for huge splotches
@export_range(0.0, 3.0, 0.05) var splotch_size_min: float = 1.45
## Size of splotch particles relative to stroke (max multiplier). Can be larger than 1.0 for huge splotches
@export_range(0.0, 3.0, 0.05) var splotch_size_max: float = 1.85

# Pooling settings - ink that accumulates when moving very slowly or stopped
@export_group("Pooling")
## Speed threshold below which pooling can occur (in pixels/sec). Increase to make pooling happen even when moving faster
@export_range(10.0, 200.0, 5.0) var pool_speed_threshold: float = 200.0
## Maximum number of pool particles per stroke point. Set to 0 to completely disable pooling
@export_range(0, 5, 1) var max_pools_per_point: int = 1
## Global pool frequency multiplier. Lower this to reduce overall pool density. 1.0 = normal, 0.1 = 10x less frequent, 0.01 = 100x less frequent
@export_range(0.0, 1.0, 0.01) var pool_frequency: float = 1.0
## Curve controlling how likely pools appear based on speed (0 to pool_speed_threshold). X: 0 (stopped) to 1 (at threshold). Y: 0 (never) to 1 (always). Lower the curve to reduce pooling
@export var speed_to_pool_curve: Curve
## How far pools spread from the stroke (as multiplier of brush size)
@export_range(0.0, 5.0, 0.1) var pool_spread_multiplier: float = 0.8
## Size of pool particles relative to stroke (min multiplier). Can be larger than 1.0 for huge pools
@export_range(0.0, 3.0, 0.05) var pool_size_min: float = 0.5
## Size of pool particles relative to stroke (max multiplier). Can be larger than 1.0 for huge pools
@export_range(0.0, 3.0, 0.05) var pool_size_max: float = 0.9

# Lifting settings - particles created when releasing the brush (mouse up)
@export_group("Lifting")
## Speed threshold for slow lift detection (in pixels/sec). Below this creates extra pooling
@export_range(50.0, 500.0, 10.0) var lift_slow_threshold: float = 500.0
## Number of pool particles created when lifting slowly (set to 0 for no lift pools)
@export_range(0, 10, 1) var lift_pool_count: int = 3
## Size multiplier for the ending blob when lifting slowly
@export_range(1.0, 3.0, 0.1) var lift_size_multiplier: float = 1.3
## How far lift pools spread from the end point (as multiplier of brush size)
@export_range(0.0, 5.0, 0.1) var lift_pool_spread: float = 1.0

# Signals
signal ink_changed(current_ink: float, max_ink: float)

# stroke state
var ink_points: Array[InkPoint] = []
var is_drawing: bool = false
var last_draw_position: Vector2 = Vector2.ZERO
var last_velocity: Vector2 = Vector2.ZERO
var current_time: float = 0.0
var stroke_start_time: float = 0.0
var accumulated_distance: float = 0.0
var cleanup_timer: float = 0.0 # timer for periodic cleanup
var smoothed_size: float = 0.0 # smoothed brush size to prevent rapid changes
var current_ink: float = 100.0 # current ink level
var is_ult_active: bool = false

# brush sprite rotation
const IDLE_ROTATION_DEG: float = 30.0  # ccw rotation when idle
var mouse_position: Vector2 = Vector2.ZERO
var player_node: CharacterBody2D = null
var brush_sprite_base_offset: Vector2 = Vector2.ZERO  # original offset from pivot


func _ready():
	# add to brush group for pickups to find
	add_to_group("brush")

	# initialize ink
	current_ink = max_ink
	ink_changed.emit(current_ink, max_ink)

	# default curves if none are set
	if speed_to_size_curve == null:
		speed_to_size_curve = Curve.new()
		speed_to_size_curve.min_value = 0.0
		speed_to_size_curve.max_value = 5.72
		speed_to_size_curve.add_point(Vector2(0.17023809, 2.286178))
		speed_to_size_curve.add_point(Vector2(0.8583334, 0.5179709))

	if speed_to_splotch_curve == null:
		speed_to_splotch_curve = Curve.new()
		speed_to_splotch_curve.add_point(Vector2(0.05357143, 0.07438588))
		speed_to_splotch_curve.add_point(Vector2(1.0, 0.009326696))

	if speed_to_pool_curve == null:
		speed_to_pool_curve = Curve.new()
		speed_to_pool_curve.add_point(Vector2(0.0, 0.0))

	# connect to player ult signals
	player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		player_node.ult_activated.connect(_on_ult_activated)
		player_node.ult_deactivated.connect(_on_ult_deactivated)

		# capture initial brush sprite offset
		var brush_sprite = player_node.get_node_or_null("BrushSprite")
		if brush_sprite:
			brush_sprite_base_offset = brush_sprite.position


func _process(delta: float):
	current_time += delta
	cleanup_timer += delta

	# update brush sprite position and rotation
	update_brush_sprite()

	# regenerate ink when not drawing
	if not is_drawing and current_ink < max_ink:
		current_ink = min(current_ink + ink_regen_rate * delta, max_ink)
		ink_changed.emit(current_ink, max_ink)

	# drain ink when drawing
	if is_drawing and current_ink > 0:
		current_ink = max(current_ink - ink_drain_rate * delta, 0.0)
		ink_changed.emit(current_ink, max_ink)

	# periodically clean up dried points instead of every frame
	if cleanup_timer >= cleanup_interval:
		cleanup_timer = 0.0

		# inplace removal for performance
		var i = 0
		while i < ink_points.size():
			if ink_points[i].is_dried(current_time):
				ink_points.remove_at(i)
			else:
				i += 1

		# enforce max point limit, remove oldest points
		# skip during ult so all strokes are kept
		if ink_points.size() > max_ink_points and not is_ult_active:
			var excess = ink_points.size() - max_ink_points
			ink_points = ink_points.slice(excess)

	# always redraw to show fading animation
	if ink_points.size() > 0:
		queue_redraw()


func _input(event: InputEvent):
	# track mouse position
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		mouse_position = event.position

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# can only start drawing if we have ink
				if current_ink > 0:
					# new stroke
					is_drawing = true
					last_draw_position = event.position
					last_velocity = Vector2.ZERO
					stroke_start_time = current_time
					accumulated_distance = 0.0
					smoothed_size = brush_min_size
					# initial touch is small and clean
					add_ink_splatter(event.position, Vector2.ZERO, true)
					GameManager.start_playing_brush_stroke()
			else:
				# lift brush
				if is_drawing:
					add_ink_splatter(event.position, last_velocity, false, true)
				is_drawing = false
				GameManager.stop_playing_brush_stroke()

	elif event is InputEventMouseMotion:
		if is_drawing:
			# stop if out of ink mid-stroke
			if current_ink <= 0:
				is_drawing = false
				GameManager.stop_playing_brush_stroke()
				return

			var current_position = event.position
			var velocity = event.velocity

			# interpolate points between last and current position
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


func add_ink_splatter(
	pos: Vector2, velocity: Vector2, is_stroke_start: bool = false, is_lifting: bool = false
):
	# calculate brush size based on speed using curve
	var speed = velocity.length()

	# normalize speed to 0-1 range for curve lookup
	var speed_normalized = clamp(speed / max_speed_for_curve, 0.0, 1.0)

	# sample curve to get size multiplier, 0 = min size, 1 = max size
	var size_multiplier = speed_to_size_curve.sample(speed_normalized)

	# calculate target size from curve
	var target_size = lerp(brush_min_size, brush_max_size, size_multiplier)

	# smooth size transitions to prevent rapid changes
	# when size_smoothing is 0 -> instant changes
	# when size_smoothing is higher eg 0.2, gradual changes
	if size_smoothing > 0.0:
		smoothed_size = lerp(smoothed_size, target_size, 1.0 - size_smoothing)
	else:
		smoothed_size = target_size

	var base_size = smoothed_size
	var final_size = base_size

	# handling for stroke start
	if is_stroke_start:
		# initial touch is small and controlled
		final_size = brush_min_size
		var lifetime = 999999.0 if is_ult_active else main_stroke_lifetime
		var point = InkPoint.new(pos, final_size, current_time, lifetime, true)
		ink_points.append(point)
		return

	# handling for lifting
	if is_lifting:
		# lifting behavior depends on speed
		if speed < lift_slow_threshold:
			# slow lift = more pooling/blob as pen lingers
			var lift_size = base_size * lift_size_multiplier
			var lifetime = 999999.0 if is_ult_active else main_stroke_lifetime
			var point = InkPoint.new(pos, lift_size, current_time, lifetime, true)
			ink_points.append(point)
			# add a small pool that scales with brush size
			var pool_spread = base_size * lift_pool_spread
			for i in range(lift_pool_count):
				var offset = Vector2(
					randf_range(-pool_spread, pool_spread), randf_range(-pool_spread, pool_spread)
				)
				var rot = randf() * TAU if rotate_splotches else 0.0
				var pool_lifetime = 999999.0 if is_ult_active else detail_lifetime
				var pool = InkPoint.new(
					pos + offset,
					lift_size * randf_range(0.7, 1.0),
					current_time,
					pool_lifetime,
					false,
					rot
				)
				ink_points.append(pool)
		else:
			# fast lift = clean, minimal extra ink
			var lifetime = 999999.0 if is_ult_active else main_stroke_lifetime
			var point = InkPoint.new(pos, final_size, current_time, lifetime, true)
			ink_points.append(point)
		return

	# add main point
	var lifetime = 999999.0 if is_ult_active else main_stroke_lifetime
	var point = InkPoint.new(pos, final_size, current_time, lifetime, true)
	ink_points.append(point)

	# splotching, use curve to determine probability based on speed
	if max_splotches_per_point > 0:
		var splotch_probability = speed_to_splotch_curve.sample(speed_normalized)
		# apply global frequency multiplier
		splotch_probability *= splotch_frequency

		# determine number of splotches based on probability
		var num_splotches = 0
		for i in range(max_splotches_per_point):
			# each additional splotch has progressively lower chance
			var threshold = splotch_probability * pow(0.5, i)
			if randf() < threshold:
				num_splotches += 1
			else:
				break

		for i in range(num_splotches):
			var splotch_spread = base_size * randf_range(splotch_spread_min, splotch_spread_max)
			var offset = Vector2(
				randf_range(-splotch_spread, splotch_spread),
				randf_range(-splotch_spread, splotch_spread)
			)
			var splotch_size = final_size * randf_range(splotch_size_min, splotch_size_max)
			var rot = randf() * TAU if rotate_splotches else 0.0
			var splotch_lifetime = 999999.0 if is_ult_active else detail_lifetime
			var splotch = InkPoint.new(
				pos + offset, splotch_size, current_time, splotch_lifetime, false, rot
			)
			ink_points.append(splotch)

	# pooling when nearly stationary
	if speed < pool_speed_threshold and max_pools_per_point > 0:
		# use curve to determine pool probability based on speed
		var pool_speed_normalized = clamp(speed / pool_speed_threshold, 0.0, 1.0)
		var pool_probability = speed_to_pool_curve.sample(pool_speed_normalized)
		# global frequency multiplier to get very small vals
		pool_probability *= pool_frequency

		# determine number of pools based on probability
		var num_pools = 0
		for i in range(max_pools_per_point):
			# each additional pool has progressively lower chance
			var threshold = pool_probability * pow(0.6, i)
			if randf() < threshold:
				num_pools += 1
			else:
				break

		for i in range(num_pools):
			var pool_spread = base_size * pool_spread_multiplier
			var pool_offset = Vector2(
				randf_range(-pool_spread, pool_spread), randf_range(-pool_spread, pool_spread)
			)
			var pool_size = final_size * randf_range(pool_size_min, pool_size_max)
			var rot = randf() * TAU if rotate_splotches else 0.0
			var pool_lifetime = 999999.0 if is_ult_active else detail_lifetime
			var pool = InkPoint.new(
				pos + pool_offset, pool_size, current_time, pool_lifetime, false, rot
			)
			ink_points.append(pool)


func _draw():
	# early exit if no points to draw
	if ink_points.is_empty():
		return

	# pre calc base color components to avoid recreating Color objects
	var base_r = ink_color.r
	var base_g = ink_color.g
	var base_b = ink_color.b

	# draw all ink points
	for point in ink_points:
		var age = current_time - point.creation_time
		var life_ratio = 1.0 - (age / point.max_lifetime)

		# skip if too faded (for performance)
		if life_ratio < 0.05:
			continue

		var current_size = point.size * life_ratio

		# skip if too small (for perf)
		if current_size < 0.2:
			continue

		# create color with calculated alpha
		var color_with_alpha = Color(base_r, base_g, base_b, life_ratio)

		# texture based on point type
		var texture_to_use: Texture2D = null
		if point.is_main_stroke and brush_texture:
			texture_to_use = brush_texture
		elif not point.is_main_stroke and splotch_texture:
			texture_to_use = splotch_texture

		# draw with tex if available, otherwise use circle
		if texture_to_use:
			var tex_size = texture_to_use.get_size()
			var max_tex_dimension = max(tex_size.x, tex_size.y)

			# calc scale to make texture match desired size
			# texture should fit within circle of diameter current_size * 2
			var scale = (current_size * 2.0) / max_tex_dimension

			# apply rotation if this is a splotch/pool and rotation is enabled
			if point.rotation != 0.0:
				# save current transform, rotate around point position
				draw_set_transform(point.position, point.rotation, Vector2.ONE)
				# draw texture centered at origin
				var draw_pos = - (tex_size * scale * 0.5)
				draw_texture_rect(
					texture_to_use, Rect2(draw_pos, tex_size * scale), false, color_with_alpha
				)
				# reset transform
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				# no rotation
				var draw_pos = point.position - (tex_size * scale * 0.5)
				draw_texture_rect(
					texture_to_use, Rect2(draw_pos, tex_size * scale), false, color_with_alpha
				)
		else:
			# fallback to circle
			draw_circle(point.position, current_size, color_with_alpha)


## Restore ink (called when picking up ink pickups)
func add_ink(amount: float):
	current_ink = min(current_ink + amount, max_ink)
	ink_changed.emit(current_ink, max_ink)


func _on_ult_activated():
	is_ult_active = true
	current_ink = max_ink
	ink_changed.emit(current_ink, max_ink)


func _on_ult_deactivated():
	is_ult_active = false

	# reset infinite lifetime ink to start fading from now
	for point in ink_points:
		if point.max_lifetime >= 999999.0:
			point.creation_time = current_time
			if point.is_main_stroke:
				point.max_lifetime = main_stroke_lifetime
			else:
				point.max_lifetime = detail_lifetime


func update_brush_sprite():
	if not player_node:
		return

	var brush_sprite = player_node.get_node_or_null("BrushSprite")
	if not brush_sprite:
		return

	# flip brush x offset to match player direction
	var player_sprite = player_node.get_node_or_null("AnimatedSprite2D")
	if player_sprite:
		if player_sprite.flip_h:
			# facing left, invert x offset
			brush_sprite.position.x = -brush_sprite_base_offset.x
		else:
			# facing right, use base offset
			brush_sprite.position.x = brush_sprite_base_offset.x

	# rotate brush based on mouse state
	if is_drawing:
		# point bottom edge toward mouse cursor
		var direction = mouse_position - player_node.global_position
		var angle = direction.angle()
		# rotate 90 deg ccw because sprite points up by default and we want bottom to point to mouse
		brush_sprite.rotation = angle + deg_to_rad(90)
	else:
		# idle rotation, 30 deg ccw flipped 180 = 150 deg or -210 deg
		brush_sprite.rotation = deg_to_rad(-IDLE_ROTATION_DEG + 180)
