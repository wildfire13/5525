extends "res://tests/facility_gui_261022.gd"
## Rendered Linux/X11 plus XTest mouse and key input, synthetic fixtures only.
func os_key(key: String):
 request_id+=1
 var f=FileAccess.open(evidence.path_join("request.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"id":request_id,"action":"key","key":key}));f.close()
 var deadline=Time.get_ticks_msec()+10000
 while Time.get_ticks_msec()<deadline:
  if FileAccess.file_exists(evidence.path_join("response.json")):
   var response=JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("response.json")))
   if response is Dictionary and response.get("id")==request_id:break
  await process_frame
 check(Time.get_ticks_msec()<deadline,"OS key acknowledged "+key)
 await create_timer(.2).timeout;await settle()
func run():
 create_timer(400).timeout.connect(func():print("FAIL brushup GUI watchdog");quit(2))
 check(DisplayServer.get_name()!="headless","real X11 rendered display")
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle()
 var original=await saved();var east=original.duplicate(true);east.state.location="east";east.state.gold=500
 east.state.characters.guard.inventory={"spear-wood":3,"swift-boots":1,"potion":2}
 var operations=[]
 var widths=[Vector2i(1920,1080)]
 if not OS.get_environment("BRUSHUP_GUI_WIDTH").is_empty():widths=[Vector2i(int(OS.get_environment("BRUSHUP_GUI_WIDTH")),812 if OS.get_environment("BRUSHUP_GUI_WIDTH")=="1180" else 1080)]
 root.window_input.connect(func(e):
  if e is InputEventMouseButton and e.pressed:print("OS_POSITION ",e.position))
 for dims in widths:
  root.size=dims;await game.update({"op":"campaign_load","data":original});await enter_facility("party");await settle();await create_timer(.5).timeout
  print("GUI_GUILD_START ",game.page," ",game.pages.guild_view.stage," ",game.locked)
  await snapshot("guild-start-"+str(dims.x))
  var start=request_id
  print("GUILD_CLICK_TARGET ",node("GuildMember_guard").get_global_rect()," window=",root.position," disabled=",node("GuildMember_guard").disabled)
  await os_click(node("GuildMember_guard"));print("GUILD_AFTER_CLICK ",game.pages.guild_view.chosen_id);check(game.pages.guild_view.chosen_id=="guard","OS selects current named member")
  await os_click(node("GuildDetails"));check(game.pages.party_view.detail_uid=="guard","OS opens correct detail")
  await os_key("Escape");check(not game.modal_open() and game.pages.guild_view.chosen_id=="guard","OS Escape returns to same guild selection")
  await os_click(node("GuildReserveJobFilter"));await os_key("Down");await os_key("Down");await os_key("Return")
  print("GUI_FILTER ",game.pages.guild_view.reserve_job," chosen=",game.pages.guild_view.chosen_id)
  check(game.pages.guild_view.reserve_job!="" and game.pages.guild_view.chosen_id=="guard","OS job filter keeps current swap target")
  await snapshot("guild-filtered-"+str(dims.x))
  await os_click(node("GuildMember_guard-2"));await create_timer(.5).timeout;await settle()
  check(game.campaign().selected[0]=="guard-2","OS two member choices still perform one direct swap")
  operations.append({"task":"guild detail/return/filter/swap","width":dims.x,"events":request_id-start,"direct_swap_member_clicks":2})
  await game.update({"op":"campaign_load","data":east});await enter_facility("shop");await settle()
  var before=await saved();await os_click(node("Product_spear-wood"));await settle()
  check(node("ShopComparisonStats").text.contains("ガロ"),"OS product click opens named comparison")
  await snapshot("comparison-"+str(dims.x))
  await os_click(node("ShopComparisonOwner"));await os_key("Down");await os_key("Down");await os_key("Return")
  print("GUI_OWNER ",game.pages.shop_view.comparison_view.owner_id," ",node("ShopComparisonStats").text)
  check(node("ShopComparisonStats").text.contains("リノ") and node("ShopComparisonOwner").has_focus(),"OS owner change updates comparison and keyboard focus")
  await os_key("Tab");check(node("ShopComparisonSlot").has_focus(),"OS Tab reaches slot selector")
  await os_key("space");await os_key("Down");await os_key("Return");await settle()
  print("GUI_SLOT ",game.pages.shop_view.comparison_view.slot)
  check(node("ShopComparisonStats").text.contains("左手") and node("ShopComparisonSlot").has_focus(),"OS keyboard slot change updates same comparison")
  await os_key("Escape");check(not game.modal_open() and (await saved())==before,"OS comparison cancellation has no side effects")
  var start_buy=request_id
  await os_click(node("ProductBuy_spear-wood"));await os_click(node("PurchaseAgree"))
  check(node("RecipientPayment").text.contains("500 → 410G"),"OS original purchase flow shows payment at recipient step")
  await snapshot("recipient-"+str(dims.x))
  await os_click(node("PurchaseRecipient_guard"));check(int(game.campaign().gold)==410 and int(game.campaign().characters.guard.inventory["spear-wood"])==4,"OS purchase commits exact owner and amount")
  operations.append({"task":"original inventory purchase","width":dims.x,"clicks":request_id-start_buy,"baseline_clicks":3})
  await os_click(node("PartyFace_guard"));check(game.pages.party_view.detail_uid=="guard","OS opens purchased owner inventory")
  await os_click(node("OwnedInventorySell_spear-wood"))
  await snapshot("sale-"+str(dims.x))
  var bought=await saved();await os_click(node("InventoryPrepareSale"));await os_click(node("InventoryCancel"))
  check((await saved())==bought,"OS sale cancellation preserves inventory and gold")
  await os_click(node("PartyFace_mage"));check(node("InventorySaleTotals")==null and node("OwnedInventorySell_spear-wood")==null,"OS portrait switch clears previous owner's sale action")
  await os_key("Escape");await settle()
  await game.update({"op":"campaign_load","data":bought});await enter_facility("shop");await settle()
  check(int(game.campaign().gold)==410 and int(game.campaign().characters.guard.inventory["spear-wood"])==4,"reload retains canonical purchase result")
  var south=original.duplicate(true);south.state.location="south";south.state.gold=500
  await game.update({"op":"campaign_load","data":south});await enter_facility("shop");await settle();await snapshot("consumables-"+str(dims.x))
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"BGM voice SE stayed OFF during real input QA")
 var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 f=FileAccess.open(evidence.path_join("operations.json"),FileAccess.WRITE);f.store_string(JSON.stringify(operations,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
