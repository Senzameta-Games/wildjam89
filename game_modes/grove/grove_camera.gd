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
## Seconds the player must stay outside the dead zone before the camera starts following.
@export var follow_delay: float = 0.2
## Lerp speed while actively chasing the player outside the dead zone.
@export var follow_speed: float = 6.0
## Lerp speed while easing back to the ideal framing after catching up. Lower = longer glide.
@export var follow_rest_speed: float = 1.5
## Transition speed when panning between two clamped rooms.
@export var transition_speed_clamp_clamp: float = 6.0
## Transition speed when the camera enters or leaves follow mode.
@export var transition_speed_follow: float = 3.0
## Positional bias applied to the follow target in FOLLOW mode only.
## Positive Y moves the frame down (shows more below the player); negative moves it up.
@export var follow_offset: Vector2 = Vector2(0.0, -32.0)
## How far ahead of the player the camera looks in the direction of horizontal movement.
## Compensates for dead-zone lag so the player sees more of what's ahead, less of what's behind.
@export var look_ahead: float = 0.0

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
var _initialized: bool = false
## Blocks _on_room_entered for one physics frame after initialize() to prevent
## spurious signals from initial physics overlap detection (player starts at
## world 0,0 which is inside Grove's 1920x1080 area before spawn placement runs).
var _ignore_room_changes: bool = true

## Editor-assigned Camera2D.offset, captured once. Shake adds on top.
var _base_offset: Vector2 = Vector2.ZERO
## Logical camera position, driven by follow/clamp logic each frame.
## Shake is kept separate so it never interferes with transitions.
var _base_position: Vector2 = Vector2.ZERO
var _shake_offset: Vector2 = Vector2.ZERO
var _shake_profile: ShakeProfile = ShakeProfile.NONE
var _shake_elapsed: float = 0.0
## Accumulated time the player has been outside the dead zone. Resets on re-entry.
var _follow_delay_elapsed: float = 0.0
## Active transition speed, set when a room transition begins based on the mode pair.
var _active_transition_speed: float = 3.0

func _ready() -> void:
	position_smoothing_enabled = false
	_base_offset = offset
	_base_position = global_position
	if target_path:
		_target = get_node(target_path) as Node2D
	if room_area:
		_room_bounds = room_area.get_bounds()
		_has_room = true
		if room_area.data:
			_camera_mode = room_area.data.camera_mode
		# Position snap is deferred to the first physics frame so that grove.gd's
		# _ready() (which runs after camera's _ready() as the parent) has time to
		# position the player at their spawn before we read _target.global_position.
		# Signal wiring is owned by the scene manager (grove.gd/_connect_rooms).

func _snap_initial_position() -> void:
	# For center-locked rooms, lerp from player position to room center rather
	# than snapping directly — this is the visible "pan on load" the player sees.
	if _has_room and _camera_mode == RoomData.CameraMode.CLAMP_CENTER:
		_transitioning = true

func set_room_bounds(bounds: Rect2) -> void:
	_room_bounds = bounds
	_has_room = true
	# Only start a transition if the camera isn't already at (or very near) the
	# target center. This prevents a spurious lerp when the initial room's Area2D
	# fires body_entered on the first physics step after the camera is already
	# correctly placed at that room's center by initialize().
	var center: Vector2 = bounds.get_center()
	if _base_position.distance_to(center) > 2.0:
		_transitioning = true

func _on_room_entered(room: RoomArea) -> void:
	if _ignore_room_changes:
		return
	var prev_mode: RoomData.CameraMode = _camera_mode
	if room.data:
		_camera_mode = room.data.camera_mode
	_active_transition_speed = _pick_transition_speed(prev_mode, _camera_mode)
	set_room_bounds(room.get_bounds())

func _pick_transition_speed(from: RoomData.CameraMode, to: RoomData.CameraMode) -> float:
	if from == RoomData.CameraMode.CLAMP_CENTER and to == RoomData.CameraMode.CLAMP_CENTER:
		return transition_speed_clamp_clamp
	return transition_speed_follow

## Called by the scene manager (grove.gd) immediately after the player is positioned
## at their spawn. Snaps the camera to the correct starting position so there is no
## one-frame flash at the scene's origin before the first _physics_process runs.
func initialize(initial_room: RoomArea) -> void:
	# Apply the initial room directly — do not go through _on_room_entered, which
	# is gated by _ignore_room_changes and is reserved for runtime room transitions.
	if initial_room:
		if initial_room.data:
			_camera_mode = initial_room.data.camera_mode
		_room_bounds = initial_room.get_bounds()
		_has_room = true
	if _has_room and _camera_mode == RoomData.CameraMode.CLAMP_CENTER:
		# CLAMP_CENTER: start at room center directly — no pan needed on load.
		_base_position = _room_bounds.get_center()
		_transitioning = false
	elif _target:
		# Start at the natural resting position (player + follow_offset) so the
		# camera has nothing to animate toward on load and the wiggle disappears.
		_base_position = _target.global_position + follow_offset
	global_position = _base_position.round()
	_initialized = true
	# Unblock room-change handling after one physics frame. This prevents the
	# spurious body_entered signal that fires because the player's initial (0,0)
	# position sits inside the Grove room area before spawn placement runs.
	call_deferred("_allow_room_changes")

func _allow_room_changes() -> void:
	_ignore_room_changes = false

func _physics_process(delta: float) -> void:
	if not _initialized:
		_initialized = true
		_snap_initial_position()

	_update_shake(delta)

	if not _target:
		return

	if _has_room and _camera_mode == RoomData.CameraMode.CLAMP_CENTER:
		_process_clamp_center(delta)
	else:
		_process_follow(delta)

	# All camera effects write to their own variables; assemble here so that
	# shake, transitions, and follow are always fully composable and additive.
	global_position = (_base_position + _shake_offset).round()
	offset = _base_offset

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
		_base_position = _base_position.lerp(target_pos, _active_transition_speed * delta)
		if _base_position.distance_to(target_pos) < 1.0:
			_base_position = target_pos
			_transitioning = false
	else:
		_base_position = target_pos

func _process_follow(delta: float) -> void:
	var desired: Vector2 = _compute_desired_position()
	if _transitioning:
		_follow_delay_elapsed = 0.0
		_base_position = _base_position.lerp(desired, _active_transition_speed * delta)
		if _base_position.distance_to(desired) < 1.0:
			_base_position = desired
			_transitioning = false
		return

	# Inside dead zone: ease slowly toward the ideal framing center so motion
	# tapers out smoothly rather than cutting off when the chase ends.
	if desired.distance_to(_base_position) < 0.5:
		_follow_delay_elapsed = 0.0
		var rest_target: Vector2 = _target.global_position + follow_offset
		if _base_position.distance_to(rest_target) > 0.5:
			_base_position = _base_position.lerp(rest_target, follow_rest_speed * delta)
		return

	# Accumulate time outside dead zone. Camera waits before committing to follow.
	_follow_delay_elapsed += delta
	if _follow_delay_elapsed < follow_delay:
		return

	# Actively following: lerp toward the dead-zone edge behind the player.
	_base_position = _base_position.lerp(desired, follow_speed * delta)

func _compute_desired_position() -> Vector2:
	var player_pos: Vector2 = _target.global_position
	# Offset the tracked point ahead of the player so the camera leads rather
	# than lags. Only activates when the player is moving; snaps back when idle.
	if look_ahead > 0.0:
		var body := _target as CharacterBody2D
		if body and absf(body.velocity.x) > 10.0:
			player_pos.x += signf(body.velocity.x) * look_ahead
	# Bias the tracking point by follow_offset so the dead zone is measured
	# against the actual rendered camera center. Adding it here (rather than
	# after the return) prevents the offset from accumulating into _base_position
	# every frame and breaking dead-zone tracking.
	player_pos += follow_offset
	var cam_pos: Vector2 = _base_position

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
