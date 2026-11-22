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
 await game.new_game();
 game.audio.fast_mode=true;game.checks_fast=true
 var owner="character_mirei"
 var seed=await saved();seed.state.location="east";seed.state.gold=1000;seed.state.characters[owner].inventory={"sword-wood":3};seed.state.characters[owner].xp=100;seed.state.characters[owner].level=2;seed.state.characters[owner].allocations.agi=1;seed.state.characters[owner].statPoints=1;seed.state.characters[owner].skillPoints=1;seed.state.characters[owner].weapon="hammer-wood";seed.state.characters[owner].leftHand="empty-leftHand"
 await game.update({"op":"campaign_load","data":seed});await enter_facility("shop")
 var shop=game.pages.shop_view
 game.shop_uid=owner;shop.open_comparison("dagger-steel");var comparison=shop.comparison_view;await wait_quote()
 check(not node("ShopComparisonStats").text.contains("対象：") and node("ShopComparisonEffects")==null,"comparison removes duplicate target and base-stat lines")
 check(node("ShopComparisonConditions").text.contains("スカウト専用") and not node("ShopComparisonConditions").text.contains("ポーター専用"),"steel dagger reports its actual scout condition")
 var compared_gear=comparison.item()
 var compared_note=node("ShopComparisonNotes")
 check(node("ShopComparisonFlavor").text==compared_gear.flavor and (compared_gear.get("note","").is_empty() and compared_note==null or is_instance_valid(compared_note) and compared_note.text==compared_gear.note),"shop comparison displays flavor and shows an original note only when defined")
 check(node("ShopComparisonBuy").text=="1個購入する" and node("ShopComparisonPayment").text.contains("購入 400G") and not node("ShopComparisonBuy").disabled,"ineligible equipment can still be purchased into inventory")
 check(node("ShopComparisonBuy").get_parent()==node("ShopTransactionFooter") and not game.modal_open(),"inline purchase button stays in transaction footer outside scroller")
 var icons=node("ShopComparisonSkills").find_children("ComparisonSkill*","Button",true,false)
 check(icons.size()>=2 and icons.all(func(b):return b.icon!=null and b.text.begins_with("Lv") and b.tooltip_text.contains("付与枠")),"gained and lost skills have icons and level/detail hover")
 check(comparison.removed_sources([{"id":"skill_ambush","level":1},{"id":"skill_ambush","level":1}],[{"id":"skill_ambush","level":1}]).size()==1,"duplicate grant removal is counted independently")
 check(comparison.removed_sources([{"id":"skill_ambush","level":3}],[{"id":"skill_ambush","level":2}]).size()==1,"different levels remain distinct")
 var inline_button=node("ShopComparisonBuy");var footer_rect=inline_button.get_global_rect()
 node("ShopTransactionScroll").scroll_vertical=100;await frames(10)
 check(inline_button.get_global_rect()==footer_rect and Rect2(Vector2.ZERO,Vector2(root.size)).encloses(footer_rect),"FHD inline purchase stays visible while details scroll")
 var before=await saved()
 await click("ShopComparisonBuy");await settle()
 check(not game.modal_open() and game.save_notice.visible and game.save_notice.caption.text=="%sへ %s×1 / 支払%dG" % [game.member_name(owner),shop.receipt.gear.name,int(shop.receipt.cost)],"purchase completion shows recipient/item/count/payment without blocking")
 var after=await saved();check(after.state.gold==600 and after.state.characters[owner].inventory.get("dagger-steel")==1 and after.state.characters[owner].weapon==before.state.characters[owner].weapon,"purchase debits once without auto-equipping")
 await create_timer(0.6).timeout;check(node("CampaignHeader").find_children("*","Label",true,false).any(func(label):return label.text=="600 G"),"visible campaign balance matches the completed purchase")
 shop.owner_pressed(owner);await settle()
 check(node("ShopExit")!=null and node("ShopExit").is_visible_in_tree(),"combined trading workspace has a visible transaction exit")
 check(node("ShopTransaction").get_theme_stylebox("panel").bg_color==Color("#faf9f5"),"combined trading workspace uses the approved neutral paper surface")
 shop.sale.select_item("sword-wood");await wait_quote();node("FacilitySaleQuantity").value=2;await wait_quote();var quote=shop.sale.quote.duplicate(true);before=await saved()
 await click("FacilitySalePrepare");node("FacilitySaleConfirmation").canceled.emit();node("FacilitySaleConfirmation").hide();await settle()
 check(await saved()==before,"sale NO preserves quantity and gold")
 await click("FacilitySalePrepare");await click("FacilitySaleConfirm");await wait_quote();after=await saved()
 check(after.state.gold==quote.afterGold and after.state.characters[owner].inventory["sword-wood"]==1,"sale panel commits exact count and money")
 var once=await saved();shop.sale.commit(quote,shop.sale.generation,game.pages.epoch,game.engine.connection_generation);await settle();check(await saved()==once,"repeated sale callback cannot apply twice")
 await click("ShopExit");check(game.pages.facility_entry.at_top(),"transaction exit returns to facility entry")
 await click("FacilityChoice_buy");await click("ShopExit");check(game.pages.facility_entry.at_top(),"repeated trading entry and exit returns safely")
 await click("FacilityExit");check(game.page=="hub","facility exit returns to town")
 seed.state.gold=0;await game.update({"op":"campaign_load","data":seed});await enter_facility("shop");shop.open_comparison("dagger-steel");await wait_quote()
 check(node("ShopComparisonBuy").disabled and node("ShopComparisonBuy").get_theme_stylebox("disabled").bg_color==Color("#e8e9e3") and not node("ShopComparisonBuy").tooltip_text.is_empty() and node("ShopComparisonPayment").text.contains("購入不可"),"insufficient funds disable purchase with visible reason and neutral disabled state")
 check(game.audio.muted.values().all(func(v):return v),"audio3 OFF")
 game.dialog.close(false);game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames()
 var failed=checks.filter(func(c):return not c.passed);print("SHOP_FEEDBACK30 "+str(checks.size()-failed.size())+"/"+str(checks.size()));quit(1 if failed.size() else 0)
