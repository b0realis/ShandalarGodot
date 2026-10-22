class_name WorldArt
extends RefCounted
## THE WORLD SCREEN'S SHEETS — the 1997 sprites the world is drawn from,
## imported into the skin as `world_*` (`tools/import_original.py`,
## WORLD_SHEETS): a grid of equal frames per sheet and a `.json` sidecar
## with the grid and every frame's anchor (its top clip).
##
## Null textures when the skin lacks them: [WorldView] then draws the
## world plain.

## The frame size and columns of each sheet, for a sidecar that is missing
## (the importer writes the same).
const LAYOUT := {
	"world_landtile": [128, 64, 6], "world_cstline1": [64, 32, 7],
	"world_land": [128, 83, 5], "world_land2": [128, 83, 5],
	"world_sland": [128, 83, 5], "world_sland2": [128, 83, 5],
	"world_roads": [128, 64, 6],
	"world_locatn01": [128, 128, 6], "world_locatn02": [192, 192, 6],
	"world_locatn03": [128, 128, 6], "world_locatn04": [192, 192, 6],
	"world_locatn05": [128, 128, 6], "world_locatn06": [192, 192, 6],
	"world_locatn07": [128, 128, 6],
	"world_castles1": [192, 192, 6], "world_castles2": [192, 192, 6],
	"world_ego_m": [154, 108, 5], "world_ego_f": [154, 108, 5], "world_sego_f": [154, 108, 5],
}

var _textures := {}
var _meta := {}


func texture(key: String) -> Texture2D:
	if not _textures.has(key):
		_textures[key] = GameSkin.texture(key)
	return _textures[key]


## Whether the sheets the ground needs are there — the test for drawing
## the 1997 world rather than the plain one.
func ready() -> bool:
	return texture("world_landtile") != null and texture("world_cstline1") != null


## Frame [param frame]'s rectangle in the sheet's own drawn size.
func frame_rect(key: String, frame: int) -> Rect2:
	var size := frame_size(key)
	var columns := _columns(key)
	return Rect2((frame % columns) * size.x, (frame / columns) * size.y, size.x, size.y)


func frame_size(key: String) -> Vector2:
	var meta := _metadata(key)
	if meta.has("frame_width"):
		return Vector2(int(meta["frame_width"]), int(meta["frame_height"]))
	var row: Array = LAYOUT.get(key, [0, 0, 1])
	return Vector2(row[0], row[1])


## A frame's anchor, the height above its foot the original drew it at;
## the format's -1 (no anchor) is 0, as the 1997 retail release reads it.
func top(key: String, frame: int) -> int:
	var tops: Array = _metadata(key).get("tops", [])
	if frame < 0 or frame >= tops.size():
		return 0
	return maxi(0, int(tops[frame]))


func _columns(key: String) -> int:
	var meta := _metadata(key)
	if meta.has("cols"):
		return maxi(1, int(meta["cols"]))
	var row: Array = LAYOUT.get(key, [0, 0, 1])
	return row[2]


func _metadata(key: String) -> Dictionary:
	if not _meta.has(key):
		_meta[key] = GameSkin.metadata(key)
	return _meta[key]
