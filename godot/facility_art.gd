extends RefCounted
## Visual-only visit state. Never uses the campaign/battle random generator.
const ROOT="res://assets/facilities/"
const STYLES=["papercut","gouache","watercolor_pen"]
var catalog: Dictionary={}
var visit_key := ""
var artwork: Dictionary={}
var texture: Texture2D
var rng=RandomNumberGenerator.new()
var npc=preload("res://facility_npc.gd").new()
func _init():
	rng.randomize()
	var path=ROOT+"manifest.json"
	if FileAccess.file_exists(path):
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:catalog=parsed
func reset():
	visit_key="";artwork={};texture=null
	npc.reset()
func facility(phase: String,location: String,page: String) -> String:
	if phase!="town":return ""
	match page:
		"map":return "departure_map"
		"party":return "guild" if location=="astaris" else ""
		"inn":return "inn" if location=="astaris" else ""
		"shop":return {"east":"weapon","west":"armor","south":"item","north":"accessory"}.get(location,"")
	return ""
func sync(phase: String,location: String,page: String):
	var id=facility(phase,location,page)
	var key=location+":"+id if not id.is_empty() else ""
	if key==visit_key:return
	reset();visit_key=key
	if id.is_empty():return
	npc.sync(id)
	var variants=[]
	var entries=catalog.get(id,[])
	if not entries is Array:return
	for entry in entries:
		if not entry is Dictionary or not STYLES.has(entry.get("style")):continue
		var path=str(entry.get("path",""))
		if not ResourceLoader.exists(path,"Texture2D"):continue
		var candidate=load(path)
		if candidate is Texture2D:variants.append({"entry":entry,"texture":candidate})
	if variants.is_empty():return
	var selected=variants[rng.randi_range(0,variants.size()-1)]
	artwork=selected.entry.duplicate();texture=selected.texture
func backdrop(parent: Control) -> Control:
	if texture==null:return parent
	var panel=PanelContainer.new();panel.name="FacilityBackdrop";panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new());panel.mouse_filter=Control.MOUSE_FILTER_PASS;parent.add_child(panel)
	var image=TextureRect.new();image.name="FacilityStill";image.texture=texture
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(image)
	var shade=ColorRect.new();shade.name="FacilityReadabilityShade";shade.color=Color(.025,.04,.06,.72)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(shade)
	var foreground=VBoxContainer.new();foreground.name="FacilityForeground";foreground.mouse_filter=Control.MOUSE_FILTER_PASS;panel.add_child(foreground)
	return npc.columns(foreground,parent.get_viewport_rect().size.x)
