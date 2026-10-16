extends RefCounted
## State-focused display. Choices, predictions and results remain engine-owned.
var ui
var middle: Control
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
var item_list := false
const ItemMenu=preload("res://item_menu.gd")
var selected_cell := -1
var range_reference := false
var reference_preview: Dictionary={}
var reference_generation := 0
var reference_pending := false
var reference_error := ""
var reference_kind := "attack"
var bottom_commands: VBoxContainer
var left_panel
var right_panel
var left_info: VBoxContainer
var person_box: VBoxContainer
var inspected_uid := ""
var hover_generation := 0
var hover_stamp := ""
var skill_content_open := false
const COMMANDS=[["attack","攻撃"],["move","移動"],["skill","スキル"],["items","アイテム"],["guard","防御"]]
func _init(frontend):ui=frontend
func l(parent,text,large:=false):
	var label=ui.label_(parent,str(text),large)
	if large:label.add_theme_color_override("font_color",Color("#f0dfbb"))
	return label
func b(parent,text,fn,disabled:=false):
	var control=ui.button(parent,text,fn,disabled);control.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return control
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
	if item_list:return "B3I"
	if ui.command=="move":return "B2" if ui.pending!=null else "B1"
	return "B4" if ui.pending!=null or ui.command=="guard" else "B3"
func reset_context():
	inspected_uid="";invalidate_hover();skill_content_open=false
	discard_reference();item_list=false;action_menu=true;selected_cell=-1;selected_enemy="";last_actor="";last_action_count=-1;presentation_action={};queue_at_start=[];intent_versions.clear();intent_updated.clear()
func mount():
	middle=Control.new();middle.name="BattleOverlay";middle.mouse_filter=Control.MOUSE_FILTER_IGNORE;middle.size_flags_vertical=Control.SIZE_EXPAND_FILL;ui.content.add_child(middle);middle.size=Vector2(ui.size.x-48,ui.size.y-130);ui.battle_row=middle
	ui.board=preload("res://battle_board.gd").new();ui.board.preferences=ui.preferences;ui.board.portraits=ui.portraits;ui.board.name="BattleBoard";ui.add_child(ui.board);ui.move_child(ui.board,0);ui.board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.memory.key(ui.board,"board");ui.board.cell_clicked.connect(ui.on_cell);ui.board.deploy_drag.connect(ui.deploy_dragged);ui.board.enemy_focused.connect(inspect_enemy);ui.board.unit_hovered.connect(inspect_hover.bind(ui.board))
	left_panel=preload("res://floating_panel.gd").new();middle.add_child(left_panel)
	left_panel.configure(ui.preferences,"battle_actor","行動者 / コマンド",Rect2(0,76,320,650))
	right_panel=preload("res://floating_panel.gd").new();middle.add_child(right_panel)
	right_panel.configure(ui.preferences,"battle_target","対象 / 効果",Rect2(maxf(0,ui.size.x-380),76,330,620))
	dock=left_panel
	tools=HBoxContainer.new();tools.name="BattleTools";middle.add_child(tools)
	intent_strip=HBoxContainer.new();intent_strip.name="FixedIntentStrip";intent_strip.visible=false;middle.add_child(intent_strip)
	ui.battle_header=VBoxContainer.new();middle.add_child(ui.battle_header)
	ui.battle_header.size=Vector2(middle.size.x,64)
	last_actor="";last_action_count=-1;action_menu=true;item_list=false;selected_cell=-1
	resize()
func resize():
	if not is_instance_valid(left_panel) or middle.size.x<100:return
	left_panel.reserved_top=76;right_panel.reserved_top=76
	left_panel.constrain();right_panel.constrain();tools.size=Vector2(middle.size.x,56)
	ui.battle_header.position.y=maxf(0,middle.size.y-64);ui.battle_header.size.x=middle.size.x
func render():
	var s=ui.state();var phase=ui.data.get("presentation");var a=acting()
	if not (phase is Dictionary) and not ui.presenting:queue_at_start=ui.data.get("queue",[]).duplicate(true)
	if not s.get("deploying",false) and s.get("result")==null and not ui.presenting and not phase is Dictionary and (a.get("id","")!=last_actor or int(s.get("actions",0))!=last_action_count):
		item_list=false;action_menu=true;selected_cell=-1;selected_enemy="";inspected_uid="";range_reference=false;ui.invalidate_preview();last_actor=str(a.get("id",""));last_action_count=int(s.get("actions",0));ui.memory.request_focus("command_attack")
	update_board()
	ui.clear(ui.battle_header);ui.clear(tools);ui.clear(left_panel.body);ui.clear(right_panel.body);ui.clear(right_panel.footer)
	render_queue();render_actor(a)
	local(tools,"行動履歴",open_history).name="BattleHistory"
	local(tools,"予告・全順番",toggle_details)
	if ui.data.get("trial") is Dictionary:
		var end=b(tools,"試用終了",ui.act.bind("endTrial",[]),ui.presenting);end.name="EndTrial";end.custom_minimum_size=Vector2(160,52)
	else:
		var retreat=b(tools,"撤退",func():ui.confirm("旅を中止し、受注・出発前の状態へ戻します。",ui.act.bind("retreat",[])),ui.presenting);retreat.name="Retreat";retreat.custom_minimum_size=Vector2(160,52)
	tools.tooltip_text="右ドラッグ: 移動 / 中ドラッグ: 角度 / ホイール: 拡大縮小"
	var hint=l(tools,tools.tooltip_text);hint.add_theme_font_size_override("font_size",16);hint.autowrap_mode=TextServer.AUTOWRAP_OFF;hint.clip_text=true;hint.max_lines_visible=1
	left_panel.visible=(a.get("side")=="ally" and not s.get("deploying",false) and s.get("result")==null) or ui.engine.disconnected
	left_info=left_panel.body
	if a.get("side")=="ally":
		var hero=ui.row(left_info);ui.portrait(hero,a,true,48);l(hero,str(a.name),true)
		var health=l(left_info,"HP %d/%d   MP %d/%d" % [a.hp,a.max,a.mp,a.maxMp]);ui.emphasize_low_hp(health,a)
		l(left_info,"DEF %d / 行動速度 %s" % [a.get("def",0),a.get("agi",0)])
	bottom_commands=VBoxContainer.new();bottom_commands.name="ActorCommands";left_info.add_child(bottom_commands);render_bottom_commands()
	actor_box=left_info;command_box=left_info
	person_box=VBoxContainer.new();person_box.name="BattlePersonInfo";right_panel.body.add_child(person_box);render_person()
	target_box=VBoxContainer.new();target_box.name="DecisionContent";right_panel.body.add_child(target_box)
	decision_footer=right_panel.footer
	if ui.engine.disconnected:l(command_box,"接続が終了しました",true)
	elif phase is Dictionary:render_presentation(phase)
	elif s.get("deploying",false):render_deployment()
	elif s.get("result")!=null:render_result()
	elif range_reference:render_reference()
	elif action_menu:render_commands()
	elif item_list:render_items()
	else:presentation_action={};render_target()
	update_board();ui.board.inspected_enemy="";refresh_hover();resize()
func open_history():
	ui.dialog.open("行動履歴",func(body,actions):
		l(body,"実際に起きた行動・結果",true)
		for entry in ui.state().get("log",[]):l(body,ui.display_log(str(entry)))
		ui.local_button(actions,"閉じる",ui.dialog.close))
func update_board():
	ui.board.reference_mode=range_reference
	ui.board.update_state(ui.data,reference_preview if range_reference else ui.preview,ui.command,ui.selected if ui.state().get("deploying",false) else "",ui.chosen)
func render_actor(_a: Dictionary):
	ui.header.text="配置" if ui.state().get("deploying",false) else "戦闘"
	ui.header.tooltip_text="右ドラッグ: 移動 / 中ドラッグ: 角度 / ホイール: 拡大縮小"
func render_queue():
	var queue_scroll=ScrollContainer.new();queue_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;queue_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;ui.battle_header.add_child(queue_scroll)
	var band=ui.row(queue_scroll);band.name="TurnOrder";band.custom_minimum_size.y=40 if ui.ui_size_mode=="standard" else 32
	if ui.state().get("deploying",false) or ui.state().get("result")!=null and not ui.data.get("presentation") is Dictionary:l(band,"行動順は戦闘開始後" if ui.state().get("deploying",false) else "戦闘終了");return
	var presenting=ui.data.get("presentation") is Dictionary or ui.presenting
	var queue_=queue_at_start if presenting else ui.data.get("queue",[])
	var entries=[]
	if presenting and not acting().is_empty():entries.append({"unit":acting(),"label":"実行中"})
	for index in range(queue_.size()):
		entries.append({"unit":unit(queue_[index].id),"label":""})
	for index in range(entries.size()):
		if index>0:l(band,"←")
		var entry=entries[index];var u=entry.unit
		if u.is_empty():continue
		var panel=PanelContainer.new();panel.custom_minimum_size.x=180;band.add_child(panel)
		var style=StyleBoxFlat.new();style.bg_color=Color("#344b50") if u.side=="ally" else Color("#594049");style.set_content_margin_all(2);style.set_corner_radius_all(4)
		if index==0:style.set_border_width_all(1);style.border_color=Color("#ffe197")
		panel.add_theme_stylebox_override("panel",style);panel.tooltip_text=str(u.name)
		var row=ui.row(panel);ui.portrait(row,u,true,32 if ui.ui_size_mode=="standard" else 24)
		var label=l(row,("● " if index==0 else "")+str(u.name));label.autowrap_mode=TextServer.AUTOWRAP_OFF;label.custom_minimum_size=Vector2(132,24);label.clip_text=true;label.max_lines_visible=1;label.tooltip_text=str(u.name)
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
	l(command_box,"左のコマンドから行動を選び、盤面で対象を指定します。")
	local(command_box,"能力・行動条件の詳細",open_action_details)
func render_bottom_commands():
	buttons.clear()
	var a=acting()
	for pair in COMMANDS:
		var eligible=pair[0] in ["guard","items"] or not ui.data.get("choices",{}).get(pair[0],[]).is_empty() or pair[0]=="skill" and (not ui.data.get("skillset",[]).is_empty() or has_return())
		var selected=not action_menu and (ui.command==pair[0] or pair[0]=="skill" and ui.command=="return" or pair[0]=="items" and ui.command in ["item","ether"])
		var control=ui.icons.apply(b(bottom_commands,("● " if selected else "")+pair[1],ui.choose_command.bind(pair[0]),not eligible or a.get("side")!="ally" or ui.state().get("deploying",false) or ui.state().get("result")!=null or ui.data.get("presentation") is Dictionary or range_reference),ui.icons.command(pair[0]),40 if ui.size.x>=1800 else 24);control.size_flags_horizontal=Control.SIZE_EXPAND_FILL;control.custom_minimum_size.y=64 if ui.ui_size_mode=="standard" else 44
		control.tooltip_text=pair[1]+(" / 今は合法な対象なし。条件を詳細で確認" if not eligible else "");ui.memory.key(control,"command_"+pair[0]);buttons[pair[0]]=control
		control.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT
		control.add_theme_constant_override("h_separation",8)
		if selected:
			for state_ in ["normal","hover","pressed"]:
				var style=control.get_theme_stylebox(state_).duplicate() as StyleBoxFlat
				style.bg_color=Color("#615640" if state_=="hover" else "#494336");style.border_color=Color("#d8bd86");style.border_width_bottom=3
				control.add_theme_stylebox_override(state_,style)
			for color_ in ["font_color","font_hover_color","font_pressed_color"]:control.add_theme_color_override(color_,Color("#f5dfae"))
func back_to_commands():
	if ui.locked or ui.presenting or ui.closing:return
	ui.invalidate_preview();item_list=false;action_menu=true;selected_cell=-1;selected_enemy="";ui.audio.ui("cancel");ui.render()
func open_items():
	if ui.locked or ui.presenting or ui.closing or range_reference:return
	ui.invalidate_preview();action_menu=false;item_list=true;selected_cell=-1;selected_enemy="";ui.command="items";ui.render()
func item_count(id: String) -> int:
	if ui.state().has("itemInventories"):return int(ui.state().itemInventories.get(acting().get("id",""),{}).get(id,0))
	return int(ui.state().get("ethers",0)) if id=="ether" else int(ui.state().get("potions",{}).get("ally",0))
func render_items():
	l(target_box,str(acting().get("name",""))+"のアイテム",true)
	for item in ItemMenu.definitions(ui.campaign()):
		var kind=str(item.get("battleKind",""))
		if kind.is_empty():continue
		var count=item_count(str(item.id))
		var reason=""
		if item.get("battleRole","")=="porter" and acting().get("job")!="porter":reason="ポーター専用"
		elif count<=0:reason="在庫なし"
		elif ui.data.get("choices",{}).get(kind,[]).is_empty():reason="回復できる生存味方なし"
		var control=b(target_box,"%s / %d個 / %s" % [item.name,count,ItemMenu.effect(item)]+(" / "+reason if not reason.is_empty() else ""),ui.choose_command.bind(kind),not reason.is_empty())
		control.name="BattleItem_"+str(item.id);ui.icons.apply(control,str(item.id))
	l(target_box,"射程無限 / 1個・1行動。アイテムを選んでから盤面の対象を選択します。")
	ui.battle_actions=VBoxContainer.new();decision_footer.add_child(ui.battle_actions);ui.battle_actions.name="BattleConfirm"
	ui.memory.key(b(ui.battle_actions,"戻る",back_to_commands),"battle_cancel")
func skill_unavailable_reason() -> String:
	if ui.command=="return":return "この戦闘で帰還は使用済みです" if acting().get("returnUsed",false) else ""
	if ui.command!="skill":return ""
	var info=ui.data.get("skillInfo");var cost=int(info.get("cost",1)) if info is Dictionary else 1
	if int(acting().get("mp",0))<cost:return "MP不足（現在%d／必要%d）" % [acting().get("mp",0),cost]
	if ui.data.get("skill")=="陣形強化" and not ui.data.get("formed",{}).get("ally",false):return "護送陣が未成立のため実行できません"
	return ""
func render_target():
	var stage=state_id();var heading=ui.row(target_box) if ui.ui_size_mode!="standard" and ui.command=="skill" else target_box
	var title=l(heading,"移動先の確認・仮置き" if stage=="B2" else "移動先を選択" if stage=="B1" else command_name()+" / 対象・効果" if stage=="B4" else command_name()+" / 対象を選択",true)
	title.name="DecisionTitle"
	if ui.command in ["skill","return"]:
		title.text=command_name()+" / 対象・効果"
		render_skills(heading)
		if skill_content_open:
			var effect=l(target_box,ui.command_hint());effect.name="SkillEffect"
			render_skill_breakdown(target_box)
	var split=VBoxContainer.new();split.add_theme_constant_override("separation",12);split.size_flags_vertical=Control.SIZE_EXPAND_FILL;target_box.add_child(split)
	var main=VBoxContainer.new();main.size_flags_horizontal=Control.SIZE_EXPAND_FILL;split.add_child(main)
	var facts=VBoxContainer.new();facts.size_flags_horizontal=Control.SIZE_EXPAND_FILL;split.add_child(facts)
	facts.add_theme_constant_override("separation",6 if ui.ui_size_mode=="standard" else 4)
	if ui.command=="move":render_move(main,facts)
	else:render_prediction(main,facts)
	var cost=l(facts,cost_text());cost.name="ActionCost"
	if ui.preview_pending:l(facts,"予測を取得中…")
	elif ui.can_commit():
		if ui.ui_size_mode!="standard":cost.text+=" / ✓ 実行可能"
		else:l(facts,"✓ 実行可能")
	elif not skill_unavailable_reason().is_empty():l(facts,skill_unavailable_reason())
	elif not ui.notice.is_empty():l(facts,ui.notice)
	elif not action_menu:l(facts,"対象未確定 / 射程・条件を確認")
	for fact in facts.get_children():
		if fact is Label:fact.add_theme_color_override("font_color",Color("#bdc5d0"))
	ui.battle_actions=VBoxContainer.new();decision_footer.add_child(ui.battle_actions);ui.battle_actions.name="BattleConfirm"
	if ui.command in ["skill","return"]:
		ui.memory.key(ui.primary(b(ui.battle_actions,"実行",ui.commit,not ui.can_commit())),"battle_commit")
		ui.memory.key(b(ui.battle_actions,"戻る",back_to_commands),"battle_cancel")
		return
	ui.memory.key(b(ui.battle_actions,"アイテム一覧へ" if ui.command in ["item","ether"] else "仮置きを取消" if stage=="B2" else "対象選択を取消" if ui.pending!=null or not ui.chosen.is_empty() else "行動一覧へ",open_items if ui.command in ["item","ether"] else ui.cancel),"battle_cancel")
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
	if ui.command=="skill" and ui.data.get("skill")=="陣形強化":summary="対象: 味方全員（陣形の3マス外も含む）"
	var target=l(main,summary,true);target.name="TargetSummary";ui.short_name(target,summary)
	var hits=ui.preview.get("damagePreview",[])
	var hp_effects=ui.preview.get("effectPreview",[]).filter(func(effect):return effect.get("hp",0)!=0)
	if ui.preview_ready and not hp_effects.is_empty():
		for i in range(hp_effects.size()):
			var effect=hp_effects[i];var recipient=unit(effect.id);var before=int(recipient.get("hp",0));var after=before+int(effect.hp)
			var prediction=ui.icons.line(ui,main,"damage" if effect.hp<0 else "healing","%s HP %d → %d（%+d）" % [recipient.get("name",effect.id),before,after,effect.hp],true)
			prediction.name="PredictionSummary" if i==0 else "PredictionSummary_"+str(effect.id);prediction.add_theme_font_size_override("font_size",30 if ui.size.x>=1800 else 25)
			prediction.add_theme_color_override("font_color",Color("#ffc7b4") if effect.hp<0 else Color("#b6f0db"))
		if not hits.is_empty():l(facts,"命中100% / 現在の対象・条件での予測")
		if hits.size()==1:l(facts,"予測受領者: "+str(hits[0].get("recipientName","未確認")))
		if hits.size()>1:l(facts,"予測 %d件: " % hits.size()+" / ".join(hits.map(func(h):return str(h.get("targetName",h.get("recipientName","未確認")))))+(" / 全対象は下へ" if ui.command=="skill" else " / 全対象は内訳へ" if ui.ui_size_mode=="standard" else ""))
		for entry in hits:
			if entry.get("targetName")!=entry.get("recipientName"):l(facts,"⚠ 肩代わり: "+str(entry.get("targetName",""))+" → "+str(entry.get("recipientName","")))
	elif ui.command!="skill" and (ui.preview_ready or ui.command=="guard"):
		var hint=l(main,ui.command_hint());hint.max_lines_visible=3;hint.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;hint.tooltip_text=ui.command_hint()
	if ui.command=="guard":ui.icons.line(ui,main,"defense_up","被ダメージ半減 / 次の本人の番まで")
	if ui.preview_ready:
		for effect in ui.preview.get("effectPreview",[]):
			if effect.get("mp",0)>0:
				var before=int(unit(effect.id).get("mp",0));ui.icons.line(ui,main,"healing","%s MP %d → %d（＋%d）" % [target_name(effect.id),before,before+int(effect.mp),effect.mp],true)
			if effect.get("boost",false):
				ui.icons.line(ui,main,"attack_up","陣形中の味方攻撃×1.75")
				ui.icons.line(ui,main,"defense_up","陣形中の味方被害×0.65")
	if ui.command=="skill":
		var info=ui.data.get("skillInfo",{});info=info if info is Dictionary else {}
		if info.get("target")=="pair" and not ui.preview_ready:l(facts,"異なる2人が必要 / 選択 %d/2" % ui.chosen.size())
		elif info.get("target")=="upToTwo":l(facts,"1〜2人を指定 / 選択 %d人" % ui.chosen.size())
		if ui.data.get("skill")=="スタンプ":l(facts,"空振りでもMP1・1行動を消費")
	if ui.preview_ready and not ui.preview.get("cells",[]).is_empty():l(facts,("影響 %dマス / 全マスは下へ" if ui.command=="skill" else "影響 %dマス / 全マスは内訳へ") % ui.preview.cells.size())
func render_skill_breakdown(parent):
	if ui.command=="return":
		for source in acting().get("skillSources",[]):
			if source.id=="returnHome":l(parent,"由来: "+str(ui.campaign().get("slots",{}).get(source.slot,source.slot))+" / "+str(ui.campaign().get("roster",[]).filter(func(u):return u.id==acting().id)[0].get("equipmentDetails",{}).get(source.slot,{}).get("name",source.itemId)))
		return
	for hit in ui.preview.get("damagePreview",[]):
		l(parent,"指定: %s → 予測受領者: %s / HP −%d" % [hit.get("targetName",hit.get("recipientName","")),hit.get("recipientName",""),hit.hpLoss])
		var parts=[]
		for weapon in hit.get("weapons",[]):parts.append("%s ATK%d" % [weapon.name,weapon.atk])
		l(parent," + ".join(parts)+" / 成長補正+%d" % hit.get("bonus",0))
	if not ui.preview.get("cells",[]).is_empty():l(parent,"影響マス: "+" / ".join(ui.preview.cells.map(coord)))
	for skill in ui.data.get("skillset",[]):
		if skill.name!=ui.data.get("skill"):continue
		for source in skill.get("sources",[]):l(parent,"由来: "+str(ui.campaign().get("slots",{}).get(source.slot,source.slot))+" / "+str(source.get("itemName",source.get("itemId",""))))
func cost_text() -> String:
	if ui.command in ["item","ether"]:return "本人の所持品を消費: 1個・1行動 / 残り%d個" % item_count("ether" if ui.command=="ether" else "potion")
	var info=ui.data.get("skillInfo")
	return "消費: MP%d / 1行動" % (info.get("cost",1) if info is Dictionary else 1) if ui.command=="skill" else "消費: MP0 / 1行動"
func render_skills(parent):
	var row=ui.row(parent)
	var choose=OptionButton.new();choose.name="SkillSelection";choose.custom_minimum_size=Vector2(160,44);choose.size_flags_horizontal=Control.SIZE_EXPAND_FILL;choose.clip_text=true;row.add_child(choose);choose.add_theme_constant_override("icon_max_width",32)
	for skill in ui.data.get("skillset",[]):
		choose.add_icon_item(ui.icons.texture(ui.icons.skill(str(skill.id))),str(skill.name));choose.set_item_metadata(choose.item_count-1,skill.id)
		if ui.command=="skill" and skill.name==ui.data.get("skill"):choose.select(choose.item_count-1)
	if has_return():
		choose.add_icon_item(ui.icons.texture("accessory"),"帰還");choose.set_item_metadata(choose.item_count-1,"returnHome")
		if ui.command=="return":choose.select(choose.item_count-1)
	choose.disabled=ui.locked or ui.presenting;choose.item_selected.connect(func(i):ui.select_skill(str(choose.get_item_metadata(i))));ui.memory.key(choose,"skill_selection")
	var content=b(row,"内容確認を閉じる" if skill_content_open else "内容確認",func():skill_content_open=not skill_content_open;ui.render());content.name="SkillContentToggle"
func has_return() -> bool:return acting().get("effects",[]).has("returnHome")
func command_name() -> String:
	if ui.command=="return":return "帰還"
	for item in ItemMenu.definitions(ui.campaign()):
		if item.get("battleKind")==ui.command:return str(item.name)
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
	var compact=ui.ui_size_mode!="standard"
	if compact:target_box.add_theme_constant_override("separation",2)
	var position_text="仮位置: "+coord(ui.pending)+" / "+("通常攻撃" if reference_kind=="attack" else "スキル")+" / 参考%dマス" % reference_preview.get("ranges",[]).size()
	l(target_box,"仮位置からの射程参考"+(" / "+position_text if compact else ""),not compact)
	l(target_box,"移動で手番終了・ここでは攻撃不可。次の本人の番まで状況は変わります。")
	var values=VBoxContainer.new();values.name="ReferenceValues";target_box.add_child(values)
	if not compact:l(values,position_text)
	l(values,"対象候補: "+("取得中…" if reference_pending else reference_error if not reference_error.is_empty() else " / ".join(reference_preview.get("targets",[]))))
	ui.battle_actions=VBoxContainer.new();decision_footer.add_child(ui.battle_actions);ui.battle_actions.name="BattleConfirm"
	b(ui.battle_actions,"通常攻撃の参考",request_reference.bind("attack"))
	b(ui.battle_actions,"スキルの参考",request_reference.bind("skill"))
	ui.memory.key(local(decision_footer if ui.ui_size_mode=="standard" else ui.battle_actions,"仮置きに戻る",close_reference),"reference_back")
func render_presentation(phase: Dictionary):
	if phase.get("phase")=="action":presentation_action=phase.duplicate(true)
	elif presentation_action.get("action_id")!=phase.get("action_id"):presentation_action={}
	l(target_box,"実行中" if phase.get("phase")=="action" else "実結果",true)
	var action=l(target_box,str(presentation_action.get("label",phase.get("label","演出中…"))));action.name="PresentationAction"
	l(target_box,str(phase.get("label","")))
	if phase.get("unit_id")!=null and phase.get("phase") in ["hurt","heal"]:
		var u=unit(phase.unit_id);ui.icons.line(ui,target_box,"healing" if phase.phase=="heal" else "damage","実受領者: "+str(u.get("name","対象不明"))+" / 現在HP%d/%d" % [u.get("hp",0),u.get("max",0)])
	var target=presentation_action.get("target");var names=[]
	for id in (target if target is Array else [target]):
		if id is String:names.append(target_name(id))
		elif id is int or id is float:names.append(coord(id))
	if presentation_action.get("skill_id")=="porter" or str(presentation_action.get("label","")).contains("陣形強化"):
		l(target_box,"効果対象: 味方全員 / 陣形成立中のみ")
		ui.icons.line(ui,target_box,"attack_up","攻撃×1.75");ui.icons.line(ui,target_box,"defense_up","被害×0.65")
	elif not names.is_empty():l(target_box,"指定対象: "+" / ".join(names))
	ui.battle_actions=VBoxContainer.new();decision_footer.add_child(ui.battle_actions);ui.battle_actions.name="BattleConfirm";ui.primary(b(ui.battle_actions,"演出中…",func():pass,true))
func render_deployment():
	var s=ui.state()
	var formations=ui.row(target_box)
	for pair in [["convoy","基本配置"],["flank","切り込み配置"]]:b(formations,("● " if s.get("formationKind","convoy")==pair[0] else "")+pair[1],choose_formation.bind(pair[0]))
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
	ui.battle_actions=VBoxContainer.new();decision_footer.add_child(ui.battle_actions);ui.battle_actions.name="BattleConfirm";b(ui.battle_actions,"配置リセット",reset_deployment);ui.primary(b(ui.battle_actions,"戦闘開始",ui.act.bind("begin",[])))
func deployment_changed() -> bool:
	for initial in ui.state().get("deploymentInitial",[]):
		if unit(initial.id).get("pos")!=initial.pos:return true
	return false
func choose_formation(kind: String):
	var action=ui.act.bind("chooseFormation",[kind])
	if deployment_changed():ui.confirm("手動配置を現在選んだプリセットの位置へ置き直します。よろしいですか？",action)
	else:action.call()
func reset_deployment():
	if deployment_changed():ui.confirm("手動配置を現在のプリセットへ戻します。よろしいですか？",ui.act.bind("deployment_reset",[]))
	else:ui.act("deployment_reset",[])
func render_result():
	l(target_box,"木人の結果" if ui.data.get("trial") is Dictionary else "戦闘結果",true);l(target_box,str(ui.state().result))
	ui.battle_actions=VBoxContainer.new();decision_footer.add_child(ui.battle_actions);ui.battle_actions.name="BattleConfirm";ui.primary(b(ui.battle_actions,"戦闘を終えて街道へ",ui.act.bind("finishBattle",[]),ui.data.get("trial")!=null))
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
	if ui.state().get("formationVersion")==1:l(parent,"旧戦闘の陣形条件を継続中（この戦闘が終わるまで）")
	for team in ["ally","enemy"]:
		var active=ui.data.get("formed",{}).get(team,false);var boost=active and ui.data.get("boosted",{}).get(team,false)
		var cells=ui.data.get("formationSlots",{}).get(team,[24,13,33] if team=="ally" else [25,16,36])
		var occupied=ui.state().units.filter(func(u):return u.side==team and u.hp>0 and cells.has(int(u.pos))).size()
		l(parent,"%sの条件マス %d/3" % ["味方" if team=="ally" else "敵",occupied])
		l(parent,"%s陣形 %s / 攻撃%s・被ダメージ%s" % ["味方" if team=="ally" else "敵","発動" if active else "未発動","×1.75" if boost else "×1.5" if active else "×1","×0.65" if boost else "×0.75" if active else "×1"])
	l(parent,"陣形条件: 点線の3マスを同陣営の生存者で埋める。陣営全体への補正。防御・かばう・丸めは別。")

func live_board(source_id: int=0) -> bool:
	return not ui.closing and is_instance_valid(ui.board) and ui.board.is_inside_tree() and not ui.board.is_queued_for_deletion() and (source_id==0 or source_id==ui.board.get_instance_id())
func render_person():
	if not live_board() or not is_instance_valid(person_box) or not person_box.is_inside_tree() or person_box.is_queued_for_deletion():return
	ui.clear(person_box)
	person_box.remove_meta("inspected_unit")
	var u=unit(str(ui.pending)) if ui.pending is String else unit(inspected_uid)
	var phase=ui.data.get("presentation")
	if phase is Dictionary and phase.get("unit_id") is String:u=unit(phase.unit_id)
	if u.is_empty() and selected_cell>=0:u=ui.board.unit_at(selected_cell)
	if u.is_empty() and ui.state().get("deploying",false):
		u=unit(ui.selected)
		if u.is_empty():
			for ally in ui.state().get("units",[]):
				if ally.side=="ally" and ally.hp>0:u=ally;break

	if u.is_empty():l(person_box,"人物にカーソルを合わせると情報を表示します。");return
	person_box.set_meta("inspected_unit",u.id)
	render_person_content(person_box,u)
func render_person_content(parent,u: Dictionary,expanded:=false):
	var hero=ui.row(parent);ui.portrait(hero,u,true,64 if ui.ui_size_mode=="standard" else 40);l(hero,str(u.name),true)
	var character={}
	for member in ui.roster():
		if member.id==u.id:character=member;break
	if expanded:ui.pages.party_view.identity(parent,character if not character.is_empty() else u)
	var resources=ui.row(parent) if ui.ui_size_mode!="standard" else parent
	for resource in ["hp","mp"]:
		var resource_box=VBoxContainer.new();resource_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;resources.add_child(resource_box)
		var value=u.get(resource,0);var maximum=u.get("max" if resource=="hp" else "maxMp",0)
		var number=ui.icons.line(ui,resource_box,resource,"%s %d/%d" % [resource.to_upper(),value,maximum]);number.add_theme_color_override("font_color",Color("#eeeae2"))
		if ui.ui_size_mode!="standard":number.text="%d/%d" % [value,maximum];number.tooltip_text=resource.to_upper();number.autowrap_mode=TextServer.AUTOWRAP_OFF
		if not expanded:continue
		var bar=ProgressBar.new();bar.name="Inspect_"+resource;bar.max_value=maxi(1,int(maximum));bar.value=value;bar.show_percentage=false;bar.custom_minimum_size.y=8;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;resource_box.add_child(bar)
		var track=StyleBoxFlat.new();track.bg_color=Color("#11171e");track.set_corner_radius_all(3)
		var fill=StyleBoxFlat.new();fill.bg_color=Color("#df958b") if resource=="hp" and value*4<maximum else Color("#8dc9af") if resource=="hp" else Color("#93b6df");fill.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("background",track);bar.add_theme_stylebox_override("fill",fill)
	if u.get("intent") is Dictionary:
		l(parent,"予告："+str(u.intent.get("name","")))
		l(parent,intent_target_text(u.intent))
	if not expanded:
		local(parent,"能力・詳細",func():ui.dialog.open("対象の能力",func(body,actions):
			render_person_content(body,u,true);local(actions,"閉じる",ui.dialog.close)))
		return
	var stats=character.get("stats",{});var breakdown=stats.get("attributeBreakdown",{})
	l(parent,"DEF %d" % u.get("def",0))
	for pair in [["str","STR","strength"],["int","INT","intelligence"],["speed","SPD（行動速度）","speed"]]:
		var value=u.get("agi") if pair[0]=="speed" else stats.get(pair[0],u.get(pair[0]))
		var part=breakdown.get(pair[0],{});var suffix="補正：未取得"
		if part.has("growth"):suffix="成長＋%d / 基礎%d" % [part.growth,part.base]
		elif part.has("equipment"):suffix="装備%+d / AGI%d" % [part.equipment,part.agi]
		ui.icons.line(ui,parent,pair[2],pair[1]+" "+("未取得" if value==null else str(int(value)))+"（"+suffix+"）")
	if ui.state().get("formationVersion")==1:l(parent,"旧戦闘の陣形条件を継続中")
func inspect_hover(uid: String,source=null):
	# A queued callback may carry an already freed Node. Validate this Variant
	# before calling any method or passing it through an Object-typed argument.
	if typeof(source)!=TYPE_NIL and not is_instance_valid(source):return
	var source_id: int=source.get_instance_id() if typeof(source)!=TYPE_NIL else 0
	if not live_board(source_id):return
	inspected_uid=uid;render_person();refresh_hover()
func invalidate_hover():
	hover_generation+=1;hover_stamp=""
	if is_instance_valid(ui.board):ui.board.hover_caption=""
func refresh_hover():
	if not live_board():return
	var uid=ui.board.hover_uid
	var stamp=JSON.stringify([uid,ui.generation,ui.command,ui.chosen,action_menu,ui.state().get("actions"),ui.state().get("actor"),ui.data.get("skill")])
	if stamp==hover_stamp:return
	hover_stamp=stamp;hover_generation+=1
	if uid.is_empty():ui.board.hover_caption="";return
	if action_menu or ui.state().get("deploying",false) or ui.presenting or ui.data.get("presentation") is Dictionary or ui.command not in ["attack","skill","item","ether"]:
		ui.board.hover_caption="行動を選択すると効果を予測" if action_menu else "命中：対象外";return
	ui.board.hover_caption="予測取得中…"
	request_hover(uid,hover_generation,ui.generation,ui.engine.connection_generation,ui.board.get_instance_id())
func request_hover(uid: String,token: int,generation: int,connection: int,source_id: int):
	# Only a stable ID crosses awaits: an old board can be freed before either
	# the busy wait or transport response completes, including after reconnect.
	while ui.engine.busy and not ui.closing:
		await ui.get_tree().process_frame
		if token!=hover_generation or not live_board(source_id):return
	if not live_board(source_id) or token!=hover_generation or ui.engine.disconnected:return
	var reply=await ui.engine.request({"op":"hover_preview","kind":ui.command,"uid":uid,"chosen":ui.chosen.duplicate()})
	if ui.handle_connection_loss(reply,connection):return
	if not live_board(source_id) or token!=hover_generation or generation!=ui.generation or connection!=ui.engine.connection_generation or ui.board.hover_uid!=uid:return
	if not reply.get("ok",false):ui.board.hover_caption="予測：未取得";return
	var prediction=reply.get("hover",{})
	if prediction.get("status")!="ready":ui.board.hover_caption="異なる2人の対象を指定" if prediction.get("status")=="needs_targets" else "対象外";return
	var parts=[]
	for hit in prediction.get("damagePreview",[]):
		parts.append("HP −%d" % hit.hpLoss+(" → "+str(hit.recipientName) if hit.get("targetId")!=hit.get("recipientId") else ""))
	if parts.is_empty():
		for effect in prediction.get("effectPreview",[]):
			if effect.get("hp",0)>0:parts.append("HP ＋%d" % effect.hp)
			if effect.get("mp",0)>0:parts.append("MP ＋%d" % effect.mp)
			if effect.get("boost",false):parts.append("攻撃×1.75 / 被害×0.65")
			if effect.get("cover")!=null or not effect.get("covers",[]).is_empty():parts.append("次の本人の番までかばう")
	ui.board.hover_caption=("予測："+" / ".join(parts) if not parts.is_empty() else "予測：効果なし")+"\n命中："+("100%" if prediction.get("accuracy")==100 else "対象外")
