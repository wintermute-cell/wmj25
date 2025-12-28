extends Control

@export var lantern_count: int = 5
@export var lantern_spacing: float = 40.0
@export var arc_height: float = 20.0  # How much the lanterns sag in the middle
@export var flicker_enabled: bool = true
@export var flicker_speed: float = 0.15  # Time between flicker frames

var lantern_texture: Texture2D = preload("res://sprites/lantern.png")
var lanterns: Array[Sprite2D] = []
var lantern_glows: Array[Sprite2D] = []
var current_health: float = 100.0
var max_health: float = 100.0

var flicker_timer: float = 0.0
var current_flicker_frame: int = 0

@export var glow_texture: Texture2D  # Set this to your glow sprite in the editor
@export_range(0.0, 1.0, 0.01) var glow_alpha: float = 0.5  # Overall brightness/opacity of glow
@export var glow_scale: float = 2.0  # Size of the glow effect
@export var glow_flicker_enabled: bool = true
@export_range(0.0, 0.5, 0.01) var glow_flicker_amount: float = 0.15  # How much the glow flickers (0 = none)


func _ready():
	# disable clipping so glows can show outside bounds
	clip_contents = false
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
	lantern_glows.clear()

	# calc total width
	var total_width = (lantern_count - 1) * lantern_spacing
	var start_x = -total_width / 2.0

	# create each lantern
	for i in range(lantern_count):
		# position calculation with hanging arc
		var t = float(i) / float(lantern_count - 1) if lantern_count > 1 else 0.5  # normalized position 0-1
		var x_pos = start_x + i * lantern_spacing

		# parabolic: highest at edges (0 and 1), lowest in middle (0.5)
		var y_offset = 4 * arc_height * t * (1 - t)

		# create glow sprite (behind lantern) if texture is provided
		if glow_texture:
			var glow = Sprite2D.new()
			glow.texture = glow_texture
			glow.position = Vector2(x_pos, y_offset)
			# Start invisible, will be set by update_health
			glow.modulate = Color(1.0, 1.0, 1.0, 0.0)
			glow.scale = Vector2(glow_scale, glow_scale)
			glow.z_index = 10  # in front of everything
			glow.material = CanvasItemMaterial.new()
			glow.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD  # additive blending for glow
			add_child(glow)
			lantern_glows.append(glow)
		else:
			lantern_glows.append(null)

		# create lantern sprite
		var lantern = Sprite2D.new()
		lantern.texture = lantern_texture
		lantern.hframes = 2  # 2 cols (anim frames)
		lantern.vframes = 6  # 6 rows (health states)
		lantern.position = Vector2(x_pos, y_offset)
		lantern.frame = 0
		lantern.z_index = 11  # on top of glow

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
		var health_ratio_for_glow: float

		if lantern_health_ratio >= 1.0:
			frame_row = 0
			health_ratio_for_glow = 1.0  # full glow
		elif lantern_health_ratio >= 0.8:
			frame_row = 1
			health_ratio_for_glow = 0.8
		elif lantern_health_ratio >= 0.6:
			frame_row = 2
			health_ratio_for_glow = 0.6
		elif lantern_health_ratio >= 0.4:
			frame_row = 3
			health_ratio_for_glow = 0.4
		elif lantern_health_ratio >= 0.2:
			frame_row = 4
			health_ratio_for_glow = 0.2
		else:
			frame_row = 5  # broken
			health_ratio_for_glow = 0.0  # no glow when broken

		lantern.frame = current_flicker_frame + frame_row * 2

		# update glow sprite (health ratio * overall alpha setting)
		if i < lantern_glows.size() and lantern_glows[i]:
			var base_alpha = health_ratio_for_glow * glow_alpha

			# add subtle flicker to glow
			var final_alpha = base_alpha
			if glow_flicker_enabled and base_alpha > 0.0:
				var flicker_variation = randf_range(-glow_flicker_amount, glow_flicker_amount)
				final_alpha = clamp(base_alpha + flicker_variation, 0.0, 1.0)

			lantern_glows[i].modulate = Color(1.0, 1.0, 1.0, final_alpha)


func _update_flicker():
	update_health(current_health, max_health)
