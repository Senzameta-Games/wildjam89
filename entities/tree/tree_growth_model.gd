class_name TreeGrowthModel
extends RefCounted

var data: TreeData

func _init(tree_data: TreeData) -> void:
	data = tree_data

## Given a progress value (0–100), return the full structural state of the tree.
func compute_state(progress: float) -> Dictionary:
	var section_count := int((progress / 100.0) * data.max_sections)
	var leaf_tier := int(progress / 10.0)
	var trunk_height := section_count * data.trunk_section_height

	return {
		"progress": progress,
		"section_count": section_count,
		"trunk_height": trunk_height,
		"leaf_tier": leaf_tier,
		"limb_states": _compute_limb_states(section_count),
	}

## Compute which limbs should exist and their maturity.
## One limb candidate per section; only even-indexed sections actually spawn a limb.
func _compute_limb_states(section_count: int) -> Array[Dictionary]:
	var limbs: Array[Dictionary] = []
	for i in range(section_count):
		var has_limb := (i % 2 == 0)
		limbs.append({
			"index": i,
			"has_limb": has_limb,
			"height_offset": i * data.trunk_section_height,
			"maturity": 1.0,  # Future: 0.0–1.0 based on limb age
			"is_platform": has_limb,  # Future: gated by limb_maturity_threshold
		})
	return limbs
