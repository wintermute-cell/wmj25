extends Node2D

## Computes intersections between paint circles and walls to create collision polygons
## Paint + Wall overlap = actual collision geometry

## Reference to the brush system to read ink points
@export var brush: Node2D

## Root node to search for StaticBody2D walls (if null, uses scene root)
@export var wall_root: Node

## How often to update collision geometry (in seconds)
@export_range(0.05, 0.5, 0.05) var update_interval: float = 0.15

## Number of sides for circle polygon approximation (higher = smoother but slower)
@export_range(5, 32, 1) var circle_segments: int = 5

## Skip every Nth ink point for performance (1 = process all, 2 = process every 2nd, etc.)
@export_range(1, 10, 1) var point_skip: int = 8

var update_timer: float = 0.0

# coll body pool for reuse
var collision_bodies: Array[StaticBody2D] = []
var active_body_count: int = 0

# track active coll polygons for crunch detection
var active_collision_areas: Array[Dictionary] = []  # {polygon: PackedVector2Array, body_index: int}

# wall polys extracted from scene
var walls: Array[PackedVector2Array] = []

# coll layer for paint-masked walls
const WALL_LAYER = 1


func _ready():
	if brush == null:
		push_error("PaintCollisionManager: No brush assigned!")
		return

	# extract walls from scene
	var search_root = wall_root if wall_root != null else get_tree().root
	extract_walls_from_scene(search_root)

	print("PaintCollisionManager init with %d walls" % walls.size())


func _process(delta: float):
	if brush == null:
		return

	update_timer += delta

	if update_timer >= update_interval:
		update_timer = 0.0
		update_collision_geometry()


func extract_walls_from_scene(root_node: Node) -> void:
	var wall_nodes = find_static_bodies(root_node)

	for wall_node in wall_nodes:
		if wall_node is StaticBody2D:
			extract_wall_from_static_body(wall_node)

	print("PaintCollisionManager: Extracted %d wall polygons from scene" % walls.size())


func find_static_bodies(node: Node) -> Array[StaticBody2D]:
	var result: Array[StaticBody2D] = []

	if node is StaticBody2D:
		result.append(node)

	for child in node.get_children():
		result.append_array(find_static_bodies(child))

	return result


func extract_wall_from_static_body(wall_node: StaticBody2D) -> void:
	# find coll shapes
	for child in wall_node.get_children():
		if child is CollisionShape2D:
			var shape = child.shape
			var global_pos = child.global_position

			if shape is RectangleShape2D:
				var size = shape.size
				var half_size = size / 2.0

				# create rect polygon centered on coll shape
				var polygon = PackedVector2Array(
					[
						global_pos + Vector2(-half_size.x, -half_size.y),
						global_pos + Vector2(half_size.x, -half_size.y),
						global_pos + Vector2(half_size.x, half_size.y),
						global_pos + Vector2(-half_size.x, half_size.y)
					]
				)

				walls.append(polygon)
				print("PaintCollisionManager: Found wall at %v, size %v" % [global_pos, size])

				# NOTE: disable the original collision shape so only paint
				# masked sections collide. would possibly be smarter to just
				# not use colliders as the data source in the first place but i
				# dunno if we can use straigth polys somehow
				child.disabled = true
				print("PaintCollisionManager: Disabled original wall collision")


func update_collision_geometry():
	# get ink points from brush
	if not "ink_points" in brush or not "current_time" in brush:
		return

	var ink_points = brush.ink_points
	var current_time = brush.current_time

	# check if we have walls
	if walls.is_empty():
		clear_all_collisions()
		return

	# convert active ink points to circle polygons
	var paint_circles: Array[Dictionary] = []  # {polygon: PackedVector2Array, center: Vector2, radius: float}

	# iter with skipping for better perf
	for i in range(0, ink_points.size(), point_skip):
		var point = ink_points[i]
		var current_size = point.get_current_size(current_time)

		# skip dried or tiny points
		if current_size < 1.0:
			continue

		var circle_poly = create_circle_polygon(point.position, current_size)
		paint_circles.append(
			{"polygon": circle_poly, "center": point.position, "radius": current_size}
		)

	# if no active paint, clear all collisions
	if paint_circles.is_empty():
		clear_all_collisions()
		return

	# compute intersections for each wall
	var new_collision_areas: Array[Dictionary] = []
	active_body_count = 0

	for wall in walls:
		# find paint circles that might overlap this wall (AABB lets gooo)
		var overlapping_circles: Array[PackedVector2Array] = []

		for circle_data in paint_circles:
			if might_overlap(wall, circle_data):
				overlapping_circles.append(circle_data.polygon)

		# skip if no paint overlaps this wall
		if overlapping_circles.is_empty():
			continue

		# instead of merging all circles, intersect each circle individually.
		# should be faster cause avoids expensive polygon merge ops
		for paint_circle in overlapping_circles:
			var intersections = Geometry2D.intersect_polygons(wall, paint_circle)

			# create collision shapes for each intersection polygon
			for intersection_poly in intersections:
				if intersection_poly.size() >= 3:  # Valid polygon
					create_collision_for_polygon(intersection_poly, active_body_count)
					new_collision_areas.append(
						{"polygon": intersection_poly, "body_index": active_body_count}
					)
					active_body_count += 1

					if active_body_count > 500:
						print("PaintCollisionManager WARN: Hit collision body limit!")
						break

			if active_body_count > 500:
				break

		if active_body_count > 500:
			break

	# disable unused collision bodies
	for i in range(active_body_count, collision_bodies.size()):
		collision_bodies[i].visible = false
		# disable collision by removing all shapes
		for child in collision_bodies[i].get_children():
			if child is CollisionShape2D:
				child.disabled = true

	# if Engine.get_physics_frames() % 180 == 0 and active_body_count > 0:
	# 	print(
	# 		(
	# 			"PaintCollisionManager: %d active collision bodies, %d paint circles"
	# 			% [active_body_count, paint_circles.size()]
	# 		)
	# 	)

	# check for crunches
	check_crunches(new_collision_areas)

	# update active collision tracking
	active_collision_areas = new_collision_areas


func create_circle_polygon(center: Vector2, radius: float) -> PackedVector2Array:
	var polygon = PackedVector2Array()
	var angle_step = TAU / circle_segments

	for i in range(circle_segments):
		var angle = i * angle_step
		var point = center + Vector2(cos(angle), sin(angle)) * radius
		polygon.append(point)

	return polygon


func might_overlap(wall_poly: PackedVector2Array, circle_data: Dictionary) -> bool:
	# simple AABB overlap check for perf
	var wall_rect = get_polygon_aabb(wall_poly)
	var circle_center = circle_data.center
	var circle_radius = circle_data.radius

	var circle_rect = Rect2(
		circle_center - Vector2(circle_radius, circle_radius),
		Vector2(circle_radius * 2, circle_radius * 2)
	)

	return wall_rect.intersects(circle_rect)


func get_polygon_aabb(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()

	var min_x = polygon[0].x
	var max_x = polygon[0].x
	var min_y = polygon[0].y
	var max_y = polygon[0].y

	for point in polygon:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)

	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)


func create_collision_for_polygon(polygon: PackedVector2Array, body_index: int):
	var body = get_or_create_collision_body(body_index)

	# clear existing shapes
	for child in body.get_children():
		if child is CollisionShape2D:
			child.queue_free()

	# create collision shape from poly
	# try use ConvexPolygonShape2D if poly is convex, else decompose
	var shapes = decompose_to_convex(polygon)

	for shape_poly in shapes:
		var collision_shape = CollisionShape2D.new()
		var convex_shape = ConvexPolygonShape2D.new()
		convex_shape.points = shape_poly
		collision_shape.shape = convex_shape
		body.add_child(collision_shape)

	body.visible = true


func decompose_to_convex(polygon: PackedVector2Array) -> Array[PackedVector2Array]:
	var decomposed = Geometry2D.decompose_polygon_in_convex(polygon)

	if decomposed.is_empty():
		# fallback: just use the polygon as is, no idea if this will fuck stuff up some time
		return [polygon]

	return decomposed


func get_or_create_collision_body(index: int) -> StaticBody2D:
	# reuse existing body if available
	if index < collision_bodies.size():
		return collision_bodies[index]

	# create new StaticBody2D for coll
	var body = StaticBody2D.new()
	body.name = "PaintCollision%d" % index
	body.collision_layer = 1 << (WALL_LAYER - 1)  # Layer 1
	body.collision_mask = 0

	add_child(body)
	collision_bodies.append(body)

	return body


func clear_all_collisions():
	for body in collision_bodies:
		body.visible = false
		for child in body.get_children():
			if child is CollisionShape2D:
				child.disabled = true

	active_body_count = 0
	active_collision_areas.clear()


func check_crunches(new_areas: Array[Dictionary]):
	# compare new collision areas with previous ones
	# if a new area appears, check if any enemies are inside it

	# find truly new areas not present in prev frame
	var newly_created_areas: Array[PackedVector2Array] = []

	for new_area in new_areas:
		var is_new = true

		# check if this area existed before (rough check by comparing first point lol)
		for old_area in active_collision_areas:
			if polygons_similar(new_area.polygon, old_area.polygon):
				is_new = false
				break

		if is_new:
			newly_created_areas.append(new_area.polygon)

	# notify enemies of new collision areas (enemy checks check if its inside)
	if not newly_created_areas.is_empty():
		get_tree().call_group("enemies", "_on_new_collision_created", newly_created_areas)


func polygons_similar(poly1: PackedVector2Array, poly2: PackedVector2Array) -> bool:
	# TODO: this might need some improvement, dunno
	if poly1.is_empty() or poly2.is_empty():
		return false

	return poly1[0].distance_to(poly2[0]) < 1.0


func _exit_tree():
	for body in collision_bodies:
		if is_instance_valid(body):
			body.queue_free()
	collision_bodies.clear()
