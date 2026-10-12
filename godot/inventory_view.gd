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

func _init(owner):owner_ref=weakref(owner);ui=owner.ui
func c() -> Dictionary:return ui.campaign()
func l(parent,text,large:=false):return ui.label_(parent,str(text),large)
func b(parent,text,fn,disabled:=false):return ui.button(parent,text,fn,disabled)
func redraw():party.refresh_modal()
func reset():
	owner_id="";item_id="";action="";stage="list";amount=1;quote={};message="";generation+=1
func data() -> Dictionary:return c().get("inventoryByCharacter",{}).get(owner_id,{})
func selected() -> Dictionary:
	for entry in data().get("entries",[]):
		if entry.id==item_id:return entry
	return {}
func available() -> bool:return not ui.locked and not ui.presenting and not ui.closing and not ui.engine.disconnected and stage not in ["pending","unknown"]
func pick(id: String):
	if not available():return
	item_id=id;stage="actions";action="";amount=1;quote={};message="";redraw()
func back() -> bool:
	if not available() or stage=="list":return false
	stage="actions" if stage in ["targets","confirm"] else "list";quote={};message="";generation+=1;redraw();return true
func choose(kind: String):
	if not available():return
	action=kind;amount=1;quote={};message=""
	stage="targets";redraw()
func render(parent,uid: String):
	if owner_id!=uid:reset();owner_id=uid
	var title=l(parent,ui.member_name(owner_id)+"のインベントリ",true);title.name="InventoryOwner"
	if not message.is_empty():l(parent,message)
	if stage=="unknown":l(parent,"結果を確認できません。自動再送はしません。保存済みの進行を読み込み直して確認してください。");return
	if stage=="pending":l(parent,"所持品の状態を確認しています…");return
	var entry=selected()
	if stage!="list" and stage!="confirm" and entry.is_empty():stage="list";item_id=""
	if stage=="list":
		if data().get("entries",[]).is_empty():l(parent,"所持品はありません。")
		for item in data().get("entries",[]):
			var button=b(parent,"%s　%d個" % [item.name,item.count],pick.bind(str(item.id)))
			button.name="InventoryItem_"+str(item.id);button.custom_minimum_size.y=48
			ui.memory.key(button,"inventory_"+owner_id+"_"+str(item.id))
		return
	if stage=="confirm":render_confirmation(parent);return
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
		if not use_reason.is_empty():l(parent,"使用できない理由: "+use_reason)
		if entry.kind=="equipment":
			var equip_available=entry.equipSlots.any(func(q):return q.ok)
			b(parent,"装備する",choose.bind("equip"),not equip_available).name="InventoryEquip"
			if not equip_available and not entry.equipSlots.is_empty():l(parent,"装備できない理由: "+str(entry.equipSlots[0].reason))
		if not entry.discard.ok:l(parent,entry.discard.reason)
		if entry.transferTargets.is_empty():l(parent,"渡せる編成中の仲間がいません。")
		b(parent,"所持品一覧へ",func():stage="list";redraw());return
	if action in ["transfer","discard"]:
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
	else:b(parent,"捨てる内容を確認",prepare.bind(null,null)).name="InventoryPrepareDiscard"
	b(parent,"操作選択へ",func():stage="actions";redraw())

func prepare(target,slot):
	if not available():return
	stage="pending";message="";generation+=1
	var ticket=generation;var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation
	var args=[owner_id,item_id,action,target,amount,slot]
	redraw()
	var reply=await ui.update({"op":"campaign","action":"inventoryQuote","args":args})
	if ticket!=generation or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation or ui.closing:return
	if reply.get("connection_lost",false):stage="unknown";redraw();return
	quote=reply.get("inventoryQuote",{})
	if not reply.get("ok",false) or not quote.get("ok",false):stage="actions";message=str(quote.get("reason",reply.get("error","状態を再確認してください")));redraw();return
	stage="confirm";redraw()

func prepare_unequip(uid: String,id: String,slot: String):
	if not available():return
	owner_id=uid;item_id=id;action="unequip";amount=1
	party.detail_tab=3;await prepare(null,slot)

func render_confirmation(parent):
	l(parent,"%sの %s / %d個" % [quote.get("ownerName",""),quote.get("name",""),quote.get("count",0)],true)
	var verb={"use":"使用する","transfer":"渡す","discard":"捨てる","equip":"装備する","unequip":"装備を外す"}.get(quote.get("action"),"確定")
	if quote.get("action")=="use":l(parent,"対象: %s / %s %d → %d / 消費1個" % [quote.targetName,str(quote.resource).to_upper(),quote.before,quote.after])
	elif quote.get("action")=="transfer":l(parent,"渡す相手: "+str(quote.targetName))
	elif quote.get("action")=="discard":l(parent,"この所持品を捨てます。取り消すと個数は変わりません。")
	elif quote.get("action") in ["equip","unequip"]:l(parent,"装備枠: "+str(c().get("slots",{}).get(quote.slot,quote.slot))+" / 外した装備は本人のインベントリへ入ります。")
	var stale=quote.get("token")!=c().get("inventoryToken")
	if stale:l(parent,"所持品や対象の状態が変わりました。戻って選び直してください。")
	var actions=ui.row(parent)
	b(actions,"取り消す",func():stage="actions";quote={};redraw()).name="InventoryCancel"
	ui.primary(b(actions,verb,commit,stale)).name="InventoryConfirm"

func commit():
	if not available() or stage!="confirm" or quote.get("token")!=c().get("inventoryToken"):return
	var confirmed=quote.duplicate(true);stage="pending";generation+=1
	var ticket=generation;var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation
	redraw()
	var reply=await ui.update({"op":"campaign","action":"inventoryAction","args":[confirmed.ownerId,confirmed.itemId,confirmed.action,confirmed.targetId,confirmed.count,confirmed.slot,confirmed.token]})
	if ticket!=generation or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation or ui.closing:return
	if reply.get("connection_lost",false):stage="unknown";redraw();return
	if not reply.get("ok",false):
		await ui.update({"op":"view"})
		if ticket!=generation or epoch!=ui.pages.epoch or connection!=ui.engine.connection_generation or ui.closing:return
	stage="list" if reply.get("ok",false) else "actions";quote={}
	message="操作が完了しました。" if reply.get("ok",false) else str(reply.get("error","状態を再確認してください"))
	redraw()
