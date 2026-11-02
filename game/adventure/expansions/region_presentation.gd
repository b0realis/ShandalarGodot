class_name RegionPresentation
extends RefCounted
## Tiny shared pennants, baked into existing map pictures. No new frame loop,
## scene, image pack or per-region texture collection. Metadata is saveable.
static var _flags := {}

static func banner(world: ShandalarWorld, tile: Vector2i) -> Array:
	for mark in world.expansion.get("banners", []):
		if mark.get("point", []) != [tile.x, tile.y]: continue
		var color := Color.from_string(String(mark.get("color", "d4b35c")), Color.GOLD)
		var key := color.to_html(false)
		if not _flags.has(key):
			var image := Image.new()
			image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="32"><path d="M4 31V1" stroke="#30251b" stroke-width="4"/><path d="M4 31V1" stroke="#d9bb79" stroke-width="2"/><path d="M5 3H22L18 9L22 15H5Z" fill="#%s" stroke="#30251b"/><path d="M6 4H20" stroke="#f0d99b"/></svg>' % key)
			_flags[key] = ImageTexture.create_from_image(image)
		var anchor: Array = mark.get("anchor", [108, -24])
		var dimensions: Array = mark.get("size", [18, 24])
		return [_flags[key], Rect2(Vector2(anchor[0], anchor[1]), Vector2(dimensions[0], dimensions[1])), Rect2(0, 0, 24, 32)]
	return []
