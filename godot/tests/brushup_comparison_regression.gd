extends "res://tests/owned_equipment_regression.gd"
var out=OS.get_environment("INVENTORY_QA_ROOT")
func select_with_details(name_: String):
 await tap(name_)
 await tap("SkillDetailsBack")
# Owner identity belongs to the shared roster; the compact body omits it.
# Fetch an independent canonical preview for the requested owner, not the shop's
# cached response, and compare the complete displayed result against that oracle.
func expected_comparison(uid: String,position: String="rightHand"):
 var q=(await game.engine.request({"op":"campaign","action":"previewGear","args":[uid,"spear-wood",position]})).previewGear
 var person={}
 for u in game.roster():
  if u.id==uid:person=u;break
 return game.pages.shop_view.comparison_view.comparison_text(person,{"name":"木製の片手槍","equipSlots":[]},position,q).replace("#8ee6ab","#277242").replace("#ffb1a6","#a84432").replace("#d5dbe2","#6e786f")
func selected_owner_is(uid: String) -> bool:
 return game.shop_uid==uid and game.pages.shop_view.comparison_view.owner_id==uid and node("RosterMember_"+uid)!=null
func run():
 create_timer(150).timeout.connect(func():print("FAIL comparison watchdog");quit(2))
 if out.is_empty() or not OS.get_user_data_dir().begins_with(out+"/"):quit(2);return
 root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 await game.new_game();
 game.checks_fast=true;game.audio.fast_mode=true
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"BGM voice SE remain OFF")
 var original=await saved();var seed=original.duplicate(true);seed.state.location="east";seed.state.gold=500
 seed.state.characters["character_mirei"].inventory={"potion":2,"spear-wood":3,"swift-boots":1}
 # Real carrying equipment supplies the space needed by this commerce boundary.
 seed.state.characters["character_mirei"].accessory2="pouch-belt-3"
 for dims in [Vector2i(1920,1080)]:
  root.size=dims;await game.update({"op":"campaign_load","data":seed});await enter_facility("shop");await settle()
  game.shop_uid="character_mirei";game.shop_slot="rightHand"
  var before=await saved();var shop=game.pages.shop_view
  await tap("Product_spear-wood")
  check(not game.modal_open(),"product selection stays inline without SkillDetailsWindow popup")
  var rect=node("ShopTransaction").get_global_rect()
  var guard_expected=await expected_comparison("character_mirei")
  check(selected_owner_is("character_mirei") and node("ShopComparisonProduct").text=="木製の片手槍" and node("ShopComparisonStats").text==guard_expected,"shared roster owner and product match canonical guard comparison "+str(dims.x))
  check(node("ShopComparisonPayment").text=="所持金 500 G − 購入 90 G = 残金 410 G","purchaseQuote supplies exact payment")
  var canonical=(await game.engine.request({"op":"campaign","action":"previewGear","args":["character_mirei","spear-wood","rightHand"]})).previewGear
  var shown=node("ShopComparisonStats").text
  check(shown.contains("26 → 23") and shown.contains("(+1)") and shown.contains("(-3)"),"canonical numeric changes include arrows and signed deltas")
  var columns=node("ShopComparisonSkills").get_children()
  var current_atk=int(canonical.current.atk)
  var spear_atk=int(canonical.gear.atk)
  var before_stat="物理ATK：%d" % current_atk
  var after_stat="物理ATK：%d（↓%d）" % [spear_atk,current_atk-spear_atk]
  check(columns[0].find_children("*","Label",true,false).any(func(label):return label.is_visible_in_tree() and label.text==before_stat) and columns[1].find_children("*","Label",true,false).any(func(label):return label.is_visible_in_tree() and label.text==after_stat),"sword to spear shows each weapon's attack and the exact decrease")
  node("RosterMember_character_merina").grab_focus();await tap("RosterMember_character_merina")
  var mage_expected=await expected_comparison("character_merina")
  check(selected_owner_is("character_merina") and mage_expected!=guard_expected and node("ShopComparisonStats").text==mage_expected,"owner switch replaces guard result with canonical mage comparison")
  check(node("RosterMember_character_merina").has_focus(),"owner keyboard focus survives rebuild")
  check(node("ShopTransaction").get_global_rect()==rect,"owner switch preserves inline transaction position and size")
  check(node("ShopComparisonSlot")==null and (await saved())==before,"weapon comparison needs no slot selector or mutation")
  await shop.confirm_purchase("spear-wood");await settle();await tap("PurchaseAgree")
  check(node("RecipientPayment").text.contains("500 → 410 G"),"original recipient flow retains money and product context")
  await tap("PurchaseRecipientCancel");check((await saved())==before,"original purchase cancellation stays pure")
  await tap("RosterMember_character_mirei");shop.open_comparison("greatsword-wood");await settle()
  check(node("ShopComparisonConditions").text.contains("装備不可") and node("ShopComparisonConditions").text.contains("左手"),"canonical two-hand restriction shown")
  check(not node("ShopComparisonBuy").disabled,"inventory purchase independent from equipment restriction")
  await tap("Product_spear-wood")
  check(not game.modal_open(),"product selection stays inline without SkillDetailsWindow popup");await tap("ShopComparisonBuy")
  check(not game.modal_open() and game.save_notice.visible and game.save_notice.caption.text=="%sへ 木製の片手槍×1 / 支払 90 G" % game.member_name("character_mirei"),"purchase completion is a non-modal recipient/item/count/payment notice")
  check(int(game.campaign().gold)==410 and int(game.campaign().characters["character_mirei"].inventory["spear-wood"])==4,"confirmed purchase matches displayed amount and exact owner")
  var bought=await saved();await shop.buy(shop.receipt,"character_mirei",shop.generation)
  check((await saved())==bought,"repeated purchase callback cannot charge twice")
  await tap("ShopInventoryTab_inventory");await tap("SaleItem_spear-wood")
  node("FacilitySaleQuantity").value=2;await settle()
  check(shop.sale.quote.get("ownerId")=="character_mirei" and shop.sale.quote.get("count")==2 and shop.sale.quote.get("afterGold")==590 and node("FacilitySaleTotals").text.contains("590"),"quantity change displays canonical owner proceeds and final gold")
  check((await saved())==bought,"quantity and sale preview do not mutate state")
  await tap("FacilitySalePrepare");await tap("FacilitySaleCancel")
  check((await saved())==bought,"sale cancellation preserves owner and inventory")
  await tap("FacilitySalePrepare");await tap("FacilitySaleConfirm")
  check(int(game.campaign().gold)==590 and int(game.campaign().characters["character_mirei"].inventory["spear-wood"])==2,"sale confirmed total matches preview")
  await tap("RosterMember_character_merina")
  check(node("FacilitySaleTotals")==null and node("SaleItem_spear-wood")==null,"owner switch removes previous sale target and values")
  game.dialog.close();await settle()
  var poor=seed.duplicate(true);poor.state.gold=0;await game.update({"op":"campaign_load","data":poor});await enter_facility("shop");await settle()
  shop.open_comparison("spear-wood");await settle()
  check(node("ShopComparisonPayment").text.contains("所持金が不足") and node("ShopComparisonBuy").disabled,"insufficient money reason uses canonical purchaseQuote")
  check(node("ShopComparisonStats").text.contains("→"),"equipment comparison remains available without funds")
  game.dialog.close();await settle()
 # Hold the first canonical response, switch owner, then release it.
 await game.update({"op":"campaign_load","data":seed});await enter_facility("shop");await settle()
 var actual=game.engine;var delayed=DelayedEngine.new();delayed.actual=actual;game.add_child(delayed);game.engine=delayed
 game.shop_uid="character_mirei";game.pages.shop_view.open_comparison("spear-wood")
 while not delayed.held:await process_frame
 node("RosterMember_character_merina").grab_focus();await tap("RosterMember_character_merina")
 var mage_expected=await expected_comparison("character_merina",game.shop_slot)
 var guard_expected=await expected_comparison("character_mirei",game.shop_slot)
 var latest=node("ShopComparisonStats").text
 check(selected_owner_is("character_merina") and latest==mage_expected and latest!=guard_expected,"new owner canonical result is shown while old response is held")
 delayed.release=true;await settle()
 check(not delayed.held and selected_owner_is("character_merina") and node("ShopComparisonStats").text==mage_expected and node("ShopComparisonStats").text!=guard_expected,"released old owner response cannot overwrite current canonical comparison")
 game.engine=actual;delayed.queue_free();game.dialog.close();await settle()
 # Canonical purchaseQuote cannot predict a chosen recipient's save-size limit.
 # The UI labels confirmation, and rejection must remain atomic and repeat-safe.
 var upper=seed.duplicate(true);upper.state.characters["character_mirei"].inventory["spear-wood"]=10000000000
 check((await game.update({"op":"campaign_load","data":upper})).get("ok",false),"canonical maximum stock fixture loads")
 await enter_facility("shop");game.shop_uid="character_mirei";await settle();var upper_before=await saved()
 game.pages.shop_view.open_comparison("spear-wood");await settle();await tap("ShopComparisonBuy")
 check((await saved())==upper_before and game.pages.shop_view.stage=="S0" and not game.pages.shop_view.message.is_empty(),"recipient save-limit rejection preserves exact state and returns to actionable list")
 var south=original.duplicate(true);south.state.location="south";south.state.gold=500
 await game.update({"op":"campaign_load","data":south});await enter_facility("shop");await settle()
 await tap("RosterMember_character_mirei");await tap("Product_potion");node("ShopPurchaseQuantity").value=5;await settle()
 check(game.pages.shop_view.purchase_quantity==5 and node("ShopComparisonPayment").text=="所持金 500 G − 購入 200 G = 残金 300 G","five potions show the exact cost and remaining funds")
 var quantity_before=await saved();await tap("ProductBuy_potion_1")
 check((await saved())==quantity_before,"quantity purchase consent leaves full save unchanged")
 await tap("PurchaseDecline");check((await saved())==quantity_before,"quantity purchase decline leaves full save unchanged")
 await tap("ProductBuy_potion_1");var agree=node("PurchaseAgree");agree.pressed.emit();agree.pressed.emit();await settle();var quantity_after=await saved()
 check(quantity_after.state.gold==300 and int(quantity_after.state.characters["character_mirei"].inventory.get("potion",0))==int(quantity_before.state.characters["character_mirei"].inventory.get("potion",0))+5,"displayed five-item cost and remainder match canonical committed purchase exactly once")
 var quantity_expected=quantity_before.duplicate(true);quantity_expected.state.gold=300;quantity_expected.state.characters["character_mirei"].inventory.potion=int(quantity_before.state.characters["character_mirei"].inventory.get("potion",0))+5
 var potion=game.campaign().shop.filter(func(item):return item.id=="potion")[0]
 quantity_expected.state.history.append(game.member_name("character_mirei")+"が"+str(potion.name)+"を5個購入。")
 if quantity_expected.state.history.size()>200:quantity_expected.state.history.pop_front()
 # Engine saves arrive through JSON with numeric variants normalized.
 check(quantity_after==JSON.parse_string(JSON.stringify(quantity_expected)),"quantity purchase changes only selected owner stock and gold in complete save")
 var full=south.duplicate(true);full.state.characters["character_mirei"].inventory.potion=99
 await game.update({"op":"campaign_load","data":full});await enter_facility("shop");await settle();await tap("Product_potion");node("ShopPurchaseQuantity").value=5;await settle()
 check(node("ProductBuy_potion_1").disabled and node("ProductBuy_potion_1").tooltip_text.contains("上限"),"consumable cap uses existing 99 stock rule and explains disabled action")
 var full_before=await saved();await game.pages.shop_view.confirm_purchase("potion","character_mirei");await settle();check((await saved())==full_before and not game.modal_open(),"programmatic over-cap purchase preserves full save")
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"all checks kept three sound categories muted")
 var f=FileAccess.open(out.path_join("brushup-comparison-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
