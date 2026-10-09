class_name HexCliffColumn
extends RefCounted
## One facet column of a cliff strip: a chain of facet corners from a rim point down to a base point.
## Spokes are shared lattice edges and keep every band. All other columns belong to the strip alone,
## so their corners can sit anywhere between the neighboring columns.
## Free columns are slab edges: their corners lie on their slab's tiers, along a line that may slant.
## Positions along the wall are in lattice steps from the strip's first rim point:
## rim point b sits at b, base point b at b + 0.5. Heights are shares of the wall (0 = base, 1 = rim).

## Rim index of the top end.
var top: int = 0
## Base index of the bottom end.
var bottom: int = 0
## Along-wall positions of its corner line at the base and at the rim, before sideways shift.
var along_bottom: float = 0.0
var along_top: float = 0.0
## True for the shared lattice edge at either end of the strip.
var is_spoke: bool = false
## True for spokes and forced columns: placed first, and free columns keep clear of them.
var is_fixed: bool = false
## True if its corners stay on the straight line between its ends, though its ends take its slab's
## pushes. A corner face to a spoke is then flat.
var is_straight: bool = false
## Slab its corners lie on. Null for fixed columns.
var slab: HexCliffSlab
## True if it lies on the turned side of its slab's split.
var turned: bool = false
## Heights where it crosses its slab's breaks, bottom to top. Corners at or above one take the tier above it.
var tier_breaks := PackedFloat32Array()
## Seam it belongs to, or -1. Columns of one seam share corner heights and sideways shift, so they
## keep their order at every height.
var seam: int = -1
## The seam's middle line: Vector2(along at the base, along at the rim).
var seam_line := Vector2.ZERO
## Breaks to give corners: (height, 1 for a ledge or 0 for a fold, break id). Its own slab's breaks,
## and for seam columns the other slab's too. Ids are unique per strip, so neighboring columns can
## tell which breaks they share.
var breaks := PackedVector3Array()
## Max sideways shift of its corners, in lattice steps. Keeps neighboring columns from crossing.
var room: float = 0.0


## Column on crossing edge k, which joins rim (k + 1) / 2 to base k / 2.
static func from_edge(k: int, spoke: bool) -> HexCliffColumn:
	var column := HexCliffColumn.new()
	column.top = HexCliffStrip.get_top_index(k)
	column.bottom = HexCliffStrip.get_bottom_index(k)
	column.along_top = column.top
	column.along_bottom = column.bottom + 0.5
	column.is_spoke = spoke
	column.is_fixed = true
	return column


## Free column along a line from the base to the rim, ending at the given rim and base indices.
static func from_line(line: Vector2, top_index: int, bottom_index: int) -> HexCliffColumn:
	var column := HexCliffColumn.new()
	column.along_bottom = line.x
	column.along_top = line.y
	column.top = top_index
	column.bottom = bottom_index
	return column


## Along-wall position of its corner line at height.
func get_along(height: float) -> float:
	return lerpf(along_bottom, along_top, height)


## Along-wall span of its ends: the column's sideways extent with no shift.
func get_end_span() -> Vector2:
	return Vector2(minf(top, bottom + 0.5), maxf(top, bottom + 0.5))


## Push of a corner at along and height. 0 for fixed columns.
func get_push(along: float, height: float) -> float:
	if slab == null:
		return 0.0
	var tier: int = 0
	for at: float in tier_breaks:
		if height >= at:
			tier += 1
	return slab.get_plane(tier, turned).get_push(along, height)


## Push of its rim point, from its top tier.
func get_top_push() -> float:
	return get_push(top, 1.0)


## Push of its base point, from its bottom tier.
func get_bottom_push() -> float:
	return get_push(bottom + 0.5, 0.0)
