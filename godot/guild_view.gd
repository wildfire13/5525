extends RefCounted
## Session-only selection. Existing Campaign.select commits one ordered ID array.
const LIMIT=5
var owner_ref: WeakRef
var pages:
	get:return owner_ref.get_ref()
var ui
var chosen_id := ""
var origin_id := ""
var stage := "idle"
var mode := ""
var notice := ""
var generation := 0
func _init(owner):owner_ref=weakref(owner);ui=owner.ui
func c() -> Dictionary:return pages.c()
func l(parent,text,large:=false):return ui.label_(parent,str(text),large)
func b(parent,text,fn,disabled:=false):return ui.button(parent,text,fn,disabled)
func available() -> bool:return ui.page=="party" and c().get("guildAvailable",false) and c().get("phase")=="town" and c().get("location")=="astaris"
func busy() -> bool:return ui.locked or ui.presenting or ui.closing or ui.engine.disconnected or stage in ["pending","unknown","animating"]
func reset():
	generation+=1;chosen_id="";origin_id="";mode="";stage="idle";notice=""
func person(id: String) -> Dictionary:
	for member in ui.roster():
		if member.id==id:return member
	return {}
func active(id: String) -> bool:return c().get("selected",[]).has(id)
func porter_count() -> int:return c().get("selected",[]).filter(func(id):return person(str(id)).get("job")=="porter").size()
func stamp() -> String:return JSON.stringify([pages.epoch,ui.engine.connection_generation,c().get("inventoryToken"),c().get("selected")])
func groups() -> Array:
	var current=[];var reserves=[]
	for id in c().get("selected",[]):
		var u=person(str(id))
		if not u.is_empty():current.append(u)
	for u in ui.roster():
		if not active(str(u.id)):reserves.append(u)
	return [reserves,current]
func render(parent):
	var header=Control.new();header.name="GuildRules";header.custom_minimum_size.y=64;parent.add_child(header)
	var rules=VBoxContainer.new();header.add_child(rules);rules.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l(rules,"最大%d人 / ポーター%d人（クエスト受注時は最低1人） / 編成変更は無料" % [LIMIT,porter_count()])
	var hint=l(rules,"人物を選択 → 入替相手を選択。パーティー内の並び順も変更できます。");hint.add_theme_font_size_override("font_size",18)
	var split=HBoxContainer.new();split.name="GuildColumns";split.size_flags_vertical=Control.SIZE_EXPAND_FILL;split.add_theme_constant_override("separation",24);parent.add_child(split)
	var lists=groups();var buttons={}
	for side in range(2):
		var column=VBoxContainer.new();column.name="GuildReserveColumn" if side==0 else "GuildCurrentColumn";column.custom_minimum_size.x=mini(860,maxi(240,int((ui.size.x-72)/2)));column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;split.add_child(column)
		var title=l(column,"控え %d人" % lists[0].size() if side==0 else "現在のパーティー %d/%d人" % [lists[1].size(),LIMIT],true);title.name="GuildReserveHeading" if side==0 else "GuildCurrentHeading"
		var body=ui.scroller(column);var scroll=body.get_parent();scroll.name="GuildReserveScroll" if side==0 else "GuildCurrentScroll";scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;ui.memory.watch(scroll,"guild_reserves" if side==0 else "guild_current")
		body.add_theme_constant_override("separation",6)
		if lists[side].is_empty():l(body,"控えの人物はいません。" if side==0 else "編成中の人物はいません。")
		for u in lists[side]:
			var id=str(u.id);var selected=id==chosen_id or stage=="confirm" and id==origin_id
			var disabled=busy() or stage=="confirm"
			var button=b(body,"",choose.bind(id),disabled);button.name="GuildMember_"+id;button.custom_minimum_size.y=104;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;buttons[id]=button
			button.set_meta("member_id",id);button.set_meta("guild_active",side==1);ui.memory.key(button,"guild_member_"+id);ui.memory.item(button,id)
			if selected:
				for state_ in ["normal","hover","pressed"]:
					var style=button.get_theme_stylebox(state_).duplicate();style.bg_color=Color("#31545b");style.border_color=Color("#91dacf");style.set_border_width_all(2);button.add_theme_stylebox_override(state_,style)
			var margin=MarginContainer.new();margin.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,8)
			var row=ui.row(margin);row.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var face=ui.portrait(row,u,false,72);face.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var copy=VBoxContainer.new();copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL;copy.mouse_filter=Control.MOUSE_FILTER_IGNORE;copy.add_theme_constant_override("separation",0);row.add_child(copy)
			var name_=l(copy,str(u.name)+" / "+str(u.get("role",u.get("job",""))));name_.name="GuildName_"+id;name_.add_theme_font_size_override("font_size",22);name_.autowrap_mode=TextServer.AUTOWRAP_OFF;name_.clip_text=true;name_.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var stats=l(copy,"Lv.%d   HP %d/%d   MP %d/%d" % [u.get("level",1),u.hp,u.max,u.mp,u.maxMp]);stats.name="GuildVitals_"+id;stats.add_theme_font_size_override("font_size",20);stats.autowrap_mode=TextServer.AUTOWRAP_OFF;stats.clip_text=true;stats.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var status=l(copy,("選択中 / " if selected else "")+("現在のパーティー" if side==1 else "控え"));status.name="GuildStatus_"+id;status.add_theme_font_size_override("font_size",18);status.mouse_filter=Control.MOUSE_FILTER_IGNORE
			button.tooltip_text=name_.text+"\n"+stats.text+"\n"+status.text
	for side in range(2):
		for i in range(lists[side].size()):
			var button=buttons[str(lists[side][i].id)]
			if i>0:button.focus_neighbor_top=button.get_path_to(buttons[str(lists[side][i-1].id)])
			if i+1<lists[side].size():button.focus_neighbor_bottom=button.get_path_to(buttons[str(lists[side][i+1].id)])
			if not lists[1-side].is_empty():
				var other=buttons[str(lists[1-side][mini(i,lists[1-side].size()-1)].id)]
				if side==0:button.focus_neighbor_right=button.get_path_to(other)
				else:button.focus_neighbor_left=button.get_path_to(other)
	var footer=Control.new();footer.name="GuildOperations";footer.custom_minimum_size.y=140;footer.clip_contents=true;parent.add_child(footer)
	var controls=VBoxContainer.new();footer.add_child(controls);controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);controls.add_theme_constant_override("separation",8)
	var u=person(chosen_id)
	var instruction="人物を選択してください。" if u.is_empty() else "選択中：%s / %s" % [u.name,"現在のパーティー" if active(chosen_id) else "控え"]
	if not u.is_empty() and active(chosen_id) and c().selected.size()==1:instruction+=" / パーティーは最低1人です。控えの人物と入れ替えできます。"
	elif not u.is_empty() and not active(chosen_id) and c().selected.size()>=LIMIT:instruction+=" / %d/%d人。入れ替える人物を選んでください。" % [LIMIT,LIMIT]
	var description=l(controls,instruction);description.name="GuildSelection";description.autowrap_mode=TextServer.AUTOWRAP_OFF;description.clip_text=true;description.add_theme_font_size_override("font_size",20)
	var result=l(controls,notice);result.name="GuildNotice";result.autowrap_mode=TextServer.AUTOWRAP_OFF;result.clip_text=true;result.add_theme_font_size_override("font_size",18)
	var actions=ui.row(controls);actions.name="GuildActions"
	if stage=="idle":
		if active(chosen_id):b(actions,"控えへ戻す",prepare.bind("remove",chosen_id,""),u.is_empty() or c().selected.size()==1 or busy()).name="GuildRemove"
		else:b(actions,"編成に加える",prepare.bind("add","",chosen_id),u.is_empty() or c().selected.size()>=LIMIT or busy()).name="GuildAdd"
	b(actions,"人物詳細",pages.party_view.open_detail.bind(chosen_id),u.is_empty() or busy() or stage=="confirm").name="GuildDetails"
	b(actions,"アスタリスへ戻る",ui.navigate.bind("hub"),busy()).name="GuildReturn"
func choose(id: String):
	if not available() or busy() or ui.modal_open() or person(id).is_empty():return
	if stage!="idle":return
	if not chosen_id.is_empty() and chosen_id!=id:
		origin_id=chosen_id
		if active(chosen_id) and active(id):prepare("reorder",chosen_id,id);return
		if active(chosen_id):prepare("swap",chosen_id,id);return
		if active(id):prepare("swap",id,chosen_id);return
	chosen_id=id;notice="";ui.memory.request_focus("guild_member_"+id);ui.render()
func cancel_selection():
	if busy():return
	generation+=1;stage="idle";mode="";origin_id="";chosen_id="";notice="";ui.render()
func outside_press(point: Vector2):
	if not available() or busy() or ui.modal_open() or chosen_id.is_empty():return
	for name_ in ["GuildReserveScroll","GuildCurrentScroll","GuildActions","PartyFaceBar"]:
		var area=ui.find_child(name_,true,false)
		if area!=null and area.get_global_rect().has_point(point):return
	cancel_selection()
func candidate(kind: String,outgoing: String,incoming: String) -> Array:
	if not available():return []
	var ids=c().get("selected",[]).duplicate()
	if kind=="reorder":
		if outgoing==incoming or not ids.has(outgoing) or not ids.has(incoming):return []
		var first=ids.find(outgoing);var second=ids.find(incoming)
		ids[first]=incoming;ids[second]=outgoing;return ids
	if kind in ["swap","remove"] and not ids.has(outgoing):return []
	if kind in ["swap","add"] and (person(incoming).is_empty() or ids.has(incoming)):return []
	if kind=="swap":ids[ids.find(outgoing)]=incoming
	elif kind=="add":
		if ids.size()>=LIMIT:return []
		ids.append(incoming)
	elif kind=="remove":ids.erase(outgoing)
	else:return []
	if ids.is_empty() or ids.size()>LIMIT or ids.any(func(id):return person(str(id)).is_empty()):return []
	var unique={}
	for id in ids:unique[id]=true
	if unique.size()!=ids.size():return []
	return ids
func prepare(kind: String,outgoing: String,incoming: String):
	if busy() or ui.modal_open():return
	if stage!="idle":return
	var ids=candidate(kind,outgoing,incoming)
	if ids.is_empty():notice="人数・所属・固定条件を確認してください。";ui.render();return
	mode=kind;generation+=1;var ticket=generation;var context=stamp();stage="confirm"
	var quest=c().get("activeQuest")
	var cargo_warning=kind in ["swap","remove"] and quest is Dictionary and quest.get("cargoOwnerId")==outgoing
	if not cargo_warning:commit(kind,outgoing,incoming,ids,context,ticket);return
	var text="%sを控えに戻し、%sを編成します。" % [ui.member_name(outgoing),ui.member_name(incoming)] if kind=="swap" else "%sを編成の末尾へ加えます。" % ui.member_name(incoming) if kind=="add" else "%sを控えへ戻します。人物・装備・所持品は保持します。" % ui.member_name(outgoing)
	ui.dialog.open("編成変更の確認",func(body,actions):
		if kind in ["swap","remove"] and quest is Dictionary and quest.get("cargoOwnerId")==outgoing:
			l(body,"そのポーター、荷物を持っていますが、控えに戻してよいですか？",true)
			l(body,"荷物は本人が持ち続けます。控えのままでは納品できません。")
		l(body,text,true);l(body,"編成変更は無料です。自動装備や所持品の移動は行いません。")
		b(actions,"取り消す",ui.dialog.close).name="GuildConfirmCancel"
		ui.primary(b(actions,"入れ替える" if kind=="swap" else "編成に加える" if kind=="add" else "控えへ戻す",commit.bind(kind,outgoing,incoming,ids,context,ticket))).name="GuildConfirm",
		func():
			if ticket!=generation or stage!="confirm":return
			generation+=1;stage="idle";notice="確認を取り消しました。";ui.render())
func commit(kind: String,outgoing: String,incoming: String,ids: Array,context: String,ticket: int):
	if busy() or stage!="confirm" or ticket!=generation:return
	if context!=stamp() or ids!=candidate(kind,outgoing,incoming):
		ui.dialog.close(false);stage="idle";notice="編成の状態が変わりました。最新の一覧から選び直してください。";ui.render();return
	var old_rects={}
	for control in ui.find_children("GuildMember_*","Button",true,false):old_rects[str(control.get_meta("member_id"))]=control.get_global_rect()
	stage="pending";ui.dialog.close(false);var epoch=pages.epoch;var connection=ui.engine.connection_generation;ui.render()
	var reply=await ui.act("select",[ids])
	if ticket!=generation or epoch!=pages.epoch or connection!=ui.engine.connection_generation or ui.closing:return
	if reply.get("connection_lost",false):stage="unknown";notice="編成結果を確認できません。再送せず、保存済み進行を読み込んで確認してください。"
	elif reply.get("ok",false) and c().get("selected")==ids:
		stage="animating";chosen_id="";origin_id=""
		notice="%s → %s 入替完了" % [ui.member_name(outgoing),ui.member_name(incoming)] if kind in ["swap","reorder"] else "%sを編成に加えました。" % ui.member_name(incoming) if kind=="add" else "%sを控えへ戻しました。" % ui.member_name(outgoing)
	else:stage="idle";notice=str(reply.get("error","編成を変更できませんでした。最新の一覧から選び直してください。"))
	ui.render()
	if stage=="animating":await animate_swap(old_rects,ticket)
func animate_swap(old_rects: Dictionary,ticket: int):
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	if generation!=ticket or ui.closing:return
	var ghosts=[];var hidden=[];var tween=ui.create_tween().set_parallel(true)
	for control in ui.find_children("GuildMember_*","Button",true,false):
		var id=str(control.get_meta("member_id"));var target=control.get_global_rect()
		if not old_rects.has(id) or old_rects[id].position.distance_to(target.position)<1:continue
		var ghost=control.duplicate(0) as Button
		ui.add_child(ghost);ghost.name="GuildSlide_"+id;ghost.mouse_filter=Control.MOUSE_FILTER_IGNORE;ghost.focus_mode=Control.FOCUS_NONE;ghost.z_index=100
		ghost.position=old_rects[id].position;ghost.size=old_rects[id].size;ghost.modulate=Color.WHITE
		ghosts.append(ghost);hidden.append(control);control.modulate.a=0
		tween.tween_property(ghost,"position",target.position,.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(ghost,"size",target.size,.32)
	if ghosts.is_empty():tween.kill()
	else:await tween.finished
	for ghost in ghosts:
		if is_instance_valid(ghost):ghost.queue_free()
	for control in hidden:
		if is_instance_valid(control):control.modulate.a=1
	if generation==ticket and not ui.closing:stage="idle";ui.render()
func guard_leave() -> bool:
	if busy():return false
	generation+=1;stage="idle";origin_id="";chosen_id="";mode="";return true
func escape() -> bool:
	if ui.page!="party" or not c().get("guildAvailable",false):return false
	if busy():return true
	if not chosen_id.is_empty():cancel_selection()
	else:ui.navigate("hub")
	return true
