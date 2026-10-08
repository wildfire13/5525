extends RefCounted
## All decisions use bridge fields; this file changes presentation only.
var ui
var middle: HBoxContainer
var dock: HBoxContainer
var actor_box: VBoxContainer
var command_box: VBoxContainer
var target_box: VBoxContainer
var details: PanelContainer
var tabs: TabContainer
var tools: HBoxContainer
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
func mount():
	ui.battle_header=VBoxContainer.new();ui.content.add_child(ui.battle_header)
	tools=HBoxContainer.new();ui.content.add_child(tools)
	middle=HBoxContainer.new();middle.size_flags_vertical=Control.SIZE_EXPAND_FILL;ui.content.add_child(middle)
	ui.battle_row=middle
	ui.board=preload("res://battle_board.gd").new();ui.board.portraits=ui.portraits;ui.board.name="BattleBoard";middle.add_child(ui.board)
	ui.memory.key(ui.board,"board")
	ui.board.cell_clicked.connect(ui.on_cell);ui.board.deploy_drag.connect(ui.deploy_dragged)
	ui.board.enemy_focused.connect(inspect_enemy)
	ui.board.resized.connect(resize)
	details=PanelContainer.new();details.name="BattleSidebar";middle.add_child(details)
	dock=HBoxContainer.new();dock.name="BattleDock";ui.content.add_child(dock)
	for weight in [22,34,44]:
		var box=ui.card(dock);box.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.get_parent().size_flags_stretch_ratio=weight
		if weight==22:actor_box=box
		elif weight==34:command_box=box
		else:target_box=box
	last_actor=""
func resize():
	if not is_instance_valid(details) or ui.board==null:return
	var compact=ui.ui_size_mode!="standard"
	if compact:
		if details.get_parent()!=ui.board:details.reparent(ui.board)
		details.custom_minimum_size.x=0
		details.position=Vector2(maxf(0,ui.board.size.x-320),0)
		details.size=Vector2(minf(320,ui.board.size.x),ui.board.size.y)
		details.visible=details_open
	else:
		if details.get_parent()!=middle:details.reparent(middle)
		details.custom_minimum_size.x=280;details.size_flags_vertical=Control.SIZE_EXPAND_FILL;details.visible=true
	dock.custom_minimum_size.y=224 if ui.ui_size_mode=="standard" else 216
func render():
	var s=ui.state();var phase=ui.data.get("presentation")
	if not (phase is Dictionary) and not ui.presenting:queue_at_start=ui.data.get("queue",[]).duplicate(true)
	ui.clear(ui.battle_header);ui.clear(tools);ui.clear(actor_box);ui.clear(command_box);ui.clear(target_box);ui.clear(details)
	render_queue()
	for mode in range(3):
		var cam=local(tools,["戦術","低","高"][mode],func():ui.board.set_camera(mode));ui.memory.key(cam,"camera_"+str(mode))
	local(tools,"詳細",toggle_details)
	if ui.data.get("trial") is Dictionary:l(tools,"木人で試用中")
	else:l(tools,"座標 X0〜9 / Y0〜4 ・ "+("処理中…" if ui.locked else "演出中…" if ui.presenting else "盤面: 矢印で移動、Enterで選択"))
	render_details()
	var a=acting()
	if s.get("deploying",false):a=unit(ui.selected)
	if not s.get("deploying",false) and s.get("result")==null and not ui.presenting and (a.get("id","")!=last_actor or int(s.get("actions",0))!=last_action_count):
		ui.memory.request_focus("actor_heading");last_actor=str(a.get("id",""));last_action_count=int(s.get("actions",0))
	render_actor(a)
	if phase is Dictionary:render_presentation(phase)
	elif s.get("deploying",false):render_deployment()
	elif s.get("result")!=null:render_result()
	else:presentation_action={};render_commands();render_target()
	if ui.data.get("trial") is Dictionary:
		b(tools,"試用を終了",ui.act.bind("endTrial",[]),ui.presenting)
	elif s.get("result")!=null or not s.get("deploying",false):
		var retreat=local(tools,"旅を中止 / 撤退",func():ui.confirm("旅を中止し、受注・出発前の状態へ戻します。",ui.act.bind("retreat",[])))
		retreat.disabled=ui.locked or ui.presenting
	ui.board.update_state(ui.data,ui.preview,ui.command,ui.selected if s.get("deploying",false) else "",ui.chosen)
	ui.board.inspected_enemy=selected_enemy
	resize()
func render_queue():
	var s=ui.state();var band=HBoxContainer.new();band.name="TurnOrder";band.custom_minimum_size.y=64 if ui.ui_size_mode=="standard" else 56;ui.battle_header.add_child(band)
	if s.get("deploying",false) or s.get("result")!=null:
		l(band,"行動順は戦闘開始後" if s.get("deploying",false) else "戦闘終了",true);return
	var queue_=queue_at_start if ui.data.get("presentation") is Dictionary or ui.presenting else ui.data.get("queue",[])
	var scroll=ScrollContainer.new();scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var rest=HBoxContainer.new();scroll.add_child(rest)
	for index in range(queue_.size()):
		var q=queue_[index];var u=unit(q.id)
		if u.is_empty():continue
		var p=PanelContainer.new();p.custom_minimum_size.x=168 if index==0 else 164
		var bg=StyleBoxFlat.new();bg.bg_color=Color("#27575d") if q.side=="ally" else Color("#623b48");bg.set_content_margin_all(4)
		if index==0:bg.set_border_width_all(2);bg.border_color=Color("#ffe197")
		p.add_theme_stylebox_override("panel",bg)
		(band if index==0 else rest).add_child(p)
		var r=HBoxContainer.new();p.add_child(r);ui.portrait(r,u,true,40)
		var line=l(r,("現在" if index==0 else "次" if index==1 else str(index)+"手先")+" / "+("味方" if q.side=="ally" else "敵")+"\n"+str(q.name))
		line.add_theme_font_size_override("font_size",16);ui.short_name(line,str(q.name));ui.memory.item(p,"queue_"+str(index))
		if ui.presenting:p.modulate=Color(.7,.7,.7)
	band.add_child(scroll);ui.memory.watch(scroll,"turn_order")
	if ui.data.get("presentation") is Dictionary or ui.presenting:l(ui.battle_header,"実行開始時の順番 / 演出中は入力できません")
func render_actor(a: Dictionary):
	ui.actor_row=HBoxContainer.new();ui.actor_row.name="CurrentActor";actor_box.add_child(ui.actor_row)
	if a.is_empty():l(ui.actor_row,"配置対象を選択" if ui.state().get("deploying",false) else "戦闘終了");return
	ui.portrait(ui.actor_row,a,true,52)
	var label=l(ui.actor_row,str(a.name));ui.short_name(label,str(a.name))
	var title=l(actor_box,("配置: " if ui.state().get("deploying",false) else "現在: ")+str(a.name))
	ui.short_name(title,str(a.name));title.focus_mode=Control.FOCUS_ALL;ui.memory.key(title,"actor_heading")
	var hp=l(actor_box,"HP %d/%d\nMP %d/%d" % [a.hp,a.max,a.mp,a.maxMp]);ui.emphasize_low_hp(hp,a)
	ui.emphasize_low_hp(label,a)
	l(actor_box,("戦闘不能" if a.hp<=0 else "防御中" if a.get("guard",false) else "味方" if a.side=="ally" else "敵")+" / 行動数 %d" % ui.state().get("actions",0))
	if ui.data.get("presentation") is Dictionary:
		var brief=l(actor_box,str(ui.data.presentation.get("label","演出中…")));ui.short_name(brief,brief.text)
func render_presentation(phase: Dictionary):
	if phase.get("phase")=="action":presentation_action=phase.duplicate(true)
	elif presentation_action.get("action_id")!=phase.get("action_id"):presentation_action={}
	buttons.clear()
	l(command_box,"実行中 / "+("味方" if acting().get("side")=="ally" else "敵"),true)
	var action_label=str(presentation_action.get("label","演出中…"))
	var action=l(command_box,action_label);action.name="PresentationAction";ui.short_name(action,action_label)
	l(command_box,"演出終了後、次の手番を操作できます。")
	var body=ui.scroller(target_box);body.get_parent().custom_minimum_size.y=32
	l(body,"実行結果" if phase.get("phase")!="action" else "実行内容",true)
	l(body,str(phase.get("label",action_label)))
	var target=presentation_action.get("target")
	var names=[]
	for id_ in (target if target is Array else [target]):
		if id_ is String:names.append(str(unit(id_).get("name",id_)))
		elif id_ is int or id_ is float:names.append("マス "+coord(id_))
	if not names.is_empty():l(body,"指定対象: "+" / ".join(names))
	ui.battle_actions=ui.row(target_box);ui.battle_actions.name="BattleConfirm"
	ui.primary(b(ui.battle_actions,"演出中…",func():pass,true))
func render_deployment():
	var s=ui.state()
	if not s.units.any(func(u):return u.id==ui.selected and u.side=="ally" and u.hp>0):
		for u in s.units:
			if u.side=="ally" and u.hp>0:ui.selected=u.id;break
	l(command_box,"配置: 味方を選び、自陣マスへ")
	var choose=OptionButton.new();choose.custom_minimum_size.y=40;command_box.add_child(choose)
	var ids=[]
	for u in s.units:
		if u.side=="ally":
			ids.append(u.id);choose.add_item(str(u.name));choose.set_item_disabled(ids.size()-1,u.hp<=0)
			if u.id==ui.selected:choose.select(ids.size()-1)
	choose.item_selected.connect(func(i):ui.selected=ids[i];ui.render())
	l(command_box,"クリック・ドラッグで移動と交換。時間・HP・MPの消費なし。")
	l(target_box,"青: 攻撃範囲 / 緑枠: 奇襲対象\n配置後に戦闘開始を選びます。")
	var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;target_box.add_child(spacer)
	ui.battle_actions=ui.row(target_box);ui.battle_actions.name="BattleConfirm"
	b(ui.battle_actions,"配置リセット",ui.act.bind("deployment_reset",[]));ui.primary(b(ui.battle_actions,"戦闘開始",ui.act.bind("begin",[])))
func render_result():
	l(command_box,"木人の結果" if ui.data.get("trial") is Dictionary else "戦闘結果",true)
	l(target_box,str(ui.state().result),true)
	var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;target_box.add_child(spacer)
	ui.battle_actions=ui.row(target_box);ui.battle_actions.name="BattleConfirm"
	ui.primary(b(ui.battle_actions,"戦闘を終えて街道へ",ui.act.bind("finishBattle",[]),ui.data.get("trial")!=null))
func render_commands():
	var actions=GridContainer.new();actions.columns=3;actions.add_theme_constant_override("h_separation",8);actions.add_theme_constant_override("v_separation",8);command_box.add_child(actions)
	buttons.clear()
	for pair in COMMANDS:
		var eligible=pair[0]=="guard" or not ui.data.get("choices",{}).get(pair[0],[]).is_empty()
		var control=b(actions,("● " if ui.command==pair[0] else "")+pair[1],ui.choose_command.bind(pair[0]),not eligible or acting().get("side")!="ally")
		control.size_flags_horizontal=Control.SIZE_EXPAND_FILL;control.tooltip_text=pair[1]+(" / 今は合法な対象なし。射程・HP/MP・陣形・進路を確認" if not eligible else "")
		ui.memory.key(control,"command_"+pair[0]);buttons[pair[0]]=control
	var skillset=ui.data.get("skillset",[])
	if ui.command=="skill" and not skillset.is_empty():
		var choose=OptionButton.new();choose.name="SkillSelection";choose.custom_minimum_size.y=40;choose.size_flags_horizontal=Control.SIZE_EXPAND_FILL;choose.clip_text=true;command_box.add_child(choose)
		for skill in skillset:
			choose.add_item(str(skill.name));choose.set_item_metadata(choose.item_count-1,skill.id)
			if str(skill.name)==str(ui.data.get("skill","")):choose.select(choose.item_count-1)
		choose.disabled=ui.locked or ui.presenting;choose.item_selected.connect(func(i):ui.select_skill(str(choose.get_item_metadata(i))))
		ui.memory.key(choose,"skill_selection")
func render_target():
	var title=l(target_box,("この移動で手番が終わります" if ui.command=="move" else "選択: "+command_name()))
	title.add_theme_color_override("font_color",Color("#ffe197"))
	var target_text="対象を選択してください"
	if ui.command=="guard":target_text="対象不要 / 次の本人の番まで被ダメージ半減"
	elif ui.pending!=null:
		var selected=ui.pending if ui.pending is Array else [ui.pending];var descriptions=[]
		for id in selected:
			if id is String:
				var u=unit(id);descriptions.append(str(u.get("name",id))+" ("+coord(u.get("pos",0))+") HP%d/%d" % [u.get("hp",0),u.get("max",0)])
			else:descriptions.append("着地点 ("+coord(id)+")" if ui.command in ["move","return"] else "対象マス ("+coord(id)+")")
		target_text=" / ".join(descriptions)
	elif not ui.chosen.is_empty():target_text="選択途中: "+" / ".join(ui.chosen.map(func(id):return ui.member_name(str(id))))
	var target=l(target_box,target_text);target.name="TargetSummary";ui.short_name(target,target_text)
	if not ui.preview.get("damagePreview",[]).is_empty():
		var losses=[]
		for hit in ui.preview.damagePreview:losses.append("HP−%d" % hit.hpLoss)
		var prediction=l(target_box,"予測損失: "+" / ".join(losses));prediction.name="PredictionSummary"
	var body=ui.scroller(target_box);body.get_parent().custom_minimum_size.y=32;ui.memory.watch(body.get_parent(),"battle_prediction")
	if ui.preview.is_empty():l(body,"予測を取得中…" if ui.preview_pending else ui.command_hint())
	else:
		if ui.command=="move":
			l(body,"着地点への固定予告: "+(" / ".join(ui.preview.get("risks",[])) if not ui.preview.get("risks",[]).is_empty() else "なし"))
			l(body,"移動後の味方陣形: "+("成立" if ui.preview.get("formationAfter",false) else "未成立"))
			var inspect=ui.row(body);local(inspect,"仮位置: 通常",ui.inspect_movement.bind("attack"));local(inspect,"仮位置: スキル",ui.inspect_movement.bind("skill"))
			l(body,"仮位置からの射程参考。次の本人の番まで状況は変わります。")
			l(body,"仮位置からの対象: "+" / ".join(ui.preview.get("targets",[])))
		if ui.command!="move":l(body,"射程内候補: "+" / ".join(ui.preview.get("targets",[])))
		if not ui.preview.get("cells",[]).is_empty():l(body,"影響マス: "+" / ".join(ui.preview.cells.map(coord)))
		for hit in ui.preview.get("damagePreview",[]):
			l(body,"予測: 指定 %s → 実受領者 %s / HP−%d" % [hit.get("targetName",hit.recipientName),hit.recipientName,hit.hpLoss])
		if ui.preview.get("damagePreview",[]).is_empty() and ui.command!="move":l(body,ui.command_hint())
		local(body,"内訳を閉じる" if breakdown_open else "内訳 / 効果説明",func():breakdown_open=not breakdown_open;ui.render())
		if breakdown_open:
			for hit in ui.preview.get("damagePreview",[]):
				var parts=[]
				for weapon in hit.get("weapons",[]):parts.append("%s ATK%d" % [weapon.name,weapon.atk])
				l(body," + ".join(parts)+" / 成長補正+%d" % hit.get("bonus",0))
			l(body,ui.command_hint())
	if ui.command=="skill":
		for skill in ui.data.get("skillset",[]):
			if skill.name==ui.data.get("skill"):
				var sources=[]
				for src in skill.get("sources",[]):sources.append(ui.campaign().get("slots",{}).get(src.get("slot",""),src.get("slot",""))+":"+str(src.get("itemName",src.get("itemId",""))))
				l(body,"由来: "+"・".join(sources))
	var cost="MP0 / 1行動"
	if ui.command=="skill":cost="MP%d / 1行動" % ui.data.get("skillInfo",{}).get("mp",1) if ui.data.get("skillInfo") is Dictionary else "MP1 / 1行動"
	elif ui.command in ["item","ether"]:cost="1個 / 1行動・残り%d個" % (ui.state().get("ethers",0) if ui.command=="ether" else ui.state().get("potions",{}).get("ally",0))
	l(target_box,"消費: "+cost)
	ui.battle_actions=ui.row(target_box);ui.battle_actions.name="BattleConfirm"
	ui.memory.key(b(ui.battle_actions,"取消",ui.cancel,ui.presenting),"battle_cancel")
	var commit=ui.primary(b(ui.battle_actions,"移動して手番終了" if ui.command=="move" else command_name()+"を確定",ui.commit,not ui.can_commit()))
	ui.memory.key(commit,"battle_commit")
func command_name() -> String:
	for pair in COMMANDS:
		if pair[0]==ui.command:return str(ui.data.get("skill","スキル")) if ui.command=="skill" else pair[1]
	return ui.command
func toggle_details():
	details_open=not details_open;resize()
func inspect_enemy(id: String):
	selected_enemy=id;detail_tab=0;details_open=true;ui.render()
func close_detail() -> bool:
	if breakdown_open:breakdown_open=false;ui.render();return true
	if ui.ui_size_mode!="standard" and details_open:details_open=false;resize();return true
	return false
func render_details():
	tabs=TabContainer.new();tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;details.add_child(tabs)
	for name_ in ["敵予告","全員状態","ログ"]:
		var container=VBoxContainer.new();container.name=name_;tabs.add_child(container)
		var body=ui.scroller(container);ui.memory.watch(body.get_parent(),"battle_details_"+name_)
		if name_=="全員状態":
			ui.side=body
			l(body,"所持: ポーション 味方%d / 敵%d\nエーテル%d（ポーター・射程無限）" % [ui.state().get("potions",{}).get("ally",0),ui.state().get("potions",{}).get("enemy",0),ui.state().get("ethers",0)])
			l(body,"通常射程 %d / スキル射程 %d / 移動 %d" % [ui.data.get("normalAttackReach",0),ui.data.get("skillReach",0),ui.data.get("moveReach",2)])
			ui.render_unit_details(body,ui.state());formations(body)
		elif name_=="ログ":
			l(body,"戦闘ログ（直近40件） / 実行済み予告は終了")
			for entry in ui.state().get("log",[]).slice(-40):l(body,ui.display_log(str(entry)))
		else:enemy_intents(body)
	tabs.current_tab=detail_tab;tabs.tab_changed.connect(func(index):detail_tab=index)
func enemy_intents(parent):
	for u in ui.state().get("units",[]):
		if u.side!="enemy" or u.hp<=0 or not u.get("intent") is Dictionary:continue
		var intent: Dictionary=u.intent;var fingerprint=JSON.stringify([intent,u.get("next")])
		if intent_versions.has(u.id) and intent_versions[u.id]!=fingerprint:intent_updated[u.id]=true
		intent_versions[u.id]=fingerprint
		var card=ui.card(parent);ui.memory.item(card.get_parent(),u.id)
		local(card,("● " if selected_enemy==u.id else "")+str(u.name),inspect_enemy.bind(u.id))
		l(card,("更新 / " if intent_updated.get(u.id,false) else "予告 / ")+str(intent.get("name","")))
		for pos in intent.get("cells",[]):
			var occupant=ui.board.unit_at(int(pos))
			l(card,"固定マス "+coord(pos)+" / 現在: "+str(occupant.get("name","空き")))
		if intent.get("destination")!=null:l(card,"移動予定: "+coord(intent.destination))
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
