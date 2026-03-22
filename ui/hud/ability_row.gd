extends PanelContainer
class_name AbilityContainer

@onready var ability_icon: TextureRect = $Abilities/AbilityIcon

var active_ability: String = ""
var ability_timer: float = 0.0
const BASE_ABILITY_DURATION: float = 15.0

func _ready() -> void:
	# Create ability icon if it doesn't exist
	if not ability_icon:
		var abilities = get_node_or_null("Abilities")
		if not abilities:
			abilities = HBoxContainer.new()
			abilities.name = "Abilities"
			add_child(abilities)
		
		ability_icon = TextureRect.new()
		ability_icon.name = "AbilityIcon"
		ability_icon.custom_minimum_size = Vector2(32, 32)
		ability_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ability_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		abilities.add_child(ability_icon)
	
	ability_icon.visible = false
	
	# Connect to Game signals
	Abilities.ability_unlocked.connect(_on_ability_collected)

func _on_ability_collected(ability_key: String) -> void:
	# Activate the ability with RED FLOWER BONUS duration
	activate_ability(ability_key)

func activate_ability(ability_key: String) -> void:
	var collectible := Abilities.get_collectible(ability_key)
	var ability := Abilities.get_ability(ability_key)
	if not collectible:
		return

	active_ability = ability_key

	var base_dur := ability.base_duration if ability else BASE_ABILITY_DURATION
	var bonus_duration = FlowerManager.get_flower_powerup_bonus()
	ability_timer = base_dur + bonus_duration

	if ability_icon:
		ability_icon.texture = collectible.icon
		ability_icon.visible = true
		
		# Pulse animation to show it's active
		var tween = create_tween().set_loops()
		tween.tween_property(ability_icon, "modulate:a", 0.7, 0.5)
		tween.tween_property(ability_icon, "modulate:a", 1.0, 0.5)

func _process(delta: float) -> void:
	# Handle ability timer
	if active_ability != "" and ability_timer > 0:
		ability_timer -= delta
		
		# Flash faster when time is running out
		if ability_timer <= 3.0 and ability_timer > 0:
			var _flash_speed = 0.2
			if int(ability_timer * 5) % 2 == 0:
				if ability_icon:
					ability_icon.modulate = Color(1, 0.5, 0.5, 1)
			else:
				if ability_icon:
					ability_icon.modulate = Color.WHITE
		
		if ability_timer <= 0:
			# Deactivate ability
			if ability_icon:
				ability_icon.visible = false
				ability_icon.modulate = Color.WHITE
			
			Abilities.lock_ability(active_ability)
			active_ability = ""
			ability_timer = 0.0
