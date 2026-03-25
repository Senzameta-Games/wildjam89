class_name GroveCamera
extends Camera2D

const VIEWPORT_SIZE: Vector2 = Vector2(640.0, 360.0)
const HALF_VIEWPORT: Vector2 = VIEWPORT_SIZE / 2.0

enum ShakeProfile { NONE, GROUND_STOMP, CHARACTER_STOMP, EMPTY_STOMP }

@export var target_path: NodePath
## Assign the RoomArea for this scene. Camera reads bounds and mode on ready,
## and updates whenever the player enters a new room.
@export var room_area: RoomArea
@export var dead_zone: Vector2 = Vector2(40.0, 20.0)
@export var follow_speed: float = 8.0
@export var transition_speed: float = 4.0

@export_group("Ground Stomp")
## How far the camera dips downward on impact (pixels).
@export var ground_intensity: float = 5.0
## Duration of the downward dip phase (seconds).
@export var ground_down_time: float = 0.05
## Duration of the return phase (seconds).
@export var ground_up_time: float = 0.12
## Small upward pop at the tail of the return (pixels).
@export var ground_overshoot: float = 1.5

@export_group("Character Stomp")
## Peak shake amplitude on character impact (pixels).
@export var character_intensity: float = 4.0
## How quickly the shake decays. Higher = fewer visible hits.
@export var character_decay: float = 14.0
## Oscillation speed (radians/sec). Higher = more rapid shaking.
@export var character_frequency: float = 38.0

var _target: Node2D
var _room_bounds: Rect2
var _transitioning: bool = false
var _has_room: bool = false
var _camera_mode: RoomData.CameraMode = RoomData.CameraMode.FOLLOW

## Editor-assigned Camera2D.offset, captured once. Shake adds on top.
var _base_offset: Vector2 = Vector2.ZERO
var _shake_offset: Vector2 = Vector2.ZERO
var _shake_profile: ShakeProfile = ShakeProfile.NONE
var _shake_elapsed: float = 0.0

func _ready() -> void:
	position_smoothing_enabled = false
	_base_offset = offset
	if target_path:
		_target = get_node(target_path) as Node2D
	if room_area:
		_room_bounds = room_area.get_bounds()
		_has_room = true
		_transitioning = false
		if room_area.data:
			_camera_mode = room_area.data.camera_mode
		_snap_initial_position()
		# Signal wiring is owned by the scene manager (grove.gd/_connect_rooms).
		# room_area export is used here only for initial bounds and mode snap.

func _snap_initial_position() -> void:
	if _camera_mode == RoomData.CameraMode.CLAMP_CENTER:
		global_position = _room_bounds.get_center()
	elif _target:
		global_position = _target.global_position

func set_room_bounds(bounds: Rect2) -> void:
	_room_bounds = bounds
	_transitioning = true
	_has_room = true

func _on_room_entered(room: RoomArea) -> void:
	if room.data:
		_camera_mode = room.data.camera_mode
	set_room_bounds(room.get_bounds())

func _physics_process(delta: float) -> void:
	_update_shake(delta)

	if not _target:
		return

	if _has_room and _camera_mode == RoomData.CameraMode.CLAMP_CENTER:
		_process_clamp_center(delta)
	else:
		_process_follow(delta)

## Quick downward dip then a spring-back with a slight upward pop.
func stomp_ground() -> void:
	_shake_profile = ShakeProfile.GROUND_STOMP
	_shake_elapsed = 0.0

## Decaying multi-directional oscillation — 2-3 visible hits before settling.
func stomp_character() -> void:
	_shake_profile = ShakeProfile.CHARACTER_STOMP
	_shake_elapsed = 0.0

## No feedback. Stub for stomping something that doesn't yield.
func stomp_empty() -> void:
	pass

## Kept for call_group compatibility with non-stomp callers (e.g. bomb).
func apply_shake(_amplitude: Vector2, _fade: float) -> void:
	pass

func _process_clamp_center(delta: float) -> void:
	var target_pos: Vector2 = _room_bounds.get_center()
	if _transitioning:
		global_position = global_position.lerp(target_pos, transition_speed * delta)
		if global_position.distance_to(target_pos) < 1.0:
			global_position = target_pos
			_transitioning = false
	else:
		global_position = target_pos
	global_position = global_position.round()
	offset = _shake_offset

func _process_follow(delta: float) -> void:
	var desired: Vector2 = _compute_desired_position()
	if _transitioning:
		global_position = global_position.lerp(desired, transition_speed * delta)
		if global_position.distance_to(desired) < 1.0:
			global_position = desired
			_transitioning = false
	else:
		global_position = global_position.lerp(desired, follow_speed * delta)
	global_position = global_position.round()
	offset = _base_offset + _shake_offset

func _compute_desired_position() -> Vector2:
	var player_pos: Vector2 = _target.global_position
	var cam_pos: Vector2 = global_position

	var delta_x: float = player_pos.x - cam_pos.x
	var delta_y: float = player_pos.y - cam_pos.y

	var desired_x: float = cam_pos.x
	var desired_y: float = cam_pos.y

	if absf(delta_x) > dead_zone.x:
		desired_x = player_pos.x - signf(delta_x) * dead_zone.x

	if absf(delta_y) > dead_zone.y:
		desired_y = player_pos.y - signf(delta_y) * dead_zone.y

	return Vector2(desired_x, desired_y)

func _update_shake(delta: float) -> void:
	if _shake_profile == ShakeProfile.NONE:
		_shake_offset = Vector2.ZERO
		return

	_shake_elapsed += delta

	match _shake_profile:
		ShakeProfile.GROUND_STOMP:
			var total: float = ground_down_time + ground_up_time
			if _shake_elapsed >= total:
				_end_shake()
			else:
				_shake_offset = _eval_ground_stomp(_shake_elapsed)
		ShakeProfile.CHARACTER_STOMP:
			var amp: float = character_intensity * exp(-character_decay * _shake_elapsed)
			if amp < 0.1:
				_end_shake()
			else:
				# Phase offset of 1.0 rad keeps x and y out of sync
				_shake_offset = Vector2(
					cos(character_frequency * _shake_elapsed),
					sin(character_frequency * _shake_elapsed + 1.0)
				) * amp
		_:
			_end_shake()

func _eval_ground_stomp(t: float) -> Vector2:
	var y: float
	if t < ground_down_time:
		# Linear drop downward
		y = ground_intensity * (t / ground_down_time)
	else:
		var pt: float = (t - ground_down_time) / ground_up_time
		# Return to zero with an upward pop shaped by a sine arch
		y = ground_intensity * (1.0 - pt) - ground_overshoot * sin(PI * pt)
	return Vector2(0.0, y)

func _end_shake() -> void:
	_shake_profile = ShakeProfile.NONE
	_shake_elapsed = 0.0
	_shake_offset = Vector2.ZERO
