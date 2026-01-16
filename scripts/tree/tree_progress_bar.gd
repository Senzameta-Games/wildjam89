extends Control

@onready var progress_bar: ProgressBar = $ProgressBar
var tree: SeedTree

func _ready() -> void:
	tree = get_tree().get_first_node_in_group("tree")

func _process(_delta: float) -> void:
	if is_instance_valid(tree):
		progress_bar.value = tree.tree_progress
