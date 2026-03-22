extends Marker2D
class_name Pickup

## A world pickup that the player collects by touching.
## Appearance and behavior are determined by PickupData.
## Spawn via pickup_data.pickup_scene.instantiate(), then call setup(key).

signal collected(pickup_key: String)

@onready var sprite: Sprite2D = $Sprite
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite")
@onready var hitbox_collider: CollisionShape2D = $Hitbox/Collider
@onready var sfx_collect: AudioStreamPlayer2D = $SFX/Collect

var pickup_key: String = ""
var _pickup_data: PickupData

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if animated_sprite:
		animated_sprite.visible = false
	if pickup_key != "":
		_apply_pickup_data()

## Call after instantiation to configure appearance and behavior.
func setup(key: String) -> void:
	pickup_key = key
	if is_node_ready():
		_apply_pickup_data()

func _apply_pickup_data() -> void:
	_pickup_data = Abilities.get_pickup(pickup_key)
	if not _pickup_data:
		push_warning("Pickup: No pickup data found for key '%s'" % pickup_key)
		return

	if _pickup_data.grant_type == PickupData.GrantType.WIN_ITEM:
		# Win items use the animated sprite
		if animated_sprite:
			animated_sprite.visible = true
		if sprite:
			sprite.visible = false
	else:
		# Ability pickups use the static sprite with the icon texture
		if sprite:
			sprite.texture = _pickup_data.icon
			sprite.visible = true
		if animated_sprite:
			animated_sprite.visible = false

	_start_float_animation()

func _start_float_animation() -> void:
	var target_node: Node2D = null
	if animated_sprite and animated_sprite.visible:
		target_node = animated_sprite
	elif sprite and sprite.visible:
		target_node = sprite
	if not target_node:
		return
	var start_y = target_node.position.y
	var tween = create_tween().set_loops()
	tween.tween_property(target_node, "position:y", start_y - 4.0, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(target_node, "position:y", start_y + 4.0, 1.0).set_trans(Tween.TRANS_SINE)

func _on_hitbox_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	hitbox_collider.set_deferred("disabled", true)

	if sprite:
		sprite.visible = false
	if animated_sprite:
		animated_sprite.visible = false

	_on_collected()
	collected.emit(pickup_key)

	if sfx_collect:
		sfx_collect.play()
		await sfx_collect.finished

	queue_free()

func _on_collected() -> void:
	if not _pickup_data:
		return
	match _pickup_data.grant_type:
		PickupData.GrantType.WIN_ITEM:
			Session.win_game()
		PickupData.GrantType.ABILITY:
			pass  # Arcade handles ability unlock via the collected signal
