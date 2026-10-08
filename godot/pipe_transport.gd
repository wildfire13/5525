extends RefCounted
## Own exactly one process and its pipe worker. No child process trees.
var handles: Dictionary={}
var worker_id: int=-1
var stopped:=false
var job: Dictionary={}
func start(program: String,args: PackedStringArray) -> bool:
	close()
	stopped=false
	if program.is_absolute_path() and not FileAccess.file_exists(program):return false
	handles=OS.execute_with_pipe(program,args,true)
	return not handles.is_empty()
func _exchange(payload: String,slot: Dictionary):
	var pipe: FileAccess=handles.stdio
	pipe.store_string(payload+"\n");pipe.flush()
	slot.reply=pipe.get_line()
func _join():
	if worker_id>=0:
		WorkerThreadPool.wait_for_task_completion(worker_id);worker_id=-1
func close():
	stopped=true
	if not handles.is_empty() and OS.is_process_running(int(handles.pid)):OS.kill(int(handles.pid))
	_join()
	if not handles.is_empty():
		handles.stdio.close();handles.stderr.close();handles.clear()
func exchange(payload: Dictionary,host: Node,budget_ms: int) -> Dictionary:
	if handles.is_empty() or stopped or worker_id>=0:return {"transport_error":"closed"}
	if not OS.is_process_running(int(handles.pid)):close();return {"transport_error":"eof"}
	job={"reply":""}
	worker_id=WorkerThreadPool.add_task(_exchange.bind(JSON.stringify(payload,"",true,true),job))
	var deadline=Time.get_ticks_msec()+budget_ms
	var timed_out=false
	while worker_id>=0 and not WorkerThreadPool.is_task_completed(worker_id):
		if Time.get_ticks_msec()>=deadline:
			timed_out=true;close();break
		await host.get_tree().process_frame
	_join()
	if timed_out:return {"transport_error":"timeout"}
	if stopped:return {"transport_error":"closed"}
	if str(job.reply).is_empty():close();return {"transport_error":"eof"}
	var parser=JSON.new()
	if parser.parse(job.reply)!=OK or not parser.data is Dictionary or not parser.data.get("ok") is bool:
		close();return {"transport_error":"invalid_reply"}
	return parser.data
