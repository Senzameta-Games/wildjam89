extends PanelContainer
class_name AbilityContainer

@onready var ability_icon: TextureRect = $Abilities/AbilityIcon

var active_ability: String = ""
var ability_timer: float = 0.0  ## -1.0 = permanent sentinel; > 0 = seconds remaining

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
	var pickup_data := Abilities.get_pickup(ability_key)
	var ability := Abilities.get_ability(ability_key)
	if not pickup_data:
		return

	active_ability = ability_key

	var dur := ability.duration if ability else -1.0
	if dur > 0:
		var bonus_duration = FlowerManager.get_flower_powerup_bonus()
		ability_timer = dur + bonus_duration
		# Pulse animation for timed abilities
		if ability_icon:
			var tween = create_tween().set_loops()
			tween.tween_property(ability_icon, "modulate:a", 0.7, 0.5)
			tween.tween_property(ability_icon, "modulate:a", 1.0, 0.5)
	else:
		ability_timer = -1.0  # Sentinel: permanent — don't count down

	if ability_icon:
		ability_icon.texture = pickup_data.icon
		ability_icon.visible = true

func _process(delta: float) -> void:
	if active_ability == "" or ability_timer < 0:
		return  # No active ability, or it's permanent

	ability_timer -= delta

	# Flash faster when time is running out
	if ability_timer <= 3.0 and ability_timer > 0:
		if int(ability_timer * 5) % 2 == 0:
			if ability_icon:
				ability_icon.modulate = Color(1, 0.5, 0.5, 1)
		else:
			if ability_icon:
				ability_icon.modulate = Color.WHITE

	if ability_timer <= 0:
		if ability_icon:
			ability_icon.visible = false
			ability_icon.modulate = Color.WHITE
		Abilities.lock_ability(active_ability)
		active_ability = ""
		ability_timer = 0.0
