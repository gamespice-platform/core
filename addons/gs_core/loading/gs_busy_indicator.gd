class_name GSBusyIndicator
extends CanvasLayer

## A small bottom-right panel that says the game is still working: a progress bar, what it is doing, and "the game may stutter".
## It stays up while any source is busy (the gate, a content download, a mount, a world build) and afterwards until frames are steady.
## It never covers the screen, so it also shows when a shell skips its cover. A [GSLoadGate] makes one by default.

## The [GSRegistry] name.
const SERVICE := &"gs_busy_indicator"
## Above the stock cover (120), so the bar is visible while it is up.
const LAYER := 125
const GATE_SOURCE := &"gate"
const DOWNLOAD_SOURCE := &"download"
const CONTENT_SOURCE := &"content"
## [enum GSCloudClient.Phase] values that mean work is going on: manifest through mounting.
const CLOUD_PHASE_FIRST := 1
const CLOUD_PHASE_LAST := 6
## [Engine] meta a host sets to true while its own full-screen cover (the shell's loading screen) is up. The cover already shows the bar and the text, so the panel stays hidden under it instead of drawing a second box over it.
const HOST_COVER_META := &"gs_host_cover_up"

## The user pressed the error's action button.
signal action_pressed()
## The panel appeared (true) or went away (false).
signal visibility_changed_to(shown: bool)

## A frame at or under this many milliseconds counts as steady.
@export var steady_msec: int = 80
## Consecutive steady frames wanted after the last source ends before the panel goes.
@export var steady_frames: int = 30
## The panel never stays longer than this after the last source ends, steady or not.
@export var max_tail_sec: float = 45.0
## Already-translated warning under the bar.
@export var warning_text: String = "Still loading, the game may stutter."
## Called by the error's action button; empty hides the button. A quota error from [method bind_cloud] fills it with clearing unpinned downloads.
var action_fn: Callable = Callable()

var _sources: Dictionary = {}
var _order: Array[StringName] = []
var _gate: Node = null
var _cloud: Object = null
var _service_wanted: StringName = &""
var _poll_msec := 0
var _tail := false
var _tail_start := 0
var _steady := 0
var _last_msec := 0
var _error := ""
var _error_action := ""
var _shown := false
var _panel: PanelContainer = null
var _status: Label = null
var _bar: ProgressBar = null
var _detail: Label = null
var _warning: Label = null
var _error_label: Label = null
var _button: Button = null


func _init() -> void:
	layer = LAYER
	name = "BusyIndicator"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _enter_tree() -> void:
	GSRegistry.register(SERVICE, self)


func _exit_tree() -> void:
	GSRegistry.unregister_instance(SERVICE, self)


func _ready() -> void:
	_build()
	_apply()


## The indicator registered by a gate or a game, or null.
static func current() -> GSBusyIndicator:
	var s: Variant = GSRegistry.get_service(SERVICE)
	return s as GSBusyIndicator if s is GSBusyIndicator else null


## Marks [param reason] busy. [param fraction] is 0..1 or -1 for none; [param detail] is a second line ("12 MB of 340 MB").
func begin(reason: StringName, text: String = "", fraction: float = -1.0, detail: String = "") -> void:
	if not _sources.has(reason):
		_order.append(reason)
	_sources[reason] = {"text": text, "fraction": fraction, "detail": detail}
	_tail = false
	_steady = 0
	_apply()


## Updates a source, starting it when new.
func update(reason: StringName, fraction: float, text: String = "", detail: String = "") -> void:
	var cur: Dictionary = _sources.get(reason, {})
	begin(reason, text if text != "" else str(cur.get("text", "")), fraction, detail if detail != "" else str(cur.get("detail", "")))


## Ends [param reason]. When the last one ends the panel waits for steady frames, then goes.
func end(reason: StringName) -> void:
	if not _sources.has(reason):
		return
	_sources.erase(reason)
	_order.erase(reason)
	if _sources.is_empty():
		_start_tail()
	_apply()


func is_busy() -> bool:
	return not _sources.is_empty()


## True while the panel is on screen: busy, in the steady-frames tail, or showing an error.
func is_showing() -> bool:
	return _shown


## True between the last source ending and the frames being steady.
func is_waiting_steady() -> bool:
	return _tail


## Shows a player-facing failure (kept until [method clear_error]) with an optional button.
func fail(text: String, action_text: String = "", action: Callable = Callable()) -> void:
	_error = text
	_error_action = action_text
	if action.is_valid():
		action_fn = action
	_apply()


func clear_error() -> void:
	_error = ""
	_error_action = ""
	_apply()


func error_text() -> String:
	return _error


## Follows [param gate]: busy while it is not open, with its status line and fraction.
func bind_gate(gate: Node) -> void:
	_gate = gate


## Follows a content client (a [code]GSCloudClient[/code], duck-typed): downloads with bytes and pack counts, the manifest-to-mount phases, and failures, a quota one with a clear-downloads button.
func bind_cloud(client: Object) -> void:
	if client == null or client == _cloud:
		return
	_cloud = client
	_link(client, &"job_progress_changed", _on_job)
	_link(client, &"progress_changed", _on_progress)
	_link(client, &"phase_changed", _on_phase)
	_link(client, &"failed", _on_failed)


func _link(client: Object, signal_name: StringName, handler: Callable) -> void:
	if client.has_signal(signal_name) and not client.is_connected(signal_name, handler):
		client.connect(signal_name, handler)


## Binds the client registered under [param service] as soon as there is one (a shell may build it after the game).
func watch_service(service: StringName) -> void:
	_service_wanted = service
	_try_service()


func _try_service() -> void:
	if _service_wanted == &"" or _cloud != null:
		return
	var s: Variant = GSRegistry.get_service(_service_wanted)
	if s is Object:
		bind_cloud(s)


func _on_job(snap: Dictionary) -> void:
	var total := int(snap.get("total_bytes", 0))
	var done := int(snap.get("done_bytes", 0))
	var packs := int(snap.get("total_packs", 0))
	if packs > 0 and int(snap.get("done_packs", 0)) >= packs and (total <= 0 or done >= total):
		end(DOWNLOAD_SOURCE)
		return
	var unpack := str(snap.get("phase", "")) == "unpack"
	var text := "Installing content" if unpack else "Downloading content"
	var detail := "%s of %s" % [GSPaths.format_bytes(done), GSPaths.format_bytes(total)] if total > 0 else ""
	if packs > 1:
		detail += (", " if detail != "" else "") + "part %d of %d" % [mini(int(snap.get("done_packs", 0)) + 1, packs), packs]
	update(DOWNLOAD_SOURCE, float(snap.get("fraction", -1.0)) if total > 0 or packs > 0 else -1.0, text, detail)


func _on_progress(p: Dictionary) -> void:
	if _sources.has(DOWNLOAD_SOURCE) and str((_sources[DOWNLOAD_SOURCE] as Dictionary)["detail"]).contains("part"):
		return  # the job's snapshot is the whole picture
	var total := int(p.get("total_bytes", 0))
	var done := int(p.get("done_bytes", 0))
	if total <= 0:
		return
	update(DOWNLOAD_SOURCE, clampf(float(done) / float(total), 0.0, 1.0), "Downloading content",
			"%s of %s" % [GSPaths.format_bytes(done), GSPaths.format_bytes(total)])
	if done >= total:
		end(DOWNLOAD_SOURCE)


func _on_phase(phase: int, text: String) -> void:
	if phase >= CLOUD_PHASE_FIRST and phase <= CLOUD_PHASE_LAST:
		if not _sources.has(CONTENT_SOURCE) or text != "":
			update(CONTENT_SOURCE, -1.0, text if text != "" else "Preparing content")
	else:
		end(CONTENT_SOURCE)
		end(DOWNLOAD_SOURCE)


func _on_failed(err: GSError) -> void:
	end(CONTENT_SOURCE)
	end(DOWNLOAD_SOURCE)
	var text := err.message if err != null and err.message != "" else "Content failed to load."
	if err != null and err.code == GSError.CODE_QUOTA:
		fail(text, "Clear downloaded content", _clear_downloads)
	else:
		fail(text)


func _clear_downloads() -> void:
	var store: Variant = _cloud.get(&"store") if _cloud != null and &"store" in _cloud else null
	if store is Object and (store as Object).has_method(&"clear_unpinned"):
		var res: Variant = await (store as Object).call(&"clear_unpinned")
		var ok: bool = res == null or not (res is GSResult) or (res as GSResult).ok
		if ok:
			clear_error()
		else:
			fail("Could not clear downloaded content. Use the menu's Clear downloaded content, or free browser storage.")


func _start_tail() -> void:
	_tail = true
	_steady = 0
	_tail_start = Time.get_ticks_msec()
	_last_msec = _tail_start


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _service_wanted != &"" and _cloud == null and now - _poll_msec > 500:
		_poll_msec = now
		_try_service()
	_follow_gate()
	if _tail:
		var frame := now - _last_msec
		_steady = _steady + 1 if frame <= steady_msec else 0
		if _steady >= steady_frames or now - _tail_start > int(max_tail_sec * 1000.0):
			_tail = false
			_apply()
	_last_msec = now
	if _shown != _wanted():
		_apply()
	elif _shown:
		_refresh()


func _follow_gate() -> void:
	if _gate == null or not is_instance_valid(_gate) or not _gate.has_method(&"is_open"):
		return
	# A host's own cover already shows the gate's line and bar.
	if bool(_gate.call(&"is_open")) or (_gate.has_method(&"is_hosted") and bool(_gate.call(&"is_hosted"))):
		end(GATE_SOURCE)
	else:
		var f: float = _gate.call(&"progress")
		var cur: Dictionary = _sources.get(GATE_SOURCE, {})
		var text: String = _gate.call(&"status_text")
		if not _sources.has(GATE_SOURCE) or f != float(cur["fraction"]) or text != cur["text"]:
			begin(GATE_SOURCE, text, f)


func _top() -> Dictionary:
	# Download detail wins the second line; the newest source names the work; the first with a fraction drives the bar.
	var text := ""
	var detail := ""
	var fraction := -1.0
	for r: StringName in _order:
		var s: Dictionary = _sources[r]
		var s_text: String = s["text"]
		var s_detail: String = s["detail"]
		if s_text != "":
			text = s_text
		if s_detail != "":
			detail = s_detail
		if float(s["fraction"]) >= 0.0:
			fraction = float(s["fraction"])
	if text == "" and _tail:
		text = "Finishing up"
	return {"text": text, "detail": detail, "fraction": fraction}


## True while a host's own cover is up (see [constant HOST_COVER_META]).
static func host_cover_up() -> bool:
	return bool(Engine.get_meta(HOST_COVER_META, false))


func _wanted() -> bool:
	return (is_busy() or _tail or _error != "") and not host_cover_up()


func _apply() -> void:
	var show := _wanted()
	if show != _shown:
		_shown = show
		visible = show
		visibility_changed_to.emit(show)
	if _shown:
		_refresh()


func _refresh() -> void:
	if _panel == null:
		return
	var top := _top()
	var top_text: String = top["text"]
	var top_detail: String = top["detail"]
	_status.text = top_text
	_detail.text = top_detail
	_detail.visible = _detail.text != ""
	var fraction := float(top["fraction"])
	_bar.visible = is_busy() or _tail
	_bar.indeterminate = fraction < 0.0
	if fraction >= 0.0:
		_bar.value = clampf(fraction, 0.0, 1.0) * 100.0
	_warning.text = warning_text
	_warning.visible = (is_busy() or _tail) and warning_text != ""
	_error_label.text = _error
	_error_label.visible = _error != ""
	_button.text = _error_action
	_button.visible = _error != "" and _error_action != "" and action_fn.is_valid()


func _build() -> void:
	if _panel != null:
		return
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_right = -16
	_panel.offset_bottom = -16
	_panel.custom_minimum_size = Vector2(320, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.82)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 5)
	_panel.add_child(box)
	_status = _label(box, 15, Color(0.88, 0.9, 0.94))
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 8)
	_bar.show_percentage = false
	_bar.max_value = 100.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_bar)
	_detail = _label(box, 13, Color(0.7, 0.74, 0.8))
	_warning = _label(box, 13, Color(1.0, 0.8, 0.35))
	_error_label = _label(box, 13, Color(1.0, 0.5, 0.45))
	_button = Button.new()
	_button.pressed.connect(_on_button)
	box.add_child(_button)


func _label(parent: Node, size: int, color: Color) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _on_button() -> void:
	action_pressed.emit()
	if action_fn.is_valid():
		action_fn.call()


func describe() -> Dictionary:
	return {
		"showing": _shown, "busy": is_busy(), "waiting_steady": _tail, "steady_frames": _steady,
		"sources": _order.map(func(r: StringName) -> String: return String(r)), "error": _error,
	}
