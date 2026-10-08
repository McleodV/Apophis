class_name HexCliffSlab
extends RefCounted
## One flat slab of a cliff strip, between two seams or a seam and a fixed column.
## A slab may break at a height: its lower part can stand out further (a ledge), and its upper part
## can split in two along a short seam that fades out at the break.
## Positions along the wall are in lattice steps, heights are shares of the wall (0 = base, 1 = rim).

## Along-wall span of its edge columns.
var left: float = 0.0
var right: float = 0.0
## Plane below the break, or of the whole slab if it has none.
var lower: HexCliffPlane
## Plane above the break: of the whole upper part, or of the part not turned at the split.
var upper: HexCliffPlane
## Plane above the break on the turned side of the split. Null without a split.
var split_upper: HexCliffPlane
## Center of the split seam. INF without a split.
var split_at: float = INF
## True if the part left of the split is the turned one. Slabs on a spoke turn the part away from it.
var split_turns_left: bool = false
## Break height at left, or above 1 for none.
var break_height: float = 2.0
## Change of break height per lattice step, so ledges run at a slant.
var break_slope: float = 0.0
## True if the lower part stands out at the break.
var has_ledge: bool = false


func _init(left_along: float, right_along: float) -> void:
	left = left_along
	right = right_along


func get_upper(along: float) -> HexCliffPlane:
	if split_at == INF:
		return upper
	return split_upper if (along < split_at) == split_turns_left else upper


## Break height at along, or above 1 for none.
func get_break(along: float) -> float:
	if break_height > 1.0:
		return break_height
	return break_height + break_slope * (along - left)
