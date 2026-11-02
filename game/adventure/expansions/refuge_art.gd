class_name RefugeArt
extends RefCounted
## Expansion pictures have their own dimensions; their map footprint is
## fixed in world pixels, independent of the skin's resolution.

static var HARBOR: Texture2D:
	get: return AdventureExpansions.picture("refuge_harbor")
static var CASTLE: Texture2D:
	get: return AdventureExpansions.picture("refuge_castle")

static func picture(key: String) -> Texture2D:
	return AdventureExpansions.picture(key)

static func map_op(kind: String) -> Array:
	return AdventureExpansions.map_op("refuge:" + kind)
