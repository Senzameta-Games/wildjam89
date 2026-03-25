class_name RoomData
extends Resource

enum RoomType { TUTORIAL, GROVE, RUN, SAFE }

## FOLLOW: camera tracks the player with a dead zone (large/open rooms).
## CLAMP_CENTER: camera locks to the room center (viewport-sized rooms).
enum CameraMode { FOLLOW, CLAMP_CENTER }

@export_category("Identity")
@export var room_name: StringName
@export var room_type: RoomType = RoomType.TUTORIAL

@export_category("Progression")
## StringName key for what clears this room (e.g. &"collect_stomp", &"defeat_all_bugs").
## Empty means no clear condition (always open).
@export var clear_condition: StringName = &""

@export_category("Camera")
@export var camera_mode: CameraMode = CameraMode.FOLLOW

@export_category("States")
## The initial state this room starts in (e.g. &"locked", &"tutorial", &"unlocked").
@export var initial_state: StringName = &"locked"
