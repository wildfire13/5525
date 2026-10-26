extends RefCounted
## Session-only selection. Existing Campaign.select commits one ordered ID array.
const LEGACY_PARTY_LIMIT=5
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
var reserve_job := ""
func _init(owner):owner_ref=weakref(owner);ui=owner.ui
func c() -> Dictionary:return pages.c()
func party_limit() -> int:
	var value=c().get("partyLimit",LEGACY_PARTY_LIMIT)
	return int(value) if (value is int or value is float) and value>=1 else LEGACY_PARTY_LIMIT
func l(parent,text,large:=false):return ui.label_(parent,str(text),large)
func b(parent,text,fn,disabled:=false):return ui.button(parent,text,fn,disabled)
func available() -> bool:return ui.page=="party" and c().get("guildAvailable",false) and c().get("phase")=="town" and c().get("location")=="astaris"
func busy() -> bool:return ui.locked or ui.presenting or ui.closing or ui.engine.disconnected or stage in ["pending","unknown","animating"]
func reset():
	generation+=1;chosen_id="";origin_id="";mode="";stage="idle";notice="";reserve_job=""
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
func visible_reserves(reserves: Array) -> Array:
	return reserves if reserve_job.is_empty() else reserves.filter(func(u):return str(u.get("job",""))==reserve_job)
func set_reserve_job(value: String):
	if not available() or busy() or ui.modal_open() or stage!="idle":return
	if value==reserve_job:return
	reserve_job=value
	var selected=person(chosen_id)
	if not selected.is_empty() and not active(chosen_id) and not visible_reserves([selected]).has(selected):
		notice="%sは絞り込み対象外のため、選択を解除しました。" % selected.name
		generation+=1;chosen_id="";origin_id="";mode=""
	else:notice=""
	ui.memory.request_focus("guild_reserve_job");ui.render()
func reserve_filter(parent):
	var filter_row=ui.row(parent);filter_row.name="GuildReserveFilter"
	var caption=l(filter_row,"控えの職業");caption.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;caption.autowrap_mode=TextServer.AUTOWRAP_OFF;caption.add_theme_font_size_override("font_size",18)
	var chooser=OptionButton.new();chooser.name="GuildReserveJobFilter";chooser.custom_minimum_size=Vector2(180,40);chooser.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	chooser.add_item("すべて");chooser.set_item_metadata(0,"")
	var jobs=[]
	for member in ui.roster():
		var job=str(member.get("job",""))
		if job.is_empty() or jobs.has(job):continue
		jobs.append(job);chooser.add_item(str(member.get("role",job)));chooser.set_item_metadata(chooser.item_count-1,job)
		if job==reserve_job:chooser.select(chooser.item_count-1)
	chooser.disabled=busy() or stage!="idle";filter_row.add_child(chooser);ui.memory.key(chooser,"guild_reserve_job")
	chooser.item_selected.connect(func(index):set_reserve_job(str(chooser.get_item_metadata(index))))
	return filter_row
func render(parent):
	var compact=ui.size.y<720
	var limit=party_limit()
	var header=Control.new();header.name="GuildRules";header.custom_minimum_size.y=56 if compact else 80;parent.add_child(header)
	var rules=VBoxContainer.new();header.add_child(rules);rules.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var capacity=l(rules,"現在%d/%d人（最大%d人） / 残り%d枠 / ポーター%d人" % [c().get("selected",[]).size(),limit,limit,maxi(0,limit-c().get("selected",[]).size()),porter_count()]);capacity.name="GuildCapacity";capacity.add_theme_font_size_override("font_size",16 if compact else 20)
	var hint=l(rules,"編成変更は無料。ポーターは受注時のみ最低1人必要。2人選択で入替・並び替え。");hint.add_theme_font_size_override("font_size",16 if compact else 18)
	var split=HBoxContainer.new();split.name="GuildColumns";split.size_flags_vertical=Control.SIZE_EXPAND_FILL;split.add_theme_constant_override("separation",12);parent.add_child(split)
	var actions_column=VBoxContainer.new();actions_column.name="GuildActionColumn";actions_column.custom_minimum_size.x=188;actions_column.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;actions_column.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var upper_space=Control.new();upper_space.size_flags_vertical=Control.SIZE_EXPAND_FILL;actions_column.add_child(upper_space)
	var actions=VBoxContainer.new();actions.name="GuildActions";actions.add_theme_constant_override("separation",6 if compact else 12);actions_column.add_child(actions)
	var lower_space=Control.new();lower_space.size_flags_vertical=Control.SIZE_EXPAND_FILL;actions_column.add_child(lower_space)
	var lists=groups();var reserve_count=lists[0].size();lists[0]=visible_reserves(lists[0]);var buttons={};var filter_height=40.0
	for side in range(2):
		var column=VBoxContainer.new();column.name="GuildReserveColumn" if side==0 else "GuildCurrentColumn";column.custom_minimum_size.x=240;column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;split.add_child(column)
		if side==0:split.add_child(actions_column)
		var title=l(column,("控え %d人" % reserve_count if reserve_job.is_empty() else "控え %d/%d人表示" % [lists[0].size(),reserve_count]) if side==0 else "現在のパーティー %d/%d人" % [lists[1].size(),limit],true);title.name="GuildReserveHeading" if side==0 else "GuildCurrentHeading";title.add_theme_font_size_override("font_size",18 if compact else 22);title.autowrap_mode=TextServer.AUTOWRAP_OFF;title.clip_text=true;title.tooltip_text=title.text
		if side==0:filter_height=reserve_filter(column).get_combined_minimum_size().y
		else:
			var spacer=Control.new();spacer.custom_minimum_size.y=filter_height;column.add_child(spacer)
		var body=ui.scroller(column);var scroll=body.get_parent();scroll.name="GuildReserveScroll" if side==0 else "GuildCurrentScroll";scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;ui.memory.watch(scroll,("guild_reserves"+("_"+reserve_job if not reserve_job.is_empty() else "")) if side==0 else "guild_current")
		body.add_theme_constant_override("separation",6)
		if lists[side].is_empty():l(body,("この職業の控えはいません。『すべて』で控え全員を表示できます。" if not reserve_job.is_empty() else "控えの人物はいません。") if side==0 else "編成中の人物はいません。").name="GuildEmptyReserves" if side==0 else "GuildEmptyCurrent"
		for u in lists[side]:
			var id=str(u.id);var selected=id==chosen_id or stage=="confirm" and id==origin_id
			var disabled=busy() or stage=="confirm"
			var button=b(body,"",choose.bind(id),disabled);button.name="GuildMember_"+id;button.custom_minimum_size.y=124 if compact else 132;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;buttons[id]=button
			button.set_meta("member_id",id);button.set_meta("guild_active",side==1);ui.memory.key(button,"guild_member_"+id);ui.memory.item(button,id)
			if selected:
				for state_ in ["normal","hover","pressed"]:
					var style=button.get_theme_stylebox(state_).duplicate();style.bg_color=Color("#31545b");style.border_color=Color("#91dacf");style.set_border_width_all(2);button.add_theme_stylebox_override(state_,style)
			var margin=MarginContainer.new();margin.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,8)
			var row=ui.row(margin);row.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var face=ui.portrait(row,u,false,48 if compact else 64);face.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var copy=VBoxContainer.new();copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL;copy.mouse_filter=Control.MOUSE_FILTER_IGNORE;copy.add_theme_constant_override("separation",0);row.add_child(copy)
			var name_=l(copy,str(u.name)+" / "+str(u.get("role",u.get("job",""))));name_.name="GuildName_"+id;name_.add_theme_font_size_override("font_size",18 if compact else 22);name_.autowrap_mode=TextServer.AUTOWRAP_OFF;name_.clip_text=true;name_.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var stats=l(copy,"Lv.%d   HP %d/%d\nMP %d/%d" % [u.get("level",1),u.hp,u.max,u.mp,u.maxMp]);stats.name="GuildVitals_"+id;stats.add_theme_font_size_override("font_size",16 if compact else 18);stats.autowrap_mode=TextServer.AUTOWRAP_OFF;stats.clip_text=true;stats.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var status=l(copy,("選択中 / " if selected else "")+("現在のパーティー" if side==1 else "控え"));status.name="GuildStatus_"+id;status.add_theme_font_size_override("font_size",14 if compact else 18);status.autowrap_mode=TextServer.AUTOWRAP_OFF;status.clip_text=true;status.mouse_filter=Control.MOUSE_FILTER_IGNORE
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
	var footer=Control.new();footer.name="GuildOperations";footer.custom_minimum_size.y=56 if compact else 64;footer.clip_contents=true;parent.add_child(footer)
	var controls=VBoxContainer.new();footer.add_child(controls);controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);controls.add_theme_constant_override("separation",4)
	var u=person(chosen_id)
	var instruction="人物を選択してください。" if u.is_empty() else "選択中：%s / %s" % [u.name,"現在のパーティー" if active(chosen_id) else "控え"]
	if not u.is_empty() and active(chosen_id) and c().selected.size()==1:instruction+=" / パーティーは最低1人です。控えの人物と入れ替えできます。"
	elif not u.is_empty() and not active(chosen_id) and c().selected.size()>=limit:instruction+=" / %d/%d人。入れ替える人物を選んでください。" % [limit,limit]
	var description=l(controls,instruction);description.name="GuildSelection";description.autowrap_mode=TextServer.AUTOWRAP_OFF;description.clip_text=true;description.tooltip_text=instruction;description.add_theme_font_size_override("font_size",18 if compact else 20)
	var result=l(controls,notice);result.name="GuildNotice";result.autowrap_mode=TextServer.AUTOWRAP_OFF;result.clip_text=true;result.add_theme_font_size_override("font_size",16 if compact else 18)
	var blocked=busy() or stage!="idle"
	var add=b(actions,"編成に加える",prepare.bind("add","",chosen_id),u.is_empty() or active(chosen_id) or c().selected.size()>=limit or blocked);add.name="GuildAdd"
	var details=b(actions,"人物詳細",pages.party_view.open_detail.bind(chosen_id),u.is_empty() or busy() or stage=="confirm");details.name="GuildDetails"
	var remove=b(actions,"パーティーから外す",prepare.bind("remove",chosen_id,""),u.is_empty() or not active(chosen_id) or c().selected.size()==1 or blocked);remove.name="GuildRemove"
	for action in [add,details,remove]:
		action.custom_minimum_size=Vector2(188,44 if compact else 60)
		action.add_theme_font_size_override("font_size",17 if compact else 18)
		ui.memory.key(action,str(action.name).to_snake_case())
		for side in range(2):
			if lists[side].is_empty():continue
			var id=chosen_id if lists[side].any(func(member):return str(member.id)==chosen_id) else str(lists[side][0].id)
			var target=buttons[id]
			if side==0:action.focus_neighbor_left=action.get_path_to(target)
			else:action.focus_neighbor_right=action.get_path_to(target)
	for side in range(2):
		for member in lists[side]:
			var button=buttons[str(member.id)]
			var action=add if side==0 and not add.disabled else remove if side==1 and not remove.disabled else details
			if action.disabled:continue
			if side==0:button.focus_neighbor_right=button.get_path_to(action)
			else:button.focus_neighbor_left=button.get_path_to(action)

func choose(id: String):
	if not available() or busy() or ui.modal_open() or person(id).is_empty():return
	if not active(id) and not reserve_job.is_empty() and str(person(id).get("job",""))!=reserve_job:return
	if stage!="idle":return
	if chosen_id==id:
		pages.party_view.open_detail(id);return
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
	for name_ in ["GuildReserveScroll","GuildCurrentScroll","GuildReserveFilter","GuildActions","TownReturnRow","PartyFaceBar"]:
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
		if ids.size()>=party_limit():return []
		ids.append(incoming)
	elif kind=="remove":ids.erase(outgoing)
	else:return []
	if ids.is_empty() or ids.size()>party_limit() or ids.any(func(id):return person(str(id)).is_empty()):return []
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
	var columns=ui.find_child("GuildColumns",true,false)
	var clip=Control.new();clip.name="GuildAnimationClip";clip.mouse_filter=Control.MOUSE_FILTER_IGNORE;clip.clip_contents=true;clip.z_index=100
	ui.add_child(clip)
	clip.global_position=columns.global_position;clip.size=columns.size
	var bounds=clip.get_global_rect()
	var ghosts=[];var hidden=[];var tween=ui.create_tween().set_parallel(true)
	for control in ui.find_children("GuildMember_*","Button",true,false):
		var id=str(control.get_meta("member_id"));var target=control.get_global_rect()
		if not old_rects.has(id) or old_rects[id].position.distance_to(target.position)<1:continue
		if not bounds.intersects(old_rects[id]) and not bounds.intersects(target):continue
		var ghost=control.duplicate(0) as Button
		clip.add_child(ghost);ghost.name="GuildSlide_"+id;ghost.mouse_filter=Control.MOUSE_FILTER_IGNORE;ghost.focus_mode=Control.FOCUS_NONE
		ghost.position=old_rects[id].position-bounds.position;ghost.size=old_rects[id].size;ghost.modulate=Color.WHITE
		ghosts.append(ghost);hidden.append(control);control.modulate.a=0
		tween.tween_property(ghost,"position",target.position-bounds.position,.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(ghost,"size",target.size,.32)
	if ghosts.is_empty():tween.kill()
	else:await tween.finished
	for ghost in ghosts:
		if is_instance_valid(ghost):ghost.queue_free()
	if is_instance_valid(clip):clip.queue_free()
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
