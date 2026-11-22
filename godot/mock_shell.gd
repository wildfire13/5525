extends RefCounted
## Shared campaign chrome. All values and operations come from the game bridge.
var ui
var roster_jobs := {}
const INK=Color("#29332f")
const PAPER=Color("#faf9f5")
const MUTED_INK=Color("#606960")
const GREEN=Color("#345c4e")
const ROSTER_WIDTH=280
const COLUMN_GAP=16
const SHOP_CATALOG_WIDTH=440
const SURFACE_ALPHA=0.90
const NESTED_SURFACE_ALPHA=0.12
const Grid=preload("res://screen_grid.gd")
func _init(frontend):ui=frontend
static func style(fill: Color=PAPER) -> StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=fill;s.border_color=Color("#cbd0c8");s.set_border_width_all(1);s.set_corner_radius_all(3);s.set_content_margin_all(8);return s
## Apply transparency to the painted surface only, never to text or child controls.
## A nested card lightly separates content without making the outer window opaque.
static func surface_style(fill: Color=PAPER,nested:=false) -> StyleBoxFlat:
	var surface=style(fill)
	surface.bg_color.a=NESTED_SURFACE_ALPHA if nested else SURFACE_ALPHA
	return surface
func content_height() -> float:
	return ui.size.y-grid_cell().y*2
func grid_cell() -> Vector2:
	return Grid.cell_rect(ui.size,0,0,1,1).size
func apply_theme():
	ui.theme.default_font_size=20
	for kind in ["Label","Button","OptionButton","CheckButton","RichTextLabel","TabBar","LineEdit","SpinBox"]:
		for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:ui.theme.set_color(key,kind,INK)
		ui.theme.set_color("font_disabled_color",kind,MUTED_INK)
	for kind in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed","disabled"]:ui.theme.set_stylebox(state,kind,style(Color("#e0e8dd") if state in ["hover","pressed"] else PAPER))
	ui.theme.set_stylebox("panel","PanelContainer",surface_style())
	ui.theme.set_stylebox("panel","AcceptDialog",style())
	ui.theme.set_stylebox("read_only","TextEdit",style())
	ui.theme.set_color("font_readonly_color","TextEdit",INK)
	for key in ["normal","focus","read_only"]:ui.theme.set_stylebox(key,"LineEdit",style())
	for key in ["embedded_border","embedded_unfocused_border"]:
		var frame=surface_style(GREEN);frame.expand_margin_top=32
		ui.theme.set_stylebox(key,"Window",frame)
	ui.theme.set_constant("title_height","Window",ui.preferences.TITLE_HEIGHT)
	ui.theme.set_color("title_color","Window",PAPER)
	ui.theme.set_stylebox("panel","TabContainer",surface_style(PAPER,true))
	for state in ["tab_selected","tab_unselected","tab_hovered","tab_disabled"]:
		ui.theme.set_stylebox(state,"TabContainer",style(Color("#e0e8dd") if state=="tab_selected" else PAPER))
	for key in ["font_selected_color","font_unselected_color","font_hovered_color","font_focus_color"]:ui.theme.set_color(key,"TabContainer",INK)
	ui.menu.add_theme_stylebox_override("panel",surface_style())
var character_origin := "hub"

func toggle_character():
	if ui.page=="party" and ui.pages.guild_view.busy():return
	if not ui.pages.party_view.guard_leave(toggle_character):return
	if ui.page=="character":ui.page=character_origin
	else:
		character_origin=ui.page
		ui.page="character"
	ui.memory.focus_key=""
	ui.render()

func toggle_journey_quest():
	if not (ui.campaign().get("activeQuest") is Dictionary):
		ui.save_notice.display("進行中のクエストはありません")
		return
	ui.navigate("map" if ui.page=="board" else "board")

func navigation(parent):
	var panel=PanelContainer.new();panel.name="CampaignHeader";panel.custom_minimum_size.y=grid_cell().y;panel.add_theme_stylebox_override("panel",surface_style());parent.add_child(panel)
	var bar=ui.row(panel);bar.name="CampaignHeaderContent";bar.custom_minimum_size.y=56
	var elapsed=Label.new()
	elapsed.name="CampaignElapsedTime"
	elapsed.text=elapsed_time_text()
	bar.add_child(elapsed)
	var place=ui.label_(bar,ui.header.text,true)
	place.name="HeaderLocation";place.size_flags_horizontal=Control.SIZE_FILL;place.custom_minimum_size.x=160
	var town=ui.campaign().get("phase")=="town"
	var facility=ui.pages.facility_entry
	var links=[]
	if ui.page=="character":
		links=[["character","パーティ情報",toggle_character]]
	elif not town:
		links=[["character","パーティ情報",toggle_character],["board","クエスト",toggle_journey_quest]]
	elif facility.supported(ui.page):
		links=[["hub",facility.facility_name(ui.page),ui.navigate.bind("hub")]]
	elif ui.page=="board":
		links=[["board","掲示板",ui.navigate.bind("hub")]]
	elif ui.page=="map":
		links=[["map","ワールドマップ",ui.navigate.bind("hub")]]
	for link in links:
		var blocked=facility.supported(ui.page) and (ui.pages.shop_view.busy() or ui.pages.warehouse_view.pending)
		var nav=ui.button(bar,link[1],link[2],blocked)
		nav.name="Header_"+str(link[0]);nav.custom_minimum_size=Vector2(140,44)
		ui.mark_selected(nav,ui.page==link[0] or facility.supported(ui.page))
	var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bar.add_child(spacer)
	ui.icons.line(ui,bar,"money",str(int(ui.campaign().get("gold",0)))+" G")
	ui.memory.key(ui.local_button(bar,"メニュー",ui.open_menu),"game_menu")
func elapsed_time_text() -> String:
	return "経過時間：%d時間" % int(ui.campaign().get("worldTime",0))
func needs_roster() -> bool:
	return ui.page!="board" and not ui.pages.facility_entry.at_top() and ui.campaign().get("phase")!="result"
func columns(parent: Control) -> HBoxContainer:
	var row=ui.row(parent)
	row.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	row.add_theme_constant_override("separation",COLUMN_GAP)
	return row
func workspace(parent) -> VBoxContainer:
	if ui.page=="character" or ui.pages.warehouse_view.available() or (ui.page=="shop" and not ui.pages.facility_entry.at_top()):
		var scroll=ScrollContainer.new()
		scroll.name="MemberWorkspaceScroll"
		scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
		scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
		parent.add_child(scroll)
		ui.memory.watch(scroll,"member_workspace_"+ui.page)
		parent=scroll
	var row=columns(parent);row.name="CampaignWorkspace"
	row.add_theme_constant_override("separation",0)
	row.custom_minimum_size.y=content_height()
	if parent is ScrollContainer:row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if needs_roster():
		var ids=ui.campaign().get("selected",[])
		if not ids.is_empty() and not ids.has(ui.pages.party_uid):ui.pages.party_uid=str(ids[0])
		roster(row)
	var body=VBoxContainer.new();body.name="CampaignBody";body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.size_flags_vertical=Control.SIZE_EXPAND_FILL;row.add_child(body);return body
func job_filter(parent,selected: String,changed: Callable) -> OptionButton:
	var chooser=OptionButton.new();parent.add_child(chooser);chooser.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	chooser.custom_minimum_size.y=40;chooser.tooltip_text="職業で絞り込む"
	chooser.add_item("すべて");chooser.set_item_metadata(0,"")
	var jobs=[]
	for member in ui.roster():
		var job=str(member.get("job",""))
		if job.is_empty() or jobs.has(job):continue
		jobs.append(job);chooser.add_item(str(member.get("role",job)));chooser.set_item_metadata(chooser.item_count-1,job)
		if job==selected:chooser.select(chooser.item_count-1)
	chooser.item_selected.connect(func(index):changed.call(str(chooser.get_item_metadata(index))))
	return chooser
func roster(parent,deployment=null):
	var panel=PanelContainer.new();panel.name="PartyRoster";panel.custom_minimum_size=Vector2(ROSTER_WIDTH,content_height());panel.size_flags_horizontal=Control.SIZE_FILL;panel.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;panel.add_theme_stylebox_override("panel",surface_style());parent.add_child(panel)
	if deployment!=null:
		panel.custom_minimum_size.y=0
		panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	else:panel.custom_minimum_size.x=grid_cell().x*2
	var body=VBoxContainer.new();panel.add_child(body)
	var ids=ui.campaign().get("selected",[])
	ui.label_(body,"パーティメンバー     %d / %d" % [ids.size(),ui.campaign().get("partyLimit",12)])
	var scene="deployment" if deployment!=null else str(ui.page)
	var job=str(roster_jobs.get(scene,""))
	var filter=job_filter(body,job,func(value):
		roster_jobs[scene]=value
		for row in body.find_children("*","Button",true,false):
			if row.has_meta("roster_job"):row.visible=value.is_empty() or row.get_meta("roster_job")==value
		if deployment==null and ui.pages.guild_view.available():
			ui.pages.guild_view.match_current_filter(value))
	filter.name="PartyJobFilter"
	var list=ui.scroller(body);list.get_parent().name="PartyRosterScroll";ui.memory.watch(list.get_parent(),"deployment_roster" if deployment!=null else "mock_party_roster")
	list.get_parent().size_flags_vertical=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",0)
	for id in ids:
		var matches=ui.roster().filter(func(u):return str(u.id)==str(id))
		if matches.is_empty():continue
		var u=matches[0]
		var button=ui.button(list,"",activate.bind(str(id)) if deployment==null else func():pass)
		button.set_meta("roster_job",u.job);button.visible=job.is_empty() or u.job==job
		button.custom_minimum_size=Vector2(254,88)
		ui.memory.key(button,"mock_roster_member_"+str(id))
		var selected=ui.pages.shop_view.selected_owner() if ui.pages.shop_view.sale_mode() else ui.pages.party_uid
		ui.mark_selected(button,str(id)==(ui.selected if deployment!=null else selected))
		var line=roster_member_line(button,u)
		var info=line.get_node("MemberInfo")
		var inventory=ui.campaign().get("inventoryByCharacter",{}).get(str(id),{});var capacity=inventory.get("capacity",{});var weight=inventory.get("weight",{});var stats=u.get("stats",u)
		var detail=ui.label_(info,"%s / %s   Wt %s / %s" % [int(capacity.get("used",0)),int(capacity.get("limit",0)) if capacity.get("limit")!=null else "∞",int(weight.get("total",0)) if weight.get("total")!=null else "?",int(stats.get("str",0))]);detail.add_theme_font_size_override("font_size",16)
		if weight.get("total")!=null and float(weight.total)>float(stats.get("str",0)):detail.add_theme_color_override("font_color",Color("#b04430"))
		for child in info.get_children():child.mouse_filter=Control.MOUSE_FILTER_IGNORE
		if deployment!=null:
			deployment.configure_deployment_card(button,u,line)
			continue
		button.name="RosterMember_"+str(id)
		button.set_script(preload("res://roster_drop_target.gd"))
		button.member_id=str(id)
		button.set_drag_forwarding(Callable(),func(_at,payload):return can_drop(payload,str(id)),func(_at,payload):drop(payload,str(id)))
	if deployment==null and ui.pages.guild_view.available():ui.pages.guild_view.remove_button(body)
	return panel
func roster_member_line(button: Button,u: Dictionary) -> HBoxContainer:
	button.custom_minimum_size.y=88
	var line=HBoxContainer.new();button.add_child(line);line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);line.offset_left=6;line.offset_top=6;line.offset_right=-6;line.offset_bottom=-6;line.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var portrait=ui.portrait(line,u,false,32);portrait.custom_minimum_size=Vector2(40,72);portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var info=VBoxContainer.new();info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;info.mouse_filter=Control.MOUSE_FILTER_IGNORE;info.name="MemberInfo";line.add_child(info)
	var name=ui.label_(info,str(u.name));name.add_theme_font_size_override("font_size",18);name.autowrap_mode=TextServer.AUTOWRAP_OFF;name.clip_text=true
	var hp=ui.label_(info,"HP %d/%d   MP %d/%d" % [u.hp,u.max,u.mp,u.maxMp]);hp.add_theme_font_size_override("font_size",16)
	for child in info.get_children():child.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return line
func refresh_roster_selection():
	var roster_panel=ui.content.find_child("PartyRoster",true,false)
	if roster_panel==null:return
	for control in roster_panel.find_children("RosterMember_*","Button",true,false):
		var selected=control.member_id==ui.pages.party_uid
		if selected!=control.get_meta("selected",false):ui.mark_selected(control,selected)

func activate(id: String):
	if ui.page=="character" and ui.pages.party_uid==id:
		toggle_character()
		return
	if not ui.pages.party_view.guard_leave(activate.bind(id)):return
	if ui.page=="shop":ui.pages.shop_view.owner_pressed(id);return
	ui.pages.party_uid=id
	if ui.pages.warehouse_view.available():ui.pages.warehouse_view.select_owner(id);return
	if ui.pages.guild_view.available():ui.pages.guild_view.select_current(id);return
	if ui.page=="character":ui.pages.party_view.workspace.refresh()
	else:toggle_character()
func can_drop(payload,id: String) -> bool:
	if payload is Dictionary and payload.get("kind")=="character_transfer":
		if ui.page=="shop" and (ui.pages.shop_view.busy() or ui.modal_open() or payload.get("owner")!=ui.shop_uid):return false
		return payload.get("owner")!=id or payload.get("allowed",[]).has(id)
	if ui.page=="shop":return ui.pages.shop_view.can_drop_product(payload,id)
	if ui.pages.guild_view.available():return not ui.pages.guild_view.drop_operation(payload,id,false).is_empty()
	return false
func drop(payload,id: String):
	if payload is Dictionary and payload.get("kind")=="character_transfer":ui.pages.party_view.workspace.drop(payload,id);return
	if ui.page=="shop":ui.pages.shop_view.confirm_purchase(str(payload.item),id)
	elif ui.pages.guild_view.available():ui.pages.guild_view.drop_member(payload,id,false)
