extends RefCounted
## Read-only canonical quotes; purchase still uses the existing consent flow.
var shop_ref: WeakRef
var shop:
	get:return shop_ref.get_ref()
var ui
var item_id := ""
var owner_id := ""
var slot := ""
var generation := 0
var money_label
var comparison_label
var condition_label
var buy_button
func _init(owner):shop_ref=weakref(owner);ui=owner.ui
func invalidate():generation+=1
func item() -> Dictionary:
	for gear in shop.c().get("shop",[]):
		if gear.id==item_id:return gear
	return {}
func slots_for(gear: Dictionary) -> Array:
	return gear.get("allowedSlots",["rightHand"] if gear.get("hands",1)==2 else ["rightHand","leftHand"] if gear.slot=="weapon" else ["upperBody"] if gear.slot=="armor" else [gear.slot])
func open(id: String):
	item_id=id
	var gear=item()
	if gear.is_empty():return
	if not shop.c().get("selected",[]).has(ui.shop_uid):ui.shop_uid=str(shop.c().selected[0])
	owner_id=ui.shop_uid
	var slots=slots_for(gear)
	slot=ui.shop_slot if slots.has(ui.shop_slot) else str(slots[0])
	ui.dialog.open("商品と装備の比較",func(_body,actions):
		ui.local_button(actions,"商品一覧へ戻る",ui.dialog.close).name="ShopComparisonBack",
		invalidate)
	render()
func render():
	generation+=1
	var body=ui.dialog.body;ui.clear(body)
	var gear=item()
	if gear.is_empty():ui.dialog.close();return
	var title=ui.label_(body,str(gear.name),true);title.name="ShopComparisonProduct"
	var selectors=ui.row(body)
	ui.label_(selectors,"対象")
	var people=OptionButton.new();people.name="ShopComparisonOwner";people.fit_to_longest_item=false;people.clip_text=true;people.size_flags_horizontal=Control.SIZE_EXPAND_FILL;people.custom_minimum_size.x=150;selectors.add_child(people)
	for uid in shop.c().selected:
		people.add_item(ui.member_name(str(uid)));people.set_item_metadata(people.item_count-1,uid)
		if uid==owner_id:people.select(people.item_count-1)
	people.item_selected.connect(func(i):switch_target(str(people.get_item_metadata(i)),slot))
	var slots=slots_for(gear)
	var positions=OptionButton.new();positions.name="ShopComparisonSlot";positions.size_flags_horizontal=Control.SIZE_EXPAND_FILL;positions.custom_minimum_size.x=130;selectors.add_child(positions)
	for id in slots:
		positions.add_item(str(shop.c().get("slots",{}).get(id,id)));positions.set_item_metadata(positions.item_count-1,id)
		if id==slot:positions.select(positions.item_count-1)
	positions.item_selected.connect(func(i):switch_target(owner_id,str(positions.get_item_metadata(i))))
	var money=ui.label_(body,"費用を確認中…");money.name="ShopComparisonPayment"
	var comparison=RichTextLabel.new();comparison.name="ShopComparisonStats";comparison.bbcode_enabled=true;comparison.fit_content=true;comparison.scroll_active=false;comparison.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(comparison);comparison.text="比較を読み込み中…"
	ui.label_(body,"装備の基礎能力："+shop.product_summary(gear)).name="ShopComparisonEffects"
	for grant in preload("res://equipment_grants.gd").list(gear):
		var id=str(grant.id)
		var copy=preload("res://skill_text.gd")
		ui.label_(body,copy.plain(copy.document(id,str(shop.c().get("skillNames",{}).get(id,id)),int(grant.get("level",1)),shop.c(),gear))).name="ShopComparisonSkill_"+id+"_"+str(grant.get("slotNo",1))
	var conditions=ui.label_(body,"条件を確認中…");conditions.name="ShopComparisonConditions"
	ui.label_(body,"補足：装備した場合の比較です。購入では自動装備しません。受取可否は購入確定時に確認します。")
	if gear.has("note") and not str(gear.note).is_empty():
		ui.label_(body,"装備メモ（原文）\n"+str(gear.note)).name="ShopComparisonNotes"
	var buy=ui.button(body,ui.member_name(owner_id)+"への購入を確認",purchase,true);buy.name="ShopComparisonBuy"
	money_label=money;comparison_label=comparison;condition_label=conditions;buy_button=buy
	refresh(money,comparison,conditions,buy)
func switch_target(uid: String,position: String):
	generation+=1;owner_id=uid;slot=position;ui.shop_uid=uid;ui.shop_slot=position
	# Keep the selectors alive: replacing an open popup can replay Enter on the
	# new control and lose keyboard focus. Clear old values before any request.
	comparison_label.text="比較を読み込み中…";money_label.text="費用を確認中…";condition_label.text="条件を確認中…"
	buy_button.text=ui.member_name(uid)+"への購入を確認";buy_button.disabled=true
	refresh(money_label,comparison_label,condition_label,buy_button)
func valid(ticket: int,window,epoch: int,connection: int,token) -> bool:
	return ticket==generation and is_instance_valid(window) and window==ui.dialog.window and ui.page=="shop" and not ui.closing and epoch==ui.pages.epoch and connection==ui.engine.connection_generation and token==shop.c().get("inventoryToken")
func refresh(money,comparison,conditions,buy):
	var ticket=generation;var window=ui.dialog.window;var epoch=ui.pages.epoch;var connection=ui.engine.connection_generation;var token=shop.c().get("inventoryToken")
	while ui.engine.busy:
		await ui.get_tree().process_frame
		if not valid(ticket,window,epoch,connection,token):return
	var reply=await ui.engine.request({"op":"campaign","action":"previewGear","args":[owner_id,item_id,slot]})
	if not valid(ticket,window,epoch,connection,token):return
	if ui.handle_connection_loss(reply,connection):return
	var q=reply.get("previewGear")
	if not q is Dictionary or not q.has("before"):
		comparison.text="比較を取得できません。商品一覧へ戻って選び直してください。";conditions.text="条件：未確認";return
	var person={}
	for u in ui.roster():
		if u.id==owner_id:person=u;break
	var entry={"name":item().name,"equipSlots":[]}
	comparison.text=ui.pages.party_view.owned_equipment_view.comparison(person,entry,slot,q)
	conditions.text="条件：装備可能" if q.get("eligible",false) else "条件：装備不可 / "+str(q.get("reason","正規判定を確認できません"))
	var payment=await ui.engine.request({"op":"campaign","action":"purchaseQuote","args":[item_id]})
	if not valid(ticket,window,epoch,connection,token):return
	if ui.handle_connection_loss(payment,connection):return
	var cost=payment.get("purchaseQuote",{})
	if cost.is_empty():money.text="費用を取得できません。";return
	money.text="1個 / 支払 %dG / 所持金 %d → 購入後 %dG" % [cost.cost,cost.goldBefore,cost.afterGold] if cost.get("ok",false) else "購入不可："+str(cost.reason)+" / 価格 %dG / 所持金 %dG" % [cost.cost,cost.goldBefore]
	buy.disabled=not cost.get("ok",false) or shop.busy()
func purchase():
	if shop.busy():return
	var id=item_id;var uid=owner_id
	invalidate();ui.dialog.close(false)
	shop.confirm_purchase(id,uid)
