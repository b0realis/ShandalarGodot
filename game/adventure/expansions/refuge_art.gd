class_name RefugeArt
extends RefCounted
## Expansion pictures have their own dimensions; their map footprint is
## fixed in world pixels, independent of the skin's resolution.

const HARBOR = preload("res://game/adventure/expansions/art/refuge_harbor.png")
const CASTLE = preload("res://game/adventure/expansions/art/refuge_castle.png")
const PORT_MAP = preload("res://game/adventure/expansions/art/refuge_port_map.png")
const CASTLE_MAP = preload("res://game/adventure/expansions/art/refuge_castle_map.png")
static var _rects := {}

static func picture(key: String) -> Texture2D:
	match key:
		"refuge_harbor": return HARBOR
		"refuge_castle": return CASTLE
	return GameSkin.texture(key)

static func map_op(kind: String) -> Array:
	var texture: Texture2D = PORT_MAP if kind == "port" else CASTLE_MAP
	if not _rects.has(kind):
		_rects[kind] = Rect2(texture.get_image().get_used_rect())
	var source: Rect2 = _rects[kind]
	var width := 160.0 if kind == "port" else 192.0
	var height := width * source.size.y / maxf(1.0, source.size.x)
	return [texture, Rect2(Vector2(64.0 - width / 2.0, 24.0 - height), Vector2(width, height)), source]
