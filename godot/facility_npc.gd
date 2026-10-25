extends RefCounted
## Visit-only decoration. Selection never consumes campaign or background RNG.
const ROOT="res://assets/facility_npcs/"
const CATALOG={"weapon":["weapon1.png","weapon2.png"],"armor":["armor.png"],"item":["item.png"],"accessory":["accessory.png"],"inn":["inn.png"],"guild":["guild.png"]}
var visit_key := ""
var selected_path := ""
var texture: Texture2D
var rng=RandomNumberGenerator.new()
func _init():rng.randomize()
func reset():visit_key="";selected_path="";texture=null
func sync(facility: String):
	if facility==visit_key:return
	reset()
	if not CATALOG.has(facility):return
	visit_key=facility
	var choices: Array=CATALOG[facility]
	# The two weapon keepers have equal probability; repeat visits may match.
	selected_path=ROOT+str(choices[rng.randi_range(0,choices.size()-1)] if choices.size()>1 else choices[0])
	if ResourceLoader.exists(selected_path,"Texture2D"):texture=load(selected_path)
func available(viewport: Vector2) -> bool:
	return texture!=null and viewport.x>=1120 and viewport.y>=720
func portrait_layer(parent: Control):
	var viewport=parent.get_viewport_rect().size
	if not available(viewport):return
	# The original full-body image is enlarged, then naturally cropped below
	# the game window. Its face stays on the reserved right side; UI is later.
	var portrait=TextureRect.new();portrait.name="FacilityNpc";portrait.texture=texture
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;portrait.focus_mode=Control.FOCUS_NONE;parent.add_child(portrait)
	var height=viewport.y*1.28;var width=height*texture.get_width()/texture.get_height()
	portrait.size=Vector2(width,height);portrait.position=Vector2(viewport.x-width+viewport.y*.08,viewport.y*.055)
	portrait.set_meta("facility",visit_key);portrait.set_meta("asset_path",selected_path)
func columns(parent: Control,viewport_width: float) -> Control:
	if not available(parent.get_viewport_rect().size):return parent
	var split=HBoxContainer.new();split.name="FacilityNpcColumns";split.size_flags_vertical=Control.SIZE_EXPAND_FILL;split.add_theme_constant_override("separation",16);split.mouse_filter=Control.MOUSE_FILTER_PASS;parent.add_child(split)
	var content=VBoxContainer.new();content.name="FacilityContent";content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.mouse_filter=Control.MOUSE_FILTER_PASS;split.add_child(content)
	# Reserving a narrower empty region preserves all current controls. The art
	# itself is on a full-window decoration layer, behind those controls.
	var stage=Control.new();stage.name="FacilityNpcStage";stage.custom_minimum_size.x=clampf(viewport_width*.23,240,500);stage.size_flags_vertical=Control.SIZE_EXPAND_FILL;stage.mouse_filter=Control.MOUSE_FILTER_IGNORE;stage.focus_mode=Control.FOCUS_NONE;split.add_child(stage)
	return content
