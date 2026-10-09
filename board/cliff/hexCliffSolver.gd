class_name HexCliffSolver
extends RefCounted
## Weighted linear least squares over a few unknowns, for fitting slab planes.
## Add rows, each a weighted wish that a sum of unknowns times coefficients equal a value, then solve.
## Heavy rows act as constraints, light ones as preferences where constraints leave freedom.

# Added to the diagonal, so unknowns no row touches come out 0 instead of failing.
const _RIDGE: float = 1e-10

var _size: int = 0
var _matrix := PackedFloat64Array() # Normal equations, row-major
var _vector := PackedFloat64Array()


func _init(size: int) -> void:
	_size = size
	_matrix.resize(size * size)
	_vector.resize(size)


## Adds weight * (sum of coefficients[i] * unknown[columns[i]] - value)^2 to the error.
func add_row(columns: PackedInt32Array, coefficients: PackedFloat64Array, value: float, weight: float) -> void:
	for a: int in columns.size():
		var scaled: float = weight * coefficients[a]
		_vector[columns[a]] += scaled * value
		for b: int in columns.size():
			_matrix[columns[a] * _size + columns[b]] += scaled * coefficients[b]


## Unknowns with the least error. Gaussian elimination with partial pivoting.
func solve() -> PackedFloat64Array:
	var n: int = _size
	var m: PackedFloat64Array = _matrix.duplicate()
	var v: PackedFloat64Array = _vector.duplicate()
	for i: int in n:
		m[i * n + i] += _RIDGE
	for column: int in n:
		var pivot: int = column
		for row: int in range(column + 1, n):
			if absf(m[row * n + column]) > absf(m[pivot * n + column]):
				pivot = row
		if pivot != column:
			for c: int in n:
				var swap: float = m[column * n + c]
				m[column * n + c] = m[pivot * n + c]
				m[pivot * n + c] = swap
			var swap_value: float = v[column]
			v[column] = v[pivot]
			v[pivot] = swap_value
		var diagonal: float = m[column * n + column]
		if absf(diagonal) < 1e-300:
			continue
		for row: int in range(column + 1, n):
			var factor: float = m[row * n + column] / diagonal
			if factor == 0.0:
				continue
			for c: int in range(column, n):
				m[row * n + c] -= factor * m[column * n + c]
			v[row] -= factor * v[column]
	var x := PackedFloat64Array()
	x.resize(n)
	for row: int in range(n - 1, -1, -1):
		var sum: float = v[row]
		for c: int in range(row + 1, n):
			sum -= m[row * n + c] * x[c]
		var diagonal: float = m[row * n + row]
		x[row] = sum / diagonal if absf(diagonal) > 1e-300 else 0.0
	return x
