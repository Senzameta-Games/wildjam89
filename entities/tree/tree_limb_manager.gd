class_name TreeLimbManager
extends Node2D

## Emitted when a limb is created that could host content (index > 0, is_platform true).
## External systems connect here to decide what to place on the branch.
signal limb_spawn_point_available(spawn_position: Vector2, side: int, limb_index: int)

# -- Visual assets (set in editor) --
@export var branch_sprite: Texture2D
@export var leaf_sprites: Array[Texture2D] = []
@export var leaves_per_segment: int = 3
@export var leaf_spread: float = 8.0
@export var branch_length: int = 24
@export var grow_duration: float = 0.4

# Active limbs keyed by limb index (int → StaticBody2D)
var _limbs: Dictionary = {}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Called by the tree whenever growth state changes.
## Compares the target limb_states against current limbs and adds/removes as needed.
func sync_to_state(limb_states: Array[Dictionary]) -> void:
	# Build a map of indices that should have limbs
	var target: Dictionary = {}  # int → state Dictionary
	for state in limb_states:
		if state.has_limb:
			target[state.index] = state

	# Remove limbs that are no longer in the target set
	for index in _limbs.keys():
		if not target.has(index):
			_remove_limb(index)

	# Add limbs that are in the target but not yet created
	for index in target:
		if not _limbs.has(index):
			var side := -1 if randf() < 0.5 else 1
			_add_limb(target[index], side)

## Returns all current limb nodes sorted by index ascending (lowest → highest on tree).
## Only includes still-valid instances. Useful for external systems that need to place
## content on branches (e.g. reward pickup spawning).
func get_limbs_sorted() -> Array[Node2D]:
	var indices := _limbs.keys()
	indices.sort()
	var result: Array[Node2D] = []
	for i in indices:
		if is_instance_valid(_limbs[i]):
			result.append(_limbs[i])
	return result

## Remove all limbs immediately (called on tree_died).
## Does NOT touch externally-spawned content — external systems own their own nodes.
func clear_all_limbs() -> void:
	for index in _limbs.keys():
		var limb = _limbs[index]
		if is_instance_valid(limb):
			limb.queue_free()
	_limbs.clear()

# ---------------------------------------------------------------------------
# Limb creation / removal
# ---------------------------------------------------------------------------

func _add_limb(state: Dictionary, side: int) -> void:
	var index: int = state.index

	# Shorter branches near the base, longer ones higher up
	var max_segments := 5
	if index <= 2:
		max_segments = 2
	var segments := randi_range(1, max_segments)
	var total_width := branch_length * segments

	var branch := StaticBody2D.new()
	branch.name = "Limb_" + str(index)
	branch.collision_layer = 0
	branch.set_collision_layer_value(6, true)
	add_child(branch)

	# Position relative to LimbManager's origin (same as tree root)
	branch.position = Vector2(side * 16, -state.height_offset)

	# Build segments and leaves
	var leaf_idx := [0]
	for i in range(segments):
		var sprite := Sprite2D.new()
		sprite.texture = branch_sprite
		sprite.scale.x = side
		var offset_from_bark := (branch_length * i) + (branch_length / 2.0)
		sprite.position.x = offset_from_bark * side
		branch.add_child(sprite)
		_add_leaves_to_segment(branch, i, side, offset_from_bark, leaf_idx)

	# One-way platform collision — disabled until maturity threshold is met
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(total_width, 8)
	collision.shape = shape
	collision.one_way_collision = true
	collision.position.x = (total_width / 2.0) * side
	collision.disabled = not state.is_platform
	branch.add_child(collision)

	_limbs[index] = branch
	_animate_branch_in(branch)

	# Notify external systems that this limb can host content
	if state.is_platform and index > 0:
		var spawn_x := branch.global_position.x + randf_range(branch_length, total_width) * side
		limb_spawn_point_available.emit(
			Vector2(spawn_x, branch.global_position.y - 16.0),
			side,
			index
		)

func _remove_limb(index: int) -> void:
	if _limbs.has(index):
		var limb = _limbs[index]
		if is_instance_valid(limb):
			limb.queue_free()
		_limbs.erase(index)

# ---------------------------------------------------------------------------
# Visuals — ported directly from branch.gd
# ---------------------------------------------------------------------------

func _add_leaves_to_segment(
	branch: Node2D,
	segment_index: int,
	side: int,
	segment_center_x: float,
	leaf_idx: Array
) -> void:
	if leaf_sprites.is_empty():
		return

	var leaf_count := randi_range(1, leaves_per_segment)
	if segment_index == 0:
		leaf_count = max(1, leaf_count - 1)

	for i in range(leaf_count):
		var leaf := Sprite2D.new()
		leaf.texture = leaf_sprites[randi() % leaf_sprites.size()]

		leaf.position = Vector2(
			segment_center_x * side + randf_range(-leaf_spread, leaf_spread) * side,
			randf_range(-leaf_spread, leaf_spread)
		)
		leaf.scale = Vector2.ONE * randf_range(0.7, 1.2)
		leaf.rotation = randf_range(-PI / 4.0, PI / 4.0)
		if randf() < 0.5:
			leaf.scale.x *= -1

		branch.add_child(leaf)
		_animate_leaf_in(leaf, leaf_idx[0] * 0.05)
		leaf_idx[0] += 1

func _animate_leaf_in(leaf: Sprite2D, delay: float = 0.0) -> void:
	leaf.modulate.a = 0.0
	var original_scale := leaf.scale
	leaf.scale = original_scale * 0.3

	var tween := create_tween()
	tween.tween_interval(delay)
	tween.parallel().tween_property(leaf, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(leaf, "scale", original_scale, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _animate_branch_in(branch: Node2D) -> void:
	branch.scale = Vector2.ZERO
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(branch, "scale", Vector2.ONE, grow_duration)
	var sfx = owner.get_node_or_null("SFX/ImpulseGrow")
	if sfx:
		sfx.play()
