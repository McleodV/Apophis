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
## How far columns alternately stand out (ridges) and sink in (grooves).
@export_range(0.0, 0.3, 0.005) var column_depth: float = 0.08
## Spread of depth from one ridge or groove to the next. 0 = all alike, 1 = from flat to full depth.
@export_range(0.0, 1.0, 0.01) var column_depth_variance: float = 0.4
## Random reduction of depth per facet corner, so columns step in and out with height.
## 0 = straight columns, 1 = corners anywhere from flat to full depth.
@export_range(0.0, 1.0, 0.01) var column_depth_jitter: float = 0.8
## Max sideways shift of each facet corner, as a fraction of the space to the neighboring columns.
## Columns never cross.
@export_range(0.0, 1.0, 0.01) var column_wander: float = 0.85
## Chance a slope between a ridge and a groove is 2 bands wide instead of 1, bent at an in-between column.
@export_range(0.0, 1.0, 0.01) var slope_split_chance: float = 0.5
## Chance an in-between column matches the ridge or groove beside it, so one band faces straight out.
@export_range(0.0, 1.0, 0.01) var slope_flat_chance: float = 0.35

@export_group("Facets")
## Average vertical gap between facet corners on a column. Lower = more, shorter facets.
@export_range(0.02, 3.0, 0.01) var facet_height: float = 0.14
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
