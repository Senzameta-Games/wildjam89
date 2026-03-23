extends CharacterBody2D
class_name Seed

const MERGE_RADIUS: float = 24.0
const FLOOR_FRICTION: float = 600.0

var quantity: int = 1

var _is_collected: bool = false
var _merge_checked: bool = false

var _mode_drop: bool = false
var _mode_loss: bool = false
var _mode_deposit: bool = false
var _mode_world: bool = false

var _deposit_target: Node2D = null
var _can_seek_deposit: bool = false
var _deposit_velocity: Vector2 = Vector2.ZERO

var _loss_velocity: Vector2 = Vector2.ZERO

var _gravity: float = 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var label: Label = $Label
@onready var collect_sfx: AudioStreamPlayer2D = $SFX/Collected
@onready var area: Area2D = $Area2D
@onready var body_collider: CollisionShape2D = $BodyCollider

func _ready() -> void:
	_gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	add_to_group("seed")
	if sprite:
		sprite.play("appear")
	_update_label()

func _update_label() -> void:
	if label:
		label.text = str(quantity)
		label.visible = quantity > 1

# --- Setup functions ---

func setup_drop(_source_position: Vector2) -> void:
	_mode_drop = true
	velocity = Vector2(randf_range(-150, 150), randf_range(-250, -100))
	if area:
		area.set_deferred("monitoring", true)

func setup_world(amount: int) -> void:
	_mode_world = true
	quantity = amount
	_update_label()
	if area:
		area.set_deferred("monitoring", true)
	_start_lifespan()

func setup_loss() -> void:
	_mode_loss = true
	if body_collider:
		body_collider.disabled = true
	_loss_velocity = Vector2(randf_range(-4, 4), randf_range(-400, -200))

	var tween = create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

func setup_deposit(target: Node2D) -> void:
	_mode_deposit = true
	_deposit_target = target
	if body_collider:
		body_collider.disabled = true
	_deposit_velocity = Vector2(randf_range(-32, 32), randf_range(-400, -200))

	if collect_sfx:
		collect_sfx.pitch_scale = 0.5
		collect_sfx.play()

	await get_tree().create_timer(0.15).timeout
	_can_seek_deposit = true

# --- Drop physics (CharacterBody2D) ---

func _physics_process(delta: float) -> void:
	# Magnetism: pulls resting drop seeds and world seeds toward the player.
	var magnetizable := (_mode_drop and _merge_checked) or _mode_world
	if magnetizable and Magnetism.is_active():
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player:
			var dist := global_position.distance_to(player.global_position)
			if dist <= Magnetism.range:
				if dist < 20.0:
					_collect()
					return
				velocity = global_position.direction_to(player.global_position) * Magnetism.pull_speed
				move_and_slide()
				return

	if not _mode_drop:
		return

	if not is_on_floor():
		velocity.y += _gravity * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, FLOOR_FRICTION * delta)

	move_and_slide()
	rotation += (velocity.x * 0.05) * delta

	if not _merge_checked and is_on_floor() and abs(velocity.x) < 10.0:
		_on_settled()

# --- Loss and deposit movement (manual, no floor collision) ---

func _process(delta: float) -> void:
	if _mode_loss:
		_loss_velocity.y += _gravity * delta
		global_position += _loss_velocity * delta
		rotation += (_loss_velocity.x * 0.05) * delta
		return

	if _mode_deposit:
		if not _deposit_target:
			return
		if _can_seek_deposit:
			var dir = global_position.direction_to(_deposit_target.global_position)
			_deposit_velocity += (dir * 400.0 - _deposit_velocity) * delta * 5.0
		else:
			_deposit_velocity = _deposit_velocity.move_toward(Vector2.ZERO, 5.0)
		global_position += _deposit_velocity * delta
		rotation += (_deposit_velocity.x * 0.05) * delta
		if global_position.distance_to(_deposit_target.global_position) < 20.0:
			_on_deposited()

# --- Settle / merge ---

func _on_settled() -> void:
	_merge_checked = true
	velocity = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "rotation", 0.0, 0.15).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(_try_merge)

func _try_merge() -> void:
	var best: Seed = null
	var best_qty: int = 0
	for node in get_tree().get_nodes_in_group("seed"):
		if node == self or not node is Seed:
			continue
		var s := node as Seed
		if not s._mode_drop:
			continue
		if s.global_position.distance_to(global_position) <= MERGE_RADIUS:
			if s.quantity > best_qty:
				best_qty = s.quantity
				best = s
	if best:
		best.quantity += quantity
		best._update_label()
		queue_free()

# --- Collection ---

func _on_area2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_collect()

func _collect() -> void:
	if _is_collected:
		return
	_is_collected = true
	if area:
		area.set_deferred("monitoring", false)
	set_physics_process(false)
	velocity = Vector2.ZERO

	Economy.add_seeds(quantity)

	if collect_sfx:
		collect_sfx.pitch_scale = 1.0
		collect_sfx.play()

	var tween = create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y - 14.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	queue_free()

func _on_deposited() -> void:
	if _is_collected:
		return
	_is_collected = true

	await get_tree().create_timer(0.2).timeout

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()

# --- Lifespan (world mode) ---

func _start_lifespan() -> void:
	await get_tree().create_timer(5.0).timeout
	if _is_collected:
		return

	var blink = create_tween().set_loops()
	blink.tween_property(self, "modulate:a", 0.3, 0.0)
	blink.tween_property(self, "modulate:a", 1.0, 0.25)

	await get_tree().create_timer(3.0).timeout
	if _is_collected:
		return

	queue_free()
