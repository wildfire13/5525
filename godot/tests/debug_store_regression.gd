extends "res://tests/feedback_261019_3.gd"
class ReleaseStore:
 extends "res://debug_store.gd"
 func allowed() -> bool:return false
var store
var db_path=""
var readback={}
var observed=[]
var last_sequence=0
func drain():
 var deadline=Time.get_ticks_msec()+5000
 while store.active and (not store.queue.is_empty() or store.pumping) and Time.get_ticks_msec()<deadline:
  if not store.pumping:store.pump()
  await process_frame
 check(store.active and not store.pumping and store.queue.is_empty(),"diagnostic queue drains independently")
func read_db():
 var probe="""import sqlite3,json,sys
from pathlib import Path
with sqlite3.connect(Path(sys.argv[1]).resolve().as_uri()+'?mode=ro',uri=True) as db:
 db.row_factory=sqlite3.Row
 events=[dict(r) for r in db.execute('SELECT * FROM events WHERE session=? ORDER BY id',(sys.argv[2],))]
 for row in events:row['data']=json.loads(row['data'])
 sessions=[dict(r) for r in db.execute('SELECT * FROM sessions')]
 print(json.dumps({'events':events,'sessions':sessions}))
"""
 var output=[];var code=OS.execute(OS.get_environment("NATIVE5525_PYTHON"),["-c",probe,db_path,store.session],output,true,false)
 check(code==0,"SQLite readonly probe succeeds")
 readback=JSON.parse_string("".join(output)) if code==0 else {"events":[],"sessions":[]}
 return readback.events
func request(payload: Dictionary,op: String,expected: bool=true):
 var from=store.sequence;var began=Time.get_ticks_msec()
 var reply=await game.update(payload);var elapsed_ms=Time.get_ticks_msec()-began
 await drain();var rows=read_db().filter(func(e):return e.seq>from and e.op==op)
 check(rows.size()==2 and rows[0].kind=="request_start" and rows[1].kind=="request_end","one ordered request pair "+op)
 if rows.size()==2:
  check(rows[0].request_id==rows[1].request_id and rows[1].ok==int(expected) and reply.get("ok",false)==expected,"stored outcome matches real reply "+op)
  check(rows[1].duration_ms>=0 and rows[1].duration_ms<=elapsed_ms+2,"stored duration bounded by real elapsed "+op)
  observed.append({"op":op,"request_id":rows[1].request_id,"elapsed_ms":elapsed_ms,"duration_ms":rows[1].duration_ms,"ok":reply.get("ok",false)})
 return reply
func latest_after() -> Dictionary:
 var rows=read_db()
 for i in range(rows.size()-1,-1,-1):
  if rows[i].data.has("after"):return rows[i].data.after
 return {}
func causal_after(expected: Dictionary,label: String):
 var rows=read_db().filter(func(e):return e.kind=="state" and e.data.get("after")==expected)
 check(not rows.is_empty() and rows[-1].request_id==observed[-1].request_id,"final state links to originating action: "+label)
func source_case() -> Dictionary:
 var script="""const C=require(process.argv[1]),B=require(process.argv[2]),assert=require('node:assert/strict');
const s=C.create();Object.assign(s.characters.mage,{leftHand:'staff-wood',accessory1:'return-ring-1',accessory2:'return-ring-2'});
assert(C.validate(s).ok);assert(C.depart(s,'east'));assert(C.travel(s,'safe',()=>0));assert(C.begin(s));
const a=s.battle.units.find(u=>u.id==='mage'),b=s.battle.units.find(u=>u.id==='guard');a.pos=23;b.pos=24;b.hp-=80;
for(const u of s.battle.units)u.next=100000;a.next=1;s.battle.actor=a.id;assert(C.validate(s).ok);
const skills=B.activeSkillOptions(a),returns=B.returnSkillOptions(a);assert.equal(skills.filter(x=>x.id==='mage').length,2);assert.equal(returns.length,2);
console.log(JSON.stringify({save:JSON.parse(C.serialize(s)),actor:a.id,target:b.id,skills,returns}));"""
 var output=[];var code=OS.execute(OS.get_environment("NATIVE5525_NODE"),["-e",script,ProjectSettings.globalize_path("res://../native/campaign.js"),ProjectSettings.globalize_path("res://../native/campaign-battle.js")],output,true,false)
 check(code==0,"synthetic source/CT/return boundary passes canonical validator")
 return JSON.parse_string("".join(output)) if code==0 else {}
func run():
 create_timer(180).timeout.connect(func():print("FAIL persistent debug integration watchdog");quit(2))
 root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle();store=game.engine.debug_store;db_path=ProjectSettings.globalize_path(store.PATH)
 check(store!=null and store.active,"debug build starts local recorder without opening window")
 check(game.debug_view.window==null,"persistent collection does not create window")
 await drain();read_db();check(readback.sessions.any(func(s):return s.session==store.session and s.clean_closed==0),"active session stored as not cleanly closed")
 var seed=(await request({"op":"campaign_save"},"campaign_save")).data
 await request({"op":"PRIVATE_SENTINEL","data":"PRIVATE_SENTINEL","name":"PRIVATE_SENTINEL"},"other",false)
 var path=evidence.path_join("PRIVATE_SENTINEL-save.json")
 await request({"op":"godot_io","action":"write","path":path,"data":seed},"godot_io.write")
 await request({"op":"godot_io","action":"read","path":path,"allowed":[]},"godot_io.read")
 await request({"op":"godot_io","action":"read","path":evidence.path_join("PRIVATE_SENTINEL-missing.json"),"allowed":[]},"godot_io.read",false)
 await request({"op":"campaign_load","data":seed},"campaign_load")
 game.file_dialog(FileDialog.FILE_MODE_OPEN_FILE,["*.json"],func(_p):pass);await settle()
 var dialogs=game.find_children("*","FileDialog",true,false)
 check(dialogs.size()==1,"file dialog opened for cancellation path")
 if not dialogs.is_empty():dialogs[0].canceled.emit();await settle()
 await drain();check(read_db().any(func(e):return e.op=="ui.file_open" and e.data.get("reason")=="cancel"),"UI-only file cancellation persists distinct cancel event")
 var fixture=source_case()
 await request({"op":"campaign_load","data":fixture.save},"campaign_load")
 await request({"op":"select_skill","skillId":fixture.skills[0].key},"select_skill")
 var before_cancel=await saved();game.command="skill";game.cancel();await settle()
 check(await saved()==before_cancel,"skill cancel preserves real battle state")
 await request({"op":"act","kind":"skill","target":fixture.target,"presentation":true},"act.skill")
 var after=latest_after();check(after.get("cooldowns",[]).any(func(g):return g.slot==fixture.skills[0].slot and g.remaining==1),"final presentation state persists used source CT1")
 check(not after.get("cooldowns",[]).any(func(g):return g.slot==fixture.skills[1].slot),"unused identical source has no fabricated CT")
 causal_after(after,"skill CT1")
 await request({"op":"act","kind":"skill","target":fixture.target,"presentation":false},"act.skill",false)
 await request({"op":"act","kind":"guard","presentation":true},"act.guard")
 after=latest_after();check(after.get("cooldowns",[]).is_empty(),"guard opportunity final presentation persists CT expiration")
 causal_after(after,"guard CT expiration")
 await request({"op":"select_return_skill","skillId":fixture.returns[0].key},"select_return_skill")
 await request({"op":"act","kind":"return","target":3,"presentation":true},"act.return")
 after=latest_after();check(after.get("returns",[]).any(func(g):return g.slot=="accessory1" and g.used),"final presentation persists selected return source used")
 check(not after.get("returns",[]).any(func(g):return g.slot=="accessory2" and g.used),"other return source remains unused")
 causal_after(after,"first return")
 await request({"op":"act","kind":"return","target":2},"act.return",false)
 await request({"op":"select_return_skill","skillId":fixture.returns[1].key},"select_return_skill")
 await request({"op":"act","kind":"return","target":2,"presentation":true},"act.return")
 after=latest_after();check(after.get("returns",[]).size()==2 and after.returns.all(func(g):return g.used),"both distinct return grants persist consumed state")
 causal_after(after,"second return")
 await drain();var all=read_db();var serialized=JSON.stringify(readback)
 check(not serialized.contains("PRIVATE_SENTINEL") and not serialized.contains(evidence) and not serialized.contains("ガロ") and not serialized.contains("staff-wood") and not serialized.contains("return-ring"),"stored records exclude raw payload names paths equipment IDs")
 check(not all.any(func(e):return e.op in ["presentation_next","presentation_finish","preview","hover_preview"]),"per-frame/preview traffic excluded from request events")
 var starts={};var ends={};var monotonic=true;var last_seq=0;var last_ms=0
 for event in all:
  monotonic=monotonic and event.seq>last_seq and event.elapsed_ms>=last_ms;last_seq=event.seq;last_ms=event.elapsed_ms
  if event.kind=="request_start":starts[event.request_id]=starts.get(event.request_id,0)+1
  if event.kind=="request_end":ends[event.request_id]=ends.get(event.request_id,0)+1
 check(monotonic,"stored sequence and session elapsed times remain ordered")
 check(starts.keys()==ends.keys() and starts.values().all(func(n):return n==1) and ends.values().all(func(n):return n==1),"all observed attempted requests have exactly one start and end")
 var sanitizer=preload("res://debug_events.gd").new();sanitizer.configure("0".repeat(32))
 var enemy={"id":"PRIVATE_SENTINEL","selectedSkillKey":"legacy:scout","skillCooldowns":{"legacy:scout":1,"legacy:PRIVATE_SENTINEL":1}}
 var snap=sanitizer.snapshot({"state":{"actor":"PRIVATE_SENTINEL","units":[enemy]},"queue":[{"id":"PRIVATE_SENTINEL"}]})
 check(snap.cooldowns.size()==1 and snap.cooldowns[0].remaining==1 and snap.selected_grant.skill=="scout","known legacy enemy source CT retained and unknown legacy suffix rejected")
 check(not JSON.stringify(snap).contains("PRIVATE_SENTINEL"),"legacy actor/source sentinel never crosses sanitized boundary")
 var release=ReleaseStore.new();root.add_child(release);release.start(ProjectSettings.globalize_path("res://../native"));release.begin_request({"op":"campaign_save"});release.local_event("file_open","cancel");release.pump()
 check(not release.active and release.session.is_empty() and release.queue.is_empty() and release.transport.handles.is_empty(),"release-disabled branch starts no worker or queue/session")
 release.queue_free()
 store.set_process(false);await drain()
 for i in range(300):store.local_event("navigate","success")
 check(store.queue.size()==256 and store.dropped==44,"queue pressure bounded with explicit drop count")
 await drain();check(read_db().any(func(e):return e.data.get("reason")=="queue_overflow" and e.data.get("dropped")==44),"overflow reported after successful independent flush")
 await game.engine.finish_diagnostics();read_db();check(readback.sessions.any(func(s):return s.session==store.session and s.clean_closed==1),"normal shutdown marks clean completion")
 var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 f=FileAccess.open(evidence.path_join("readback.json"),FileAccess.WRITE);f.store_string(JSON.stringify(readback,"\t"));f.close()
 f=FileAccess.open(evidence.path_join("observed.json"),FileAccess.WRITE);f.store_string(JSON.stringify(observed,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
