extends Resource
class_name EnemyData

enum EnemyType { SNAIL, WORM, BEETLE, BIRD }

@export_category("Identity")
@export var enemy_name: String
@export var enemy_kind: EnemyType = EnemyType.SNAIL

@export_category("Spawner")
@export var spawn_cost: int = 1

@export_category("Movement")
@export var speed: float = 150.0

@export_category("Drops")
@export var seed_value: int = 1
