extends CanvasLayer
## Displays generic system toasts (save, load confirmations).
## Add to the main scene. Listens to Saves.save_toast and instantiates
## Toast scenes on demand — no queue, since save/load events are infrequent.

var _toast_scene: PackedScene = preload("res://ui/overlays/toast.tscn")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Saves.save_toast.connect(_on_save_toast)

func _on_save_toast(message: String) -> void:
	var toast := _toast_scene.instantiate() as Toast
	add_child(toast)
	toast.show_text(message)
