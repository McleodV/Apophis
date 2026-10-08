class_name HexCliffPlane
extends RefCounted
## A flat slab face in a cliff strip's wall coordinates.
## Push: how far the face stands out from the wall at rest, in world units. It changes linearly
## with height share (0 = base, 1 = rim) and with position along the wall (lattice steps), so every
## point on it lies on one plane.

## Push at the base, at origin.
var base: float = 0.0
## Change of push from base to rim.
var lean: float = 0.0
## Change of push per lattice step along the wall.
var turn: float = 0.0
## Along-wall position where turn adds nothing.
var origin: float = 0.0


func _init(base_push: float, lean_push: float, turn_push: float, origin_along: float) -> void:
	base = base_push
	lean = lean_push
	turn = turn_push
	origin = origin_along


func get_push(along: float, height: float) -> float:
	return base + lean * height + turn * (along - origin)
