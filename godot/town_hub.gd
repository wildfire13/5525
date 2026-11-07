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
	var quest=c.get("activeQuest")
	if quest is Dictionary and quest.get("eventId","")=="wheel":
		var box=PanelContainer.new();box.name="HubMeetingPanel";box.anchor_left=.70;box.anchor_right=.99;box.anchor_top=.04;box.anchor_bottom=.96;box.add_theme_stylebox_override("panel",ui.mock_shell.surface_style());panel.add_child(box)
		var column=VBoxContainer.new();column.add_theme_constant_override("separation",12);box.add_child(column)
		var details=ui.scroller(column);ui.pages.quest_board.meeting.render(details,quest,"Hub",true)
		var m: Dictionary=quest.get("meeting",{})
		if m.get("canWait",false):
			ui.primary(ui.button(column,ui.pages.quest_board.meeting.wait_label(quest),ui.pages.quest_board.meeting.open_wait)).name="HubWaitForMerchant"
		elif m.get("canDeliver",false) or m.get("canSettleFailure",false):
			var action="期限切れを確認して荷物を戻す" if m.get("canSettleFailure",false) else "荷物を届ける"
			ui.primary(ui.button(column,action,ui.act.bind("completeQuest",[]),not c.get("cargoAboard",false))).name="HubDeliverCargo"
		elif m.get("reason")=="cargo_missing" or (m.get("state")=="departed" and c.location=="south" and not c.get("cargoAboard",false)):
			ui.button(column,"荷物担当を確認",ui.navigate.bind("party")).name="HubCheckCarrier"
		else:
			ui.button(column,"移動先を確認",ui.navigate.bind("map")).name="HubMeetingMap"
	elif quest is Dictionary and quest.get("to")==c.location:
		var column=VBoxContainer.new();panel.add_child(column);column.anchor_left=.7;column.anchor_top=.82
		var missing=not c.get("cargoAboard",false)
		var deliver=ui.button(column,"荷物を届ける",ui.act.bind("completeQuest",[]),missing);deliver.name="HubDeliverCargo"
		if missing:ui.label_(column,"同行ポーターがこの依頼の荷物を持っていません。依頼は未完了です。")

	if artwork.is_empty():ui.label_(parent,"拠点画像は準備中です。施設は利用できます。")
