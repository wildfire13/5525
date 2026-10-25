extends RefCounted
## A projection of inventoryByCharacter, never a second inventory.
var owner_ref: WeakRef
var party:
	get:return owner_ref.get_ref()
var ui
var slot := ""
var generation := 0
var hover_window: Window
var list_scroll: ScrollContainer
var list_positions: Dictionary={}
var reveal_id := ""
func _init(owner):owner_ref=weakref(owner);ui=owner.ui
func reset():slot="";generation+=1;list_scroll=null;list_positions.clear();reveal_id=""
func list_key(uid: String) -> String:return uid+":"+slot
func context(uid: String,id: String,origin: String) -> Dictionary:
	return {"window":ui.dialog.window.get_instance_id(),"owner":uid,"item":id,"category":slot,"scroll":list_scroll.scroll_vertical if is_instance_valid(list_scroll) else 0,"outer_scroll":ui.dialog.body.get_parent().scroll_vertical,"origin":origin}
func restore_context(saved: Dictionary,focus_name: String,ticket: int):
	if saved.is_empty() or not is_instance_valid(ui) or ui.closing or not ui.is_inside_tree():return
	list_positions[str(saved.owner)+":"+str(saved.category)]=int(saved.scroll)
	var tree=ui.get_tree()
	for i in range(4):await tree.process_frame
	if not is_instance_valid(ui) or ui.closing:return
	if ticket!=party.inventory_view.generation or party.detail_uid!=saved.owner or slot!=saved.category or not is_instance_valid(ui.dialog.window) or ui.dialog.window.get_instance_id()!=saved.window:return
	var button=ui.dialog.body.find_child(focus_name if not focus_name.is_empty() else str(saved.origin),true,false)
	if button is SpinBox:button.get_line_edit().grab_focus()
	elif button is Control:button.grab_focus()
	if is_instance_valid(list_scroll):list_scroll.scroll_vertical=int(saved.scroll)
	ui.dialog.body.get_parent().scroll_vertical=int(saved.outer_scroll)
func fit_list(scroll: ScrollContainer,parent: Control,key: String):
	if not is_instance_valid(ui) or ui.closing or not ui.is_inside_tree():return
	var tree=ui.get_tree()
	await tree.process_frame
	await tree.process_frame
	if not is_instance_valid(scroll) or scroll!=list_scroll or not scroll.is_visible_in_tree() or not is_instance_valid(ui.dialog.window):return
	var viewport=ui.dialog.body.get_parent()
	# Only the list scrolls: leave the selected item's controls below it visible.
	var top=scroll.global_position.y-viewport.global_position.y+viewport.scroll_vertical
	var actions=parent.find_child("StatusInventoryActions",true,false)
	var reserved=actions.get_combined_minimum_size().y+8 if actions!=null else 0.0
	# A short saved character window may have room for only one inventory row.
	# Reserve the controls first instead of forcing a three-row list over them.
	var height=clampf(viewport.size.y-top-reserved-8,44,360)
	height=minf(height,maxf(44,scroll.get_child(0).get_combined_minimum_size().y))
	if absf(scroll.custom_minimum_size.y-height)>1:scroll.custom_minimum_size.y=height
	await tree.process_frame
	await tree.process_frame
	if not is_instance_valid(scroll) or scroll!=list_scroll or not scroll.is_inside_tree():return
	if scroll.get_meta("restoring",false):
		scroll.scroll_vertical=int(list_positions.get(key,0));scroll.set_meta("restoring",false)
		if not reveal_id.is_empty():
			var selected=scroll.find_child("OwnedEquipment_"+reveal_id,true,false)
			if selected!=null and party.inventory_view.item_id==reveal_id and party.inventory_view.stage!="list":scroll.ensure_control_visible(selected)
			reveal_id=""
func entries(uid: String) -> Array:
	return ui.campaign().get("inventoryByCharacter",{}).get(uid,{}).get("entries",[])
func target(entry: Dictionary) -> String:
	if not slot.is_empty():return slot
	var choices=entry.get("equipSlots",[])
	return str(choices[0].slot) if choices.size()==1 else ""
func render_header(parent,u: Dictionary):
	var heading=ui.row(parent);heading.name="OwnedInventoryHeader"
	var title=ui.label_(heading,str(u.name)+"のインベントリ",true);title.name="OwnedEquipmentOwner";title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;ui.short_name(title,title.text);title.autowrap_mode=TextServer.AUTOWRAP_OFF;title.clip_text=true;title.max_lines_visible=1
	var chooser=OptionButton.new();chooser.name="OwnedEquipmentSlot";chooser.fit_to_longest_item=false;chooser.clip_text=true;chooser.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(chooser);chooser.custom_minimum_size.x=160
	chooser.add_item("すべて");chooser.set_item_metadata(0,"")
	for e in u.get("equipmentSlots",[]):
		chooser.add_item(str(e.label));chooser.set_item_metadata(chooser.item_count-1,str(e.slot))
		if slot==e.slot:chooser.select(chooser.item_count-1)
	chooser.add_item("消耗品・荷物");chooser.set_item_metadata(chooser.item_count-1,"items")
	if slot=="items":chooser.select(chooser.item_count-1)
	chooser.disabled=not party.inventory_view.available() or party.inventory_view.stage=="confirm"
	chooser.item_selected.connect(func(i):
		if not party.inventory_view.available() or party.inventory_view.stage=="confirm":return
		slot=str(chooser.get_item_metadata(i));party.inventory_view.reset();party.inventory_view.owner_id=str(u.id);party.refresh_modal())
func render(parent,u: Dictionary):
	generation+=1
	if is_instance_valid(hover_window):hover_window.hide();hover_window.name="RetiredEquipmentHover";hover_window.queue_free()
	var scroll=ScrollContainer.new();scroll.name="OwnedEquipmentScroll";scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;scroll.custom_minimum_size.y=200;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(scroll);list_scroll=scroll
	var key=list_key(str(u.id));scroll.set_meta("restoring",true)
	scroll.get_v_scroll_bar().value_changed.connect(func(value):
		if scroll==list_scroll and scroll.is_inside_tree() and not scroll.is_queued_for_deletion() and not scroll.get_meta("restoring",false):list_positions[key]=int(value))
	parent.resized.connect(func():fit_list(scroll,parent,key))
	var list=GridContainer.new();list.columns=3;list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.name="OwnedEquipmentList";scroll.add_child(list)
	var hover=preload("res://hover_comparison.gd").new();hover.ui=ui;ui.dialog.window.add_child(hover);hover_window=hover
	var panel=hover.content
	for entry in entries(str(u.id)):
		if slot=="items" and entry.kind=="equipment":continue
		if not slot.is_empty() and slot!="items" and not entry.equipSlots.any(func(q):return q.slot==slot):continue
		var row=list
		var selected=party.inventory_view.owner_id==str(u.id) and party.inventory_view.item_id==str(entry.id) and party.inventory_view.stage!="list"
		var button=ui.button(row,("選択中 / " if selected else "")+"%s　%d個" % [entry.name,entry.count],actions.bind(str(u.id),str(entry.id)));button.name="OwnedEquipment_"+str(entry.id);ui.memory.key(button,"inventory_"+str(u.id)+"_"+str(entry.id));button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.set_meta("selected_inventory_item",selected)
		if selected:
			for state_ in ["normal","hover","pressed"]:
				var style=button.get_theme_stylebox(state_).duplicate();style.border_color=Color("#91dacf");style.set_border_width_all(2);button.add_theme_stylebox_override(state_,style)
		button.set_script(preload("res://equipment_tooltip.gd"));button.configure_entry(entry,ui.campaign())
		ui.icons.apply(button,ui.icons.equipment(entry.definition) if entry.kind=="equipment" else str(entry.id) if entry.id in ["potion","ether"] else "items");button.set_meta("placeholder_item_icon",true)

		if entry.kind=="equipment":
			preload("res://item_drag.gd").source(button,func():
				if not party.inventory_view.available() or party.inventory_view.stage=="confirm":return null
				return {"kind":"owned_equipment","owner":str(u.id),"item":str(entry.id),"connection":ui.engine.connection_generation,"token":ui.campaign().get("inventoryToken"),"epoch":party.pages.epoch},button.text,button.icon)
		if entry.kind!="equipment":
			var usable=entry.get("useTargets",[]).any(func(q):return q.get("ok",false))
			if usable:
				ui.button(row,"使用",use_item.bind(str(u.id),str(entry.id))).name="OwnedInventoryUse_"+str(entry.id)
			else:row.add_child(Control.new())
			sale_button(row,u,entry)
			continue
		var chosen=target(entry);var allowed=entry.equipSlots.any(func(q):return q.slot==chosen and q.ok)
		var action_button=ui.button(row,"装備",equip.bind(u,entry,panel),not allowed);action_button.name="OwnedEquipmentActions_"+str(entry.id)
		action_button.mouse_entered.connect(func():hover.show_for(action_button))
		action_button.focus_entered.connect(func():hover.show_for(action_button,true))
		action_button.mouse_entered.connect(inspect.bind(u,entry,panel));action_button.focus_entered.connect(inspect.bind(u,entry,panel))
		sale_button(row,u,entry)
	if list.get_child_count()==0:
		scroll.hide();scroll.custom_minimum_size.y=0
		# An empty three-column grid cannot give this label a useful text width.
		var empty=ui.label_(parent,"この枠に装備できる所持装備はありません。" if not slot.is_empty() else "所持品はありません。")
		empty.name="OwnedInventoryEmpty";empty.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	fit_list(scroll,parent,key)
func use_item(uid: String,id: String):
	if actions(uid,id,"OwnedInventoryUse_"+id):party.inventory_view.choose("use")
func sale_button(parent,u,entry):
	if ui.page!="shop":parent.add_child(Control.new());return
	var enabled=ui.campaign().get("saleAvailable",false) and ui.campaign().get("selected",[]).has(u.id) and entry.get("sale",{}).get("ok",false)
	ui.button(parent,"売却",sell_item.bind(str(u.id),str(entry.id)),not enabled).name="OwnedInventorySell_"+str(entry.id)
func sell_item(uid: String,id: String):
	if actions(uid,id,"OwnedInventorySell_"+id):party.inventory_view.choose_sale(id)
func actions(uid: String,id: String,origin: String="") -> bool:
	var inv=party.inventory_view
	if not inv.available() or inv.stage=="confirm" or party.detail_uid!=uid:return false
	var visible=entries(uid).filter(func(entry):return entry.id==id and (slot.is_empty() or slot=="items" and entry.kind!="equipment" or slot!="items" and entry.equipSlots.any(func(q):return q.slot==slot)))
	if visible.is_empty():return false
	var saved=context(uid,id,origin if not origin.is_empty() else "OwnedEquipment_"+id)
	inv.reset();inv.owner_id=uid;inv.list_context=saved;reveal_id=id;inv.pick(id)
	return true
func current(ticket: int,panel,epoch,connection,token) -> bool:
	return ticket==generation and is_instance_valid(panel) and panel.is_inside_tree() and not panel.is_queued_for_deletion() and not ui.closing and epoch==ui.pages.epoch and connection==ui.engine.connection_generation and token==ui.campaign().get("inventoryToken")
func inspect(u: Dictionary,entry: Dictionary,panel) -> String:
	generation+=1;var ticket=generation;var chosen=target(entry)
	if chosen.is_empty():
		panel.text="比較する装備枠を選択してください。";return ""
	var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation;var token=ui.campaign().get("inventoryToken")
	panel.text="比較を読み込み中…"
	while ui.engine.busy:
		await ui.get_tree().process_frame
		if not current(ticket,panel,epoch,connection,token):return ""
	if not current(ticket,panel,epoch,connection,token):return ""
	var reply=await ui.engine.request({"op":"campaign","action":"previewGear","args":[u.id,entry.id,chosen]})
	if not current(ticket,panel,epoch,connection,token):return ""
	var preview=reply.get("previewGear",{})
	if not preview is Dictionary or not preview.has("before"):
		panel.text="比較を取得できませんでした。もう一度選択してください。";return ""
	var result=comparison(u,entry,chosen,preview);panel.text=result;return result
func escaped(value) -> String:return str(value).replace("[","[lb]")
func change(title: String,before,after) -> String:
	var delta=int(after)-int(before);var color="#8ee6ab" if delta>0 else "#ffb1a6" if delta<0 else "#d5dbe2"
	return "%s: %d → %d [color=%s](%+d)[/color]" % [title,before,after,color,delta]
func comparison(u: Dictionary,entry: Dictionary,chosen: String,q: Dictionary) -> String:
	var a: Dictionary=q.before;var z: Dictionary=q.after;
	var lines=[]
	for pair in [["HP上限","max"],["MP上限","maxMp"],["行動速度","speed"],["DEF","def"]]:
		if int(a.get(pair[1],0))!=int(z.get(pair[1],0)):lines.append(change(pair[0],a.get(pair[1],0),z.get(pair[1],0)))
	var before_reach=party.pages.normal_reach(a);var after_reach=party.pages.normal_reach(z)
	if before_reach!=after_reach:lines.append(change("通常射程",before_reach,after_reach))
	for distance in range(1,maxi(before_reach,after_reach)+1):
		var before_atk=party.pages.normal_atk(a,distance);var after_atk=party.pages.normal_atk(z,distance)
		if before_atk!=after_atk:lines.append(change("通常ATK 距離%d" % distance,before_atk,after_atk))
	for pair in [["現在HP","hp","max"],["現在MP","mp","maxMp"]]:
		var before=int(u.get(pair[1],0));var after=mini(before,int(z.get(pair[2],before)))
		if before!=after:lines.append(change(pair[0],before,after))
	var names=ui.campaign().get("skillNames",{})
	for field in ["activeSkills","effects"]:
		for id in z.get(field,[]):
			if not a.get(field,[]).has(id):lines.append("[color=#8ee6ab]＋ "+escaped(names.get(id,id))+"[/color]")
		for id in a.get(field,[]):
			if not z.get(field,[]).has(id):lines.append("[color=#ffb1a6]− "+escaped(names.get(id,id))+"[/color]")
	for id in ["scout","itemUse","legSweep"]:
		var before_level=0;var after_level=0
		for source in a.get("skillSources",[]):
			if source.id==id:before_level=maxi(before_level,int(source.get("level",1)))
		for source in z.get("skillSources",[]):
			if source.id==id:after_level=maxi(after_level,int(source.get("level",1)))
		if before_level>0 and after_level>0 and before_level!=after_level:lines.append(change(str(names.get(id,id))+" Lv",before_level,after_level))
	for candidate in entry.equipSlots:
		if candidate.slot==chosen and not candidate.ok:lines.append("装備不可: "+escaped(candidate.reason))
	var heading="対象：%s / %s\n現在：%s → 候補：%s" % [escaped(u.get("name",ui.member_name(str(u.get("id",""))))),escaped(ui.campaign().get("slots",{}).get(chosen,chosen)),escaped(q.get("current",{}).get("name","現在の装備")),escaped(entry.get("name",q.get("gear",{}).get("name","候補装備")))]
	return heading+"\n"+("\n".join(lines) if not lines.is_empty() else "能力値・スキルの変化なし")
func equip(u: Dictionary,entry: Dictionary,panel):
	var chosen=target(entry)
	var text=await inspect(u,entry,panel)
	if chosen.is_empty() or text.is_empty() or not party.inventory_view.available():return
	for candidate in entry.equipSlots:
		if candidate.slot==chosen and candidate.ok:
			var inv=party.inventory_view;inv.reset();inv.owner_id=str(u.id);inv.item_id=str(entry.id);inv.action="equip";inv.equipment_comparison=text;inv.return_to_equipment=true;inv.capture_equipment_context(str(u.id),str(entry.id))
			await inv.prepare(null,chosen);return

func can_drop(data: Dictionary,uid: String,chosen: String) -> bool:
	if not party.inventory_view.available() or party.inventory_view.stage=="confirm":return false
	if data.get("kind")!="owned_equipment" or data.get("owner")!=uid or data.get("connection")!=ui.engine.connection_generation or data.get("epoch")!=party.pages.epoch or data.get("token")!=ui.campaign().get("inventoryToken"):return false
	for entry in entries(uid):
		if entry.id==data.get("item"):return entry.get("equipSlots",[]).any(func(q):return q.slot==chosen and q.ok)
	return false
func drop_equipment(data: Dictionary,uid: String,chosen: String):
	if not can_drop(data,uid,chosen):return
	var inv=party.inventory_view
	inv.reset();inv.owner_id=uid;inv.item_id=str(data.item);inv.action="equip";inv.return_to_equipment=true;inv.capture_equipment_context(uid,str(data.item),"OwnedEquipment_"+str(data.item))
	await inv.prepare(null,chosen)
