extends RefCounted
## Local presentation preferences, deliberately separate from campaign saves.
const DEFAULT_DIALOG_SIZE=Vector2(840,620)
const TITLE_HEIGHT=32
const TITLE_MARGIN=Vector2(0,36)
const PATH="user://ui-layout-v1.cfg"
var config=ConfigFile.new()
func _init():config.load(PATH)
func rect_for(key: String,fallback: Rect2,available: Vector2,minimum: Vector2) -> Rect2:
	var value=config.get_value("windows",key,fallback)
	return bounded(value if value is Rect2 else fallback,available,minimum)
func bounded(value: Rect2,available: Vector2,minimum: Vector2) -> Rect2:
	var limit=Vector2(maxf(1,available.x),maxf(1,available.y))
	var extent=value.size.clamp(minimum.min(limit),limit)
	return Rect2(value.position.clamp(Vector2.ZERO,(limit-extent).max(Vector2.ZERO)),extent)
func store_rect(key: String,value: Rect2):
	config.set_value("windows",key,value);save()
func camera() -> Dictionary:
	var value=config.get_value("battle","camera",{})
	return value if value is Dictionary else {}
func store_camera(value: Dictionary):config.set_value("battle","camera",value);save()
func save():
	var error=config.save(PATH)
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
	var area=(available-TITLE_MARGIN).max(Vector2.ONE)
	window.unresizable=false;window.min_size=Vector2i(minimum.min(area))
	var value=config.get_value("windows",key,fallback)
	if not value is Rect2:value=fallback
	# Older versions also saved untouched defaults when a window closed.
	if not config.get_value("layout_origin_v2",key,false):
		if previous.has_area() and value==previous:value=fallback
		config.set_value("layout_origin_v2",key,true)
		if config.has_section_key("windows",key):store_rect(key,value)
	# Stored positions already include the title-bar margin. Bound in the
	# usable coordinate space, then convert back exactly once.
	var rect=bounded(Rect2(value.position-TITLE_MARGIN,value.size),area,minimum)
	window.set_meta("layout_preferred",value)
	window.size=Vector2i(rect.size);window.position=Vector2i(rect.position+TITLE_MARGIN)
	window.set_meta("layout_applied",Rect2(Vector2(window.position),Vector2(window.size)))
	window.set_meta("layout_area",area)

func keep_visible(window: Window,available: Vector2):
	if not is_instance_valid(window) or not window.visible:return
	var area=(available-TITLE_MARGIN).max(Vector2.ONE)
	# Retain the preferred minimum, but allow an already-open child to fit a
	# smaller parent. Restore that minimum when the parent grows again.
	if not window.has_meta("layout_minimum"):window.set_meta("layout_minimum",Vector2(window.min_size))
	var minimum=Vector2(window.get_meta("layout_minimum")).min(area)
	if window.min_size!=Vector2i(minimum) or window.max_size!=Vector2i(area):
		window.min_size=Vector2i.ONE;window.max_size=Vector2i(area);window.min_size=Vector2i(minimum)
	var current=Rect2(Vector2(window.position),Vector2(window.size))
	var preferred=window.get_meta("layout_preferred",current)
	# Only a user resize/move in an unchanged parent updates the preference.
	# Clamping a window to a smaller screen must not become its permanent size.
	if area==window.get_meta("layout_area",area) and current!=window.get_meta("layout_applied",current):preferred=current
	window.set_meta("layout_preferred",preferred)
	var rect=bounded(Rect2(preferred.position-TITLE_MARGIN,preferred.size),area,Vector2(window.min_size))
	window.size=Vector2i(rect.size);window.position=Vector2i(rect.position+TITLE_MARGIN)

	window.set_meta("layout_applied",Rect2(Vector2(window.position),Vector2(window.size)))
	window.set_meta("layout_area",area)
func remember_window(window: Window,key: String):
	var current=Rect2(Vector2(window.position),Vector2(window.size))
	if current!=window.get_meta("layout_applied",current):window.set_meta("layout_preferred",current)
	store_rect(key,window.get_meta("layout_preferred",current))
