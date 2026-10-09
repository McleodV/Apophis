class_name HexCliffSettings
extends Resource
## Tunable cliff face shape. Used by HexTerrainSurface.
## Distances are world units. Push is horizontal: positive = out toward the low side.

@export_group("Bands")
## Average vertical gap between candidate heights for facet corners.
@export_range(0.02, 1.0, 0.005) var band_height: float = 0.1
## Random height shift per band, as a fraction of band_height.
@export_range(0.0, 0.45, 0.01) var band_jitter: float = 0.25
## Height shift that varies along the wall, as a fraction of band_height.
@export_range(0.0, 0.45, 0.01) var band_wave: float = 0.3
## Noise frequency of the band wave. Higher = more undulation per wall.
@export_range(0.05, 10.0, 0.05) var band_wave_frequency: float = 1.5

@export_group("Slabs")
## Average width of the slabs a wall is made of. Lower = more, narrower slabs.
@export_range(0.05, 3.0, 0.01) var slab_width: float = 0.22
## Spread of slab width. 0 = even, 1 = from very narrow to twice the average.
@export_range(0.0, 1.0, 0.01) var slab_width_variance: float = 0.5
## Average height of the flat tiers a slab is stacked from. Lower = more, shorter tiers.
@export_range(0.05, 3.0, 0.01) var slab_height: float = 0.22
## Most a slab stands out from the wall at rest, at the rim and at the base.
## Also limited by edge_max_push. Tiers between may stand out further.
@export_range(0.0, 0.3, 0.005) var slab_depth: float = 0.08
## Least depth change between neighboring slabs where their seam opens, as a share of slab_depth.
@export_range(0.0, 1.0, 0.01) var slab_step: float = 0.5
## How far a tier turns left or right: the most its depth changes across it, as a share of slab_depth.
@export_range(0.0, 1.0, 0.01) var slab_turn: float = 0.8
## How far every other tier leans back, as a share of the wall's own run from base to rim.
## The others stand near upright. Higher = stronger folds between tiers.
@export_range(0.0, 2.0, 0.01) var slab_tilt: float = 1.0
## Random in and out of slab corners. 0 = perfectly flat tiers.
@export_range(0.0, 0.05, 0.001) var slab_roughness: float = 0.0
## Max sideways shift of slab edges and seams, as a share of the space to their neighbors.
## Edges never cross.
@export_range(0.0, 1.0, 0.01) var slab_edge_wander: float = 0.85

@export_group("Seams and Breaks")
## Width of the narrow faces joining neighboring slabs. Lower = steeper seams that look more sideways.
@export_range(0.01, 0.2, 0.005) var seam_width: float = 0.04
## Most a seam leans from upright, as sideways run per height. Higher = more diagonal seams.
@export_range(0.0, 2.0, 0.01) var seam_lean: float = 0.6
## Chance a seam starts as a point at the rim and opens toward the base. Otherwise it starts at the
## base and opens toward the rim.
@export_range(0.0, 1.0, 0.01) var seam_from_rim_chance: float = 0.5
## Most a break between tiers slants, as rise per run along the wall. Breaks in one slab slant the
## same way, at least about half this much. Higher = more diagonal breaks.
@export_range(0.0, 3.0, 0.01) var break_slant: float = 1.0
## Chance a break is a ledge: the lower tier stands out, joined to the upper one by a small face
## looking up. Otherwise it is a fold, where the tiers meet at an angle.
@export_range(0.0, 1.0, 0.01) var ledge_chance: float = 0.35
## Chance a slab's top tier splits in two along a seam that fades out at the break below it,
## so the upper wall has more, narrower slabs than the lower wall.
@export_range(0.0, 1.0, 0.01) var split_chance: float = 0.4

@export_group("Facets")
## Average vertical gap between corners along slab edges and spokes. Lower = more irregular edges.
@export_range(0.02, 3.0, 0.01) var facet_height: float = 0.15
## How much corner gaps shorten toward the rim. 0 = same throughout.
## 1 = gaps near the base 1.5x facet_height, near the rim 0.4x.
@export_range(0.0, 1.0, 0.01) var facet_height_taper: float = 0.75
## Spread of corner spacing from place to place along walls. 0 = even, 1 = from twice as dense to very sparse.
@export_range(0.0, 1.0, 0.01) var facet_height_variance: float = 0.3
## Random up/down shift of each column's corners, as a fraction of facet_height.
## Each column draws its own heights, so corners on neighboring columns don't line up into level rows.
@export_range(0.0, 0.9, 0.01) var facet_height_jitter: float = 0.7
## How far facet corners at cliff corners and ends, and on spokes, wander in or out.
## Slabs use slab_roughness instead.
@export_range(0.0, 0.5, 0.005) var relief_amplitude: float = 0.04
## Noise frequency of corner wander. Higher = neighboring corners differ more.
@export_range(0.1, 20.0, 0.1) var relief_frequency: float = 4.0
@export var noise_seed: int = 0

@export_group("Profile")
## At cliff corners and ends: how far the face just below the rim sets back out from it, forming a lip.
@export_range(0.0, 0.3, 0.005) var lip_depth: float = 0.03
## At cliff corners and ends: how far the face just above the base sets back in from it, forming a foot.
@export_range(0.0, 0.3, 0.005) var foot_depth: float = 0.03

@export_group("Rim and Base")
## Max push of rim and base vertices. Keeps tile borders readable.
## Also kept under 0.6 lattice rows, which only binds at high subdivisions.
## Rims only push out, so they never pull back behind the grid line.
@export_range(0.0, 0.3, 0.005) var edge_max_push: float = 0.08
## Noise push of rim and base vertices outside column ends, as a fraction of edge_max_push.
@export_range(0.0, 1.0, 0.01) var edge_relief_scale: float = 0.5
