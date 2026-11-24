extends RefCounted
const ElementBadges=preload("res://element_badges.gd")
const ScreenGrid=preload("res://screen_grid.gd")
const Tokens=preload("res://ui_tokens.gd")
## Presentation of existing Campaign.view fields. Mutations stay in the bridge.
var ui
var party_uid := ""
var gear_id := ""
var epoch := 0
var quote_generation := 0
var travel_map_expanded := false
var quote_pending := false
var quote_stamp := ""
var trial_return: Dictionary={}
var cached_quotes: Dictionary={}
var party_focus_after := ""
var shop_view
var facility_entry
var party_view
var guild_view
var warehouse_view
var hub_view
var quest_board
var inn_view
var facility_art=preload("res://facility_art.gd").new()
var item_stage := "entry"
var item_id := ""
const ItemMenu=preload("res://item_menu.gd")
func _init(frontend):
	ui=frontend
	quest_board=preload("res://quest_board.gd").new(self)
	inn_view=preload("res://inn_view.gd").new(self)
	hub_view=preload("res://town_hub.gd").new(frontend)
	ui=frontend;shop_view=preload("res://shop_view.gd").new(self);party_view=preload("res://party_view.gd").new(self);guild_view=preload("res://guild_view.gd").new(self);facility_entry=preload("res://facility_entry.gd").new(self)
	warehouse_view=preload("res://warehouse_view.gd").new(self)
func l(parent,text,large:=false):return ui.label_(parent,str(text),large)
func b(parent,text,fn,disabled:=false,preset:=""):return ui.button(parent,text,fn,disabled,preset)
func row(parent):return ui.row(parent)
func card(parent):return ui.card(parent)
func c() -> Dictionary:return ui.campaign()
func roster() -> Array:return ui.roster()
func town(id) -> String:return ui.town_name(id)
func muted(parent,text):
	var label=l(parent,text);label.add_theme_color_override("font_color",Tokens.MUTED_INK);return label
# Display normal attack power before formation, skills and target defense.
# Match the battle rule: only reaching weapons, with growth added once.
func normal_reach(stats: Dictionary) -> int:
	return int(stats.get("normalReach",stats.get("reach",0)))
func normal_atk(stats: Dictionary,distance: int) -> int:
	if not stats.has("attackWeapons"):
		return int(stats.get("atk",0)) if distance<=normal_reach(stats) else 0
	var power=0;var reaches=false
	for weapon in stats.attackWeapons:
		if distance<=int(weapon.reach):power+=int(weapon.atk);reaches=true
	return power+int(stats.get("attackBonus",0)) if reaches else 0
func attack_profile(stats: Dictionary) -> String:
	var parts=[]
	for distance in range(1,normal_reach(stats)+1):
		parts.append("距離%d: %d" % [distance,normal_atk(stats,distance)])
	return "通常ATK（物理） "+(" / ".join(parts) if not parts.is_empty() else "なし")+" / 属性ATK 火%d 水%d 地%d / 最大射程 %d" % [stats.get("atkFire",0),stats.get("atkWater",0),stats.get("atkEarth",0),normal_reach(stats)]
func defense_profile(stats: Dictionary) -> String:
	return "DEF 物%d 火%d 水%d 地%d" % [stats.get("def",0),stats.get("defFire",0),stats.get("defWater",0),stats.get("defEarth",0)]
func element_name(element) -> String:
	return {"fire":"火","water":"水","earth":"地","none":"無属性"}.get(str(element),"無属性")
func elemental_combat_line(parent,stats: Dictionary):
	var detail=row(parent);detail.name="ElementalCombatProfile"
	var explanation=ElementBadges.MATCHUP_TIP
	var title=l(detail,"属性 ATK/DEF",false);title.tooltip_text=explanation
	for element in ["fire","water","earth"]:
		ElementBadges.add(detail,element,24)
		var values=l(detail,"%d / %d" % [stats.get("atk"+element.capitalize(),0),stats.get("def"+element.capitalize(),0)])
		values.tooltip_text=explanation
	detail.tooltip_text=explanation
func stats_text(stats: Dictionary,character_id: String="") -> String:
	var text="HP上限 %d / MP上限 %d / %s / %s / SPD %d / 属性 %s" % [stats.get("max",0),stats.get("maxMp",0),attack_profile(stats),defense_profile(stats),stats.get("speed",stats.get("agi",0)),element_name(stats.get("element","none"))]
	if not character_id.is_empty():
		var weight=c().get("inventoryByCharacter",{}).get(character_id,{}).get("weight",{})
		if weight is Dictionary:
			var current=weight.get("total")
			text+=" / Wt %s / STR上限 %d" % [str(current) if current!=null else str(weight.get("known",0))+"（一部不明）",stats.get("str",0)]
			if current!=null and current>stats.get("str",0):text+="（超過中: SPD 50%）"
	return text
func hub(parent):hub_view.render(parent)
func board(parent):quest_board.render(parent)
func accept(id: String):quest_board.open_picker(id)
func map(parent):
	var surface=card(parent);var panel=surface.get_parent()
	panel.custom_minimum_size.y=ui.mock_shell.content_height()
	var style=panel.get_theme_stylebox("panel").duplicate()
	for side in ["left","top","right","bottom"]:style.set("content_margin_"+side,0.0)
	panel.add_theme_stylebox_override("panel",style)
	surface.add_theme_constant_override("separation",Tokens.SPACE_NONE);parent=surface
	var available=[]
	for place in c().get("destinations",[]):available.append(place.id if place is Dictionary else place)
	var quest=c().get("activeQuest")
	if not available.has(ui.destination):ui.destination=str(available[0]) if not available.is_empty() else ""
	var chart=preload("res://town_map.gd").new();chart.name="TownMap"
	chart.towns=c().get("locations",[]);chart.current=c().location;chart.selected=ui.destination;chart.available=available;chart.routes=c().get("routes",{});chart.icons=ui.icons
	chart.quest_destination=str(quest.to) if quest is Dictionary else ""
	parent.add_child(chart);chart.custom_minimum_size.y=ui.mock_shell.content_height()-ui.mock_shell.grid_cell().y;chart.size_flags_vertical=Control.SIZE_EXPAND_FILL
	for id in chart.buttons:ui.widgets.append(chart.buttons[id])
	var actions=row(parent);actions.name="MapControls";actions.custom_minimum_size.y=ui.mock_shell.grid_cell().y
	var left_pad=Control.new();left_pad.custom_minimum_size.x=Tokens.SPACE_MD;left_pad.mouse_filter=Control.MOUSE_FILTER_IGNORE;actions.add_child(left_pad)
	var route=VBoxContainer.new();route.custom_minimum_size.x=320;route.size_flags_vertical=Control.SIZE_SHRINK_CENTER;actions.add_child(route)
	var route_title=l(route,town(c().location)+" → "+town(ui.destination),true)
	chart.destination_selected.connect(func(id):
		ui.destination=id
		chart.select_town(id)
		route_title.text=town(c().location)+" → "+town(id))
	l(route,"最短移動時間：6時間")
	var over=c().get("inventoryOverflow",[])
	var depart=ui.action_button(b(actions,"出発する",func():ui.act("depart",[ui.destination,"convoy"]),ui.destination.is_empty() or not over.is_empty()),"md");depart.name="DepartButton"
	if not over.is_empty():depart.tooltip_text="インベントリ枠を超えているメンバーがいます"
	b(actions,"都市に入る" if c().location=="astaris" else "村に入る",ui.navigate.bind("hub"),false,"md")
	var space=Control.new();space.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(space)
	var fit_button=b(actions,"全体表示",chart.reset_view,false,"md");fit_button.name="MapFit"
	var right_pad=Control.new();right_pad.custom_minimum_size.x=Tokens.SPACE_MD;right_pad.mouse_filter=Control.MOUSE_FILTER_IGNORE;actions.add_child(right_pad)
func choose_formation(value: String):ui.formation=value;ui.render()
func grid_height(cells: int) -> float:
	return ScreenGrid.cell_rect(ui.size,0,0,1,cells).size.y

func journey(parent):
	var phase=c().get("phase","");var journey_: Dictionary=c().get("journey") if c().get("journey") is Dictionary else {}
	if phase=="result":
		result(card(ui.scroller(parent)))
		return
	if phase=="prepare":map(parent);return
	parent.add_theme_constant_override("separation",Tokens.SPACE_NONE)
	var strip=preload("res://travel_strip.gd").new();strip.name="TravelRouteStrip"
	strip.origin=town(journey_.get("origin",c().get("location","")))
	strip.destination=town(journey_.get("outboundDestination",journey_.get("destination","")))
	strip.returning=journey_.get("returning",false);strip.stage=int(journey_.get("stage",0));strip.phase=phase
	var route=VBoxContainer.new();route.name="JourneyRoute";route.add_theme_constant_override("separation",Tokens.SPACE_NONE)
	route.custom_minimum_size.y=ui.mock_shell.content_height()-ui.mock_shell.grid_cell().y;parent.add_child(route);route.add_child(strip)
	strip.custom_minimum_size.y=grid_height(2)
	var quest=c().get("activeQuest")
	var sluice_trip=phase=="road" and quest is Dictionary and quest.get("id")=="sluice-bell" and journey_.get("destination")=="east" and not strip.returning
	var map_row=row(parent);map_row.name="JourneyMapBar";map_row.alignment=BoxContainer.ALIGNMENT_END;map_row.custom_minimum_size.y=grid_height(3)-grid_height(2)
	var toggle=b(map_row,"経路だけ表示" if travel_map_expanded else "ワールドマップを表示",func():toggle_travel_map(parent,map_row,journey_),false,"lg_md")
	toggle.name="TravelMapToggle"
	var actions_panel=PanelContainer.new();actions_panel.name="CampActions"
	var action_cell=3
	actions_panel.custom_minimum_size.y=grid_height(action_cell+1)-grid_height(action_cell)
	actions_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	actions_panel.add_theme_stylebox_override("panel",Tokens.surface_box(Tokens.SURFACE,false,Tokens.RADIUS_SM,Tokens.SPACE_SM))
	route.add_child(actions_panel)
	var actions=row(actions_panel)
	var copy=VBoxContainer.new();copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL;copy.size_flags_vertical=Control.SIZE_SHRINK_CENTER;actions.add_child(copy)
	l(copy,"帰路" if strip.returning else "野営地" if phase=="camp" else "到着" if phase in ["arrival","delivery"] else "%d区間目の道" % (int(journey_.get("stage",0))+1),true)
	var remaining=maxi(0,2-int(journey_.get("stage",0)))*3
	if phase=="arrival" or phase=="delivery":remaining=0
	l(copy,"最短の到着見込 %d時間" % (int(journey_.get("hours",0))+remaining))
	match phase:
		"camp":
			ui.action_button(b(actions,"次の区間へ",ui.act.bind("onward",[])),"md")
			var rest=b(actions,"休息済み" if journey_.get("rested",false) else "休息する",ui.forecast_action.bind("rest","rest",[]),journey_.get("rested",false),"md");rest.tooltip_text="2時間 · HP +60 / MP +2"
			if c().get("canTurnBack",false):
				var turn_back=b(actions,"引き返す",ui.forecast_action.bind("turnBack","turnBack",[]),false,"md");turn_back.tooltip_text="通った経路を戻る · 帰着まで%d時間" % c().get("returnHours",0)
		"road":
			if c().get("canTurnBack",false):
				var turn_back=b(actions,"引き返す",ui.forecast_action.bind("turnBack","turnBack",[]),false,"md");turn_back.tooltip_text="通った経路を戻る · 帰着まで%d時間" % c().get("returnHours",0)
		"arrival","delivery":
			ui.action_button(b(actions,"都市に入る" if journey_.get("destination")=="astaris" else "村に入る",ui.act.bind("arrive",[])),"md")
	if phase=="road":
		var choices=row(route);choices.name="RouteChoices"
		choices.custom_minimum_size.y=grid_height(action_cell+2)-grid_height(action_cell+1)
		for choice in [["short","峠の近道",2],["safe","川沿いの道",4]]:
			var caption = "%s\n移動 %d時間" % [choice[1], choice[2]]
			if sluice_trip:
				caption += "\n陣形の外にいる味方が射手に狙われる" if choice[0] == "short" else "\n番人が巻上機を塞ぐ"
			var choose = b(choices, caption, ui.act.bind("travel", [choice[0]]))
			choose.name = "RouteChoice_" + choice[0]
			choose.custom_minimum_size = Vector2(400, 100) if sluice_trip else Vector2(260, 80)
			choose.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if sluice_trip:
			var gate_note = "守護者が通常移動で巻上機に入ると開門。離脱・撃破で閉門。"
			gate_note += "\n舟守の合図は一戦一度。開門後、味方が道を空けてポーターが一手で出口に届くと、次はポーターの手番。"
			if int(journey_.get("stage", 0)) == 0:
				gate_note += "\n最初の区間で川沿いの舟守を助けると、次の戦闘の出口が近くなる。"
			var note_panel=PanelContainer.new();note_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;note_panel.size_flags_vertical=Control.SIZE_SHRINK_CENTER
			note_panel.add_theme_stylebox_override("panel",Tokens.surface_box(Tokens.SURFACE,false,Tokens.RADIUS_SM,Tokens.SPACE_XS))
			map_row.add_child(note_panel);map_row.move_child(note_panel,0)
			var note=l(note_panel,gate_note)
			note.add_theme_font_size_override("font_size",Tokens.FONT_SM)
			note.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	if phase=="camp":
		var inventory=row(route);inventory.name="CampInventoryBar";inventory.alignment=BoxContainer.ALIGNMENT_END
		inventory.custom_minimum_size.y=grid_height(action_cell+2)-grid_height(action_cell+1)
		b(inventory,"インベントリ",party_view.open_camp_inventory,false,"md")
	if travel_map_expanded:
		route.hide()
		add_travel_map(parent,journey_)

func toggle_travel_map(parent,map_row,journey_):
	travel_map_expanded=not travel_map_expanded
	parent.get_node("JourneyRoute").visible=not travel_map_expanded
	var toggle=map_row.get_node("TravelMapToggle")
	toggle.text="経路だけ表示" if travel_map_expanded else "ワールドマップを表示"
	if travel_map_expanded:
		add_travel_map(parent,journey_)
	else:
		var chart=parent.get_node("TravelFullMap")
		parent.remove_child(chart)
		chart.queue_free()

func add_travel_map(parent,journey_):
	var chart=preload("res://town_map.gd").new();chart.name="TravelFullMap";chart.read_only=true
	chart.towns=c().get("locations",[]);chart.current=str(journey_.get("origin",c().get("location","")));chart.selected=str(journey_.get("outboundDestination",journey_.get("destination","")))
	chart.available=chart.towns.map(func(place):return place.id);chart.routes=c().get("routes",{});chart.icons=ui.icons
	var quest=c().get("activeQuest");chart.quest_destination=str(quest.to) if quest is Dictionary else ""
	parent.add_child(chart);parent.move_child(chart,0)
	chart.custom_minimum_size.y=ui.mock_shell.content_height()-ui.mock_shell.grid_cell().y;chart.size_flags_vertical=Control.SIZE_FILL
	return chart

func party(parent):
	if not facility_entry.render_top(parent,"party"):
		if facility_entry.supported("party"):facility_entry.render_dialogue()
		party_view.render(parent)
func reset_items():item_stage="entry";item_id=""
func show_items(stage: String,id: String=""):
	if ui.locked or ui.presenting or ui.closing:return
	var previous=item_id;item_stage=stage;item_id=id
	if stage=="entry":ui.memory.request_focus("campaign_item_entry",true)
	elif stage=="list":ui.memory.request_focus("campaign_item_"+(previous if not previous.is_empty() else "potion"),true)
	else:
		for item in ItemMenu.definitions(c()):
			if item.id!=id:continue
			for u in roster():
				if c().selected.has(u.id) and ItemMenu.camp_reason(item,u,c().inventory).is_empty():
					ui.memory.request_focus("item_target_"+str(u.id),true);break
	ui.render()
func close_items() -> bool:
	if c().get("phase") not in ["town","camp"] or item_stage=="entry":return false
	show_items("list" if item_stage=="target" else "entry");return true
func use_selected_item(uid: String):
	if item_stage!="target" or item_id.is_empty():return
	await ui.act("useItem",[item_id,uid])
func item_members(parent) -> GridContainer:
	var body=ui.scroller(parent)
	var members: GridContainer=ui.member_grid(body,"CampParty" if c().phase=="camp" else "ItemParty")
	var fit=func():
		var cell=ui.size.y/ScreenGrid.DIVISIONS
		if cell>0:members.custom_minimum_size.y=grid_height(maxi(1,ceili(members.get_minimum_size().y/cell)))
	members.minimum_size_changed.connect(fit,CONNECT_DEFERRED)
	fit.call_deferred()
	return members

func items(parent):
	if c().phase not in ["town","camp"]:l(parent,"町・野営で使用できます");return
	parent.add_theme_constant_override("separation",Tokens.SPACE_NONE)
	if c().has("inventoryByCharacter"):
		var selected_ids: Array=c().get("selected",[])
		var cell_y=ui.mock_shell.grid_cell().y
		var body_rows=clampi(ceili((selected_ids.size()*60.0+16.0)/cell_y),2,6)
		var panel=PanelContainer.new();panel.name="CampaignItems"
		panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;panel.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
		panel.custom_minimum_size.y=cell_y*(body_rows+2)
		panel.add_theme_stylebox_override("panel",Tokens.surface_box(Tokens.SURFACE,false,Tokens.RADIUS_SM,Tokens.SPACE_NONE))
		parent.add_child(panel)
		var layout=VBoxContainer.new();layout.add_theme_constant_override("separation",Tokens.SPACE_NONE)
		layout.size_flags_horizontal=Control.SIZE_EXPAND_FILL;layout.size_flags_vertical=Control.SIZE_EXPAND_FILL;panel.add_child(layout)
		var header_box=VBoxContainer.new();header_box.add_theme_constant_override("separation",Tokens.SPACE_NONE)
		header_box.custom_minimum_size.y=cell_y;layout.add_child(header_box)
		var header_margin=MarginContainer.new();header_margin.size_flags_vertical=Control.SIZE_EXPAND_FILL
		header_margin.add_theme_constant_override("margin_left",Tokens.SPACE_MD);header_margin.add_theme_constant_override("margin_right",Tokens.SPACE_MD)
		header_margin.add_theme_constant_override("margin_top",Tokens.SPACE_SM);header_margin.add_theme_constant_override("margin_bottom",Tokens.SPACE_XS)
		header_box.add_child(header_margin)
		var header_copy=VBoxContainer.new();header_copy.size_flags_vertical=Control.SIZE_EXPAND_FILL;header_copy.add_theme_constant_override("separation",Tokens.SPACE_SM);header_margin.add_child(header_copy)
		l(header_copy,"所持品一覧",true)
		var cols=row(header_copy)
		var col_member=muted(cols,"メンバー");col_member.custom_minimum_size.x=180;col_member.size_flags_horizontal=Control.SIZE_FILL;col_member.add_theme_font_size_override("font_size",Tokens.FONT_SM)
		var col_items=muted(cols,"所持品");col_items.size_flags_horizontal=Control.SIZE_EXPAND_FILL;col_items.add_theme_font_size_override("font_size",Tokens.FONT_SM)
		var col_action=muted(cols,"操作");col_action.custom_minimum_size.x=Tokens.BUTTON_W_MD;col_action.size_flags_horizontal=Control.SIZE_SHRINK_END;col_action.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;col_action.add_theme_font_size_override("font_size",Tokens.FONT_SM)
		var header_divider=ColorRect.new();header_divider.name="CampaignItemsHeaderDivider";header_divider.color=Tokens.BORDER;header_divider.custom_minimum_size.y=Tokens.BORDER_WIDTH;header_divider.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header_divider.mouse_filter=Control.MOUSE_FILTER_IGNORE;header_box.add_child(header_divider)
		var body_list=ui.scroller(layout)
		var body_scroll=body_list.get_parent()
		body_scroll.name="CampParty" if c().phase=="camp" else "ItemParty"
		body_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
		body_scroll.custom_minimum_size.y=cell_y*body_rows
		var body_pad=StyleBoxEmpty.new();body_pad.content_margin_left=Tokens.SPACE_MD;body_pad.content_margin_right=Tokens.SPACE_MD;body_pad.content_margin_top=Tokens.SPACE_XS;body_pad.content_margin_bottom=Tokens.SPACE_XS
		body_scroll.add_theme_stylebox_override("panel",body_pad)
		body_list.add_theme_constant_override("separation",Tokens.SPACE_XS)
		var by_character: Dictionary=c().get("inventoryByCharacter",{})
		var rendered_rows=0
		for uid in selected_ids:
			var matches=roster().filter(func(member):return member.id==uid)
			if matches.is_empty():continue
			if rendered_rows>0:body_list.add_child(HSeparator.new())
			rendered_rows+=1
			var u=matches[0]
			var member=row(body_list);member.name="ItemMember_"+str(uid);member.custom_minimum_size.y=52
			var name_box=VBoxContainer.new();name_box.custom_minimum_size.x=180;name_box.size_flags_vertical=Control.SIZE_SHRINK_CENTER;name_box.add_theme_constant_override("separation",2);member.add_child(name_box)
			var name_label=l(name_box,u.name);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;ui.short_name(name_label,str(u.name))
			var role_label=muted(name_box,str(u.get("role","")));role_label.add_theme_font_size_override("font_size",Tokens.FONT_XS)
			if u.hp<=0:
				var ko=l(name_box,"戦闘不能");ko.add_theme_font_size_override("font_size",Tokens.FONT_XS);ko.add_theme_color_override("font_color",Tokens.DANGER)
			var entries: Array=by_character.get(str(uid),{}).get("entries",[])
			var items_flow=HFlowContainer.new();items_flow.size_flags_horizontal=Control.SIZE_EXPAND_FILL;items_flow.size_flags_vertical=Control.SIZE_SHRINK_CENTER
			items_flow.add_theme_constant_override("h_separation",Tokens.SPACE_MD);items_flow.add_theme_constant_override("v_separation",Tokens.SPACE_XS);member.add_child(items_flow)
			if entries.is_empty():
				var empty_lbl=muted(items_flow,"所持品なし");empty_lbl.autowrap_mode=TextServer.AUTOWRAP_OFF;empty_lbl.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;empty_lbl.add_theme_font_size_override("font_size",Tokens.FONT_SM)
			else:
				for entry in entries:
					var item_row=HBoxContainer.new();item_row.add_theme_constant_override("separation",Tokens.SPACE_XS);items_flow.add_child(item_row)
					var icon_key=ui.icons.equipment(entry) if entry.get("kind")=="equipment" else "items" if entry.get("kind")=="quest" else str(entry.id)
					ui.icons.add(item_row,icon_key,24)
					var item_label=l(item_row,"%s ×%d" % [str(entry.get("name",entry.id)),int(entry.get("count",1))])
					item_label.autowrap_mode=TextServer.AUTOWRAP_OFF;item_label.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;item_label.add_theme_font_size_override("font_size",Tokens.FONT_SM)
			var open_inventory=b(member,"インベントリ",party_view.open_inventory.bind(str(uid)),false,"md")
			open_inventory.name="InventoryOwner_"+str(uid);open_inventory.size_flags_horizontal=Control.SIZE_SHRINK_END
		var footer_box=VBoxContainer.new();footer_box.add_theme_constant_override("separation",Tokens.SPACE_NONE)
		footer_box.custom_minimum_size.y=cell_y;layout.add_child(footer_box)
		var footer_divider=ColorRect.new();footer_divider.name="CampaignItemsFooterDivider";footer_divider.color=Tokens.BORDER;footer_divider.custom_minimum_size.y=Tokens.BORDER_WIDTH;footer_divider.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer_divider.mouse_filter=Control.MOUSE_FILTER_IGNORE;footer_box.add_child(footer_divider)
		var footer_margin=MarginContainer.new();footer_margin.size_flags_vertical=Control.SIZE_EXPAND_FILL
		footer_margin.add_theme_constant_override("margin_left",Tokens.SPACE_MD);footer_margin.add_theme_constant_override("margin_right",Tokens.SPACE_MD)
		footer_box.add_child(footer_margin)
		var footer_row=row(footer_margin);footer_row.name="CampaignItemsActions";footer_row.alignment=BoxContainer.ALIGNMENT_END
		var return_target="map" if c().get("phase")=="camp" else "hub"
		var back=b(footer_row,"戻る",ui.navigate.bind(return_target),false,"md");back.name="ItemsReturn"
		return
	var catalog=ItemMenu.definitions(c());var inventory: Dictionary=c().inventory
	var selected_item={}
	for item in catalog:
		if item.id==item_id:selected_item=item
	if item_stage=="target" and selected_item.is_empty():reset_items()
	var controls=card(parent)
	var panel=controls.get_parent();panel.name="CampaignItems";panel.custom_minimum_size.y=grid_height(2)
	if item_stage=="entry":
		var entry=ui.icons.apply(b(controls,"アイテム",show_items.bind("list")),"items");entry.name="CampaignItemEntry";ui.memory.key(entry,"campaign_item_entry")
	elif item_stage=="list":
		l(controls,"アイテム / 種類を選択",true)
		var choices=row(controls);choices.name="CampaignItemList"
		for item in catalog:
			var control=ui.icons.apply(b(choices,"%s %s / %d個" % [item.name,ItemMenu.effect(item),inventory.get(item.id,0)],show_items.bind("target",item.id),int(inventory.get(item.id,0))<=0),str(item.id))
			preload("res://equipment_tooltip.gd").bind_hover(control,{"name":item.name,"kind":"item","definition":item},c())
			ui.memory.key(control,"campaign_item_"+str(item.id))
		b(controls,"戻る",show_items.bind("entry"))
	else:
		ui.icons.line(ui,controls,str(selected_item.id),"%s / 対象を選択" % selected_item.name,true)
		l(controls,"%s / 残り%d個。生存している編成中の仲間に使用します。" % [ItemMenu.effect(selected_item),inventory.get(item_id,0)])
		b(controls,"アイテム一覧へ",show_items.bind("list"))
	var members=item_members(parent)
	for u in roster():
		if not c().selected.has(u.id):continue
		var member=card(members);member.name="ItemMember_"+str(u.id);member.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var portrait=ui.portrait(member,u,false,64);portrait.name="FullBodyPortrait";portrait.custom_minimum_size=Vector2(64,160 if ui.ui_size_mode=="standard" else 48);portrait.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var name_label=l(member,u.name);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;ui.short_name(name_label,str(u.name));name_label.add_theme_font_size_override("font_size",Tokens.FONT_SM)
		var hp=ui.icons.line(ui,member,"hp","HP %d/%d" % [u.hp,u.max]);ui.emphasize_low_hp(hp,u)
		ui.icons.line(ui,member,"mp","MP %d/%d" % [u.mp,u.maxMp])
		if u.hp<=0:l(member,"戦闘不能")
		if item_stage=="target":
			var reason=ItemMenu.camp_reason(selected_item,u,inventory)
			var target=b(member,"使う" if reason.is_empty() else reason,use_selected_item.bind(u.id),not reason.is_empty());target.name="ItemTarget_"+str(u.id);ui.memory.key(target,"item_target_"+str(u.id))
			target.theme_type_variation=&"ActionButton"
func inn(parent):inn_view.render(parent)
func shop(parent):
	if facility_entry.render_top(parent,"shop"):return
	facility_entry.render_dialogue()
	if c().get("location") not in ["east","west","south","north"]:l(parent,"この拠点にお店はありません");return
	shop_view.render(parent)
func select_slot(slot: String):await shop_view.select_slot(slot)
func purchase(_q: Dictionary):shop_view.confirm_purchase()
func buy(id: String):
	await shop_view.confirm_purchase(id)
func return_to_town(parent):
	parent.add_theme_constant_override("separation",Tokens.SPACE_NONE)
	var actions=row(parent);actions.name="TownReturnRow";actions.alignment=BoxContainer.ALIGNMENT_END
	actions.custom_minimum_size.y=grid_height(9)-grid_height(8)
	var back=b(actions,"広場に移動",acknowledge.bind("hub"),ui.page=="party" and guild_view.busy())
	Tokens.apply_button_size(back)
	back.name="GuildReturn" if ui.page=="party" else "InnReturn" if ui.page=="inn" else "TownReturn"

func result(parent):
	var result_: Dictionary=c().get("result",{});var outcome=result_.get("outcome","")
	var delivery_status: String=ui.results_view.delivery_status(result_)
	l(parent,delivery_status if not delivery_status.is_empty() else {"failed":"クエスト失敗 / 出発前へ","travel":"目的地に到着"}.get(outcome,"旅の結果"),true)
	quest_board.render_sluice_story(parent,result_)
	if outcome=="failed":
		l(parent,result_.get("reason","護送隊が敗北しました"))
		l(parent,"受注直前の状態へ戻しました。自由移動の場合は出発直前へ戻ります。")
		muted(parent,"所持金・装備・編成・HP/MP・道具・経験値・経過時間を復元しています。")
	elif outcome=="travel":l(parent,"依頼を受けずに移動しました。配達報酬はありません。戦闘の経験値は保持されます。")
	else:l(parent,"荷物を届けました。報酬と成長を持ち越して、次の依頼や買い物へ進めます。")
	ui.icons.line(ui,parent,"money","今回の配達報酬 %dG" % result_.get("gold",0),true)
	ui.icons.line(ui,parent,"experience","各同行者の配達経験値 %d" % result_.get("xp",0))
	ui.icons.line(ui,parent,"money","所持金 %dG" % c().gold)
	if result_.get("hours")!=null:l(parent,"所要時間 %d時間" % result_.hours)
	l(parent,"現在地: "+town(c().location)+"。ここで施設を利用し、次の出発を選べます。")

func acknowledge(page: String):
	if ui.results_view.active and ui.results_view.current.get("acknowledge",false):await ui.results_view.advance_to(page);return
	ui.page=page;await ui.act("acknowledge",[])

func select_party(id: String):
	if not ui.can_inspect_member(id):return
	if id!=party_uid and not party_view.guard_leave(select_party.bind(id)):return
	party_uid=id;ui.memory.request_focus("party_"+id);ui.render()
func change_membership(id: String):
	if not c().get("guildAvailable",false):return
	party_uid=id
	await ui.toggle_member(id)
	ui.memory.request_focus("party_"+id,true);ui.memory.restore()
func offered() -> Array:
	return shop_view.offered()
func selection_key(id: String) -> String:
	var character=c().get("characters",{}).get(ui.shop_uid,{}).duplicate(true)
	for key in ["inventory","hp","mp"]:character.erase(key)
	return JSON.stringify([epoch,ui.engine.connection_generation,c().get("location"),ui.shop_uid,ui.shop_slot,id,c().get("gold"),character,c().get("selected")])
func quote_valid() -> bool:
	return not quote_pending and not ui.gear_preview.is_empty() and quote_stamp==selection_key(gear_id)
func invalidate_quote(clear_id:=false):
	quote_generation+=1;quote_pending=false;quote_stamp="";ui.gear_preview={}
	if clear_id:gear_id=""
func reset_context():
	warehouse_view.reset()
	quest_board.reset();inn_view.reset();ui.mock_shell.roster_jobs.clear()
	hub_view.reset()
	facility_art.reset()
	if ui.hud!=null:ui.hud.reset_context()
	reset_items();facility_entry.reset();shop_view.reset();guild_view.reset();party_view.reset()
	epoch+=1;invalidate_quote(true);trial_return={};cached_quotes={}
func request_quote(id: String):await shop_view.select_product(id)
func select_member(uid: String):await shop_view.select_member(uid)
func remember_trial(args: Array):
	shop_view.stage="S8";shop_view.background.clear()
	ui.memory.capture()
	trial_return={"epoch":epoch,"location":c().get("location"),"uid":args[0],"gear":args[1],"slot":args[2],"filter":shop_view.filter_slot,"scrolls":ui.memory.scrolls.duplicate(true),"focus":"product_"+str(args[1])}
func start_trial():await shop_view.start_trial()
func restore_trial():
	if trial_return.is_empty() or trial_return.get("epoch")!=epoch:return
	var previous=trial_return.duplicate(true);trial_return={}
	if c().get("location")!=previous.location:ui.notice="試用前の店が変わったため選択を解除しました";invalidate_quote(true);return
	ui.page="shop";ui.shop_uid=previous.uid;party_uid=previous.uid;ui.shop_slot=previous.slot;shop_view.filter_slot=previous.get("filter","all")
	if not c().get("selected",[]).has(ui.shop_uid) or not offered().any(func(g):return g.id==previous.gear):
		invalidate_quote(true);ui.notice="試用前の人物・商品を確認できないため選択を解除しました";ui.render();return
	ui.memory.scrolls.merge(previous.scrolls,true)
	shop_view.back_list()
	ui.memory.scrolls.merge(previous.scrolls,true);ui.memory.request_focus(previous.focus);ui.memory.restore()

func describe_gear(parent,gear: Dictionary,party_detail:=false):
	var comparison=shop_view.comparison_view
	comparison.gear_summary(parent,gear,comparison.equipment_rows(gear,gear)[0])
	if not party_detail and gear.has("price"):l(parent,"購入価格 %dG" % int(gear.price))
	for key in ["str","int","agi"]:
		if int(gear.get(key,0))>0:l(parent,"必要%s：%d" % [key.to_upper(),int(gear[key])])
	var grants=preload("res://equipment_grants.gd").list(gear)
	if not grants.is_empty():
		var icons=HFlowContainer.new();parent.add_child(icons)
		for grant in grants:
			var id=str(grant.id);var level=int(grant.level);var title=str(c().skillNames.get(id,id))
			var button=ui.button(icons,"Lv%d" % level,ui.show_skill_details.bind(id,title,level,gear))
			button.icon=comparison.skill_texture(id,level);button.expand_icon=true;button.custom_minimum_size.x=96;button.add_theme_constant_override("icon_max_width",40)
			button.accessibility_name=title+" Lv%d" % level
			preload("res://comparison_skill_icon.gd").bind_hover(button,id,title,level,c(),gear)
	comparison.equipment_notes(parent,gear)
