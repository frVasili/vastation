class_name GlassBox
extends RefCounted
## Unit box mesh with 0..1 UVs on every face (the shaders light the edges from UV).

static var _centered: ArrayMesh
static var _grounded: ArrayMesh

## Box from -0.5..0.5 (centered) or with its base at y = 0 and top at y = 1 (grounded).
static func get_mesh(grounded: bool) -> ArrayMesh:
	if grounded:
		if _grounded == null:
			_grounded = _build(0.0, 1.0)
		return _grounded
	if _centered == null:
		_centered = _build(-0.5, 0.5)
	return _centered

static func _build(y0: float, y1: float) -> ArrayMesh:
	var h := 0.5
	var faces := [
		[Vector3(h, y1, h), Vector3(h, y1, -h), Vector3(h, y0, -h), Vector3(h, y0, h), Vector3.RIGHT],
		[Vector3(-h, y1, -h), Vector3(-h, y1, h), Vector3(-h, y0, h), Vector3(-h, y0, -h), Vector3.LEFT],
		[Vector3(-h, y1, h), Vector3(h, y1, h), Vector3(h, y0, h), Vector3(-h, y0, h), Vector3.BACK],
		[Vector3(h, y1, -h), Vector3(-h, y1, -h), Vector3(-h, y0, -h), Vector3(h, y0, -h), Vector3.FORWARD],
		[Vector3(-h, y1, -h), Vector3(h, y1, -h), Vector3(h, y1, h), Vector3(-h, y1, h), Vector3.UP],
		[Vector3(-h, y0, h), Vector3(h, y0, h), Vector3(h, y0, -h), Vector3(-h, y0, -h), Vector3.DOWN],
	]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for f: Array in faces:
		var base := verts.size()
		for i in 4:
			verts.append(f[i])
			norms.append(f[4])
			uv.append(uvs[i])
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
