extends HBoxContainer
class_name TreeMeters

@onready var tree_meters_container: HBoxContainer
@onready var ability_icon: TextureRect

var tree_to_meter: Dictionary = {} # {tree: meter_node}

# Ability icons
var ability_icons: Dictionary = {
	"aim_stomp": preload("res://assets/sprites/items/aimstomp/stopwatch.png"),
	"double_jump": preload("res://assets/sprites/items/doublejump/feather.png"),
	"pesticide": preload("res://assets/sprites/items/pesticide/pesticide.png")
}

var active_ability: String = ""
var ability_timer: float = 0.0
const ABILITY_DURATION: float = 15.0

func _ready() -> void:
	# Find or create container
	tree_meters_container = get_node_or_null("TreeMetersContainer")
	if not tree_meters_container:
		tree_meters_container = HBoxContainer.new()
		tree_meters_container.name = "TreeMetersContainer"
		tree_meters_container.add_theme_constant_override("separation", 8)
		add_child(tree_meters_container)
	
	# Find or create ability icon
	ability_icon = get_node_or_null("AbilityIcon")
	if not ability_icon:
		ability_icon = TextureRect.new()
		ability_icon.name = "AbilityIcon"
		ability_icon.custom_minimum_size = Vector2(32, 32)
		ability_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ability_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Add as first child so it appears on the left
		add_child(ability_icon)
		move_child(ability_icon, 0)
	
	ability_icon.visible = false
	
	# Connect to Game signals
	if Game:
		Game.ability_unlocked.connect(_on_ability_collected)

func register_tree(tree: SeedTree) -> void:
	if not tree or tree in tree_to_meter:
		return
	
	# Create a new meter for this tree
	var meter = _create_tree_meter(tree)
	tree_meters_container.add_child(meter)
	tree_to_meter[tree] = meter
	
	# Connect to tree signals
	if tree.tree_damaged.connect(_on_tree_damaged.bind(tree)) != OK:
		push_warning("Failed to connect tree_damaged signal")
	if tree.tree_healed.connect(_on_tree_healed.bind(tree)) != OK:
		push_warning("Failed to connect tree_healed signal")
	if tree.tree_died.connect(_on_tree_died.bind(tree)) != OK:
		push_warning("Failed to connect tree_died signal")
	
	_update_meter(tree, meter)

func unregister_tree(tree: SeedTree) -> void:
	if tree not in tree_to_meter:
		return
	
	var meter = tree_to_meter[tree]
	tree_to_meter.erase(tree)
	
	if is_instance_valid(meter):
		meter.queue_free()

func _create_tree_meter(tree: SeedTree) -> HBoxContainer:
	var meter = HBoxContainer.new()
	meter.add_theme_constant_override("separation", 2)
	
	# Sprite (acorn icon)
	var sprite = TextureRect.new()
	sprite.name = "Sprite"
	sprite.custom_minimum_size = Vector2(24, 24)
	sprite.texture = load("res://assets/sprites/tree/acorn.png")
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	meter.add_child(sprite)
	
	# Index label
	var index_label = Label.new()
	index_label.name = "Index"
	var tree_index = tree_to_meter.size() + 1
	index_label.text = str(tree_index)
	var label_settings = LabelSettings.new()
	label_settings.font = load("res://assets/fonts/Tiny5-Regular.ttf")
	index_label.label_settings = label_settings
	index_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	meter.add_child(index_label)
	
	# Progress bar
	var progress_bar = ProgressBar.new()
	progress_bar.name = "Meter"
	progress_bar.custom_minimum_size = Vector2(0, 18)
	progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Create styles
	var bg_style = StyleBoxLine.new()
	bg_style.color = Color(0.0885599, 0.08855992, 0.08855987, 1)
	bg_style.thickness = 6
	bg_style.vertical = true
	
	var fill_style = StyleBoxLine.new()
	fill_style.color = Color(1, 1, 1, 1)
	fill_style.thickness = 6
	fill_style.vertical = true
	
	progress_bar.add_theme_stylebox_override("background", bg_style)
	progress_bar.add_theme_stylebox_override("fill", fill_style)
	progress_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	progress_bar.show_percentage = false
	progress_bar.max_value = 100
	
	meter.add_child(progress_bar)
	
	return meter

func _update_meter(tree: SeedTree, meter: HBoxContainer) -> void:
	if not is_instance_valid(tree) or not is_instance_valid(meter):
		return
	
	# Find the progress bar
	var progress_bar = meter.get_node_or_null("Meter") as ProgressBar
	if progress_bar:
		progress_bar.value = tree.tree_progress

func _on_tree_damaged(_amount: float, tree: SeedTree) -> void:
	if tree not in tree_to_meter:
		return
	
	var meter = tree_to_meter[tree]
	_update_meter(tree, meter)

func _on_tree_healed(_amount: float, tree: SeedTree) -> void:
	if tree not in tree_to_meter:
		return
	
	var meter = tree_to_meter[tree]
	_update_meter(tree, meter)

func _on_tree_died(tree: SeedTree) -> void:
	unregister_tree(tree)

func _on_ability_collected(ability_key: String) -> void:
	# Activate the ability for 15 seconds
	activate_ability(ability_key)

func activate_ability(ability_key: String) -> void:
	if not ability_icons.has(ability_key):
		return
	
	active_ability = ability_key
	ability_timer = ABILITY_DURATION
	
	if ability_icon:
		ability_icon.texture = ability_icons[ability_key]
		ability_icon.visible = true

func _process(delta: float) -> void:
	# Update all active tree meters
	for tree in tree_to_meter:
		if is_instance_valid(tree):
			var meter = tree_to_meter[tree]
			_update_meter(tree, meter)
	
	# Handle ability timer
	if active_ability != "" and ability_timer > 0:
		ability_timer -= delta
		
		if ability_timer <= 0:
			# Deactivate ability
			if ability_icon:
				ability_icon.visible = false
			
			Game.lock_ability(active_ability)
			active_ability = ""
			ability_timer = 0.0
