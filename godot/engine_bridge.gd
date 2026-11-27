extends Node
signal engine_stopped
signal diagnostic_completed(file_operation: bool, ok: bool, duration_ms: int)
var click_observer: Callable
var debug_store: Node
## Rules and files own separate processes; a file timeout never kills game state.
var transport=preload("res://pipe_transport.gd").new()
var file_transport=preload("res://pipe_transport.gd").new()
var handles: Dictionary:
	get:return transport.handles
var busy:=false
var closing:=false
var disconnected:=false
var connection_generation:=0
var last_error:=""
var timeout_ms:=15000
var io_timeout_ms:=10000
var recovery_timeout_ms:=5000
var native_dir: String
var node_program:=""
var node_script:=""
var python_program:=""
var io_script:=""
var owned_io_pids: Array[int]=[]
func start_engine() -> bool:
	if busy or disconnected:return false
	last_error=preload("res://runtime_paths.gd").apply(ProjectSettings.globalize_path("res://..").simplify_path())
	if not last_error.is_empty():
		disconnected=true
		return false
	native_dir=ProjectSettings.globalize_path("res://../native")
	if OS.is_debug_build() and debug_store==null:
		debug_store=preload("res://debug_store.gd").new();add_child(debug_store);debug_store.start(native_dir,python_program)
	var program=node_program if not node_program.is_empty() else OS.get_environment("NATIVE5525_NODE")
	if program.is_empty():program="node"
	var script=node_script if not node_script.is_empty() else native_dir.path_join("bridge.cjs")
	closing=false;last_error=""
	disconnected=not transport.start(program,PackedStringArray([script]))
	if not disconnected:connection_generation+=1
	if disconnected:last_error="ゲーム処理（Node.js）を起動できません。Node.jsの設定を確認して、ゲームを起動し直してください。"
	return not disconnected
func _disconnect(code: String) -> Dictionary:
	transport.close();disconnected=true
	var reason="ゲーム処理（Node.js）が終了しました。"
	if code=="timeout":reason="ゲーム処理（Node.js）が応答しませんでした。"
	elif code=="invalid_reply":reason="ゲーム処理（Node.js）からの応答を読み取れませんでした。"
	last_error=reason+"\nゲームを起動し直してください。最後に保存したところから再開できます。"
	engine_stopped.emit()
	return {"ok":false,"connection_lost":true,"error":last_error}
func _run_file(payload: Dictionary,script: String,budget: int) -> Dictionary:
	var program=python_program if not python_program.is_empty() else OS.get_environment("NATIVE5525_PYTHON")
	if program.is_empty():program="python"
	if not file_transport.start(program,PackedStringArray(["-X","utf8","-B",script])):
		return {"ok":false,"error":"Python + Pillowを起動できません。実行ファイルを確認してください。"}
	owned_io_pids.append(int(file_transport.handles.pid))
	if owned_io_pids.size()>32:owned_io_pids.pop_front()
	var result=await file_transport.exchange(payload,self,budget)
	file_transport.close()
	return result
func _file_request(payload: Dictionary) -> Dictionary:
	var request=payload.duplicate(true)
	request.profile_dir=preload("res://user_data_paths.gd").base_dir()
	var writing=request.get("action")=="write"
	if writing:request.operation=Crypto.new().generate_random_bytes(16).hex_encode()
	var script=io_script if not io_script.is_empty() else native_dir.path_join("godot_files.py")
	var result=await _run_file(request,script,io_timeout_ms)
	if not result.has("transport_error"):return result
	if writing and not closing:
		# The helper might have published before its response was lost. Inspect
		# this exact target and clean only this request's exclusive temporary.
		request.action="recover_write"
		var recovered=await _run_file(request,native_dir.path_join("godot_files.py"),recovery_timeout_ms)
		if not recovered.has("transport_error") and recovered.get("ok",false):
			if recovered.data.get("outcome")=="saved":return recovered
			return {"ok":false,"outcome":"not_saved","error":recovered.data.get("reason","保存されていません。ゲーム進行は保持しています。")}
		return {"ok":false,"outcome":"unknown","error":"保存結果を確認できません。ゲーム進行は保持しています。保存先を確認してから別名で保存してください。","path":payload.get("path","")}
	return {"ok":false,"error":"ファイル処理が終了しました（%s）。ゲーム進行は保持しています。" % result.transport_error}
func request(payload: Dictionary, click_context = null) -> Dictionary:
	var diagnostic_token=debug_store.begin_request(payload) if is_instance_valid(debug_store) else {}
	if busy or closing:
		diagnostic_completed.emit(payload.get("op")=="godot_io",false,0)
		if is_instance_valid(debug_store):debug_store.finish_request(diagnostic_token,{"ok":false},"rejected")
		return {"ok":false,"error":"接続が使用中、または終了しています"}
	if disconnected or handles.is_empty():
		diagnostic_completed.emit(payload.get("op")=="godot_io",false,0)
		if is_instance_valid(debug_store):debug_store.finish_request(diagnostic_token,{"ok":false},"disconnected")
		return {"ok":false,"connection_lost":true,"error":last_error}
	busy=true
	var observed := Callable()
	if click_observer.is_valid():
		var op: String = debug_store.sanitizer.operation(payload)
		if op.is_empty():op=str(payload.get("op","other"))
		observed=click_observer.call(op,click_context)
	var diagnostic_started=Time.get_ticks_msec()
	var result: Dictionary
	if payload.get("op")=="godot_io":result=await _file_request(payload)
	else:
		result=await transport.exchange(payload,self,timeout_ms)
		if result.has("transport_error") and not closing:result=_disconnect(result.transport_error)
	if closing:result={"ok":false,"error":"終了しています"}
	busy=false
	if observed.is_valid():observed.call()
	if is_instance_valid(debug_store):debug_store.finish_request(diagnostic_token,result,"disconnected" if result.get("connection_lost",false) else "")
	diagnostic_completed.emit(payload.get("op")=="godot_io",bool(result.get("ok",false)),Time.get_ticks_msec()-diagnostic_started)
	return result
func close_engine():
	closing=true
	if is_instance_valid(debug_store):debug_store.stop_now()
	file_transport.close();transport.close()
	# An awaiting request observes closing and completes without another join.
func debug_rejected_request(payload: Dictionary):
	if is_instance_valid(debug_store):
		var token=debug_store.begin_request(payload);debug_store.finish_request(token,{"ok":false},"rejected")
func debug_local_event(name: String,reason: String):
	if is_instance_valid(debug_store):debug_store.local_event(name,reason)
func finish_diagnostics():
	if is_instance_valid(debug_store):await debug_store.shutdown()
func _exit_tree():close_engine()
