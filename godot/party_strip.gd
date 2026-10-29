extends HBoxContainer
## Session-only scrolling and deployment payloads; the campaign remains authoritative.
var owner_ref: WeakRef
var view:
	get:return owner_ref.get_ref()
var ui:
	get:return view.ui
var scroll: ScrollContainer
var left: Button
var right: Button
const Drag=preload("res://deployment_drag.gd")
func build(owner):
	owner_ref=weakref(owner);name="PartyFaceBar"
	var standard=ui.ui_size_mode=="standard"
	custom_minimum_size.y=84 if standard else 74
	size_flags_horizontal=Control.SIZE_EXPAND_FILL;mouse_filter=Control.MOUSE_FILTER_PASS
	add_theme_constant_override("separation",6)
	left=ui.button(self,"‹",slide.bind(-1));left.name="PartySlideLeft";left.custom_minimum_size=Vector2(38,custom_minimum_size.y);left.tooltip_text="パーティー一覧を左へ";left.set_meta("no_status_hint",true)
	scroll=ScrollContainer.new();scroll.name="PartyFacesScroll";scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;add_child(scroll);ui.memory.watch(scroll,"party_faces")
	var members=HBoxContainer.new();members.name="PartyFaces";members.add_theme_constant_override("separation",6);members.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.add_child(members)
	var deployed=Drag.deployed(ui) if ui.campaign().get("phase")=="deployment" else []
	for id in ui.campaign().get("selected",[]):
		var matches=ui.roster().filter(func(member):return str(member.id)==str(id))
		if matches.is_empty():continue
		var member=matches[0]
		var disabled_=(ui.modal_open() and view.detail_uid.is_empty()) or (ui.pages.guild_view.available() and ui.pages.guild_view.busy()) or ui.pages.shop_view.stage in ["S4","S5"] or ui.pages.shop_view.unknown
		var control=ui.button(members,"",func():pass,disabled_)
		control.set_script(preload("res://party_member_card.gd"));control.configure(self,str(id))
		control.name="PartyFace_"+str(id);control.set_meta("member_id",str(id));control.set_meta("no_status_hint",true)
		control.custom_minimum_size=Vector2(96 if standard else 86,custom_minimum_size.y-18);control.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;control.size_flags_vertical=Control.SIZE_EXPAND_FILL
		control.icon=ui.portraits.texture(member,true);control.expand_icon=true;control.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER;control.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP;control.add_theme_constant_override("icon_max_width",46 if standard else 32);control.clip_text=true
		control.tooltip_text=str(member.name)+(" / 戦闘不能" if member.hp<=0 else "")+"\nHP%d/%d MP%d/%d" % [member.hp,member.max,member.mp,member.maxMp]+" / ステータスを開く"
		if ui.campaign().get("phase")=="deployment":
			var badge=Label.new();badge.name="DeploymentMemberState";badge.text="出場" if deployed.has(str(id)) else "控え";badge.add_theme_font_size_override("font_size",13);badge.add_theme_color_override("font_color",Color("#d7ebd5") if deployed.has(str(id)) else Color("#e8cc94"));badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;control.add_child(badge);badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);badge.offset_top=-21;badge.offset_bottom=-2;badge.offset_right=-4
			if member.hp<=0:
				badge.text="戦闘不能";badge.add_theme_color_override("font_color",Color("#ffac9a"))
				control.tooltip_text+=" / 戦闘不能のため出場できません。"
				if deployed.has(str(id)):
					badge.hide()
					var remove=ui.button(control,"除外",remove_inactive.bind(str(id),Drag.signature(ui),ui.pages.epoch,ui.engine.connection_generation),ui.modal_open())
					remove.name="DeploymentRemoveInactive_"+str(id);remove.tooltip_text="戦闘不能の出場枠を外して控えへ戻します。HPや所持品は変わりません。";remove.set_meta("no_status_hint",true);remove.add_theme_font_size_override("font_size",12);remove.custom_minimum_size=Vector2(0,22);remove.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);remove.offset_top=-24;remove.offset_bottom=-2;remove.offset_left=3;remove.offset_right=-3
					for state_ in ["normal","hover","pressed","disabled"]:
						var style=remove.get_theme_stylebox(state_).duplicate();style.content_margin_top=0;style.content_margin_bottom=0;remove.add_theme_stylebox_override(state_,style)
			else:control.tooltip_text+=" / 盤面から一覧へドラッグで控えに戻す" if deployed.has(str(id)) else " / 盤面へ上向きにドラッグで出場・入替"
		if str(id)==view.detail_uid or (ui.pages.shop_view.sale_mode() and str(id)==ui.pages.shop_view.selected_owner()) or (ui.pages.warehouse_view.available() and str(id)==ui.pages.warehouse_view.owner_id):view.tint(control,Color("#243c68"))
		elif ui.pages.guild_view.available() and str(id)==ui.pages.guild_view.chosen_id:view.tint(control,Color("#236044"))
		elif deployed.has(str(id)):view.tint(control,Color("#294b51"))
		ui.memory.key(control,"face_"+str(id));ui.memory.item(control,str(id))
	if guild_drag():
		var slot=Button.new();slot.name="GuildPartyAppend";slot.text="満員" if ui.campaign().get("selected",[]).size()>=ui.pages.guild_view.party_limit() else "＋";slot.custom_minimum_size=Vector2(72,custom_minimum_size.y-18);slot.tooltip_text="控えをここへドラッグして末尾に追加";members.add_child(slot);slot.set_drag_forwarding(Callable(),func(_at,data):return can_drop(data),func(_at,data):drop(data))
	right=ui.button(self,"›",slide.bind(1));right.name="PartySlideRight";right.custom_minimum_size=Vector2(38,custom_minimum_size.y);right.tooltip_text="パーティー一覧を右へ";right.set_meta("no_status_hint",true)
	scroll.get_h_scroll_bar().value_changed.connect(func(_v):refresh_arrows())
	scroll.resized.connect(refresh_arrows,CONNECT_DEFERRED);refresh_arrows.call_deferred()
func refresh_arrows():
	if not is_instance_valid(scroll) or not is_instance_valid(right):return
	var bar=scroll.get_h_scroll_bar();var overflow=bar.max_value>bar.page+1
	left.disabled=not overflow or scroll.scroll_horizontal<=0 or ui.locked or ui.presenting
	right.disabled=not overflow or scroll.scroll_horizontal>=bar.max_value-bar.page-1 or ui.locked or ui.presenting
	left.set_meta("base_disabled",left.disabled);right.set_meta("base_disabled",right.disabled)
func slide(direction: int):
	if ui.locked or ui.presenting:return
	scroll.scroll_horizontal+=direction*int(maxf(120,scroll.size.x*.7));refresh_arrows()
func activate(id: String):
	if ui.locked or ui.presenting or ui.closing or ui.engine.disconnected:return
	view.portrait_pressed(id)
func remove_inactive(id: String,stamp: String,epoch: int,connection: int):
	if not Drag.available(ui) or stamp!=Drag.signature(ui) or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation or not Drag.deployed(ui).has(id):return
	for member in ui.roster():
		if str(member.id)==id and member.hp<=0:ui.deployment_assigned(id,null);return
func guild_drag() -> bool:return ui.pages.guild_view.available()
func drag_payload(id: String):
	return ui.pages.guild_view.drag_payload(id) if guild_drag() else Drag.make_payload(ui,id,"party")
func can_drop(data,uid: String="") -> bool:
	if guild_drag():return not ui.pages.guild_view.drop_operation(data,uid,uid.is_empty()).is_empty()
	if Drag.valid(ui,data):return data.source=="board"
	return not uid.is_empty() and ui.page=="shop" and not ui.pages.shop_view.sale_mode() and ui.pages.shop_view.can_drop_product(data,uid) if data is Dictionary else false
func drop(data,uid: String=""):
	if guild_drag():
		ui.pages.guild_view.drop_member(data,uid,uid.is_empty());return
	if Drag.valid(ui,data) and data.source=="board":
		if Drag.consume(ui,data):ui.deployment_assigned(str(data.uid),null)
	elif can_drop(data,uid):ui.pages.shop_view.confirm_purchase(str(data.item),uid)
func _can_drop_data(_at: Vector2,data) -> bool:return can_drop(data)
func _drop_data(_at: Vector2,data):drop(data)
