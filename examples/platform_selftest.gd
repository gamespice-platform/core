extends Node

## Exercises GSPlatform.has_touch(): the override beats the build, and a headless desktop has no touch.

var _passed := 0
var _failed := 0


func _ready() -> void:
	GSLog.set_level(GSLog.Level.ERROR)
	print("gs-core platform self-test")
	var build := GSPlatform.is_mobile() or (not GSPlatform.is_headless() and DisplayServer.is_touchscreen_available())
	GSPlatform.touch_override = -1
	_check("no override asks the build", GSPlatform.has_touch() == build)
	GSPlatform.touch_override = 1
	_check("override on", GSPlatform.has_touch())
	GSPlatform.touch_override = 0
	_check("override off", not GSPlatform.has_touch())
	GSPlatform.touch_override = -1
	_check("override cleared returns to the build", GSPlatform.has_touch() == build)
	if GSPlatform.is_headless() and not GSPlatform.is_mobile():
		_check("headless desktop reports no touch", not GSPlatform.has_touch())
	print("%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 or _passed < 5 else 0)


func _check(what: String, ok: bool) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)
