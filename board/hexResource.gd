class_name HexResource
extends Object
## Resource types a tile produces, and per-tile output limits.

enum Type { FOOD, TRADE, INDUSTRY, PHENOMENA }

const COUNT: int = 4
## Max combined base output of all types on one tile. Also the max for a single type.
const MAX_TILE_TOTAL: int = 4
