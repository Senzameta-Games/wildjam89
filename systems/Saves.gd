extends Node

const SAVE_DIR := "user://saves/"
const META_FILE := "user://saves/meta.json"
const RUN_FILE := "user://saves/run.json"
const SAVE_VERSION: int = 2

# -- Migration functions --
# Each function transforms a save dict from version N to version N+1.
# They run in sequence: if a save is v1 and current is v3, it runs v1->v2 then v2->v3.
# Migrations operate on the raw Dictionary before it reaches any system's deserialize().

var _migrations: Dictionary = {
	# Add transforms here when bumping SAVE_VERSION.
	# Key = version the save is currently at. Value = function that transforms it forward.
	# Name functions after what they do, not the versions they bridge:
	# 1: _add_tree_data_fields,
	# 2: _rename_seed_value_from_energy,
}

func _migrate_save(save_data: Dictionary) -> Dictionary:
	var version: int = save_data.get("version", 1)

	if version > SAVE_VERSION:
		push_warning("[Saves] Save version %d is newer than game version %d. Loading anyway." % [version, SAVE_VERSION])
		return save_data

	while version < SAVE_VERSION:
		if _migrations.has(version):
			print("[Saves] Migrating save from v%d to v%d" % [version, version + 1])
			save_data = _migrations[version].call(save_data)
			version += 1
		else:
			push_error("[Saves] No migration path from v%d to v%d. Aborting load." % [version, version + 1])
			return {}

	save_data["version"] = SAVE_VERSION
	return save_data

# -- Migration utilities --

## Rename a key in a nested dictionary path.
## Example: _rename_key(save_data, ["abilities"], "old_key", "new_key")
func _rename_key(dict: Dictionary, path: Array, old_key: String, new_key: String) -> void:
	var target = dict
	for p in path:
		if target.has(p) and target[p] is Dictionary:
			target = target[p]
		else:
			return
	if target.has(old_key):
		target[new_key] = target[old_key]
		target.erase(old_key)

## Remove a key from a nested dictionary path.
## Example: _remove_key(save_data, ["session"], "deprecated_field")
func _remove_key(dict: Dictionary, path: Array, key: String) -> void:
	var target = dict
	for p in path:
		if target.has(p) and target[p] is Dictionary:
			target = target[p]
		else:
			return
	target.erase(key)

## Add a key with a default value if it doesn't exist.
## Example: _add_default(save_data, ["tree"], "new_field", 0.0)
func _add_default(dict: Dictionary, path: Array, key: String, default_value: Variant) -> void:
	var target = dict
	for p in path:
		if target.has(p) and target[p] is Dictionary:
			target = target[p]
		else:
			return
	if not target.has(key):
		target[key] = default_value

var _player: Player = null
var _arcade: Arcade = null
var _pending_run_data: Dictionary = {}
var _restoring_run: bool = false  # survives the scene reload; cleared by TitleScreen._ready()

func _ready() -> void:
	load_meta()

# ---- Registration ----

func register_player(node: Player) -> void:
	_player = node

func unregister_player() -> void:
	_player = null

func register_arcade(node: Arcade) -> void:
	_arcade = node

func unregister_arcade() -> void:
	_arcade = null

func is_restoring_run() -> bool:
	return _restoring_run

func finish_run_restore() -> void:
	_restoring_run = false

# ---- Pending run load handshake (used by Arcade._ready) ----

func has_pending_run_load() -> bool:
	return not _pending_run_data.is_empty()

func consume_pending_run_data() -> Dictionary:
	var data := _pending_run_data.duplicate()
	_pending_run_data.clear()
	return data

# ---- Meta save ----

func write_meta() -> void:
	_ensure_save_dir()
	var data := {
		"version": SAVE_VERSION,
		"unlocked_achievements": Achievements.serialize_meta()["unlocked_achievements"],
		"tutorial_completed": Tutorial.serialize_meta()["tutorial_completed"],
	}
	_write_json(META_FILE, data)
	print("[Saves] meta written")

func load_meta() -> void:
	if not FileAccess.file_exists(META_FILE):
		print("[Saves] no meta save found")
		return
	var data := _read_json(META_FILE)
	if data.is_empty():
		return
	data = _migrate_save(data)
	if data.is_empty():
		push_error("[Saves] Meta migration failed, starting fresh")
		return
	Achievements.deserialize_meta(data)
	Tutorial.deserialize_meta(data)
	print("[Saves] meta loaded")

# ---- Run save ----

func write_run() -> void:
	if _player == null or _arcade == null:
		push_error("[Saves] write_run called but player or arcade is not registered")
		return
	_ensure_save_dir()

	var trees_data: Array = []
	for tree in get_tree().get_nodes_in_group("tree"):
		if tree.has_method("serialize"):
			trees_data.append(tree.serialize())

	var data := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"session": Session.serialize(),
		"economy": Economy.serialize(),
		"abilities": Abilities.serialize(),
		"achievements_run": Achievements.serialize_run(),
		"flower_manager": FlowerManager.serialize(),
		"arcade": _arcade.serialize(),
		"player": _player.serialize(),
		"trees": trees_data,
	}
	_write_json(RUN_FILE, data)
	print("[Saves] run written (stage %d, %d trees)" % [Session.current_stage, trees_data.size()])

func load_run() -> void:
	if not FileAccess.file_exists(RUN_FILE):
		print("[Saves] no run save found")
		return
	var data := _read_json(RUN_FILE)
	if data.is_empty():
		return
	data = _migrate_save(data)
	if data.is_empty():
		push_error("[Saves] Run migration failed, starting fresh")
		return
	_pending_run_data = data
	_restoring_run = true
	print("[Saves] run data cached — will apply when Arcade is ready")

func has_run_save() -> bool:
	return FileAccess.file_exists(RUN_FILE)

func delete_run_save() -> void:
	if FileAccess.file_exists(RUN_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_FILE))
		print("[Saves] run save deleted")

# ---- Internal helpers ----

func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SAVE_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))

func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[Saves] could not open %s for writing" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[Saves] could not open %s for reading" % path)
		return {}
	var text := file.get_as_text()
	file.close()
	var result = JSON.parse_string(text)
	if result == null:
		push_error("[Saves] failed to parse JSON from %s" % path)
		return {}
	return result

# ---- Debug ----

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_clear_saves"):
		debug_clear_saves()

func debug_clear_saves() -> void:
	delete_run_save()
	if FileAccess.file_exists(META_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(META_FILE))
		print("[Saves] meta save deleted")
	Tutorial.reset_tutorial()
	print("[Saves] all saves cleared — reloading scene")
	get_tree().reload_current_scene()

func debug_print_run_save() -> void:
	if not FileAccess.file_exists(RUN_FILE):
		print("[Saves] no run save on disk")
		return
	var data := _read_json(RUN_FILE)
	print("[Saves] run save:\n", JSON.stringify(data, "\t"))

func debug_print_meta_save() -> void:
	if not FileAccess.file_exists(META_FILE):
		print("[Saves] no meta save on disk")
		return
	var data := _read_json(META_FILE)
	print("[Saves] meta save:\n", JSON.stringify(data, "\t"))
