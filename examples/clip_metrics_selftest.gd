extends Node

## GSClipMetrics.pose_sample follows the leg the mesh deforms, not an IK control foot bone under the root.
## godot --headless --path . res://examples/clip_metrics_selftest.tscn

const SECTIONS := 1
const CHECKS := 6

var _failed := 0
var _checks := 0
var _sections := 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failed += 1


func _build(control: bool) -> Skeleton3D:
	var sk := Skeleton3D.new()
	sk.add_bone("Root")
	sk.add_bone("Hips")
	sk.add_bone("LowerLeg.L")
	sk.add_bone("Foot.L")
	sk.set_bone_parent(1, 0)
	sk.set_bone_parent(2, 1)
	sk.set_bone_parent(3, 0 if control else 2)
	sk.set_bone_rest(1, Transform3D(Basis(), Vector3(0, 0.9, 0)))
	sk.set_bone_rest(2, Transform3D(Basis(), Vector3(0, -0.45, 0)))
	sk.set_bone_rest(3, Transform3D(Basis(), Vector3(0, 0.02, 0) if control else Vector3(0, -0.43, 0)))
	sk.reset_bone_poses()
	return sk


func _ready() -> void:
	for control in [true, false]:
		var sk := _build(control)
		add_child(sk)
		var m := GSClipMetrics.new()
		var rest: Dictionary = m.pose_sample(0.0, sk, Vector3.ZERO, true)
		sk.set_bone_pose_position(1, Vector3(0, 0.8, 0))
		sk.set_bone_pose_position(3, sk.get_bone_pose_position(3) + Vector3(0, -0.3, 0)) if control else null
		var low: Dictionary = m.pose_sample(0.1, sk, Vector3.ZERO, true)
		var drop: float = (rest["feet"][0] as Vector3).y - (low["feet"][0] as Vector3).y
		# Hips drop 0.1: a leg-driven ankle falls 0.1 whatever the control bone does.
		_check(absf(drop - 0.1) < 0.001, "%s foot: ankle follows the leg (fell %.3f)" % ["control" if control else "child", drop])
		sk.queue_free()
	# The sole is the rest pose's, so a first sample taken mid-blend (hips already 0.1 low) still reads the drop.
	var mid := _build(false)
	add_child(mid)
	mid.set_bone_pose_position(1, Vector3(0, 0.8, 0))
	var first: Dictionary = GSClipMetrics.new().pose_sample(0.0, mid, Vector3.ZERO, true)
	_check(absf((first["feet"][0] as Vector3).y + 0.1) < 0.001, "sole comes from the rest pose, not a mid-blend first frame (foot y %.3f)" % (first["feet"][0] as Vector3).y)
	mid.queue_free()
	# A look that scales the hips 1.5x lifts the standing ankles with it: the sole is read at the pose's scales.
	var big := _build(false)
	add_child(big)
	big.set_bone_pose_scale(1, Vector3.ONE * 1.5)
	var tall: Dictionary = GSClipMetrics.new().pose_sample(0.0, big, Vector3.ZERO, true)
	# The scaled ankle stands at -0.42 (0.9 - 1.5 * 0.88), the unscaled one at 0.02: the foot reads 0 only against the scaled sole.
	_check(absf((tall["feet"][0] as Vector3).y) < 0.001, "sole follows the pose's bone scales (foot y %.3f)" % (tall["feet"][0] as Vector3).y)
	big.queue_free()
	# Height limits are for a 1x body: a foot 0.16 m up in the world is planted on a skeleton stretched 2x tall, hovering on a 1x one.
	for tall_body in [true, false]:
		var lifted := _build(false)
		lifted.scale = Vector3(1.0, 2.0 if tall_body else 1.0, 1.0)
		add_child(lifted)
		var gauge := GSClipMetrics.new()
		gauge.pose_sample(0.0, lifted, Vector3.ZERO, true)
		lifted.set_bone_pose_position(1, Vector3(0, 0.98 if tall_body else 1.06, 0))
		for n in 4:
			gauge.add(gauge.pose_sample(0.1 * n, lifted, Vector3.ZERO, true))
		var row: Dictionary = {}
		for r in gauge.evaluate({"float_m": 0.12}):
			if r["check"] == "floor_contact":
				row = r
		_check(bool(row["pass"]) == tall_body, "%s body, foot 0.16 m up: floor_contact %s (hover %.2f)" % ["2x" if tall_body else "1x", "passes" if row["pass"] else "fails", float(row["value"])])
		lifted.queue_free()
	_sections += 1
	print("clip_metrics_selftest: %d sections, %d checks, %d failed" % [_sections, _checks, _failed])
	if _sections != SECTIONS or _checks != CHECKS:
		print("ERROR: %d of %d sections, %d of %d checks ran." % [_sections, SECTIONS, _checks, CHECKS])
		get_tree().quit(1)
		return
	get_tree().quit(1 if _failed > 0 else 0)
