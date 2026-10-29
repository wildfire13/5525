extends "res://tests/ui_feedback_20261016.gd"
func fresh_at(seed: Dictionary,place: String):
 var data=seed.duplicate(true);data.state.location=place;game.page="hub";await game.update({"op":"campaign_load","data":data});await settle()
func run():
 create_timer(180).timeout.connect(func():print("FAIL facility feedback2 watchdog");quit(2))
 if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
 root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 await preload("res://tests/current_historical_fixture.gd").install(game)
 game.checks_fast=true;game.audio.fast_mode=true;await settle();var seed=await saved();seed.state.characters.guard.inventory={"potion":8,"spear-wood":3};seed.state.characters.archer.inventory={"potion":2};seed.state.gold=1000
 var facility=game.pages.facility_entry;var shop=game.pages.shop_view
 for place in ["east","west","north","south"]:
  await fresh_at(seed,place);game.navigate("shop");await settle();var before=await saved()
  check(facility.at_top() and node("FacilityEntry")!=null and node("ShopSlotFilter")==null,"entry precedes transactions "+place)
  check(node("FacilityChoice_delivery").disabled,"delivery remains unavailable "+place)
  facility.choose("delivery");check(facility.at_top() and await saved()==before,"unimplemented entry cannot route into a real transaction "+place)
  if place!="south":check(node("FacilityChoice_upgrade").disabled,"upgrade remains unavailable "+place)
  await click("FacilityChoice_buy");check(not facility.at_top() and node("ShopSlotFilter")!=null,"buy opens existing product classification "+place)
  check(facility.return_label()=="戻る" and await saved()==before,"entering buy is presentation-only "+place)
  await click("TownReturn");check(facility.at_top() and await saved()==before,"back returns to same facility without mutation "+place)
 for page in ["inn","party"]:
  await fresh_at(seed,"astaris");game.navigate(page);await settle();check(facility.at_top() and node("FacilityEntry")!=null,"Astaris facility entry "+page)
  await click("FacilityChoice_"+("inn" if page=="inn" else "guild"));check(not facility.at_top(),"existing service opens "+page)
 await fresh_at(seed,"east");game.navigate("party");await settle();check(not facility.at_top(),"village status does not become a guild entry")
 game.navigate("shop");await settle();await click("FacilityChoice_sell");var before=await saved()
 check(shop.sale_mode() and shop.selected_owner().is_empty() and node("PurchasedInventory")==null,"sale requests bottom-bar owner, without obsolete owner button")
 check(shop.owner_pressed("guard"),"first owner press is consumed by sale selection");await settle();check(shop.selected_owner()=="guard" and node("SaleRow_spear-wood")!=null,"chosen owner's inventory replaces products")
 check(not shop.owner_pressed("guard"),"same owner second press delegates to character details")
 shop.sale.select_item("spear-wood");await settle();while shop.sale.previewing:await process_frame
 var q=shop.sale.quote;check(q.get("ok",false) and q.ownerId=="guard","sale amount is canonical owner quote")
 node("FacilitySaleQuantity").value=2;await settle();while shop.sale.previewing:await process_frame
 q=shop.sale.quote.duplicate(true);check(q.count==2 and node("FacilitySaleTotals").text.contains(str(int(q.proceeds))),"quantity and canonical total update together")
 var transfer=await game.engine.request({"op":"campaign","action":"inventoryQuote","args":["guard","potion","transfer","archer",1,null]})
 await game.update({"op":"campaign","action":"inventoryAction","args":["guard","potion","transfer","archer",1,null,transfer.inventoryQuote.token]});await settle()
 while shop.sale.previewing:await process_frame
 q=shop.sale.quote.duplicate(true);before=await saved();check(q.token==game.campaign().inventoryToken and q.count==2,"detail-side inventory mutation invalidates stale sale quote while retaining owner/item/count")
 for dims in [Vector2i(1920,1080),Vector2i(1180,812),Vector2i(960,540),Vector2i(1920,1080)]:
  root.size=dims;game.render();await frames(12)
  var panel=node("FacilitySalePanel");var back=node("TownReturnRow")
  var heading=node("FacilitySaleHeading");var font=heading.get_theme_font("font");var text_width=font.get_string_size(heading.text,HORIZONTAL_ALIGNMENT_LEFT,-1,heading.get_theme_font_size("font_size")).x
  check(heading.autowrap_mode==TextServer.AUTOWRAP_OFF and heading.size.x>=text_width,str(dims)+" short sale heading stays one horizontal line")
  check(node("FacilitySaleOwner").max_lines_visible==2 and node("FacilitySaleOwner").size_flags_horizontal==Control.SIZE_EXPAND_FILL,str(dims)+" owner name has a separate bounded wrapping region")
  check(Rect2(Vector2.ZERO,Vector2(dims)).encloses(panel.get_global_rect()) and panel.get_global_rect().end.y<=back.global_position.y+1,str(dims)+" sale panel fits above fixed return controls")
  check(Rect2(Vector2.ZERO,Vector2(dims)).encloses(node("FacilitySalePrepare").get_global_rect()),str(dims)+" quantity confirmation remains onscreen")
  if dims.x>=1120 and dims.y>=720:check(not panel.get_global_rect().intersects(node("FacilityGreeting").get_global_rect()),str(dims)+" sale list and NPC dialogue do not overlap")
 shop.sale.confirm_sale();await settle();check(shop.owner_pressed("archer") and shop.selected_owner()=="guard","confirmation consumes owner changes")
 var cancel=node("FacilitySaleConfirmation");cancel.canceled.emit();cancel.hide();await settle();check(shop.sale.stage=="selected" and await saved()==before and shop.sale.amount==2,"NO preserves amount and all resources")
 shop.sale.confirm_sale();await settle();node("FacilitySaleConfirm").pressed.emit();await settle()
 var after=await saved();check(after.state.gold==q.afterGold and after.state.characters.guard.inventory["spear-wood"]==1 and after.state.characters.archer==before.state.characters.archer,"YES sells only named owner's exact count and value")
 check(game.save_notice.visible and game.save_notice.caption.text.contains("売却"),"sale uses existing transient notification")
 shop.owner_pressed("archer");await settle();check(node("SaleRow_spear-wood")==null and shop.sale.item_id.is_empty(),"owner switch clears prior item and quote")
 await fresh_at(seed,"south");game.navigate("shop");await settle();await click("FacilityChoice_buy");before=await saved()
 await shop.purchase_consumable("potion",5);await settle();after=await saved()
 check(after.state.characters.guard.inventory.potion==before.state.characters.guard.inventory.potion+5,"tool store preserves five-item purchase")
 check(after.state.gold==before.state.gold-5*int(game.campaign().itemDefinitions.filter(func(item):return item.id=="potion")[0].price),"tool store exact canonical charge")
 check(node("ShopNotice")==null and game.save_notice.visible and node("PurchasedInventory")==null,"trade message is a toast without permanent transaction row")
 await click("TownReturn");var tool_before=await saved()
 check(node("FacilityChoice_sell").disabled and not game.campaign().saleAvailable,"tool sale remains unavailable by canonical facility eligibility")
 facility.choose("sell");var denied=await game.engine.request({"op":"campaign","action":"saleQuote","args":["guard","potion",5]})
 check(not denied.get("saleQuote",{}).get("ok",false) and not shop.sale_mode() and await saved()==tool_before,"unsupported tool sale quote remains read-only and cannot enable a sale")
 await click("FacilityChoice_buy")
 shop.show_consumable_details("potion");await settle();check(node("SkillDetailsWindow")!=null,"tool product description uses an inventory-entry adapter")
 var detail=node("SkillDetailsWindow")
 if detail!=null:detail.hide()
 for dims in [Vector2i(1920,1080),Vector2i(1180,812),Vector2i(960,540)]:
  root.size=dims;game.render();await frames(12)
  var header=node("ShopListHeader");var products=node("ShopProductsScroll").get_child(0)
  check(absf(header.get_global_rect().end.x-products.get_global_rect().end.x)<2,str(dims)+" product filter and product rows share right edge")
  check(Rect2(Vector2.ZERO,Vector2(dims)).encloses(node("ProductRow_potion").get_global_rect()),str(dims)+" tool purchase row stays onscreen")
 check(game.audio.muted.values().all(func(v):return v),"facility QA audio3 OFF")
 var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
