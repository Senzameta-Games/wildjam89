extends Node

signal tree_should_grow(amount: int, current_height: int)  # Added height parameter

@export var target_tree: Node2D  # Drag your Tree node here

# Growth resources
var tree_height: int = 0

func _ready():
	# Connect to tree's signals
	if target_tree:
		print("Connecting to tree: ", target_tree.name)
		tree_should_grow.connect(target_tree._on_grow_tree_signal)
		print("Connection successful")
	else:
		print("ERROR: target_tree is null!")

func _input(event):
	# Testing input
	if event.is_action_pressed("DebugTree"):
		grow_tree(1)

func grow_tree(amount: int = 1):
	tree_height += amount
	print("Growing tree by: ", amount, " Height now: ", tree_height)
	tree_should_grow.emit(amount, tree_height)  # Pass both amount and current height
