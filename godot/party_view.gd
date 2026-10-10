extends RefCounted
var owner_ref: WeakRef
var pages:
	get:return owner_ref.get_ref()
var ui
var tab := 0
var highlight_slot := ""
func _init(owner):owner_ref=weakref(owner);ui=owner.ui
func l(parent,text,large:=false):return ui.label_(parent,str(text),large)
func b(parent,text,fn,disabled:=false):return ui.button(parent,text,fn,disabled)
func render(parent):
	var c=pages.c();var members=ui.roster();var ids=c.get("selected",[])
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
		for group in [["編成 %d/5" % ids.size(),active],["控え %d人" % reserves.size(),reserves]]:
			l(body,group[0],true)
			for u in group[1]:
				var r=ui.row(body);r.set_meta("member_id",u.id);r.set_meta("active_member",ids.has(u.id));ui.portrait(r,u,true,40)
				var chooser=b(r,("● " if u.id==pages.party_uid else "")+str(u.name)+" / "+str(u.get("role",""))+"\nHP%d/%d MP%d/%d" % [u.hp,u.max,u.mp,u.maxMp],pages.select_party.bind(str(u.id)))
				chooser.custom_minimum_size.y=56;chooser.clip_text=true;chooser.size_flags_horizontal=Control.SIZE_EXPAND_FILL;chooser.tooltip_text=chooser.text;ui.memory.key(chooser,"party_"+str(u.id));ui.memory.item(r,str(u.id))
	else:
		l(split,"編成 %d/5" % ids.size())
		var lineup=ui.row(split);lineup.name="PartyActiveLineup"
		for u in active:
			var chooser=b(lineup,"",pages.select_party.bind(str(u.id)));chooser.custom_minimum_size.y=128;chooser.size_flags_horizontal=Control.SIZE_EXPAND_FILL;chooser.set_meta("member_id",u.id);ui.memory.key(chooser,"party_"+str(u.id))
			var card=VBoxContainer.new();chooser.add_child(card);card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);card.offset_top=4;card.offset_bottom=-4;card.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_theme_constant_override("separation",0)
			var face=ui.portrait(card,u,true,28);face.mouse_filter=Control.MOUSE_FILTER_IGNORE
			var caption=l(card,("● " if u.id==pages.party_uid else "")+str(u.name)+"\n"+str(u.get("role",""))+"\nHP%d/%d\nMP%d/%d" % [u.hp,u.max,u.mp,u.maxMp]);caption.add_theme_font_size_override("font_size",16);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.autowrap_mode=TextServer.AUTOWRAP_OFF;caption.clip_text=true;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;chooser.tooltip_text=caption.text
			card.minimum_size_changed.connect(func():
				if is_instance_valid(chooser):chooser.custom_minimum_size.y=maxf(112,card.get_minimum_size().y+8))
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
		var where="east" if highlight_slot in ["rightHand","leftHand"] else "west" if not highlight_slot.is_empty() else ""
		if where==c.location and ids.has(member.id):
			ui.primary(b(detail,"選択枠の装備をこの町で買い替える",func():ui.shop_uid=member.id;ui.shop_slot=highlight_slot;ui.page="shop";pages.gear_id="";pages.shop_view.from_party=true;pages.shop_view.back_list()))
		else:l(detail,"手装備はイース、防具・装飾はウエスで買い替えます。" if where!=c.location else "編成中の仲間が購入対象です。")
func equipment(parent,u: Dictionary):
	var grid=GridContainer.new();grid.name="EquipmentSlots";grid.columns=2;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);parent.add_child(grid)
	for e in u.get("equipmentSlots",[]):
		var title=("● " if highlight_slot==e.slot else "")+str(e.label)+"\n"+("右手の両手武器で使用中" if e.get("occupiedBy")!=null else equipment_name(e))
		var btn=b(grid,title,open_equipment.bind(u,e));btn.custom_minimum_size.y=56;btn.size_flags_horizontal=Control.SIZE_EXPAND_FILL;btn.clip_text=true;btn.tooltip_text=title;ui.memory.key(btn,"equipment_"+str(e.slot))
func equipment_name(e: Dictionary) -> String:
	return str(e.get("name","なし")).trim_prefix(str(e.label)+":").trim_prefix(str(e.label)+"：").strip_edges()
func open_equipment(u: Dictionary,e: Dictionary):
	highlight_slot=e.slot;ui.render()
	ui.dialog.open(str(e.label)+" / "+equipment_name(e),func(body,actions):
		if e.get("occupiedBy")!=null:l(body,"右手の両手武器で使用中。別の2個目を持っているわけではありません。")
		var item=u.get("equipmentDetails",{}).get(e.slot,{})
		pages.describe_gear(body,item)
		l(body,"閲覧専用です。所持品への取り外し・自由な付け替えはありません。")
		ui.local_button(actions,"装備一覧へ",ui.dialog.close))
func growth(parent,u: Dictionary):
	var stats=u.get("stats",u)
	l(parent,"STR %d / INT %d / AGI %d" % [stats.get("str",0),stats.get("int",0),stats.get("agi",0)]);l(parent,pages.stats_text(stats))
	l(parent,"能力ポイント %d / スキルポイント %d（スキル配分は未実装）" % [u.get("statPoints",0),u.get("skillPoints",0)])
	var row=ui.row(parent)
	for stat in ["str","int","agi"]:ui.memory.key(b(row,stat.to_upper()+"+1",ui.act.bind("allocate",[u.id,stat,1]),pages.c().get("phase")!="town" or u.get("statPoints",0)<=0),"allocate_"+stat)
	var ids=pages.c().get("selected",[]);var active=ids.has(u.id);var guild=pages.c().get("guildAvailable",false)
	ui.memory.key(b(parent,"編成から外す" if active else "編成に加える",pages.change_membership.bind(u.id),not guild or not active and ids.size()>=5 or active and u.get("job")=="porter"),"party_membership")
	l(parent,"ギルドで編成 / 雇用無料・最大5人 / 出発にはポーター必須。人物の装備・HP/MP・成長を保持します。")
func skills(parent,u: Dictionary):
	var s=u.get("stats",u);var names=pages.c().get("skillNames",{})
	l(parent,"使用可能: "+" / ".join(u.get("activeSkillNames",[])));l(parent,"効果: "+" / ".join(u.get("effectNames",[])))
	for source in s.get("skillSources",[]):
		l(parent,str(names.get(source.id,source.id))+" / "+str(pages.c().slots.get(source.slot,source.slot))+" / "+str(u.get("equipmentDetails",{}).get(source.slot,{}).get("name",source.itemId)),true)
		l(parent,pages.skill_description(str(source.id),int(pages.c().get("level",1))))
		l(parent,str(u.get("equipmentDetails",{}).get(source.slot,{}).get("note","")))
	if u.get("job")=="porter":l(parent,"ポーターは武器交換後も攻撃・攻撃スキルを使用できません。陣形強化は既存条件に従います。")
