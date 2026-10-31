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
var sale_preview_generation := 0
var sale_preview_loading := false
var list_context: Dictionary={}
var confirmation_list_context: Dictionary={}
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
	list_context={};confirmation_list_context={};sale_preview_loading=false
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
	if stage=="confirm":cancel_confirmation();return true
	if not available() or stage=="list":return false
	if action=="sell" and sale_available() and stage in ["targets","confirm"]:stage="targets" if stage=="confirm" else "list"
	else:stage="actions" if stage in ["targets","confirm"] else "list"
	quote={};message="";generation+=1;redraw()
	if stage=="list":party.owned_equipment_view.restore_context(list_context,"",generation)
	return true
func show_list():
	if not available() or stage=="confirm":return
	stage="list";quote={};generation+=1;redraw();party.owned_equipment_view.restore_context(list_context,"",generation)
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
	if stage=="list":return # The persistent owner list is rendered by owned_equipment_view.
	if stage=="confirm":l(parent,"確認ダイアログで操作を選択してください。");return
	l(parent,"%s / %s / 所持 %d個" % [ui.member_name(owner_id),entry.name,entry.count],true)
	if stage=="actions":
		var primary=ui.row(parent)
		b(primary,"説明",ui.show_equipment_details.bind(entry)).name="InventoryDetails"
		var equip_available=entry.kind=="equipment" and entry.equipSlots.any(func(q):return q.ok)
		if entry.kind=="equipment":b(primary,"装備する",choose.bind("equip"),not equip_available).name="InventoryEquip"
		b(primary,"所持品一覧へ",show_list).name="InventoryList"
		var use_reason=""
		if entry.kind=="equipment":use_reason="装備品です。装備枠を選んで装備できます。"
		elif entry.kind=="quest":use_reason="依頼の荷物は使用できません。目的地の拠点で「荷物を届ける」を選んで納品してください。"
		elif not entry.useTargets.any(func(q):return q.ok):
			use_reason=str(entry.useTargets[0].reason) if not entry.useTargets.is_empty() else "回復対象がいません"
		var actions=ui.row(parent)
		b(actions,"使用",choose.bind("use"),not use_reason.is_empty()).name="InventoryUse"
		b(actions,"他のキャラに渡す",choose.bind("transfer"),not entry.transferTargets.any(func(q):return q.ok)).name="InventoryTransfer"
		b(actions,"捨てる",choose.bind("discard"),not entry.discard.ok).name="InventoryDiscard"
		if ui.page=="shop":b(actions,"売却",choose.bind("sell"),not sale_available() or not entry.get("sale",{}).get("ok",false)).name="InventorySell"
		if not use_reason.is_empty():l(parent,"使用できない理由: "+use_reason)
		if entry.kind=="equipment":
			if not equip_available and not entry.equipSlots.is_empty():l(parent,"装備できない理由: "+str(entry.equipSlots[0].reason))
		if not entry.discard.ok:l(parent,entry.discard.reason)
		if entry.transferTargets.is_empty():l(parent,"渡せる編成中の仲間がいません。")
		return
	if action in ["transfer","discard","sell"]:
		amount=clampi(amount,1,int(entry.count))
		var row=ui.row(parent);l(row,"個数")
		var count=SpinBox.new();count.name="InventoryQuantity";count.min_value=1;count.max_value=int(entry.count);count.step=1;count.value=amount;count.custom_minimum_size.x=132;row.add_child(count)
		count.editable=available()
		if action=="sell":
			var totals=l(parent,"売却額を確認中…");totals.name="InventorySaleTotals"
			count.value_changed.connect(func(value):amount=int(value);preview_sale(totals))
			preview_sale(totals)
		else:count.value_changed.connect(func(value):amount=int(value))
	if action in ["use","transfer","equip"]:
		l(parent,"回復対象を選択" if action=="use" else "受取人を選択" if action=="transfer" else "装備枠を選択")
		var choices=entry.useTargets if action=="use" else entry.transferTargets if action=="transfer" else entry.equipSlots
		for candidate in choices:
			var caption=str(c().get("slots",{}).get(candidate.slot,candidate.slot)) if action=="equip" else str(candidate.targetName)
			if candidate.ok and action=="use":caption+=" / %s %d → %d（1個消費）" % [str(candidate.resource).to_upper(),candidate.before,candidate.after]
			if not candidate.ok:caption+=" / "+str(candidate.reason)
			var target=b(parent,caption,prepare.bind(candidate.get("targetId"),candidate.get("slot")),not candidate.ok)
			target.name="InventoryTarget_"+str(candidate.get("targetId",candidate.get("slot","")))
	elif action=="sell":
		var actions=ui.row(parent);actions.name="InventorySaleActions"
		b(actions,"売却内容を確認",prepare.bind(null,null),not sale_available()).name="InventoryPrepareSale"
		b(actions,"所持品一覧へ",show_list).name="InventoryList"
		return
	else:b(parent,"捨てる内容を確認",prepare.bind(null,null)).name="InventoryPrepareDiscard"
	b(parent,"操作選択へ",func():stage="actions";redraw())

func preview_sale(label):
	sale_preview_generation+=1;sale_preview_loading=true
	var ticket=sale_preview_generation;var owner=owner_id;var item=item_id;var count=amount;var token=c().get("inventoryToken");var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation
	var label_ref=weakref(label)
	label.text="売却額を確認中…"
	var valid=func():
		var current_label=label_ref.get_ref()
		return ticket==sale_preview_generation and is_instance_valid(current_label) and current_label.is_inside_tree() and not current_label.is_queued_for_deletion() and owner==owner_id and item==item_id and amount==count and action=="sell" and stage=="targets" and epoch==ui.pages.epoch and connection==ui.engine.connection_generation and token==c().get("inventoryToken") and not ui.closing
	while ui.engine.busy:
		await ui.get_tree().process_frame
		if not valid.call():
			if ticket==sale_preview_generation:sale_preview_loading=false
			return
	var result=await ui.engine.request({"op":"campaign","action":"saleQuote","args":[owner,item,count]})
	if ticket==sale_preview_generation:sale_preview_loading=false
	if not valid.call():return
	var q=result.get("saleQuote",{})
	label_ref.get_ref().text="%sの%s ×%d / 受取 %dG / 所持金 %d → 売却後 %dG" % [q.ownerName,q.name,q.count,q.proceeds,q.goldBefore,q.afterGold] if q.get("ok",false) else "売却不可："+str(q.get("reason","金額を取得できません。"))

func prepare(target,slot):
	if not available():return
	if action=="sell" and not sale_available():return
	if action=="sell":confirmation_list_context=party.owned_equipment_view.context(owner_id,item_id,"InventoryQuantity")
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

func capture_equipment_context(uid: String,id: String,origin: String=""):
	equipment_context={"origin":origin if not origin.is_empty() else "OwnedEquipmentActions_"+id,"window":ui.dialog.window.get_instance_id(),"owner":uid,"item":id,"slot":party.owned_equipment_view.slot,"scroll":ui.dialog.body.get_parent().scroll_vertical,"list_scroll":party.owned_equipment_view.list_scroll.scroll_vertical if is_instance_valid(party.owned_equipment_view.list_scroll) else 0}
func restore_equipment_context():
	var context=equipment_context.duplicate();equipment_context={}
	if context.is_empty():return
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	if not is_instance_valid(ui.dialog.window) or party.detail_uid!=context.owner or ui.dialog.window.get_instance_id()!=context.window:return
	var scroll=ui.dialog.body.get_parent()
	var button=ui.dialog.body.find_child(str(context.get("origin","OwnedEquipmentActions_"+str(context.item))),true,false)
	if button!=null:button.grab_focus()
	if is_instance_valid(party.owned_equipment_view.list_scroll):party.owned_equipment_view.list_scroll.scroll_vertical=int(context.get("list_scroll",0))
	scroll.scroll_vertical=int(context.scroll)
func cancel_confirmation():
	close_confirmation()
	var restore=return_to_equipment
	var sale=action=="sell" and sale_available()
	stage="list" if return_to_equipment else "targets" if sale else "actions";quote={};generation+=1
	if return_to_equipment:return_to_equipment=false
	redraw()
	if restore:restore_equipment_context()
	elif sale:party.owned_equipment_view.restore_context(confirmation_list_context if not confirmation_list_context.is_empty() else list_context,"InventoryQuantity",generation)

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
	confirmation.name="InventoryConfirmation";confirmation.ok_button_text=verb+"する";confirmation.cancel_button_text="キャンセル"
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
		if return_to_equipment:return_to_equipment=false
		redraw()
