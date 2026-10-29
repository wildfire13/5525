extends "res://tests/ui_feedback_20261016.gd"
func wait_quote():
 await settle()
 while game.engine.busy or game.pages.shop_view.sale.previewing:await process_frame
 await frames(10)
func run():
 create_timer(180).timeout.connect(func():push_error("shop feedback watchdog");quit(2))
 if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
 root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 await preload("res://tests/current_historical_fixture.gd").install(game)
 game.audio.fast_mode=true;game.checks_fast=true
 var seed=await saved();seed.state.location="east";seed.state.gold=1000;seed.state.characters.guard.inventory={"sword-wood":3};seed.state.characters.guard.xp=100;seed.state.characters.guard.level=2;seed.state.characters.guard.allocations.agi=1;seed.state.characters.guard.statPoints=1;seed.state.characters.guard.skillPoints=1;seed.state.characters.guard.weapon="hammer-wood";seed.state.characters.guard.leftHand="empty-leftHand"
 await game.update({"op":"campaign_load","data":seed});await enter_facility("shop")
 var shop=game.pages.shop_view
 game.shop_uid="guard";shop.open_comparison("dagger-steel");var comparison=shop.comparison_view;await wait_quote()
 check(not node("ShopComparisonStats").text.contains("対象：") and node("ShopComparisonEffects")==null,"comparison removes duplicate target and base-stat lines")
 check(node("ShopComparisonConditions").text.contains("スカウト専用") and not node("ShopComparisonConditions").text.contains("ポーター専用"),"steel dagger reports its actual scout condition")
 check(node("ShopComparisonBuy").text=="400Gで購入する" and not node("ShopComparisonBuy").disabled,"ineligible equipment can still be purchased into inventory")
 check(node("ShopComparisonBuy").get_parent()==game.dialog.actions and node("ShopComparisonBuy").icon!=null,"compact icon purchase button stays outside scroller")
 var icons=node("ShopComparisonSkills").find_children("ComparisonSkill*","Button",true,false)
 check(icons.size()>=2 and icons.all(func(b):return b.icon!=null and b.text.begins_with("Lv") and b.tooltip_text.contains("付与枠")),"gained and lost skills have icons and level/detail hover")
 check(comparison.removed_sources([{"id":"scout","level":1},{"id":"scout","level":1}],[{"id":"scout","level":1}]).size()==1,"duplicate grant removal is counted independently")
 check(comparison.removed_sources([{"id":"scout","level":3}],[{"id":"scout","level":2}]).size()==1,"different levels remain distinct")
 for dims in [Vector2i(1920,1080),Vector2i(1180,812),Vector2i(960,540)]:
  root.size=dims;game.dialog.resize();await frames(15)
  var button=node("ShopComparisonBuy");check(Rect2(Vector2.ZERO,Vector2(game.dialog.window.size)).encloses(button.get_global_rect()),str(dims)+" purchase visible without scrolling")
  if dims.x==1920:check(game.dialog.window.size.x>=1280,"comparison wider at FHD")
 root.size=Vector2i(1920,1080);game.dialog.resize();var before=await saved();await click("ShopComparisonBuy");await click("PurchaseDecline")
 check(await saved()==before,"purchase cancellation changes no stock/money/equipment")
 comparison.open("dagger-steel");await wait_quote();await click("ShopComparisonBuy");await click("PurchaseAgree");await settle()
 var after=await saved();check(after.state.gold==600 and after.state.characters.guard.inventory.get("dagger-steel")==1 and after.state.characters.guard.weapon==before.state.characters.guard.weapon,"purchase debits once without auto-equipping")
 await create_timer(0.6).timeout;check(game.gold_header.text=="600G","money count-down ends at canonical balance")
 game.pages.facility_entry.back();await settle();await click("FacilityChoice_sell");shop.owner_pressed("guard");await settle()
 check(node("FacilitySaleClose")!=null and node("FacilitySaleEnd")!=null,"sale panel has both close and bottom exit")
 check(node("FacilitySalePanel").get_theme_stylebox("panel").bg_color==Color("#1e232bed"),"sale panel neutral, not blue selection")
 shop.sale.select_item("sword-wood");await wait_quote();node("FacilitySaleQuantity").value=2;await wait_quote();var quote=shop.sale.quote.duplicate(true);before=await saved()
 await click("FacilitySalePrepare");node("FacilitySaleConfirmation").canceled.emit();node("FacilitySaleConfirmation").hide();await settle()
 check(await saved()==before,"sale NO preserves quantity and gold")
 await click("FacilitySalePrepare");await click("FacilitySaleConfirm");await wait_quote();after=await saved()
 check(after.state.gold==quote.afterGold and after.state.characters.guard.inventory["sword-wood"]==1,"sale panel commits exact count and money")
 var once=await saved();shop.sale.commit(quote,shop.sale.generation,game.pages.epoch,game.engine.connection_generation);await settle();check(await saved()==once,"repeated sale callback cannot apply twice")
 game.pages.party_view.open_detail("guard");await settle();await click("OwnedInventorySell_sword-wood");await wait_quote()
 check(node("InventoryPrepareSale")!=null,"status inventory also exposes sale confirmation")
 before=await saved();await click("InventoryPrepareSale");await click("InventoryCancel");check(await saved()==before,"status sale cancel pure")
 await click("InventoryPrepareSale");await click("InventoryConfirm");await wait_quote();after=await saved()
 check(after.state.characters.guard.inventory.get("sword-wood",0)==0 and after.state.gold==before.state.gold+70,"status sale commits once and refreshes shared inventory")
 game.dialog.close();await settle();check(node("SaleRow_sword-wood")==null,"background sale panel removes status-sold item")
 await click("TownReturn");check(game.pages.facility_entry.at_top(),"background return exits sale")
 for exit_name in ["FacilitySaleClose","FacilitySaleEnd"]:
  await click("FacilityChoice_sell");await click(exit_name);check(game.pages.facility_entry.at_top(),exit_name+" returns to facility top")
 seed.state.gold=0;await game.update({"op":"campaign_load","data":seed});await enter_facility("shop");comparison.open("dagger-steel");await wait_quote()
 check(node("ShopComparisonBuy").disabled and node("ShopComparisonBuy").get_theme_stylebox("disabled").bg_color==Color("#783b3b"),"insufficient-money purchase is disabled red")
 check(game.audio.muted.values().all(func(v):return v),"audio3 OFF")
 game.dialog.close(false);game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames()
 var failed=checks.filter(func(c):return not c.passed);print("SHOP_FEEDBACK30 "+str(checks.size()-failed.size())+"/"+str(checks.size()));quit(1 if failed.size() else 0)
