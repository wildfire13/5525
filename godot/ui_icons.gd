extends RefCounted
## R11: canonical adopted artwork; semantic namespaces never change action IDs.
var cache: Dictionary={}
const ROOT="res://assets/ui_icons/icons64/"
const SLOTS={"rightHand":"right_hand","leftHand":"left_hand","head":"head","upperBody":"body","lowerBody":"trousers","feet":"feet","accessory1":"accessory","accessory2":"accessory"}
const JOBS={"guard":"warrior","warrior":"warrior","archer":"scout","scout":"scout","mage":"mage","porter":"porter"}
const SKILLS={"swift":"feet","retreatSlash":"sheet_one_handed_sword","knockback":"sheet_hammer","splitShot":"sheet_bow","pincer":"dagger","healingCross":"sheet_staff","defenseLine":"sheet_shield","manaGift":"book","returnHome":"accessory","victoryBreath":"accessory","loneWolf":"accessory","firstStride":"accessory","invasion":"accessory","archer":"sheet_bow","mage":"sheet_staff","scout":"dagger","stamp":"sheet_hammer","porter":"skill","guard":"sheet_shield"}
const WEAPONS={"sword":"sheet_one_handed_sword","greatsword":"sheet_two_handed_sword","spear":"sheet_spear","bow":"sheet_bow","hammer":"sheet_hammer","staff":"sheet_staff","shield":"sheet_shield","dagger":"dagger","book":"book","gun":"gun","empty":"unarmed"}
const FACILITIES={"weapon":"weapon_shop","armor":"armor_shop","items":"item_shop","accessory":"accessory_shop","inn":"inn"}
func texture(id: String) -> Texture2D:
	if id.is_empty():return null
	if not cache.has(id):
		var path=ROOT+id+".png"
		if not ResourceLoader.exists(path):push_error("Unknown adopted UI icon: "+id);return null
		cache[id]=load(path)
	return cache[id]
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
func skill(id: String) -> String:return SKILLS.get(id,"skill")
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
