extends RefCounted
## Shared campaign chrome. All values and operations come from the game bridge.
var ui
var roster_jobs := {}
const Tokens=preload("res://ui_tokens.gd")
const INK=Tokens.INK
const PAPER=Tokens.SURFACE
const MUTED_INK=Tokens.MUTED_INK
const GREEN=Tokens.ACCENT
const ROSTER_WIDTH=280
const COLUMN_GAP=Tokens.SPACE_LG
const SHOP_CATALOG_WIDTH=440
const SURFACE_ALPHA=Tokens.SURFACE_ALPHA
const NESTED_SURFACE_ALPHA=Tokens.NESTED_SURFACE_ALPHA
const Grid=preload("res://screen_grid.gd")
func _init(frontend):ui=frontend
static func style(fill: Color=PAPER) -> StyleBoxFlat:
	return Tokens.box(fill)
## Apply transparency to the painted surface only, never to text or child controls.
## A nested card lightly separates content without making the outer window opaque.
static func surface_style(fill: Color=PAPER,nested:=false) -> StyleBoxFlat:
	return Tokens.surface_box(fill,nested)
func content_height() -> float:
	return ui.size.y-grid_cell().y*2
func grid_cell() -> Vector2:
	return Grid.cell_rect(ui.size,0,0,1,1).size
# Variations share resources across both scene themes. A disabled action always
# uses the same neutral appearance, even if it was previously selected.
static func apply_button_theme(target: Theme):
	var disabled=Tokens.box(Tokens.BTN_DISABLED)
	var focus=Tokens.box(Color.TRANSPARENT,Tokens.FOCUS,Tokens.RADIUS_SM,Tokens.SPACE_SM,Tokens.BORDER_WIDTH_EMPHASIS)
	var colors={
		&"Button":[Tokens.SURFACE,Tokens.BTN_HOVER,Tokens.BTN_PRESSED],
		&"ActionButton":[Tokens.ACTION,Tokens.ACTION_HOVER,Tokens.ACTION_PRESSED],
		&"SelectedButton":[Tokens.SELECTED,Tokens.SELECTED_HOVER,Tokens.SELECTED_PRESSED],
		&"DestinationButton":[Tokens.DEST,Tokens.DEST_HOVER,Tokens.DEST_PRESSED],
	}
	for role in colors:
		var types=[role]
		if role==&"Button":types.append_array([&"OptionButton",&"CheckButton",&"CheckBox",&"MenuButton"])
		else:target.set_type_variation(role,&"Button")
		var ink=Tokens.INK_INVERSE if role==&"ActionButton" else Tokens.INK
		for type in types:
			target.set_stylebox("focus",type,focus)
			target.set_stylebox("disabled",type,disabled)
			target.set_color("font_disabled_color",type,Tokens.MUTED_INK)
			for key in ["font_color","font_focus_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]:
				target.set_color(key,type,ink)
		for i in 3:
			var state=["normal","hover","pressed"][i]
			var box=Tokens.box(colors[role][i])
			if role==&"SelectedButton":
				box.border_color=Tokens.BORDER_ACCENT;box.set_border_width_all(Tokens.BORDER_WIDTH_EMPHASIS)
			for type in types:
				target.set_stylebox(state,type,box)
				if state=="pressed":target.set_stylebox("hover_pressed",type,box)
	for type in [&"TabBar",&"TabContainer"]:
		for pair in [["tab_unselected","normal"],["tab_hovered","hover"],["tab_disabled","disabled"]]:
			target.set_stylebox(pair[0],type,target.get_stylebox(pair[1],&"Button"))
		target.set_stylebox("tab_selected",type,target.get_stylebox("normal",&"SelectedButton"))
		target.set_stylebox("tab_focus",type,focus)
		for key in ["font_selected_color","font_unselected_color","font_hovered_color"]:
			target.set_color(key,type,Tokens.INK)
		target.set_color("font_disabled_color",type,Tokens.MUTED_INK)
	target.set_type_variation(&"DisabledButtonText",&"Label")
	target.set_color("font_color",&"DisabledButtonText",Tokens.MUTED_INK)

# A Button only paints its own text. Inventory rows and map pins also contain Labels.
static func bind_button_text(button: Button,content: Control):
	button.draw.connect(func():
		var role=(&"DisabledButtonText" if button.disabled else &"")
		if content.get_meta("button_text_role",&"")==role:return
		content.set_meta("button_text_role",role)
		for label in content.find_children("*","Label",true,false):
			label.theme_type_variation=role)

func apply_theme():
	ui.theme.default_font_size=Tokens.FONT_BODY
	for kind in ["Label","RichTextLabel","LineEdit","SpinBox"]:
		for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:ui.theme.set_color(key,kind,Tokens.INK)
		ui.theme.set_color("font_disabled_color",kind,Tokens.MUTED_INK)
	ui.theme.set_stylebox("panel","PanelContainer",surface_style())
	ui.theme.set_stylebox("panel","AcceptDialog",style())
	ui.theme.set_stylebox("read_only","TextEdit",style())
	ui.theme.set_color("font_readonly_color","TextEdit",Tokens.INK)
	for key in ["normal","focus","read_only"]:ui.theme.set_stylebox(key,"LineEdit",style())
	ui.theme.set_stylebox("panel","TooltipPanel",Tokens.surface_box(Tokens.SURFACE,false,Tokens.RADIUS_SM,Tokens.SPACE_MD))
	ui.theme.set_color("font_color","TooltipLabel",Tokens.INK)
	ui.theme.set_font_size("font_size","TooltipLabel",Tokens.FONT_SM)
	for key in ["embedded_border","embedded_unfocused_border"]:
		var frame=Tokens.box(Tokens.ACCENT,Tokens.BORDER_ACCENT,Tokens.RADIUS_SM,Tokens.SPACE_SM)
		frame.expand_margin_top=Tokens.WINDOW_BAR_HEIGHT
		ui.theme.set_stylebox(key,"Window",frame)
	ui.theme.set_constant("title_height","Window",ui.preferences.TITLE_HEIGHT)
	ui.theme.set_color("title_color","Window",Tokens.INK_INVERSE)
	ui.theme.set_stylebox("panel","TabContainer",surface_style(Tokens.SURFACE,true))
var character_origin := "hub"

func toggle_character():
	if ui.locked or ui.presenting:return
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

func add_header_menu_button(parent: Node,button_name: String="") -> Button:
	var menu_btn=ui.local_button(parent,"メニュー",ui.open_menu)
	if not button_name.is_empty():menu_btn.name=button_name
	menu_btn.theme_type_variation=&"ActionButton"
	Tokens.apply_button_size(menu_btn,Tokens.BUTTON_MD,true,Tokens.BUTTON_W_SM)
	ui.memory.key(menu_btn,"game_menu")
	return menu_btn

func build_header_panel(parent: Node,panel_name: String,content_name: String,elapsed_name: String,title_text: String,title_name: String="") -> Dictionary:
	var panel=PanelContainer.new()
	panel.name=panel_name
	panel.mouse_filter=Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size.y=maxf(float(Tokens.BUTTON_MD),grid_cell().y)
	panel.add_theme_stylebox_override("panel",surface_style())
	parent.add_child(panel)
	var bar=ui.row(panel)
	bar.name=content_name
	bar.custom_minimum_size.y=Tokens.BUTTON_MD
	bar.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	bar.add_theme_constant_override("separation",Tokens.SPACE_MD)
	var elapsed=Label.new()
	elapsed.name=elapsed_name
	elapsed.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	elapsed.text=elapsed_time_text()
	bar.add_child(elapsed)
	var title=ui.label_(bar,title_text,true)
	if not title_name.is_empty():title.name=title_name
	title.size_flags_horizontal=Control.SIZE_FILL
	title.custom_minimum_size.x=160
	title.autowrap_mode=TextServer.AUTOWRAP_OFF
	title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	title.clip_text=true
	title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	return {"panel":panel,"bar":bar,"elapsed":elapsed,"title":title}

func refresh_header_panel(panel: PanelContainer,elapsed: Label,title: Label,available: Vector2,active: bool):
	panel.add_theme_stylebox_override("panel",surface_style())
	panel.custom_minimum_size.y=Grid.cell_rect(available,0,0,10,1).size.y if active else float(Tokens.BUTTON_MD)
	elapsed.text=elapsed_time_text()
	title.add_theme_font_size_override("font_size",Tokens.FONT_DISPLAY if available.x>=1800 else Tokens.FONT_HEADING)
	for caption in [elapsed,title]:
		caption.remove_theme_color_override("font_color")
		caption.remove_theme_color_override("font_outline_color")
		caption.remove_theme_constant_override("outline_size")

func navigation(parent):
	var parts=build_header_panel(parent,"CampaignHeader","CampaignHeaderContent","CampaignElapsedTime",ui.header.text,"HeaderLocation")
	var bar: HBoxContainer=parts.bar
	var town=ui.campaign().get("phase")=="town"
	var facility=ui.pages.facility_entry
	var links=[]
	if ui.page=="character":
		pass
	elif not town:
		links=[["board","クエスト",toggle_journey_quest]]
	elif facility.supported(ui.page):
		links=[["hub",facility.facility_name(ui.page),ui.navigate.bind("hub")]]
	elif ui.page=="board":
		links=[["board","掲示板",ui.navigate.bind("hub")]]
	elif ui.page=="map":
		links=[["map","ワールドマップ",ui.navigate.bind("hub")]]
	for link in links:
		var blocked=facility.supported(ui.page) and (ui.pages.shop_view.busy() or ui.pages.warehouse_view.pending)
		var nav=ui.button(bar,link[1],link[2],blocked)
		nav.name="Header_"+str(link[0]);Tokens.apply_button_size(nav,Tokens.BUTTON_MD,true,Tokens.BUTTON_W_MD)
		ui.mark_selected(nav,ui.page==link[0] or facility.supported(ui.page))
	var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;spacer.mouse_filter=Control.MOUSE_FILTER_IGNORE;bar.add_child(spacer)
	ui.icons.line(ui,bar,"money",str(int(ui.campaign().get("gold",0)))+" G").name="HeaderGold"
	add_header_menu_button(bar)
func elapsed_time_text() -> String:
	return "経過時間：%d時間" % int(ui.campaign().get("worldTime",0))
func needs_roster() -> bool:
	var phase=str(ui.campaign().get("phase",""))
	if phase=="town" and ui.page in ["hub","map","board","inn"]:return false
	if phase=="prepare":return false
	if phase!="town" and ui.page not in ["character","items"] and ui.pages.travel_map_expanded:return false
	return ui.page not in ["board","inn"] and not ui.pages.facility_entry.at_top() and (ui.page=="character" or phase!="result")
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
	Tokens.apply_button_size(chooser,Tokens.BUTTON_MD,false);chooser.tooltip_text="職業で絞り込む"
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
		var detail_row=HBoxContainer.new();detail_row.mouse_filter=Control.MOUSE_FILTER_IGNORE;detail_row.add_theme_constant_override("separation",Tokens.SPACE_MD);info.add_child(detail_row)
		var cap_label=Label.new();cap_label.text="%s / %s" % [int(capacity.get("used",0)),int(capacity.get("limit",0)) if capacity.get("limit")!=null else "∞"];cap_label.add_theme_font_size_override("font_size",Tokens.FONT_SM);cap_label.autowrap_mode=TextServer.AUTOWRAP_OFF;cap_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;detail_row.add_child(cap_label)
		var wt_label=Label.new();wt_label.text="Wt %s / %s" % [int(weight.get("total",0)) if weight.get("total")!=null else "?",int(stats.get("str",0))];wt_label.add_theme_font_size_override("font_size",Tokens.FONT_SM);wt_label.autowrap_mode=TextServer.AUTOWRAP_OFF;wt_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;detail_row.add_child(wt_label)
		if weight.get("total")!=null and float(weight.total)>float(stats.get("str",0)):wt_label.add_theme_color_override("font_color",Tokens.DANGER)
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
	var line=HBoxContainer.new();button.add_child(line);line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);line.offset_left=Tokens.SPACE_XS;line.offset_top=Tokens.SPACE_XS;line.offset_right=-Tokens.SPACE_XS;line.offset_bottom=-Tokens.SPACE_XS;line.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bind_button_text(button,line)
	var portrait=ui.portrait(line,u,false,32);portrait.custom_minimum_size=Vector2(40,72);portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var info=VBoxContainer.new();info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;info.mouse_filter=Control.MOUSE_FILTER_IGNORE;info.name="MemberInfo";info.add_theme_constant_override("separation",2);line.add_child(info)
	var name=ui.label_(info,str(u.name));name.add_theme_font_size_override("font_size",Tokens.FONT_BODY);name.autowrap_mode=TextServer.AUTOWRAP_OFF;name.clip_text=true
	var hp=ui.label_(info,"HP %d/%d   MP %d/%d" % [u.hp,u.max,u.mp,u.maxMp]);hp.add_theme_font_size_override("font_size",Tokens.FONT_SM)
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
