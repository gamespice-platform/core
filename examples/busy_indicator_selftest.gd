extends Node

## Exercises GSBusyIndicator hiding under a host's own cover (Engine meta gs_host_cover_up).

class StubGate:
	extends Node

	func is_open() -> bool:
		return false

	func progress() -> float:
		return 0.5

	func status_text() -> String:
		return "Loading"


var _passed := 0
var _failed := 0


func _ready() -> void:
	GSLog.set_level(GSLog.Level.ERROR)
	print("gs-core busy indicator self-test")
	var ind := GSBusyIndicator.new()
	add_child(ind)
	_check("idle indicator draws nothing (no empty box bottom-right)", not ind.visible and not ind.is_showing())
	ind.begin(&"a", "Working", 0.25)
	_check("shows while busy", ind.is_showing())
	Engine.set_meta(GSBusyIndicator.HOST_COVER_META, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("hidden under a host cover while still busy", not ind.is_showing() and ind.is_busy())
	ind.fail("Out of space")
	await get_tree().process_frame
	await get_tree().process_frame
	_check("an error is hidden under the cover too", not ind.is_showing())
	Engine.remove_meta(GSBusyIndicator.HOST_COVER_META)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("back when the cover goes", ind.is_showing())
	ind.clear_error()
	await get_tree().process_frame
	var problem := {"message": "Not enough browser storage for this map's art (needs 1.1 GiB, 700 MiB free).", "action": "clear_downloaded_content", "bytes": 1181116006, "free": 734003200}
	ind.show_art_problem(problem)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("an art problem is shown to the player", ind.is_showing() and ind.error_text() == problem["message"])
	var btns := ind.find_children("*", "Button", true, false)
	_check("with a clear-downloads button", btns.size() == 1 and (btns[0] as Button).visible)
	ind.clear_error()
	var gate := StubGate.new()
	gate.set_meta(&"art_problem", problem)
	ind.bind_gate(gate)
	await get_tree().process_frame
	_check("a closed gate's art_problem meta is shown once", ind.error_text() == problem["message"] and not gate.has_meta(&"art_problem"))
	gate.free()
	print("%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 or _passed < 7 else 0)


func _check(what: String, ok: bool) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)
