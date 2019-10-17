extends Spatial

# If you want to extend this script for your purposes, read
# http://www.gamers.org/dhs/helpdocs/dmsp1666.html

export(bool) var PrintDebugInfo = true

var min_height := 1000
var max_height := -1000

var vertexes = []
var things = []
var linedefs = []
var sidedefs = []
var sectors = []
var pictures =  []
var palettes = []
var pnames = []

func decode_32_as_string(file):
	var c1 = char(file.get_8())
	var c2 = char(file.get_8())
	var c3 = char(file.get_8())
	var c4 = char(file.get_8())
	return c1 + c2 + c3 + c4

func decode_64_as_string(file):
	var c1 = char(file.get_8())
	var c2 = char(file.get_8())
	var c3 = char(file.get_8())
	var c4 = char(file.get_8())
	var c5 = char(file.get_8())
	var c6 = char(file.get_8())
	var c7 = char(file.get_8())
	var c8 = char(file.get_8())
	return c1 + c2 + c3 + c4 + c5 + c6 + c7 + c8 

class Header:
	var type
	var lumpNum
	var dirOffset

class Lump:
	var offset
	var size
	var name

class Thing:
	var x
	var y
	var angle
	var type
	var options

class Linedef:
	var start_vertex
	var end_vertex
	var flags
	var type
	var trigger
	var right_sidedef
	var left_sidedef

class Sidedef:
	var x_offset
	var y_offset
	var upper_texture
	var lower_texture
	var middle_texture
	var sector

class Vertex:
	var x
	var y
	
class Segment:
	var from
	var to
	var angle
	var linedef
	var direction
	var offset

class Sector:
	var floor_height
	var ceil_height
	var floor_texture
	var ceil_texture
	var light_level
	var special
	var tag
	
class Picture:
	var name
	var width
	var height
	var image
	var image_texture

func read_lump(file):
	var lump = Lump.new()
	lump.offset = file.get_32()
	lump.size = file.get_32()
	lump.name = decode_64_as_string(file)
	return lump
	
# combine two bytes to short
func to_short(a, b):
	return wrapi((b << 8) | (a & 0xff), -32768, 32768)
	
# combine eight bytes to string
func combine_8_bytes_to_string(c1, c2, c3, c4, c5, c6, c7, c8):
	return char(c1) + char(c2) + char(c3) + char(c4) + char(c5) + char(c6) + char(c7) + char(c8)
	
func add_picture(name, width, height, image, image_texture):
	var picture = Picture.new()
	picture.name = name.to_upper()
	picture.width = width
	picture.height = height
	picture.image = image
	picture.image_texture = image_texture
	
	pictures.append(picture)
	
func get_picture(name):
	var search_name = name.to_upper()
	
	for pic in pictures:
		if pic.name == search_name:
			return pic
			
	for pic in pictures:
		if pic.name == "DUMMY":
			return pic	
			
func _ready() -> void:
	var image_texture = load("res://gfx/STARTAN3.png")
	
	add_picture("DUMMY", 64, 64, null, image_texture)

func load_wad(wad_path, level_name, level_scale):
	vertexes = []
	things = []
	linedefs = []
	sidedefs = []
	sectors = []
	
	var buffer
	var i
	print("Opening %s" % wad_path + "...")
	
	var file = File.new() 
	if file.open(wad_path, File.READ) != OK:
		print("Failed to open WAD file %s" % wad_path)
		return
		
	if PrintDebugInfo:
		print("READING HEADER...")	
	var header = Header.new()  
	header.type = decode_32_as_string(file)
	header.lumpNum = file.get_32()
	header.dirOffset = file.get_32()
	
	print(wad_path," is ", header.type)
	
	if PrintDebugInfo:
		print("READING LUMPS... " + str(header.lumpNum))
	
	var lump_mapname
	var lump_things
	var lump_linedefs
	var lump_sidedefs
	var lump_vertexes
	var lump_segs
	var lump_sectors
	var lump_reject
	var lump_texture
	
	var first = true
	var breakAfter = false
	var map_look = true
	file.seek(header.dirOffset)
	
	var sprite_look = false
	var flat_look = false
	var gui_look = false
	
	for i in range(header.lumpNum):
		var lump = read_lump(file)
		
		if lump.name == "PLAYPAL":
			var pos = file.get_position()
			file.seek(lump.offset)
			for i in range(0, lump.size / 256, 256):
				var palette = []

				for i in range(0, 256):
					palette.append(Color(file.get_8() / 255.0, file.get_8() / 255.0, file.get_8() / 255.0))

				palettes.append(palette)
			
			file.seek(pos)			
			
		if lump.name == "PNAMES":
			var pos = file.get_position()
			file.seek(lump.offset)
			
			var nummappatches = file.get_32()
			for i in range(0, nummappatches):
				var name = file.get_buffer(8)
				pnames.append(combine_8_bytes_to_string(name[0], name[1], name[2], name[3], name[4], name[5], name[6], name[7]).to_upper())
			
			file.seek(pos)		
	
		if lump.name == "D_INTROA":
			gui_look = true
			continue
			
		if lump.name == "S_START" || lump.name == "P1_START":
			gui_look = false
			sprite_look = true
			continue
			
		if lump.name == "S_END" || lump.name == "P1_END":
			sprite_look = false
			
		if lump.name == "F1_START":
			flat_look = true
			continue
			
		if lump.name == "F1_END":
			flat_look = false			
			
		if lump.name == "TEXTURE1":
			lump_texture = lump
			
		if sprite_look || gui_look:
			var raw_image = Image.new()
			var pos = file.get_position()
			
			file.seek(lump.offset)
			var width = file.get_16()
			var height = file.get_16()
			var leftoffset = file.get_16()
			var topoffset = file.get_16()

			raw_image.create(width, height, false, Image.FORMAT_RGBA8)
			raw_image.lock()
			
			var col_array = []
			
			for i in range(0, width):					
				col_array.append(file.get_32())
				
			for i in range(0, width):
				file.seek(lump.offset + col_array[i])
				
				var loop = true
				
				while loop:
					var row_start = file.get_8()
					
					if row_start == 255:
						break
						
					var pixel_count = file.get_8()
					var dummy = file.get_8()
					
					for j in range(0, pixel_count):
						var pixel_index = file.get_8()
						raw_image.set_pixel(i, j + row_start, palettes[0][pixel_index])
						
					var second_dummy = file.get_8()
			
			raw_image.unlock()

			var imageTexture = ImageTexture.new()
			imageTexture.create_from_image(raw_image, 1 | 2)
			
			add_picture(lump.name, width, height, raw_image, imageTexture)
			
			file.seek(pos)
			
		if flat_look:
			var raw_image = Image.new()
			var pos = file.get_position()
			
			file.seek(lump.offset)

			raw_image.create(64, 64, false, Image.FORMAT_RGBA8)
			raw_image.lock()
			
			var col_array = []
			
			for i in range(0, 64 * 64):
				var pixel_index = file.get_8()
				raw_image.set_pixel(i % 64, i / 64, palettes[0][pixel_index])
			
			raw_image.unlock()

			var imageTexture = ImageTexture.new()
			imageTexture.create_from_image(raw_image, 1 | 2)
			
			add_picture(lump.name, 64, 64, raw_image, imageTexture)
			
			file.seek(pos)			
		
		if map_look:
			if first:
				lump_mapname = lump
				first = false
			match lump.name:
				"THINGS":
					lump_things = lump
				"LINEDEFS":
					lump_linedefs = lump
				"SIDEDEFS":
					lump_sidedefs = lump
				"VERTEXES":
					lump_vertexes = lump
				"SEGS":
					lump_segs = lump
				"SECTORS":
					lump_sectors = lump
				"REJECT":
					lump_reject = lump
				"BLOCKMAP":
					if breakAfter:
						map_look = false
				level_name:
					breakAfter = true
					
	if PrintDebugInfo:
		print("Internal map name: " + lump_mapname.name)
	
	if PrintDebugInfo:
		print("READING THINGS...")
	file.seek(lump_things.offset)
	buffer = file.get_buffer(lump_things.size)
	i = 0
	while i < buffer.size():
		var thing = Thing.new()
		thing.x = to_short(buffer[i], buffer[i+1]) * level_scale
		thing.y = to_short(buffer[i+2], buffer[i+3]) * level_scale
		thing.angle = to_short(buffer[i+4], buffer[i+5])
		thing.type = to_short(buffer[i+6], buffer[i+7])
		thing.options = to_short(buffer[i+8], buffer[i+9])
		things.push_back(thing)
		i+=10
		
	if PrintDebugInfo:
		print("READING LINEDEFS...")
	file.seek(lump_linedefs.offset)
	buffer = file.get_buffer(lump_linedefs.size)
	i = 0
	while i < buffer.size():
		var linedef = Linedef.new()
		linedef.start_vertex = to_short(buffer[i],buffer[i+1])
		linedef.end_vertex = to_short(buffer[i+2],buffer[i+3])
		linedef.flags = to_short(buffer[i+4],buffer[i+5])
		linedef.type = to_short(buffer[i+6],buffer[i+7])
		linedef.trigger = to_short(buffer[i+8],buffer[i+9])
		linedef.right_sidedef = to_short(buffer[i+10],buffer[i+11])
		linedef.left_sidedef = to_short(buffer[i+12],buffer[i+13])
		linedefs.push_back(linedef)
		i+=14
	
	if PrintDebugInfo:
		print("READING SIDEDEFS...")
	file.seek(lump_sidedefs.offset)
	buffer = file.get_buffer(lump_sidedefs.size)
	i = 0
	while i < buffer.size():
		var sidedef = Sidedef.new()
		sidedef.x_offset = to_short(buffer[i], buffer[i+1])
		sidedef.y_offset = to_short(buffer[i+2], buffer[i+3])
		sidedef.upper_texture = combine_8_bytes_to_string(buffer[i+4], buffer[i+5], buffer[i+6], buffer[i+7], buffer[i+8], buffer[i+9], buffer[i+10], buffer[i+11])
		sidedef.lower_texture = combine_8_bytes_to_string(buffer[i+12], buffer[i+13], buffer[i+14], buffer[i+15], buffer[i+16], buffer[i+17], buffer[i+18], buffer[i+19])
		sidedef.middle_texture = combine_8_bytes_to_string(buffer[i+20], buffer[i+21], buffer[i+22], buffer[i+23], buffer[i+24], buffer[i+25], buffer[i+26], buffer[i+27])
		sidedef.sector = to_short(buffer[i+28], buffer[i+29])
		sidedefs.push_back(sidedef)
		i+=30
		
	if PrintDebugInfo:
		print("READING VERTEXES...")
	file.seek(lump_vertexes.offset)
	
	buffer = file.get_buffer(lump_vertexes.size)
	i = 0
	while i < buffer.size():
		var x = to_short(buffer[i], buffer[i+1]) * level_scale
		var y = to_short(buffer[i+2], buffer[i+3]) * level_scale
		var vertex = Vertex.new()
		vertex.x = float(x)
		vertex.y = float(y)	
		vertexes.push_back(vertex)
		i+=4
	
	if PrintDebugInfo:
		print("READING SECTORS...")
	file.seek(lump_sectors.offset)
	buffer = file.get_buffer(lump_sectors.size)
	i = 0
	while i < buffer.size():
		var sector = Sector.new()
		sector.floor_height = to_short(buffer[i],buffer[i+1])
		sector.ceil_height = to_short(buffer[i+2],buffer[i+3])
		sector.floor_texture = combine_8_bytes_to_string(buffer[i+4], buffer[i+5], buffer[i+6], buffer[i+7], buffer[i+8], buffer[i+9], buffer[i+10], buffer[i+11])
		sector.ceil_texture = combine_8_bytes_to_string(buffer[i+12], buffer[i+13], buffer[i+14], buffer[i+15], buffer[i+16], buffer[i+17], buffer[i+18], buffer[i+19])
		sector.light_level = to_short(buffer[i+20], buffer[i+21])
		sector.special = to_short(buffer[i+22], buffer[i+23])
		sector.tag = to_short(buffer[i+24], buffer[i+25])

		sectors.push_back(sector)
		
		if sector.floor_height * level_scale < min_height:
			min_height = sector.floor_height * level_scale
		
		if sector.ceil_height * level_scale > max_height:
			max_height = sector.ceil_height * level_scale

		i+=26
		
	if PrintDebugInfo:
		print("READING TEXTURES...")
	file.seek(lump_texture.offset)
	
	var numtextures = file.get_32()
	var offsets = []
	
	for i in range(0, numtextures):
		offsets.append(file.get_32())	

	for i in range(0, numtextures):
		file.seek(lump_texture.offset + offsets[i])

		var name = file.get_buffer(8)
		name = combine_8_bytes_to_string(name[0], name[1], name[2], name[3], name[4], name[5], name[6], name[7])
		var masked = file.get_32()
		var width = file.get_16()
		var height = file.get_16()
		var columndirectory = file.get_32()
		var patchcount = file.get_16()
		
		var raw_image = Image.new()
		raw_image.create(width, height, false, Image.FORMAT_RGBA8)
		
		for j in range(0, patchcount):
			var originx = wrapi(file.get_16(), -32768, 32768)
			var originy = wrapi(file.get_16(), -32768, 32768)
			var patch = file.get_16()
			var stepdir = file.get_16()
			var colormap = file.get_16()
			
			var patch_pic = get_picture(pnames[patch])
			raw_image.blit_rect(patch_pic.image, Rect2(0, 0, patch_pic.width, patch_pic.height), Vector2(originx, originy))
			
		var imageTexture = ImageTexture.new()
		imageTexture.create_from_image(raw_image, 1 | 2)
		add_picture(name, width, height, raw_image, imageTexture)
				
	file.close()
	
