extends SceneTree
var game
var failures=[]
func capture(label):
 if OS.get_environment("MOCK_UI_CAPTURE").is_empty():return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("MOCK_UI_CAPTURE").path_join(label+".png"))
func _initialize():call_deferred("run")
func check(value,label):
 print(("PASS " if value else "FAIL ")+label)
 if not value:failures.append(label)
func settle():
 for i in range(8):await process_frame
 while game.locked or game.engine.busy or game.presenting:await process_frame
func node(id):return game.find_child(id,true,false)
func run():
 root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true
 game.navigate("party");await settle()
 check(node("FacilityExit")!=null,"guild entry has exit")
 check(node("FacilityChoice_guild")!=null and node("FacilityChoice_warehouse")!=null,"guild has direct choices")
 await capture("guild-entry")
 game.pages.facility_entry.choose("guild");await settle()
 check(node("GuildComparison")!=null and node("GuildReserveColumn")!=null,"guild comparison and reserve columns")
 check(node("GuildReturn")!=null,"guild return is inside service")
 var guild=game.pages.guild_view
 var candidate=guild.groups()[0][0]
 guild.choose(str(candidate.id));await settle()
 check(node("GuildSwap")!=null and not node("GuildSwap").disabled,"selecting reserve enables explicit swap")
 await capture("guild-comparison")
 var old_ids=game.campaign().selected.duplicate()
 guild.prepare("swap",guild.current_id,str(candidate.id));await settle()
 while guild.stage=="animating":await process_frame
 check(game.campaign().selected.has(candidate.id) and game.campaign().selected.size()==old_ids.size(),"swap commits selected pair without changing party size")
 game.pages.facility_entry.back();await settle();game.pages.facility_entry.choose("warehouse");await settle()
 check(node("WarehouseSelectedPanel")!=null and node("WarehouseReturn")!=null,"warehouse center details and return")
 await capture("warehouse")
 var warehouse=game.pages.warehouse_view
 var saved=await game.engine.request({"op":"campaign_save"})
 var owner=str(game.campaign().selected[0])
 saved.data.state.characters[owner].inventory["potion"]=2
 await game.update({"op":"campaign_load","data":saved.data});await settle()
 game.navigate("party");game.pages.facility_entry.choose("warehouse");await settle()
 warehouse.select_owner(owner);await settle();warehouse.choose("character","potion");await settle()
 warehouse.request_transfer("character","potion");await settle()
 check(node("WarehouseQuantity")!=null and game.dialog.window.title=="個数","stack transfer asks simplified quantity")
 node("WarehouseQuantity").value=2
 for button in game.dialog.actions.get_children():
  if button is Button and button.text=="OK":button.pressed.emit();break
 await settle()
 check(warehouse.rows("warehouse").any(func(entry):return entry.id=="potion" and int(entry.count)==2),"warehouse transfers selected quantity atomically")
 await warehouse.transfer("warehouse","potion",1,str(game.campaign().inventoryToken));await settle()
 check(warehouse.rows("warehouse").any(func(entry):return entry.id=="potion" and int(entry.count)==1),"warehouse withdrawal preserves remaining stack")

 game.navigate("board");await settle()
 check(node("QuestRequesterPortrait")!=null and node("QuestCargoInformation")!=null,"quest requester and cargo are visible")
 await capture("quest-board")
 game.navigate("inn");await settle();game.pages.facility_entry.choose("inn");await settle()
 check(node("InnActions")!=null and node("InnReturn")!=null,"inn adjacent rest and return")
 await capture("inn-service")
 var rows=[]
 for id in game.campaign().selected:
  var member=game.campaign().roster.filter(func(value):return value.id==id)[0]
  rows.append({"id":str(id),"name":member.name,"member":member,"xp_before":0,"xp_after":150,"xp_gain":150,"level_before":1,"level_after":2 if rows.size()<2 else 1,"stat_gain":2,"skill_gain":0})
 var result=game.results_view
 result.enqueue({"kind":"quest","title":"QUEST COMPLETE","subtitle":"配達達成","gold_gain":0,"gold_after":180,"rp_gain":100,"members":rows,"quest":"試験配達","hours":6,"restored":false,"acknowledge":false,"location":"astaris"})
 result.present_pending();await settle()
 check(node("ResultLevelUpStrip").get_child_count()==2,"only leveled characters appear in portrait strip")
 check(node("ResultContinue").text=="OK" and node("ResultRankPoints")!=null,"result shows RP and OK")
 await capture("result")
 result.advance();await settle()
 game.closing=true;game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();await create_timer(.15).timeout;game.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
