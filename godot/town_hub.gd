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

	var panel=PanelContainer.new();panel.name="TownHub";panel.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new());parent.add_child(panel)
	var margin=MarginContainer.new();margin.add_theme_constant_override("margin_left",24);margin.add_theme_constant_override("margin_right",24);margin.add_theme_constant_override("margin_top",24);margin.add_theme_constant_override("margin_bottom",24);panel.add_child(margin)
	var column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_SHRINK_END;column.custom_minimum_size.x=280;margin.add_child(column)
	for id in place.get("facilities",[]):
		if not FACILITIES.has(id):continue
		var spec=FACILITIES[id];var button=ui.button(column,spec[0],ui.navigate.bind(spec[1]));button.name="HubFacility_"+id;ui.memory.key(button,"nav_"+spec[1])
	var map=ui.button(column,"地図・出発",ui.navigate.bind("map"));map.name="HubMap";ui.memory.key(map,"nav_map")
	var quest=c.get("activeQuest")
	if quest is Dictionary and quest.get("to")==c.location:
		var missing=not c.get("cargoAboard",false)
		var deliver=ui.button(column,"荷物を届ける",ui.act.bind("completeQuest",[]),missing);deliver.name="HubDeliverCargo"
		if missing:ui.label_(column,"同行ポーターがこの依頼の荷物を持っていません。依頼は未完了です。")
	var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(spacer)
	if artwork.is_empty():ui.label_(parent,"拠点画像は準備中です。施設は利用できます。")
