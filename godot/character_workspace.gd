extends RefCounted
## Full-page character inspection; no inventory copy is kept in UI state.
var ui
var tab="equipment"
var picked: Dictionary={}
var owner=""
var busy=false
var allocating=false
var equip_slot=""
var preview_generation=0
var inventory_filter="all"
const Drag=preload("res://item_drag.gd")
func _init(frontend):ui=frontend
func render(parent):
	preview_generation+=1
	var members=ui.roster().filter(func(u):return ui.campaign().get("selected",[]).has(u.id))
	if members.is_empty():return
	if not members.any(func(u):return str(u.id)==ui.pages.party_uid):ui.pages.party_uid=str(ui.campaign().get("selected",[])[0])
	var member=members.filter(func(u):return str(u.id)==ui.pages.party_uid)[0]
	if owner!=str(member.id):owner=str(member.id);picked={};allocating=false
	var tabs=ui.row(parent)
	for spec in [["equipment","装備"],["inventory","インベントリ"],["ability","能力"],["skills","スキル"]]:
		var control=ui.button(tabs,spec[1],set_tab.bind(str(spec[0])));control.custom_minimum_size.x=140;ui.mark_selected(control,tab==spec[0])
	var split=ui.row(parent);split.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;split.add_theme_constant_override("separation",16)
	var display=ui.card(split);display.get_parent().custom_minimum_size=Vector2(320,536);display.get_parent().size_flags_horizontal=Control.SIZE_FILL if tab in ["equipment","inventory"] else Control.SIZE_EXPAND_FILL
	if tab=="equipment":equipment(display,member)
	elif tab=="inventory":inventory(display,member)
	elif tab=="ability":
		ui.label_(display,str(member.name)+" / Lv."+str(int(member.level)),true)
		ability(display,member)
	else:skills(display,member)
	if tab in ["equipment","inventory"]:
		var card=ui.card(split);card.get_parent().custom_minimum_size=Vector2(420,536);card.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
		ui.label_(card,"選択アイテム")
		var detail=ui.scroller(card)
		if picked.is_empty():return
		ui.pages.describe_gear(detail,picked)
		if picked.has("equipped_slot"):
			if picked.get("type")!="empty" and not picked.get("occupied",false):ui.button(detail,"装備を外す",perform.bind(owner,str(picked.id),"unequip",null,1,picked.equipped_slot),busy)
		else:
			if picked.get("kind")=="equipment":
				var options=picked.get("equipSlots",[])
				if not options.is_empty():
					if not options.any(func(q):return q.slot==equip_slot):equip_slot=str(options[0].slot)
					var actions=ui.row(detail);var selector=OptionButton.new();selector.name="CharacterEquipSlot";actions.add_child(selector)
					for option in options:
						selector.add_item(str(ui.campaign().get("slots",{}).get(option.slot,option.slot)));selector.set_item_metadata(selector.item_count-1,str(option.slot))
						if option.slot==equip_slot:selector.select(selector.item_count-1)
					selector.disabled=busy;selector.item_selected.connect(func(i):equip_slot=str(selector.get_item_metadata(i));ui.render())
					var chosen=options.filter(func(q):return q.slot==equip_slot)[0]
					var equip=ui.button(actions,"装備する",perform.bind(owner,str(picked.id),"equip",null,1,equip_slot),true);equip.name="CharacterEquip";equip.tooltip_text=str(chosen.get("reason",""))
					preview(detail,member,picked,equip)
			else:
				for option in picked.get("useTargets",[]):
					var control=ui.button(detail,str(option.targetName)+"に使う",perform.bind(owner,str(picked.id),"use",option.targetId,1,null),busy or not option.ok);control.tooltip_text=str(option.get("reason",""))
			var discard=picked.get("discard",{})
			var remove=ui.button(detail,"捨てる",confirm_discard.bind(owner,picked.duplicate(true)),busy or not discard.get("ok",false));remove.name="CharacterDiscard";remove.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;remove.tooltip_text=str(discard.get("reason",""))

func equipment(parent,member):
	ui.label_(parent,"装備")
	var stage=Control.new();stage.custom_minimum_size=Vector2(296,470);stage.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(stage)
	var art=ui.portrait(stage,member,false,1);art.position=Vector2(20,8);art.size=Vector2(260,470);art.modulate.a=.22;art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var positions={"head":Vector2(108,0),"rightHand":Vector2(12,92),"upperBody":Vector2(108,92),"leftHand":Vector2(204,92),"lowerBody":Vector2(108,188),"feet":Vector2(108,284),"accessory1":Vector2(60,380),"accessory2":Vector2(156,380)}
	for slot in member.get("equipmentSlots",[]):
		var item=member.get("equipmentDetails",{}).get(slot.slot,{}).duplicate(true);item["equipped_slot"]=slot.slot;item["occupied"]=slot.get("occupiedBy")!=null;item["id"]=slot.get("id","");item["name"]=ui.pages.party_view.equipment_name(slot)
		var button=ui.button(stage,"",func():picked=item;ui.render());button.name="CharacterSlot_"+str(slot.slot);button.position=positions.get(slot.slot,Vector2.ZERO);button.custom_minimum_size=Vector2(72,72);button.size=Vector2(72,72);button.tooltip_text=str(slot.label)+" / "+str(item.name)
		button.icon=ui.icons.texture(ui.icons.equipment(item));button.expand_icon=true;button.add_theme_constant_override("icon_max_width",52)
		var caption=ui.label_(stage,str(slot.label));caption.position=button.position+Vector2(0,74);caption.size=Vector2(90,12);caption.autowrap_mode=TextServer.AUTOWRAP_OFF;caption.add_theme_font_size_override("font_size",11)
		if item.get("type")!="empty" and slot.get("occupiedBy")==null:Drag.source(button,func():return payload(item,"transferEquipped",str(slot.slot)),str(item.name),button.icon)
func inventory(parent,member):
	ui.label_(parent,"インベントリ",true)
	var filter=OptionButton.new();filter.name="CharacterInventoryFilter";parent.add_child(filter)
	var filters=[["all","すべて"],["items","消耗品・荷物"]]
	for slot in member.get("equipmentSlots",[]):filters.append([str(slot.slot),str(slot.label)])
	for choice in filters:
		filter.add_item(choice[1]);filter.set_item_metadata(filter.item_count-1,choice[0])
		if choice[0]==inventory_filter:filter.select(filter.item_count-1)
	filter.item_selected.connect(func(i):inventory_filter=str(filter.get_item_metadata(i));picked={};ui.render())
	var list=ui.scroller(parent)
	var entries=ui.campaign().get("inventoryByCharacter",{}).get(str(member.id),{}).get("entries",[]).filter(func(e):return inventory_filter=="all" or (inventory_filter=="items" and e.kind!="equipment") or e.get("equipSlots",[]).any(func(q):return q.slot==inventory_filter))

	if entries.is_empty():ui.label_(list,"アイテムはありません")
	for entry in entries:
		var button=ui.button(list,str(entry.name)+"  ×"+str(int(entry.count)),func():picked=entry;ui.render());button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.custom_minimum_size.y=60
		button.icon=ui.icons.texture(ui.icons.equipment(entry)) if entry.kind=="equipment" else ui.icons.texture(str(entry.id) if entry.kind!="quest" else "items");button.expand_icon=true;button.add_theme_constant_override("icon_max_width",40)
		Drag.source(button,func():return payload(entry,"transfer",null),str(entry.name),button.icon)
func payload(item,action,slot) -> Dictionary:
	var allowed=[]
	for uid in ui.campaign().get("selected",[]):
		if str(uid)==owner:continue
		var inventory=ui.campaign().get("inventoryByCharacter",{}).get(uid,{})
		var capacity=inventory.get("capacity",{})
		if capacity.get("limit")==null or int(capacity.get("used",0))<int(capacity.get("limit",0)) or inventory.get("entries",[]).any(func(e):return e.id==item.id):allowed.append(str(uid))
	return {"allowed":allowed,"kind":"character_transfer","owner":owner,"item":str(item.id),"action":action,"slot":slot,"count":int(item.get("count",1)),"token":ui.campaign().get("inventoryToken"),"epoch":ui.pages.epoch}
func drop(data,target):
	if busy or data.get("token")!=ui.campaign().get("inventoryToken") or data.get("epoch")!=ui.pages.epoch:return
	if int(data.count)>1:
		ui.dialog.open("個数",func(body,actions):
			var count=SpinBox.new();count.min_value=1;count.max_value=int(data.count);count.value=int(data.count);body.add_child(count)
			ui.local_button(actions,"OK",func():var amount=int(count.value);ui.dialog.close();commit_drop(data,target,amount))
			ui.local_button(actions,"キャンセル",ui.dialog.close))
	else:commit_drop(data,target,1)
func commit_drop(data,target,count):
	if data.get("token")!=ui.campaign().get("inventoryToken") or data.get("epoch")!=ui.pages.epoch:toast("状態が変わりました。もう一度選んでください");return
	perform(data.owner,data.item,data.action,target,count,data.slot)
func perform(uid,item,action,target,count,slot):
	if busy or ui.locked or ui.presenting:return
	busy=true
	var token=ui.campaign().get("inventoryToken");var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation
	var response=await ui.engine.request({"op":"campaign","action":"inventoryQuote","args":[uid,item,action,target,count,slot]})
	var quote=response.get("inventoryQuote",{})
	if not quote.get("ok",false):busy=false;toast(str(quote.get("reason","操作できません")));return
	if token!=ui.campaign().get("inventoryToken") or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation:busy=false;return
	var result=await ui.update({"op":"campaign","action":"inventoryAction","args":[uid,item,action,target,count,slot,quote.token]})
	busy=false
	if result.get("ok",false):picked={};toast(str(quote.name)+" ×"+str(count)+(" → "+ui.member_name(str(target)) if target!=null else "：更新しました"))
	else:toast(str(result.get("error","操作できません")))
	ui.render()
func toast(text):
	var panel=PanelContainer.new();panel.name="InventoryToast";panel.add_theme_stylebox_override("panel",ui.mock_shell.style());ui.add_child(panel);panel.z_index=90
	var label=ui.label_(panel,text);label.custom_minimum_size=Vector2(400,40);panel.position=Vector2(ui.size.x-460,ui.size.y-100)
	ui.get_tree().create_timer(3).timeout.connect(panel.queue_free)
func preview(parent,member,item,equip):
	var chosen=equip_slot;var ticket=preview_generation;var token=ui.campaign().get("inventoryToken");var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation
	var text=RichTextLabel.new();text.name="CharacterEquipmentComparison";text.bbcode_enabled=true;text.add_theme_color_override("default_color",Color("#29332f"));text.fit_content=true;text.custom_minimum_size.y=110;parent.add_child(text)
	text.text="比較を確認中…"
	while ui.engine.busy:
		await ui.get_tree().process_frame
		if not is_instance_valid(text) or ticket!=preview_generation:return
	if ticket!=preview_generation:return
	var result=await ui.engine.request({"op":"campaign","action":"previewGear","args":[member.id,item.id,chosen]})
	if not is_instance_valid(text) or not text.is_inside_tree() or ticket!=preview_generation or token!=ui.campaign().get("inventoryToken") or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation:return
	var quote=result.get("previewGear",{})
	if quote is Dictionary and quote.has("before"):
		# Keep skills visual; comparison heading identifies the exact selected slot.
		text.text=ui.pages.party_view.owned_equipment_view.comparison(member,item,chosen,quote,true).replace("#8ee6ab","#247044").replace("#ffb1a6","#b04430").replace("#d5dbe2","#707970")
		text.text="比較対象："+str(ui.campaign().get("slots",{}).get(chosen,chosen))+"\n"+text.text
		render_comparison_skills(parent,quote)
		equip.disabled=busy or not item.get("equipSlots",[]).any(func(q):return q.slot==chosen and q.ok);equip.set_meta("base_disabled",equip.disabled)
	else:text.text="比較を取得できません。選び直してください。"

func ability(parent,member):
	if allocating:
		ui.pages.party_view.growth(parent,member)
		ui.button(parent,"戻る",end_allocation)
		return
	var row=ui.row(parent)
	var portrait=ui.portrait(row,member,false,200);portrait.name="CharacterPortrait";portrait.tooltip_text="クリックで画像変更";portrait.mouse_filter=Control.MOUSE_FILTER_STOP
	portrait.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:open_portrait(member))
	var values=VBoxContainer.new();values.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(values)
	var stats=member.get("stats",member)
	ui.label_(values,"HP %d/%d   MP %d/%d" % [member.hp,member.max,member.mp,member.maxMp])
	for key in ["str","int","agi","speed"]:
		var value=int(stats.get(key,0));var breakdown=stats.get("attributeBreakdown",{}).get(key,{})
		var delta=int(breakdown.get("equipment",0)) if key in ["str","int"] else value-int(stats.get("agi",value)) if key=="speed" else 0
		var line=ui.row(values);line.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;var base_label=ui.label_(line,("SPD" if key=="speed" else key.to_upper())+"  "+str(value));base_label.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;base_label.autowrap_mode=TextServer.AUTOWRAP_OFF
		var mod=ui.label_(line,"(%+d)" % delta);mod.autowrap_mode=TextServer.AUTOWRAP_OFF;mod.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;mod.add_theme_color_override("font_color",Color("#247044") if delta>0 else Color("#b04430") if delta<0 else Color("#707970"))
	ui.label_(values,"EXP %d" % int(member.get("xp",0)))
	ui.pages.party_view.identity(values,member)
	ui.label_(values,"通常ATK %d / 射程 %d" % [ui.pages.normal_atk(stats,1),ui.pages.normal_reach(stats)])
	ui.label_(values,"属性ATK  火%d / 水%d / 地%d" % [stats.get("atkFire",0),stats.get("atkWater",0),stats.get("atkEarth",0)])
	ui.label_(values,ui.pages.defense_profile(stats))
	var points=int(member.get("statPoints",0))
	var allocate=ui.button(parent,"能力を割り振る  "+str(points),func():allocating=true;ui.render(),points<=0);allocate.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
func skills(parent,member):
	var stats=member.get("stats",member);var names=ui.campaign().get("skillNames",{});var definitions=ui.campaign().get("skillDefinitions",{})
	var content=ui.scroller(parent)
	for group in [["active","アクティブスキル"],["passive","パッシブスキル"]]:
		ui.label_(content,group[1],true)
		var grid=HFlowContainer.new();grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);content.add_child(grid)
		for source in stats.get("skillSources",[]):
			var id=str(source.id);var classification=str(source.get("classification",definitions.get(id,{}).get("classification","passive")))
			if classification!=group[0]:continue
			var level=int(source.get("level",1));var name=str(names.get(id,id));var gear=member.get("equipmentDetails",{}).get(source.slot,{})
			var origin=str(ui.campaign().get("slots",{}).get(source.slot,source.slot))+" / "+str(gear.get("name",source.get("itemId","")))
			var button=ui.button(grid,name+" Lv%d\n" % level+origin,ui.show_skill_details.bind(id,name,level,gear));button.name="CharacterSkill_"+group[0]+"_"+id+"_"+str(source.slot);button.icon=ui.icons.texture(ui.icons.skill(id,level));button.expand_icon=true;button.add_theme_constant_override("icon_max_width",40);button.custom_minimum_size=Vector2(280,72)
			button.tooltip_text=preload("res://skill_text.gd").plain(preload("res://skill_text.gd").document(id,name,level,ui.campaign(),gear))
		if grid.get_child_count()==0:ui.label_(content,"なし")

func set_tab(value: String):
	if value==tab:return
	if not ui.pages.party_view.guard_leave(set_tab.bind(value)):return
	tab=value;picked={};allocating=false;ui.render()
func end_allocation():
	if not ui.pages.party_view.guard_leave(end_allocation):return
	allocating=false;ui.render()
func open_portrait(member: Dictionary):
	if not ui.pages.party_view.guard_leave(open_portrait.bind(member)):return
	ui.dialog.open(str(member.name)+"の画像",func(body,actions):
		var picture=ui.portrait(body,member,false,200);picture.custom_minimum_size=Vector2(300,400)
		ui.local_button(actions,"画像変更",func():
			ui.dialog.close()
			ui.file_dialog(FileDialog.FILE_MODE_OPEN_FILE,PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp,*.bmp,*.gif ; キャラ画像"]),ui.import_portrait.bind(str(member.id)))).name="StatusChangePortrait"
		ui.local_button(actions,"閉じる",ui.dialog.close))
func render_comparison_skills(parent,quote: Dictionary):
	var helper=preload("res://shop_comparison.gd").new(ui.pages.shop_view)
	var before=quote.before.get("skillSources",[]);var after=quote.after.get("skillSources",[])
	for group in [["追加",helper.removed_sources(after,before),"#277242"],["失う",helper.removed_sources(before,after),"#a84432"]]:
		if group[1].is_empty():continue
		ui.label_(parent,group[0]+"スキル").add_theme_color_override("font_color",Color(group[2]))
		var line=HFlowContainer.new();parent.add_child(line)
		for source in group[1]:
			var id=str(source.id);var level=int(source.get("level",1));var name_=str(ui.campaign().get("skillNames",{}).get(id,id))
			var gear=quote.get("gear",{}) if group[0]=="追加" else quote.get("current",{})
			var doc=preload("res://skill_text.gd").document(id,name_,level,ui.campaign(),gear)
			var button=preload("res://comparison_skill_icon.gd").new();line.add_child(button);button.name="CharacterComparisonSkill_"+group[0]+"_"+id;button.text="Lv%d" % level
			button.icon=helper.skill_texture(id,level);button.custom_minimum_size=Vector2(96,52);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",40)
			button.tooltip_text=group[0]+" / "+preload("res://skill_text.gd").plain(doc)
			button.pressed.connect(ui.show_skill_details.bind(id,name_,level,gear))

func confirm_discard(uid: String,item: Dictionary):
	if busy or ui.locked or ui.modal_open():return
	var token=ui.campaign().get("inventoryToken");var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation
	ui.dialog.open("アイテムを捨てる",func(body,actions):
		ui.label_(body,str(item.name))
		var count=SpinBox.new();count.name="CharacterDiscardQuantity";count.min_value=1;count.max_value=int(item.count);count.value=1;body.add_child(count)
		ui.local_button(actions,"捨てる",func():
			var amount=int(count.value);ui.dialog.close()
			if token!=ui.campaign().get("inventoryToken") or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation:toast("状態が変わりました。もう一度選んでください");return
			perform(uid,str(item.id),"discard",null,amount,null)).name="CharacterDiscardConfirm"
		ui.local_button(actions,"キャンセル",ui.dialog.close))
