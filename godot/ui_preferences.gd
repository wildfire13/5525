extends RefCounted
## Local presentation preferences, deliberately separate from campaign saves.
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

func bind_window(window: Window,key: String,available: Vector2,extent: Vector2,minimum:=Vector2(420,300)):
	window.set_meta("managed_layout",true)
	window.set_meta("layout_minimum",minimum)
	var margin=Vector2(0,36);var area=(available-margin).max(Vector2.ONE)
	window.unresizable=false;window.min_size=Vector2i(minimum.min(area))
	var fallback=Rect2((area-extent)/2+margin,extent)
	var value=config.get_value("windows",key,fallback)
	if not value is Rect2:value=fallback
	# Stored positions already include the title-bar margin. Bound in the
	# usable coordinate space, then convert back exactly once.
	var rect=bounded(Rect2(value.position-margin,value.size),area,minimum)
	window.size=Vector2i(rect.size);window.position=Vector2i(rect.position+margin)
	# tree_exiting covers close, cancel, selection and application teardown.
	window.tree_exiting.connect(func():store_rect(key,Rect2(Vector2(window.position),Vector2(window.size))))

func keep_visible(window: Window,available: Vector2):
	if not is_instance_valid(window) or not window.visible:return
	var margin=Vector2(0,36)
	var area=(available-margin).max(Vector2.ONE)
	# Retain the preferred minimum, but allow an already-open child to fit a
	# smaller parent. Restore that minimum when the parent grows again.
	if not window.has_meta("layout_minimum"):window.set_meta("layout_minimum",Vector2(window.min_size))
	var minimum=Vector2(window.get_meta("layout_minimum")).min(area)
	if window.min_size!=Vector2i(minimum) or window.max_size!=Vector2i(area):
		window.min_size=Vector2i.ONE;window.max_size=Vector2i(area);window.min_size=Vector2i(minimum)
	var rect=bounded(Rect2(Vector2(window.position)-margin,Vector2(window.size)),area,Vector2(window.min_size))
	window.size=Vector2i(rect.size);window.position=Vector2i(rect.position+margin)
