extends SceneTree
## Immediate synchronous teardown must not leave an awaiting coroutine or worker.
func _initialize():call_deferred("run")
func run():
 var store=preload("res://debug_store.gd").new();root.add_child(store)
 store.start(ProjectSettings.globalize_path("res://../native"))
 store.worker_script=ProjectSettings.globalize_path("res://tests/debug_store_blocked_worker.py")
 store.pump()
 if store.transport.handles.is_empty():
  print("FAIL blocked diagnostic worker starts");store.free();quit(1);return
 var pid=int(store.transport.handles.pid);print("OWNED_WORKER_PID ",pid)
 await create_timer(.05).timeout
 var pending=store.pumping and store.transport.worker_id>=0 and OS.is_process_running(pid)
 print(("PASS " if pending else "FAIL ")+"diagnostic worker remains pending and alive before synchronous stop")
 var started=Time.get_ticks_msec()
 store.stop_now()
 var stopped=store.transport.handles.is_empty() and store.transport.worker_id<0
 print(("PASS " if stopped else "FAIL ")+"synchronous stop clears owned process handle and pipe task")
 print("STOPPED_MS ",Time.get_ticks_msec()-started)
 store.free()
 # Deliberately no frames/timers/grace period after stop/free. The subprocess
 # runner must also reject ObjectDB/GDScriptFunctionState leak warnings at exit.
 quit(0 if pending and stopped else 1)
