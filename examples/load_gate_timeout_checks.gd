extends RefCounted

## The load gate self-test's timeout sections: the timeout naming the step, and [method GSLoadGate.advance] stretching it up to the ceiling. Runs against the self-test node [member t] for its helpers and log records.

var t: Node


func _init(selftest: Node) -> void:
	t = selftest


func test_advance() -> void:
	t._section("a step that advances is slow, not stuck")
	var gate: GSLoadGate = t._make()
	gate.timeout_sec = 1.0
	gate.timeout_ceiling_sec = 3.0
	gate.hold(&"models", "Preparing models")
	t._records.clear()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2000:
		gate.advance(&"models")
		await t.get_tree().process_frame
	t._check(not gate.is_open(), "advancing, it stays closed past its timeout", "%d ms" % (Time.get_ticks_msec() - t0))
	gate.release(&"models")
	t._check(await opens(gate, 15000, &""), "and opens once the step is released")
	t._check(gate_errors().is_empty(), "with no error", str(gate_errors()))
	t._drop(gate)

	gate = t._make()
	gate.timeout_sec = 1.0
	gate.timeout_ceiling_sec = 3.0
	gate.hold(&"models", "Preparing models")
	t0 = Time.get_ticks_msec()
	var opened := await opens(gate, 15000, &"models")
	var took := Time.get_ticks_msec() - t0
	t._check(opened and took >= 2900, "a step advancing forever is ended by the ceiling", "%d ms" % took)
	t._check(gate_errors().size() == 1, "with the timeout's error", str(gate_errors().size()))
	t._drop(gate)

	gate = t._make()
	gate.timeout_sec = 1.0
	gate.timeout_ceiling_sec = 30.0
	gate.hold(&"stuck", "Stuck")
	t0 = Time.get_ticks_msec()
	opened = await opens(gate, 25000, &"other")
	took = Time.get_ticks_msec() - t0
	t._check(opened and took < 20000, "advancing a reason not held stretches nothing", "%d ms" % took)
	t._check(not opened or took >= 900, "and the timeout still waits its own time", "%d ms" % took)
	t._drop(gate)


## Frames until [param gate] opens or [param msec] pass, advancing [param advancing] each frame.
func opens(gate: GSLoadGate, msec: int, advancing: StringName) -> bool:
	var t0 := Time.get_ticks_msec()
	while not gate.is_open() and Time.get_ticks_msec() - t0 < msec:
		if advancing != &"":
			gate.advance(advancing)
		await t.get_tree().process_frame
	return gate.is_open()


func gate_errors() -> Array:
	return t._records.filter(func(r: Dictionary) -> bool:
		return int(r["level"]) == GSLog.Level.ERROR and r["channel"] == GSLoadGate.CHANNEL)


func test_timeout() -> void:
	t._section("the timeout opens it with an error naming the step")
	var gate: GSLoadGate = t._make()
	gate.timeout_sec = 0.3
	gate.hold(&"map", "Loading the map")
	gate.require(&"never", func() -> bool: return false)
	t._records.clear()
	var t0 := Time.get_ticks_msec()
	while not gate.is_open() and Time.get_ticks_msec() - t0 < 15000:
		await t.get_tree().process_frame
	t._check(gate.is_open(), "open after the timeout")
	var warned := gate_errors()
	t._check(warned.size() == 1, "exactly one error", str(warned.size()))
	t._check(warned.size() == 1 and str((warned[0]["fields"] as Dictionary).get("step", "")) == "Loading the map", "it names the step the cover said", str(warned))
	var held: Array = (warned[0]["fields"] as Dictionary).get("still_held", []) if warned.size() > 0 else []
	t._check(held.has("map") and held.has("never"), "naming every reason still held", str(held))
	t._check(gate.reasons().is_empty(), "and nothing is held afterwards")
	var infos: Array = t._records.filter(func(r: Dictionary) -> bool:
		return int(r["level"]) == GSLog.Level.INFO and r["channel"] == GSLoadGate.CHANNEL)
	t._check(infos.size() == 1 and (infos[0]["fields"]["timed_out"] as Array).size() == 2, "the open line says it timed out", str(infos))
	t._drop(gate)
