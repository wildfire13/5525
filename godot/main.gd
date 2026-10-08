extends Control
var engine
var portraits=preload("res://portraits.gd").new()
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
var content: VBoxContainer
var battle_row: HBoxContainer
var board
var side: VBoxContainer
var battle_header: VBoxContainer
var battle_actions: HBoxContainer
var footer: Label
var actor_row: HBoxContainer
var widgets: Array[Button]=[]
var view_kind := ""
var generation := 0
var retry_button: Button
const BG=Color("#0e1e28")
func _ready():
	pages=preload("res://campaign_panels.gd").new(self)
	get_tree().auto_accept_quit=false
	get_tree().root.gui_embed_subwindows=true
	var theme_=Theme.new();theme_.default_font_size=17
	theme_.set_color("font_color","TooltipLabel",Color.WHITE)
	var tip=StyleBoxFlat.new();tip.bg_color=Color("#183341");tip.set_content_margin_all(8);theme_.set_stylebox("panel","TooltipPanel",tip)
	theme=theme_
	var panel=StyleBoxFlat.new();panel.bg_color=BG;add_theme_stylebox_override("panel",panel)
	base=VBoxContainer.new();add_child(base);base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.add_theme_constant_override("separation",10)
	top=HBoxContainer.new();base.add_child(top)
	header=Label.new();header.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(header)
	button(top,"保存",save_game);button(top,"読込",load_dialog);button(top,"ログ保存",save_log)
	button(top,"画像",portrait_dialog);button(top,"全画面 F11",fullscreen)
	retry_button=button(top,"再接続",func():confirm("ゲーム接続を再開します。失われた未保存の進行は復元できません。\n再接続後、保存済みファイルを読み込んでください。",reconnect_engine));retry_button.visible=false
	button(top,"新しい旅",func(): confirm("未保存の進行を終了し、新しい旅を始めます。保存済みファイルは変更しません。",new_game))
	var mute_row=HBoxContainer.new();base.add_child(mute_row)
	audio=preload("res://audio.gd").new();add_child(audio)
	for pair in [["bgm","BGM"],["voice","ボイス"],["se","SE"]]:
		var check=CheckButton.new();check.text=pair[1]+"ミュート";mute_row.add_child(check)
		check.toggled.connect(func(value):audio.set_mute(pair[0],value);audio.sync(data))
	content=VBoxContainer.new();content.size_flags_vertical=Control.SIZE_EXPAND_FILL;base.add_child(content)
	actor_row=HBoxContainer.new();base.add_child(actor_row)
	footer=Label.new();footer.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;base.add_child(footer)
	engine=preload("res://engine_bridge.gd").new();add_child(engine)
	if not engine.start_engine(): notice=engine.last_error;render();return
	await update({"op":"campaign_start"})
func campaign() -> Dictionary: return data.get("campaign") if data.get("campaign") is Dictionary else {}
func state() -> Dictionary: return data.get("state") if data.get("state") is Dictionary else {}
func roster() -> Array: return campaign().get("roster",[])
func label_(parent: Node,text: String,large:=false) -> Label:
	var l=Label.new();l.text=text;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if parent is HBoxContainer:l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if large:l.add_theme_font_size_override("font_size",23)
	parent.add_child(l);return l
func row(parent: Node) -> HBoxContainer:
	var r=HBoxContainer.new();parent.add_child(r);return r
func button(parent: Node,text: String,fn: Callable,disabled:=false) -> Button:
	var b=Button.new();b.text=text;b.custom_minimum_size.y=38;b.disabled=disabled or (engine!=null and engine.disconnected)
	parent.add_child(b);widgets.append(b)
	b.pressed.connect(func():
		if not locked and not presenting and not closing: fn.call())
	return b
func clear(node: Node):
	for child in node.get_children():node.remove_child(child);child.queue_free()
func portrait(parent: Node,u: Dictionary,face:=false,size_:=72) -> TextureRect:
	var p=TextureRect.new();p.custom_minimum_size=Vector2(size_,size_);p.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;p.texture=portraits.texture(u,face)
	parent.add_child(p);return p
func card(parent: Node) -> VBoxContainer:
	var p=PanelContainer.new();var style=StyleBoxFlat.new();style.bg_color=Color("#20333f")
	style.set_corner_radius_all(9);style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=10;style.content_margin_bottom=10
	p.add_theme_stylebox_override("panel",style);parent.add_child(p)
	var v=VBoxContainer.new();p.add_child(v);return v
func scroller(parent: Node) -> VBoxContainer:
	var s=ScrollContainer.new();s.size_flags_vertical=Control.SIZE_EXPAND_FILL;s.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;parent.add_child(s)
	var v=VBoxContainer.new();v.size_flags_horizontal=Control.SIZE_EXPAND_FILL;s.add_child(v);return v
func confirm(text: String,fn: Callable):
	var d=ConfirmationDialog.new();d.exclusive=true;d.title="確認";d.dialog_text=text;d.ok_button_text="はい";d.cancel_button_text="戻る"
	add_child(d);d.confirmed.connect(func():d.queue_free();fn.call());d.canceled.connect(func():audio.ui("cancel");d.queue_free())
	d.popup_centered(Vector2i(560,230));d.get_cancel_button().grab_focus()
func fullscreen():
	get_window().mode=Window.MODE_WINDOWED if get_window().mode==Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
func _unhandled_key_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F11:fullscreen()
		elif event.keycode==KEY_ESCAPE and not presenting:cancel()
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
	if locked or closing:return {"ok":false}
	locked=true
	for b in widgets:
		if is_instance_valid(b):b.disabled=true
	var reply: Dictionary=await engine.request(request)
	locked=false
	if request.get("op")=="campaign" and request.get("action") not in ["begin","finishBattle","endTrial","trial","forecast","previewGear"] and reply.get("presentation")==null:
		audio.ui("confirm" if reply.get("ok",false) else "cancel")
	if reply.get("ok",false):
		if reply.has("campaign"):
			# Successful load commits all frontend metadata before its first render.
			if frontend.has("images"):
				portraits.activate(frontend.images);audio.restore(frontend.music);gear_preview={}
			invalidate_preview();data=reply
		notice=""
	else:
		notice=str(reply.get("error","操作できません"))
		if reply.get("connection_lost",false):invalidate_preview()
	if closing:return reply
	render()
	if data.get("presentation")!=null and not presenting and not engine.disconnected:await present()
	return reply
func present():
	presenting=true
	while data.get("presentation")!=null and not closing:
		render()
		var p: Dictionary=data.presentation
		if board:board.animate(p)
		var duration=audio.phase(p)
		await get_tree().create_timer(0.001 if checks_fast else duration).timeout
		if closing:break
		var response: Dictionary=await engine.request({"op":"presentation_next","id":p.id,"index":p.index})
		if not response.get("ok",false):notice=response.get("error","演出を進められません");break
		data=response
	presenting=false
	if not closing:render()
func act(action: String,args: Array=[]):
	invalidate_preview()
	await update({"op":"campaign","action":action,"args":args,"presentation":action=="begin"})
func reconnect_engine():
	if engine.start_engine():await new_game()
	else:notice=engine.last_error;render()
func invalidate_preview():
	generation+=1;pending=null;chosen=[];preview={}
func new_game():
	invalidate_preview()
	portraits.activate({"version":1,"characters":{}});audio.restore({});gear_preview={};page="board"
	await update({"op":"campaign_start"})
func navigate(value: String):invalidate_preview();page=value;gear_preview={};render()
func render():
	audio.follow_connection(engine.connection_generation)
	audio.sync(data)
	widgets=widgets.filter(func(b):return is_instance_valid(b) and b.get_parent()==top)
	for b in widgets:b.disabled=locked or presenting or (engine.disconnected and b!=retry_button)
	retry_button.visible=engine.disconnected
	var c=campaign();var s=state();var phase=c.get("phase","")
	var place=c.get("journey",{}).get("destination",c.get("location","")) if phase=="arrival" and c.get("journey") is Dictionary else c.get("location","")
	header.text="5525 / %s  %dG  経験値%d・隊Lv.%d\n編成%d/5人 / 累計%d時間" % [town_name(place),c.get("gold",0),c.get("xp",0),c.get("level",1),c.get("selected",[]).size(),c.get("hours",0)]
	var battle=not s.is_empty() and (phase in ["deployment","battle"] or data.get("trial")!=null)
	if battle:
		if view_kind!="battle":
			clear(content);battle_row=HBoxContainer.new();battle_row.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(battle_row)
			board=preload("res://battle_board.gd").new();board.portraits=portraits;battle_row.add_child(board)
			board.cell_clicked.connect(on_cell);board.deploy_drag.connect(deploy_dragged)
			var sidebar=VBoxContainer.new();sidebar.name="BattleSidebar";sidebar.custom_minimum_size.x=380;battle_row.add_child(sidebar)
			battle_header=VBoxContainer.new();battle_header.name="BattleHeader";sidebar.add_child(battle_header)
			side=scroller(sidebar);side.custom_minimum_size.x=360
			battle_actions=row(sidebar);battle_actions.name="BattleConfirm"
			view_kind="battle"
		render_battle()
	else:
		board=null;clear(content);view_kind="page"
		var nav=row(content)
		var tabs=[["board","掲示板"],["map","地図・出発"],["party","仲間・装備"],["shop","商店"],["items","道具"]] if phase=="town" else [["board","旅程"],["items","道具"]]
		if phase=="town" and c.get("location")=="astaris":tabs.append(["inn","宿屋"])
		for tab in tabs:button(nav,("● " if page==tab[0] else "")+tab[1],navigate.bind(tab[0]),phase!="town" and tab[0]=="items" and phase!="camp")
		var body=scroller(content)
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
	clear(actor_row)
	var acting={}
	for u in s.get("units",[]):
		if u.id==s.get("actor"):acting=u
	if data.get("presentation")!=null:
		for u in s.get("units",[]):
			if u.id==data.presentation.get("actor_id"):acting=u
	if not acting.is_empty():
		portrait(actor_row,acting,true,62)
		var info=label_(actor_row,"%s  HP %d/%d  MP %d/%d" % [acting.name,acting.hp,acting.max,acting.mp,acting.maxMp])
		if acting.hp*4<acting.max:info.add_theme_color_override("font_color",Color("#ff6868"))
	if data.get("presentation")!=null:label_(actor_row,str(data.presentation.label))
	footer.text=notice if not notice.is_empty() else ("処理中…" if locked else "演出中…" if presenting else "選択 → プレビュー → 確定 / Escで取消")
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
func select_shop(uid: String):shop_uid=uid;gear_preview={};render()
func render_shop(body):pages.shop(body)
func preview_gear(id: String):
	var r=await update({"op":"campaign","action":"previewGear","args":[shop_uid,id,shop_slot]})
	if r.get("previewGear")!=null:
		gear_preview=r.previewGear;render()
		await get_tree().process_frame;await get_tree().process_frame
		var quote=content.find_child("GearQuote",true,false)
		if quote!=null:
			for scroll in content.find_children("*","ScrollContainer",true,false):scroll.ensure_control_visible(quote)
func inspect_movement(which: String):
	if command!="move" or pending==null:return
	await request_preview(which)
func render_battle():
	clear(battle_header);clear(side);clear(battle_actions)
	var s=state();var deploying=s.get("deploying",false)
	var order=GridContainer.new();order.name="TurnOrder";order.columns=5;battle_header.add_child(order)
	for q in data.get("queue",[]):
		for u in s.units:
			if u.id==q.id:
				var p=PanelContainer.new();var bg=StyleBoxFlat.new();bg.bg_color=Color("#27575d") if q.side=="ally" else Color("#623b48");p.add_theme_stylebox_override("panel",bg);order.add_child(p)
				var face=portrait(p,u,true,44);face.tooltip_text=q.name
	var cameras=row(battle_header)
	for mode in range(3):button(cameras,["戦術","低","高"][mode],func():board.set_camera(mode))
	if deploying:
		label_(side,"配置 / 味方を選び、自陣マスへ",true)
		label_(side,"クリックで移動・交換、ドラッグでも配置。時間・HP・MP消費なし。青: 攻撃範囲 / 緑枠: 奇襲対象")
		if not s.units.any(func(u):return u.id==selected and u.side=="ally" and u.hp>0):
			for u in s.units:
				if u.side=="ally" and u.hp>0:selected=u.id;break
		for u in s.units:
			if u.side=="ally":button(side,("● " if selected==u.id else "")+"%s HP%d MP%d" % [u.name,u.hp,u.mp],func():selected=u.id;render(),u.hp<=0)
		button(battle_actions,"配置リセット",act.bind("deployment_reset",[]));button(battle_actions,"戦闘開始",act.bind("begin",[]))
	elif s.get("result")!=null:
		label_(side,str(s.result),true)
		button(battle_actions,"戦闘を終えて街道へ",act.bind("finishBattle",[]),data.get("trial")!=null)
	else:
		var actions=GridContainer.new();actions.columns=3;battle_header.add_child(actions)
		for pair in [["attack","攻撃"],["move","移動"],["skill","スキル"],["item","ポーション"],["ether","エーテル"],["guard","防御"],["return","帰還"]]:
			var action_button=button(actions,pair[1],choose_command.bind(pair[0]),locked or presenting or (pair[0]!="guard" and data.get("choices",{}).get(pair[0],[]).is_empty()))
			action_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		for skill in data.get("skillset",[]):
			var sources=[]
			for src in skill.get("sources",[]):sources.append(campaign().get("slots",{}).get(src.get("slot",""),src.get("slot",""))+":"+str(src.get("itemName",src.get("itemId",""))))
			button(side,skill.name+" / "+"・".join(sources),select_skill.bind(skill.id),presenting)
		label_(side,"通常射程 %d / スキル射程 %d / 移動 %d" % [data.get("normalAttackReach",0),data.get("skillReach",0),data.get("moveReach",2)])
		label_(side,"所持: ポーション 味方%d / 敵%d\nエーテル%d（ポーター・射程無限）" % [s.get("potions",{}).get("ally",0),s.get("potions",{}).get("enemy",0),s.get("ethers",0)])
		label_(side,"行動数: %d" % s.get("actions",0))
		label_(side,command_hint())
		var names=[]
		for uid in chosen:names.append(member_name(str(uid)))
		label_(side,"選択: "+{"attack":"攻撃","skill":"スキル","move":"移動","guard":"防御","item":"ポーション","ether":"エーテル","return":"帰還"}.get(command,command)+" / "+"・".join(names))
		if command=="move" and pending!=null:
			var inspect=row(side);button(inspect,"仮位置: 通常",inspect_movement.bind("attack"));button(inspect,"仮位置: スキル",inspect_movement.bind("skill"))
		if not preview.is_empty():
			label_(side,("仮位置からの対象: " if command=="move" else "射程内候補: ")+" / ".join(preview.get("targets",[])))
			label_(side,"着地点への固定予告: "+" / ".join(preview.get("risks",[])))
			if command=="move":label_(side,"移動後の味方陣形: "+("成立" if preview.get("formationAfter",false) else "未成立"))
			for hit in preview.get("damagePreview",[]):
				var contributions=[]
				for weapon in hit.get("weapons",[]):contributions.append("%s ATK%d" % [weapon.name,weapon.atk])
				label_(side,"予測: %s → %s HP−%d\n%s / 成長補正+%d" % [hit.get("targetName",hit.recipientName),hit.recipientName,hit.hpLoss," + ".join(contributions),hit.get("bonus",0)])
		button(battle_actions,"確定",commit,not(pending!=null or command=="guard") or presenting)
		button(battle_actions,"取消",cancel,presenting)
	if data.get("trial")!=null:
		label_(side,str(data.trial.get("notice","木人で試用中")))
		button(side,"試用を終了",act.bind("endTrial",[]),presenting)
	else:button(side,"撤退",func():confirm("今回の旅を取り消し、受注／出発前の状態へ戻ります。",act.bind("retreat",[])),presenting)
	for team in ["ally","enemy"]:
		var active=data.get("formed",{}).get(team,false);var boost=active and data.get("boosted",{}).get(team,false)
		var cells=[24,13,33] if team=="ally" else [25,16,36]
		var occupied=s.units.filter(func(u):return u.side==team and u.hp>0 and cells.has(int(u.pos))).size()
		label_(side,"%sの条件マス %d/3" % ["味方" if team=="ally" else "敵",occupied])
		label_(side,("%s陣形 %s / 攻撃%s・被ダメージ%s" % ["味方" if team=="ally" else "敵","発動" if active else "未発動","×1.75" if boost else "×1.5" if active else "×1","×0.65" if boost else "×0.75" if active else "×1"]))
	label_(side,"陣形条件: 点線の3マスを同陣営の生存者で埋める。陣営全体への補正。防御・かばう・丸めは別。")
	render_unit_details(side,s)
	for e in data.get("enemyInfo",[]):
		label_(side,"%s / 通常%d・%s %s\n%s" % [member_name(e.id),e.normalReach,e.skill,"同横列" if e.skillReach==null else str(int(e.skillReach)),e.reason])
	label_(side,"戦闘ログ（直近40件）")
	label_(side,"\n".join(s.get("log",[]).slice(-40).map(display_log)))
	board.update_state(data,preview,command,selected,chosen)
func command_hint() -> String:
	var a={}
	for u in state().get("units",[]):
		if u.id==state().get("actor"):a=u
	if a.is_empty():return ""
	var descriptions={
		"かばう":"かばう: 隣接する自分以外の味方を、次の本人の番まで肩代わり。MP1",
		"ヒール":"ヒール: 射程2の傷ついた味方/自分のHPを60回復（最大HPまで）。MP1",
		"スナイプ":"スナイプ: その一撃だけ各武器の射程+1、届くATK合算。MP1",
		"スタンプ":"スタンプ: 縦横の隣接中心から3マス。空/味方中心も可。敵のみ通常威力。空振りでもMP1",
		"奇襲":"奇襲: 同じ横列の"+("前方のみ" if a.get("skillStage")==1 else "左右")+"。遮るキャラなしで手前に着地+通常攻撃。MP1",
		"陣形強化":"陣形強化: 護送陣成立時に確認して実行。次の本人の番まで攻撃+75%/被害-35%。重複なし。MP1"}
	var skill=data.get("skillInfo")
	var hints={
		"attack":"通常攻撃: 縦横距離%d以内。対象に届く武器のATKを合算。" % data.get("normalAttackReach",0),
		"move":"移動: 経路%d以内。キャラを通り抜け不可。侵入用装飾品の権限に従います。" % data.get("moveReach",2)+("味方を選ぶと位置交換。MP消費なし。" if a.get("job")=="porter" else ""),
		"skill":skill.get("description","") if skill is Dictionary else descriptions.get(data.get("skill",""),""),
		"return":"帰還: 装備中のみ、1戦1回。自陣の空きマスを指定。MP0・1行動。",
		"item":"ポーション: 射程無限、傷ついた生存味方のHP+55（上限まで）。共有在庫を1消費。",
		"ether":"エーテル: ポーターのみ、生存味方/自分へ射程無限。MP+3（上限まで）、1個・1行動。",
		"guard":"防御: 次の本人の番まで被ダメージ半減。MP消費なし。"}
	var hint=str(hints.get(command,""))
	if command!="guard" and data.get("choices",{}).get(command,[]).is_empty():hint+="\n今は合法な対象なし。射程・HP/MP・陣形・進路を確認してください。"
	return hint
func render_unit_details(parent: Node,s: Dictionary):
	label_(parent,"全員の状態",true)
	for u in s.get("units",[]):
		var status="%s: HP %d/%d MP %d AGI %d%s%s" % [u.name,u.hp,u.max,u.mp,u.agi," 防御" if u.get("guard",false) else ""," 戦闘不能" if u.hp<=0 else ""]
		var line=label_(parent,status)
		if u.hp*4<u.max:line.add_theme_color_override("font_color",Color("#ff8484"))
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
	invalidate_preview();command=value
	if value=="skill" and data.get("skill")=="陣形強化":
		confirm("陣形を強化します。MP1・1行動を使用。\n次の本人の番まで攻撃+75%・被害−35%。重複しません。",porter_boost)
	render()
func porter_boost():
	await update({"op":"act","kind":"skill","target":state().actor,"presentation":true})
func select_skill(id: String):
	invalidate_preview();command="skill"
	await update({"op":"select_skill","skillId":id})
func deploy_dragged(uid: String,pos: int):
	if locked or presenting:return
	await act("deploy",[uid,pos])
func on_cell(pos: int):
	if locked or presenting:return
	var s=state();var u=board.unit_at(pos)
	if s.get("deploying",false):
		if selected.is_empty():
			if u.get("side")=="ally":selected=u.id;render()
		else:await act("deploy",[selected,pos])
		return
	var target=null
	if command in ["move","return"] or command=="skill" and data.get("skill")=="スタンプ":target=pos
	elif not u.is_empty():target=u.id
	if target==null:return
	var options=data.get("choices",{}).get(command,[])
	# JSON numbers arrive as float; clicks are int. Array.has is type-sensitive.
	if target is int:options=options.map(func(value):return int(value))
	var paired=command=="skill" and data.get("skillInfo")!=null and data.skillInfo.get("target") in ["pair","upToTwo"]
	if paired:
		if chosen.has(target):chosen.erase(target)
		elif chosen.size()<2:chosen.append(target)
		target=chosen.duplicate()
	if paired:
		for option in options:
			if option.size()==chosen.size() and option.all(func(id):return chosen.has(id)):target=option;break
	if not options.has(target):
		pending=null;preview={}
		if not paired:chosen=[]
		render();return
	if not paired and target is String:chosen=[target]
	pending=target
	await request_preview("attack")
func request_preview(which: String):
	generation+=1
	var token=generation;var actor=state().get("actor");var action_count=state().get("actions");var kind=command
	var target=JSON.stringify(pending);var skill=data.get("skill")
	var reply=await update({"op":"preview","kind":kind,"target":pending,"previewKind":which})
	if closing:return
	if reply.get("ok",false) and token==generation and pending!=null and target==JSON.stringify(pending) and command==kind and state().get("actor")==actor and state().get("actions")==action_count and data.get("skill")==skill:
		preview=reply.preview
	render()
func cancel():
	invalidate_preview();audio.ui("cancel");render()
func commit():
	var target=pending;invalidate_preview();audio.ui("confirm")
	await update({"op":"act","kind":command,"target":target,"presentation":true})
func file_dialog(mode: FileDialog.FileMode, filters: PackedStringArray, callback: Callable, filename: String=""):
	var d=FileDialog.new();d.access=FileDialog.ACCESS_FILESYSTEM;d.file_mode=mode;d.filters=filters
	d.use_native_dialog=false;d.exclusive=true;add_child(d);d.current_dir=ProjectSettings.globalize_path("user://")
	if not filename.is_empty():d.current_file=filename;d.title="新規ファイルへ保存（既存ファイルは上書きできません）"
	d.file_selected.connect(func(path):d.queue_free();callback.call(path));d.canceled.connect(func():d.queue_free())
	d.popup_centered_ratio(.75)
func save_game():
	var r=await update({"op":"campaign_save"})
	if not r.get("ok",false):return
	var envelope: Dictionary=r.data
	envelope.nativePortraits=portraits.metadata.duplicate(true);envelope.godotFrontend=audio.frontend_save()
	file_dialog(FileDialog.FILE_MODE_SAVE_FILE,PackedStringArray(["*.json ; 5525進行セーブ"]),write_snapshot.bind(envelope,"進行"),"5525-godot-%d-%d.json" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()])
func write_snapshot(path: String,envelope: Dictionary,kind: String):
	var written=await update({"op":"godot_io","action":"write","path":path,"data":envelope})
	if written.get("ok",false):notice=kind+"を新規ファイルへ保存しました: "+path;audio.ui("confirm");render()
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
