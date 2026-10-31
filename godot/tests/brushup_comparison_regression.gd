extends "res://tests/owned_equipment_regression.gd"
class DisconnectEngine extends DelayedEngine:
 func request(payload):
  if payload.get("action")=="previewGear":return actual._disconnect("synthetic-preview-loss")
  return await actual.request(payload)
var out=OS.get_environment("INVENTORY_QA_ROOT")
func select_option(name_: String,value: String):
 var chooser=node(name_)
 chooser.grab_focus()
 for i in range(chooser.item_count):
  if str(chooser.get_item_metadata(i))==value:
   chooser.select(i);chooser.item_selected.emit(i);await settle();return
 check(false,"option exists "+name_+" "+value)
# Owner identity belongs to the selector; the compact body deliberately omits it.
# Fetch an independent canonical preview for the requested owner, not the shop's
# cached response, and compare the complete displayed result against that oracle.
func expected_comparison(uid: String,position: String="rightHand"):
 var q=(await game.engine.request({"op":"campaign","action":"previewGear","args":[uid,"spear-wood",position]})).previewGear
 var person={}
 for u in game.roster():
  if u.id==uid:person=u;break
 return game.pages.party_view.owned_equipment_view.comparison(person,{"name":"木製の片手槍","equipSlots":[]},position,q,true)
func selected_owner_is(uid: String) -> bool:
 var chooser=node("ShopComparisonOwner")
 return str(chooser.get_selected_metadata())==uid and chooser.get_item_text(chooser.selected)==game.member_name(uid)
func run():
 create_timer(150).timeout.connect(func():print("FAIL comparison watchdog");quit(2))
 if out.is_empty() or not OS.get_user_data_dir().begins_with(out+"/"):quit(2);return
 root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 await preload("res://tests/current_historical_fixture.gd").install(game)
 game.checks_fast=true;game.audio.fast_mode=true
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"BGM voice SE remain OFF")
 var original=await saved();var seed=original.duplicate(true);seed.state.location="east";seed.state.gold=500
 seed.state.characters.guard.inventory={"potion":2,"spear-wood":3,"swift-boots":1}
 for dims in [Vector2i(1920,1080)]:
  root.size=dims;await game.update({"op":"campaign_load","data":seed});await enter_facility("shop");await settle()
  game.shop_uid="guard";game.shop_slot="rightHand"
  var before=await saved();var shop=game.pages.shop_view
  await tap("Product_spear-wood")
  var window=game.dialog.window;var rect=Rect2(Vector2(window.position),Vector2(window.size))
  var guard_expected=await expected_comparison("guard")
  check(selected_owner_is("guard") and node("ShopComparisonProduct").text=="木製の片手槍" and node("ShopComparisonStats").text==guard_expected,"owner selector and product match canonical guard comparison "+str(dims.x))
  check(node("ShopComparisonPayment").text.contains("500 → 購入後 410G"),"purchaseQuote supplies exact payment")
  var canonical=(await game.engine.request({"op":"campaign","action":"previewGear","args":["guard","spear-wood","rightHand"]})).previewGear
  var shown=node("ShopComparisonStats").text
  check(shown.contains("26 → 23") and shown.contains("(+1)") and shown.contains("(-3)"),"canonical numeric changes include arrows and signed deltas")
  check(canonical.after.attackWeapons[0].atk==23,"comparison checked against canonical attack stats")
  await select_option("ShopComparisonOwner","mage")
  var mage_expected=await expected_comparison("mage")
  check(selected_owner_is("mage") and mage_expected!=guard_expected and node("ShopComparisonStats").text==mage_expected,"owner switch replaces guard result with canonical mage comparison")
  check(node("ShopComparisonOwner").has_focus(),"owner keyboard focus survives rebuild")
  check(Rect2(Vector2(window.position),Vector2(window.size))==rect,"owner switch preserves window position and size")
  await select_option("ShopComparisonSlot","leftHand")
  check(node("ShopComparisonStats").text.contains("左手") and node("ShopComparisonSlot").has_focus(),"slot switch replaces context and keeps focus")
  check((await saved())==before,"preview owners and slots have no campaign side effects")
  await tap("ShopComparisonBuy")
  check(node("PurchasePayment").text.contains("500 → 410G") and game.dialog.body.get_child_count()>0,"comparison purchase preserves canonical payment consent")
  check(game.dialog.body.get_children().any(func(n):return n is Label and n.text.contains("ミオのインベントリ")),"recipient is named before confirmation")
  await tap("PurchaseDecline");check((await saved())==before,"decline changes no inventory gold equipment or save")
  await shop.confirm_purchase("spear-wood");await settle();await tap("PurchaseAgree")
  check(node("RecipientPayment").text.contains("500 → 410G"),"original recipient flow retains money and product context")
  await tap("PurchaseRecipientCancel");check((await saved())==before,"original purchase cancellation stays pure")
  game.shop_uid="guard";shop.open_comparison("greatsword-wood");await settle()
  check(node("ShopComparisonConditions").text.contains("装備不可") and node("ShopComparisonConditions").text.contains("左手"),"canonical two-hand restriction shown")
  check(not node("ShopComparisonBuy").disabled,"inventory purchase independent from equipment restriction")
  await tap("ShopComparisonBack")
  shop.open_comparison("spear-wood");await settle();await tap("ShopComparisonBuy");await tap("PurchaseAgree")
  check(int(game.campaign().gold)==410 and int(game.campaign().characters.guard.inventory["spear-wood"])==4,"confirmed purchase matches displayed amount and exact owner")
  var bought=await saved();await shop.buy(shop.receipt,"guard",shop.generation)
  check((await saved())==bought,"repeated purchase callback cannot charge twice")
  game.pages.party_view.open_detail("guard");await settle();await tap("OwnedInventorySell_spear-wood")
  var quantity=node("InventoryQuantity");quantity.value=2;await settle()
  check(node("InventorySaleTotals").text.contains("ガロ") and node("InventorySaleTotals").text.contains("×2") and node("InventorySaleTotals").text.contains("410 → 売却後 590G"),"quantity change displays canonical owner proceeds and final gold")
  check((await saved())==bought,"quantity and sale preview do not mutate state")
  await tap("InventoryPrepareSale");await tap("InventoryCancel")
  check((await saved())==bought,"sale cancellation preserves owner and inventory")
  game.pages.party_view.inventory_view.choose_sale("spear-wood");await settle();node("InventoryQuantity").value=2;await settle();await tap("InventoryPrepareSale");await tap("InventoryConfirm")
  check(int(game.campaign().gold)==590 and int(game.campaign().characters.guard.inventory["spear-wood"])==2,"sale confirmed total matches preview")
  await tap("PartyFace_mage")
  check(node("InventorySaleTotals")==null and node("OwnedInventorySell_spear-wood")==null,"owner switch removes previous sale target and values")
  game.dialog.close();await settle()
  var poor=seed.duplicate(true);poor.state.gold=0;await game.update({"op":"campaign_load","data":poor});await enter_facility("shop");await settle()
  shop.open_comparison("spear-wood");await settle()
  check(node("ShopComparisonPayment").text.contains("所持金が不足") and node("ShopComparisonBuy").disabled,"insufficient money reason uses canonical purchaseQuote")
  check(node("ShopComparisonStats").text.contains("→"),"equipment comparison remains available without funds")
  game.dialog.close();await settle()
 # Hold the first canonical response, switch owner, then release it.
 await game.update({"op":"campaign_load","data":seed});await enter_facility("shop");await settle()
 var actual=game.engine;var delayed=DelayedEngine.new();delayed.actual=actual;game.add_child(delayed);game.engine=delayed
 game.shop_uid="guard";game.pages.shop_view.open_comparison("spear-wood")
 while not delayed.held:await process_frame
 await select_option("ShopComparisonOwner","mage")
 var mage_expected=await expected_comparison("mage",game.shop_slot)
 var guard_expected=await expected_comparison("guard",game.shop_slot)
 var latest=node("ShopComparisonStats").text
 check(selected_owner_is("mage") and latest==mage_expected and latest!=guard_expected,"new owner canonical result is shown while old response is held")
 delayed.release=true;await settle()
 check(not delayed.held and selected_owner_is("mage") and node("ShopComparisonStats").text==mage_expected and node("ShopComparisonStats").text!=guard_expected,"released old owner response cannot overwrite current canonical comparison")
 game.engine=actual;delayed.queue_free();game.dialog.close();await settle()
 # Canonical purchaseQuote cannot predict a chosen recipient's save-size limit.
 # The UI labels confirmation, and rejection must remain atomic and repeat-safe.
 var upper=seed.duplicate(true);upper.state.characters.guard.inventory["spear-wood"]=10000000000
 check((await game.update({"op":"campaign_load","data":upper})).get("ok",false),"canonical maximum stock fixture loads")
 await enter_facility("shop");game.shop_uid="guard";await settle();var upper_before=await saved()
 game.pages.shop_view.open_comparison("spear-wood");await settle();await tap("ShopComparisonBuy");await tap("PurchaseAgree")
 check((await saved())==upper_before and game.pages.shop_view.stage=="S0" and not game.pages.shop_view.message.is_empty(),"recipient save-limit rejection preserves exact state and returns to actionable list")
 var south=original.duplicate(true);south.state.location="south";south.state.gold=500
 await game.update({"op":"campaign_load","data":south});await enter_facility("shop");await settle()
 var buttons=game.find_children("*","Button",true,false)
 check(buttons.any(func(b):return b.text=="5個 / 200G\n残金 300G"),"existing consumable quantity shows total and remainder without extra click")
 var quantity_before=await saved();await tap("ProductBuy_potion_5");var quantity_after=await saved()
 check(quantity_after.state.gold==300 and int(quantity_after.state.characters.guard.inventory.get("potion",0))==int(quantity_before.state.characters.guard.inventory.get("potion",0))+5,"displayed five-item cost and remainder match canonical committed purchase for current owner")
 check(quantity_after.state.characters.archer==quantity_before.state.characters.archer and quantity_after.state.characters.guard.weapon==quantity_before.state.characters.guard.weapon,"quantity purchase changes neither another owner nor current equipment")
 var full=south.duplicate(true);full.state.characters.guard.inventory.potion=99
 await game.update({"op":"campaign_load","data":full});await enter_facility("shop");await settle()
 check(game.find_children("*","Button",true,false).any(func(b):return b.disabled and b.text.contains("5個 / 200G") and b.text.contains("上限99個")),"consumable cap uses existing stock rule and explains disabled action")
 await game.update({"op":"campaign_load","data":seed});await enter_facility("shop");await settle()
 var failed=DisconnectEngine.new();failed.actual=game.engine;game.add_child(failed);game.engine=failed
 game.pages.shop_view.open_comparison("spear-wood");await settle()
 check(game.engine.disconnected and not game.modal_open() and game.retry_button.visible,"comparison connection loss uses existing recovery UI and cannot confirm purchase")
 game.engine=failed.actual;failed.queue_free();await frames()
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"all checks kept three sound categories muted")
 var f=FileAccess.open(out.path_join("brushup-comparison-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
