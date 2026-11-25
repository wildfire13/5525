extends RefCounted
## Visual-only visit state. Never uses the campaign/battle random generator.
const ROOT="res://assets/facilities/"
const DEFAULT_ROAD_PATH="res://assets/roads/bg_road_forest.png"
const BACKGROUND_EFFECTS = {
	DEFAULT_ROAD_PATH: preload("res://shaders/forest_clouds.tres"),
	"res://assets/towns/bg_village_east.png": preload("res://shaders/east_river.tres"),
}
const TOWN_SKY = preload("res://shaders/town_sky/clouds.tres")
const SKY_MASKS = {
	"res://assets/towns/bg_town_astaris.png": preload("res://shaders/town_sky/astaris.png"),
	"res://assets/towns/bg_village_east.png": preload("res://shaders/town_sky/east.png"),
	"res://assets/towns/bg_village_north.png": preload("res://shaders/town_sky/north.png"),
	"res://assets/towns/bg_village_south.png": preload("res://shaders/town_sky/south.png"),
	"res://assets/towns/bg_village_west.png": preload("res://shaders/town_sky/west.png"),
}
var effects_enabled := true
const STYLES=["interior","papercut","gouache","watercolor_pen"]
var catalog: Dictionary={}
var visit_key := ""
var artwork: Dictionary={}
var texture: Texture2D
var road_texture: Texture2D
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
		"party":return "guild" if location=="astaris" else ""
		"inn":return "inn" if location=="astaris" else ""
		"shop":return {"east":"weapon","west":"armor","south":"item","north":"accessory"}.get(location,"")
	return ""
func sync(phase: String,location: String,page: String):
	# Information tabs do not move the party out of the current facility.
	if phase=="town" and page in ["character","board","items"] and visit_key.begins_with(location+":"):return
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
func default_road_texture() -> Texture2D:
	if road_texture==null and ResourceLoader.exists(DEFAULT_ROAD_PATH,"Texture2D"):
		var loaded=load(DEFAULT_ROAD_PATH)
		if loaded is Texture2D:road_texture=loaded
	return road_texture
func render_background(parent: Control,ui,battle: bool):
	var c=ui.campaign()
	if battle or c.is_empty():
		if parent.get_child_count()>0:ui.clear(parent)
		return
	if c.get("phase")!="town":
		fullscreen(parent,ui.preferences,default_road_texture(),"RoadStill")
		return
	ui.pages.hub_view.select_art(str(c.get("location","")))
	var town_art=ui.pages.hub_view.artwork
	var town_texture=load(town_art.path) if texture==null and not town_art.is_empty() else null
	fullscreen(parent,ui.preferences,town_texture)
func fullscreen(parent: Control,preferences,fallback_texture: Texture2D=null,fallback_name: String="TownStill"):
	var selected=texture if texture!=null else fallback_texture
	if selected==null:
		for child in parent.get_children():
			parent.remove_child(child);child.queue_free()
		return
	# Reuse the same background nodes across tab/selection redraws.
	var image=parent.get_node_or_null("FacilityStill")
	if image==null:image=parent.get_node_or_null("TownStill")
	if image==null:image=parent.get_node_or_null("RoadStill")
	if image==null:
		image=TextureRect.new();image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(image);image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.name="FacilityStill" if texture!=null else fallback_name
	if image.texture!=selected:image.texture=selected
	image.material = BACKGROUND_EFFECTS.get(selected.resource_path) if effects_enabled else null
	update_sky(image, preferences, SKY_MASKS.get(selected.resource_path) if effects_enabled else null)
	var shade=image.get_node_or_null("FacilityReadabilityShade")
	if shade==null:
		shade=ColorRect.new();shade.name="FacilityReadabilityShade";shade.color=Color(.025,.04,.06,.12)
		shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;image.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# NPC portraits are positioned by the facility entry or service view.
func update_sky(image: TextureRect, preferences, mask: Texture2D):
	var sky := image.get_node_or_null("TownSky") as TextureRect
	if sky == null and mask != null:
		sky = preload("res://shaders/town_sky/town_sky.gd").new()
		sky.preferences = preferences
		sky.name = "TownSky"
		sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sky.expand_mode = image.expand_mode
		sky.stretch_mode = image.stretch_mode
		sky.material = TOWN_SKY.duplicate()
		image.add_child(sky)
		image.move_child(sky, 0)
		sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if sky != null:
		sky.texture = mask
		sky.visible = mask != null

func backdrop(parent: Control) -> Control:
	var foreground=VBoxContainer.new();foreground.name="FacilityForeground";foreground.mouse_filter=Control.MOUSE_FILTER_PASS;foreground.size_flags_vertical=Control.SIZE_EXPAND_FILL;parent.add_child(foreground)
	return foreground
