extends RefCounted
## Shared campaign chrome. All values and operations come from the game bridge.
var ui
const INK=Color("#29332f")
const PAPER=Color("#faf9f5")
const GREEN=Color("#345c4e")
func _init(frontend):ui=frontend
func style(fill: Color=PAPER) -> StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=fill;s.border_color=Color("#cbd0c8");s.set_border_width_all(1);s.set_corner_radius_all(3);s.set_content_margin_all(8);return s
func content_height() -> float:
	return maxf(584,ui.size.y-148)
func apply_theme():
	ui.theme.default_font_size=20
	for kind in ["Label","Button","OptionButton","CheckButton","RichTextLabel","TabBar","LineEdit","SpinBox"]:
		for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:ui.theme.set_color(key,kind,INK)
		ui.theme.set_color("font_disabled_color",kind,Color("#929b93"))
	for kind in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed","disabled"]:ui.theme.set_stylebox(state,kind,style(Color("#e0e8dd") if state in ["hover","pressed"] else PAPER))
	ui.theme.set_stylebox("panel","PanelContainer",style())
	for key in ["normal","focus","read_only"]:ui.theme.set_stylebox(key,"LineEdit",style())
	for key in ["embedded_border","embedded_unfocused_border"]:
		var frame=style(GREEN);frame.expand_margin_top=32
		ui.theme.set_stylebox(key,"Window",frame)
	ui.theme.set_constant("title_height","Window",32)
	ui.theme.set_color("title_color","Window",PAPER)
	ui.theme.set_stylebox("panel","TabContainer",style())
	for state in ["tab_selected","tab_unselected","tab_hovered","tab_disabled"]:
		ui.theme.set_stylebox(state,"TabContainer",style(Color("#e0e8dd") if state=="tab_selected" else PAPER))
	for key in ["font_selected_color","font_unselected_color","font_hovered_color","font_focus_color"]:ui.theme.set_color(key,"TabContainer",INK)
	ui.menu.add_theme_stylebox_override("panel",style())
func navigation(parent):
	var panel=PanelContainer.new();panel.add_theme_stylebox_override("panel",style());parent.add_child(panel)
	var bar=ui.row(panel);bar.name="CampaignHeader";bar.custom_minimum_size.y=56
	var brand=ui.label_(bar,"5525",true);brand.size_flags_horizontal=Control.SIZE_FILL;brand.custom_minimum_size.x=160
	for pair in [["hub","ローカルマップ"],["character","パーティ情報"],["board","クエスト"],["map","ワールドマップ"]]:
		var nav=ui.button(bar,pair[1],ui.navigate.bind(pair[0]),ui.campaign().get("phase")!="town" and pair[0]=="hub");nav.name="Header_"+pair[0];nav.custom_minimum_size=Vector2(140,44);ui.mark_selected(nav,ui.page==pair[0])
	var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bar.add_child(spacer)
	ui.icons.line(ui,bar,"money",str(int(ui.campaign().get("gold",0)))+" G")
	ui.local_button(bar,"メニュー",ui.open_menu)
func needs_roster() -> bool:
	return ui.page!="board" and not ui.pages.facility_entry.at_top() and ui.campaign().get("phase")!="result"
func workspace(parent) -> VBoxContainer:
	var row=ui.row(parent);row.name="CampaignWorkspace";row.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;row.add_theme_constant_override("separation",16)
	if needs_roster():
		var ids=ui.campaign().get("selected",[])
		if not ids.is_empty() and not ids.has(ui.pages.party_uid):ui.pages.party_uid=str(ids[0])
		roster(row)
	var body=VBoxContainer.new();body.name="CampaignBody";body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.size_flags_vertical=Control.SIZE_EXPAND_FILL;row.add_child(body);return body
func roster(parent):
	var panel=PanelContainer.new();panel.name="PartyRoster";panel.custom_minimum_size=Vector2(280,content_height());panel.size_flags_horizontal=Control.SIZE_FILL;panel.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;panel.add_theme_stylebox_override("panel",style());parent.add_child(panel)
	var body=VBoxContainer.new();panel.add_child(body)
	var ids=ui.campaign().get("selected",[])
	ui.label_(body,"パーティメンバー     %d / %d" % [ids.size(),ui.campaign().get("partyLimit",12)])
	var list=ui.scroller(body);list.get_parent().custom_minimum_size.y=content_height()-64;list.add_theme_constant_override("separation",0)
	for id in ids:
		var matches=ui.roster().filter(func(u):return str(u.id)==str(id))
		if matches.is_empty():continue
		var u=matches[0];var button=ui.button(list,"",activate.bind(str(id)));button.set_script(preload("res://roster_drop_target.gd"));button.member_id=str(id);button.name="RosterMember_"+str(id);button.custom_minimum_size=Vector2(254,88)
		ui.mark_selected(button,str(id)==ui.pages.party_uid)
		var line=HBoxContainer.new();button.add_child(line);line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);line.offset_left=6;line.offset_top=6;line.offset_right=-6;line.offset_bottom=-6;line.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var portrait=ui.portrait(line,u,false,32);portrait.custom_minimum_size=Vector2(40,72);portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var info=VBoxContainer.new();info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;info.mouse_filter=Control.MOUSE_FILTER_IGNORE;line.add_child(info)
		var name=ui.label_(info,str(u.name));name.add_theme_font_size_override("font_size",18);name.autowrap_mode=TextServer.AUTOWRAP_OFF;name.clip_text=true
		var hp=ui.label_(info,"HP %d/%d   MP %d/%d" % [u.hp,u.max,u.mp,u.maxMp]);hp.add_theme_font_size_override("font_size",16)
		var inventory=ui.campaign().get("inventoryByCharacter",{}).get(str(id),{});var capacity=inventory.get("capacity",{});var weight=inventory.get("weight",{});var stats=u.get("stats",u)
		var detail=ui.label_(info,"%s / %s   Wt %s / %s" % [int(capacity.get("used",0)),int(capacity.get("limit",0)) if capacity.get("limit")!=null else "∞",int(weight.get("total",0)) if weight.get("total")!=null else "?",int(stats.get("str",0))]);detail.add_theme_font_size_override("font_size",16)
		if weight.get("total")!=null and float(weight.total)>float(stats.get("str",0)):detail.add_theme_color_override("font_color",Color("#b04430"))
		for child in info.get_children():child.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.set_drag_forwarding(Callable(),func(_at,payload):return can_drop(payload,str(id)),func(_at,payload):drop(payload,str(id)))
func activate(id: String):
	if not ui.pages.party_view.guard_leave(activate.bind(id)):return
	ui.pages.party_uid=id
	if ui.pages.warehouse_view.available():ui.pages.warehouse_view.select_owner(id);return
	if ui.pages.guild_view.available():ui.pages.guild_view.select_current(id);return
	if ui.page=="shop":ui.pages.shop_view.owner_pressed(id);return
	ui.navigate("character")
func can_drop(payload,id: String) -> bool:
	if payload is Dictionary and payload.get("kind")=="character_transfer":return payload.get("owner")!=id
	if ui.page=="shop":return ui.pages.shop_view.can_drop_product(payload,id)
	if ui.pages.guild_view.available():return not ui.pages.guild_view.drop_operation(payload,id,false).is_empty()
	return false
func drop(payload,id: String):
	if payload is Dictionary and payload.get("kind")=="character_transfer":ui.pages.party_view.workspace.drop(payload,id);return
	if ui.page=="shop":ui.pages.shop_view.confirm_purchase(str(payload.item),id)
	elif ui.pages.guild_view.available():ui.pages.guild_view.drop_member(payload,id,false)
