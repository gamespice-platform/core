class_name GSCameraFade
extends Node
## Fades characters between a camera and its [member focus], and hides one that walks into the camera: a [member near] sphere goes transparent,
## a capsule to the focus sets [member faded]. Faded, not collided with, so a bot behind the player cannot pull the camera in.
## Fades every [GeometryInstance3D] under the hit body (or [member root_fn]'s), skipping any [Camera3D] subtree.

## Layers whose bodies fade: characters, never the level.
@export_flags_3d_physics var collision_mask: int = 0

## What the camera looks at. Null: only the near test runs.
var focus: Node3D = null

## Metres round the camera inside which a body is hidden outright.
@export var near: float = 0.25

## Radius of the line between the camera and the focus.
@export var line_radius: float = 0.25

## The line stops this far short of the focus, so the watched body is not on it.
@export var focus_clearance: float = 0.6

## How transparent a body on the line goes (0 opaque, 1 gone).
@export_range(0.0, 1.0) var faded: float = 0.7

## Seconds for a fade to go about two-thirds of the way.
@export var fade_time: float = 0.08

## [code](collider: Object) -> Node[/code]: whose meshes fade for a hit. Default: the
## collider itself.
var root_fn: Callable = Callable()

## [code]() -> Array[/code] of [Node3D]s that are not in the physics space (analytic players, remote
## figures with no client collider), each taken as an upright capsule of [member body_radius] and
## [member body_height] on its origin. Used as well as [member collision_mask], not instead.
var bodies_fn: Callable = Callable()

## The capsule [member bodies_fn]'s characters are taken as.
@export var body_radius: float = 0.35
@export var body_height: float = 1.8

var _excluded: Array[RID] = []
# instance id -> {"root": WeakRef, "meshes": Array, "amount": float, "target": float}
var _fading: Dictionary = {}
var _near_shape: SphereShape3D = null
var _line_shape: CapsuleShape3D = null


func _init() -> void:
	# After the camera has been placed for the frame, whatever placed it.
	process_priority = 1000


func add_excluded_object(rid: RID) -> void:
	if rid.is_valid() and not _excluded.has(rid):
		_excluded.append(rid)


func remove_excluded_object(rid: RID) -> void:
	_excluded.erase(rid)


func clear_excluded_objects() -> void:
	_excluded.clear()


func _process(delta: float) -> void:
	var camera := get_parent() as Node3D

	if camera == null or not camera.is_inside_tree():
		return

	var to := camera.global_position

	if focus != null and is_instance_valid(focus) and focus.is_inside_tree():
		to = focus.global_position

	update(camera.global_position, to, delta)


var _wanted: Dictionary = {}
## Per-frame scratch, reused: hits of the near sphere and of the line capsule, ids to drop,
## one query, and a read-only stand-in for "no entry".
var _near_hits: Array[Object] = []
var _line_hits: Array[Object] = []
var _gone: Array[int] = []
var _query: PhysicsShapeQueryParameters3D = null
const _NONE := {}


## One frame's fade, for a caller placing its own camera without this node's parent.
## Returns how many bodies are faded or fading.
func update(camera_position: Vector3, focus_position: Vector3, delta: float) -> int:
	var world := _world()
	# Reused every frame: a fresh Dictionary per update is garbage at the camera's rate.
	var wanted := _wanted
	wanted.clear()

	if world != null and collision_mask != 0:
		var space := world.direct_space_state

		_near(space, camera_position, _near_hits)
		for collider in _near_hits:
			wanted[collider] = 1.0

		_line(space, camera_position, focus_position, _line_hits)
		for collider in _line_hits:
			if not wanted.has(collider):
				wanted[collider] = faded

	if bodies_fn.is_valid():
		_analytic(camera_position, focus_position, wanted)

	if wanted.is_empty() and _fading.is_empty():
		return 0

	for collider in wanted:
		_target(collider as Object, float(wanted[collider]))

	for key: int in _fading:
		var entry: Dictionary = _fading[key]

		if not wanted.has(entry.get("collider")):
			entry["target"] = 0.0

	return _step(delta)


## Puts every faded body back as it was. Call on leaving, or when the camera stops being
## this player's.
func release() -> void:
	for key in _fading.keys():
		_apply(_fading[key], 0.0)

	_fading.clear()


func _exit_tree() -> void:
	release()


## The same two tests against upright capsules, for characters with no collider.
func _analytic(camera_position: Vector3, focus_position: Vector3, wanted: Dictionary) -> void:
	var offset := focus_position - camera_position
	var length := offset.length() - focus_clearance
	var line_end := camera_position + offset.normalized() * maxf(length, 0.0)

	for node in bodies_fn.call():
		var body := node as Node3D

		if body == null or not is_instance_valid(body) or not body.is_inside_tree() or not body.visible:
			continue

		var feet := body.global_position
		var low := feet + Vector3.UP * body_radius
		var high := feet + Vector3.UP * maxf(body_height - body_radius, body_radius)
		var on_axis := Geometry3D.get_closest_point_to_segment(camera_position, low, high)

		if on_axis.distance_to(camera_position) < near + body_radius:
			wanted[body] = 1.0
			continue

		if length <= line_radius * 2.0:
			continue

		var pair := Geometry3D.get_closest_points_between_segments(camera_position, line_end, low, high)

		if (pair[0] as Vector3).distance_to(pair[1] as Vector3) < line_radius + body_radius:
			wanted[body] = faded


func _near(space: PhysicsDirectSpaceState3D, at: Vector3, out: Array[Object]) -> void:
	out.clear()
	if near <= 0.0:
		return

	if _near_shape == null:
		_near_shape = SphereShape3D.new()

	_near_shape.radius = near
	_colliders(space, _near_shape, Transform3D(Basis.IDENTITY, at), out)


func _line(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, out: Array[Object]) -> void:
	out.clear()
	var offset := to - from
	var length := offset.length() - focus_clearance

	if length <= line_radius * 2.0:
		return

	var direction := offset.normalized()

	if _line_shape == null:
		_line_shape = CapsuleShape3D.new()

	_line_shape.radius = line_radius
	_line_shape.height = length

	# A capsule stands along its local Y; turn Y onto the line, and centre it on the part
	# of the line that is not the focus's clearance.
	var y := direction
	var x := y.cross(Vector3.UP)

	if x.length_squared() < 0.0001:
		x = y.cross(Vector3.RIGHT)

	x = x.normalized()
	var z := x.cross(y).normalized()
	var centre := from + direction * (length * 0.5)

	_colliders(space, _line_shape, Transform3D(Basis(x, y, z), centre), out)


func _colliders(space: PhysicsDirectSpaceState3D, shape: Shape3D, at: Transform3D, out: Array[Object]) -> void:
	if _query == null:
		_query = PhysicsShapeQueryParameters3D.new()
	var params := _query
	params.shape = shape
	params.transform = at
	params.collision_mask = collision_mask
	params.exclude = _excluded
	params.collide_with_areas = false

	for hit in space.intersect_shape(params, 16):
		var collider: Object = (hit as Dictionary).get("collider")

		if collider != null and not out.has(collider):
			out.append(collider)



func _target(collider: Object, amount: float) -> void:
	var root: Node = collider as Node

	if root_fn.is_valid():
		root = root_fn.call(collider) as Node

	if root == null:
		return

	var key := root.get_instance_id()
	var entry: Dictionary = _fading.get(key, _NONE)

	if entry.is_empty():
		entry = {"root": weakref(root), "meshes": [], "ids": {}, "hidden": {}, "amount": 0.0, "collider": collider}
		_fading[key] = entry

	# Collected again on every frame it is hit, merged: a figure that rebuilt its avatar
	# while faded has new meshes, and the old ones still have to be put back.
	var ids: Dictionary = entry["ids"]

	for ref in _meshes(root):
		var id := (ref as WeakRef).get_ref().get_instance_id() as int

		if not ids.has(id):
			ids[id] = true
			(entry["meshes"] as Array).append(ref)
			((ref as WeakRef).get_ref() as GeometryInstance3D).transparency = float(entry["amount"])

	entry["collider"] = collider
	entry["target"] = amount


func _step(delta: float) -> int:
	var factor := 1.0 - exp(-maxf(delta, 0.0) / maxf(fade_time, 0.001))

	_gone.clear()

	for key: int in _fading:
		var entry: Dictionary = _fading[key]

		if (entry["root"] as WeakRef).get_ref() == null:
			_gone.append(key)
			continue

		var target := float(entry.get("target", 0.0))
		var amount := lerpf(float(entry["amount"]), target, factor)

		if absf(amount - target) < 0.01:
			amount = target

		_apply(entry, amount)

		if amount <= 0.0 and target <= 0.0:
			_gone.append(key)

	# Erased after the walk: erasing from a Dictionary while iterating it is undefined.
	for key: int in _gone:
		_fading.erase(key)

	return _fading.size()


func _apply(entry: Dictionary, amount: float) -> void:
	entry["amount"] = amount
	var hidden: Dictionary = entry["hidden"]

	for ref in entry["meshes"]:
		var mesh := (ref as WeakRef).get_ref() as GeometryInstance3D

		if mesh == null:
			continue

		mesh.transparency = amount

		# Fully faded is also not drawn. `transparency` alone left an unshaded figure drawn
		# as a grey slab at 1.0 (mg-wipeout's stand-ins at the lens); only what this fade hid
		# is shown again, so a mesh the game hid stays hidden.
		var id := mesh.get_instance_id()
		if amount >= 0.99 and mesh.visible:
			mesh.visible = false
			hidden[id] = true
		elif amount < 0.99 and hidden.has(id):
			mesh.visible = true
			hidden.erase(id)


static func _meshes(root: Node) -> Array:
	var out: Array = []
	var stack: Array[Node] = [root]

	while not stack.is_empty():
		var node: Node = stack.pop_back()

		# Somebody's first-person camera carries their view model; leave it alone.
		if node is Camera3D:
			continue

		if node is GeometryInstance3D:
			out.append(weakref(node))

		for child in node.get_children():
			stack.append(child)

	return out


func _world() -> World3D:
	var node := get_parent() as Node3D

	if node != null and node.is_inside_tree():
		return node.get_world_3d()

	return null


## How many bodies are faded or fading now.
func faded_count() -> int:
	return _fading.size()


## Whether this body (or its [member root_fn] root) is faded more than half.
func is_faded(node: Node) -> bool:
	if node == null:
		return false

	var entry: Dictionary = _fading.get(node.get_instance_id(), _NONE)
	return not entry.is_empty() and float(entry["amount"]) > 0.5


func describe() -> Dictionary:
	return {
		"fading": _fading.size(),
		"focus": focus.name if focus != null and is_instance_valid(focus) else "",
		"mask": collision_mask,
		"near": near,
	}


func describe_lines() -> PackedStringArray:
	return PackedStringArray([
		"camera fade: %d bodies, near %.2f m, %s" % [
			_fading.size(), near, "line to a focus" if focus != null else "near only",
		]
	])
