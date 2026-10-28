extends RefCounted
## Polled diagnostic pipe. No SceneTree signal awaits or suspended function state.
var handles: Dictionary={}
var worker_id: int=-1
var deadline=0
var job: Dictionary={}
func start(program: String,args: PackedStringArray) -> bool:
 close()
 if program.is_absolute_path() and not FileAccess.file_exists(program):return false
 handles=OS.execute_with_pipe(program,args,true)
 return not handles.is_empty()
static func exchange_line(pipe: FileAccess,payload: String,result: Dictionary):
 pipe.store_string(payload+"\n");pipe.flush()
 result.reply=pipe.get_line()
func begin(payload: Dictionary,budget_ms: int) -> bool:
 if handles.is_empty() or worker_id>=0:return false
 if not OS.is_process_running(int(handles.pid)):close();return false
 job={"reply":""};deadline=Time.get_ticks_msec()+maxi(1,budget_ms)
 worker_id=WorkerThreadPool.add_task(exchange_line.bind(handles.stdio,JSON.stringify(payload,"",true,true),job))
 return true
func poll() -> Dictionary:
 if worker_id<0:return {"transport_error":"closed"}
 if not WorkerThreadPool.is_task_completed(worker_id):
  if Time.get_ticks_msec()<deadline:return {"pending":true}
  close();return {"transport_error":"timeout"}
 WorkerThreadPool.wait_for_task_completion(worker_id);worker_id=-1
 var reply=str(job.get("reply",""));job={}
 if reply.is_empty():close();return {"transport_error":"eof"}
 var parser=JSON.new()
 if parser.parse(reply)!=OK or not parser.data is Dictionary or not parser.data.get("ok") is bool:
  close();return {"transport_error":"invalid_reply"}
 return parser.data
func close():
 if not handles.is_empty() and OS.is_process_running(int(handles.pid)):OS.kill(int(handles.pid))
 if worker_id>=0:WorkerThreadPool.wait_for_task_completion(worker_id);worker_id=-1
 if not handles.is_empty():handles.stdio.close();handles.stderr.close();handles.clear()
 job={};deadline=0
