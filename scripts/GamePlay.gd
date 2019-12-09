extends Spatial

var SurfaceMaterial

enum WeaponType {
	FIST,
	SAW,
	PISTOL,
	SHOTGUN,
	CHAINGUN,
	MISSILE
	}

export(String) var WADPath = "doom1.wad"
export(String) var level_name = "E1M1"

export(float) var level_scale = 0.05
export(NodePath) var ear_cut_path
export(NodePath) var player_path

var current_weapon = WeaponType.PISTOL

onready var wall_segment_blueprint = preload("res://scripts/WallSegment.gd")
onready var flat_segment_blueprint = preload("res://scripts/FlatSegment.gd")
onready var sector_blueprint = preload("res://scripts/Sector.gd")
onready var thing_blueprint = preload("res://scripts/Thing.gd")
var map_sectors = []

var sectors_animations = []

func _ready() -> void:
	$Level.load_wad(WADPath, level_name, level_scale)

	render_level()
	render_things()
	render_hud()
	gun_select_pistol()
	place_player_at_start()

func render_hud() -> void:
	$GameUI/HUDBar.texture = $Level.get_picture("STBAR").image_texture

	var raw_image = Image.new()
	raw_image.create(3 * 14, 16, false, Image.FORMAT_RGBA8)

	var patch_pic1 = get_picture("STTNUM5")
	raw_image.blit_rect(patch_pic1.image, Rect2(0, 0, patch_pic1.width, patch_pic1.height), Vector2(0, 0))
	var patch_pic2 = get_picture("STTNUM0")
	raw_image.blit_rect(patch_pic2.image, Rect2(0, 0, patch_pic2.width, patch_pic2.height), Vector2(14, 0))

	var imageTexture = ImageTexture.new()
	imageTexture.create_from_image(raw_image, 1 | 2)

	$GameUI/CurrentAmmo.texture = imageTexture

var fist_selected : bool = true
func _unhandled_key_input(event: InputEventKey) -> void:
	if event.pressed:
		match event.scancode:
			KEY_1:
				if fist_selected:
					gun_select_fist()
				else:
					gun_select_saw()

				fist_selected = not fist_selected
			KEY_2:
				gun_select_pistol()
			KEY_3:
				gun_select_shotgun()
			KEY_4:
				gun_select_chaingun()
			KEY_5:
				gun_select_missile()

func gun_select_saw() -> void:
	current_weapon = WeaponType.SAW
	$GameUI/Gun.texture = $Level.get_picture("SAWGC0").image_texture

func gun_select_fist() -> void:
	current_weapon = WeaponType.FIST
	$GameUI/Gun.texture = $Level.get_picture("PUNGA0").image_texture

func gun_select_pistol() -> void:
	current_weapon = WeaponType.PISTOL
	$GameUI/Gun.texture = $Level.get_picture("PISGA0").image_texture

func gun_select_shotgun() -> void:
	current_weapon = WeaponType.SHOTGUN
	$GameUI/Gun.texture = $Level.get_picture("SHTGA0").image_texture

func gun_select_chaingun() -> void:
	current_weapon = WeaponType.CHAINGUN
	$GameUI/Gun.texture = $Level.get_picture("CHGGA0").image_texture

func gun_select_missile() -> void:
	current_weapon = WeaponType.MISSILE
	$GameUI/Gun.texture = $Level.get_picture("MISGA0").image_texture

func fire_curent_weapon() -> void:
	match current_weapon:
		WeaponType.PISTOL:
			var animated_texture = AnimatedTexture.new()
			animated_texture.frames = 5
			animated_texture.fps = 5

			animated_texture.set_frame_texture(0, get_picture("PISGA0").image_texture)
			animated_texture.set_frame_texture(1, get_picture("PISGB0").image_texture)
			animated_texture.set_frame_texture(2, get_picture("PISGC0").image_texture)
			animated_texture.set_frame_texture(3, get_picture("PISGB0").image_texture)
			animated_texture.set_frame_texture(4, get_picture("PISGA0").image_texture)

			$GameUI/Gun.texture = animated_texture

func _input(event: InputEvent) -> void:
	if Input.is_action_pressed("fire"):
		fire_curent_weapon()

	if Input.is_action_pressed("action"):
		var player_pos = Vector2($Player.translation.x, $Player.translation.z)

		for sector in map_sectors:
			for wall in sector.walls:
				if wall.is_door and wall.front_side:
					var vertex1 = Vector2(wall.start_vertex.x, -wall.start_vertex.y)
					var vertex2 = Vector2(wall.end_vertex.x, -wall.end_vertex.y)
					var mid_point = vertex1.linear_interpolate(vertex2, 0.5)
					var distance = abs(player_pos.distance_to(mid_point))

					if distance < 8:
						move_sector_ceiling(true, wall.other_sector)
					elif distance > 8 and distance < 14:
						pass#move_sector_ceiling(false, wall.other_sector, delta)

	#			if wall.is_lift and wall.front_side:
	#				var vertex1 = Vector2(wall.start_vertex.x, -wall.start_vertex.y)
	#				var vertex2 = Vector2(wall.end_vertex.x, -wall.end_vertex.y)
	#				var mid_point = vertex1.linear_interpolate(vertex2, 0.5)
	#				var distance = abs(player_pos.distance_to(mid_point))
	#
	#				if distance > 4 and distance < 8:
	#					move_sector_floor(true, wall.other_sector, delta)
	#				if distance < 4:
	#					move_sector_floor(false, wall.other_sector, delta)

func _process(delta: float) -> void:
	$SkyBox.translation.x = $Player.translation.x
	$SkyBox.translation.y = $Player.translation.y - 50
	$SkyBox.translation.z = $Player.translation.z

	for anim in sectors_animations:
		if anim.rest_time >= 0.0:
			anim.rest_time -= delta
			continue

		for sector in map_sectors:
			if sector.sector_id == anim.sector_id:
				var completed = sector.move_ceiling(anim.move_up, anim.lowest_ceiling, delta)

				if completed:
					if anim.move_up and anim.was_moving_up:
						anim.rest_time = 3.0 # seconds

					if not anim.move_up and anim.was_moving_up:
						sectors_animations.erase(anim)
						return

					anim.move_up = not anim.move_up

			for wall in sector.walls:
				if wall.sector == anim.sector_id or wall.other_sector == anim.sector_id:
					move_walls_with_ceiling(wall, anim.move_up, anim.lowest_ceiling, delta, anim.sector_id)

func move_sector_ceiling(move_up: bool, sector_id: int):
	for anim in sectors_animations:
		if anim.sector_id == sector_id:
			return

	var lowest_ceiling = 10000.0
	for s in map_sectors:
		for wall_segment in s.walls:
			if wall_segment.other_sector == sector_id:
				var sec = get_sector(wall_segment.sector)
				if sec.ceil_height < lowest_ceiling:
					lowest_ceiling = sec.ceil_height

	lowest_ceiling *= level_scale

	var anim = {}
	anim.sector_id = sector_id
	anim.move_up = move_up
	anim.was_moving_up = move_up
	anim.lowest_ceiling = lowest_ceiling
	anim.playing = true
	anim.rest_time = 0.0

	sectors_animations.append(anim)

func move_sector_floor(move_up: bool, sector_id: int, delta: float):
	var lowest_floor = 10000.0
	var floor_height = 0.0
	for s in map_sectors:
		for wall_segment in s.walls:
			if wall_segment.other_sector == sector_id:
				var sec = get_sector(wall_segment.sector)
				if sec.floor_height < lowest_floor:
					lowest_floor = sec.floor_height

	for sector in map_sectors:
		if sector.sector_id == sector_id:
			sector.move_floor(move_up, lowest_floor * level_scale, delta)

		for wall in sector.walls:
			if wall.sector == sector_id or wall.other_sector == sector_id:
				move_walls_with_floor(wall, move_up, lowest_floor * level_scale, delta, sector_id)


var moving_speed: float = 3.5

func move_walls_with_ceiling(wall_segment, move_up: bool, lowest_ceiling: float, delta: float, sector_id: int) -> void:
	if move_up:
		if wall_segment.pos_offset < lowest_ceiling - wall_segment.other_floor_height:
			wall_segment.move_ceiling(moving_speed * delta, wall_segment.sector == sector_id)
		else:
			wall_segment.move_ceiling(lowest_ceiling - wall_segment.other_floor_height - wall_segment.pos_offset, wall_segment.sector == sector_id)

	if not move_up:
		if wall_segment.pos_offset > 0.0:
			wall_segment.move_ceiling(-moving_speed * delta, wall_segment.sector == sector_id)
		else:
			wall_segment.move_ceiling(0.0 - wall_segment.pos_offset, wall_segment.sector == sector_id)

func move_walls_with_floor(wall_segment, move_up: bool, lowest_floor: float, delta: float, sector_id: int) -> void:
#	if move_up:
#		if wall_segment.pos_offset < 0:
#			wall_segment.move_floor(moving_speed * delta, wall_segment.sector == sector_id)
#			else:
#				wall_segment.move_floor(lowest_floor - wall_segment.other_floor_height - wall_segment.pos_offset, wall_segment.sector == sector_id)

	if not move_up:
		var real_height = wall_segment.floor_height if wall_segment.sector == sector_id else wall_segment.other_floor_height
		if real_height + wall_segment.pos_offset > lowest_floor:
			wall_segment.move_floor(-moving_speed * delta, wall_segment.sector == sector_id)
#			else:
#				wall_segment.move_ceiling(0.0 - wall_segment.pos_offset, wall_segment.sector == sector_id)

func place_player_at_start() -> void:
	for thing in $Level.things:
		if thing.type == 1:
			var space_state = get_world().direct_space_state
			var raycast = space_state.intersect_ray(Vector3(thing.x, -10000, -thing.y), Vector3(thing.x, 10000, -thing.y))
			var up_posiiton = Vector3(3, 3, 3)

			if raycast:
				up_posiiton = raycast.position

			get_node(player_path).translation = Vector3(thing.x, up_posiiton.y + 1.5, -thing.y)
			get_node(player_path).rotate_y(deg2rad(thing.angle - 90))

func _physics_process(delta):
	if Input.is_action_pressed("restart_level"):
		place_player_at_start()

func build_walls():
	var selected_sectors = [131] #[37, 38, 39, 41]

	var walls = []
	var sidedef_index = 0
	for sidedef in $Level.sidedefs:
#		if sidedef.sector in selected_sectors:
		if true:
			var line_index = 0

			for line in $Level.linedefs:
				if line.right_sidedef == sidedef_index or line.left_sidedef == sidedef_index:
					var curr_sector = $Level.sectors[sidedef.sector]
					var wall = wall_segment_blueprint.new()
					wall.line_index = line_index
					wall.line_def_type = line.type
					wall.start_vertex_index = line.start_vertex
					wall.end_vertex_index = line.end_vertex
					wall.start_vertex = $Level.vertexes[line.start_vertex]
					wall.end_vertex = $Level.vertexes[line.end_vertex]
					wall.floor_height = curr_sector.floor_height * level_scale
					wall.ceil_height = curr_sector.ceil_height * level_scale
					wall.floor_texture = curr_sector.floor_texture
					wall.ceil_texture = curr_sector.ceil_texture
					wall.upper_texture = sidedef.upper_texture
					wall.lower_texture = sidedef.lower_texture
					wall.middle_texture = sidedef.middle_texture
					wall.light_level = curr_sector.light_level
					wall.x_offset = sidedef.x_offset
					wall.y_offset = sidedef.y_offset
					wall.two_sided = line.left_sidedef > -1 and line.right_sidedef > -1	 #l.flags & 0x0004
					wall.flags = line.flags
					wall.lower_unpegged = line.flags & 0x0010 > 0
					wall.upper_unpegged = line.flags & 0x0008 > 0
					wall.front_side = (sidedef_index == line.right_sidedef)
					wall.sector = sidedef.sector
					wall.other_sector = -1

					if not wall.two_sided:
						wall.other_floor_height = wall.floor_height
						wall.other_ceil_height = wall.ceil_height
					else:
						if wall.front_side:
							wall.other_sector = $Level.sidedefs[$Level.linedefs[wall.line_index].left_sidedef].sector
							wall.other_floor_height = $Level.sectors[wall.other_sector].floor_height * level_scale
							wall.other_ceil_height = $Level.sectors[wall.other_sector].ceil_height * level_scale
						else:
							wall.other_sector = $Level.sidedefs[$Level.linedefs[wall.line_index].right_sidedef].sector
							wall.other_floor_height = $Level.sectors[wall.other_sector].floor_height * level_scale
							wall.other_ceil_height = $Level.sectors[wall.other_sector].ceil_height * level_scale

					if wall.sector != wall.other_sector:
						walls.push_back(wall)
						add_child(wall)
				line_index += 1

		sidedef_index += 1

	return walls

func render_level() -> void:
	var walls = build_walls()

	var sectors_drawn = []
	var sector_id : int = 0

	for sector in $Level.sectors:
		var current_sector = $Level.sectors[sector_id]

		var walls_in_current_sector = []
		for candidate_wall in walls:
			if candidate_wall.sector == sector_id:
				for duplicate in walls_in_current_sector:
					if duplicate.line_index == candidate_wall.line_index:
						walls_in_current_sector.erase(duplicate)
						break

				walls_in_current_sector.append(candidate_wall)

			if candidate_wall.other_sector == sector_id:
				var skip : bool = false
				for duplicate in walls_in_current_sector:
					if duplicate.line_index == candidate_wall.line_index:
						skip = true
						break

				if not skip:
					walls_in_current_sector.append(candidate_wall)

		if walls_in_current_sector.empty():
			sector_id += 1
			continue

		var found_map_sector = null
		for look_sector in map_sectors:
			if look_sector.sector_id == sector_id:
				found_map_sector = look_sector
				break

		if found_map_sector == null:
			found_map_sector = sector_blueprint.new()
			found_map_sector.sector_id = sector_id
			found_map_sector.light_level = current_sector.light_level
			found_map_sector.floor_height = current_sector.floor_height * level_scale
			found_map_sector.ceil_height = current_sector.ceil_height * level_scale
			map_sectors.append(found_map_sector)

		found_map_sector.walls = walls_in_current_sector
		var points_set : Array = _triangulate(walls_in_current_sector, found_map_sector)

		for points in points_set:
			for idx in range(0, points.size(), 3):
				var v1 = points[idx]
				var v2 = points[idx + 1]
				var v3 = points[idx + 2]

				if current_sector.floor_texture != "F_SKY1":
					var floor_segment = flat_segment_blueprint.new(sector_id)
					found_map_sector.floor_segments.append(floor_segment)
					add_child(floor_segment)

					floor_segment.create_floor_part(v1, v2, v3, found_map_sector.floor_height, current_sector.floor_texture, found_map_sector.light_level)

				if current_sector.ceil_texture != "F_SKY1":
					var ceil_segment = flat_segment_blueprint.new(sector_id)
					found_map_sector.ceil_segments.append(ceil_segment)
					add_child(ceil_segment)

					ceil_segment.create_ceiling_part(v1, v2, v3, found_map_sector.ceil_height, current_sector.ceil_texture, found_map_sector.light_level)

		sectors_drawn.append(sector_id)
		sector_id += 1

	for sector in map_sectors:
		for wall in sector.walls:
			var duplicate = null
			for sector_duplicate in map_sectors:
				for wall_duplicate in sector_duplicate.walls:
					if wall_duplicate.line_index == wall.line_index:
						duplicate = wall_duplicate
						break

				if duplicate != null:
					break

			wall.create(duplicate)

func _triangulate(walls_in_current_sector: Array, sector) -> Array:
	var points_set : Array = []

	for sorted_polys in sort_polys(walls_in_current_sector):
		sector.polygon_set.append(sorted_polys[0])
		get_node(ear_cut_path).positions = PoolVector2Array(sorted_polys[0])
		get_node(ear_cut_path).rejects = []

		for rej in range(1, sorted_polys.size()):
			get_node(ear_cut_path).rejects.append(PoolVector2Array(sorted_polys[rej]))

		points_set.append(get_node(ear_cut_path).triangulate())

	sector.triangulated_polygon_set = points_set
	return points_set

# Returns Array of Array of structs: Outer, Inner1, Inner2, InnerN...
func sort_polys(walls : Array) -> Array:
	var copy = [] + walls
	var sorted = []

	while not copy.empty():
		var element = copy[0]

		var sub_array = []

		var vertex1 = $Level.vertexes[element.start_vertex_index]
		var vertex2 = $Level.vertexes[element.end_vertex_index]
#		print("> " + str(element.id))
#		print("> " + str(element.start_vertex) + " " + str(element.end_vertex))

		sub_array.append(Vector2(vertex1.x, vertex1.y))
		sub_array.append(Vector2(vertex2.x, vertex2.y))

		var last_vertex = vertex2

		copy.remove(0)

		var still_connected = true
		while still_connected:
			var found = false

			for i in range(0, copy.size()):
				var element_tmp = copy[i]
				var tmp1 = $Level.vertexes[element_tmp.start_vertex_index]
				var tmp2 = $Level.vertexes[element_tmp.end_vertex_index]

				if tmp1.x == last_vertex.x and tmp1.y == last_vertex.y:
					sub_array.append(Vector2(tmp1.x, tmp1.y))
					sub_array.append(Vector2(tmp2.x, tmp2.y))
#					print("A " + str(element_tmp.id))
#					print("A " + str(element_tmp.start_vertex) + " " + str(element_tmp.end_vertex))
					copy.remove(i)

					last_vertex = tmp2
					found = true
					break
				elif tmp2.x == last_vertex.x and tmp2.y == last_vertex.y:
					sub_array.append(Vector2(tmp2.x, tmp2.y))
					sub_array.append(Vector2(tmp1.x, tmp1.y))
#					print("B " + str(element_tmp.id))
#					print("B " + str(element_tmp.start_vertex) + " " + str(element_tmp.end_vertex))
					copy.remove(i)

					last_vertex = tmp1
					found = true
					break

			if not found:
				still_connected = false

		sorted.append(sub_array)

	#	Check which polygon is outer-shell one
	var final_array = []
	var islands = []

	if sorted.size() == 1:
		var item : Array = []
		item.append(sorted[0])

		final_array.append(item)
	else:
		var inner_counter
		var inners : Array = []

		for outer in sorted:
			inner_counter = 0
			for inner in sorted:
				if _poly_contains_poly(outer, inner):
					if not inners.has(inner_counter):
						inners.append(inner_counter)

				inner_counter += 1

		var outers : Array = []

		inner_counter = 0
		for el in sorted:
			if not inners.has(inner_counter):
				var item : Array = []
				item.append(el)

				var deep_inner_counter = 0
				for deep_el in sorted:
					if inners.has(deep_inner_counter):
						item.append(deep_el)

					deep_inner_counter += 1

				final_array.append(item)

			inner_counter += 1

	return final_array

func _poly_contains_poly(outer: Array, inner: Array) -> bool:
	for point in inner:
		if not _point_in_poly(outer, point):
			return false

	return true

func _point_in_poly(polygon : Array, test_point : Vector2) -> bool:
	var i : int = 0
	var j : int = polygon.size() - 1
	var c : bool = false

	for vert in polygon:
		if (((polygon[i].y > test_point.y) != (polygon[j].y > test_point.y)) and \
		(test_point.x < (polygon[j].x - polygon[i].x) * (test_point.y - polygon[i].y) / (polygon[j].y - polygon[i].y) + polygon[i].x)):
			c = not c

		j = i
		i += 1

	return c

func render_things():
	for thing in $Level.things:
		if thing.type != 11: # deathmatch start
			var thing_obj = thing_blueprint.new(thing.type, thing.angle, Vector2(thing.x, thing.y))
			add_child(thing_obj)

func get_picture(pic_name):
	return $Level.get_picture(pic_name)

func get_linedef(id):
	return $Level.linedefs[id]

func get_sidedef(id):
	return $Level.sidedefs[id]

func get_sector(id):
	return $Level.sectors[id]
