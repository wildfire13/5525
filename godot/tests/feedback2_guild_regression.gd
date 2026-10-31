extends "res://tests/guild_regression.gd"
## Canonical 6..12-member operations on the migrated 35-person roster.
## Separate view-only capacity overrides never write back to the engine.
var geometry=[]
func current_ids() -> Array:return ids("GuildCurrentScroll")
func check_layout(tag: String):
 var reserve=node("GuildReserveColumn");var current=node("GuildCurrentColumn");var middle=node("GuildActionColumn");var buttons=[node("GuildAdd"),node("GuildDetails"),node("GuildRemove")]
 var r=reserve.get_global_rect();var c=current.get_global_rect();var m=middle.get_global_rect();var viewport=Rect2(Vector2.ZERO,Vector2(root.size))
 check(r.end.x<=m.position.x+1 and m.end.x<=c.position.x+1,tag+" narrow lists flank the dedicated central operations column")
 check(buttons[0].get_global_rect().end.y<=buttons[1].global_position.y and buttons[1].get_global_rect().end.y<=buttons[2].global_position.y,tag+" add/details/remove retain fixed vertical order")
 for control in buttons+[node("GuildOperations"),node("GuildReturn")]:
  check(viewport.encloses(control.get_global_rect()),tag+" operation stays on screen "+str(control.name))
 var members=game.find_children("GuildMember_*","Button",true,false)
 for member in members:
  var margin=member.get_child(0)
  check(member.size.y+1>=margin.get_combined_minimum_size().y and member.size.y<=132,tag+" row content fits compact card without pre-layout wrap inflation "+str(member.get_meta("member_id")))
 geometry.append({"tag":tag,"window":str(root.size),"reserve":str(r),"actions":str(m),"current":str(c),"footer":str(node("GuildOperations").get_global_rect()),"limit":game.pages.guild_view.party_limit(),"selected":game.campaign().selected.size()})
func pure_ui_boundaries():
 var guild=game.pages.guild_view;var original=game.data.campaign.duplicate(true);var roster=original.roster.duplicate(true)
 for index in range(3):
  var member=roster[0].duplicate(true);member.id="qa-guild-extra-"+str(index);member.name="検査専用の長い人物名・境界"+str(index);roster.append(member)
 var all_ids=roster.map(func(member):return str(member.id))
 for count in range(6,13):
  game.data.campaign=original.duplicate(true);game.data.campaign.roster=roster.duplicate(true);game.data.campaign.partyLimit=12;game.data.campaign.selected=all_ids.slice(0,count);guild.reset();game.render();await settle()
  check(current_ids()==all_ids.slice(0,count),"synthetic UI "+str(count)+" members preserve ordered personal rows")
  guild.choose(all_ids[count]);await settle()
  check(node("GuildAdd").disabled==(count==12) and node("GuildRemove").disabled,"synthetic UI "+str(count)+" reserve add follows canonical partyLimit and cannot remove a reserve")
  check(guild.candidate("add","",all_ids[count]).is_empty()==(count==12),"synthetic UI "+str(count)+" candidate enforces twelve limit")
  var swapped=guild.candidate("swap",all_ids[0],all_ids[count]);check(swapped.size()==count and swapped[0]==all_ids[count],"synthetic UI "+str(count)+" full/partial swap preserves capacity")
  var reordered=guild.candidate("reorder",all_ids[0],all_ids[count-1]);check(reordered.size()==count and reordered[0]==all_ids[count-1] and reordered[-1]==all_ids[0],"synthetic UI "+str(count)+" reorder swaps only selected positions")
  check(guild.candidate("remove",all_ids[0],"").size()==count-1,"synthetic UI "+str(count)+" removal preserves remaining members")
  if count==12:check(node("GuildCapacity").text.contains("最大12人") and node("GuildSelection").text.contains("12/12人"),"synthetic full twelve has explicit capacity reason")
 game.data.campaign.partyLimit=8;game.data.campaign.selected=all_ids.slice(0,8);guild.reset();game.render();await settle();guild.choose(all_ids[8]);await settle()
 check(guild.party_limit()==8 and node("GuildAdd").disabled and node("GuildCapacity").text.contains("最大8人"),"UI derives capacity from field instead of hardcoded twelve")
 game.data.campaign.erase("partyLimit");game.data.campaign.selected=all_ids.slice(0,5);guild.reset();game.render();await settle()
 check(guild.party_limit()==5 and guild.candidate("add","",all_ids[5]).is_empty(),"older view without capacity field retains five-member fallback")
 game.data.campaign=original;guild.reset();game.render();await settle()
func run():
 create_timer(180).timeout.connect(func():print("FAIL feedback2 guild watchdog");quit(2))
 var root_evidence=OS.get_environment("INVENTORY_QA_ROOT")
 if root_evidence.is_empty() or not OS.get_user_data_dir().begins_with(root_evidence+"/"):quit(2);return
 root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():
  if game.engine!=null and game.engine.disconnected:check(false,"test startup: "+game.engine.last_error);quit(2);return
  await process_frame
 await preload("res://tests/current_historical_fixture.gd").install(game)
 game.audio.fast_mode=true;game.checks_fast=true;actual=game.engine;await settle();var seed=await saved()
 game.navigate("party");await settle();var guild=game.pages.guild_view
 if node("FacilityChoice_guild")!=null:await tap("FacilityChoice_guild")
 if node("GuildActions")==null:check(false,"guild page mounted before geometry tests");quit(2);return
 check(node("GuildActions") is VBoxContainer and node("GuildActions").get_parent()==node("GuildActionColumn"),"central action list is vertically laid out between two roster lists")
 var original_limit=guild.party_limit();check(original_limit==int(game.campaign().get("partyLimit",5)),"initial displayed cap uses current canonical field")
 for dims in [Vector2i(1920,1080)]:
  root.size=dims;await settle();check_layout(str(dims))
 await pure_ui_boundaries()
 check((await saved())==seed,"synthetic display/candidate boundaries never write engine save or ownership")
 if game.campaign().get("partyLimit",0)!=12:
  check(false,"native partyLimit12 integration must be available before canonical 6..12 operations")
 else:
  var roster_ids=game.campaign().roster.map(func(member):return str(member.id));var wanted=game.campaign().selected.duplicate();var added=0
  for id in roster_ids:
   if wanted.size()==original_limit:break
   if wanted.has(id):continue
   await tap("GuildMember_"+id);check(not node("GuildAdd").disabled,"canonical reserve add stays available above five")
   await tap("GuildAdd");wanted.append(id);added+=1
   check(game.campaign().selected==wanted,"canonical membership count "+str(wanted.size())+" commits ordered personal IDs")
  check(roster_ids.size()==35 and wanted.size()==12 and added==7,"twelve real people join while other migrated candidates remain in reserve")
  var full=await saved();check(full.state.characters==seed.state.characters and full.state.gold==seed.state.gold,"joining seven additional people preserves equipment inventories growth and money")
  var extra=roster_ids.filter(func(id):return not wanted.has(id))[0];guild.choose(extra);await settle()
  check(node("GuildAdd").disabled and guild.candidate("add","",extra).is_empty() and (await saved())==full,"canonical full party rejects a thirteenth member without mutation")
  # The capacity probe selected a reserve. Clear that selection so the next
  # current-member click opens its details instead of performing a legal swap.
  guild.cancel_selection();await settle();check((await saved())==full,"ending capacity probe preserves full party before details checks")
  var scroll=node("GuildCurrentScroll");scroll.scroll_vertical=500;await frames();var chosen=roster_ids[7];guild.choose(chosen);await settle();var position=node("GuildCurrentScroll").scroll_vertical
  await tap("GuildDetails");check(game.pages.party_view.detail_uid==chosen,"central details opens the selected personal identity")
  game.dialog.close(false);await settle();check(guild.chosen_id==chosen and node("GuildCurrentScroll").scroll_vertical==position,"details close preserves selected identity and list position")
  guild.cancel_selection();await settle();await tap("GuildMember_"+wanted[0]);await tap("GuildMember_"+wanted[7]);var swap=wanted[0];wanted[0]=wanted[7];wanted[7]=swap
  check(game.campaign().selected==wanted,"twelve-member reorder retains exact slot order through normal two-row flow")
  await tap("GuildMember_"+wanted[3]);var removed=wanted[3];await tap("GuildRemove");wanted.erase(removed)
  check(game.campaign().selected==wanted,"central remove acts on selected member and preserves others")
  await tap("GuildMember_"+removed);await tap("GuildAdd");wanted.append(removed)
  check(game.campaign().selected==wanted,"central add returns named reserve to the end")
  check((await saved()).state.characters==seed.state.characters,"reorder/remove/re-add leave personal ownership unchanged")
  await game.update({"op":"campaign","action":"select","args":[["guard"]]});await settle();guild.choose("guard");await settle();var one=await saved()
  check(node("GuildRemove").disabled and guild.candidate("remove","guard","").is_empty() and node("GuildSelection").text.contains("最低1人"),"minimum one member enforced without a porter condition")
  guild.cancel_selection();await settle();check((await saved())==one,"selection cancellation never removes last member")
  await game.update({"op":"campaign_load","data":seed});game.navigate("party");await settle()
  if node("FacilityChoice_guild")!=null:await tap("FacilityChoice_guild")
  await game.act("accept",[game.campaign().board[0].id,"porter"]);await settle();var cargo=await saved();guild.choose("porter");await settle();await tap("GuildRemove")
  check(guild.stage=="confirm" and node("GuildConfirmCancel")!=null,"cargo owner removal retains existing confirmation contract")
  await tap("GuildConfirmCancel");check((await saved())==cargo and guild.stage=="idle","cargo removal cancellation preserves save")
  await tap("GuildRemove");await tap("GuildConfirm");check(not game.campaign().selected.has("porter") and game.campaign().activeQuest.cargoOwnerId=="porter","accepted quest does not create a new guild porter-membership restriction")
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"guild tests BGM voice SE OFF")
 for spec in [["feedback2-guild-checks.json",checks],["feedback2-guild-geometry.json",geometry]]:
  var f=FileAccess.open(root_evidence.path_join(spec[0]),FileAccess.WRITE);f.store_string(JSON.stringify(spec[1],"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();actual.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(row):return row.passed) else 1)
