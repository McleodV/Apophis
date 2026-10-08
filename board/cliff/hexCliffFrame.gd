class_name HexCliffFrame
extends RefCounted
## A cliff strip's wall coordinates: along the wall in lattice steps from the first rim point,
## out from the rim line in world units (toward the low side), and world height.

## Horizontal unit direction from the strip's first rim point to its last.
var along := Vector3.ZERO
## Horizontal unit direction the face looks.
var outward := Vector3.ZERO

var _origin := Vector3.ZERO
var _step: float = 1.0


## start, end: rest positions of the first and last rim points. spacing: lattice step.
func _init(start: Vector3, end: Vector3, out_direction: Vector3, spacing: float) -> void:
	_origin = Vector3(start.x, 0.0, start.z)
	along = Vector3(end.x - start.x, 0.0, end.z - start.z).normalized()
	outward = out_direction
	_step = spacing


func to_world(along_steps: float, out: float, height: float) -> Vector3:
	var position: Vector3 = _origin + along * (along_steps * _step) + outward * out
	position.y = height
	return position


func get_along(position: Vector3) -> float:
	return (position - _origin).dot(along) / _step


func get_out(position: Vector3) -> float:
	return (position - _origin).dot(outward)


## World length of one lattice step.
func get_step() -> float:
	return _step
