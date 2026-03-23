class_name DefenseWaveSpawner
extends Node2D
## Wave-based spawner for grove defense phases.
## Kept separate from arcade's EnemySpawner intentionally — defense waves are
## event-triggered, not timer-triggered, and bugs will eventually target food
## rather than trees. Food-targeting AI is future work; bugs use placeholder
## aggro_tree() behavior until stash placement is implemented.

signal wave_cleared

@export var spawn_points: Array[NodePath] = []
@export var default_enemy_scenes: Array[PackedScene] = []

var _active_enemies: Array[Node] = []
var _resolved_spawn_points: Array[Node2D] = []

func _ready() -> void:
	for path: NodePath in spawn_points:
		var node: Node = get_node_or_null(path)
		if node is Node2D:
			_resolved_spawn_points.append(node as Node2D)

## Spawn count enemies. Passing count = 0 stubs the wave (immediately clears).
func spawn_wave(enemy_scenes: Array[PackedScene], count: int) -> void:
	if count == 0:
		wave_cleared.emit()
		return
	var scenes: Array[PackedScene] = enemy_scenes if not enemy_scenes.is_empty() else default_enemy_scenes
	if scenes.is_empty() or _resolved_spawn_points.is_empty():
		push_warning("DefenseWaveSpawner: no enemy scenes or spawn points configured")
		wave_cleared.emit()
		return
	for i: int in range(count):
		var scene: PackedScene = scenes[i % scenes.size()]
		var point: Node2D = _resolved_spawn_points[i % _resolved_spawn_points.size()]
		var enemy: Node = scene.instantiate()
		get_tree().current_scene.add_child(enemy)
		enemy.global_position = point.global_position
		if enemy.has_signal("enemy_defeated"):
			enemy.enemy_defeated.connect(_on_enemy_defeated.bind(enemy))
		_active_enemies.append(enemy)

func _on_enemy_defeated(enemy: Node) -> void:
	_active_enemies.erase(enemy)
	if _active_enemies.is_empty():
		wave_cleared.emit()
