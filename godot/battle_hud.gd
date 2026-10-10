extends RefCounted
## State-focused display. Choices, predictions and results remain engine-owned.
var ui
var middle: HBoxContainer
var board_column: VBoxContainer
var dock: Control
var decision_footer: VBoxContainer
var tools: HBoxContainer
var intent_strip: HBoxContainer
var actor_box: VBoxContainer
var command_box: VBoxContainer
var target_box: VBoxContainer
var details: PanelContainer
var tabs: TabContainer
var queue_at_start: Array=[]
var last_actor := ""
var last_action_count := -1
var detail_tab := 0
var details_open := false
var breakdown_open := false
var intent_versions: Dictionary={}
var intent_updated: Dictionary={}
var selected_enemy := ""
var buttons: Dictionary={}
var presentation_action: Dictionary={}
var action_menu := true
var selected_cell := -1
var range_reference := false
var reference_preview: Dictionary={}
var reference_generation := 0
var reference_pending := false
var reference_error := ""
var reference_kind := "attack"
const COMMANDS=[["attack","攻撃"],["move","移動"],["skill","スキル"],["item","ポーション"],["ether","エーテル"],["guard","防御"],["return","帰還"]]
func _init(frontend):ui=frontend
func l(parent,text,large:=false):return ui.label_(parent,str(text),large)
func b(parent,text,fn,disabled:=false):return ui.button(parent,text,fn,disabled)
func local(parent,text,fn):return ui.local_button(parent,text,fn)
func unit(id) -> Dictionary:
	for u in ui.state().get("units",[]):
		if u.id==id:return u
	return {}
func acting() -> Dictionary:
	var phase=ui.data.get("presentation")
	return unit(phase.get("actor_id",ui.state().get("actor"))) if phase is Dictionary else unit(ui.state().get("actor"))
func coord(pos) -> String:return "X%d,Y%d" % [int(pos)%10,4-int(int(pos)/10)]
func state_id() -> String:
	if ui.data.get("presentation") is Dictionary:return "B5" if ui.data.presentation.get("phase")=="action" else "B6"
	if range_reference:return "B2R"
	if action_menu:return "B0"
	if ui.command=="move":return "B2" if ui.pending!=null else "B1"
	return "B4" if ui.pending!=null or ui.command=="guard" else "B3"
func reset_context():
	discard_reference();action_menu=true;selected_cell=-1;selected_enemy="";last_actor="";last_action_count=-1;presentation_action={};queue_at_start=[];intent_versions.clear();intent_updated.clear()
func mount():
	ui.content.add_theme_constant_override("separation",8)
	ui.battle_header=VBoxContainer.new();ui.battle_header.custom_minimum_size.y=40;ui.content.add_child(ui.battle_header)
	middle=HBoxContainer.new();middle.add_theme_constant_override("separation",12);middle.size_flags_vertical=Control.SIZE_EXPAND_FILL;ui.content.add_child(middle);ui.battle_row=middle
	board_column=VBoxContainer.new();board_column.name="BattleBoardColumn";board_column.add_theme_constant_override("separation",0);board_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;board_column.size_flags_vertical=Control.SIZE_EXPAND_FILL;middle.add_child(board_column)
	tools=HBoxContainer.new();tools.custom_minimum_size.y=32;board_column.add_child(tools)
	ui.board=preload("res://battle_board.gd").new();ui.board.portraits=ui.portraits;ui.board.name="BattleBoard";board_column.add_child(ui.board)
	ui.memory.key(ui.board,"board");ui.board.cell_clicked.connect(ui.on_cell);ui.board.deploy_drag.connect(ui.deploy_dragged);ui.board.enemy_focused.connect(inspect_enemy)
	intent_strip=HBoxContainer.new();intent_strip.name="FixedIntentStrip";intent_strip.custom_minimum_size.y=42;board_column.add_child(intent_strip)
	dock=Control.new();dock.clip_contents=true;dock.name="BattleDecision";dock.size_flags_vertical=Control.SIZE_EXPAND_FILL;middle.add_child(dock)
	last_actor="";last_action_count=-1;action_menu=true;selected_cell=-1
func resize():
	if not is_instance_valid(dock):return
	var compact=ui.ui_size_mode!="standard"
	ui.battle_header.custom_minimum_size.y=32 if compact else 40
	if compact:
		if dock.get_parent()!=ui.content:dock.reparent(ui.content)
		dock.custom_minimum_size=Vector2(0,192);dock.size_flags_vertical=Control.SIZE_FILL
		board_column.custom_minimum_size.y=244
	else:
		if dock.get_parent()!=middle:dock.reparent(middle)
		dock.custom_minimum_size=Vector2(380,0);dock.size_flags_vertical=Control.SIZE_EXPAND_FILL
		board_column.custom_minimum_size.y=244
	ui.content.queue_sort();middle.queue_sort();ui.call_deferred("fit_battle_layout")
func render():
	var s=ui.state();var phase=ui.data.get("presentation");var a=acting()
	if not (phase is Dictionary) and not ui.presenting:queue_at_start=ui.data.get("queue",[]).duplicate(true)
	if not s.get("deploying",false) and s.get("result")==null and not ui.presenting and not phase is Dictionary and (a.get("id","")!=last_actor or int(s.get("actions",0))!=last_action_count):
		action_menu=true;selected_cell=-1;selected_enemy="";range_reference=false;ui.invalidate_preview();last_actor=str(a.get("id",""));last_action_count=int(s.get("actions",0));ui.memory.request_focus("command_attack")
	update_board()
	ui.clear(ui.battle_header);ui.clear(tools);ui.clear(intent_strip);ui.clear(dock)
	render_queue();render_actor(a)
	for mode in range(3):
		var cam=local(tools,["戦術","低","高"][mode],func():ui.board.set_camera(mode));cam.custom_minimum_size.y=32;ui.memory.key(cam,"camera_"+str(mode))
	var tile=l(tools,"選択: "+coord(selected_cell)+" / 足元のマス" if selected_cell>=0 else "足元のマスを選択 / X0〜9・Y0〜4");tile.autowrap_mode=TextServer.AUTOWRAP_OFF;tile.custom_minimum_size.y=20;tile.clip_text=true;tile.max_lines_visible=1;tile.tooltip_text=tile.text
	var details_button=local(tools,"詳細",toggle_details);details_button.custom_minimum_size.y=32
	if ui.data.get("trial") is Dictionary:
		var end=b(tools,"試用終了",ui.act.bind("endTrial",[]),ui.presenting);end.custom_minimum_size.y=32
	else:
		var retreat=b(tools,"撤退",func():ui.confirm("旅を中止し、受注・出発前の状態へ戻します。",ui.act.bind("retreat",[])),ui.presenting);retreat.custom_minimum_size.y=32
	render_intent_strip()
	# A bounded parent prevents text/button minimum sizes from moving the board.
	var shell=ui.card(dock);shell.get_parent().set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box=ui.scroller(shell);box.name="DecisionContent";box.get_parent().name="DecisionScroll"
	decision_footer=VBoxContainer.new();shell.add_child(decision_footer)
	actor_box=box;command_box=box;target_box=box
	if ui.engine.disconnected:
		ui.battle_actions=null;l(box,"接続が終了しました",true)
		l(box,ui.notice if not ui.notice.is_empty() else "再接続して保存済みファイルを読み込めます。")
	elif phase is Dictionary:render_presentation(phase)
	elif s.get("deploying",false):render_deployment()
	elif s.get("result")!=null:render_result()
	elif range_reference:render_reference()
	elif action_menu:render_commands()
	else:presentation_action={};render_target()
	update_board();ui.board.inspected_enemy=""
	resize()
func update_board():
	ui.board.reference_mode=range_reference
	ui.board.update_state(ui.data,reference_preview if range_reference else ui.preview,ui.command,ui.selected if ui.state().get("deploying",false) else "",ui.chosen)
func render_actor(a: Dictionary):
	if a.is_empty():ui.header.text="配置対象を選択" if ui.state().get("deploying",false) else "戦闘終了";return
	ui.header.text="現在: %s   HP %d/%d   MP %d/%d\n%s" % [a.name,a.hp,a.max,a.mp,a.maxMp,{"B0":"行動を選択","B1":"移動先を選択","B2":"移動先を確認・仮置き","B3":"対象を選択","B4":"対象・効果を確認","B5":"実行中","B6":"実結果","B2R":"仮位置からの射程参考"}.get(state_id(),"")]
	ui.header.tooltip_text=ui.header.text;ui.header.remove_theme_color_override("font_color");ui.header.remove_theme_font_override("font");ui.emphasize_low_hp(ui.header,a)
	ui.actor_face.texture=ui.portraits.texture(a,true)
func render_queue():
	var band=ui.row(ui.battle_header);band.name="TurnOrder";band.custom_minimum_size.y=40 if ui.ui_size_mode=="standard" else 32
	if ui.state().get("deploying",false) or ui.state().get("result")!=null and not ui.data.get("presentation") is Dictionary:l(band,"行動順は戦闘開始後" if ui.state().get("deploying",false) else "戦闘終了");return
	var presenting=ui.data.get("presentation") is Dictionary or ui.presenting
	var queue_=queue_at_start if presenting else ui.data.get("queue",[])
	var entries=[]
	if presenting and not acting().is_empty():entries.append({"unit":acting(),"label":"実行中"})
	for index in range(mini(queue_.size(),(6 if ui.ui_size_mode=="standard" else 4)-entries.size())):
		entries.append({"unit":unit(queue_[index].id),"label":("開始時"+str(index+1)) if presenting else ("現在" if index==0 else "次" if index==1 else str(index)+"手先")})
	for index in range(entries.size()):
		var entry=entries[index];var u=entry.unit
		if u.is_empty():continue
		var panel=PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;band.add_child(panel)
		var style=StyleBoxFlat.new();style.bg_color=Color("#27575d") if u.side=="ally" else Color("#623b48");style.set_content_margin_all(2)
		if index==0:style.set_border_width_all(1);style.border_color=Color("#ffe197")
		panel.add_theme_stylebox_override("panel",style);panel.tooltip_text=str(u.name)
		var row=ui.row(panel);ui.portrait(row,u,true,32 if ui.ui_size_mode=="standard" else 24)
		var label=l(row,str(entry.label)+" "+("味" if u.side=="ally" else "敵"));label.autowrap_mode=TextServer.AUTOWRAP_OFF;label.custom_minimum_size.y=20;label.clip_text=true;label.max_lines_visible=1
	var all_=local(band,"全順番",toggle_details);all_.custom_minimum_size.y=40 if ui.ui_size_mode=="standard" else 32
func target_name(id) -> String:
	return str(unit(id).get("name","対象不明"))
func selected_target_text(target) -> String:
	if target is String:return target_name(target)
	if target is Array:return " / ".join(target.map(target_name))
	if target is int or target is float:return coord(target)
	return "対象不要" if ui.command=="guard" else "未選択"
func intent_target_text(intent: Dictionary) -> String:
	var cells=intent.get("cells",[])
	if not cells.is_empty():
		return " / ".join(cells.map(func(pos):return "固定マス "+coord(pos)+" / 現在: "+str(ui.board.unit_at(int(pos)).get("name","空き"))))
	if intent.get("destination")!=null:return "移動先: "+coord(intent.destination)
	if intent.get("target") is String:return "対象: "+target_name(intent.target)
	if intent.get("target") is int or intent.get("target") is float:return "対象マス: "+coord(intent.target)
	return "対象指定なし" if intent.get("kind")=="guard" else "対象不明"
func render_intent_strip():
	var source={}
	for u in ui.state().get("units",[]):
		if u.side=="enemy" and u.hp>0 and u.get("intent") is Dictionary and selected_cell>=0 and u.intent.get("cells",[]).has(float(selected_cell)):source=u;break
	if source.is_empty():
		for entry in ui.data.get("queue",[]):
			var u=unit(entry.id)
			if u.get("side")=="enemy" and u.hp>0 and u.get("intent") is Dictionary:source=u;break
	var summary="現在の予告はありません" if source.is_empty() else "敵予告: "+str(source.name)+" / "+str(source.intent.get("name",""))+"\n"+intent_target_text(source.intent)
	var label=l(intent_strip,summary);label.add_theme_font_size_override("font_size",16);label.autowrap_mode=TextServer.AUTOWRAP_OFF;label.custom_minimum_size.y=40;label.clip_text=true;label.max_lines_visible=2;label.tooltip_text=label.text
	var button=local(intent_strip,"予告・順番の詳細",toggle_details);button.custom_minimum_size.y=40
func render_commands():
	l(command_box,"行動を選択",true)
	var actions=GridContainer.new();actions.columns=3 if ui.ui_size_mode=="standard" else 4;actions.add_theme_constant_override("h_separation",8);actions.add_theme_constant_override("v_separation",8);command_box.add_child(actions);buttons.clear()
	for pair in COMMANDS:
		var eligible=pair[0]=="guard" or not ui.data.get("choices",{}).get(pair[0],[]).is_empty() or pair[0]=="skill" and not ui.data.get("skillset",[]).is_empty()
		var control=b(actions,pair[1],ui.choose_command.bind(pair[0]),not eligible or acting().get("side")!="ally");control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		control.tooltip_text=pair[1]+(" / 今は合法な対象なし。条件を詳細で確認" if not eligible else "");ui.memory.key(control,"command_"+pair[0]);buttons[pair[0]]=control
	var detail_button=local(command_box if ui.ui_size_mode=="standard" else actions,"能力・行動条件の詳細" if ui.ui_size_mode=="standard" else "行動条件",open_action_details);detail_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
func render_target():
	var stage=state_id();var heading=ui.row(target_box) if ui.ui_size_mode!="standard" and ui.command=="skill" and stage=="B3" else target_box
	var title=l(heading,"移動先の確認・仮置き" if stage=="B2" else "移動先を選択" if stage=="B1" else command_name()+" / 対象・効果" if stage=="B4" else command_name()+" / 対象を選択",true)
	title.name="DecisionTitle"
	if ui.command=="skill" and stage=="B3":render_skills(heading)
	var split=HBoxContainer.new() if ui.ui_size_mode!="standard" else VBoxContainer.new();split.add_theme_constant_override("separation",12);split.size_flags_vertical=Control.SIZE_EXPAND_FILL;target_box.add_child(split)
	var main=VBoxContainer.new();main.size_flags_horizontal=Control.SIZE_EXPAND_FILL;split.add_child(main)
	var facts=VBoxContainer.new();facts.size_flags_horizontal=Control.SIZE_EXPAND_FILL;split.add_child(facts)
	if ui.command=="move":render_move(main,facts)
	else:render_prediction(main,facts)
	var cost=l(facts,cost_text());cost.name="ActionCost"
	if ui.preview_pending:l(facts,"予測を取得中…")
	elif ui.can_commit():
		if ui.ui_size_mode!="standard":cost.text+=" / ✓ 実行可能"
		else:l(facts,"✓ 実行可能")
	elif not ui.notice.is_empty():l(facts,ui.notice)
	elif not action_menu:l(facts,"対象未確定 / 射程・条件を確認")
	ui.battle_actions=ui.row(decision_footer);ui.battle_actions.name="BattleConfirm"
	ui.memory.key(b(ui.battle_actions,"仮置きを取消" if stage=="B2" else "対象選択を取消" if ui.pending!=null or not ui.chosen.is_empty() else "行動一覧へ",ui.cancel),"battle_cancel")
	if stage=="B2":ui.memory.key(b(ui.battle_actions,"仮位置の射程参考",open_range_reference),"range_reference")
	else:local(ui.battle_actions,"内訳・全対象",open_action_details)
	if stage in ["B2","B4"]:
		ui.memory.key(ui.primary(b(decision_footer if ui.ui_size_mode=="standard" else ui.battle_actions,"移動して手番終了" if ui.command=="move" else command_name()+"を確定",ui.commit,not ui.can_commit())),"battle_commit")
func render_move(main,facts):
	if selected_cell>=0:l(main,"選択: "+coord(selected_cell)+" / "+str(ui.board.unit_at(selected_cell).get("name","空きマス")))
	if ui.pending==null:l(main,"合法な着地点を選ぶと半透明の仮置きを表示します。");return
	l(main,"出発 "+coord(acting().get("pos",0))+" → 着地 "+coord(ui.pending))
	l(main,"この移動で手番終了",true)
	if ui.preview_ready:
		if ui.preview.get("swap")!=null:l(facts,"交換: "+ui.member_name(str(ui.preview.swap))+" → "+coord(acting().get("pos",0)))
		l(facts,"着地点の固定予告: "+(" / ".join(ui.preview.get("risks",[])) if not ui.preview.get("risks",[]).is_empty() else "なし（取得済み）"))
		l(facts,"移動後の陣形: "+("成立" if ui.preview.get("formationAfter",false) else "未成立"))
	else:l(facts,"予告・陣形を確認中…")
func render_prediction(main,facts):
	var summary="対象未選択"
	if selected_cell>=0:
		var occupant=ui.board.unit_at(selected_cell)
		summary=coord(selected_cell)+" / "+str(occupant.get("name","空きマス"))
		if not occupant.is_empty():summary+=" HP%d/%d" % [occupant.hp,occupant.max]
	if ui.command=="guard":summary="防御 / 対象不要"
	elif ui.pending is String:
		var target=unit(ui.pending);summary=str(target.get("name",ui.pending))+" / "+coord(target.get("pos",0))+" HP%d/%d" % [target.get("hp",0),target.get("max",0)]
	elif ui.pending is Array or not ui.chosen.is_empty():summary="選択 %d人: " % ui.chosen.size()+" / ".join(ui.chosen.map(func(id):return ui.member_name(str(id))))
	var target=l(main,summary);target.name="TargetSummary";ui.short_name(target,summary)
	var hits=ui.preview.get("damagePreview",[])
	if ui.preview_ready and not hits.is_empty():
		var hit=hits[0];var prediction=l(main,"予測: HP −%d" % hit.hpLoss,true);prediction.name="PredictionSummary"
		if hits.size()==1:l(facts,"予測受領者: "+str(hit.get("recipientName","未確認")))
		if hits.size()>1:l(facts,"予測 %d件: " % hits.size()+" / ".join(hits.map(func(h):return str(h.get("targetName",h.get("recipientName","未確認")))))+(" / 全対象は内訳へ" if ui.ui_size_mode=="standard" else ""))
		for entry in hits:
			if entry.get("targetName")!=entry.get("recipientName"):l(facts,"⚠ 肩代わり: "+str(entry.get("targetName",""))+" → "+str(entry.get("recipientName","")))
	elif ui.preview_ready or ui.command=="guard":
		var hint=l(main,ui.command_hint());hint.max_lines_visible=3;hint.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;hint.tooltip_text=ui.command_hint()
	if ui.command=="skill":
		var info=ui.data.get("skillInfo",{});info=info if info is Dictionary else {}
		if info.get("target")=="pair" and not ui.preview_ready:l(facts,"異なる2人が必要 / 選択 %d/2" % ui.chosen.size())
		elif info.get("target")=="upToTwo":l(facts,"1〜2人を指定 / 選択 %d人" % ui.chosen.size())
		if ui.data.get("skill")=="スタンプ":l(facts,"空振りでもMP1・1行動を消費")
	if ui.preview_ready and not ui.preview.get("cells",[]).is_empty():l(facts,"影響 %dマス / 全マスは内訳へ" % ui.preview.cells.size())
func cost_text() -> String:
	if ui.command in ["item","ether"]:return "消費: 1個・1行動 / 残り%d個" % (ui.state().get("ethers",0) if ui.command=="ether" else ui.state().get("potions",{}).get("ally",0))
	var info=ui.data.get("skillInfo")
	return "消費: MP%d / 1行動" % (info.get("cost",1) if info is Dictionary else 1) if ui.command=="skill" else "消費: MP0 / 1行動"
func render_skills(parent):
	var choose=OptionButton.new();choose.name="SkillSelection";choose.custom_minimum_size.y=44;choose.clip_text=true;parent.add_child(choose)
	for skill in ui.data.get("skillset",[]):
		choose.add_item(str(skill.name));choose.set_item_metadata(choose.item_count-1,skill.id)
		if skill.name==ui.data.get("skill"):choose.select(choose.item_count-1)
	choose.disabled=ui.locked or ui.presenting;choose.item_selected.connect(func(i):ui.select_skill(str(choose.get_item_metadata(i))));ui.memory.key(choose,"skill_selection")
func command_name() -> String:
	for pair in COMMANDS:
		if pair[0]==ui.command:return str(ui.data.get("skill","スキル")) if ui.command=="skill" else pair[1]
	return ui.command
func open_action_details():
	breakdown_open=true
	ui.dialog.open("行動の内訳・全対象",func(body,actions):
		l(body,command_name()+" / "+cost_text(),true);l(body,ui.command_hint())
		l(body,"指定対象: "+selected_target_text(ui.pending));l(body,"選択中: "+" / ".join(ui.chosen.map(func(id):return ui.member_name(str(id)))))
		for hit in ui.preview.get("damagePreview",[]):
			l(body,"指定: %s → 予測受領者: %s / 予測HP −%d" % [hit.get("targetName",hit.get("recipientName","")),hit.get("recipientName",""),hit.hpLoss],true)
			var parts=[]
			for weapon in hit.get("weapons",[]):parts.append("%s ATK%d" % [weapon.name,weapon.atk])
			l(body," + ".join(parts)+" / 成長補正+%d" % hit.get("bonus",0))
		l(body,"影響マス: "+" / ".join(ui.preview.get("cells",[]).map(coord)))
		l(body,"参考候補（今回の指定・実結果とは別）: "+" / ".join(ui.preview.get("targets",[])))
		l(body,"候補全員に効果が出るとは限りません。実受領者は実行後の結果で確認できます。")
		for skill in ui.data.get("skillset",[]):
			l(body,str(skill.name),true)
			for source in skill.get("sources",[]):l(body,"由来: "+str(ui.campaign().get("slots",{}).get(source.slot,source.slot))+" / "+str(source.get("itemName",source.get("itemId",""))))
		ui.local_button(actions,"戻る",ui.dialog.close),func():breakdown_open=false)
func discard_reference():
	reference_generation+=1;range_reference=false;reference_preview={};reference_pending=false;reference_error=""
func open_range_reference():
	if ui.command!="move" or ui.pending==null or not ui.preview_ready:return
	discard_reference();range_reference=true;reference_kind="attack";reference_preview=ui.preview.duplicate(true)
	ui.render()
func close_reference():
	if not range_reference:return
	discard_reference();ui.memory.request_focus("range_reference");ui.render()
func request_reference(which: String):
	if not range_reference:return
	reference_generation+=1;reference_pending=true;reference_error="";reference_kind=which
	reference_preview=ui.preview.duplicate(true);reference_preview.ranges=[];reference_preview.targets=[];reference_preview.cells=[]
	var token=reference_generation;var generation=ui.generation;var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation
	var destination=ui.pending;var actor=ui.state().get("actor");var actions=ui.state().get("actions");var skill=ui.data.get("skill")
	ui.render()
	while ui.engine.busy and not ui.closing:
		await ui.get_tree().process_frame
		if token!=reference_generation:return
	if ui.closing or token!=reference_generation:return
	var reply=await ui.engine.request({"op":"preview","kind":"move","target":destination,"previewKind":which})
	if ui.handle_connection_loss(reply,connection):return
	# Reference responses own no movement decision or old UI nodes. Closure/reopen,
	# new/load, actor/skill changes and connection replacement all invalidate them.
	if ui.closing or token!=reference_generation or not range_reference or generation!=ui.generation or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation:return
	if destination!=ui.pending or actor!=ui.state().get("actor") or actions!=ui.state().get("actions") or skill!=ui.data.get("skill"):return
	reference_pending=false
	if reply.get("ok",false):reference_preview=reply.preview
	else:
		reference_error=str(reply.get("error","射程参考を取得できませんでした"))
	ui.render()
func render_reference():
	l(target_box,"仮位置からの射程参考",true)
	l(target_box,"移動で手番終了・ここでは攻撃不可。次の本人の番まで状況は変わります。")
	var values=VBoxContainer.new();values.name="ReferenceValues";target_box.add_child(values)
	l(values,"仮位置: "+coord(ui.pending)+" / "+("通常攻撃" if reference_kind=="attack" else "スキル")+" / 参考%dマス" % reference_preview.get("ranges",[]).size())
	l(values,"対象候補: "+("取得中…" if reference_pending else reference_error if not reference_error.is_empty() else " / ".join(reference_preview.get("targets",[]))))
	ui.battle_actions=ui.row(decision_footer);ui.battle_actions.name="BattleConfirm"
	b(ui.battle_actions,"通常攻撃の参考",request_reference.bind("attack"))
	b(ui.battle_actions,"スキルの参考",request_reference.bind("skill"))
	ui.memory.key(local(decision_footer if ui.ui_size_mode=="standard" else ui.battle_actions,"仮置きに戻る",close_reference),"reference_back")
func render_presentation(phase: Dictionary):
	if phase.get("phase")=="action":presentation_action=phase.duplicate(true)
	elif presentation_action.get("action_id")!=phase.get("action_id"):presentation_action={}
	buttons.clear();l(target_box,"実行中" if phase.get("phase")=="action" else "実結果",true)
	var action=l(target_box,str(presentation_action.get("label",phase.get("label","演出中…"))));action.name="PresentationAction"
	l(target_box,str(phase.get("label","")))
	if phase.get("unit_id")!=null and phase.get("phase") in ["hurt","heal"]:
		var u=unit(phase.unit_id);l(target_box,"実受領者: "+str(u.get("name","対象不明"))+" / 現在HP%d/%d" % [u.get("hp",0),u.get("max",0)])
	var target=presentation_action.get("target");var names=[]
	for id in (target if target is Array else [target]):
		if id is String:names.append(target_name(id))
		elif id is int or id is float:names.append(coord(id))
	if not names.is_empty():l(target_box,"指定対象: "+" / ".join(names))
	ui.battle_actions=ui.row(decision_footer);ui.battle_actions.name="BattleConfirm";ui.primary(b(ui.battle_actions,"演出中…",func():pass,true))
func render_deployment():
	var s=ui.state()
	if not s.units.any(func(u):return u.id==ui.selected and u.side=="ally" and u.hp>0):
		for u in s.units:
			if u.side=="ally" and u.hp>0:ui.selected=u.id;break
	l(target_box,"配置: 味方を選び、自陣の足元マスへ")
	var choose=OptionButton.new();choose.custom_minimum_size.y=44;choose.clip_text=true;target_box.add_child(choose);var ids=[]
	for u in s.units:
		if u.side=="ally":
			ids.append(u.id);choose.add_item(str(u.name));choose.set_item_disabled(ids.size()-1,u.hp<=0)
			if u.id==ui.selected:choose.select(ids.size()-1)
	choose.item_selected.connect(func(i):ui.selected=ids[i];ui.render())
	l(target_box,"クリック・ドラッグで配置と交換。消費なし / 青: 攻撃範囲・緑: 奇襲対象")
	ui.battle_actions=ui.row(decision_footer);ui.battle_actions.name="BattleConfirm";b(ui.battle_actions,"配置リセット",ui.act.bind("deployment_reset",[]));ui.primary(b(ui.battle_actions,"戦闘開始",ui.act.bind("begin",[])))
func render_result():
	l(target_box,"木人の結果" if ui.data.get("trial") is Dictionary else "戦闘結果",true);l(target_box,str(ui.state().result))
	ui.battle_actions=ui.row(decision_footer);ui.battle_actions.name="BattleConfirm";ui.primary(b(ui.battle_actions,"戦闘を終えて街道へ",ui.act.bind("finishBattle",[]),ui.data.get("trial")!=null))
func toggle_details():
	details_open=true
	ui.dialog.open("戦闘の詳細",func(body,actions):
		l(body,"開始時の全行動順（演出中の実行者は上部に表示）" if ui.presenting else "全行動順",true)
		for q in (queue_at_start if ui.presenting else ui.data.get("queue",[])):l(body,str(q.name)+" / "+("味方" if q.side=="ally" else "敵"))
		l(body,"所持: ポーション 味方%d / 敵%d / エーテル%d（ポーター専用・射程無限）" % [ui.state().get("potions",{}).get("ally",0),ui.state().get("potions",{}).get("enemy",0),ui.state().get("ethers",0)])
		enemy_intents(body);ui.render_unit_details(body,ui.state());formations(body)
		l(body,"ログ（実結果・直近40件）",true)
		for entry in ui.state().get("log",[]).slice(-40):l(body,ui.display_log(str(entry)))
		ui.local_button(actions,"戻る",ui.dialog.close),func():details_open=false)
func inspect_enemy(id: String):
	selected_enemy=id;toggle_details()
func close_detail() -> bool:
	if range_reference:close_reference();return true
	if is_instance_valid(ui.dialog.window):ui.dialog.close();return true
	return false
func render_details():toggle_details()
func enemy_intents(parent):
	for u in ui.state().get("units",[]):
		if u.side!="enemy" or u.hp<=0 or not u.get("intent") is Dictionary:continue
		var intent: Dictionary=u.intent;var fingerprint=JSON.stringify([intent,u.get("next")])
		if intent_versions.has(u.id) and intent_versions[u.id]!=fingerprint:intent_updated[u.id]=true
		intent_versions[u.id]=fingerprint
		var card=ui.card(parent);ui.memory.item(card.get_parent(),u.id)
		local(card,("● " if selected_enemy==u.id else "")+str(u.name),inspect_enemy.bind(u.id))
		l(card,("更新 / " if intent_updated.get(u.id,false) else "予告 / ")+str(intent.get("name","")))
		l(card,intent_target_text(intent))
		for e in ui.data.get("enemyInfo",[]):
			if e.id==u.id:l(card,"通常射程%d / %s %s\n%s" % [e.normalReach,e.skill,"同横列" if e.skillReach==null else str(int(e.skillReach)),e.reason])
		l(card,"元の理由: "+str(intent.get("reason","")))
func formations(parent):
	for team in ["ally","enemy"]:
		var active=ui.data.get("formed",{}).get(team,false);var boost=active and ui.data.get("boosted",{}).get(team,false)
		var cells=[24,13,33] if team=="ally" else [25,16,36]
		var occupied=ui.state().units.filter(func(u):return u.side==team and u.hp>0 and cells.has(int(u.pos))).size()
		l(parent,"%sの条件マス %d/3" % ["味方" if team=="ally" else "敵",occupied])
		l(parent,"%s陣形 %s / 攻撃%s・被ダメージ%s" % ["味方" if team=="ally" else "敵","発動" if active else "未発動","×1.75" if boost else "×1.5" if active else "×1","×0.65" if boost else "×0.75" if active else "×1"])
	l(parent,"陣形条件: 点線の3マスを同陣営の生存者で埋める。陣営全体への補正。防御・かばう・丸めは別。")
