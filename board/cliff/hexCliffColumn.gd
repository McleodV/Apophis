class_name HexCliffColumn
extends RefCounted
## One facet column of a cliff strip: a chain of facet corners from a rim point down to a base point.
## Spokes are shared lattice edges and keep every band. All other columns belong to the strip alone,
## so their corners can sit anywhere between the neighboring columns.
## Positions along the wall are in lattice steps from the strip's first rim point:
## rim point b sits at b, base point b at b + 0.5.

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
## Signed depth. Positive = ridge, pushed out; negative = groove, pushed in.
var depth: float = 0.0
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
