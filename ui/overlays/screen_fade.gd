## Full-screen fade overlay. Registered as the ScreenFade autoload so any
## state or system can trigger a fade without coupling to a scene node.
## Sits on layer 200 — above TitleScreen (101) and GameOver (99).
## process_mode = ALWAYS so fades work while the scene tree is paused.
extends CanvasLayer

var _rect: ColorRect
var _tween: Tween

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS

	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	add_child(_rect)

## Fade the screen to opaque black. Await this to block until the fade finishes.
func fade_to_black(duration: float = 0.4) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_rect, "modulate:a", 1.0, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await _tween.finished

## Fade from black to transparent. Fire-and-forget or await as needed.
func fade_from_black(duration: float = 0.5) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_rect, "modulate:a", 0.0, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await _tween.finished

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
