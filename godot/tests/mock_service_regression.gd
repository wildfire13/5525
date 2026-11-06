extends SceneTree
# Regressions from the matched main/revised audit. Input events, not pressed.emit,
# verify the result dialog's custom keyboard focus handling.
var game
var failures=[]
func _initialize():call_deferred("run")
func check(ok,label):
 print(("PASS " if ok else "FAIL ")+label)
 if not ok:failures.append(label)
func node(id):return game.find_child(id,true,false)
func settle():
 for i in range(10):await process_frame
 while game.locked or game.engine.busy or game.presenting:await process_frame
func key(code,shift=false):
 for down in [true,false]:
  var event=InputEventKey.new();event.keycode=code;event.pressed=down;event.shift_pressed=shift;Input.parse_input_event(event);await process_frame
 await settle()
func capture(name_):
 if OS.get_environment("SERVICE_QA_CAPTURE").is_empty():return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("SERVICE_QA_CAPTURE").path_join(name_+".png"))
func run():
 root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true
 var saved=(await game.engine.request({"op":"campaign_save"})).data
 var owner=str(saved.state.selected[0]);saved.state.characters[owner].hp=1;saved.state.gold=1000
 await game.update({"op":"campaign_load","data":saved});await settle()
 game.navigate("inn");game.pages.facility_entry.choose("inn");await settle()
 var inn=game.pages.inn_view
 check(node("InnKeeperSpeech").words.text=="お泊まりですか？","injured party receives inn greeting")
 var gold_before=int(game.campaign().gold);var price=int(game.campaign().inn.price)
 inn.stay();await settle()
 var confirm
 for window in game.find_children("*","ConfirmationDialog",true,false):
  if window.visible:confirm=window;break
 check(is_instance_valid(confirm),"rest still asks before charging")
 if is_instance_valid(confirm):confirm.confirmed.emit()
 await settle();await create_timer(1.8).timeout
 check(inn.dialogue==inn.RESTED_GREETING and node("InnKeeperSpeech").words.text==inn.RESTED_GREETING,"successful real rest displays keeper reply")
 check(int(game.campaign().gold)==gold_before-price and not game.campaign().inn.needsRecovery,"rest charges once and recovers actual campaign")
 var speech=node("InnKeeperSpeech")
 check(speech.is_visible_in_tree() and speech.get_global_rect().end.y<=node("InnKeeper").get_global_rect().position.y,"reply stays above keeper without overlapping portrait")
 await capture("inn-after-rest")
 game.pages.facility_entry.back();game.pages.facility_entry.choose("inn");await settle()
 check(node("InnKeeperSpeech").words.text==inn.FULL_GREETING,"already healthy visit displays healthy greeting")
 var rows=[]
 for member in game.campaign().roster:
  if game.campaign().selected.has(member.id):rows.append({"id":str(member.id),"name":member.name,"member":member,"xp_before":0,"xp_after":150,"xp_gain":150,"level_before":1,"level_after":2,"stat_gain":2,"skill_gain":0})
 var result=game.results_view
 result.enqueue({"kind":"battle","title":"BATTLE VICTORY","subtitle":"戦闘勝利","gold_gain":30,"gold_after":1000,"members":rows,"restored":false,"acknowledge":false,"location":"astaris"})
 result.present_pending();await settle()
 check(not node("ResultMemberDetails").visible,"growth details initially collapsed")
 node("ResultContinue").grab_focus();await key(KEY_TAB);await key(KEY_TAB)
 check(root.gui_get_focus_owner()==node("ResultDetailsToggle"),"Tab reaches growth details from OK")
 await key(KEY_ENTER)
 check(node("ResultMemberDetails").visible,"Enter expands growth details through real keyboard input")
 await key(KEY_PAGEDOWN)
 check(node("ResultMembersScroll").scroll_vertical>0,"PageDown reveals expanded growth information")
 await capture("result-keyboard-details")
 await key(KEY_ENTER)
 check(not node("ResultMemberDetails").visible,"Enter collapses growth details without dismissing result")
 await key(KEY_TAB,true)
 check(root.gui_get_focus_owner()==node("ResultMembersScroll"),"Shift Tab returns to scroll for keyboard inspection")
 result.advance();await settle()
 game.closing=true;game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();await create_timer(.15).timeout;game.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
