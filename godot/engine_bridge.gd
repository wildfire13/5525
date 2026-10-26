extends Node
signal diagnostic_completed(file_operation: bool, ok: bool, duration_ms: int)
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
	if busy:return false
	native_dir=ProjectSettings.globalize_path("res://../native")
	var program=node_program if not node_program.is_empty() else OS.get_environment("NATIVE5525_NODE")
	if program.is_empty():program="C:/Program Files/nodejs/node.exe" if OS.get_name()=="Windows" else "/usr/bin/node"
	var script=node_script if not node_script.is_empty() else native_dir.path_join("bridge.cjs")
	closing=false;last_error=""
	disconnected=not transport.start(program,PackedStringArray([script]))
	if not disconnected:connection_generation+=1
	if disconnected:last_error="Node.js 22以上を起動できません。実行ファイルを確認し「再接続」を選んでください。"
	return not disconnected
func _disconnect(code: String) -> Dictionary:
	transport.close();disconnected=true
	last_error="ゲーム接続が終了しました（%s）。未保存の進行は失われています。再接続して保存済みファイルを読み込めます。" % code
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
func request(payload: Dictionary) -> Dictionary:
	if busy or closing:
		diagnostic_completed.emit(payload.get("op")=="godot_io",false,0)
		return {"ok":false,"error":"接続が使用中、または終了しています"}
	if disconnected or handles.is_empty():
		diagnostic_completed.emit(payload.get("op")=="godot_io",false,0)
		return {"ok":false,"connection_lost":true,"error":last_error}
	busy=true
	var diagnostic_started=Time.get_ticks_msec()
	var result: Dictionary
	if payload.get("op")=="godot_io":result=await _file_request(payload)
	else:
		result=await transport.exchange(payload,self,timeout_ms)
		if result.has("transport_error") and not closing:result=_disconnect(result.transport_error)
	if closing:result={"ok":false,"error":"終了しています"}
	busy=false
	diagnostic_completed.emit(payload.get("op")=="godot_io",bool(result.get("ok",false)),Time.get_ticks_msec()-diagnostic_started)
	return result
func close_engine():
	closing=true
	file_transport.close();transport.close()
	# An awaiting request observes closing and completes without another join.
func _exit_tree():close_engine()
