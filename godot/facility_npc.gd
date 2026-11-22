extends RefCounted
## Visit-only decoration. Selection never consumes campaign or background RNG.
const ROOT="res://assets/facility_npcs/"
const CATALOG={"weapon":["weapon1.png","weapon2.png"],"armor":["armor.png"],"item":["item.png"],"accessory":["accessory.png"],"inn":["inn.png"],"guild":["guild-dwarf.png","guild-elf.png","guild-human.png"]}
# Mouth landmarks measured on the current 1024x1536 source portraits (five replaced 2026-10-31).
const MOUTHS={"weapon1.png":Vector2(490,180),"weapon2.png":Vector2(500,280),"armor.png":Vector2(520,265),"item.png":Vector2(515,260),"accessory.png":Vector2(462,162),"inn.png":Vector2(490,260),"guild-dwarf.png":Vector2(534,360),"guild-elf.png":Vector2(536,350),"guild-human.png":Vector2(545,350)}
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
func mouth_anchor(parent: Control) -> Vector2:
	var portrait=parent.get_node_or_null("FacilityNpcRegion/FacilityNpc")
	if portrait==null or texture==null:return Vector2(-1,-1)
	var source: Vector2=MOUTHS.get(selected_path.get_file(),Vector2(512,240))
	return portrait.global_position+portrait.size*source/texture.get_size()
