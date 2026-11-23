extends Node

## Exercises GSBusyIndicator hiding under a host's own cover (Engine meta gs_host_cover_up).

var _passed := 0
var _failed := 0


func _ready() -> void:
	GSLog.set_level(GSLog.Level.ERROR)
	print("gs-core busy indicator self-test")
	var ind := GSBusyIndicator.new()
	add_child(ind)
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
	print("%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 or _passed < 4 else 0)


func _check(what: String, ok: bool) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)
