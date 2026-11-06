extends RefCounted
## Full-page character inspection; no inventory copy is kept in UI state.
var ui
var tab="equipment"
var picked: Dictionary={}
var owner=""
var busy=false
var allocating=false
const Drag=preload("res://item_drag.gd")
func _init(frontend):ui=frontend
func render(parent):
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
		ui.label_(display,str(member.name)+" / Lv."+str(member.level),true)
		ability(display,member)
	else:skills(display,member)
	if tab in ["equipment","inventory"]:
		var detail=ui.card(split);detail.get_parent().custom_minimum_size=Vector2(420,536);detail.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
		ui.label_(detail,"選択アイテム")
		if picked.is_empty():return
		ui.label_(detail,str(picked.get("name","")),true)
		ui.pages.describe_gear(detail,picked)
		if picked.has("equipped_slot"):
			ui.button(detail,"装備を外す",perform.bind(owner,str(picked.id),"unequip",null,1,picked.equipped_slot),busy)
		else:
			for option in picked.get("equipSlots",[]):
				var control=ui.button(detail,"装備する — "+str(ui.campaign().get("slots",{}).get(option.slot,option.slot)),perform.bind(owner,str(picked.id),"equip",null,1,option.slot),busy or not option.ok)
				control.tooltip_text=str(option.get("reason",""))
			for option in picked.get("useTargets",[]):
				var control=ui.button(detail,str(option.targetName)+"に使う",perform.bind(owner,str(picked.id),"use",option.targetId,1,null),busy or not option.ok);control.tooltip_text=str(option.get("reason",""))
			if picked.get("kind")=="equipment":preview(detail,member,picked)
func equipment(parent,member):
	ui.label_(parent,"装備")
	var stage=Control.new();stage.custom_minimum_size=Vector2(296,470);stage.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(stage)
	var art=ui.portrait(stage,member,false,1);art.position=Vector2(20,8);art.size=Vector2(260,470);art.modulate.a=.22;art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var positions={"head":Vector2(108,0),"rightHand":Vector2(12,92),"upperBody":Vector2(108,92),"leftHand":Vector2(204,92),"lowerBody":Vector2(108,188),"feet":Vector2(108,284),"accessory1":Vector2(60,380),"accessory2":Vector2(156,380)}
	for slot in member.get("equipmentSlots",[]):
		var item=member.get("equipmentDetails",{}).get(slot.slot,{}).duplicate(true);item["equipped_slot"]=slot.slot;item["id"]=slot.get("id","");item["name"]=ui.pages.party_view.equipment_name(slot)
		var button=ui.button(stage,"",func():picked=item;ui.render());button.name="CharacterSlot_"+str(slot.slot);button.position=positions.get(slot.slot,Vector2.ZERO);button.custom_minimum_size=Vector2(72,72);button.size=Vector2(72,72);button.tooltip_text=str(slot.label)+" / "+str(item.name)
		button.icon=ui.icons.texture(ui.icons.equipment(item));button.expand_icon=true;button.add_theme_constant_override("icon_max_width",52)
		var caption=ui.label_(stage,str(slot.label));caption.position=button.position+Vector2(0,74);caption.size=Vector2(90,12);caption.autowrap_mode=TextServer.AUTOWRAP_OFF;caption.add_theme_font_size_override("font_size",11)
		if item.get("type")!="empty" and slot.get("occupiedBy")==null:Drag.source(button,func():return payload(item,"transferEquipped",str(slot.slot)),str(item.name),button.icon)
func inventory(parent,member):
	ui.label_(parent,"インベントリ",true)
	var list=ui.scroller(parent)
	var entries=ui.campaign().get("inventoryByCharacter",{}).get(str(member.id),{}).get("entries",[])
	if entries.is_empty():ui.label_(list,"アイテムはありません")
	for entry in entries:
		var button=ui.button(list,str(entry.name)+"  ×"+str(entry.count),func():picked=entry;ui.render());button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.custom_minimum_size.y=60
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
	var token=ui.campaign().get("inventoryToken");var epoch=ui.pages.epoch
	var response=await ui.engine.request({"op":"campaign","action":"inventoryQuote","args":[uid,item,action,target,count,slot]})
	var quote=response.get("inventoryQuote",{})
	if not quote.get("ok",false):busy=false;toast(str(quote.get("reason","操作できません")));return
	if token!=ui.campaign().get("inventoryToken") or epoch!=ui.pages.epoch:busy=false;return
	var result=await ui.update({"op":"campaign","action":"inventoryAction","args":[uid,item,action,target,count,slot,quote.token]})
	busy=false
	if result.get("ok",false):picked={};toast(str(quote.name)+" ×"+str(count)+(" → "+ui.member_name(str(target)) if target!=null else "：更新しました"))
	else:toast(str(result.get("error","操作できません")))
	ui.render()
func toast(text):
	var panel=PanelContainer.new();panel.name="InventoryToast";panel.add_theme_stylebox_override("panel",ui.mock_shell.style());ui.add_child(panel);panel.z_index=90
	var label=ui.label_(panel,text);label.custom_minimum_size=Vector2(400,40);panel.position=Vector2(ui.size.x-460,ui.size.y-100)
	ui.get_tree().create_timer(3).timeout.connect(panel.queue_free)
func preview(parent,member,item):
	var options=item.get("equipSlots",[]).filter(func(q):return q.ok)
	if options.is_empty():return
	var text=RichTextLabel.new();text.bbcode_enabled=true;text.add_theme_color_override("default_color",Color("#29332f"));text.fit_content=true;text.custom_minimum_size.y=180;parent.add_child(text)
	var result=await ui.engine.request({"op":"campaign","action":"previewGear","args":[member.id,item.id,options[0].slot]})
	if not is_instance_valid(text):return
	var quote=result.get("previewGear",{})
	if quote is Dictionary and quote.has("before"):
		render_comparison_skills(parent,quote)
		text.text=ui.pages.party_view.owned_equipment_view.comparison(member,item,options[0].slot,quote,true).replace("#8ee6ab","#247044").replace("#ffb1a6","#b04430").replace("#d5dbe2","#707970")
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
		var line=ui.row(values);ui.label_(line,("SPD" if key=="speed" else key.to_upper())+"  "+str(value))
		var mod=ui.label_(line,"(%+d)" % delta);mod.add_theme_color_override("font_color",Color("#247044") if delta>0 else Color("#b04430") if delta<0 else Color("#707970"))
	ui.pages.elemental_badge(values,str(stats.get("element","none")),32)
	ui.label_(values,ui.pages.defense_profile(stats))
	var points=int(member.get("statPoints",0))
	ui.button(parent,"能力を割り振る  "+str(points),func():allocating=true;ui.render(),points<=0)
func skills(parent,member):
	ui.label_(parent,"アクティブスキル",true)
	var grid=GridContainer.new();grid.columns=4;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);parent.add_child(grid)
	var stats=member.get("stats",member);var names=ui.campaign().get("skillNames",{})
	for source in stats.get("skillSources",[]):
		var id=str(source.id);var level=int(source.get("level",1));var name=str(names.get(id,id));var gear=member.get("equipmentDetails",{}).get(source.slot,{})
		var button=ui.button(grid,name,ui.show_skill_details.bind(id,name,level,gear));button.icon=ui.icons.texture(ui.icons.skill(id,level));button.expand_icon=true;button.add_theme_constant_override("icon_max_width",40);button.custom_minimum_size=Vector2(160,72)
		button.tooltip_text=preload("res://skill_text.gd").plain(preload("res://skill_text.gd").document(id,name,level,ui.campaign(),gear))
	ui.label_(parent,"パッシブスキル",true)
	for effect in member.get("effectNames",[]):ui.label_(parent,str(effect))

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
