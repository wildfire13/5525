extends RefCounted
## Session-only selection. Existing Campaign.select commits one ordered ID array.
const LEGACY_PARTY_LIMIT=5
const Tokens=preload("res://ui_tokens.gd")
var owner_ref: WeakRef
var pages:
	get:return owner_ref.get_ref()
var ui
var chosen_id := ""
var current_id := ""
var reserve: VBoxContainer
var compare: HBoxContainer
var footer: HBoxContainer
var detail_tab := 0
var origin_id := ""
var stage := "idle"
var mode := ""
var notice := ""
var generation := 0
var reserve_job := ""
var drag_serial := 0
func _init(owner):owner_ref=weakref(owner);ui=owner.ui
func c() -> Dictionary:return pages.c()
func party_limit() -> int:
	var value=c().get("partyLimit",LEGACY_PARTY_LIMIT)
	return int(value) if (value is int or value is float) and value>=1 else LEGACY_PARTY_LIMIT
func l(parent,text,large:=false):return ui.label_(parent,str(text),large)
func b(parent,text,fn,disabled:=false):return ui.button(parent,text,fn,disabled)
func available() -> bool:return ui.page=="party" and pages.facility_entry.view!="warehouse" and c().get("guildAvailable",false) and c().get("phase")=="town" and c().get("location")=="astaris"
func busy() -> bool:return ui.locked or ui.presenting or ui.closing or ui.engine.disconnected or stage in ["pending","unknown","animating"]
func reset():
	generation+=1;chosen_id="";origin_id="";mode="";stage="idle";notice="";reserve_job=""
func person(id: String) -> Dictionary:
	for member in ui.roster():
		if member.id==id:return member
	return {}
func active(id: String) -> bool:return c().get("selected",[]).has(id)
func porter_count() -> int:return c().get("selected",[]).filter(func(id):return person(str(id)).get("job")=="job_porter").size()
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
	var chooser=ui.mock_shell.job_filter(filter_row,reserve_job,set_reserve_job)
	chooser.name="GuildReserveJobFilter";chooser.disabled=busy() or stage!="idle";ui.memory.key(chooser,"guild_reserve_job")
	return filter_row
func render(parent):
	var lists=groups();var current=lists[1];var reserves=visible_reserves(lists[0])
	select_filtered_current(current,str(ui.mock_shell.roster_jobs.get("party","")))
	if active(chosen_id):chosen_id=""
	var split=ui.mock_shell.columns(parent);split.name="GuildColumns";split.custom_minimum_size.y=ui.mock_shell.content_height()
	split.add_theme_constant_override("separation",Tokens.SPACE_NONE)
	var panel=PanelContainer.new();panel.name="GuildComparison";panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;split.add_child(panel)
	var background=Tokens.surface_box(Tokens.SURFACE,false,Tokens.RADIUS_SM,Tokens.SPACE_NONE);panel.add_theme_stylebox_override("panel",background)
	var center=VBoxContainer.new();center.add_theme_constant_override("separation",Tokens.SPACE_NONE);panel.add_child(center)
	var cell=ui.mock_shell.grid_cell()
	var spacer=Control.new();spacer.custom_minimum_size.y=cell.y;spacer.mouse_filter=Control.MOUSE_FILTER_IGNORE;center.add_child(spacer)
	var tabs=ui.row(center);tabs.name="GuildInfoTabs"
	tabs.custom_minimum_size=cell*Vector2(2,1)
	tabs.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	for index in range(3):
		var tab=b(tabs,["能力","装備","スキル"][index],select_tab.bind(index));tab.name="GuildTab_"+str(index);Tokens.apply_button_size(tab);ui.mark_selected(tab,detail_tab==index)
	build_comparison(center)
	var reserve_panel=PanelContainer.new();reserve_panel.custom_minimum_size.x=ui.mock_shell.grid_cell().x*2;reserve_panel.add_theme_stylebox_override("panel",background);split.add_child(reserve_panel)
	reserve=VBoxContainer.new();reserve.name="GuildReserveColumn";reserve.size_flags_vertical=Control.SIZE_EXPAND_FILL;reserve_panel.add_child(reserve)
	l(reserve,"控え %d人" % lists[0].size()).name="GuildReserveHeading"
	reserve_filter(reserve)
	var body=ui.scroller(reserve);body.get_parent().name="GuildReserveScroll";ui.memory.watch(body.get_parent(),"guild_reserves_"+reserve_job)
	for u in reserves:
		var id=str(u.id);var button=b(body,"",choose.bind(id),busy());button.name="GuildMember_"+id;button.custom_minimum_size=Vector2(300,100)
		button.tooltip_text=str(u.name);button.set_script(preload("res://guild_member_card.gd"));button.configure(self,id);button.set_meta("member_id",id);button.set_meta("guild_active",false);ui.memory.key(button,"guild_member_"+id)
		ui.mark_selected(button,id==chosen_id)
		var margin=MarginContainer.new();margin.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,Tokens.SPACE_SM)
		var line=ui.row(margin);line.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var face=ui.portrait(line,u,false,40);face.custom_minimum_size=Vector2(44,72);face.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var copy=VBoxContainer.new();copy.mouse_filter=Control.MOUSE_FILTER_IGNORE;copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL;copy.add_theme_constant_override("separation",Tokens.SPACE_NONE);line.add_child(copy)
		for text in [str(u.name),str(u.get("role",""))+" · Lv."+str(int(u.get("level",1))),"HP %d/%d   MP %d/%d" % [u.hp,u.max,u.mp,u.maxMp]]:
			var label=l(copy,text);label.add_theme_font_size_override("font_size",Tokens.FONT_SM);label.autowrap_mode=TextServer.AUTOWRAP_OFF;label.clip_text=true;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if reserves.is_empty():l(body,"この職業の控えはいません")
	var add=b(reserve,"編成に加える",func():prepare("add","",chosen_id),busy() or candidate("add","",chosen_id).is_empty());add.name="GuildAdd";Tokens.apply_button_size(add,Tokens.BUTTON_MD,false);ui.action_button(add)
	update_remove_button();ui.mock_shell.refresh_roster_selection()
func select_tab(index: int):
	if detail_tab==index:return
	detail_tab=index
	refresh_selection()

func refresh_selection():
	if not is_instance_valid(compare) or not compare.is_inside_tree():
		ui.render()
		return
	ui.refresh_panel(func():
		var center=compare.get_parent()
		center.remove_child(compare)
		compare.queue_free()
		center.remove_child(footer)
		footer.queue_free()
		build_comparison(center)
		for button in center.find_children("GuildTab_*","Button",true,false):
			var selected=button.name=="GuildTab_"+str(detail_tab)
			if button.get_meta("selected",false)!=selected:ui.mark_selected(button,selected)
		for button in reserve.find_children("GuildMember_*","Button",true,false):
			var selected=button.get_meta("member_id")==chosen_id
			if button.get_meta("selected",false)!=selected:ui.mark_selected(button,selected)
		var add=reserve.find_child("GuildAdd",true,false)
		add.disabled=busy() or candidate("add","",chosen_id).is_empty()
		add.set_meta("base_disabled",add.disabled)
		update_remove_button()
		ui.mock_shell.refresh_roster_selection())

func build_comparison(center):
	compare=HBoxContainer.new();compare.name="GuildComparisonDetails";compare.size_flags_vertical=Control.SIZE_EXPAND_FILL;compare.add_theme_constant_override("separation",Tokens.SPACE_NONE);center.add_child(compare)
	var left=pages.card(compare);left.name="GuildActiveDetail";left.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
	render_member(left,person(current_id),"現在のパーティ")
	var swap_column=pages.card(compare);swap_column.name="GuildSwapColumn";swap_column.alignment=BoxContainer.ALIGNMENT_CENTER
	var swap=b(swap_column,"入れ替える",prepare.bind("swap",current_id,chosen_id),busy() or candidate("swap",current_id,chosen_id).is_empty());swap.name="GuildSwap";Tokens.apply_button_size(swap,Tokens.BUTTON_MD,true,Tokens.BUTTON_W_MD)
	var right=pages.card(compare);right.name="GuildReserveDetail";right.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
	render_member(right,person(chosen_id),"控え")
	for column in [left,swap_column,right]:
		var frame=column.get_parent()
		frame.name=str(column.name)+"Region"
		frame.custom_minimum_size.x=ui.mock_shell.grid_cell().x*2
		frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	footer=ui.row(center);footer.name="GuildActions"
	footer.custom_minimum_size.y=ui.mock_shell.grid_cell().y
	var notice_label=l(footer,notice);notice_label.name="GuildNotice";notice_label.add_theme_font_size_override("font_size",Tokens.FONT_SM);notice_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var back=b(footer,"戻る",pages.facility_entry.back,busy());back.name="GuildReturn";Tokens.apply_button_size(back,Tokens.BUTTON_MD,true,Tokens.BUTTON_W_SM)
func remove_button(parent):
	var remove=b(parent,"パーティから外す",func():prepare("remove",current_id,""));remove.name="GuildRemove";ui.action_button(remove)
	Tokens.apply_button_size(remove,Tokens.BUTTON_MD,false)
func update_remove_button():
	var button=ui.content.find_child("GuildRemove",true,false)
	if button!=null:
		button.disabled=busy() or candidate("remove",current_id,"").is_empty()
		button.set_meta("base_disabled",button.disabled)
func select_filtered_current(current: Array,job: String):
	var matches=current.filter(func(u):return job.is_empty() or u.job==job)
	if not matches.any(func(u):return str(u.id)==current_id):current_id=str(matches[0].id) if not matches.is_empty() else ""
	ui.pages.party_uid=current_id
func match_current_filter(job: String):
	select_filtered_current(groups()[1],job);refresh_selection()
func render_member(column,u: Dictionary,caption: String):
	if detail_tab==1:
		preload("res://member_loadout_column.gd").align_column(column.get_parent())
	l(column,caption).add_theme_font_size_override("font_size",Tokens.FONT_SM)
	if u.is_empty():
		if caption=="控え":
			var npc=pages.facility_art.npc
			if npc.texture!=null:
				var image=TextureRect.new();image.texture=npc.texture;image.custom_minimum_size=Vector2(160,300);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;column.add_child(image)
		l(column,"控えから人物を選んでください" if caption=="控え" else "この職業のメンバーはいません")
		return
	if detail_tab==1:
		var equipment_body=ui.scroller(column)
		var doll=preload("res://member_loadout_column.gd").new();equipment_body.add_child(doll)
		doll.build_art(ui,doll,u)
		doll.equipment(ui,u,"","GuildEq_"+str(u.id)+"_",func(_item):pass,Callable(),true)
		return
	var portrait=ui.portrait(column,u,false,128);portrait.custom_minimum_size=Vector2(128,220);portrait.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	var details=ui.scroller(column)
	match detail_tab:
		0:
			var stats=u.get("stats",u)
			for pair in [["STR","str"],["INT","int"],["AGI","agi"],["SPD","speed"]]:l(details,"%s  %s" % [pair[0],str(int(stats.get(pair[1],stats.get("agi",0))))])
			l(details,pages.defense_profile(stats)).add_theme_font_size_override("font_size",Tokens.FONT_SM)
			l(details,pages.attack_profile(stats)).add_theme_font_size_override("font_size",Tokens.FONT_SM)
		2:pages.party_view.skills(details,u,false)
func select_current(id: String):
	if not available() or busy() or ui.modal_open() or not active(id):return
	current_id=id;notice="";refresh_selection()
func choose(id: String):
	if not available() or busy() or ui.modal_open() or person(id).is_empty() or stage!="idle":return
	if active(id):select_current(id);return
	if not reserve_job.is_empty() and str(person(id).get("job",""))!=reserve_job:return
	chosen_id=id;notice="";ui.memory.request_focus("guild_member_"+id);refresh_selection()
func cancel_selection():
	if busy():return
	generation+=1;stage="idle";mode="";origin_id="";chosen_id="";notice="";refresh_selection()
func outside_press(point: Vector2):
	if not available() or busy() or ui.modal_open() or chosen_id.is_empty():return
	for name_ in ["GuildColumns","PartyRoster","PartyFaceBar"]:
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
	var old_faces={}
	for control in ui.find_children("PartyFace_*","Button",true,false):old_faces[str(control.get_meta("member_id"))]=control.get_global_rect()
	for control in ui.find_children("GuildMember_*","Button",true,false):old_rects[str(control.get_meta("member_id"))]=control.get_global_rect()
	if not incoming.is_empty() and not old_faces.has(incoming) and old_rects.has(incoming):old_faces[incoming]=old_rects[incoming]
	stage="pending";ui.dialog.close(false);var epoch=pages.epoch;var connection=ui.engine.connection_generation;ui.render()
	var reply=await ui.act("select",[ids])
	if ticket!=generation or epoch!=pages.epoch or connection!=ui.engine.connection_generation or ui.closing:return
	if reply.get("connection_lost",false):stage="unknown";notice="編成結果を確認できません。再送せず、保存済み進行を読み込んで確認してください。"
	elif reply.get("ok",false) and c().get("selected")==ids:
		stage="animating";chosen_id="";origin_id=""
		notice="%s → %s 入替完了" % [ui.member_name(outgoing),ui.member_name(incoming)] if kind in ["swap","reorder"] else "%sを編成に加えました。" % ui.member_name(incoming) if kind=="add" else "%sを控えへ戻しました。" % ui.member_name(outgoing)
	else:stage="idle";notice=str(reply.get("error","編成を変更できませんでした。最新の一覧から選び直してください。"))
	ui.render()
	if stage=="animating":
		animate_faces(old_faces,ticket)
		await animate_swap(old_rects,ticket)
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
	else:pages.facility_entry.back()
	return true

func drag_payload(id: String):
	if not available() or busy() or ui.modal_open() or stage!="idle" or person(id).is_empty():return null
	if not active(id) and not visible_reserves([person(id)]).has(person(id)):return null
	drag_serial+=1
	return {"kind":"guild_member","uid":id,"stamp":stamp(),"generation":generation,"serial":drag_serial,"consumed":false}
func valid_drag(data) -> bool:
	if not available() or busy() or ui.modal_open() or stage!="idle" or not data is Dictionary:return false
	return data.get("kind")=="guild_member" and data.get("uid") is String and not person(data.uid).is_empty() and data.get("stamp")==stamp() and data.get("generation")==generation and data.get("serial")==drag_serial and data.get("consumed")==false
func drop_operation(data,target: String="",append_slot:=false) -> Array:
	if not valid_drag(data):return []
	var source=str(data.uid)
	if append_slot:
		if active(source) or not target.is_empty():return []
		return ["add","",source] if not candidate("add","",source).is_empty() else []
	if target==source or person(target).is_empty():return []
	var operation=[]
	if active(source) and active(target):operation=["reorder",source,target]
	elif active(source):operation=["swap",source,target]
	elif active(target):operation=["swap",target,source]
	if operation.is_empty() or candidate(operation[0],operation[1],operation[2]).is_empty():return []
	return operation
func drop_member(data,target: String="",append_slot:=false):
	var operation=drop_operation(data,target,append_slot)
	if operation.is_empty():return
	data.consumed=true
	prepare(operation[0],operation[1],operation[2])
func animate_faces(old_rects: Dictionary,ticket: int):
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	if generation!=ticket or ui.closing:return
	var strip=ui.find_child("PartyFacesScroll",true,false)
	if strip==null:return
	var clip=Control.new();clip.name="GuildPartyAnimation";clip.mouse_filter=Control.MOUSE_FILTER_IGNORE;clip.clip_contents=true;clip.z_index=100;ui.add_child(clip);clip.global_position=strip.global_position;clip.size=strip.size
	var hidden=[];var tween=ui.create_tween().set_parallel(true)
	for control in ui.find_children("PartyFace_*","Button",true,false):
		var id=str(control.get_meta("member_id"));var target=control.get_global_rect()
		if not old_rects.has(id) or old_rects[id].position.distance_to(target.position)<1:continue
		var ghost=control.duplicate(0) as Button;clip.add_child(ghost);ghost.mouse_filter=Control.MOUSE_FILTER_IGNORE;ghost.focus_mode=Control.FOCUS_NONE;ghost.position=old_rects[id].position-clip.global_position;ghost.size=target.size
		hidden.append(control);control.modulate.a=0
		tween.tween_property(ghost,"position",target.position-clip.global_position,.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if hidden.is_empty():tween.kill()
	else:await tween.finished
	for control in hidden:
		if is_instance_valid(control):control.modulate.a=1
	if is_instance_valid(clip):clip.queue_free()
