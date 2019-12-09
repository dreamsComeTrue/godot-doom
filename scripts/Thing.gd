extends Sprite3D

var type : int
var angle: float
var location: Vector2

var pic_lookup = {
		9: { "pics": ["SPOSA1"], "pickable": true, "obstacle": false },
		10: { "pics": ["SPOSU0"], "pickable": true, "obstacle": false },
		12: { "pics": ["SPOSU0"], "pickable": true, "obstacle": false },
		15: { "pics": ["PLAYN0"], "pickable": true, "obstacle": false },
		48: { "pics": ["ELECA0"], "pickable": true, "obstacle": false },

		2005: { "pics": ["CSAWA0"], "pickable": true, "obstacle": false },														# Chainsaw
		2001: { "pics": ["SHOTA0"], "pickable": true, "obstacle": false },														# Shotgun
		82: { "pics": ["SGN2A0"], "pickable": true, "obstacle": false },														# Double-barreled shotgun
		2002: { "pics": ["MGUNA0"], "pickable": true, "obstacle": false },														# Chaingun
		2003: { "pics": ["LAUNA0"], "pickable": true, "obstacle": false },														# Rocket launcher
		2004: { "pics": ["PLASA0"], "pickable": true, "obstacle": false },														# Plasma gun
		2006: { "pics": ["BFUGA0"], "pickable": true, "obstacle": false },														# Bfg9000

		2007: { "pics": ["CLIPA0"], "pickable": true, "obstacle": false },														# Ammo clip
		2008: { "pics": ["SHELA0"], "pickable": true, "obstacle": false },														# Shotgun shells
		2010: { "pics": ["ROCKA0"], "pickable": true, "obstacle": false },														# A rocket
		2047: { "pics": ["CELLA0"], "pickable": true, "obstacle": false },														# Cell charge
		2048: { "pics": ["AMMOA0"], "pickable": true, "obstacle": false },														# Box of Ammo
		2049: { "pics": ["SBOXA0"], "pickable": true, "obstacle": false },														# Box of Shells
		2046: { "pics": ["BROKA0"], "pickable": true, "obstacle": false },														# Box of Rockets
		17: { "pics": ["CELPA0"], "pickable": true, "obstacle": false },														# Cell charge pack
		8: { "pics": ["BPAKA0"], "pickable": true, "obstacle": false },															# Backpack: doubles maximum ammo capacities

		2011: { "pics": ["STIMA0"], "pickable": true, "obstacle": false },														# Stimpak
		2012: { "pics": ["MEDIA0"], "pickable": true, "obstacle": false },														# Medikit
		2014: { "pics": ["BON1A0", "BON1B0", "BON1C0", "BON1D0", "BON1C0", "BON1B0"], "pickable": true, "obstacle": false },	# Health Potion +1% health
		2015: { "pics": ["BON2A0", "BON2B0", "BON2C0", "BON2D0", "BON2C0", "BON2B0"], "pickable": true, "obstacle": false },	# Spirit Armor +1% armor
		2018: { "pics": ["ARM1A0", "ARM1B0"], "pickable": true, "obstacle": false },											# Green armor 100%
		2019: { "pics": ["ARM2A0", "ARM2B0"], "pickable": true, "obstacle": false },											# Blue armor 200%

		2028: { "pics": ["COLUA0"], "pickable": true, "obstacle": false },
		2035: { "pics": ["BAR1A0", "BAR1B0"], "pickable": false, "obstacle": true },											# Barrel

		3001: { "pics": ["TROOA1"], "pickable": true, "obstacle": false },
		3004: { "pics": ["POSSA1"], "pickable": true, "obstacle": false }
	}

func _init(type: int, angle: float, location: Vector2) -> void:
	self.type = type
	self.angle = angle
	self.location = location

func _ready() -> void:
	var pictures : Array = ["SPOSD1"]

	if pic_lookup.has(type):
		pictures = pic_lookup[type].pics

	if type != 11: # deathmatch start
		create_sprite3d(location, pictures)

	self.rotate_y(deg2rad(angle - 90))

func create_sprite3d(location, pictures):
	var parent := get_parent()
	var material = SpatialMaterial.new()
	material.flags_unshaded = true
	material.flags_transparent = true
	material.params_billboard_keep_scale = true
	material.params_billboard_mode = SpatialMaterial.BILLBOARD_FIXED_Y
	material.params_depth_draw_mode = SpatialMaterial.DEPTH_DRAW_ALPHA_OPAQUE_PREPASS
	material.flags_disable_ambient_light = true
	material.flags_do_not_receive_shadows = true

	var space_state = parent.get_world().direct_space_state
	var raycast = space_state.intersect_ray(Vector3(location.x, -10000, -location.y), Vector3(location.x, 10000, -location.y))
	var up_posiiton = Vector3.ONE

	if raycast:
		up_posiiton = raycast.position

		for sector in parent.map_sectors:
			for floor_segment in sector.floor_segments:
				if floor_segment.raycast_id == raycast.collider.get_instance_id():
					var sector_color = Color.white * (sector.light_level / 255.0)
					material.albedo_color.r = sector_color.r
					material.albedo_color.g = sector_color.g
					material.albedo_color.b = sector_color.b
					break

	var animated_texture = AnimatedTexture.new()
	var pic_height: float

	animated_texture.frames = pictures.size()
	animated_texture.fps = 5

	var index = 0
	for animated_picture in pictures:
		var pic : Reference = parent.get_node("Level").get_picture(animated_picture)
		animated_texture.set_frame_texture(index, pic.image_texture)
		pic_height = pic.height
		index += 1

	material.albedo_texture = animated_texture

	self.offset.y = pic_height * 0.5
	self.texture = animated_texture
	self.translation = Vector3(location.x, up_posiiton.y, -location.y)
	self.material_override = material
	self.scale = Vector3(5, 5, 5)
