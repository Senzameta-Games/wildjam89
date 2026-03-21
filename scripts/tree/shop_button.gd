extends Node2D

@export var zapper_script: Script
@export var empty_sfx: AudioStreamPlayer2D
@export var grow_sfx: AudioStreamPlayer2D
@export var seed_scn: PackedScene
@export var zap_sfx: AudioStreamPlayer2D

@export var zap_threshold: int = 10

@onready var detect_area: Area2D = $Area

var player_in_range: bool = false
var interaction_locked: bool = false
var deposit_timer: float = 0.0
var current_interval: float = 0.2
var seed_since_last_zap: int = 0
var current_player_body: Node2D = null

const MAX_INTERVAL: float = 0.2
const MIN_INTERVAL: float = 0.05

signal shop_interacted

func _process(delta) -> void:
	if not player_in_range:
		_reset_deposit_logic()
		return
	
	if Input.is_action_pressed("interact"):
		if interaction_locked:
			return
		
		deposit_timer -= delta
		
		if deposit_timer <= 0:
			_attempt_deposit()
			deposit_timer = current_interval
			current_interval = max(current_interval * 0.9, MIN_INTERVAL)
		
	else:
		_reset_deposit_logic()

func _reset_deposit_logic() -> void:
	deposit_timer = 0.0
	current_interval = MAX_INTERVAL
	interaction_locked = false

func _attempt_deposit() -> void:
	if Economy.get_balance() <= 0:
		_trigger_empty_feedback()
		return

	Economy.add_seeds(-1)
	shop_interacted.emit()
	
	if seed_scn and current_player_body:
		var visual_seed = seed_scn.instantiate()
		get_tree().current_scene.add_child(visual_seed)
		visual_seed.global_position = current_player_body.global_position
		
		if visual_seed.has_method("setup_deposit"):
			visual_seed.setup_deposit(self)
	
	if grow_sfx:
		grow_sfx.play()
	
	if Abilities.has_ability("pesticide"):
		seed_since_last_zap += 1
		if seed_since_last_zap >= zap_threshold:
			_fire_zapper()
			seed_since_last_zap = 0

func _trigger_empty_feedback() -> void:
	interaction_locked = true
	
	if empty_sfx:
		empty_sfx.play()
	
	var ui_seeds = get_tree().current_scene.find_child("Seeds", true, false)
	if ui_seeds and ui_seeds.has_method("shake_visual"):
		ui_seeds.shake_visual()

func _fire_zapper() -> void:
	if not zapper_script: return
	var enemies = get_tree().get_nodes_in_group("enemy")
	var target = null
	var closest_dist = INF
	
	for enemy in enemies:
		if enemy.has_method("die") and not enemy.get("is_dying") and not enemy.get("stomped"):
			var dist = global_position.distance_to(enemy.global_position)
			if dist < closest_dist:
				closest_dist = dist
				target = enemy
	if target:
		var zapper = zapper_script.new()
		get_tree().current_scene.add_child(zapper)
		zapper.zap(target.global_position)
		zap_sfx.play()
		target.die()

func _on_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		current_player_body = body

func _on_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		current_player_body = null
