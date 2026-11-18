extends RefCounted

# Godot started from the editor must resolve its children before opening any pipes.
static func apply(root: String) -> String:
	var keys := ["NATIVE5525_NODE", "NATIVE5525_PYTHON"]
	var files: Array[String] = []
	if OS.has_environment("AKI_SHARED_ENV_FILE"):
		var shared := OS.get_environment("AKI_SHARED_ENV_FILE").replace("\\", "/")
		if not shared.is_absolute_path() or (OS.get_name() == "Windows" and shared.begins_with("/") and not shared.begins_with("//")):
			return "AKI_SHARED_ENV_FILE に絶対パスを指定してください。"
		files.append(shared)
	elif OS.get_name() == "Windows":
		files.append(FileAccess.get_file_as_string("res://windows-shared-env.txt").strip_edges())
	files.append(root.path_join(".env"))
	var selected := {}
	for path in files:
		if selected.size() == keys.size():
			break
		if DirAccess.dir_exists_absolute(path):
			return ".env にファイルを指定してください。"
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return ".env を読み込めません。"
		var entries := {}
		while file.get_position() < file.get_length():
			var parts := file.get_line().trim_prefix("\uFEFF").split("=", true, 1)
			var key := parts[0].strip_edges()
			if parts.size() != 2 or not keys.has(key) or selected.has(key):
				continue
			if entries.has(key):
				return ".env の設定が重複しています: " + key
			var value := parts[1].strip_edges()
			if value.begins_with('"') or value.begins_with("'"):
				if value.length() < 2 or value[-1] != value[0]:
					return ".env の引用符を確認してください: " + key
				value = value.substr(1, value.length() - 2)
			entries[key] = [value, path.get_base_dir()]
		selected.merge(entries)
	for key in keys:
		if not selected.has(key) and OS.has_environment(key):
			selected[key] = [OS.get_environment(key), root]
	for key in selected:
		var entry: Array = selected[key]
		var value: String = entry[0].replace("\\", "/")
		var path := value if value.is_absolute_path() else str(entry[1]).path_join(value)
		if value.strip_edges().is_empty() or not FileAccess.file_exists(path):
			return "%s に実行ファイルを指定してください。" % key
		selected[key] = path.simplify_path()
	for key in selected:
		OS.set_environment(key, selected[key])
	return ""
