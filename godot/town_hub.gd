extends RefCounted
## Visit-scoped artwork; never alters campaign state or random battle outcomes.
var ui
var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/towns/manifest.json"))
var location := ""
var artwork: Dictionary={}
var rng=RandomNumberGenerator.new()
const Tokens=preload("res://ui_tokens.gd")
const MEETING_GAP=float(Tokens.SPACE_LG)
const Grid=preload("res://screen_grid.gd")
const FACILITIES={"board":["掲示板","board"],"guild":["ギルド","party"],"inn":["宿屋","inn"],"weapon":["武器店","shop"],"armor":["防具店","shop"],"items":["道具店","shop"],"accessory":["装飾品店","shop"]}
const HUB_ANCHORS={
	"astaris":{"guild":Vector2(.50,.48),"board":Vector2(.645,.48),"inn":Vector2(.885,.57),"map":Vector2(.485,.82)},
	"east":{"weapon":Vector2(.07,.40),"board":Vector2(.225,.41),"map":Vector2(.56,.49)},
	"west":{"armor":Vector2(.80,.47),"board":Vector2(.90,.60),"map":Vector2(.43,.56)},
	"south":{"items":Vector2(.82,.50),"board":Vector2(.12,.57),"map":Vector2(.54,.58)},
	"north":{"board":Vector2(.13,.49),"accessory":Vector2(.305,.46),"map":Vector2(.53,.51)},
}
func anchor_for(loc: String,id: String,fallback: Vector2) -> Vector2:
	var table: Dictionary=HUB_ANCHORS.get(loc,{})
	return table.get(id,fallback)
func _init(frontend):ui=frontend;rng.randomize()
func reset():location="";artwork={}
func select_art(id: String):
	if location==id:return
	location=id;artwork={}
	var variants=catalog.get(id,[]).filter(func(v):return v is Dictionary and ResourceLoader.exists(str(v.get("path",""))))
	if not variants.is_empty():artwork=variants[rng.randi_range(0,variants.size()-1)].duplicate()
func _fit_before_meeting(panel: Control):
	# Keep the artwork-relative position unless the meeting column needs room.
	# Recompute from the original anchor on resize, so offsets never accumulate.
	for button in panel.get_children():
		if button is Button and button.has_meta("hub_x_anchor"):
			var meeting_left=Grid.cell_rect(ui.size,7,1,3,8).position.x-panel.global_position.x
			button.position.x=minf(panel.size.x*float(button.get_meta("hub_x_anchor")),maxf(0,meeting_left-button.size.x-MEETING_GAP))
func render(parent):
	var c=ui.campaign();select_art(str(c.location))
	var place={}
	for entry in c.get("locations",[]):
		if entry.id==c.location:place=entry;break

	var panel=Control.new();panel.name="TownHub";panel.custom_minimum_size=Vector2(900,ui.mock_shell.content_height());panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(panel)
	var quest=c.get("activeQuest")
	var has_meeting=quest is Dictionary and quest.get("eventId","")=="wheel"
	var points={"board":Vector2(.58,.22),"guild":Vector2(.18,.22),"inn":Vector2(.64,.65),"weapon":Vector2(.18,.28),"armor":Vector2(.18,.28),"items":Vector2(.18,.28),"accessory":Vector2(.18,.28)}
	# Anchors are relative to the playable map beside the party list, aligned to each town's artwork landmarks.
	for id in place.get("facilities",[]):
		if not FACILITIES.has(id):continue
		var spec=FACILITIES[id];var button=ui.button(panel,spec[0],ui.navigate.bind(spec[1]));button.name="HubFacility_"+id;button.theme_type_variation=&"ActionButton";Tokens.apply_button_preset(button,"md_lg",false);ui.memory.key(button,"nav_"+spec[1])
		var point=anchor_for(str(c.location),id,points.get(id,Vector2(.2,.2)));button.anchor_left=point.x;button.anchor_top=point.y;button.anchor_right=point.x;button.anchor_bottom=point.y
		if has_meeting:
			button.set_meta("hub_x_anchor",point.x);button.resized.connect(_fit_before_meeting.bind(panel))
	var map_point=anchor_for(str(c.location),"map",Vector2(.12,.82))
	var map=ui.button(panel,"出発の準備・街道口",ui.navigate.bind("map"));map.name="HubMap";map.theme_type_variation=&"ActionButton";map.anchor_left=map_point.x;map.anchor_top=map_point.y;map.anchor_right=map_point.x;map.anchor_bottom=map_point.y;Tokens.apply_button_preset(map,"lg",false);ui.memory.key(map,"nav_map")
	if has_meeting:
		map.set_meta("hub_x_anchor",map_point.x);map.resized.connect(_fit_before_meeting.bind(panel))
		var fit=_fit_before_meeting.bind(panel);panel.resized.connect(fit);fit.call_deferred()
	if has_meeting:
		var box=PanelContainer.new();box.name="HubMeetingPanel";box.add_theme_stylebox_override("panel",ui.mock_shell.surface_style());panel.add_child(box)
		var place_meeting=func():
			if not is_instance_valid(box) or box.is_queued_for_deletion():return
			Grid.place(box,ui.pages.quest_board.meeting.panel_rect())
			_fit_before_meeting(panel)
		for container in [panel,parent,parent.get_parent()]:container.item_rect_changed.connect(place_meeting)
		place_meeting.call_deferred()
		var column=VBoxContainer.new();column.add_theme_constant_override("separation",Tokens.SPACE_MD);box.add_child(column)
		var details=ui.scroller(column);ui.pages.quest_board.meeting.render(details,quest,"Hub",true)
		var m: Dictionary=quest.get("meeting",{})
		if m.get("canWait",false):
			var wait_btn=ui.primary(ui.button(column,ui.pages.quest_board.meeting.wait_label(quest),ui.pages.quest_board.meeting.open_wait));wait_btn.name="HubWaitForMerchant";Tokens.apply_button_preset(wait_btn,"md",false)
		elif m.get("canDeliver",false) or m.get("canSettleFailure",false):
			var action="期限切れを確認して荷物を戻す" if m.get("canSettleFailure",false) else "荷物を届ける"
			var callback=ui.pages.quest_board.meeting.open_failure if m.get("canSettleFailure",false) else ui.act.bind("completeQuest",[])
			var deliver=ui.primary(ui.button(column,action,callback));deliver.name="HubDeliverCargo";Tokens.apply_button_preset(deliver,"md",false)
			deliver.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		elif m.get("reason")=="cargo_missing":
			var check_carrier=ui.button(column,"荷物担当を確認",ui.navigate.bind("party"));check_carrier.name="HubCheckCarrier";Tokens.apply_button_preset(check_carrier,"md",false)
		else:
			var meeting_map=ui.button(column,"移動先を確認",ui.navigate.bind("map"));meeting_map.name="HubMeetingMap";Tokens.apply_button_preset(meeting_map,"md",false)
	elif quest is Dictionary and quest.get("to")==c.location and str(quest.get("deliveryFacility","")).is_empty():
		var column=VBoxContainer.new();panel.add_child(column);column.anchor_left=.7;column.anchor_top=.82
		var missing=not c.get("cargoAboard",false)
		var deliver=ui.primary(ui.button(column,"荷物を届ける",ui.act.bind("completeQuest",[]),missing));deliver.name="HubDeliverCargo";Tokens.apply_button_preset(deliver,"md_lg",false)
		if missing:ui.label_(column,"同行ポーターがこの依頼の荷物を持っていません。依頼は未完了です。")

	if artwork.is_empty():ui.label_(parent,"拠点画像は準備中です。施設は利用できます。")
