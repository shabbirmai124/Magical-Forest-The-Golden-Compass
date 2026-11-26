extends RefCounted
## Pure Godot 4 Procedural 3D Organic & Hard-Surface Mesh Factory.
## Builds anatomically sculpted character pieces, gnarled trees with buttress roots,
## crossed botanical foliage clusters, faceted boulders, fluted ruins, ornate blades,
## iron lantern cages, crystal spires, and astrolabe rings with proper winding, normals, UVs & tangents.


static func _emit_quad_cw(st: SurfaceTool, p00: Vector3, p10: Vector3, p11: Vector3, p01: Vector3, uv00: Vector2, uv10: Vector2, uv11: Vector2, uv01: Vector2) -> void:
	## Clockwise outward quad winding matching Godot's SurfaceTool normal & backface convention.
	st.set_uv(uv00); st.add_vertex(p00)
	st.set_uv(uv10); st.add_vertex(p10)
	st.set_uv(uv11); st.add_vertex(p11)
	st.set_uv(uv00); st.add_vertex(p00)
	st.set_uv(uv11); st.add_vertex(p11)
	st.set_uv(uv01); st.add_vertex(p01)


static func _emit_island_band(st: SurfaceTool, a0: Vector3, b0: Vector3, a1: Vector3, b1: Vector3, v0: float, v1: float) -> void:
	_emit_quad_cw(st, a0, a1, b1, b0, Vector2(0.0, v0), Vector2(0.0, v1), Vector2(1.0, v1), Vector2(1.0, v0))


static func _emit_island_wall(st: SurfaceTool, t0: Vector3, t1: Vector3, m0: Vector3, m1: Vector3, l0: Vector3, l1: Vector3, b0: Vector3, b1: Vector3) -> void:
	_emit_island_band(st, t0, t1, m0, m1, 0.0, 0.3)
	_emit_island_band(st, m0, m1, l0, l1, 0.3, 0.65)
	_emit_island_band(st, l0, l1, b0, b1, 0.65, 1.0)


static func build_lofted_tube_mesh(rings: Array, radial_segments: int = 12, cap_ends: bool = true, ridge_lobes: int = 0, ridge_amp: float = 0.0, flat_shaded: bool = false, with_tangents: bool = true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if flat_shaded:
		st.set_smooth_group(-1)

	var ring_verts: Array = []
	for r_idx in rings.size():
		var cfg: Dictionary = rings[r_idx]
		var center: Vector3 = cfg.get("center", Vector3.ZERO)
		var rx: float = maxf(float(cfg.get("rx", 0.2)), 0.008)
		var rz: float = maxf(float(cfg.get("rz", rx)), 0.008)
		var flute_w: float = float(cfg.get("flute", 1.0))
		var rot_y: float = float(cfg.get("twist", 0.0))

		var row: Array[Vector3] = []
		for j in range(radial_segments + 1):
			var u := float(j) / float(radial_segments)
			var ang := u * TAU + rot_y
			var mod_r := 1.0
			if ridge_lobes > 0 and ridge_amp > 0.0:
				mod_r += ridge_amp * flute_w * cos(ang * float(ridge_lobes) + float(r_idx) * 0.12)
			row.append(center + Vector3(cos(ang) * rx * mod_r, 0.0, sin(ang) * rz * mod_r))
		ring_verts.append(row)

	for r_idx in range(rings.size() - 1):
		var v0 := float(rings[r_idx].get("v", float(r_idx) / maxf(float(rings.size() - 1), 1.0)))
		var v1 := float(rings[r_idx + 1].get("v", float(r_idx + 1) / maxf(float(rings.size() - 1), 1.0)))
		for j in radial_segments:
			var u0 := float(j) / float(radial_segments)
			var u1 := float(j + 1) / float(radial_segments)
			_emit_quad_cw(
				st,
				ring_verts[r_idx][j], ring_verts[r_idx][j + 1],
				ring_verts[r_idx + 1][j + 1], ring_verts[r_idx + 1][j],
				Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)
			)

	if cap_ends and rings.size() >= 2:
		var c_bot: Vector3 = rings[0].get("center", Vector3.ZERO)
		for j in radial_segments:
			var u0 := float(j) / float(radial_segments)
			var u1 := float(j + 1) / float(radial_segments)
			st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(c_bot)
			st.set_uv(Vector2(u1, 0.0)); st.add_vertex(ring_verts[0][j + 1])
			st.set_uv(Vector2(u0, 0.0)); st.add_vertex(ring_verts[0][j])

		var last_i := rings.size() - 1
		var c_top: Vector3 = rings[last_i].get("center", Vector3.ZERO)
		for j in radial_segments:
			var u0 := float(j) / float(radial_segments)
			var u1 := float(j + 1) / float(radial_segments)
			st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(c_top)
			st.set_uv(Vector2(u0, 1.0)); st.add_vertex(ring_verts[last_i][j])
			st.set_uv(Vector2(u1, 1.0)); st.add_vertex(ring_verts[last_i][j + 1])

	st.generate_normals()
	if with_tangents:
		st.generate_tangents()
	return st.commit()


static func build_boulder_mesh(radii: Vector3 = Vector3(1.0, 0.72, 0.9), seed_val: int = 1) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var lat := 9
	var lon := 14
	var p_seed := float(seed_val) * 1.731
	var grid: Array = []

	for i in range(lat + 1):
		var v := float(i) / float(lat)
		var phi := clampf(v * PI, 0.04, PI - 0.04)
		var y_base := -cos(phi)
		var r_sin := sin(phi)
		var row: Array[Vector3] = []
		for j in range(lon + 1):
			var u := float(j) / float(lon)
			var theta := u * TAU
			var dir := Vector3(cos(theta) * r_sin, y_base, sin(theta) * r_sin)
			var disp := 1.0
			disp += 0.19 * sin(dir.x * 3.1 + dir.z * 2.4 + p_seed)
			disp += 0.12 * cos(dir.y * 4.5 - dir.x * 2.9 + p_seed * 1.7)
			disp += 0.08 * sin(dir.z * 6.2 + dir.y * 3.8 - p_seed * 0.9)
			var pt := Vector3(dir.x * radii.x, dir.y * radii.y, dir.z * radii.z) * disp
			if pt.y < -radii.y * 0.68:
				pt.y = -radii.y * 0.68
			row.append(pt)
		grid.append(row)

	for i in lat:
		for j in lon:
			_emit_quad_cw(
				st,
				grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j],
				Vector2(float(j) / lon, float(i) / lat),
				Vector2(float(j + 1) / lon, float(i) / lat),
				Vector2(float(j + 1) / lon, float(i + 1) / lat),
				Vector2(float(j) / lon, float(i + 1) / lat)
			)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func build_gnarled_trunk_mesh(height: float = 9.0, base_r: float = 0.88, top_r: float = 0.34, seed_val: int = 1) -> ArrayMesh:
	var rings: Array = []
	var steps := 10
	var ph := float(seed_val) * 1.17
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var y := t * height
		var root_flare := pow(maxf(1.0 - t * 3.2, 0.0), 1.8) * 0.55
		var rad := lerpf(base_r, top_r, pow(t, 0.72)) + root_flare
		var bend_x := sin(t * PI * 1.2 + ph) * 0.28 * t
		var bend_z := cos(t * PI * 0.9 + ph * 1.4) * 0.22 * t
		rings.append({
			"center": Vector3(bend_x, y, bend_z),
			"rx": rad * (1.0 + 0.06 * sin(t * 9.0 + ph)),
			"rz": rad * (1.0 - 0.05 * cos(t * 7.0 + ph)),
			"twist": t * 0.85,
			"flute": 0.45 + pow(maxf(1.0 - t * 2.2, 0.0), 1.4) * 1.35,
			"v": t * 3.2,
		})
	return build_lofted_tube_mesh(rings, 14, true, 5, 0.16, false, true)


static func build_branch_bough_mesh(length: float = 3.8, r0: float = 0.26, r1: float = 0.07, seed_val: int = 1) -> ArrayMesh:
	var rings: Array = []
	var steps := 6
	var ph := float(seed_val) * 0.83
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var rad := lerpf(r0, r1, t)
		rings.append({
			"center": Vector3(sin(t * 2.2 + ph) * 0.18 * t, t * length, cos(t * 1.9 + ph) * 0.16 * t),
			"rx": rad,
			"rz": rad * 0.94,
			"twist": t * 0.6,
			"flute": 0.5,
			"v": t * 1.8,
		})
	return build_lofted_tube_mesh(rings, 8, true, 3, 0.08, false, true)


static func build_foliage_canopy_cluster_mesh(radius: float = 3.2, card_count: int = 30, seed_val: int = 1) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_val)

	for i in card_count:
		var t := (float(i) + 0.5) / float(card_count)
		var phi := acos(1.0 - 1.35 * t)
		var theta := float(i) * 2.39996 + rng.randf_range(-0.35, 0.35)
		var dist := maxf(radius, 0.2) * rng.randf_range(0.18, 0.88)
		var pos := Vector3(
			sin(phi) * cos(theta) * dist,
			cos(phi) * dist * 0.58 + rng.randf_range(-0.35, 0.45),
			sin(phi) * sin(theta) * dist
		)
		var cw := rng.randf_range(1.15, 1.85) * (radius / 3.0)
		var ch := cw * rng.randf_range(0.95, 1.25)
		var b := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis(Vector3.RIGHT, rng.randf_range(-0.55, 0.55)) * Basis(Vector3.FORWARD, rng.randf_range(-0.4, 0.4))

		for sub_ang in [0.0, PI * 0.5]:
			var sb := b * Basis(Vector3.UP, sub_ang)
			var p0 := pos + sb * Vector3(-cw * 0.5, -ch * 0.35, 0.0)
			var p1 := pos + sb * Vector3(cw * 0.5, -ch * 0.35, 0.0)
			var p2 := pos + sb * Vector3(cw * 0.5, ch * 0.65, 0.0)
			var p3 := pos + sb * Vector3(-cw * 0.5, ch * 0.65, 0.0)
			var pos_dir := pos.normalized() if pos.length() > 0.001 else Vector3.UP
			var nrm := (sb * Vector3.UP + pos_dir * 0.6).normalized()
			st.set_normal(nrm)
			_emit_quad_cw(st, p0, p1, p2, p3, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0))

	return st.commit()


static func build_crossed_frond_mesh(w: float = 0.62, h: float = 0.92) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ang in [deg_to_rad(25.0), deg_to_rad(-35.0), deg_to_rad(85.0)]:
		var dx := cos(ang) * w
		var dz := sin(ang) * w
		var p0 := Vector3(-dx, 0.0, -dz)
		var p1 := Vector3(dx, 0.0, dz)
		var p2 := Vector3(dx * 1.12, h, dz * 1.12)
		var p3 := Vector3(-dx * 1.12, h, -dz * 1.12)
		st.set_normal(Vector3.UP)
		_emit_quad_cw(st, p0, p1, p2, p3, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0))
	return st.commit()


static func build_curved_cloak_mesh(top_w: float = 0.48, bot_w: float = 0.92, length: float = 1.06, cols: int = 10, rows: int = 12) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for r in range(rows + 1):
		var v := float(r) / float(rows)
		var width := lerpf(top_w, bot_w, pow(v, 0.85))
		var y := -v * length
		var z_drape := pow(v, 1.35) * 0.28
		var row: Array[Vector3] = []
		for c in range(cols + 1):
			var u := float(c) / float(cols)
			var x_norm := u * 2.0 - 1.0
			var curve_ang := x_norm * 0.92
			var pleat := sin(x_norm * PI * 3.0) * 0.032 * v
			var x := sin(curve_ang) * (width * 0.56)
			var z := (1.0 - cos(curve_ang)) * -0.14 + z_drape + pleat
			row.append(Vector3(x, y, z))
		grid.append(row)

	for r in rows:
		for c in cols:
			_emit_quad_cw(
				st,
				grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c],
				Vector2(float(c) / cols, float(r) / rows),
				Vector2(float(c + 1) / cols, float(r) / rows),
				Vector2(float(c + 1) / cols, float(r + 1) / rows),
				Vector2(float(c) / cols, float(r + 1) / rows)
			)

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func build_sculpted_hood_mesh() -> ArrayMesh:
	var rings := [
		{"center": Vector3(0.0, -0.16, 0.04), "rx": 0.25, "rz": 0.27, "v": 0.0},
		{"center": Vector3(0.0, -0.02, 0.05), "rx": 0.26, "rz": 0.29, "v": 0.35},
		{"center": Vector3(0.0, 0.14, 0.07), "rx": 0.23, "rz": 0.28, "v": 0.72},
		{"center": Vector3(0.0, 0.24, 0.18), "rx": 0.11, "rz": 0.15, "v": 0.92},
		{"center": Vector3(0.0, 0.22, 0.31), "rx": 0.04, "rz": 0.05, "v": 1.0},
	]
	return build_lofted_tube_mesh(rings, 12, true, 0, 0.0, false, true)


static func build_sculpted_sword_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var prof := [
		{"z": 0.0, "w": 0.055, "h": 0.018},
		{"z": -0.28, "w": 0.05, "h": 0.016},
		{"z": -0.78, "w": 0.042, "h": 0.014},
		{"z": -0.96, "w": 0.022, "h": 0.009},
		{"z": -1.06, "w": 0.004, "h": 0.004},
	]
	var rings: Array = []
	for d in prof:
		var z := float(d["z"])
		var w := float(d["w"])
		var h := float(d["h"])
		rings.append([
			Vector3(-w, 0.0, z),
			Vector3(0.0, h, z),
			Vector3(w, 0.0, z),
			Vector3(0.0, -h, z),
		])
	for i in range(rings.size() - 1):
		for k in 4:
			var kn := (k + 1) % 4
			_emit_quad_cw(
				st,
				rings[i][k], rings[i][kn], rings[i + 1][kn], rings[i + 1][k],
				Vector2(float(k) * 0.25, float(i) / 4.0),
				Vector2(float(k + 1) * 0.25, float(i) / 4.0),
				Vector2(float(k + 1) * 0.25, float(i + 1) / 4.0),
				Vector2(float(k) * 0.25, float(i + 1) / 4.0)
			)
	_emit_quad_cw(st, rings[0][0], rings[0][3], rings[0][2], rings[0][1], Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.UP)
	_emit_quad_cw(st, rings[4][0], rings[4][1], rings[4][2], rings[4][3], Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.UP)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func build_rune_shard_mesh(radius: float = 0.26, height: float = 0.78, seed_val: int = 1) -> ArrayMesh:
	var skew_x := sin(float(seed_val) * 2.1) * radius * 0.16
	var skew_z := cos(float(seed_val) * 1.7) * radius * 0.16
	var rings := [
		{"center": Vector3(0.0, -height * 0.5, 0.0), "rx": 0.025, "rz": 0.025, "v": 0.0},
		{"center": Vector3(-skew_x * 0.4, -height * 0.24, -skew_z * 0.4), "rx": radius * 0.86, "rz": radius * 0.76, "v": 0.28},
		{"center": Vector3(skew_x * 0.3, height * 0.18, skew_z * 0.3), "rx": radius, "rz": radius * 0.88, "v": 0.68},
		{"center": Vector3(skew_x, height * 0.5, skew_z), "rx": 0.02, "rz": 0.02, "v": 1.0},
	]
	return build_lofted_tube_mesh(rings, 6, true, 0, 0.0, true, true)


static func build_crystal_cluster_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var spires := [
		{"pos": Vector3(0.0, 0.02, 0.0), "rot": Vector3(0.04, 0.2, -0.05), "r": 0.23, "h": 0.78},
		{"pos": Vector3(-0.14, -0.08, 0.08), "rot": Vector3(0.28, 1.1, 0.35), "r": 0.14, "h": 0.48},
		{"pos": Vector3(0.15, -0.1, -0.06), "rot": Vector3(-0.24, 2.3, -0.32), "r": 0.13, "h": 0.44},
	]
	for cfg_var in spires:
		var cfg: Dictionary = cfg_var
		var m: ArrayMesh = build_rune_shard_mesh(float(cfg["r"]), float(cfg["h"]), int(float(cfg["r"]) * 100.0))
		var rot_v: Vector3 = cfg["rot"]
		var pos_v: Vector3 = cfg["pos"]
		var xf: Transform3D = Transform3D(Basis.from_euler(rot_v), pos_v)
		st.append_from(m, 0, xf)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func build_fluted_column_mesh(radius: float = 0.62, height: float = 6.0) -> ArrayMesh:
	var rings := [
		{"center": Vector3(0.0, 0.0, 0.0), "rx": radius * 1.38, "rz": radius * 1.38, "flute": 0.0, "v": 0.0},
		{"center": Vector3(0.0, 0.28, 0.0), "rx": radius * 1.32, "rz": radius * 1.32, "flute": 0.0, "v": 0.15},
		{"center": Vector3(0.0, 0.42, 0.0), "rx": radius * 1.15, "rz": radius * 1.15, "flute": 0.2, "v": 0.25},
		{"center": Vector3(0.0, 0.65, 0.0), "rx": radius * 1.0, "rz": radius * 1.0, "flute": 1.0, "v": 0.4},
		{"center": Vector3(0.0, height * 0.5, 0.0), "rx": radius * 0.94, "rz": radius * 0.94, "flute": 1.0, "v": 2.0},
		{"center": Vector3(0.0, height - 0.55, 0.0), "rx": radius * 0.86, "rz": radius * 0.86, "flute": 1.0, "v": 3.4},
		{"center": Vector3(0.0, height - 0.35, 0.0), "rx": radius * 1.05, "rz": radius * 1.05, "flute": 0.2, "v": 3.6},
		{"center": Vector3(0.0, height - 0.18, 0.0), "rx": radius * 1.26, "rz": radius * 1.26, "flute": 0.0, "v": 3.8},
		{"center": Vector3(0.0, height, 0.0), "rx": radius * 1.34, "rz": radius * 1.34, "flute": 0.0, "v": 4.0},
	]
	return build_lofted_tube_mesh(rings, 16, true, 10, 0.075, false, true)


static func build_lantern_cage_mesh(r: float = 0.125, h: float = 0.26) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cap := build_lofted_tube_mesh([
		{"center": Vector3(0, h * 0.38, 0), "rx": r * 1.25, "rz": r * 1.25, "v": 0.0},
		{"center": Vector3(0, h * 0.55, 0), "rx": r * 0.72, "rz": r * 0.72, "v": 0.5},
		{"center": Vector3(0, h * 0.68, 0), "rx": 0.025, "rz": 0.025, "v": 1.0},
	], 8, true, 0, 0.0, true, false)
	st.append_from(cap, 0, Transform3D.IDENTITY)

	var base := build_lofted_tube_mesh([
		{"center": Vector3(0, -h * 0.56, 0), "rx": 0.02, "rz": 0.02, "v": 0.0},
		{"center": Vector3(0, -h * 0.42, 0), "rx": r * 1.05, "rz": r * 1.05, "v": 0.6},
		{"center": Vector3(0, -h * 0.35, 0), "rx": r * 1.15, "rz": r * 1.15, "v": 1.0},
	], 8, true, 0, 0.0, true, false)
	st.append_from(base, 0, Transform3D.IDENTITY)

	for i in 4:
		var ang := float(i) * (PI * 0.5) + PI * 0.25
		var pos := Vector3(cos(ang) * r * 0.96, 0.0, sin(ang) * r * 0.96)
		var bar := build_lofted_tube_mesh([
			{"center": Vector3(0, -h * 0.36, 0), "rx": 0.012, "rz": 0.012, "v": 0.0},
			{"center": Vector3(0, h * 0.4, 0), "rx": 0.012, "rz": 0.012, "v": 1.0},
		], 5, true, 0, 0.0, false, false)
		st.append_from(bar, 0, Transform3D(Basis.IDENTITY, pos))

	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func build_astrolabe_ring_mesh(r_inner: float = 0.44, r_outer: float = 0.58, thickness: float = 0.08, segs: int = 28) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hh := thickness * 0.5
	for i in segs:
		var u0 := float(i) / float(segs)
		var u1 := float(i + 1) / float(segs)
		var a0 := u0 * TAU
		var a1 := u1 * TAU
		var c0 := cos(a0); var s0 := sin(a0)
		var c1 := cos(a1); var s1 := sin(a1)
		var it0 := Vector3(c0 * r_inner, hh, s0 * r_inner)
		var ot0 := Vector3(c0 * r_outer, hh, s0 * r_outer)
		var it1 := Vector3(c1 * r_inner, hh, s1 * r_inner)
		var ot1 := Vector3(c1 * r_outer, hh, s1 * r_outer)
		var ib0 := Vector3(c0 * r_inner, -hh, s0 * r_inner)
		var ob0 := Vector3(c0 * r_outer, -hh, s0 * r_outer)
		var ib1 := Vector3(c1 * r_inner, -hh, s1 * r_inner)
		var ob1 := Vector3(c1 * r_outer, -hh, s1 * r_outer)
		_emit_quad_cw(st, it0, ot0, ot1, it1, Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0))
		_emit_quad_cw(st, ob0, ob1, ot1, ot0, Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1))
		_emit_quad_cw(st, ib1, ob1, ob0, ib0, Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1), Vector2(u0, 0))
		_emit_quad_cw(st, it0, it1, ib1, ib0, Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0), Vector2(u0, 0))
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func build_compass_rose_mesh(r_outer: float = 0.42, r_inner: float = 0.14) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var pts := 8
	var c_top := Vector3(0.0, 0.045, 0.0)
	var c_bot := Vector3(0.0, -0.045, 0.0)
	for i in (pts * 2):
		var a0 := (float(i) / float(pts * 2)) * TAU
		var a1 := (float(i + 1) / float(pts * 2)) * TAU
		var r0 := r_outer if (i % 2 == 0) else r_inner
		var r1 := r_inner if (i % 2 == 0) else r_outer
		var p0 := Vector3(cos(a0) * r0, 0.0, sin(a0) * r0)
		var p1 := Vector3(cos(a1) * r1, 0.0, sin(a1) * r1)
		st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(c_top)
		st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(p0)
		st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(p1)
		st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(c_bot)
		st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(p1)
		st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(p0)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func build_telegraph_ring_mesh(r_in: float = 1.65, r_out: float = 2.05, segs: int = 36) -> ArrayMesh:
	return build_astrolabe_ring_mesh(r_in, r_out, 0.03, segs)


static func build_sculpted_island_mesh(size: Vector3) -> ArrayMesh:
	## Watertight sculpted floating forest cliff island without lambdas for full Godot 4 static safety.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var seg_x := clampi(int(size.x / 2.2), 5, 18)
	var seg_z := clampi(int(size.z / 2.2), 5, 18)

	var grid_top: Array = []
	var grid_mid: Array = []
	var grid_low: Array = []
	var grid_bot: Array = []

	for ix in range(seg_x + 1):
		var ct: Array = []; var cm: Array = []; var cl: Array = []; var cb: Array = []
		var u := (float(ix) / float(seg_x)) * 2.0 - 1.0
		for iz in range(seg_z + 1):
			var v := (float(iz) / float(seg_z)) * 2.0 - 1.0
			var edge := maxf(absf(u), absf(v))
			var x := u * hx
			var z := v * hz
			var disp := sin(x * 0.35 + z * 0.28) * 0.34 + cos(x * 0.72 - z * 0.52) * 0.18
			var rim_noise := sin(x * 0.6 + z * 0.55) * 0.28 if edge > 0.78 else 0.0
			var top_y := hy - (maxf(edge - 0.86, 0.0) * 1.15) + sin(x * 0.4) * cos(z * 0.4) * 0.035
			var mid_x := x * (1.035 if edge > 0.82 else 1.0) + rim_noise
			var mid_z := z * (1.035 if edge > 0.82 else 1.0) + rim_noise
			var mid_y := hy - minf(0.8, size.y * 0.24) + disp * 0.16
			var low_x := x * 0.92 + disp * 0.55
			var low_z := z * 0.92 + disp * 0.55
			var low_y := -hy * 0.35 + disp * 0.25
			var bot_x := x * 0.74 + disp * 0.7
			var bot_z := z * 0.74 + disp * 0.7
			var bot_y := -hy - absf(disp) * 0.65 - (1.0 - edge) * 0.75
			ct.append(Vector3(x, top_y, z))
			cm.append(Vector3(mid_x, mid_y, mid_z))
			cl.append(Vector3(low_x, low_y, low_z))
			cb.append(Vector3(bot_x, bot_y, bot_z))
		grid_top.append(ct); grid_mid.append(cm); grid_low.append(cl); grid_bot.append(cb)

	for ix in seg_x:
		for iz in seg_z:
			_emit_quad_cw(
				st,
				grid_top[ix][iz], grid_top[ix + 1][iz], grid_top[ix + 1][iz + 1], grid_top[ix][iz + 1],
				Vector2(float(ix) / seg_x, float(iz) / seg_z),
				Vector2(float(ix + 1) / seg_x, float(iz) / seg_z),
				Vector2(float(ix + 1) / seg_x, float(iz + 1) / seg_z),
				Vector2(float(ix) / seg_x, float(iz + 1) / seg_z)
			)
			_emit_quad_cw(
				st,
				grid_bot[ix][iz + 1], grid_bot[ix + 1][iz + 1], grid_bot[ix + 1][iz], grid_bot[ix][iz],
				Vector2(float(ix) / seg_x, float(iz + 1) / seg_z),
				Vector2(float(ix + 1) / seg_x, float(iz + 1) / seg_z),
				Vector2(float(ix + 1) / seg_x, float(iz) / seg_z),
				Vector2(float(ix) / seg_x, float(iz) / seg_z)
			)

	for ix in seg_x:
		_emit_island_wall(st, grid_top[ix][0], grid_top[ix + 1][0], grid_mid[ix][0], grid_mid[ix + 1][0], grid_low[ix][0], grid_low[ix + 1][0], grid_bot[ix][0], grid_bot[ix + 1][0])
		_emit_island_wall(st, grid_top[ix + 1][seg_z], grid_top[ix][seg_z], grid_mid[ix + 1][seg_z], grid_mid[ix][seg_z], grid_low[ix + 1][seg_z], grid_low[ix][seg_z], grid_bot[ix + 1][seg_z], grid_bot[ix][seg_z])
	for iz in seg_z:
		_emit_island_wall(st, grid_top[seg_x][iz], grid_top[seg_x][iz + 1], grid_mid[seg_x][iz], grid_mid[seg_x][iz + 1], grid_low[seg_x][iz], grid_low[seg_x][iz + 1], grid_bot[seg_x][iz], grid_bot[seg_x][iz + 1])
		_emit_island_wall(st, grid_top[0][iz + 1], grid_top[0][iz], grid_mid[0][iz + 1], grid_mid[0][iz], grid_low[0][iz + 1], grid_low[0][iz], grid_bot[0][iz + 1], grid_bot[0][iz])

	st.generate_normals()
	st.generate_tangents()
	return st.commit()

static func build_sculpted_head_mesh() -> ArrayMesh:
	## Anatomical human cranium, cheekbone contour, and tapered jawline/chin.
	var rings := [
		{"center": Vector3(0.0, -0.145, -0.02), "rx": 0.052, "rz": 0.068, "v": 0.0},
		{"center": Vector3(0.0, -0.095, -0.025), "rx": 0.088, "rz": 0.105, "v": 0.22},
		{"center": Vector3(0.0, -0.025, -0.015), "rx": 0.112, "rz": 0.128, "v": 0.48},
		{"center": Vector3(0.0, 0.05, 0.005), "rx": 0.118, "rz": 0.135, "v": 0.74},
		{"center": Vector3(0.0, 0.115, 0.012), "rx": 0.096, "rz": 0.112, "v": 0.9},
		{"center": Vector3(0.0, 0.155, 0.01), "rx": 0.036, "rz": 0.042, "v": 1.0},
	]
	return build_lofted_tube_mesh(rings, 16, true, 0, 0.0, false, true)


static func build_ranger_hood_mesh() -> ArrayMesh:
	## Draped ranger cowl hood framing the head naturally and flowing into the shoulder collar.
	var rings := [
		{"center": Vector3(0.0, -0.18, 0.028), "rx": 0.158, "rz": 0.165, "v": 0.0},
		{"center": Vector3(0.0, -0.05, 0.032), "rx": 0.15, "rz": 0.17, "v": 0.35},
		{"center": Vector3(0.0, 0.09, 0.036), "rx": 0.145, "rz": 0.172, "v": 0.68},
		{"center": Vector3(0.0, 0.18, 0.088), "rx": 0.102, "rz": 0.132, "v": 0.88},
		{"center": Vector3(0.0, 0.16, 0.215), "rx": 0.03, "rz": 0.04, "v": 1.0},
	]
	return build_lofted_tube_mesh(rings, 16, true, 5, 0.03, false, true)


static func build_ranger_boot_mesh(leg_h: float = 0.46) -> ArrayMesh:
	## Sculpted knee-high leather riding boot with ankle contour, foot vamp, and sole.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shaft := build_lofted_tube_mesh([
		{"center": Vector3(0.0, -leg_h + 0.05, 0.0), "rx": 0.06, "rz": 0.068, "v": 0.0},
		{"center": Vector3(0.0, -leg_h + 0.16, 0.0), "rx": 0.058, "rz": 0.064, "v": 0.3},
		{"center": Vector3(0.0, -0.06, 0.0), "rx": 0.072, "rz": 0.078, "v": 0.78},
		{"center": Vector3(0.0, 0.0, 0.0), "rx": 0.08, "rz": 0.086, "v": 0.92},
		{"center": Vector3(0.0, 0.03, 0.0), "rx": 0.086, "rz": 0.092, "v": 1.0},
	], 12, true, 0, 0.0, false, true)
	st.append_from(shaft, 0, Transform3D.IDENTITY)

	var foot := build_lofted_tube_mesh([
		{"center": Vector3(0.0, -leg_h, 0.055), "rx": 0.062, "rz": 0.046, "v": 0.0},
		{"center": Vector3(0.0, -leg_h + 0.032, -0.025), "rx": 0.065, "rz": 0.045, "v": 0.45},
		{"center": Vector3(0.0, -leg_h + 0.028, -0.105), "rx": 0.058, "rz": 0.035, "v": 0.8},
		{"center": Vector3(0.0, -leg_h + 0.015, -0.152), "rx": 0.04, "rz": 0.02, "v": 1.0},
	], 10, true, 0, 0.0, false, true)
	st.append_from(foot, 0, Transform3D.IDENTITY)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func build_pine_trunk_mesh(height: float = 12.0, base_r: float = 0.56, top_r: float = 0.08, seed_val: int = 1) -> ArrayMesh:
	## Tall straight forest conifer trunk with flared roots.
	var rings: Array = []
	var steps := 8
	var ph := float(seed_val) * 0.91
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var y := t * height
		var root_flare := pow(maxf(1.0 - t * 4.0, 0.0), 1.8) * 0.34
		var rad := lerpf(base_r, top_r, pow(t, 0.85)) + root_flare
		rings.append({
			"center": Vector3(sin(t * 2.5 + ph) * 0.09 * t, y, cos(t * 2.1 + ph) * 0.09 * t),
			"rx": rad,
			"rz": rad * 0.96,
			"twist": t * 0.4,
			"flute": 0.3 + pow(maxf(1.0 - t * 2.8, 0.0), 1.4) * 1.1,
			"v": t * 4.0,
		})
	return build_lofted_tube_mesh(rings, 10, true, 5, 0.1, false, true)


static func build_pine_canopy_mesh(height: float = 12.0, radius: float = 3.2, seed_val: int = 1) -> ArrayMesh:
	## Layered woodland conifer bough cards forming natural drooping pine whorls.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_val + 701)

	var tiers := 6
	for tier in tiers:
		var tf := float(tier) / float(tiers - 1)
		var y := lerpf(height * 0.28, height * 0.96, tf)
		var tier_r := lerpf(radius, radius * 0.24, pow(tf, 0.82))
		var cards := maxi(7 - tier, 4)
		for j in cards:
			var ang := (float(j) / float(cards)) * TAU + float(tier) * 0.55 + rng.randf_range(-0.2, 0.2)
			var cw := tier_r * rng.randf_range(0.82, 1.12)
			var ch := cw * rng.randf_range(0.85, 1.05)
			var b := Basis(Vector3.UP, ang) * Basis(Vector3.RIGHT, deg_to_rad(lerpf(-42.0, -24.0, tf)))
			var pos := Vector3(cos(ang) * tier_r * 0.34, y, sin(ang) * tier_r * 0.34)
			var p0 := pos + b * Vector3(-cw * 0.55, 0.0, 0.0)
			var p1 := pos + b * Vector3(cw * 0.55, 0.0, 0.0)
			var p2 := pos + b * Vector3(cw * 0.35, -ch * 0.45, ch * 0.88)
			var p3 := pos + b * Vector3(-cw * 0.35, -ch * 0.45, ch * 0.88)
			st.set_normal((b * Vector3.UP + Vector3.UP * 0.5).normalized())
			_emit_quad_cw(st, p0, p1, p2, p3, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0))

	return st.commit()


static func build_shrub_cluster_mesh(radius: float = 1.45, card_count: int = 12, seed_val: int = 1) -> ArrayMesh:
	## Low woodland bush / undergrowth cluster for road embankments & forest floor.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_val + 913)
	for i in card_count:
		var ang := (float(i) / float(card_count)) * TAU + rng.randf_range(-0.25, 0.25)
		var dist := radius * rng.randf_range(0.08, 0.42)
		var cw := radius * rng.randf_range(0.75, 1.15)
		var ch := cw * rng.randf_range(0.72, 1.02)
		var pos := Vector3(cos(ang) * dist, ch * 0.36, sin(ang) * dist)
		var b := Basis(Vector3.UP, ang + rng.randf_range(-0.4, 0.4)) * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4))
		var p0 := pos + b * Vector3(-cw * 0.5, -ch * 0.4, 0.0)
		var p1 := pos + b * Vector3(cw * 0.5, -ch * 0.4, 0.0)
		var p2 := pos + b * Vector3(cw * 0.45, ch * 0.6, 0.0)
		var p3 := pos + b * Vector3(-cw * 0.45, ch * 0.6, 0.0)
		st.set_normal((pos.normalized() + Vector3.UP).normalized())
		_emit_quad_cw(st, p0, p1, p2, p3, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0))
	return st.commit()


static func build_road_valley_terrain_mesh(
	z_min: float,
	z_max: float,
	x_half: float,
	step_x: float,
	step_z: float,
	terrain_sampler: Callable
) -> ArrayMesh:
	## Builds a continuous, watertight, indexed vertex-colored terrain + road valley mesh.
	## Computes seamless finite-difference normals across chunk boundaries.
	var nx := maxi(int(round((x_half * 2.0) / step_x)), 4)
	var total_z := absf(z_max - z_min)
	var nz := maxi(int(round(total_z / step_z)), 4)
	var dx_step := (x_half * 2.0) / float(nx)
	var dz_step := total_z / float(nz)

	var vert_count := (nx + 1) * (nz + 1)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var ys := PackedFloat32Array()
	verts.resize(vert_count)
	norms.resize(vert_count)
	uvs.resize(vert_count)
	cols.resize(vert_count)
	ys.resize(vert_count)

	var stride := nz + 1
	for ix in range(nx + 1):
		var u := float(ix) / float(nx)
		var x := lerpf(-x_half, x_half, u)
		for iz in range(nz + 1):
			var v := float(iz) / float(nz)
			var z := lerpf(z_min, z_max, v)
			var res: Dictionary = terrain_sampler.call(x, z)
			var y := float(res["y"])
			var idx := ix * stride + iz
			verts[idx] = Vector3(x, y, z)
			uvs[idx] = Vector2(x * 0.1, z * 0.1)
			cols[idx] = res["col"]
			ys[idx] = y

	for ix in range(nx + 1):
		var x := lerpf(-x_half, x_half, float(ix) / float(nx))
		for iz in range(nz + 1):
			var z := lerpf(z_min, z_max, float(iz) / float(nz))
			var idx := ix * stride + iz
			var y_l: float = ys[(ix - 1) * stride + iz] if ix > 0 else float((terrain_sampler.call(x - dx_step, z) as Dictionary)["y"])
			var y_r: float = ys[(ix + 1) * stride + iz] if ix < nx else float((terrain_sampler.call(x + dx_step, z) as Dictionary)["y"])
			var y_b: float = ys[ix * stride + (iz - 1)] if iz > 0 else float((terrain_sampler.call(x, z - dz_step) as Dictionary)["y"])
			var y_f: float = ys[ix * stride + (iz + 1)] if iz < nz else float((terrain_sampler.call(x, z + dz_step) as Dictionary)["y"])
			var vx := Vector3(2.0 * dx_step, y_r - y_l, 0.0)
			var vz := Vector3(0.0, y_f - y_b, 2.0 * dz_step)
			norms[idx] = vz.cross(vx).normalized()

	var indices := PackedInt32Array()
	indices.resize(nx * nz * 6)
	var k := 0
	for ix in nx:
		for iz in nz:
			var i00 := ix * stride + iz
			var i10 := (ix + 1) * stride + iz
			var i11 := (ix + 1) * stride + (iz + 1)
			var i01 := ix * stride + (iz + 1)
			indices[k] = i00; k += 1
			indices[k] = i10; k += 1
			indices[k] = i11; k += 1
			indices[k] = i00; k += 1
			indices[k] = i11; k += 1
			indices[k] = i01; k += 1

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
