extends Node
## Explicit opt-in native diagnostics. Never stores payloads, paths or save data.
const MAX_ENTRIES=200
var owner_ref: WeakRef
var ui:
 get:return owner_ref.get_ref()
var window: Window
var status: Label
var persistence: Label
var history: TextEdit
var entries: Array[String]=[]
var previous: Dictionary={}
var elapsed:=0.0
func is_enabled() -> bool:return OS.is_debug_build()
func _ready():set_process(is_enabled())
func configure(owner):
 owner_ref=weakref(owner);set_process(is_enabled())
func sample() -> Dictionary:
 if ui==null or ui.engine==null:return {}
 return {"処理待ち":bool(ui.locked),"演出":bool(ui.presenting),"予測待ち":bool(ui.preview_pending),"見積待ち":bool(ui.pages.quote_pending),"エンジン処理":bool(ui.engine.busy),"接続断":bool(ui.engine.disconnected),"ロード画面":bool(ui.loading_screen.active)}
func state_text(value: Dictionary) -> String:
 var parts: Array[String]=[]
 for key in value:parts.append(str(key)+": "+("ON" if value[key] else "OFF"))
 return " / ".join(parts)
func append_entry(message: String):
 entries.append("%0.3f  %s" % [Time.get_ticks_msec()/1000.0,message])
 if entries.size()>MAX_ENTRIES:entries.pop_front()
 refresh_history()
func request_finished(file_operation: bool,ok: bool,duration: int):
 if not is_enabled():return
 # These typed primitives are deliberately the whole logging interface.
 append_entry(("ファイル要求" if file_operation else "ゲーム要求")+" / "+("成功" if ok else "失敗")+" / %d ms" % maxi(0,duration))
func refresh_state():
 if not is_enabled():return
 var current=sample()
 if current!=previous:
  previous=current;append_entry(state_text(current))
  if "debug_store" in ui.engine and is_instance_valid(ui.engine.debug_store):ui.engine.debug_store.state_changed({"locked":current.get("処理待ち",false),"presenting":current.get("演出",false),"preview_pending":current.get("予測待ち",false),"quote_pending":current.get("見積待ち",false),"busy":current.get("エンジン処理",false),"disconnected":current.get("接続断",false),"loading":current.get("ロード画面",false)})
 if is_instance_valid(status):status.text=state_text(current)
 if is_instance_valid(persistence):persistence.text="ローカルDB："+str(ui.engine.debug_store.status if "debug_store" in ui.engine and is_instance_valid(ui.engine.debug_store) else "無効")
func _process(delta):
 elapsed+=delta
 if elapsed<.2:return
 elapsed=0;refresh_state()
func refresh_history():
 if not is_instance_valid(window) or not window.visible:return
 history.text="\n".join(entries)
 # Wrapped visual lines can exceed logical line_count. Wait for the range
 # to update, then follow its actual bottom instead of a logical line index.
 follow_latest.call_deferred()
func follow_latest():
 if not is_instance_valid(window) or not window.visible:return
 history.scroll_vertical=history.get_v_scroll_bar().max_value
func clear_history():
 entries.clear();refresh_history()
func open():
 if not is_enabled():return
 if not is_instance_valid(window):build()
 refresh_state();window.show();refresh_history();window.grab_focus();history.grab_focus()
func build():
 if not is_enabled():return
 window=Window.new();window.visible=false;window.name="DeveloperWindow";window.title="5525 開発情報";window.force_native=true;window.transient=false;window.exclusive=false;window.size=Vector2i(720,480);window.min_size=Vector2i(440,480);window.visible=false;window.theme=ui.theme;add_child(window)
 window.close_requested.connect(window.hide)
 window.window_input.connect(func(event):
  if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
   window.hide();window.set_input_as_handled())
 var margin=MarginContainer.new();window.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,12)
 var column=VBoxContainer.new();margin.add_child(column)
 var heading=Label.new();heading.text="開発情報（ゲーム操作・保存データとは独立）";heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(heading)
 status=Label.new();status.name="DebugState";status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(status)
 var hint=Label.new();hint.text="表示は最新200件。構造化診断はローカルDBに保存（公開・送信なし）";hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(hint)
 persistence=Label.new();persistence.name="DebugPersistence";persistence.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(persistence)
 history=TextEdit.new();history.name="DebugHistory";history.editable=false;history.custom_minimum_size.y=120;history.size_flags_vertical=Control.SIZE_EXPAND_FILL;history.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;column.add_child(history)
 history.get_v_scroll_bar().changed.connect(follow_latest,CONNECT_DEFERRED)
 var actions=HBoxContainer.new();column.add_child(actions)
 var clear=Button.new();clear.name="DebugClear";clear.text="表示履歴を消去";clear.pressed.connect(clear_history);actions.add_child(clear)
 var close=Button.new();close.name="DebugClose";close.text="閉じる";close.pressed.connect(window.hide);actions.add_child(close)
