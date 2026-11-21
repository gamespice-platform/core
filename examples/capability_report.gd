extends Control

## Prints what this build can do, then exercises the pieces testable without a network. Run it on each export target:
## a web export without threads or an Android storage estimate that comes back unknown is invisible from a desktop run.
## Headless-friendly: [code]godot --headless --path . --scene examples/capability_report.tscn[/code]

@export var scheduler_ref: GSNodeRef

@onready var _output: RichTextLabel = $Output

var _scheduler: GSScheduler


func _ready() -> void:
	GSLog.set_level(GSLog.Level.DEBUG)

	# A GSNodeRef that creates what it cannot find: this scene ships without a
	# GSScheduler node, and the ref makes one. A host project that already has
	# a scheduler points the ref at theirs instead, changing nothing here.
	if scheduler_ref == null:
		scheduler_ref = GSNodeRef.of_created(&"Scheduler", GSScheduler)

	var res := scheduler_ref.resolve(self)
	if res.ok:
		_scheduler = res.value as GSScheduler

	_report()
	await _exercise()


func _report() -> void:
	_line("[b]Platform[/b]")
	for l in GSPlatform.describe_lines():
		_line("  " + l)

	_line("")
	_line("[b]Storage[/b]")
	_line("  user dir         %s" % GSPaths.describe_user_dir())

	if GSPlatform.is_web():
		var est := await GSWeb.estimate_storage()
		if est.ok:
			var d: Dictionary = est.value
			_line("  browser quota    %s" % GSPaths.format_bytes(int(d.get("quota", 0))))
			_line("  browser used     %s" % GSPaths.format_bytes(int(d.get("usage", 0))))
		else:
			_line("  browser quota    unknown (%s)" % est.error.message)

	_line("")
	_line("[b]Transports[/b]")
	for t: GSTransport in [
		GSTransportWebSocket.new(),
		GSTransportENet.new(),
		GSTransportAuto.new(),
	]:
		var avail := t._is_available()
		_line("  %-12s %s" % [
			t._transport_name(),
			"available" if avail.ok else "unavailable — " + avail.error.message,
		])


func _exercise() -> void:
	_line("")
	_line("[b]Self-test[/b]")

	# Path sanitisation: the traversal must be refused, not cleaned up.
	var bad := GSPaths.safe_relative("../../etc/passwd")
	_line("  traversal        %s" % (
		"refused" if not bad.ok else "ACCEPTED — this is a bug"
	))

	var good := GSPaths.safe_relative("games/dm_arena/map.pck")
	_line("  normal path      %s" % (
		"accepted" if good.ok else "REFUSED — this is a bug"
	))

	# Hashing, through the scheduler, on a file we write ourselves.
	var probe_path := "user://gs_core_selftest.bin"
	var payload := GSHash.random_bytes(3 * 1024 * 1024)
	var written := GSPaths.write_bytes(probe_path, payload)

	if not written.ok:
		_line("  hash job         could not write probe: %s" % written.error.message)
	elif _scheduler == null:
		_line("  hash job         no scheduler")
	else:
		var expected := GSHash.sha256_bytes(payload)
		var job := GSHashJob.new(probe_path, expected)

		var started := Time.get_ticks_msec()
		_scheduler.set_boost(10.0)
		var hashed := await _scheduler.run(job)
		var elapsed := Time.get_ticks_msec() - started

		_line("  hash job         %s (%d ms, %s)" % [
			"matched" if hashed.ok else "FAILED: " + hashed.error.message,
			elapsed,
			"threaded" if GSPlatform.has_threads() else "sliced on main thread",
		])

		DirAccess.remove_absolute(probe_path)

	# Rate limiter: 5 permitted from a burst of 5, the sixth refused.
	var limiter := GSRateLimiter.new(1.0, 5.0)
	var allowed := 0
	for _i in range(10):
		if limiter.allow("probe"):
			allowed += 1
	_line("  rate limiter     %d/10 allowed, retry in %.1fs" % [
		allowed, limiter.retry_after("probe")
	])

	# Address parsing, including the IPv6 case that a naive split gets wrong.
	for addr in ["1.2.3.4", "1.2.3.4:27015", "[::1]:27015", "wss://x.dev/game"]:
		var p := GSTransport.normalise_address(addr, 27015)
		_line("  parse %-18s -> host=%s port=%d%s" % [
			addr, p["host"], p["port"],
			" scheme=" + str(p["scheme"]) if str(p["scheme"]) != "" else "",
		])

	_line("")
	_line("[b]done[/b]")

	if GSPlatform.is_headless():
		# Give the log sink a chance to flush before the process ends.
		await get_tree().process_frame
		get_tree().quit()


func _line(text: String) -> void:
	# Printed as well as displayed so a headless run is useful.
	print(text.replace("[b]", "").replace("[/b]", ""))
	if _output != null:
		_output.append_text(text + "\n")
