## Economy — Arcade mode seed counter.
## Manages the transient seed balance displayed in the arcade HUD.
## Not used by grove or run systems. New code uses GameState.add_resource() instead.
extends Node

signal seeds_changed(current_total: int)

var total_seeds: int = 0

func add_seeds(amount: int) -> void:
	total_seeds += amount
	seeds_changed.emit(total_seeds)
	print("Seeds collected: ", total_seeds)

func spend(amount: int) -> bool:
	if total_seeds < amount:
		return false
	total_seeds -= amount
	seeds_changed.emit(total_seeds)
	return true

func get_balance() -> int:
	return total_seeds

func big_money() -> void:
	total_seeds = 999
	seeds_changed.emit(total_seeds)

func reset() -> void:
	total_seeds = 0
	seeds_changed.emit(total_seeds)

func serialize() -> Dictionary:
	return { "total_seeds": total_seeds }

func deserialize(data: Dictionary) -> void:
	total_seeds = data.get("total_seeds", 0)
	seeds_changed.emit(total_seeds)
