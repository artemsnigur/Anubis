class_name Carver
extends RefCounted
## Builds solid rock around carved-out rooms: the bounds are filled with 1 m cells,
## room rectangles are cleared, and the remaining cells are merged into as few boxes
## as possible (greedy meshing). Box sides show the painted tomb wall, tops the desert.


static func carve(parent: Node3D, bounds: Rect2i, rooms: Array, floor_y: float, top_y: float, mat: Material) -> int:
	var w := bounds.size.x
	var h := bounds.size.y
	var solid := PackedByteArray()
	solid.resize(w * h)
	solid.fill(1)
	for r: Rect2i in rooms:
		for z in range(maxi(r.position.y - bounds.position.y, 0), mini(r.end.y - bounds.position.y, h)):
			for x in range(maxi(r.position.x - bounds.position.x, 0), mini(r.end.x - bounds.position.x, w)):
				solid[z * w + x] = 0
	var used := PackedByteArray()
	used.resize(w * h)
	used.fill(0)
	var count := 0
	for z in h:
		for x in w:
			var i := z * w + x
			if solid[i] == 0 or used[i] == 1:
				continue
			var x1 := x
			while x1 + 1 < w and solid[z * w + x1 + 1] == 1 and used[z * w + x1 + 1] == 0:
				x1 += 1
			var z1 := z
			var grow := true
			while grow and z1 + 1 < h:
				for xx in range(x, x1 + 1):
					var j := (z1 + 1) * w + xx
					if solid[j] == 0 or used[j] == 1:
						grow = false
						break
				if grow:
					z1 += 1
			for zz in range(z, z1 + 1):
				for xx in range(x, x1 + 1):
					used[zz * w + xx] = 1
			var size := Vector3(float(x1 - x + 1), top_y - floor_y, float(z1 - z + 1))
			var center := Vector3(bounds.position.x + x + size.x * 0.5, (floor_y + top_y) * 0.5, bounds.position.y + z + size.z * 0.5)
			Kit.box(parent, center, size, mat)
			count += 1
	return count
