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

	var panel=Control.new();panel.name="TownHub";panel.custom_minimum_size=Vector2(900,ui.mock_shell.content_height());panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(panel)
	var points={"board":Vector2(.58,.22),"guild":Vector2(.18,.22),"inn":Vector2(.64,.65),"weapon":Vector2(.18,.28),"armor":Vector2(.18,.28),"items":Vector2(.18,.28),"accessory":Vector2(.18,.28)}
	for id in place.get("facilities",[]):
		if not FACILITIES.has(id):continue
		var spec=FACILITIES[id];var button=ui.button(panel,spec[0],ui.navigate.bind(spec[1]));button.name="HubFacility_"+id;button.custom_minimum_size=Vector2(168,64);ui.memory.key(button,"nav_"+spec[1])
		var point=points.get(id,Vector2(.2,.2));button.anchor_left=point.x;button.anchor_top=point.y;button.anchor_right=point.x;button.anchor_bottom=point.y
	var map=ui.button(panel,"出発の準備\n街道口",ui.navigate.bind("map"));map.name="HubMap";map.anchor_left=.12;map.anchor_top=.82;map.custom_minimum_size=Vector2(168,64);ui.memory.key(map,"nav_map")
	var column=VBoxContainer.new();panel.add_child(column);column.anchor_left=.7;column.anchor_top=.82
	var quest=c.get("activeQuest")
	if quest is Dictionary and quest.get("to")==c.location:
		var missing=not c.get("cargoAboard",false)
		if quest.get("eventId","")=="wheel" and not quest.get("merchantAtStop",false) and not quest.get("merchantDeparted",false):
			ui.label_(column,"行商人の到着を待っています。").name="MerchantArrivalWait"
		else:
			var label="期限切れを確認して荷物を戻す" if quest.get("merchantDeparted",false) else "荷物を届ける"
			var deliver=ui.button(column,label,ui.act.bind("completeQuest",[]),missing);deliver.name="HubDeliverCargo"
			if missing:ui.label_(column,"同行ポーターがこの依頼の荷物を持っていません。依頼は未完了です。")
	var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(spacer)
	if artwork.is_empty():ui.label_(parent,"拠点画像は準備中です。施設は利用できます。")
