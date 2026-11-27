extends Node

## Exercises [GSShaderGroupArm]: nothing to arm headless, and the viewport it builds draws one lightmapped box in a world of its own.

const CHECKS := 5

var _passed := 0
var _failed := 0


func _ready() -> void:
	GSLog.set_level(GSLog.Level.ERROR)
	print("gs-core shader group arm self-test")
	_check(not GSShaderGroupArm.wanted(), "a headless run has no shader group to arm")
	_check(GSShaderGroupArm.start(self) == null, "so start adds nothing")
	var arm := GSShaderGroupArm.new()
	add_child(arm)
	var gi := arm.find_children("*", "LightmapGI", true, false)
	var boxes := arm.find_children("Box", "MeshInstance3D", true, false)
	_check(arm.own_world_3d and arm.size == Vector2i(4, 4), "a 4x4 viewport with its own world")
	_check(gi.size() == 1 and (gi[0] as LightmapGI).light_data != null, "one LightmapGI with data")
	_check(boxes.size() == 1 and (boxes[0] as MeshInstance3D).gi_mode == GeometryInstance3D.GI_MODE_STATIC, "one lightmapped box")
	arm.free()
	print("shader group arm: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 or _passed != CHECKS else 0)


func _check(condition: bool, what: String) -> void:
	if condition:
		_passed += 1
		print("  ok    " + what)
	else:
		_failed += 1
		print("  FAIL  " + what)
