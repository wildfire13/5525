extends RefCounted
## Session-only selection and confirmation. The campaign owns all quantities.
var owner_ref: WeakRef
var party:
	get:return owner_ref.get_ref()
var ui
var owner_id := ""
var item_id := ""
var action := ""
var stage := "list"
var amount := 1
var quote: Dictionary={}
var message := ""
var generation := 0
var equipment_comparison := ""
var return_to_equipment := false
var equipment_context: Dictionary={}
var confirmation: ConfirmationDialog
func close_confirmation():
	if is_instance_valid(confirmation):confirmation.hide();confirmation.queue_free()
	confirmation=null

func _init(owner):owner_ref=weakref(owner);ui=owner.ui
func c() -> Dictionary:return ui.campaign()
func l(parent,text,large:=false):return ui.label_(parent,str(text),large)
func b(parent,text,fn,disabled:=false):return ui.button(parent,text,fn,disabled)
func redraw():party.refresh_modal()
func reset():
	close_confirmation()
	equipment_comparison="";return_to_equipment=false;equipment_context={}
	owner_id="";item_id="";action="";stage="list";amount=1;quote={};message="";generation+=1
func data() -> Dictionary:return c().get("inventoryByCharacter",{}).get(owner_id,{})
func selected() -> Dictionary:
	for entry in data().get("entries",[]):
		if entry.id==item_id:return entry
	return {}
func available() -> bool:return not ui.locked and not ui.presenting and not ui.closing and not ui.engine.disconnected and stage not in ["pending","unknown"]
func sale_available() -> bool:return ui.page=="shop" and c().get("saleAvailable",false) and c().get("selected",[]).has(owner_id)
func pick(id: String):
	if not available():return
	equipment_comparison=""
	item_id=id;stage="actions";action="";amount=1;quote={};message="";redraw()
func back() -> bool:
	if return_to_equipment and stage=="confirm":cancel_confirmation();return true
	if not available() or stage=="list":return false
	if action=="sell" and sale_available() and stage in ["targets","confirm"]:stage="targets" if stage=="confirm" else "list"
	else:stage="actions" if stage in ["targets","confirm"] else "list"
	quote={};message="";generation+=1;redraw();return true
func choose(kind: String):
	if not available():return
	equipment_comparison=""
	action=kind;amount=1;quote={};message=""
	stage="targets";redraw()
func choose_sale(id: String):
	if not available() or not sale_available():return
	item_id=id;choose("sell")
func render(parent,uid: String):
	if owner_id!=uid:reset();owner_id=uid
	if not message.is_empty():l(parent,message)
	if stage=="unknown":l(parent,"結果を確認できません。自動再送はしません。保存済みの進行を読み込み直して確認してください。");return
	if stage=="pending":l(parent,"所持品の状態を確認しています…");return
	var entry=selected()
	if stage!="list" and stage!="confirm" and entry.is_empty():stage="list";item_id=""
	if stage=="list":
		if data().get("entries",[]).is_empty():l(parent,"所持品はありません。")
		for item in data().get("entries",[]):
			var row=ui.row(parent)
			var sale: Dictionary=item.get("sale",{})
			var sale_text=(" / 単価 %dG" % sale.get("price",0) if sale.get("ok",false) else " / 売却不可") if ui.page=="shop" else ""
			var button=b(row,"%s　%d個" % [item.name,item.count]+sale_text,pick.bind(str(item.id)))
			button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			button.set_script(preload("res://equipment_tooltip.gd"));button.configure_entry(item,c())
			var icon=ui.icons.gear(item.definition) if item.kind=="equipment" else str(item.id) if item.id in ["potion","ether"] else "items"
			if not ResourceLoader.exists(ui.icons.ROOT+icon+".png"):icon="items"
			ui.icons.apply(button,icon);button.set_meta("placeholder_item_icon",true)
			button.name="InventoryItem_"+str(item.id);button.custom_minimum_size.y=48
			ui.memory.key(button,"inventory_"+owner_id+"_"+str(item.id))
			if ui.page=="shop":
				var sell=b(row,"売却",choose_sale.bind(str(item.id)),not sale_available() or not sale.get("ok",false));sell.name="InventorySell_"+str(item.id)
				sell.tooltip_text=str(sale.get("reason",""))
		return
	if stage=="confirm":l(parent,"確認ダイアログで操作を選択してください。");return
	l(parent,"%s / %s / 所持 %d個" % [ui.member_name(owner_id),entry.name,entry.count],true)
	if stage=="actions":
		var use_reason=""
		if entry.kind=="equipment":use_reason="装備品です。装備枠を選んで装備できます。"
		elif not entry.useTargets.any(func(q):return q.ok):
			use_reason=str(entry.useTargets[0].reason) if not entry.useTargets.is_empty() else "回復対象がいません"
		var actions=ui.row(parent)
		b(actions,"使用",choose.bind("use"),not use_reason.is_empty()).name="InventoryUse"
		b(actions,"他のキャラに渡す",choose.bind("transfer"),not entry.transferTargets.any(func(q):return q.ok)).name="InventoryTransfer"
		b(actions,"捨てる",choose.bind("discard"),not entry.discard.ok).name="InventoryDiscard"
		if ui.page=="shop":b(actions,"売却",choose.bind("sell"),not sale_available() or not entry.get("sale",{}).get("ok",false)).name="InventorySell"
		if not use_reason.is_empty():l(parent,"使用できない理由: "+use_reason)
		if entry.kind=="equipment":
			var equip_available=entry.equipSlots.any(func(q):return q.ok)
			b(parent,"装備する",choose.bind("equip"),not equip_available).name="InventoryEquip"
			if not equip_available and not entry.equipSlots.is_empty():l(parent,"装備できない理由: "+str(entry.equipSlots[0].reason))
		if not entry.discard.ok:l(parent,entry.discard.reason)
		if entry.transferTargets.is_empty():l(parent,"渡せる編成中の仲間がいません。")
		b(parent,"所持品一覧へ",func():stage="list";redraw());return
	if action in ["transfer","discard","sell"]:
		amount=clampi(amount,1,int(entry.count))
		var row=ui.row(parent);l(row,"個数")
		var count=SpinBox.new();count.name="InventoryQuantity";count.min_value=1;count.max_value=int(entry.count);count.step=1;count.value=amount;count.custom_minimum_size.x=132;row.add_child(count)
		count.value_changed.connect(func(value):amount=int(value));count.editable=available()
	if action in ["use","transfer","equip"]:
		l(parent,"回復対象を選択" if action=="use" else "受取人を選択" if action=="transfer" else "装備枠を選択")
		var choices=entry.useTargets if action=="use" else entry.transferTargets if action=="transfer" else entry.equipSlots
		for candidate in choices:
			var caption=str(c().get("slots",{}).get(candidate.slot,candidate.slot)) if action=="equip" else str(candidate.targetName)
			if candidate.ok and action=="use":caption+=" / %s %d → %d（1個消費）" % [str(candidate.resource).to_upper(),candidate.before,candidate.after]
			if not candidate.ok:caption+=" / "+str(candidate.reason)
			var target=b(parent,caption,prepare.bind(candidate.get("targetId"),candidate.get("slot")),not candidate.ok)
			target.name="InventoryTarget_"+str(candidate.get("targetId",candidate.get("slot","")))
	elif action=="sell":b(parent,"売却内容を確認",prepare.bind(null,null),not sale_available()).name="InventoryPrepareSale"
	else:b(parent,"捨てる内容を確認",prepare.bind(null,null)).name="InventoryPrepareDiscard"
	if action=="sell" and sale_available():b(parent,"所持品一覧へ",func():stage="list";quote={};generation+=1;redraw()).name="InventoryList"
	else:b(parent,"操作選択へ",func():stage="actions";redraw())

func prepare(target,slot):
	if not available():return
	if action=="sell" and not sale_available():return
	stage="pending";message="";generation+=1
	var ticket=generation;var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation
	var args=[owner_id,item_id,action,target,amount,slot]
	redraw()
	var reply=await ui.update({"op":"campaign","action":"saleQuote" if action=="sell" else "inventoryQuote","args":[owner_id,item_id,amount] if action=="sell" else args})
	if ticket!=generation or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation or ui.closing:return
	if reply.get("connection_lost",false):stage="unknown";redraw();return
	quote=reply.get("saleQuote" if action=="sell" else "inventoryQuote",{})
	if action=="sell":quote.action="sell"
	if not reply.get("ok",false) or not quote.get("ok",false):stage="actions";message=str(quote.get("reason",reply.get("error","状態を再確認してください")));redraw();return
	stage="confirm";redraw();show_confirmation()

func prepare_unequip(uid: String,id: String,slot: String):
	if not available():return
	owner_id=uid;item_id=id;action="unequip";amount=1;return_to_equipment=party.detail_tab==0
	if return_to_equipment:capture_equipment_context(uid,id)
	await prepare(null,slot)

func capture_equipment_context(uid: String,id: String):
	equipment_context={"window":ui.dialog.window.get_instance_id(),"owner":uid,"item":id,"slot":party.owned_equipment_view.slot,"scroll":ui.dialog.body.get_parent().scroll_vertical}
func restore_equipment_context():
	var context=equipment_context.duplicate();equipment_context={}
	if context.is_empty():return
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	if not is_instance_valid(ui.dialog.window) or party.detail_tab!=0 or party.detail_uid!=context.owner or ui.dialog.window.get_instance_id()!=context.window:return
	var scroll=ui.dialog.body.get_parent()
	var button=ui.dialog.body.find_child("OwnedEquipmentActions_"+str(context.item),true,false)
	if button!=null:button.grab_focus()
	scroll.scroll_vertical=int(context.scroll)
func cancel_confirmation():
	close_confirmation()
	var restore=return_to_equipment
	stage="list" if return_to_equipment else "actions";quote={};generation+=1
	if return_to_equipment:party.detail_tab=0;return_to_equipment=false
	redraw()
	if restore:restore_equipment_context()

func show_confirmation():
	close_confirmation()
	var verb={"use":"使用","transfer":"譲渡","discard":"破棄","equip":"装備","unequip":"装備解除","sell":"売却"}.get(quote.get("action"),"操作")
	var text="%sしますか？\n%sの %s / %d個" % [verb,quote.get("ownerName",""),quote.get("name",""),quote.get("count",0)]
	if quote.get("action")=="use":text+="\n対象: %s / %s %d → %d / 消費1個" % [quote.targetName,str(quote.resource).to_upper(),quote.before,quote.after]
	elif quote.get("action")=="transfer":text+="\n渡す相手: "+str(quote.targetName)
	elif quote.get("action")=="sell":text+="\n受取 %dG / 所持金 %d → %dG" % [quote.proceeds,quote.goldBefore,quote.afterGold]
	elif quote.get("action") in ["equip","unequip"]:text+="\n装備枠: "+str(c().get("slots",{}).get(quote.slot,quote.slot))
	var ticket=generation;var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation
	confirmation=ui.confirm(text,func():
		if ticket==generation and epoch==ui.pages.epoch and connection==ui.engine.connection_generation:commit())
	confirmation.name="InventoryConfirmation";confirmation.ok_button_text="YES";confirmation.cancel_button_text="NO"
	confirmation.get_ok_button().name="InventoryConfirm";confirmation.get_cancel_button().name="InventoryCancel"
	var cancel=func():
		if ticket==generation and epoch==ui.pages.epoch and connection==ui.engine.connection_generation:cancel_confirmation()
	confirmation.canceled.connect(cancel)
	confirmation.close_requested.connect(cancel)
	confirmation.get_cancel_button().grab_focus()

func commit():
	if not available() or stage!="confirm" or quote.get("token")!=c().get("inventoryToken"):return
	if quote.get("action")=="sell" and not sale_available():return
	close_confirmation()
	var confirmed=quote.duplicate(true);stage="pending";generation+=1
	var ticket=generation;var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation
	redraw()
	var sale=confirmed.action=="sell"
	var reply=await ui.update({"op":"campaign","action":"sellInventory" if sale else "inventoryAction","args":[confirmed.ownerId,confirmed.itemId,confirmed.count,confirmed.token] if sale else [confirmed.ownerId,confirmed.itemId,confirmed.action,confirmed.targetId,confirmed.count,confirmed.slot,confirmed.token]})
	if ticket!=generation or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation or ui.closing:return
	if reply.get("connection_lost",false):stage="unknown";redraw();return
	if not reply.get("ok",false):
		await ui.update({"op":"view"})
		if ticket!=generation or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation or ui.closing:return
	stage="list" if reply.get("ok",false) else "actions";quote={}
	message="操作が完了しました。" if reply.get("ok",false) else str(reply.get("error","状態を再確認してください"))
	if sale and reply.get("ok",false):
		message="%s×%dを売却 / 受取%dG" % [confirmed.name,confirmed.count,confirmed.proceeds]
		ui.pages.shop_view.record_sale(confirmed);ui.render()
	else:
		if return_to_equipment:party.detail_tab=0;return_to_equipment=false
		redraw()
