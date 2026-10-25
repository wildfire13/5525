extends Control
# Presentation only. The board supplies canonical cells and the resolved recipient.
# World-space strokes are projected anew every frame, including camera changes.
var board_ref: WeakRef
var _event: Dictionary = {}
var _elapsed := 0.0
var _duration := 0.0
const INK = Color("#ead1a1")
const MINT = Color("#b6ead0")
const OCHRE = Color("#c79a66")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_process(false)

func play(event: Dictionary, duration: float) -> void:
	clear()
	var skill = str(event.get("skill_id", ""))
	var phase = str(event.get("phase", ""))
	if not is_finite(duration) or duration <= 0.0:
		return
	if not ((phase == "action" and skill in ["legSweep", "mage", "stamp", "attack", "guard"]) or (phase == "heal" and skill == "mage") or (phase == "hurt" and skill in ["stamp", "impact"])):
		return
	var origin = int(event.get("origin", -1))
	var recipient = int(event.get("recipient", -1))
	if (phase == "action" and not _valid_cell(origin)) or (phase != "action" and not _valid_cell(recipient)):
		return
	_event = event.duplicate(true)
	var cells: Array = []
	for value in event.get("cells", []):
		if not (value is int or value is float):
			continue
		var cell = int(value)
		if _valid_cell(cell) and not cells.has(cell) and not (skill == "legSweep" and cell == origin):
			cells.append(cell)
	_event["cells"] = cells
	_duration = duration
	set_process(true)
	queue_redraw()

func clear() -> void:
	_event = {}
	_elapsed = 0.0
	_duration = 0.0
	set_process(false)
	queue_redraw()

func snapshot() -> Dictionary:
	return {"active": not _event.is_empty(), "event": _event.duplicate(true), "elapsed": _elapsed, "duration": _duration, "progress": clampf(_elapsed / _duration, 0.0, 1.0) if _duration > 0.0 else 0.0}

func _process(delta: float) -> void:
	if _event.is_empty():
		return
	if board_ref == null or not is_instance_valid(board_ref.get_ref()):
		clear()
		return
	_elapsed += maxf(0.0, delta)
	if _elapsed >= _duration:
		clear()
	else:
		queue_redraw()

func _valid_cell(cell: int) -> bool:
	return cell >= 0 and cell < 50

func _project(cell: int, offset: Vector3) -> Vector2:
	var board = board_ref.get_ref()
	return board.project(board.point(cell) + offset)

func _stroke(cell: int, offsets: Array, color: Color, width: float = 1.7) -> void:
	var points = PackedVector2Array()
	for offset in offsets:
		points.append(_project(cell, offset))
	if points.size() > 1:
		draw_polyline(points, color, width, true)

func _ground_arc(cell: int, radius: float, start: float, span: float, color: Color) -> void:
	var offsets: Array = []
	for index in range(17):
		var angle = start + span * float(index) / 16.0
		offsets.append(Vector3(cos(angle) * radius, .055, sin(angle) * radius))
	_stroke(cell, offsets, color)

func _ring(cell: int, progress: float, color: Color) -> void:
	# Shared restrained activation mark; no success or damage claim.
	_ground_arc(cell, .18 + progress * .22, 0.0, TAU, color)
	_ground_arc(cell, .11 + progress * .12, .15, PI * 1.2, color * Color(1, 1, 1, .55))

func _burst(cell: int, progress: float, color: Color) -> void:
	# Shared angular hit/pressure motif. Entire mark remains in the recipient cell.
	for index in range(4):
		var angle = PI * .25 + float(index) * PI * .5
		var near = .08 + progress * .08
		var far = .22 + progress * .22
		_stroke(cell, [Vector3(cos(angle) * near, .09, sin(angle) * near), Vector3(cos(angle) * far, .09, sin(angle) * far)], color, 2.0)

func _shield_outline(cell: int) -> PackedVector2Array:
	# Face the camera so the shield remains distinct from a ground ring at every
	# view angle. Keep its bottom above the fixed 18px selection ring and HP text.
	var foot = _project(cell, Vector3(0, .03, 0))
	var raised = _project(cell, Vector3(0, .65, 0))
	var height = clampf(foot.distance_to(raised) * .72, 22.0, 30.0)
	var bottom = Vector2(foot.x, minf(foot.y - 26.0, raised.y + height * .5))
	var half_width = height * .43
	return PackedVector2Array([bottom + Vector2(-half_width, -height), bottom + Vector2(half_width, -height), bottom + Vector2(half_width * .92, -height * .4), bottom, bottom + Vector2(-half_width * .92, -height * .4), bottom + Vector2(-half_width, -height)])

func _shield(cell: int, color: Color) -> void:
	# Outline only: no filled plate over portraits, labels or actual HP values.
	# The supplied guarding/cover state never claims success or damage reduction.
	var points = _shield_outline(cell)
	draw_polyline(points, Color(Color("#19313e"), color.a * .9), 4.0, true)
	draw_polyline(points, Color(Color("#e2eef3"), color.a), 2.1, true)
	var top = (points[0] + points[1]) * .5
	draw_line(top.lerp(points[3], .20), top.lerp(points[3], .63), Color(Color("#e2eef3"), color.a * .75), 1.4, true)

func _attack_preparation(origin: int, recipient: int, progress: float, color: Color) -> void:
	if not _valid_cell(recipient) or origin == recipient:
		return
	var board = board_ref.get_ref()
	var direction: Vector3 = (board.point(recipient) - board.point(origin)).normalized()
	# Confine the neutral travel mark to the caster cell. Only hurt emits a hit.
	var near = direction * (.08 + progress * .26)
	var far = direction * (.22 + progress * .30)
	near.y = .09
	far.y = .09
	_stroke(origin, [near, far], color, 1.7)
	var side = Vector3(-direction.z, 0, direction.x) * .09
	_stroke(origin, [near + side, far + side], Color(color, color.a * .5), 1.2)

func _draw() -> void:
	if _event.is_empty() or board_ref == null or not is_instance_valid(board_ref.get_ref()):
		return
	var board = board_ref.get_ref()
	if not board.has_method("point") or not board.has_method("project"):
		return
	var t = clampf(_elapsed / _duration, 0.0, 1.0)
	var fade = sin(PI * t) * .76
	var origin = int(_event.get("origin", -1))
	var recipient = int(_event.get("recipient", -1))
	var skill = str(_event.get("skill_id", ""))
	var phase = str(_event.get("phase", ""))
	if phase == "action":
		_ring(origin, t, Color(MINT if skill == "mage" else INK, fade * .6))
		if skill == "legSweep":
			for cell in _event.get("cells", []):
				# Local arcs never imply a successful knockdown or expand the range.
				_ground_arc(cell, .28 + t * .23, -.8 + t * .7, PI * 1.05, Color(INK, fade))
				_ground_arc(cell, .19 + t * .2, -.5 + t * .7, PI * .72, Color(OCHRE, fade * .65))
		elif skill == "stamp":
			for cell in _event.get("cells", []):
				var inset = .26 + t * .16
				_stroke(cell, [Vector3(-inset, .055, -.3), Vector3(0, .055, -.1), Vector3(inset, .055, -.3)], Color(INK, fade), 2.0)
				_stroke(cell, [Vector3(-inset, .055, .05), Vector3(0, .055, .25), Vector3(inset, .055, .05)], Color(OCHRE, fade), 2.0)
		elif skill == "attack":
			_attack_preparation(origin, recipient, t, Color(INK, fade * .75))
		elif skill == "guard":
			_shield(origin, Color(INK, fade))
	elif phase == "heal":
		_ring(recipient, t, Color(MINT, fade * .7))
		for index in range(5):
			var angle = float(index) * TAU / 5.0
			var rise = .28 + t * .57 + float(index % 2) * .1
			var offset = Vector3(cos(angle) * .22, rise, sin(angle) * .22)
			_stroke(recipient, [offset, offset + Vector3(0, .10, 0)], Color(MINT if index % 2 == 0 else INK, fade), 2.0)
	elif phase == "hurt":
		_burst(recipient, t, Color(INK, fade))
		if bool(_event.get("guarding", false)) or bool(_event.get("redirected", false)):
			_shield(recipient, Color(INK, fade * .8))
