extends RefCounted
## R11: canonical adopted artwork; semantic namespaces never change action IDs.
var cache: Dictionary={}
var approved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/approved_v56/recipes.json"))
var equipment_paths: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/equipment_icons_placeholder/mapping.json"))
const ROOT="res://assets/ui_icons/icons64/"
const SLOTS={"rightHand":"right_hand","leftHand":"left_hand","head":"head","upperBody":"body","lowerBody":"trousers","feet":"feet","accessory1":"accessory","accessory2":"accessory"}
const JOBS={"guard":"warrior","warrior":"warrior","archer":"scout","scout":"scout","mage":"mage","porter":"porter"}
const SKILLS={"swift":"feet","retreatSlash":"sheet_one_handed_sword","knockback":"sheet_hammer","splitShot":"sheet_bow","pincer":"dagger","healingCross":"sheet_staff","defenseLine":"sheet_shield","manaGift":"book","returnHome":"accessory","victoryBreath":"accessory","loneWolf":"accessory","firstStride":"accessory","invasion":"accessory","archer":"sheet_bow","mage":"sheet_staff","scout":"dagger","stamp":"sheet_hammer","porter":"skill","guard":"sheet_shield"}
const WEAPONS={"sword":"sheet_one_handed_sword","greatsword":"sheet_two_handed_sword","spear":"sheet_spear","bow":"sheet_bow","hammer":"sheet_hammer","staff":"sheet_staff","shield":"sheet_shield","dagger":"dagger","book":"book","gun":"gun","empty":"unarmed"}
const FACILITIES={"weapon":"weapon_shop","armor":"armor_shop","items":"item_shop","accessory":"accessory_shop","inn":"inn"}
func texture(id: String) -> Texture2D:
	if id.is_empty():return null
	if not cache.has(id):
		if id.begins_with("approved:"):
			cache[id]=compose_approved(id)
			return cache[id]
		var path=path_for(id)
		if not ResourceLoader.exists(path):push_error("Unknown adopted UI icon: "+id);return null
		cache[id]=load(path)
	return cache[id]
func path_for(id: String) -> String:
	return str(equipment_paths.get(id.trim_prefix("equipment:"),"")) if id.begins_with("equipment:") else ROOT+id+".png"
func equipment(item: Dictionary) -> String:
	var id=str(item.get("id",""))
	if item.get("virtualDefault",false) or item.get("type")=="fist":return "approved:fist"
	if item.get("type")=="empty":return ""
	if approved.equipment.has(id):return "approved:equipment:"+id
	return "equipment:"+id if equipment_paths.has(id) else gear(item)
func add(parent: Node,id: String,pixels:=32) -> TextureRect:
	var image=TextureRect.new();image.name="Icon_"+id;image.set_meta("ui_icon_id",id)
	image.texture=texture(id);image.custom_minimum_size=Vector2(pixels,pixels)
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(image);return image
func apply(control: Button,id: String,pixels:=32) -> Button:
	control.icon=texture(id);control.expand_icon=true;control.add_theme_constant_override("icon_max_width",pixels)
	control.custom_minimum_size.x=maxf(control.custom_minimum_size.x,control.get_minimum_size().x+pixels+4)
	control.set_meta("ui_icon_id",id);return control
func line(ui,parent,id: String,text: String,large:=false) -> Label:
	var row=ui.row(parent);add(row,id,32 if large else 24)
	var label=ui.label_(row,text,large)
	if parent is HBoxContainer:label.autowrap_mode=TextServer.AUTOWRAP_OFF
	return label
func skill(id: String,level:=1) -> String:
	if approved.skills.has(id):
		var levels: Dictionary=approved.skills[id].get("levels",{})
		return "approved:skill:"+id+":"+str(level if levels.has(str(level)) else 1)
	return "" if id.is_empty() else "skill"

func approved_image(spec: Dictionary) -> Image:
	var source: Texture2D=load(str(spec.base))
	var result=source.get_image()
	if spec.has("crop"):
		var c=spec.crop;result=result.get_region(Rect2i(int(c[0]),int(c[1]),int(c[2]),int(c[3])))
	result.convert(Image.FORMAT_RGBA8)
	return result
func fit_image(source: Image,pixels: int) -> Image:
	var ratio=float(pixels)/maxi(source.get_width(),source.get_height())
	source.resize(maxi(1,roundi(source.get_width()*ratio)),maxi(1,roundi(source.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
	return source
func compose_approved(id: String) -> Texture2D:
	var parts=id.split(":");var spec: Dictionary
	if parts[1]=="fist":spec=approved.fist
	elif parts[1]=="equipment":spec=approved.equipment[parts[2]]
	else:spec=approved.skills[parts[2]]
	var levels: Dictionary=spec.get("levels",{});var level=str(parts[3]) if parts.size()>3 else "1"
	if not levels.has(level):level="1"
	var has_level=levels.has(level)
	# CSS stack is 64x64; the level badge extends right by 5 and up by 4.
	var canvas=Image.create(69 if has_level else 64,68 if has_level else 64,false,Image.FORMAT_RGBA8)
	var base=fit_image(approved_image(spec),64);var offset=4 if has_level else 0
	canvas.blend_rect(base,Rect2i(Vector2i.ZERO,base.get_size()),Vector2i((64-base.get_width())/2,offset+(64-base.get_height())/2))
	if spec.has("badge"):
		var badge=fit_image(approved_image({"base":spec.badge}),30)
		canvas.blend_rect(badge,Rect2i(Vector2i.ZERO,badge.get_size()),Vector2i(64-badge.get_width(),offset+64-badge.get_height()))
	if has_level:
		var badge=fit_image(approved_image(levels[level]),26)
		canvas.blend_rect(badge,Rect2i(Vector2i.ZERO,badge.get_size()),Vector2i(43,0))
	return ImageTexture.create_from_image(canvas)
func job(id: String) -> String:return JOBS.get(id,"")
func race(id: String) -> String:return id+"_blank_face" if id in ["human","elf","dwarf"] else ""
func slot(id: String) -> String:return SLOTS.get(id,"")
func gear(item: Dictionary) -> String:
	if item.get("type")=="empty":return "unarmed" if item.get("slot","") in ["weapon","rightHand","leftHand"] else slot(str({"armor":"upperBody"}.get(item.get("slot"),item.get("slot",""))))
	if item.get("id")=="javelin-wood":return "sheet_throwing_javelin"
	if item.get("id")=="porter-kit":return "porter"
	if item.get("type")=="accessory":return "accessory"
	if item.get("type")=="armor":return slot({"armor":"upperBody"}.get(item.get("slot"),item.get("slot","")))
	return WEAPONS.get(item.get("type",""),slot(item.get("slot","")))
func command(id: String) -> String:return {"guard":"defend","return":"accessory","item":"potion","ether":"ether"}.get(id,id)
func place(id: String) -> String:return "castle" if id=="astaris" else "village"
func shop(id: String) -> String:return {"east":"weapon_shop","west":"armor_shop","south":"item_shop","north":"accessory_shop"}.get(id,"")
