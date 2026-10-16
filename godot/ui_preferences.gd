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
	window.unresizable=false;window.min_size=Vector2i(minimum.min(available))
	var rect=rect_for(key,Rect2((available-extent)/2,extent),available,minimum)
	window.size=Vector2i(rect.size);window.position=Vector2i(rect.position.max(Vector2(0,36)))
	# tree_exiting covers close, cancel, selection and application teardown.
	window.tree_exiting.connect(func():store_rect(key,Rect2(Vector2(window.position),Vector2(window.size))))

func keep_visible(window: Window,available: Vector2):
	if not is_instance_valid(window) or not window.visible:return
	var margin=Vector2(0,36)
	var area=(available-margin).max(Vector2.ONE)
	window.max_size=Vector2i(area)
	var rect=bounded(Rect2(Vector2(window.position)-margin,Vector2(window.size)),area,Vector2(window.min_size))
	window.size=Vector2i(rect.size);window.position=Vector2i(rect.position+margin)
