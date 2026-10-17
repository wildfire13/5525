extends RefCounted
## Visit-scoped artwork; never alters campaign state or random battle outcomes.
var ui
var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/towns/manifest.json"))
var location := ""
var artwork: Dictionary={}
var rng=RandomNumberGenerator.new()
const FACILITIES={"board":["掲示板","board"],"guild":["ギルド","party"],"inn":["宿屋","inn"],"weapon":["武器店","shop"],"armor":["防具店","shop"],"items":["道具店","shop"],"accessory":["装飾品店","shop"]}
func _init(frontend):ui=frontend;rng.randomize()
func reset():location="";artwork={}
func select_art(id: String):
	if location==id:return
	location=id;artwork={}
	var variants=catalog.get(id,[]).filter(func(v):return v is Dictionary and ResourceLoader.exists(str(v.get("path",""))))
	if not variants.is_empty():artwork=variants[rng.randi_range(0,variants.size()-1)].duplicate()
func render(parent):
	var c=ui.campaign();select_art(str(c.location))
	var place={}
	for entry in c.get("locations",[]):
		if entry.id==c.location:place=entry;break
	ui.label_(parent,ui.town_name(c.location),true)
	var panel=PanelContainer.new();panel.name="TownHub";panel.custom_minimum_size.y=maxf(400,ui.size.y*.65);parent.add_child(panel)
	var image=TextureRect.new();image.name="TownStill";image.texture=load(artwork.path) if not artwork.is_empty() else null;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(image)
	var margin=MarginContainer.new();margin.add_theme_constant_override("margin_left",24);margin.add_theme_constant_override("margin_right",24);margin.add_theme_constant_override("margin_top",24);margin.add_theme_constant_override("margin_bottom",24);panel.add_child(margin)
	var column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_SHRINK_END;column.custom_minimum_size.x=280;margin.add_child(column)
	for id in place.get("facilities",[]):
		if not FACILITIES.has(id):continue
		var spec=FACILITIES[id];var button=ui.button(column,spec[0],ui.navigate.bind(spec[1]));button.name="HubFacility_"+id;ui.memory.key(button,"nav_"+spec[1])
	var map=ui.button(column,"地図・出発",ui.navigate.bind("map"));map.name="HubMap";ui.memory.key(map,"nav_map")
	var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(spacer)
	var quest=c.get("activeQuest")
	if quest is Dictionary and quest.get("to")==c.location:
		var notice=ui.label_(column,"依頼は未完了です。掲示板で納品してください。");notice.custom_minimum_size.x=280
	var style=ui.label_(parent,"画風："+str(artwork.get("style","")) if not artwork.is_empty() else "拠点画像は準備中です。施設は利用できます。")
	style.name="TownArtStyle";style.add_theme_font_size_override("font_size",16)
