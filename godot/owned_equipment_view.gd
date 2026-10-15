extends RefCounted
## A projection of inventoryByCharacter, never a second inventory.
var owner_ref: WeakRef
var party:
	get:return owner_ref.get_ref()
var ui
var slot := ""
var generation := 0
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
	ui.label_(parent,str(u.name)+"の所持装備",true).name="OwnedEquipmentOwner"
	var chooser=OptionButton.new();chooser.name="OwnedEquipmentSlot";chooser.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(chooser)
	chooser.add_item("すべての所持装備 / 比較枠を選択");chooser.set_item_metadata(0,"")
	for e in u.get("equipmentSlots",[]):
		chooser.add_item(str(e.label));chooser.set_item_metadata(chooser.item_count-1,str(e.slot))
		if slot==e.slot:chooser.select(chooser.item_count-1)
	chooser.item_selected.connect(func(i):slot=str(chooser.get_item_metadata(i));party.refresh_modal())
	var list=VBoxContainer.new();list.name="OwnedEquipmentList";parent.add_child(list)
	var panel=RichTextLabel.new();panel.name="OwnedEquipmentComparison";panel.bbcode_enabled=true;panel.fit_content=true;panel.custom_minimum_size.y=150;panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;panel.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;panel.text="装備にカーソルを合わせるか、キーボードで選択すると比較できます。";parent.add_child(panel)
	for entry in entries(str(u.id)):
		if not slot.is_empty() and not entry.equipSlots.any(func(q):return q.slot==slot):continue
		var row=ui.row(list)
		var button=ui.button(row,"%s　%d個" % [entry.name,entry.count],equip.bind(u,entry,panel));button.name="OwnedEquipment_"+str(entry.id);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		button.mouse_entered.connect(inspect.bind(u,entry,panel));button.focus_entered.connect(inspect.bind(u,entry,panel))
		ui.button(row,"操作",actions.bind(str(u.id),str(entry.id))).name="OwnedEquipmentActions_"+str(entry.id)
	if list.get_child_count()==0:ui.label_(list,"この枠に装備できる所持装備はありません。" if not slot.is_empty() else "所持装備はありません。")
func actions(uid: String,id: String):
	var inv=party.inventory_view
	if not inv.available():return
	inv.reset();inv.owner_id=uid;party.detail_tab=3;inv.pick(id)
func current(ticket: int,panel,epoch,connection,token) -> bool:
	return ticket==generation and is_instance_valid(panel) and panel.is_inside_tree() and not panel.is_queued_for_deletion() and not ui.closing and party.detail_tab==0 and epoch==ui.pages.epoch and connection==ui.engine.connection_generation and token==ui.campaign().get("inventoryToken")
func inspect(u: Dictionary,entry: Dictionary,panel) -> String:
	generation+=1;var ticket=generation;var chosen=target(entry)
	if chosen.is_empty():panel.text=str(u.name)+" / "+str(entry.name)+"\n比較する装備枠を選択してください。";return ""
	var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation;var token=ui.campaign().get("inventoryToken")
	panel.text=str(u.name)+" / "+str(ui.campaign().slots.get(chosen,chosen))+"\n比較を読み込み中…"
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
	var a: Dictionary=q.before;var z: Dictionary=q.after;var g: Dictionary=q.gear;var old: Dictionary=q.current
	var lines=["[b]%s / %s[/b]" % [escaped(u.name),escaped(ui.campaign().slots.get(chosen,chosen))],escaped(old.get("name","なし"))+" → "+escaped(g.name),"[b]単品性能[/b]",change("武器ATK",old.get("atk",0),g.get("atk",0)),change("通常射程",old.get("reach",0),g.get("reach",0)),"[b]人物全体の実効値[/b]"]
	for pair in [["HP上限","max"],["MP上限","maxMp"],["行動速度","speed"],["DEF","def"]]:lines.append(change(pair[0],a.get(pair[1],0),z.get(pair[1],0)))
	for distance in range(1,maxi(party.pages.normal_reach(a),party.pages.normal_reach(z))+1):lines.append(change("通常ATK 距離%d" % distance,party.pages.normal_atk(a,distance),party.pages.normal_atk(z,distance)))
	lines.append("現在HP %d → %d / MP %d → %d（上限増加では回復しません）" % [u.hp,mini(int(u.hp),int(z.max)),u.mp,mini(int(u.mp),int(z.maxMp))])
	var names=ui.campaign().get("skillNames",{})
	for field in ["activeSkills","effects"]:
		for id in z.get(field,[]):
			if not a.get(field,[]).has(id):lines.append("[color=#8ee6ab]＋ "+escaped(names.get(id,id))+"[/color]")
		for id in a.get(field,[]):
			if not z.get(field,[]).has(id):lines.append("[color=#ffb1a6]− "+escaped(names.get(id,id))+"[/color]")
	if int(g.get("hands",1))==2 or int(old.get("hands",1))==2:lines.append("両手装備の影響枠: 右手・左手。左手は空いている必要があります。")
	for candidate in entry.equipSlots:
		if candidate.slot==chosen and not candidate.ok:lines.append("装備不可: "+escaped(candidate.reason))
	if g.get("note")!=null:lines.append(escaped(g.note))
	return "\n".join(lines)
func equip(u: Dictionary,entry: Dictionary,panel):
	var chosen=target(entry)
	var text=await inspect(u,entry,panel)
	if chosen.is_empty() or text.is_empty() or not party.inventory_view.available():return
	for candidate in entry.equipSlots:
		if candidate.slot==chosen and candidate.ok:
			var inv=party.inventory_view;inv.reset();inv.owner_id=str(u.id);inv.item_id=str(entry.id);inv.action="equip";inv.equipment_comparison=text
			party.detail_tab=3;await inv.prepare(null,chosen);return
