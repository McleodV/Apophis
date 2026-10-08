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

@export_group("Columns")
## Average distance between facet columns along a wall. Lower = more, narrower facets.
## Columns may share rim and base points, so they can stand closer than a lattice step.
@export_range(0.05, 3.0, 0.01) var column_width: float = 0.11
## Spread of column spacing. 0 = even, 1 = from very narrow to twice the average.
@export_range(0.0, 1.0, 0.01) var column_width_variance: float = 0.6
## Most a face stands out from the hex edge. Faces step between flush and this far out.
## Also limited by edge_max_push.
@export_range(0.0, 0.3, 0.005) var column_depth: float = 0.08
## Spread of the depth change from one face to the next. 0 = every step is column_depth,
## 1 = from no step to column_depth.
@export_range(0.0, 1.0, 0.01) var column_depth_variance: float = 0.6
## Random reduction of depth per facet corner, so faces step in and out a little with height.
## 0 = faces straight up and down, 1 = corners anywhere from flat to full depth.
@export_range(0.0, 1.0, 0.01) var column_depth_jitter: float = 0.3
## Max sideways shift of each facet corner, as a fraction of the space to the neighboring columns.
## Columns never cross.
@export_range(0.0, 1.0, 0.01) var column_wander: float = 0.85
## Average width of the flat faces along a wall. Each face looks straight out; neighboring faces
## sit at different depths, joined by a short step. Lower = more, smaller steps.
@export_range(0.05, 3.0, 0.01) var face_width: float = 0.15
## Spread of face width. 0 = even, 1 = from one band to twice the average.
@export_range(0.0, 1.0, 0.01) var face_width_variance: float = 0.6
## Chance a step between faces is 2 bands wide instead of 1, so it is less steep.
@export_range(0.0, 1.0, 0.01) var slope_split_chance: float = 0.4
## Chance a column starts at the rim but merges into its outer neighbor partway down.
## The upper wall then has more, narrower facets than the lower wall.
@export_range(0.0, 1.0, 0.01) var column_branch_chance: float = 0.5

@export_group("Facets")
## Average vertical gap between facet corners on a column. Lower = more, shorter facets.
@export_range(0.02, 3.0, 0.01) var facet_height: float = 0.15
## How much facets shorten toward the rim. 0 = same height throughout.
## 1 = facets near the base 1.5x facet_height, near the rim 0.4x.
@export_range(0.0, 1.0, 0.01) var facet_height_taper: float = 0.75
## How much shorter facets are on faces that stand out than on ones sunk in. 0 = same, 1 = half.
@export_range(0.0, 1.0, 0.01) var ridge_detail: float = 0.6
## Spread of corner spacing from place to place along walls. 0 = even, 1 = from twice as dense to very sparse.
@export_range(0.0, 1.0, 0.01) var facet_height_variance: float = 0.3
## Random up/down shift of each column's facet corners, as a fraction of facet_height.
## Each column draws its own heights, so corners on neighboring columns don't line up into level rows.
@export_range(0.0, 0.9, 0.01) var facet_height_jitter: float = 0.7
## How far each facet corner wanders in or out, on top of its column's depth.
@export_range(0.0, 0.5, 0.005) var relief_amplitude: float = 0.04
## Noise frequency of corner wander. Higher = neighboring corners differ more.
@export_range(0.1, 20.0, 0.1) var relief_frequency: float = 4.0
@export var noise_seed: int = 0

@export_group("Profile")
## How far the face just below the rim sets back out from it, forming a lip.
@export_range(0.0, 0.3, 0.005) var lip_depth: float = 0.03
## How far the face just above the base sets back in from it, forming a foot.
@export_range(0.0, 0.3, 0.005) var foot_depth: float = 0.03

@export_group("Rim and Base")
## Max push of rim and base vertices. Keeps tile borders readable.
## Also kept under 0.6 lattice rows, which only binds at high subdivisions.
## Rims only push out, so they never pull back behind the grid line.
@export_range(0.0, 0.3, 0.005) var edge_max_push: float = 0.08
## Noise push of rim and base vertices outside column ends, as a fraction of edge_max_push.
@export_range(0.0, 1.0, 0.01) var edge_relief_scale: float = 0.5
