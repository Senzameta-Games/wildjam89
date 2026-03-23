extends CharacterBody2D
class_name Enemy

# -- Data-driven config --
# Assign a .tres resource in the editor. All identity/tuning values come from here.
@export var data: EnemyData

# -- Convenience accessors (read from resource, fall back to defaults) --
var enemy_kind: EnemyData.EnemyType:
	get: return data.enemy_kind if data else EnemyData.EnemyType.SNAIL
var spawn_cost: int:
	get: return data.spawn_cost if data else 1
var speed: float:
	get: return data.speed if data else 150.0
var seed_value: int:
	get: return data.seed_value if data else 1

# -- Scene references (stay on the node, not on the resource) --
@export var seed_scn: PackedScene

var current_target: Node2D = null
signal seed_dropped
signal enemy_defeated

@onready var stomped: bool = false
@onready var is_dying: bool = false

@onready var die_sfx: AudioStreamPlayer2D = $SFX/Die
@onready var enemy_sprite: AnimatedSprite2D = $Sprite
@onready var dropped_seed: Node2D = $Seed

var passive_movement: bool = false
var passive_dir: float = 0.0

# Anti-stuck tracking
var stuck_check_timer: float = 0.0
var last_check_pos: Vector2 = Vector2.ZERO
const STUCK_CHECK_INTERVAL: float = 1.0
const STUCK_THRESHOLD: float = 5.0

func _ready() -> void:
	$SFX/Spawned.play()
	if not passive_movement:
		aggro_tree()
	else:
		passive_dir = 1.0 if global_position.x < 320.0 else -1.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	_check_if_stuck(delta)
	move_towards_target()
	move_and_slide()

func no_aggro() -> void:
	passive_movement = true
	current_target = null
	if is_inside_tree():
		passive_dir = 1.0 if global_position.x < 320.0 else -1.0

func aggro_player() -> void:
	if passive_movement: return
	current_target = get_tree().get_first_node_in_group("player")
	$Hitbox.set_collision_layer_value(3, false)

func aggro_tree() -> void:
	if passive_movement: return
	var trees = get_tree().get_nodes_in_group("tree")
	var valid_trees: Array = []
	for t in trees:
		if t is SeedTree:
			valid_trees.append(t)
	if valid_trees.size() > 0:
		current_target = valid_trees.pick_random()
	else:
		current_target = get_tree().get_first_node_in_group("tree")

func _check_if_stuck(delta: float) -> void:
	if stomped or is_dying or passive_movement:
		return
	stuck_check_timer += delta
	if stuck_check_timer >= STUCK_CHECK_INTERVAL:
		stuck_check_timer = 0.0
		var distance_moved = global_position.distance_to(last_check_pos)
		if distance_moved < STUCK_THRESHOLD and is_on_floor():
			_handle_stuck_state()
		last_check_pos = global_position

func _handle_stuck_state() -> void:
	var trees = get_tree().get_nodes_in_group("tree")
	var near_any_tree = false
	for t in trees:
		if t is SeedTree:
			if global_position.distance_to(t.global_position) < 80.0:
				near_any_tree = true
				break
	if not near_any_tree:
		var valid_trees: Array = []
		for t in trees:
			if t is SeedTree and t != current_target:
				valid_trees.append(t)
		if valid_trees.size() > 0:
			current_target = valid_trees.pick_random()

func move_towards_target() -> void:
	if passive_movement:
		velocity.x = passive_dir * speed
		if enemy_sprite:
			enemy_sprite.play("walk")
			if passive_dir != 0:
				enemy_sprite.flip_h = passive_dir < 0
		return
	if not is_instance_valid(current_target):
		aggro_tree()
		return
	var target_x = current_target.global_position.x
	var dir_x = sign(target_x - global_position.x)
	velocity.x = dir_x * (speed / 3)
	if enemy_sprite:
		enemy_sprite.play("walk")
		if dir_x != 0:
			enemy_sprite.flip_h = dir_x < 0

func _on_hitbox_body_entered(body: Node2D) -> void:
	if stomped or is_dying:
		return
	if (body != self) and body.is_in_group("player"):
		var is_above = body.global_position.y < (global_position.y - 8.0)
		var is_stomp_active: bool = body.get("is_stomping")
		if is_stomp_active and is_above:
			if body.has_method("bounce"):
				body.bounce()
			die()
		elif is_above and body.velocity.y > 0:
			if body.has_method("bounce"):
				body.bounce()
		else:
			body.hurt(global_position)

func die() -> void:
	if is_dying: return
	is_dying = true
	stomped = true
	$Hitbox/CollisionShape2D.set_deferred("disabled", true)
	remove_from_group("enemy")
	set_physics_process(false)
	$Collider.set_deferred("disabled", true)
	die_sfx.play()
	squash_and_hide()
	drop_seed()
	FlowerManager.plant_flower(global_position)

func squash_and_hide() -> void:
	var tween = create_tween()
	tween.tween_property($Sprite, "scale", Vector2(1.4, 0.2), 0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): $Sprite.visible = false)
	$SFX/Squash.play()

const TYPE_NAMES: Dictionary = {
	EnemyData.EnemyType.SNAIL: "snail",
	EnemyData.EnemyType.WORM: "worm",
	EnemyData.EnemyType.BEETLE: "beetle",
	EnemyData.EnemyType.BIRD: "bird",
}

func drop_seed() -> void:
	if dropped_seed: dropped_seed.visible = false
	seed_dropped.emit()
	enemy_defeated.emit()
	if Achievements:
		Achievements.on_enemy_stomped(TYPE_NAMES.get(enemy_kind, "enemy"))
	var interval = remap(float(seed_value), 1.0, 10.0, 0.2, 0.1)
	interval = clampf(interval, 0.05, 0.2)
	for i in range(seed_value):
		_spawn_visual_seed()
		if i < seed_value - 1:
			await get_tree().create_timer(interval).timeout
	await get_tree().create_timer(1.7).timeout
	queue_free()

func _spawn_visual_seed() -> void:
	if not seed_scn: return
	_deferred_spawn_seed.call_deferred(global_position)

func _deferred_spawn_seed(spawn_pos: Vector2) -> void:
	var new_seed = seed_scn.instantiate()
	get_tree().current_scene.add_child(new_seed)
	new_seed.global_position = spawn_pos
	new_seed.visible = true
	new_seed.setup_drop(spawn_pos)

func freeze() -> void:
	set_physics_process(false)
	velocity = Vector2.ZERO
	if enemy_sprite:
		enemy_sprite.pause()

func unfreeze() -> void:
	set_physics_process(true)
	if enemy_sprite:
		enemy_sprite.play()

func sacrifice() -> void:
	set_physics_process(false)
	$Collider.set_deferred("disabled", true)
	enemy_sprite.play("die")
	die_sfx.play()
	await enemy_sprite.animation_finished
	queue_free()
