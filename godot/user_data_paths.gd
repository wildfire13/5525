extends RefCounted
## Stores client profile, settings, diagnostics, and default save location
## inside `<client_dir>/user-data/` during normal play, while keeping `user://`
## isolation intact for `--script` QA/regression runners.

static func _is_script_run() -> bool:
	for arg in OS.get_cmdline_args():
		if arg == "--script" or arg == "-s" or arg.begins_with("--script="):
			return true
	return false

static func base_dir() -> String:
	var env_dir := OS.get_environment("NATIVE5525_USER_DATA_DIR").strip_edges()
	var root := ""
	if not env_dir.is_empty():
		root = env_dir
	elif _is_script_run():
		root = OS.get_user_data_dir()
	elif OS.has_feature("standalone"):
		root = OS.get_executable_path().get_base_dir().path_join("user-data")
	else:
		root = ProjectSettings.globalize_path("res://").path_join("user-data")
	DirAccess.make_dir_recursive_absolute(root)
	return root

static func file_path(rel: String) -> String:
	var full := base_dir().path_join(rel)
	DirAccess.make_dir_recursive_absolute(full.get_base_dir())
	return full
