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
