extends Node
## Debug-only, local diagnostics. The rules/file workers never await this worker.
const BUILD="89c4990+debug-store-v1"
const PATH="user://diagnostics/debug.sqlite"
const MAX_QUEUE=256
const BATCH_SIZE=32
const FLUSH_INTERVAL=.2
const WORKER_TIMEOUT_MS=500
var transport=preload("res://pipe_transport.gd").new()
var sanitizer=preload("res://debug_events.gd").new()
var session=""
var queue: Array=[]
var sequence=0
var request_sequence=0
var causal_request_id=0
var dropped=0
var lost=0
var start_ticks=0
var active=false
var pumping=false
var closing=false
var failed=false
var disabled_by_environment=false
var elapsed=0.0
var status="無効"
var last_snapshot: Dictionary={}
var python_program=""
var worker_script=""
func allowed() -> bool:return OS.is_debug_build()
func _ready():set_process(false)
func start(native_dir: String,python_override: String=""):
 if not allowed() or active or failed or closing:return
 disabled_by_environment=OS.get_environment("NATIVE5525_DEBUG_DB_OFF")=="1"
 if disabled_by_environment:status="環境設定で無効";return
 start_ticks=Time.get_ticks_msec()
 session=Crypto.new().generate_random_bytes(16).hex_encode();sanitizer.configure(session);causal_request_id=0
 python_program=python_override if not python_override.is_empty() else OS.get_environment("NATIVE5525_PYTHON")
 if python_program.is_empty():python_program="python"
 worker_script=native_dir.path_join("debug_store.py")
 active=true;status="記録待ち";set_process(true)
 enqueue("lifecycle","session",0,{"reason":"start"})
func enqueue(kind: String,op: String,request_id: int,data: Dictionary={},ok=null,duration=0):
 if not allowed() or not active or failed or closing:return
 if queue.size()>=MAX_QUEUE:dropped+=1;return
 sequence+=1
 var event={"seq":sequence,"request_id":request_id,"kind":kind,"op":op,"elapsed_ms":maxi(0,Time.get_ticks_msec()-start_ticks),"data":data}
 if ok is bool:event.ok=ok;event.duration_ms=clampi(duration,0,600000)
 queue.append(event)
func begin_request(payload: Dictionary) -> Dictionary:
 if not allowed() or not active:return {}
 var op=sanitizer.operation(payload)
 if op.is_empty():return {"unrecorded":true,"presentation":payload.get("op") in ["presentation_next","presentation_finish"]}
 var quiet=sanitizer.quiet(payload)
 if not quiet:request_sequence+=1
 var token={"id":request_sequence,"op":op,"started":Time.get_ticks_msec(),"before":last_snapshot.duplicate(true),"quiet":quiet}
 if not quiet:enqueue("request_start",op,token.id,{"before":token.before})
 return token
func finish_request(token: Dictionary,reply: Dictionary,reason: String=""):
 if not allowed() or not active:return
 var before=last_snapshot.duplicate(true)
 if reply.has("state"):last_snapshot=sanitizer.snapshot(reply)
 if token.is_empty() or token.get("unrecorded",false):
  var is_presentation=bool(token.get("presentation",false))
  if before!=last_snapshot:enqueue("state","state",causal_request_id if is_presentation else 0,{"before":before,"after":last_snapshot.duplicate(true)})
  if is_presentation and reply.has("presentation") and reply.presentation==null:causal_request_id=0
  return
 var ok=bool(reply.get("ok",false))
 if ok and token.op in ["campaign_start","campaign_load","reset","campaign.endTrial"]:causal_request_id=0
 if ok and (str(token.op).begins_with("act.") or token.op in ["campaign.begin","reset"]) and reply.get("presentation") is Dictionary:
  causal_request_id=int(token.id)
 if reply.get("connection_lost",false):causal_request_id=0
 if token.get("quiet",false):
  if ok:return
  request_sequence+=1;token.id=request_sequence;enqueue("request_start",token.op,token.id,{"before":token.before})
 var outcome=reason if reason in ["rejected","disconnected","failed","success"] else ("success" if ok else "failed")
 enqueue("request_end",token.op,token.id,{"before":token.before,"after":last_snapshot.duplicate(true),"reason":outcome},ok,Time.get_ticks_msec()-int(token.started))
func local_event(name: String,reason: String):
 if not allowed() or not active:return
 var op="ui."+name if name in sanitizer.UI else "other"
 enqueue("lifecycle",op,0,{"reason":reason if reason in ["cancel","success","failed","rejected","start","close"] else "failed"})
func state_changed(values: Dictionary):
 if not allowed() or not active:return
 var safe={}
 for key in ["locked","presenting","preview_pending","quote_pending","busy","disconnected","loading"]:
  if values.get(key) is bool:safe[key]=values[key]
 enqueue("state","state",0,safe)
func _process(delta):
 if not allowed() or not active:return
 elapsed+=delta
 if elapsed<FLUSH_INTERVAL or pumping:return
 elapsed=0
 if not queue.is_empty():pump()
func disable():
 lost+=queue.size()
 failed=true;active=false;status="保存停止（保存未確認%d件・ゲーム操作は継続できます）" % lost;queue.clear();set_process(false);transport.close()
func pump(timeout_budget_ms: int=WORKER_TIMEOUT_MS):
 if pumping or not active or queue.is_empty():return
 pumping=true
 if transport.handles.is_empty():
  if not transport.start(python_program,PackedStringArray(["-X","utf8","-B",worker_script,"--db",ProjectSettings.globalize_path(PATH)])):
   pumping=false;disable();return
 var events=queue.slice(0,BATCH_SIZE)
 queue=queue.slice(events.size())
 var response=await transport.exchange({"action":"batch","session":session,"version":BUILD,"events":events},self,clampi(timeout_budget_ms,1,WORKER_TIMEOUT_MS))
 pumping=false
 if closing and not is_inside_tree():return
 if not response.get("ok",false):lost+=events.size();disable();return
 status="保存中"
 if dropped>0 and queue.size()<MAX_QUEUE:
  var count=dropped;dropped=0;enqueue("lifecycle","session",0,{"reason":"queue_overflow","dropped":count})
func shutdown(budget_ms: int=700):
 if not allowed() or closing:return
 if not active:stop_now();return
 var deadline=Time.get_ticks_msec()+clampi(budget_ms,0,1000)
 enqueue("lifecycle","session",0,{"reason":"close"})
 set_process(false)
 while active and (pumping or not queue.is_empty()) and Time.get_ticks_msec()<deadline:
  if not pumping:pump(maxi(1,deadline-Time.get_ticks_msec()))
  await get_tree().process_frame
 if active and not pumping and queue.is_empty() and Time.get_ticks_msec()<deadline:
  var response=await transport.exchange({"action":"close","session":session,"version":BUILD},self,maxi(1,deadline-Time.get_ticks_msec()))
  if response.get("ok",false):status="保存完了"
 stop_now()
func stop_now():
 closing=true;active=false;set_process(false);transport.close();queue.clear()
func _exit_tree():stop_now()
