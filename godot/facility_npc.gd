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
func columns(parent: Control,viewport_width: float) -> Control:
	# Preserve the existing compact UI rather than squeeze its controls for art.
	# The visit selection survives resize and reappears unchanged with more room.
	if texture==null or viewport_width<1120 or parent.get_viewport_rect().size.y<720:return parent
	var split=HBoxContainer.new();split.name="FacilityNpcColumns";split.size_flags_vertical=Control.SIZE_EXPAND_FILL;split.add_theme_constant_override("separation",16);split.mouse_filter=Control.MOUSE_FILTER_PASS;parent.add_child(split)
	var content=VBoxContainer.new();content.name="FacilityContent";content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.mouse_filter=Control.MOUSE_FILTER_PASS;split.add_child(content)
	var stage=Control.new();stage.name="FacilityNpcStage";stage.custom_minimum_size.x=clampf(viewport_width*.2,220,420);stage.size_flags_vertical=Control.SIZE_EXPAND_FILL;stage.mouse_filter=Control.MOUSE_FILTER_IGNORE;stage.focus_mode=Control.FOCUS_NONE;split.add_child(stage)
	var portrait=TextureRect.new();portrait.name="FacilityNpc";portrait.texture=texture;portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;portrait.focus_mode=Control.FOCUS_NONE;stage.add_child(portrait);portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.set_meta("facility",visit_key);portrait.set_meta("asset_path",selected_path)
	return content
