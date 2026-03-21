extends Node2D

func zap(target_pos: Vector2) -> void:
	var tween = create_tween()
	tween.tween_interval(0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.tween_callback(queue_free)
	
	var start_pos = Vector2(target_pos.x, 0)
	var end_pos = target_pos
	
	var points = _get_lightning_points(start_pos, end_pos)
	
	# lines/feedback
	# wider line
	var wide_line = Line2D.new()
	wide_line.width = 2.0
	wide_line.default_color = Color.WHITE
	wide_line.points = points
	add_child(wide_line)
	# thin line
	var thin_line = Line2D.new()
	thin_line.width = 1.0
	thin_line.default_color = Color.WHITE
	thin_line.points = points
	add_child(thin_line)

func _get_lightning_points(start: Vector2, end: Vector2) -> PackedVector2Array:
	var points = PackedVector2Array()
	points.append(start)
	
	var _current = start
	var segment_length = 20.0
	var total_dist = start.distance_to(end)
	var steps = int(total_dist / segment_length)
	
	for i in range(steps):
		var t = float(i) / float(steps)
		var straight_pos = start.lerp(end, t)
		var jitter = randf_range(-15.0, 15.0)
		
		points.append(Vector2(straight_pos.x + jitter, straight_pos.y))
	
	points.append(end)
	return points
