class_name HexCliffColumn
extends RefCounted
## One facet column of a cliff strip: a chain of facet corners from a rim point down to a base point.
## Spokes are shared lattice edges and keep every band. All other columns belong to the strip alone,
## so their corners can sit anywhere between the neighboring columns.
## Free columns are slab edges: their corners lie on their slab's planes.
## Positions along the wall are in lattice steps from the strip's first rim point:
## rim point b sits at b, base point b at b + 0.5. Heights are shares of the wall (0 = base, 1 = rim).

## Rim index of the top end.
var top: int = 0
## Base index of the bottom end.
var bottom: int = 0
## Along-wall position of its corners before sideways shift.
var along: float = 0.0
## True for the shared lattice edge at either end of the strip.
var is_spoke: bool = false
## True for spokes and forced columns: placed first, and free columns keep clear of them.
var is_fixed: bool = false
## Plane its corners lie on below its break, or throughout if it has none. Null for fixed columns.
var lower: HexCliffPlane
## Plane above its break. Same as lower without one.
var upper: HexCliffPlane
## Break height, or above 1 for none.
var break_height: float = 2.0
## True if the lower plane stands out at the break, joined to the upper one by a small ledge.
var has_ledge: bool = false
## Middle of the seam it edges. Both edges of a seam take their corner heights and sideways shift
## from it, so they keep their order at every height. NAN if it edges no seam.
var seam_center: float = NAN
## Breaks to give corners: (height, 1 for a ledge or 0 for a kink, break id). Its own break, and its
## seam partner's, so both edges of a seam keep the same corner heights. Ids are unique per strip,
## so neighboring columns can tell which breaks they share.
var breaks := PackedVector3Array()
## Max sideways shift of its corners, in lattice steps. Keeps neighboring columns from crossing.
var room: float = 0.0


## Column on crossing edge k, which joins rim (k + 1) / 2 to base k / 2.
static func from_edge(k: int, spoke: bool) -> HexCliffColumn:
	var column := HexCliffColumn.new()
	column.top = HexCliffStrip.get_top_index(k)
	column.bottom = HexCliffStrip.get_bottom_index(k)
	column.along = (column.top + column.bottom + 0.5) * 0.5
	column.is_spoke = spoke
	column.is_fixed = true
	return column


## Free column at a position along the wall, ending at the nearest rim and base points.
static func from_position(along_steps: float) -> HexCliffColumn:
	var column := HexCliffColumn.new()
	column.along = along_steps
	column.top = roundi(along_steps)
	column.bottom = roundi(along_steps - 0.5)
	return column


## Along-wall span of its ends: the column's sideways extent with no shift.
func get_end_span() -> Vector2:
	return Vector2(minf(top, bottom + 0.5), maxf(top, bottom + 0.5))


## Push of a corner at along and height. 0 for fixed columns.
func get_push(along_steps: float, height: float) -> float:
	if lower == null:
		return 0.0
	return (upper if height >= break_height else lower).get_push(along_steps, height)


## Push of its rim point, from its upper plane.
func get_top_push() -> float:
	return get_push(top, 1.0)


## Push of its base point, from its lower plane.
func get_bottom_push() -> float:
	return get_push(bottom + 0.5, 0.0)
