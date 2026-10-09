class_name HexCliffSlab
extends RefCounted
## One slab of a cliff strip, between two seams, or a seam and an edge column of its run. Its edges
## may slant.
## A slab is stacked from flat tiers. Between two tiers runs a break line, often at a slant: at a fold
## the tiers meet at an angle, at a ledge the lower tier stands out and a small face joins them.
## The top tier may split in two along a short seam that fades out at the top break.
## Positions along the wall are in lattice steps, heights are shares of the wall (0 = base, 1 = rim).

## Edge lines: along-wall positions of its edge columns at the base and at the rim.
var left_bottom: float = 0.0
var left_top: float = 0.0
var right_bottom: float = 0.0
var right_top: float = 0.0
## Where its edge columns end, as Vector2(along at the rim, along at the base): rim and base points
## that take its top and bottom tiers' pushes.
var left_ends := Vector2.ZERO
var right_ends := Vector2.ZERO
## Where its left edge shares an end with the column before it, a seam's other edge or a spoke:
## 1 = rim, 0 = base, -1 = none.
var left_shared: int = -1
## Along-wall position of that shared end.
var left_shared_along: float = 0.0
## Where its right edge shares an end with a spoke after it, likewise.
var right_shared: int = -1
## Planes of its tiers, bottom to top.
var tiers: Array[HexCliffPlane] = []
## Breaks between tiers, bottom to top: (height at origin, change of height per lattice step,
## ledge depth at the left edge, at the right edge). Depths of 0 make a fold.
var breaks := PackedVector4Array()
## Top tier on the turned side of the split. Null without a split.
var split_upper: HexCliffPlane
## Along-wall position of the split seam. INF without a split.
var split_at: float = INF
## True if the part left of the split is the turned one.
var split_turns_left: bool = false


func _init(left_line: Vector2, right_line: Vector2) -> void:
	left_bottom = left_line.x
	left_top = left_line.y
	right_bottom = right_line.x
	right_top = right_line.y


## Along-wall position planes measure turn from: the left edge at mid-height.
func get_origin() -> float:
	return 0.5 * (left_bottom + left_top)


## Width at mid-height, in lattice steps.
func get_width() -> float:
	return 0.5 * (right_bottom + right_top) - get_origin()


## Along-wall span the slab covers at any height.
func get_span() -> Vector2:
	return Vector2(minf(left_bottom, left_top), maxf(right_bottom, right_top))


## Height of break j at along.
func get_break(j: int, along: float) -> float:
	return breaks[j].x + breaks[j].y * (along - get_origin())


## Ledge depth of break j at along: 0 for a fold.
func get_ledge(j: int, along: float) -> float:
	var t: float = (along - get_origin()) / maxf(get_width(), 0.001)
	return lerpf(breaks[j].z, breaks[j].w, t)


func is_turned(along: float) -> bool:
	return split_at < INF and (along < split_at) == split_turns_left


func get_plane(tier: int, turned: bool) -> HexCliffPlane:
	if turned and split_upper and tier == tiers.size() - 1:
		return split_upper
	return tiers[tier]


## Plane of the tier holding (along, height), as seen by breaks crossed at their own heights.
func get_plane_at(along: float, height: float) -> HexCliffPlane:
	var tier: int = 0
	for j: int in breaks.size():
		if height >= get_break(j, along):
			tier += 1
	return get_plane(tier, is_turned(along))
