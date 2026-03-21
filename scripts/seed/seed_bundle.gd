extends Node2D

@export var min_amount: int = 5
@export var max_amount: int = 15
@onready var amount: int = randi_range(min_amount, max_amount)

@onready var label: Label = $Label
@onready var sfx_collect: AudioStreamPlayer2D = $SFX/Collect
var collected: bool = false

func _ready() -> void:
	if label:
		label.text = str(amount)
	_start_lifespan()

func _on_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_collect()

func _collect() -> void:
	Economy.add_seeds(amount)
	$Area/Collider.set_deferred("disabled", true)
	visible = false
	
	if sfx_collect:
		sfx_collect.play()
		await sfx_collect.finished
	
	queue_free()
	
func _start_lifespan() -> void:
	await get_tree().create_timer(5.0).timeout
	if collected: return
	
	var tween = create_tween().set_loops()
	tween.tween_property(self, "modulate:a", 0.3, 0.0)
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
	
	await get_tree().create_timer(3.0).timeout
	if collected: return
	
	queue_free()
