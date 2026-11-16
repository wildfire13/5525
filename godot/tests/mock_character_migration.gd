extends SceneTree
var game
var failures=[]
func _initialize():call_deferred("run")
func check(ok,label):
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)
func settle():
	for i in range(8):await process_frame
	while game.locked or game.engine.busy:await process_frame
func run():
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;game.navigate("character");await settle()
	var ids=game.campaign().selected;var workspace=game.pages.party_view.workspace
	check(game.find_child("PartyRoster",true,false)!=null,"shared roster on character page")
	check(game.pages.party_uid==ids[0],"first current member selected")
	if not OS.get_environment("MOCK_CHARACTER_CAPTURE").is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("MOCK_CHARACTER_CAPTURE"))
	var slot=game.find_child("CharacterSlot_rightHand",true,false);slot.pressed.emit();await settle()
	check(workspace.picked.equipped_slot=="rightHand","equipped item selection")
	game.find_child("CharacterSlot_upperBody",true,false).pressed.emit();await settle()
	check(workspace.picked.equipped_slot=="upperBody","second equipped selection replaces details")
	check(game.find_child("CharacterSlot_upperBody",true,false).get_meta("selected") and not game.find_child("CharacterSlot_rightHand",true,false).get_meta("selected"),"selection follows the equipped slot")
	var portrait_rect=game.find_child("CharacterPortrait",true,false).get_global_rect()
	var member=game.roster().filter(func(u):return u.id==ids[0])[0]
	var sword=member.equipmentSlots.filter(func(e):return e.slot=="rightHand")[0].id
	await workspace.perform(ids[0],sword,"transferEquipped",ids[1],1,"rightHand");await settle()
	check(game.campaign().inventoryByCharacter[ids[1]].entries.any(func(e):return e.id==sword),"equipped item transferred through atomic game API")
	check(not game.modal_open(),"single item transfer does not open confirmation")
	await workspace.perform(ids[1],sword,"transfer",ids[0],1,null);await settle()
	check(game.campaign().inventoryByCharacter[ids[0]].entries.any(func(e):return e.id==sword),"inventory transfer back")
	await workspace.perform(ids[0],sword,"equip",null,1,"rightHand");await settle()
	member=game.roster().filter(func(u):return u.id==ids[0])[0]
	check(member.equipmentSlots.any(func(e):return e.slot=="rightHand" and e.id==sword),"inventory equipment connected")
	var roster_id=game.find_child("PartyRoster",true,false).get_instance_id()
	for tab in ["inventory","ability","skills"]:
		workspace.set_tab(tab);await settle()
		check(game.find_child("CharacterPortrait",true,false).get_global_rect()==portrait_rect,"same portrait bounds in "+tab)
		check(game.find_child("PartyRoster",true,false).get_instance_id()==roster_id,"tab keeps party roster")
		check(game.find_child("PartyRoster",true,false).size.x==280,"fixed roster width in "+tab)
	workspace.set_tab("skills");await settle()
	check(game.page=="hub","active tab returns to previous page")
	var hub_clock=game.find_child("CampaignElapsedTime",true,false)
	var clock_position=hub_clock.global_position
	check(hub_clock.get_index()==0,"elapsed time is first in hub header")
	game.navigate("map");await settle()
	game.find_child("RosterMember_"+str(ids[0]),true,false).pressed.emit();await settle()
	check(game.find_child("Header_map",true,false)==null,"party header omits map shortcut")
	game.find_child("Header_character",true,false).pressed.emit();await settle()
	check(game.page=="map","header toggle restores map")
	for tab in ["equipment","inventory","ability","skills"]:
		game.mock_shell.activate(str(ids[0]));await settle()
		if workspace.tab!=tab:workspace.set_tab(tab);await settle()
		game.find_child("RosterMember_"+str(ids[1]),true,false).pressed.emit();await settle()
		check(game.page=="character" and game.pages.party_uid==ids[1],"another member stays open on "+tab)
		game.find_child("RosterMember_"+str(ids[1]),true,false).pressed.emit();await settle()
		check(game.page=="map","same member closes "+tab+" and restores map")
	var clock=game.find_child("CampaignElapsedTime",true,false)
	check(clock.global_position==clock_position and clock.get_global_rect().end.x<=game.find_child("HeaderLocation",true,false).global_position.x,"elapsed time stays fixed before location on map")
	check(clock.text=="経過時間：%d時間" % game.campaign().worldTime,"map displays elapsed world time")
	game.navigate("board");await settle()
	game.navigate("character");await settle()
	game.find_child("Header_character",true,false).pressed.emit();await settle()
	check(game.page=="board","direct character entry remembers its own origin")
	game.navigate("character");await settle()

	workspace.tab="ability";game.render();await settle()
	workspace.open_portrait(member);await settle()
	check(game.find_child("StatusChangePortrait",true,false)!=null,"portrait customization remains reachable from character ability")
	game.dialog.close();await settle()
	var party=game.pages.party_view
	party.ensure_draft(member);party.draft.str=1;workspace.allocating=true
	workspace.set_tab("inventory");await settle()
	check(workspace.tab=="ability" and party.draft_total()==1,"tab change preserves draft until confirmed")
	var discard=game.find_child("DiscardAllocation",true,false);discard.canceled.emit();discard.hide();discard.queue_free();await settle()
	check(workspace.tab=="ability" and party.draft_total()==1,"cancel tab leave retains allocation")
	workspace.set_tab("inventory");await settle()
	discard=game.find_child("DiscardAllocation",true,false);discard.confirmed.emit();discard.hide();discard.queue_free();await settle()
	check(workspace.tab=="inventory" and party.draft_total()==0 and not workspace.allocating,"confirmed tab leave clears draft and allocation mode")
	workspace.tab="ability";workspace.allocating=true;game.render();await settle();workspace.end_allocation();await settle()
	check(not workspace.allocating,"allocation back exits with no draft")
	party.ensure_draft(member);party.draft.str=1
	var previous=game.pages.party_uid
	game.mock_shell.activate(str(ids[1]));await settle()
	check(game.pages.party_uid==previous and party.draft_total()==1,"roster change guards before owner mutation")
	discard=game.find_child("DiscardAllocation",true,false)
	if discard!=null:discard.confirmed.emit();discard.hide();discard.queue_free();await settle()
	check(game.pages.party_uid==ids[1] and party.draft_total()==0,"confirmed owner switch clears allocation draft")
	var host=VBoxContainer.new();game.add_child(host)
	workspace.render_comparison_skills(host,{"before":{"skillSources":[]},"after":{"skillSources":[{"id":"skill_ambush","level":1,"slot":"head"}]}})
	var skill=host.find_child("CharacterComparisonSkill_追加_skill_ambush",true,false)
	check(skill!=null and skill.icon!=null and not skill.tooltip_text.is_empty(),"equipment skill changes use icon and effect tooltip")
	host.queue_free()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
