extends RefCounted
const Grid=preload("res://screen_grid.gd")
const WindowGrid=preload("res://window_grid.gd")
const Tokens=preload("res://ui_tokens.gd")
## Local presentation preferences, deliberately separate from campaign saves.
const DEFAULT_DIALOG_SIZE=Vector2(840,620)
const TITLE_HEIGHT=Tokens.WINDOW_BAR_HEIGHT
const TITLE_MARGIN=Vector2(0,Tokens.WINDOW_BAR_HEIGHT+Tokens.SPACE_XS)
const UserDataPaths=preload("res://user_data_paths.gd")
const SETTINGS_FILE="ui-layout-v1.cfg"
var config=ConfigFile.new()
const DEFAULT_CLOUD_SPEED := 0.1
const MAX_CLOUD_SPEED := 1.0
var cloud_speed := DEFAULT_CLOUD_SPEED
var reduced_motion := false

func _path() -> String:
	return UserDataPaths.file_path(SETTINGS_FILE)

func _init():
	config.load(_path())
	var stored = config.get_value("background", "cloud_speed", DEFAULT_CLOUD_SPEED)
	if (stored is float or stored is int) and is_finite(float(stored)):
		cloud_speed = clampf(float(stored), 0.0, MAX_CLOUD_SPEED)
	reduced_motion = bool(config.get_value("motion", "reduced_motion", false))

func store_cloud_speed(value: float):
	cloud_speed = clampf(value, 0.0, MAX_CLOUD_SPEED)
	config.set_value("background", "cloud_speed", cloud_speed)
	save()

func store_reduced_motion(value: bool):
	reduced_motion = value
	config.set_value("motion", "reduced_motion", reduced_motion)
	save()

func rect_for(key: String,fallback: Rect2,available: Vector2,minimum: Vector2) -> Rect2:
	var value=config.get_value("windows",key,fallback)
	return bounded(value if value is Rect2 else fallback,available,minimum)
func bounded(value: Rect2,available: Vector2,minimum: Vector2) -> Rect2:
	return Grid.snap_rect(value,available,minimum)
func store_rect(key: String,value: Rect2):
	config.set_value("windows",key,value);save()
func camera() -> Dictionary:
	var value=config.get_value("battle","camera",{})
	return value if value is Dictionary else {}
func store_camera(value: Dictionary):config.set_value("battle","camera",value);save()
func save():
	var error=config.save(_path())
	if error!=OK:push_warning("UI preferences could not be saved: %s" % error)

func default_window_rect(available: Vector2,extent: Vector2) -> Rect2:
	return Rect2((available-DEFAULT_DIALOG_SIZE)/2,extent)

func overlay_rect(available: Vector2,extent: Vector2,inset:=0.0) -> Rect2:
	var frame=default_window_rect(available,extent)
	var padding=Vector2.ONE*inset
	frame.position-=padding+Vector2(0,TITLE_HEIGHT)
	frame=bounded(frame,available-padding*2,Vector2.ONE)
	frame.position+=padding
	return frame

func bind_window(window: Window,key: String,available: Vector2,extent: Vector2,minimum:=Vector2(420,300)):
	var previous=Rect2((available-extent+TITLE_MARGIN)/2,extent)
	place_window(window,key,available,default_window_rect(available,extent),minimum,previous)
	window.tree_exiting.connect(func():remember_window(window,key))

func place_window(window: Window,key: String,available: Vector2,fallback: Rect2,minimum:=Vector2(420,300),previous:=Rect2()):
	window.set_meta("managed_layout",true)
	window.set_meta("layout_minimum",minimum)
	var bounds=window_bounds(window,available)
	var area=bounds.size.max(Vector2.ONE)
	window.unresizable=false;window.min_size=Vector2i(minimum.min(area))
	var value=config.get_value("windows",key,fallback)
	if not value is Rect2:value=fallback
	# Older versions also saved untouched defaults when a window closed.
	if not config.get_value("layout_origin_v2",key,false):
		if previous.has_area() and value==previous:value=fallback
		config.set_value("layout_origin_v2",key,true)
		if config.has_section_key("windows",key):store_rect(key,value)
	# Preferences use game coordinates; native windows also need the desktop origin.
	var rect=Grid.snap_rect(value,available,minimum,bounds)
	window.set_meta("layout_preferred",value)
	window.size=Vector2i(rect.size);window.position=Vector2i(rect.position+window_origin(window))
	window.set_meta("layout_applied",rect)
	window.set_meta("layout_area",area)

func keep_visible(window: Window,available: Vector2):
	if not is_instance_valid(window) or not window.visible:return
	var bounds=window_bounds(window,available)
	var area=bounds.size.max(Vector2.ONE)
	# Retain the preferred minimum, but allow an already-open child to fit a
	# smaller parent. Restore that minimum when the parent grows again.
	if not window.has_meta("layout_minimum"):window.set_meta("layout_minimum",Vector2(window.min_size))
	var minimum=Vector2(window.get_meta("layout_minimum")).min(area)
	var bounds_changed=window.min_size!=Vector2i(minimum) or window.max_size!=Vector2i(area)
	if bounds_changed:
		window.min_size=Vector2i.ONE;window.max_size=Vector2i(area);window.min_size=Vector2i(minimum)
	var current=Rect2(Vector2(window.position)-window_origin(window),Vector2(window.size))
	if not bounds_changed and area==window.get_meta("layout_area",Vector2.ZERO) and current==window.get_meta("layout_applied",Rect2()):
		return
	var preferred=window.get_meta("layout_preferred",current)
	# Only a user resize/move in an unchanged parent updates the preference.
	# Clamping a window to a smaller screen must not become its permanent size.
	if area==window.get_meta("layout_area",area) and current!=window.get_meta("layout_applied",current):preferred=current
	window.set_meta("layout_preferred",preferred)
	var rect=Grid.snap_rect(preferred,available,Vector2(window.min_size),bounds)
	window.size=Vector2i(rect.size);window.position=Vector2i(rect.position+window_origin(window))

	window.set_meta("layout_applied",Rect2(Vector2(window.position)-window_origin(window),Vector2(window.size)))
	window.set_meta("layout_area",area)
func remember_window(window: Window,key: String):
	var current=Rect2(Vector2(window.position)-window_origin(window),Vector2(window.size))
	if current!=window.get_meta("layout_applied",current):window.set_meta("layout_preferred",current)
	store_rect(key,window.get_meta("layout_preferred",current))

func window_origin(window: Window) -> Vector2:
	return Vector2.ZERO if window.is_embedded() else Vector2(window.get_tree().root.position)

func place_detail_frame(window: Window,frame: Rect2=Rect2()):
	if window.is_embedded():window.borderless=true
	window.unresizable=true
	var view=Vector2(window.get_tree().root.size)
	var rect=frame if frame.has_area() else WindowGrid.modal_frame_rect(view)
	window.position=Vector2i(rect.position+window_origin(window))
	window.size=Vector2i(rect.size)
	window.set_meta("managed_layout",true)
	window.set_meta("layout_minimum",rect.size)
	window.set_meta("layout_preferred",rect)
	window.set_meta("layout_applied",rect)
	window.set_meta("layout_area",Grid.cell_rect(view,0,1,10,8).size)

func place_confirm_frame(window: Window,box: Rect2i=Rect2i()):
	var view=Vector2(window.get_tree().root.size)
	if box.has_area():
		place_detail_frame(window,WindowGrid.grid_frame_rect(view,box))
	elif window.get("grid_box") is Rect2i and window.grid_box.has_area():
		place_detail_frame(window,WindowGrid.grid_frame_rect(view,window.grid_box))
	else:
		place_detail_frame(window,WindowGrid.confirm_frame_rect(view))

func window_bounds(window: Window,available: Vector2) -> Rect2:
	# Godot draws a decorated embedded title bar above its client rectangle.
	var first=2 if window.is_embedded() and not window.borderless else 1
	return Grid.cell_rect(available,0,first,10,9-first)
