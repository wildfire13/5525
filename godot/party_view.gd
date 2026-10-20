extends RefCounted
var owner_ref: WeakRef
var pages:
	get:return owner_ref.get_ref()
var ui
var tab := 0
var highlight_slot := ""
var draft_uid := ""
var draft_token := ""
var draft: Dictionary={"str":0,"int":0,"agi":0}
var detail_uid := ""
var detail_tab := 0
var detail_gear: Dictionary={}
var committing := false
var leave_pending := false
var modal_refreshing := false
var inventory_view
var owned_equipment_view
func _init(owner):owner_ref=weakref(owner);ui=owner.ui;inventory_view=preload("res://inventory_view.gd").new(self);owned_equipment_view=preload("res://owned_equipment_view.gd").new(self)
func l(parent,text,large:=false):return ui.label_(parent,str(text),large)
func b(parent,text,fn,disabled:=false):return ui.button(parent,text,fn,disabled)
func render(parent):
	l(parent,"ギルド / パーティー編成" if pages.c().get("guildAvailable",false) else "仲間・装備",true).name="PartyFacilityHeading"
	if pages.c().get("guildAvailable",false):pages.guild_view.render(parent);return
	var c=pages.c();var members=ui.visible_roster();var ids=c.get("selected",[])
	if members.is_empty():return
	if not draft_uid.is_empty() and not ui.active_member(draft_uid):clear_draft()
	if not members.any(func(u):return u.id==pages.party_uid):pages.party_uid=str(ids[0]) if not ids.is_empty() else str(members[0].id)
	var split=HBoxContainer.new() if ui.ui_size_mode=="standard" else VBoxContainer.new();split.name="PartySplit";split.size_flags_vertical=Control.SIZE_EXPAND_FILL;split.add_theme_constant_override("separation",12);parent.add_child(split)
	var active=[];var reserves=[]
	for id in ids:
		for u in members:
			if u.id==id:active.append(u)
	for u in members:
		if not ids.has(u.id):reserves.append(u)
	if ui.ui_size_mode=="standard":
		var body=ui.scroller(split);var roster_scroll=body.get_parent();roster_scroll.custom_minimum_size.x=360;roster_scroll.size_flags_horizontal=Control.SIZE_FILL;roster_scroll.name="PartyRoster";ui.memory.watch(roster_scroll,"party_roster")
		var groups=[["編成 %d/5" % ids.size(),active]]
		if ui.reserves_visible():groups.append(["控え %d人" % reserves.size(),reserves])
		for group in groups:
			l(body,group[0],true)
			for u in group[1]:
				var r=ui.row(body);r.set_meta("member_id",u.id);r.set_meta("active_member",ids.has(u.id));ui.portrait(r,u,true,40)
				ui.icons.add(r,ui.icons.race(str(u.race)),24);ui.icons.add(r,ui.icons.job(str(u.job)),24)
				var chooser=b(r,("● " if u.id==pages.party_uid else "")+str(u.name)+" / "+str(u.get("role",""))+"\nHP%d/%d MP%d/%d" % [u.hp,u.max,u.mp,u.maxMp],pages.select_party.bind(str(u.id)))
				chooser.custom_minimum_size.y=56;chooser.clip_text=true;chooser.size_flags_horizontal=Control.SIZE_EXPAND_FILL;chooser.tooltip_text=chooser.text;ui.memory.key(chooser,"party_"+str(u.id));ui.memory.item(r,str(u.id))
	else:
		l(split,"編成 %d/5" % ids.size())
		var lineup=ui.row(split);lineup.name="PartyActiveLineup"
		for u in active:
			var chooser=b(lineup,"",pages.select_party.bind(str(u.id)));chooser.custom_minimum_size.y=108;chooser.size_flags_horizontal=Control.SIZE_EXPAND_FILL;chooser.set_meta("member_id",u.id);ui.memory.key(chooser,"party_"+str(u.id))
			var card=VBoxContainer.new();chooser.add_child(card);card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);card.offset_top=4;card.offset_bottom=-4;card.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_theme_constant_override("separation",0)
			var face=ui.portrait(card,u,true,28);face.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var caption=l(card,("● " if u.id==pages.party_uid else "")+str(u.name)+" / "+str(u.get("role",""))+"\nHP%d/%d\nMP%d/%d" % [u.hp,u.max,u.mp,u.maxMp]);caption.add_theme_font_size_override("font_size",16);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.autowrap_mode=TextServer.AUTOWRAP_OFF;caption.clip_text=true;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;chooser.tooltip_text=caption.text
			card.minimum_size_changed.connect(func():
				if is_instance_valid(chooser):chooser.custom_minimum_size.y=maxf(108,card.get_minimum_size().y+8))
		if ui.reserves_visible():
			var reserve_row=ui.row(split);l(reserve_row,"控え %d人" % reserves.size())
			var chooser=OptionButton.new();chooser.name="PartyReserveSelector";chooser.custom_minimum_size.y=44;chooser.size_flags_horizontal=Control.SIZE_EXPAND_FILL;chooser.clip_text=true;chooser.add_theme_constant_override("icon_max_width",28);reserve_row.add_child(chooser);ui.memory.key(chooser,"party_narrow_select")
			chooser.add_item("控えの仲間を選択");chooser.set_item_disabled(0,true)
			for u in reserves:
				chooser.add_icon_item(ui.portraits.texture(u,true),str(u.name)+" / "+str(u.get("role",""))+" HP%d/%d MP%d/%d" % [u.hp,u.max,u.mp,u.maxMp]);chooser.set_item_metadata(chooser.item_count-1,u.id)
				if u.id==pages.party_uid:chooser.select(chooser.item_count-1)
			chooser.item_selected.connect(func(i):pages.select_party(str(chooser.get_item_metadata(i))))
	var detail=VBoxContainer.new();detail.name="PartyDetail";detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail.size_flags_vertical=Control.SIZE_EXPAND_FILL;split.add_child(detail)
	var member={}
	for u in members:
		if u.id==pages.party_uid:member=u;break
	if member.is_empty():return
	var hero=ui.row(detail);ui.portrait(hero,member,false,56)
	identity(hero,member)
	var name=l(hero,str(member.name)+" / "+str(member.get("role",""))+" / Lv.%d\nHP %d/%d  MP %d/%d" % [member.get("level",1),member.hp,member.max,member.mp,member.maxMp]);ui.emphasize_low_hp(name,member)
	if pages.shop_view.return_from_party:b(hero,"商店へ戻る",func():pages.shop_view.return_from_party=false;ui.page="shop";pages.shop_view.back_list())
	var tabs=ui.row(detail)
	for i in range(3):
		var button=b(tabs,("● " if tab==i else "")+["装備","能力・成長","スキル・効果"][i],func():tab=i;ui.render());button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;ui.memory.key(button,"party_tab_"+str(i))
	var body=ui.scroller(detail);body.get_parent().name="PartyDetailScroll";ui.memory.watch(body.get_parent(),"party_"+pages.party_uid+"_"+str(tab))
	match tab:
		0:equipment(body,member)
		1:growth(body,member)
		2:skills(body,member)
	if tab==0:
		var where="east" if highlight_slot in ["rightHand","leftHand"] else "north" if highlight_slot in ["accessory1","accessory2"] else "west" if not highlight_slot.is_empty() else ""
		if where==c.location and ids.has(member.id):
			ui.primary(b(detail,"選択枠の装備をこの町で買い替える",go_shop.bind(str(member.id),highlight_slot)))
		else:l(detail,"手装備はイース、防具はウエス、装飾品はノースで買い替えます。" if where!=c.location else "編成中の仲間が購入対象です。")
func equipment(parent,u: Dictionary):
	var grid=GridContainer.new();grid.name="EquipmentSlots";grid.columns=2;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);parent.add_child(grid)
	for e in u.get("equipmentSlots",[]):
		var title=("● " if highlight_slot==e.slot else "")+str(e.label)+"\n"+("右手の両手武器で使用中" if e.get("occupiedBy")!=null else equipment_name(e))
		var btn=b(grid,title,open_equipment.bind(u,e));btn.custom_minimum_size.y=56;btn.size_flags_horizontal=Control.SIZE_EXPAND_FILL;btn.clip_text=true;ui.memory.key(btn,"equipment_"+str(e.slot))
		btn.set_script(preload("res://equipment_tooltip.gd"))
		var item: Dictionary=u.get("equipmentDetails",{}).get(e.slot,{})
		var descriptions={};var effective_levels={}
		for field in ["skill","effect"]:
			if item.get(field)==null:continue
			var id=str(item[field]);var level=int(item.get("skillLevel",1));effective_levels[id]=level
			for source in u.get("stats",{}).get("skillSources",[]):
				if source.id==id:effective_levels[id]=maxi(effective_levels[id],int(source.get("level",1)))
			descriptions[id]=pages.skill_description(id,effective_levels[id] if id=="scout" else level)
		btn.configure(equipment_name(e),item,{"names":pages.c().get("skillNames",{}),"definitions":pages.c().get("skillDefinitions",{}),"descriptions":descriptions,"effective_levels":effective_levels,"occupied":e.get("occupiedBy")!=null,"job":u.get("job"),"title_size":24 if ui.size.x>=1800 else 20,"detail_size":18 if ui.size.x>=1800 else 16})
		ui.icons.apply(btn,ui.icons.slot(str(e.slot)))
func equipment_name(e: Dictionary) -> String:
	return str(e.get("name","なし")).trim_prefix(str(e.label)+":").trim_prefix(str(e.label)+"：").strip_edges()
func open_equipment(u: Dictionary,e: Dictionary):
	if not ui.can_inspect_member(str(u.id)):return
	if not detail_uid.is_empty():detail_gear=u.get("equipmentDetails",{}).get(e.slot,{});owned_equipment_view.slot=str(e.slot);refresh_modal();return
	if not guard_leave(open_equipment.bind(u,e)):return
	highlight_slot=e.slot;ui.render()
	ui.dialog.open(str(e.label)+" / "+equipment_name(e),func(body,actions):
		if e.get("occupiedBy")!=null:l(body,"右手の両手武器で使用中。別の2個目を持っているわけではありません。")
		var item=u.get("equipmentDetails",{}).get(e.slot,{})
		pages.describe_gear(body,item)
		ui.local_button(body,"ステータスで所持品・装備を操作",func():ui.dialog.close();open_detail(str(u.id)))
		ui.local_button(actions,"装備一覧へ",ui.dialog.close))
func growth(parent,u: Dictionary):
	if not detail_uid.is_empty() and str(u.id)!=detail_uid:l(parent,"人物ステータスを別画面で編集中です。");return
	ensure_draft(u)
	var stats=u.get("stats",u)
	var remaining=int(u.get("statPoints",0))-draft_total();var editable=pages.c().get("phase")=="town" and ui.active_member(str(u.id)) and not committing
	var points=ui.row(parent)
	var info=ui.icons.apply(b(points,"ポイント説明",point_help),"attribute_points");info.name="AttributePointHelp"
	var count=l(points,"割り振り可能な残ポイント：%d" % remaining,true);count.name="AllocationRemaining"
	for stat in ["str","int","agi"]:
		var row=ui.row(parent);ui.icons.add(row,{"str":"strength","int":"intelligence","agi":"speed"}[stat],24)
		var value=l(row,"%s  %d → %d（＋%d）" % [stat.to_upper(),stats.get(stat,0),stats.get(stat,0)+draft[stat],draft[stat]])
		value.size_flags_horizontal=Control.SIZE_FILL;value.custom_minimum_size.x=260
		ui.memory.key(b(row,"＋1",change_draft.bind(u,stat,1),not editable or remaining<=0),"allocate_"+stat)
		ui.memory.key(b(row,"−1",change_draft.bind(u,stat,-1),not editable or draft[stat]<=0),"allocate_minus_"+stat)
	var confirm=b(parent,"確定",confirm_allocation.bind(u),not editable or draft_total()==0);confirm.name="AllocationConfirm";confirm.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;confirm.custom_minimum_size.x=180;ui.memory.key(confirm,"allocation_confirm")
	if draft_total()>0:tint(confirm,Color("#236044"))
	if not editable:l(parent,"控えは編成してから操作できます。" if not ui.active_member(str(u.id)) else "成長の配分は町にいる時だけ編集できます。" if pages.c().get("phase")!="town" else "確定結果を確認しています。")
	l(parent,pages.stats_text(stats));l(parent,"SPD（行動速度）はAGIと装備補正から算出します。")
	l(parent,"編成はアスタリスのギルドで変更できます。")
func skills(parent,u: Dictionary):
	var s=u.get("stats",u);var names=pages.c().get("skillNames",{})
	l(parent,"使用可能: "+" / ".join(u.get("activeSkillNames",[])));l(parent,"効果: "+" / ".join(u.get("effectNames",[])))
	var groups={}
	for source in s.get("skillSources",[]):
		if not groups.has(source.id):groups[source.id]=[]
		groups[source.id].append(source)
	for id in groups:
		ui.icons.line(ui,parent,ui.icons.skill(str(id)),str(names.get(id,id)),true)
		var level=1
		for source in groups[id]:level=maxi(level,int(source.get("level",1)))
		l(parent,pages.skill_description(str(id),level))
		for source in groups[id]:
			l(parent,"由来: "+str(pages.c().slots.get(source.slot,source.slot))+" / "+str(u.get("equipmentDetails",{}).get(source.slot,{}).get("name",source.itemId)))
			if id=="scout":l(parent,"装備の奇襲Lv%d / 使用する奇襲Lv%d" % [source.get("level",1),level])
	if u.get("job")=="porter":l(parent,"ポーターは武器交換後も攻撃・攻撃スキルを使用できません。陣形強化は既存条件に従います。")

func identity(parent,u: Dictionary):
	var r=ui.row(parent)
	var race=str(u.get("race",""));var job=str(u.get("job",""))
	if not race.is_empty():ui.icons.add(r,ui.icons.race(race),24)
	ui.icons.add(r,ui.icons.job(job),24)
	var label=l(r,{"human":"人間","elf":"エルフ","dwarf":"ドワーフ"}.get(race,"種族未取得")+" / "+str(u.get("role",job)))
	label.autowrap_mode=TextServer.AUTOWRAP_OFF
func draft_total() -> int:return int(draft.str)+int(draft.int)+int(draft.agi)
func clear_draft():draft={"str":0,"int":0,"agi":0};draft_uid="";draft_token=""
func reset():clear_draft();detail_uid="";detail_gear={};committing=false;leave_pending=false;inventory_view.reset();owned_equipment_view.reset()
func ensure_draft(u: Dictionary):
	if draft_uid!=str(u.id) or draft_token!=str(u.get("allocationToken","")):
		clear_draft();draft_uid=str(u.id);draft_token=str(u.get("allocationToken",""))
func change_draft(u: Dictionary,stat: String,amount: int):
	if ui.locked or committing or pages.c().get("phase")!="town" or not ui.active_member(str(u.id)):return
	ensure_draft(u)
	if amount>0 and draft_total()>=int(u.get("statPoints",0)) or amount<0 and int(draft[stat])<=0:return
	draft[stat]+=amount;redraw_details()
func redraw_details():
	if detail_uid.is_empty():ui.render()
	else:refresh_modal()
func point_help():
	var dialog=ui.confirm("レベルアップで獲得し、STR・INT・AGIに配分できる未使用ポイントです。\n確定前の＋／−だけを調整できます。",func():pass)
	dialog.ok_button_text="閉じる";dialog.get_cancel_button().hide();dialog.get_ok_button().grab_focus()
func confirm_allocation(u: Dictionary):
	if ui.locked or committing or draft_total()<=0 or pages.c().get("phase")!="town" or not ui.active_member(str(u.id)):return
	var delta=draft.duplicate(true);var token=draft_token;var uid=str(u.id)
	var text="ステータスポイントの割り振りを確定しますか？\n%s\nSTR＋%d / INT＋%d / AGI＋%d\n使用 %d点 / 確定後の残り %d点" % [u.name,delta.str,delta.int,delta.agi,draft_total(),int(u.statPoints)-draft_total()]
	var dialog=ui.confirm(text,submit_allocation.bind(uid,delta,token));dialog.name="AllocationConfirmation";dialog.ok_button_text="YES";dialog.cancel_button_text="NO";dialog.get_cancel_button().grab_focus()
func submit_allocation(uid: String,delta: Dictionary,token: String):
	if committing or ui.locked or uid!=draft_uid or token!=draft_token or not ui.active_member(uid):return
	committing=true
	var reply=await ui.act("allocateBatch",[uid,delta,token])
	committing=false
	if reply is Dictionary and reply.get("ok",false):clear_draft()
	redraw_details()
func guard_leave(next: Callable) -> bool:
	if committing or ui.locked:return false
	if draft_total()==0:return true
	if leave_pending:return false
	leave_pending=true
	var dialog=ui.confirm("未確定の配分があります。破棄して戻りますか？",func():leave_pending=false;clear_draft();next.call())
	dialog.name="DiscardAllocation";dialog.ok_button_text="破棄して戻る";dialog.cancel_button_text="編集を続ける"
	dialog.canceled.connect(func():leave_pending=false)
	return false
func go_shop(uid: String,slot: String):
	if not ui.active_member(uid):return
	if not guard_leave(go_shop.bind(uid,slot)):return
	ui.shop_uid=uid;ui.shop_slot=slot;ui.page="shop";pages.gear_id="";pages.shop_view.from_party=true;pages.shop_view.back_list()
func face_bar(parent):
	var row=ui.row(parent);row.name="PartyFaceBar";row.custom_minimum_size.y=96 if ui.ui_size_mode=="standard" else 64
	# Item target cards own HP/MP; the persistent portraits remain detail entry points.
	var show_resources=parent.find_child("CampParty",true,false)==null and parent.find_child("ItemParty",true,false)==null
	for id in pages.c().get("selected",[]):
		var u=ui.roster().filter(func(member):return member.id==id)[0]
		var caption=str(u.name)+(" 戦闘不能" if u.hp<=0 else "")
		if show_resources:caption+="\nHP%d/%d MP%d/%d" % [u.hp,u.max,u.mp,u.maxMp]
		var control=b(row,"",portrait_pressed.bind(str(id)),(ui.modal_open() and detail_uid.is_empty()) or (pages.guild_view.available() and pages.guild_view.busy()) or pages.shop_view.stage in ["S4","S5"] or pages.shop_view.unknown)
		if str(id)==detail_uid:tint(control,Color("#243c58"))
		elif pages.guild_view.available() and str(id)==pages.guild_view.chosen_id:tint(control,Color("#236044"))
		control.name="PartyFace_"+str(id);control.size_flags_horizontal=Control.SIZE_EXPAND_FILL;control.icon=ui.portraits.texture(u,true);control.expand_icon=true;control.add_theme_constant_override("icon_max_width",48 if ui.ui_size_mode=="standard" else 28);control.clip_text=true;control.tooltip_text=caption+" / ステータスを開く";ui.memory.key(control,"face_"+str(id))
func open_detail(uid: String):
	if ui.locked or ui.presenting or ui.modal_open() or not ui.can_inspect_member(uid):return
	if not guard_leave(open_detail.bind(uid)):return
	detail_uid=uid;detail_tab=0;detail_gear={};inventory_view.reset();owned_equipment_view.reset()
	ui.dialog.open(ui.dialog.STATUS_TITLE,func(_body,actions):
		ui.local_button(actions,"戻る",detail_back).name="StatusBack",
		func():detail_uid="";detail_gear={};inventory_view.reset();ui.render())
	ui.dialog.close_guard=detail_close_guard
	ui.dialog.escape_handler=detail_escape
	ui.render()
func open_inventory(uid: String):
	open_detail(uid)
func detail_close_guard(next: Callable) -> bool:
	if ui.locked or ui.presenting or inventory_view.stage=="pending":return false
	return guard_leave(next)
func detail_escape() -> bool:
	if inventory_view.stage=="confirm":inventory_view.cancel_confirmation();return true
	return false
func detail_back():
	inventory_view.back()
func refresh_modal():
	if detail_uid.is_empty() or modal_refreshing or not is_instance_valid(ui.dialog.window):return
	if ui.dialog.window.title!=ui.dialog.STATUS_TITLE:return
	modal_refreshing=true
	var matches=ui.visible_roster().filter(func(u):return u.id==detail_uid)
	if matches.is_empty():
		clear_draft();detail_uid="";detail_gear={};inventory_view.reset();modal_refreshing=false;ui.dialog.close(false);return
	var u=matches[0];var body=ui.dialog.body
	var scroll=body.get_parent();var old_scroll=scroll.scroll_vertical
	ui.clear(body)
	var hero=ui.row(body);var face=ui.portrait(hero,u,false,88);face.set_script(preload("res://portrait_hover_hint.gd"));face.name="StatusPortrait";face.tooltip_text="クリックで画像変更";face.mouse_filter=Control.MOUSE_FILTER_STOP;face.configure_hint()
	face.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:face.hide_hint();open_portrait_preview(u))
	l(hero,str(u.name)+" / Lv.%d / 経験値 %d\nHP%d/%d  MP%d/%d" % [u.level,u.get("xp",0),u.hp,u.max,u.mp,u.maxMp],true);identity(body,u)
	# The left tabs select character detail; the right column is always inventory.
	if inventory_view.owner_id!=detail_uid:inventory_view.reset();inventory_view.owner_id=detail_uid
	var split=GridContainer.new();split.columns=2;split.name="StatusEquipmentSplit";split.add_theme_constant_override("h_separation",16);body.add_child(split)
	var left_tabs=ui.row(split);left_tabs.name="StatusLeftTabs";left_tabs.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var right_header=VBoxContainer.new();right_header.name="StatusInventoryHeading";right_header.size_flags_horizontal=Control.SIZE_EXPAND_FILL;split.add_child(right_header)
	owned_equipment_view.render_header(right_header,u)
	for i in range(3):
		var tab_button=b(left_tabs,("● " if detail_tab==i else "")+["装備","能力・成長","スキル・効果"][i],func():detail_tab=i;detail_gear={};refresh_modal())
		tab_button.name="StatusTab_"+str(i);tab_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var equipped=VBoxContainer.new();equipped.name="StatusEquipped";equipped.size_flags_horizontal=Control.SIZE_EXPAND_FILL;split.add_child(equipped)
	var owned=VBoxContainer.new();owned.name="StatusOwnedInventory";owned.size_flags_horizontal=Control.SIZE_EXPAND_FILL;split.add_child(owned)
	match detail_tab:
		0:
			equipment(equipped,u)
			for e in u.get("equipmentSlots",[]):
				if e.slot==owned_equipment_view.slot and e.get("occupiedBy")==null and e.get("id","")!="" and u.get("equipmentDetails",{}).get(e.slot,{}).get("type")=="empty":continue
				if e.slot==owned_equipment_view.slot and e.get("occupiedBy")==null and u.get("equipmentDetails",{}).get(e.slot,{}).get("type")!="empty":
					var row=ui.row(equipped)
					var remove=b(row,"装備を外す",inventory_view.prepare_unequip.bind(detail_uid,str(e.id),str(e.slot)),pages.c().get("phase") not in ["town","camp"] or not pages.c().get("selected",[]).has(detail_uid));remove.name="UnequipSelected";remove.custom_minimum_size=Vector2(160,40)
					l(row,str(e.label))
		1:growth(equipped,u)
		2:skills(equipped,u)
	owned_equipment_view.render(owned,u)
	if inventory_view.stage!="list" or not inventory_view.message.is_empty():
		var actions=VBoxContainer.new();actions.name="StatusInventoryActions";owned.add_child(actions)
		inventory_view.render(actions,detail_uid)
	if not ui.notice.is_empty():l(body,ui.notice)
	var back_button=ui.dialog.actions.get_node("StatusBack")
	back_button.visible=inventory_view.stage!="list"
	back_button.disabled=not inventory_view.available() or inventory_view.stage=="list"
	scroll.set_deferred("scroll_vertical",old_scroll);modal_refreshing=false

func tint(control: Button,color: Color):
	for state_ in ["normal","hover","pressed"]:
		var style=control.get_theme_stylebox(state_).duplicate() as StyleBoxFlat
		style.bg_color=color.lightened(.12) if state_=="hover" else color
		control.add_theme_stylebox_override(state_,style)
func portrait_pressed(uid: String):
	if detail_uid.is_empty():open_detail(uid);return
	if uid==detail_uid or ui.locked or ui.presenting or committing or leave_pending or inventory_view.stage in ["pending","unknown","confirm"]:return
	if not ui.can_inspect_member(uid) or not guard_leave(portrait_pressed.bind(uid)):return
	detail_uid=uid;detail_gear={};inventory_view.reset();owned_equipment_view.reset();clear_draft();ui.render();ui.dialog.window.grab_focus()
func outside_press(point: Vector2) -> bool:
	if detail_uid.is_empty() or not is_instance_valid(ui.dialog.window) or ui.dialog.window.title!=ui.dialog.STATUS_TITLE:return false
	var window=ui.dialog.window
	var rect=Rect2(Vector2(window.position)-Vector2(0,32),Vector2(window.size)+Vector2(0,32))
	if rect.has_point(point):return false
	# Child confirmations and other popups retain their exclusive input/consent.
	for child in ui.find_children("*","Window",true,false):
		if child!=window and child.visible and child.exclusive:return true
	for id in pages.c().get("selected",[]):
		var face=ui.find_child("PartyFace_"+str(id),true,false)
		if face!=null and face.is_visible_in_tree() and face.get_global_rect().has_point(point):portrait_pressed(str(id));return true
	ui.dialog.close();return true

func open_portrait_preview(u: Dictionary):
	if not is_instance_valid(ui.dialog.window):return
	var window=Window.new();window.name="StatusPortraitPreview";window.title=str(u.name)+"の画像";window.exclusive=true;ui.dialog.window.add_child(window)
	var box=VBoxContainer.new();window.add_child(box);box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var picture=ui.portrait(box,u,false,160);picture.name="StatusFullPortrait";picture.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var change=b(box,"画像変更",func():
		window.hide();window.queue_free()
		ui.file_dialog(FileDialog.FILE_MODE_OPEN_FILE,PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp,*.bmp,*.gif ; キャラ画像"]),ui.import_portrait.bind(str(u.id))),not ui.active_member(str(u.id)))
	change.name="StatusChangePortrait"
	if not ui.active_member(str(u.id)):change.tooltip_text="画像変更は編成中のキャラが対象です"
	ui.local_button(box,"閉じる",window.queue_free)
	window.close_requested.connect(window.queue_free)
	window.window_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:window.set_input_as_handled();window.queue_free())
	ui.preferences.bind_window(window,"portrait_preview",ui.size,Vector2(420,320),Vector2(320,300));window.popup()
