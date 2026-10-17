extends RefCounted
## A projection of inventoryByCharacter, never a second inventory.
var owner_ref: WeakRef
var party:
	get:return owner_ref.get_ref()
var ui
var slot := ""
var generation := 0
var hover_window: Window
func _init(owner):owner_ref=weakref(owner);ui=owner.ui
func reset():slot="";generation+=1
func entries(uid: String) -> Array:
	return ui.campaign().get("inventoryByCharacter",{}).get(uid,{}).get("entries",[]).filter(func(e):return e.kind=="equipment")
func target(entry: Dictionary) -> String:
	if not slot.is_empty():return slot
	var choices=entry.get("equipSlots",[])
	return str(choices[0].slot) if choices.size()==1 else ""
func render(parent,u: Dictionary):
	generation+=1
	if is_instance_valid(hover_window):hover_window.queue_free()
	ui.label_(parent,str(u.name)+"の所持装備",true).name="OwnedEquipmentOwner"
	var chooser=OptionButton.new();chooser.name="OwnedEquipmentSlot";chooser.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(chooser)
	chooser.add_item("すべての所持装備 / 比較枠を選択");chooser.set_item_metadata(0,"")
	for e in u.get("equipmentSlots",[]):
		chooser.add_item(str(e.label));chooser.set_item_metadata(chooser.item_count-1,str(e.slot))
		if slot==e.slot:chooser.select(chooser.item_count-1)
	chooser.item_selected.connect(func(i):slot=str(chooser.get_item_metadata(i));party.refresh_modal())
	var list=VBoxContainer.new();list.name="OwnedEquipmentList";parent.add_child(list)
	var hover=preload("res://hover_comparison.gd").new();hover.ui=ui;ui.dialog.window.add_child(hover);hover_window=hover
	var panel=hover.content
	for entry in entries(str(u.id)):
		if not slot.is_empty() and not entry.equipSlots.any(func(q):return q.slot==slot):continue
		var row=ui.row(list)
		var button=ui.button(row,"%s　%d個" % [entry.name,entry.count],func():pass);button.name="OwnedEquipment_"+str(entry.id);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.set_script(preload("res://equipment_tooltip.gd"));button.configure_entry(entry,ui.campaign())
		ui.icons.apply(button,ui.icons.equipment(entry.definition));button.set_meta("placeholder_item_icon",true)

		var chosen=target(entry);var allowed=entry.equipSlots.any(func(q):return q.slot==chosen and q.ok)
		var action_button=ui.button(row,"装備",equip.bind(u,entry,panel),not allowed);action_button.name="OwnedEquipmentActions_"+str(entry.id)
		action_button.mouse_entered.connect(func():hover.show_for(action_button))
		action_button.focus_entered.connect(func():hover.show_for(action_button,true))
		action_button.mouse_entered.connect(inspect.bind(u,entry,panel));action_button.focus_entered.connect(inspect.bind(u,entry,panel))
	if list.get_child_count()==0:ui.label_(list,"この枠に装備できる所持装備はありません。" if not slot.is_empty() else "所持装備はありません。")
func actions(uid: String,id: String):
	var inv=party.inventory_view
	if not inv.available():return
	inv.reset();inv.owner_id=uid;party.detail_tab=3;inv.pick(id)
func current(ticket: int,panel,epoch,connection,token) -> bool:
	return ticket==generation and is_instance_valid(panel) and panel.is_inside_tree() and not panel.is_queued_for_deletion() and not ui.closing and party.detail_tab==0 and epoch==ui.pages.epoch and connection==ui.engine.connection_generation and token==ui.campaign().get("inventoryToken")
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
	for candidate in entry.equipSlots:
		if candidate.slot==chosen and not candidate.ok:lines.append("装備不可: "+escaped(candidate.reason))
	return "\n".join(lines) if not lines.is_empty() else "能力値・スキルの変化なし"
func equip(u: Dictionary,entry: Dictionary,panel):
	var chosen=target(entry)
	var text=await inspect(u,entry,panel)
	if chosen.is_empty() or text.is_empty() or not party.inventory_view.available():return
	for candidate in entry.equipSlots:
		if candidate.slot==chosen and candidate.ok:
			var inv=party.inventory_view;inv.reset();inv.owner_id=str(u.id);inv.item_id=str(entry.id);inv.action="equip";inv.equipment_comparison=text;inv.return_to_equipment=true;inv.capture_equipment_context(str(u.id),str(entry.id))
			await inv.prepare(null,chosen);return
