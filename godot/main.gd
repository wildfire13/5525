extends Control
var engine
var portraits=preload("res://portraits.gd").new()
var icons=preload("res://ui_icons.gd").new()
var audio
var data: Dictionary={}
var preview: Dictionary={}
var pending=null
var chosen: Array=[]
var command := "attack"
var page := "board"
var selected := ""
var shop_uid := "guard"
var shop_slot := "rightHand"
var formation := "convoy"
var destination := ""
var pages
var gear_preview: Dictionary={}
var notice := ""
var locked := false
var presenting := false
var closing := false
var checks_fast := false
var base: VBoxContainer
var top: HBoxContainer
var header: Label
var resource_header: HBoxContainer
var gold_header: Label
var xp_header: Label
var content: VBoxContainer
var battle_row: HBoxContainer
var board
var side: VBoxContainer
var battle_header: VBoxContainer
var battle_actions: Control
var footer: Label
var actor_row: HBoxContainer
var widgets: Array[Button]=[]
var view_kind := ""
var generation := 0
var retry_button: Button
var low_hp_font: FontVariation
var memory
var hud
var dialog
var actor_face: TextureRect
var town_back: Button
var status_override := ""
var modal_escape_frame := -1
var ui_size_mode := "standard"
var menu: PopupPanel
var preview_pending := false
var preview_ready := false
var rendering := false
var layout_queued := false
var focus_hint := ""
var swallow_mouse_release := false
var skip_capture_once := false
const BG=Color("#0e1e28")
func _ready():
	pages=preload("res://campaign_panels.gd").new(self)
	memory=preload("res://ui_memory.gd").new(self)
	hud=preload("res://battle_hud.gd").new(self)
	dialog=preload("res://ui_dialog.gd").new(self)
	get_tree().auto_accept_quit=false
	get_tree().root.gui_embed_subwindows=true
	var theme_=Theme.new();theme_.default_font_size=18
	theme_.set_color("font_color","TooltipLabel",Color.WHITE)
	var tip=StyleBoxFlat.new();tip.bg_color=Color("#183341");tip.set_content_margin_all(8);theme_.set_stylebox("panel","TooltipPanel",tip)
	var focus=StyleBoxFlat.new();focus.bg_color=Color(0,0,0,0);focus.set_border_width_all(2);focus.border_color=Color("#78edce")
	for type_ in ["Button","OptionButton","CheckButton","ItemList","TabBar"]:theme_.set_stylebox("focus",type_,focus)
	for type_ in ["Button","OptionButton"]:
		for state_ in ["normal","hover","pressed","disabled"]:
			var style=StyleBoxFlat.new();style.bg_color=Color("#2b4355" if state_=="hover" else "#244b51" if state_=="pressed" else "#20333f");style.border_color=Color("#5a7486");style.set_border_width_all(1);style.set_corner_radius_all(4)
			style.content_margin_left=8;style.content_margin_right=8;style.content_margin_top=4;style.content_margin_bottom=4;theme_.set_stylebox(state_,type_,style)
		theme_.set_color("font_disabled_color",type_,Color("#b0bfc9"))
	theme=theme_
	low_hp_font=FontVariation.new();low_hp_font.base_font=ThemeDB.fallback_font;low_hp_font.variation_embolden=1.0
	base=VBoxContainer.new();add_child(base);base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.add_theme_constant_override("separation",8)
	top=HBoxContainer.new();top.custom_minimum_size.y=44;base.add_child(top)
	actor_face=portrait(top,{},true,40);actor_face.visible=false
	header=Label.new();header.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.clip_text=true;header.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;top.add_child(header)
	resource_header=row(top);gold_header=icons.line(self,resource_header,"money","");xp_header=icons.line(self,resource_header,"experience","")
	town_back=button(top,"拠点へ",navigate.bind("board"));town_back.visible=false
	local_button(top,"メニュー",open_menu)
	retry_button=button(top,"再接続",func():confirm("ゲーム接続を再開します。失われた未保存の進行は復元できません。\n再接続後、保存済みファイルを読み込んでください。",reconnect_engine));retry_button.visible=false
	audio=preload("res://audio.gd").new();add_child(audio)
	menu=PopupPanel.new();menu.name="CommonMenu";add_child(menu)
	var menu_body=VBoxContainer.new();menu.add_child(menu_body)
	for item in [["拠点・旅程へ",func():navigate("board")],["保存",save_game],["読込",load_dialog],["ログ保存",save_log],["画像",portrait_dialog],["新しい旅",func():confirm("未保存の進行を終了し、新しい旅を始めます。保存済みファイルは変更しません。",new_game)]]:
		var callback: Callable=item[1]
		button(menu_body,item[0],func():menu.hide();callback.call())
	local_button(menu_body,"操作説明",func():menu.hide();show_status_details())
	local_button(menu_body,"全画面 F11",func():menu.hide();fullscreen())
	for pair in [["bgm","BGM"],["voice","ボイス"],["se","SE"]]:
		var check=CheckButton.new();check.text=pair[1]+"ミュート";check.custom_minimum_size.y=40;menu_body.add_child(check)
		check.toggled.connect(func(value):audio.set_mute(pair[0],value);audio.sync(data))
	local_button(menu_body,"閉じる",menu.hide)
	content=VBoxContainer.new();content.size_flags_vertical=Control.SIZE_EXPAND_FILL;base.add_child(content)
	footer=Label.new();footer.name="StatusFooter";footer.custom_minimum_size.y=24;footer.clip_text=true;footer.max_lines_visible=1;footer.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;base.add_child(footer)
	footer.focus_mode=Control.FOCUS_ALL;footer.mouse_filter=Control.MOUSE_FILTER_STOP;footer.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;memory.key(footer,"status_footer")
	footer.gui_input.connect(func(event):
		if (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_SPACE]):
			show_status_details();footer.accept_event())
	engine=preload("res://engine_bridge.gd").new();add_child(engine)
	resized.connect(queue_layout)
	if not engine.start_engine():notice=engine.last_error;render();return
	await update({"op":"campaign_start"})
func campaign() -> Dictionary: return data.get("campaign") if data.get("campaign") is Dictionary else {}
func state() -> Dictionary: return data.get("state") if data.get("state") is Dictionary else {}
func roster() -> Array: return campaign().get("roster",[])
func label_(parent: Node,text: String,large:=false) -> Label:
	var l=Label.new();l.text=text;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if parent is HBoxContainer:l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if large:l.add_theme_font_size_override("font_size",28 if size.x>=1800 else 23)
	parent.add_child(l);return l
func emphasize_low_hp(label: Label,unit: Dictionary):
	if unit.get("max",0)>0 and unit.get("hp",0)*4<unit.max:
		label.add_theme_color_override("font_color",Color("#ff9494"))
		label.add_theme_font_override("font",low_hp_font)
func row(parent: Node) -> HBoxContainer:
	var r=HBoxContainer.new();r.add_theme_constant_override("separation",8);parent.add_child(r);return r
func button(parent: Node,text: String,fn: Callable,disabled:=false) -> Button:
	var b=Button.new();b.text=text;b.custom_minimum_size.y=56 if size.x>=1800 and size.y>=1000 else 44
	b.set_meta("base_disabled",disabled);b.disabled=disabled or locked or presenting or (engine!=null and engine.disconnected)
	parent.add_child(b);widgets.append(b)
	b.pressed.connect(func():
		if not closing and (b.get_meta("read_only",false) or (not locked and not presenting and not b.disabled)):status_override="";fn.call())
	b.focus_entered.connect(func():
		# Popup-local controls must not replace the underlying screen explanation.
		if b.get_window()!=get_window():return
		focus_hint=b.tooltip_text
		if is_instance_valid(footer) and notice.is_empty():set_status(focus_hint))
	b.focus_exited.connect(func():
		if b.get_window()==get_window():focus_hint="")
	return b
func set_status(message: String):
	# Newlines and wrapping must never enlarge the fixed status row.
	footer.text=message.replace("\r","").replace("\n"," / ")
	footer.tooltip_text=message;footer.set_meta("full_message",message)
func show_status_details():
	if find_child("StatusDetails",true,false)!=null:return
	var message=str(footer.get_meta("full_message",footer.text))
	var saved_notice=notice;var saved_hint=focus_hint;var epoch=pages.epoch;var generation=engine.connection_generation
	var popup=PopupPanel.new();popup.name="StatusDetails";popup.exclusive=true;add_child(popup)
	var box=VBoxContainer.new();box.custom_minimum_size.x=mini(620,int(size.x)-48);popup.add_child(box)
	var body=scroller(box);body.get_parent().custom_minimum_size.y=mini(240,int(size.y)-120)
	label_(body,message)
	var close=local_button(box,"閉じる",popup.hide)
	popup.popup_hide.connect(func():
		if not closing and pages.epoch==epoch and engine.connection_generation==generation and notice==saved_notice:
			focus_hint=saved_hint;status_override=message;set_status(message);footer.grab_focus()
		popup.queue_free())
	popup.popup_centered();close.grab_focus()
func clear(node: Node):
	for child in node.get_children():node.remove_child(child);child.queue_free()
func portrait(parent: Node,u: Dictionary,face:=false,size_:=72) -> TextureRect:
	var p=TextureRect.new();p.custom_minimum_size=Vector2(size_,size_);p.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;p.texture=portraits.texture(u,face)
	parent.add_child(p);return p
func card(parent: Node) -> VBoxContainer:
	var p=PanelContainer.new();var style=StyleBoxFlat.new();style.bg_color=Color("#172b36");style.border_color=Color("#385260");style.set_border_width_all(1)
	style.set_corner_radius_all(9);style.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel",style);parent.add_child(p)
	var v=VBoxContainer.new();p.add_child(v);return v
func scroller(parent: Node) -> VBoxContainer:
	var s=ScrollContainer.new();s.size_flags_vertical=Control.SIZE_EXPAND_FILL;s.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;parent.add_child(s)
	var v=VBoxContainer.new();v.size_flags_horizontal=Control.SIZE_EXPAND_FILL;s.add_child(v);return v
func confirm(text: String,fn: Callable):
	# Snapshot immediately before modal focus changes: wheels do not trigger a render.
	memory.capture()
	var scroll_state=memory.scrolls.duplicate(true)
	var epoch=pages.epoch;var generation=engine.connection_generation
	var origin=get_viewport().gui_get_focus_owner()
	var origin_key=str(origin.get_meta("ui_key","")) if origin!=null else memory.focus_key
	var d=ConfirmationDialog.new();d.exclusive=true;d.title="確認";d.dialog_text=text;d.ok_button_text="はい";d.cancel_button_text="戻る"
	for button_ in [d.get_ok_button(),d.get_cancel_button()]:button_.custom_minimum_size=Vector2(96,56) if size.x>=1800 else Vector2(80,44)
	if is_instance_valid(dialog.window) and dialog.window.visible:dialog.window.add_child(d)
	else:add_child(d)
	d.confirmed.connect(func():
		if d.get_meta("submitted",false) or locked or presenting:return
		d.set_meta("submitted",true);d.hide();d.queue_free();fn.call())
	d.canceled.connect(func():
		audio.ui("cancel");d.hide();d.queue_free()
		if not closing and pages.epoch==epoch and engine.connection_generation==generation:
			memory.scrolls.merge(scroll_state,true);memory.request_focus(origin_key);memory.restore())
	d.popup_centered(Vector2i(mini(560,int(size.x)-32),230));d.get_cancel_button().grab_focus()
	return d
func fullscreen():
	get_window().mode=Window.MODE_WINDOWED if get_window().mode==Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
func _unhandled_key_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F11:fullscreen();get_viewport().set_input_as_handled()
		elif event.keycode==KEY_ESCAPE:
			if modal_escape_frame==Engine.get_process_frames():get_viewport().set_input_as_handled();return
			if menu.visible:menu.hide()
			elif is_instance_valid(dialog.window):dialog.close()
			elif pages.shop_view.escape():pass
			elif pages.close_items():pass
			elif hud.close_detail():pass
			elif not presenting:cancel()
			get_viewport().set_input_as_handled()
func _notification(what):
	if what==NOTIFICATION_WM_CLOSE_REQUEST and not closing:close_game()
func close_game():
	closing=true;invalidate_preview()
	while engine.busy:await get_tree().process_frame
	if data.get("presentation")!=null:await engine.request({"op":"presentation_finish","id":data.presentation.id})
	await audio.finish_audio();engine.close_engine()
	await get_tree().process_frame
	get_tree().quit()
func update(request: Dictionary,frontend: Dictionary={}) -> Dictionary:
	if locked or closing:return {"ok":false,"error":"処理中です"}
	locked=true;status_override=""
	while engine.busy and not closing:await get_tree().process_frame
	if closing:locked=false;return {"ok":false,"error":"終了しています"}
	for b in widgets:
		if is_instance_valid(b) and not b.get_meta("read_only",false):b.disabled=true
	if footer!=null:set_status("処理中…")
	var reply: Dictionary=await engine.request(request)
	locked=false
	if request.get("op")=="campaign" and request.get("action") not in ["begin","finishBattle","endTrial","trial","forecast","previewGear","inventoryQuote","purchasePlan","saleQuote"] and reply.get("presentation")==null:
		audio.ui("confirm" if reply.get("ok",false) else "cancel")
	if reply.get("ok",false):
		if reply.has("campaign"):
			if frontend.has("images"):
				portraits.activate(frontend.images);audio.restore(frontend.music)
			if request.get("op") in ["campaign_load","campaign_start"]:pages.reset_context();memory.reset();skip_capture_once=true
			invalidate_preview();data=reply
		notice=""
	else:
		notice=str(reply.get("error","操作できません"))
		if reply.get("connection_lost",false):invalidate_preview();pages.reset_context()
	if closing:return reply
	render()
	if data.get("presentation")!=null and not presenting and not engine.disconnected:await present()
	return reply
func present():
	presenting=true
	while data.get("presentation")!=null and not closing:
		render()
		var p: Dictionary=data.presentation
		var visual_duration=board.animate(p) if board else 0.0
		var duration=maxf(audio.phase(p),visual_duration)
		await get_tree().create_timer(0.001 if checks_fast else duration).timeout
		if closing:break
		var response: Dictionary=await engine.request({"op":"presentation_next","id":p.id,"index":p.index})
		if not response.get("ok",false):notice=response.get("error","演出を進められません");break
		data=response
	presenting=false
	if not closing:render()
func act(action: String,args: Array=[]):
	if locked or presenting or closing:return
	if action=="trial":pages.remember_trial(args)
	invalidate_preview()
	var response=await update({"op":"campaign","action":action,"args":args,"presentation":action=="begin"})
	if action=="endTrial" and response.get("ok",false):await pages.restore_trial()
	return response
func reconnect_engine():
	if engine.start_engine():await new_game()
	else:notice=engine.last_error;render()
func invalidate_preview():
	if hud!=null:hud.discard_reference();hud.invalidate_hover()
	generation+=1;pending=null;chosen=[];preview={};preview_ready=false;preview_pending=false
func handle_connection_loss(reply: Dictionary,connection: int) -> bool:
	# Loss belongs to the connection, not to the preview that happened to detect it.
	# Ignore notifications from a connection already replaced by an explicit reconnect.
	if closing or connection!=engine.connection_generation or not reply.get("connection_lost",false):return false
	invalidate_preview();pages.reset_context();status_override=""
	notice=str(reply.get("error","ゲーム接続が終了しました。再接続してください。"))
	render();return true
func new_game():
	invalidate_preview()
	portraits.activate({"version":1,"characters":{}});audio.restore({});gear_preview={};page="board"
	await update({"op":"campaign_start"})
func navigate(value: String):
	if not pages.party_view.guard_leave(navigate.bind(value)):return
	invalidate_preview();page=value;pages.reset_items();pages.invalidate_quote(false);memory.focus_key="";render()
func render():
	if rendering:return
	rendering=true
	if not skip_capture_once:memory.capture()
	skip_capture_once=false
	audio.follow_connection(engine.connection_generation);audio.sync(data)
	widgets=widgets.filter(func(b):return is_instance_valid(b) and (b.get_parent()==top or menu.is_ancestor_of(b)))
	for b in widgets:
		b.disabled=bool(b.get_meta("base_disabled",false)) or ((locked or presenting or (engine.disconnected and b!=retry_button)) and not b.get_meta("read_only",false))
	retry_button.visible=engine.disconnected
	var available=get_viewport_rect().size
	content.add_theme_constant_override("separation",8)
	ui_size_mode="standard" if available.x>=1120 and available.y>=720 else "compact"
	var margin=24 if available.x>=1800 and available.y>=1000 else 12 if ui_size_mode=="standard" else 8
	base.offset_left=margin;base.offset_right=-margin;base.offset_top=margin;base.offset_bottom=-margin
	theme.default_font_size=22 if available.x>=1800 and available.y>=1000 else 18 if ui_size_mode=="standard" else 16
	var c=campaign();var s=state();var phase=c.get("phase","")
	var place=c.get("journey",{}).get("destination",c.get("location","")) if phase=="arrival" and c.get("journey") is Dictionary else c.get("location","")
	header.text="5525 / %s / 隊Lv.%d / 編成%d/5人 / 累計%d時間" % [town_name(place),c.get("level",1),c.get("selected",[]).size(),c.get("hours",0)]
	gold_header.text="%dG" % c.get("gold",0);xp_header.text="経験値%d" % c.get("xp",0)
	header.tooltip_text=header.text+" / 経験値%d" % c.get("xp",0)
	var battle=not s.is_empty() and (phase in ["deployment","battle"] or data.get("trial")!=null)
	resource_header.visible=not battle and not (phase=="town" and page in ["party","shop"])
	actor_face.visible=battle
	town_back.visible=not battle and page in ["shop","party"] and phase=="town"
	top.custom_minimum_size.y=56 if battle and ui_size_mode=="standard" else 44
	footer.visible=not battle and page not in ["shop","party"]
	if battle:
		if view_kind!="battle":clear(content);hud.mount();view_kind="battle"
		render_battle()
	else:
		board=null;actor_row=null;clear(content);view_kind="page"
		var nav=row(content)
		var focused_page=phase=="town" and page in ["shop","party"]
		if focused_page:
			header.text="装備を購入" if page=="shop" else "仲間・装備"
			button(nav,"拠点へ",navigate.bind("board"));nav.visible=false
		var tabs_=[["board","掲示板"],["map","地図・出発"],["party","仲間・装備"],["shop","商店"]] if phase=="town" else [["board","旅程"],["items","道具"]]
		if phase=="town" and c.get("location")=="astaris":tabs_.append(["inn","宿屋"])
		for tab in ([] if focused_page else tabs_):
			var nb=button(nav,("● " if page==tab[0] else "")+tab[1],navigate.bind(tab[0]),phase!="town" and tab[0]=="items" and phase!="camp");memory.key(nb,"nav_"+tab[0])
		var body: VBoxContainer
		if phase=="town" and page in ["party","shop"]:
			body=VBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(body)
		else:body=scroller(content);memory.watch(body.get_parent(),"page_"+phase+"_"+page)
		if phase=="town":
			match page:
				"map":pages.map(body)
				"inn":pages.inn(body)
				"party":render_party(body)
				"shop":render_shop(body)
				"items":render_items(body)
				_:render_town(body)
		elif phase=="camp" and page=="items":render_items(body)
		else:render_journey(body)
		pages.party_view.face_bar(content)
	pages.party_view.refresh_modal()
	set_status(notice if not notice.is_empty() else status_override if not status_override.is_empty() else ("処理中…" if locked or preview_pending or pages.quote_pending else "演出中…" if presenting else focus_hint if not focus_hint.is_empty() else "選択 → プレビュー → 確定 / Escで取消"))
	rendering=false;memory.restore()
func town_name(id) -> String:
	for t in campaign().get("towns",[]):
		if t.id==id:return t.name
	return str(id)
func render_town(body):pages.board(body)
func render_journey(body):pages.journey(body)
func forecast_action(choice: String,action: String,args: Array):
	var r=await update({"op":"campaign","action":"forecast","args":[choice]})
	if r.get("ok",false):
		var f=r.get("forecast",{})
		if f.get("late",false):
			var q=campaign().get("activeQuest",{})
			confirm("以降を最短で進んでも納期を超えます。\n見込み %d時間 / 納期 %d時間\n超過 %d時間 / 見込み報酬 %dG\nこのまま進みますか？" % [f.get("hours",0),q.get("deadline",0),f.get("over",0),f.get("reward",0)],act.bind(action,args))
		else:await act(action,args)
func render_party(body):pages.party(body)
func toggle_member(uid: String):
	var ids=campaign().selected.duplicate()
	if ids.has(uid):ids.erase(uid)
	else:ids.append(uid)
	await act("select",[ids])
func render_items(body):pages.items(body)
func member_name(uid: String) -> String:
	for u in roster()+state().get("units",[]):
		if u.id==uid:return u.name
	return uid
func display_log(line: String) -> String:
	var regex=RegEx.new();regex.compile("\\((\\d+),(\\d+)\\)")
	var found=regex.search(line)
	if found:
		var x=int(found.get_string(1));var y=int(found.get_string(2))
		if x>=1 and x<=10 and y>=1 and y<=5:line=line.replace(found.get_string(),"(X%d,Y%d)" % [x-1,5-y])
	return line
func select_shop(uid: String):await pages.select_member(uid)
func render_shop(body):pages.shop(body)
func preview_gear(id: String):await pages.request_quote(id)
func inspect_movement(which: String):
	if command!="move" or pending==null:return
	await request_preview(which)
func render_battle():hud.render()
func command_hint() -> String:
	var a={}
	for u in state().get("units",[]):
		if u.id==state().get("actor"):a=u
	if a.is_empty():return ""

	var skill=data.get("skillInfo")
	var hints={
		"attack":"通常攻撃: 縦横距離%d以内。対象に届く武器のATKを合算。" % data.get("normalAttackReach",0),
		"move":"移動: 経路%d以内。キャラを通り抜け不可。侵入用装飾品の権限に従います。" % data.get("moveReach",2)+("味方を選ぶと位置交換。MP消費なし。" if a.get("job")=="porter" else ""),
		"skill":skill.get("description","") if skill is Dictionary else legacy_skill_description(str(data.get("skill","")),int(a.get("skillStage",2))),
		"return":"帰還: 装備中のみ、1戦1回。自陣の空きマスを指定。MP0・1行動。",
		"item":"ポーション: 射程無限、傷ついた生存味方のHP+55（上限まで）。共有在庫を1消費。",
		"ether":"エーテル: ポーターのみ、生存味方/自分へ射程無限。MP+3（上限まで）、1個・1行動。",
		"guard":"防御: 次の本人の番まで被ダメージ半減。MP消費なし。"}
	var hint=str(hints.get(command,""))
	if not hud.skill_unavailable_reason().is_empty():hint+="\n"+hud.skill_unavailable_reason()
	elif command!="guard" and data.get("choices",{}).get(command,[]).is_empty():hint+="\n今は合法な対象なし。射程・HP/MP・陣形・進路を確認してください。"
	return hint
func render_unit_details(parent: Node,s: Dictionary):
	label_(parent,"全員の状態",true)
	for u in s.get("units",[]):
		var status="%s: HP %d/%d MP %d AGI %d%s%s" % [u.name,u.hp,u.max,u.mp,u.agi," 防御" if u.get("guard",false) else ""," 戦闘不能" if u.hp<=0 else ""]
		var line=label_(parent,status)
		emphasize_low_hp(line,u)
		if u.get("cover")!=null:label_(parent,"かばう → "+member_name(str(u.cover)))
		if not u.get("covers",[]).is_empty():label_(parent,"防衛線 → "+"・".join(u.covers.map(func(id):return member_name(str(id)))))
		if u.side=="enemy" and u.hp>0 and u.get("intent") is Dictionary:
			var intent: Dictionary=u.intent
			var cells=[]
			for p in intent.get("cells",[]):cells.append("(X%d,Y%d)" % [int(p)%10,4-int(int(p)/10)])
			var target_text=""
			if intent.get("target") is String:target_text=" → "+member_name(intent.target)
			elif intent.get("target") is float or intent.get("target") is int:target_text=" → (X%d,Y%d)" % [int(intent.target)%10,4-int(int(intent.target)/10)]
			label_(parent,"予告: "+str(intent.get("name",""))+target_text+(" → "+", ".join(cells) if not cells.is_empty() else "")+" / "+str(intent.get("reason","")))
			if intent.get("destination")!=null:label_(parent,"移動予定: X%d,Y%d" % [int(intent.destination)%10,4-int(int(intent.destination)/10)])
func choose_command(value: String):
	if locked or presenting or closing or hud.range_reference:return
	if value=="items":hud.open_items();return
	if value=="skill" and data.get("skillset",[]).is_empty() and hud.has_return():value="return"
	invalidate_preview();command=value;hud.action_menu=false;hud.item_list=false;hud.selected_cell=-1;hud.selected_enemy=""
	if value=="skill":await prepare_skill_preview()
	render()
func prepare_skill_preview():
	# The engine requires the porter ID, but the effect belongs to the whole side.
	if command=="skill" and data.get("skill")=="陣形強化" and data.get("choices",{}).get("skill",[]).has(state().get("actor")):
		pending=state().actor
		await request_preview("attack")
func select_skill(id: String):
	if id=="returnHome":choose_command("return");return
	invalidate_preview();command="skill"
	await update({"op":"select_skill","skillId":id})
	await prepare_skill_preview()
func deploy_dragged(uid: String,pos: int):
	if locked or presenting:return
	await act("deploy",[uid,pos])
func on_cell(pos: int):
	if locked or presenting or closing or hud.range_reference or hud.item_list:return
	if command=="skill" and data.get("skill")=="陣形強化" and not hud.action_menu:return
	var s=state();var u=board.unit_at(pos)
	hud.selected_cell=pos
	if hud.action_menu and not s.get("deploying",false):render();return
	if u.get("side")=="enemy":hud.selected_enemy=str(u.id)
	if s.get("deploying",false):
		if selected.is_empty():
			if u.get("side")=="ally":selected=u.id;render()
		else:await act("deploy",[selected,pos])
		return
	var target=null
	if command in ["move","return"] or command=="skill" and data.get("skill")=="スタンプ":target=pos
	elif not u.is_empty():target=u.id
	if target==null:invalidate_preview();render();return
	generation+=1;preview={};preview_ready=false;preview_pending=false
	var options=data.get("choices",{}).get(command,[])
	if target is int:options=options.map(func(value):return int(value))
	var paired=command=="skill" and data.get("skillInfo")!=null and data.skillInfo.get("target") in ["pair","upToTwo"]
	if paired:
		if chosen.has(target):chosen.erase(target)
		elif chosen.size()<2:chosen.append(target)
		target=chosen.duplicate()
		for option in options:
			if option.size()==chosen.size() and option.all(func(id):return chosen.has(id)):target=option;break
	if not options.has(target):
		pending=null
		if not paired:chosen=[]
		render();return
	if not paired and target is String:chosen=[target]
	pending=target
	await request_preview("attack")
func request_preview(which: String):
	generation+=1;preview={};preview_ready=false;preview_pending=true
	var token=generation;var actor=state().get("actor");var action_count=state().get("actions");var kind=command
	var selected_target=pending.duplicate(true) if pending is Array else pending
	var target=JSON.stringify(selected_target);var skill=data.get("skill");var connection=engine.connection_generation;var epoch=pages.epoch
	render()
	while engine.busy and not closing:
		await get_tree().process_frame
		if token!=generation:return
	if closing or token!=generation:return
	var reply=await engine.request({"op":"preview","kind":kind,"target":selected_target,"previewKind":which})
	if handle_connection_loss(reply,connection):return
	if closing or token!=generation or epoch!=pages.epoch or connection!=engine.connection_generation:return
	preview_pending=false
	if reply.get("ok",false) and pending!=null and target==JSON.stringify(pending) and command==kind and state().get("actor")==actor and state().get("actions")==action_count and data.get("skill")==skill:
		preview=reply.preview;preview_ready=true;notice=""
	elif not reply.get("ok",false):
		notice=str(reply.get("error","予測を取得できませんでした"))
	render()
func cancel():
	if locked or presenting or closing:return
	if hud.range_reference:hud.close_reference();return
	if hud.item_list or command in ["skill","return"] and not hud.action_menu:hud.back_to_commands();return
	if command in ["item","ether"] and not hud.action_menu:hud.open_items();return
	var had_target=pending!=null or not chosen.is_empty()
	invalidate_preview();hud.selected_cell=-1;hud.selected_enemy=""
	if not had_target:hud.action_menu=true
	audio.ui("cancel");render()
func commit():
	if not can_commit():return
	var target=pending;invalidate_preview();audio.ui("confirm")
	await update({"op":"act","kind":command,"target":target,"presentation":true})
func file_dialog(mode: FileDialog.FileMode, filters: PackedStringArray, callback: Callable, filename: String=""):
	var d=FileDialog.new();d.access=FileDialog.ACCESS_FILESYSTEM;d.file_mode=mode;d.filters=filters
	d.use_native_dialog=false;d.exclusive=true;add_child(d);d.current_dir=ProjectSettings.globalize_path("user://")
	if not filename.is_empty():d.current_file=filename;d.title="保存先を選択";d.overwrite_warning_enabled=false
	d.file_selected.connect(func(path):d.queue_free();callback.call(path));d.canceled.connect(func():d.queue_free())
	d.popup_centered_ratio(.75)
func save_game():
	var r=await update({"op":"campaign_save"})
	if not r.get("ok",false):return
	var envelope: Dictionary=r.data
	envelope.nativePortraits=portraits.metadata.duplicate(true);envelope.godotFrontend=audio.frontend_save()
	file_dialog(FileDialog.FILE_MODE_SAVE_FILE,PackedStringArray(["*.json ; 5525進行セーブ"]),write_snapshot.bind(envelope,"進行"),"5525-godot-%d-%d.json" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()])
func write_snapshot(path: String,envelope: Dictionary,kind: String):
	var target=await update({"op":"godot_io","action":"write_target","path":path})
	if not target.get("ok",false):return
	if target.data.exists:
		var dialog=confirm("既存のファイルを"+kind+"で上書きしますか？\n"+path+"\n確認後に内容が変わった場合は保存を中止します。",publish_snapshot.bind(path,envelope.duplicate(true),kind,str(target.data.sha256),str(target.data.resolved_target)))
		dialog.name="OverwriteConfirmation"
	else:await publish_snapshot(path,envelope,kind,"",str(target.data.resolved_target))
func publish_snapshot(path: String,envelope: Dictionary,kind: String,expected_sha256: String="",resolved_target: String=""):
	var request={"op":"godot_io","action":"write","path":path,"data":envelope}
	if not resolved_target.is_empty():request.resolved_target=resolved_target
	if not expected_sha256.is_empty():request.overwrite=true;request.expected_sha256=expected_sha256
	var written=await update(request)
	if written.get("ok",false):notice=kind+"を保存しました: "+path;audio.ui("confirm");render()
func load_dialog():
	file_dialog(FileDialog.FILE_MODE_OPEN_FILE,PackedStringArray(["*.json ; 5525進行セーブ"]),func(path):confirm("現在の未保存の進行を置き換えて読み込みます。元の保存ファイルは変更しません。",load_game.bind(path)))
func load_game(path: String):
	invalidate_preview()
	var allowed=[]
	for u in roster():allowed.append(u.id)
	var r=await update({"op":"godot_io","action":"read","path":path,"allowed":allowed})
	if not r.get("ok",false):return
	var envelope: Dictionary=r.data
	var images: Dictionary=envelope.get("nativePortraits",{"version":1,"characters":{}})
	var music=envelope.get("godotFrontend",{})
	if not audio.valid_metadata(music):notice="旅曲の保存情報が不正です";render();return
	envelope.erase("nativePortraits");envelope.erase("godotFrontend")
	await update({"op":"campaign_load","data":envelope},{"images":images,"music":music})
func save_log():
	var r=await update({"op":"export"})
	if r.get("ok",false):
		file_dialog(FileDialog.FILE_MODE_SAVE_FILE,PackedStringArray(["*.json ; プレイログ（進行セーブとは別）"]),write_snapshot.bind(r.data,"プレイログ"),"5525-log-%d-%d.json" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()])
func portrait_dialog():
	if data.get("trial")!=null or campaign().get("phase") in ["battle","deployment"]:notice="画像変更は戦闘・試用の終了後にできます";render();return
	var d=Window.new();d.exclusive=true;d.title="キャラ画像";d.size=Vector2i(660,700);add_child(d)
	var body=scroller(d);body.get_parent().set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label_(body,"各キャラの画像を変更します。能力・装備は変わりません。")
	label_(body,"PNG / JPEG / WebP / BMP / GIF（先頭フレーム）、16MiBまで。透過・縦横比を保持し最大256pxに正規化。割当を残すには進行を保存してください。")
	d.window_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:d.queue_free())
	for u in roster():
		var r=row(body);portrait(r,u,false,55);label_(r,u.name)
		button(r,"画像を選ぶ",func():d.queue_free();file_dialog(FileDialog.FILE_MODE_OPEN_FILE,PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp,*.bmp,*.gif ; キャラ画像"]),import_portrait.bind(u.id)))
		button(r,"元に戻す",func():portraits.clear_member(u.id);notice="元の画像に戻しました。割当を残すには進行を保存してください。";d.queue_free();render(),not portraits.metadata.get("characters",{}).has(u.id))
	button(body,"閉じる",d.queue_free)
	d.close_requested.connect(d.queue_free);d.popup_centered()
func import_portrait(path: String,uid: String):
	var r=await update({"op":"godot_io","action":"portrait","path":path})
	if r.get("ok",false):portraits.assign(uid,r.data);notice="画像を変更しました。割当を残すには進行を保存してください。";render()

func can_commit() -> bool:
	if locked or presenting or closing or engine.disconnected or preview_pending or hud.range_reference or hud.action_menu or hud.item_list:return false
	if state().is_empty() or state().get("deploying",false) or state().get("result")!=null:return false
	if hud.acting().get("side")!="ally":return false
	return command=="guard" or (pending!=null and preview_ready and not preview.is_empty())
func local_button(parent: Node,text: String,callback: Callable) -> Button:
	var control=button(parent,text,callback);control.set_meta("read_only",true);control.disabled=false;return control
func primary(control: Button) -> Button:
	control.custom_minimum_size.y=44;control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var style=StyleBoxFlat.new();style.bg_color=Color("#91dacf");style.set_corner_radius_all(4);style.set_content_margin_all(8)
	control.add_theme_stylebox_override("normal",style);control.add_theme_color_override("font_color",Color("#102d38"));return control
func short_name(control: Label,full: String):
	control.max_lines_visible=2;control.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;control.tooltip_text=full
	control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
func open_menu():
	menu.popup_centered(Vector2i(300,0))
func modal_open() -> bool:
	for child in get_children():
		if child is Window and child.visible:return true
	return false
func queue_layout():
	if layout_queued or engine==null:return
	if memory!=null:skip_capture_once=true
	layout_queued=true;call_deferred("refresh_layout")
func refresh_layout():
	layout_queued=false
	if not closing:render();dialog.resize()
func _process(_delta):
	fit_battle_layout()
func fit_battle_layout():
	if closing or view_kind!="battle" or not is_instance_valid(hud.middle):return
	# Keep the container within the available viewport after dock reparenting.
	var available_height=content.size.y-battle_header.size.y-8
	if ui_size_mode!="standard":available_height-=hud.dock.size.y+8
	var height=maxf(hud.middle.get_combined_minimum_size().y,available_height)
	if absf(hud.middle.size.y-height)>0.5:hud.middle.size.y=height;hud.middle.queue_sort()
func prefetch_shop_rows():
	if pages!=null:pages.shop_view.prefetch_visible()
func _input(event):
	if event is InputEventKey and event.pressed and event.echo and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:
		var focus=get_viewport().gui_get_focus_owner()
		if focus is BaseButton or focus==board:get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.double_click and event.pressed:swallow_mouse_release=true;get_viewport().set_input_as_handled()
		elif not event.pressed and swallow_mouse_release:swallow_mouse_release=false;get_viewport().set_input_as_handled()

func legacy_skill_description(name_: String,stage:=2) -> String:
	return {
		"かばう":"かばう: 隣接する自分以外の味方を、次の本人の番まで肩代わり。MP1",
		"ヒール":"ヒール: 射程2の傷ついた味方/自分のHPを60回復（最大HPまで）。MP1",
		"スナイプ":"スナイプ: その一撃だけ各武器の射程+1、届くATK合算。MP1",
		"スタンプ":"スタンプ: 縦横の隣接中心から3マス。空/味方中心も可。敵のみ通常威力。空振りでもMP1",
		"奇襲":"奇襲: 同じ横列の"+("前方のみ" if stage==1 else "左右")+"。遮るキャラなしで手前に着地+通常攻撃。MP1",
		"陣形強化":"陣形強化: 味方全員が対象（陣形の3マス外も含む）。護送陣が成立している間だけ、通常の攻撃×1.5／被ダメージ×0.75を、攻撃×1.75／被ダメージ×0.65に置き換えます。効果は使用者の次の番まで。陣形が崩れている間は適用されず、重ねても倍率は加算されません。MP1・1行動。"}.get(name_,"")
