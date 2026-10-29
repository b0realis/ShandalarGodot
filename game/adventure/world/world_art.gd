class_name WorldArt
extends RefCounted
## THE WORLD SCREEN'S SHEETS — the 1997 sprites the world is drawn from,
## imported into the skin as `world_*` (`tools/import_original.py`,
## WORLD_SHEETS): a grid of equal frames per sheet and a `.json` sidecar
## with the grid and every frame's anchor (its top clip).
##
## Null textures when the skin lacks them: [WorldView] then draws the
## world plain. A sheet whose grid is known neither from its sidecar nor
## from [constant LAYOUT] is absent too — cut with no grid, every frame
## would be the whole sheet squeezed into one icon.

## The frame size and columns of each sheet (`[width, height, columns]`),
## for a sidecar that is missing: the importer's own table, WORLD_SHEETS in
## `tools/import_original.py`, row for row.
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
	"world_magics": [52, 54, 12], "world_amulets": [12, 17, 5], "world_map_tiles": [13, 20, 16],
	"quest_scroll": [237, 115, 2], "quest_clock": [67, 88, 8], "quest_sunmoon": [67, 88, 14],
	"quest_days": [67, 88, 6],
	# The creatures walking the world (part B; the importer's
	# CREATURE_SHEETS), every one the hero's grid — [method creature_rect].
	"world_creature_bk_fwz": [154, 108, 5], "world_creature_bk_kht": [154, 108, 5],
	"world_creature_bk_mwz": [154, 108, 5], "world_creature_bk_lrd": [154, 108, 5],
	"world_creature_bk_wg": [154, 108, 5], "world_creature_bk_amg": [154, 108, 5],
	"world_creature_w_mwz": [154, 108, 5], "world_creature_w_fwz": [154, 108, 5],
	"world_creature_w_kht": [154, 108, 5], "world_creature_w_lrd": [154, 108, 5],
	"world_creature_w_wg": [154, 108, 5], "world_creature_w_amg": [154, 108, 5],
	"world_creature_bu_fwz": [154, 108, 5], "world_creature_bu_lrd": [154, 108, 5],
	"world_creature_bu_mwz": [154, 108, 5], "world_creature_bu_wrm": [154, 108, 5],
	"world_creature_b_sfr": [154, 108, 5], "world_creature_bu_amg": [154, 108, 5],
	"world_creature_g_mwz": [154, 108, 5], "world_creature_g_kht": [154, 108, 5],
	"world_creature_g_fwz": [154, 108, 5], "world_creature_g_wrm": [154, 108, 5],
	"world_creature_g_lrd": [154, 108, 5], "world_creature_g_amg": [154, 108, 5],
	"world_creature_r_fwz": [154, 108, 5], "world_creature_r_mwz": [154, 108, 5],
	"world_creature_troll": [154, 108, 5], "world_creature_r_lrd": [154, 108, 5],
	"world_creature_r_wrm": [154, 108, 5], "world_creature_r_amg": [154, 108, 5],
	"world_creature_m_tsk": [154, 108, 5], "world_creature_m_trl": [154, 108, 5],
	"world_creature_m_ape": [154, 108, 5], "world_creature_m_cen2": [154, 108, 5],
	"world_creature_m_wg": [154, 108, 5], "world_creature_m_fng": [154, 108, 5],
	"world_creature_m_cen": [154, 108, 5], "world_creature_m_lrd": [154, 108, 5],
	"world_creature_m_kht": [154, 108, 5], "world_creature_m_fwz": [154, 108, 5],
	"world_creature_bk_djn": [154, 108, 5], "world_creature_g_djn": [154, 108, 5],
	"world_creature_r_djn": [154, 108, 5], "world_creature_bu_djn": [154, 108, 5],
	"world_creature_dg_bru": [154, 108, 5], "world_creature_dg_uwb": [154, 108, 5],
	"world_creature_dg_gwr": [154, 108, 5], "world_creature_dg_rbg": [154, 108, 5],
	"world_creature_dg_wug": [154, 108, 5], "world_creature_sfwz": [154, 108, 5],
	"world_creature_sb_kht": [154, 108, 5], "world_creature_smwz": [154, 108, 5],
	"world_creature_sb_lrd": [154, 108, 5], "world_creature_sbk_wg": [154, 108, 5],
	"world_creature_sb_amg": [154, 108, 5], "world_creature_sw_mwz": [154, 108, 5],
	"world_creature_skht": [154, 108, 5], "world_creature_sw_lrd": [154, 108, 5],
	"world_creature_sw_wg": [154, 108, 5], "world_creature_sw_amg": [154, 108, 5],
	"world_creature_su_lrd": [154, 108, 5], "world_creature_swrm": [154, 108, 5],
	"world_creature_sb_sft": [154, 108, 5], "world_creature_su_amg": [154, 108, 5],
	"world_creature_sg_lrd": [154, 108, 5], "world_creature_sg_amg": [154, 108, 5],
	"world_creature_sr_fwz": [154, 108, 5], "world_creature_strl": [154, 108, 5],
	"world_creature_sr_lrd": [154, 108, 5], "world_creature_sr_wrm": [154, 108, 5],
	"world_creature_sr_amg": [154, 108, 5], "world_creature_sm_tsk": [154, 108, 5],
	"world_creature_sm_trl": [154, 108, 5], "world_creature_sm_ape": [154, 108, 5],
	"world_creature_sm_cen": [154, 108, 5], "world_creature_sm_wg": [154, 108, 5],
	"world_creature_sm_fng": [154, 108, 5], "world_creature_sm_cen2": [154, 108, 5],
	"world_creature_sm_lrd": [154, 108, 5], "world_creature_sdjn": [154, 108, 5],
	"world_creature_s_dg": [154, 108, 5],
	# The wizards' window's creature pictures (`Creatures640.pic`, not a
	# sheet the importer writes a sidecar for): 8 cells of 80 x 64 a row.
	"creature_thumbs": [80, 64, 8],
	# The boards of the castles and the dungeons (part C; the importer's
	# DUNGEON_SHEETS, [DungeonView]): the three dungeons' tiles and the five
	# castles', 64 x 64 frames twelve to a row; Dungbutt's plaque pieces,
	# four cells of 201 x 281 (each frame its own size within its cell —
	# the sidecar's `sizes`, else [constant DungeonView.PLAQUE_SIZES]).
	"dungeon_tiles_1": [64, 64, 12], "dungeon_tiles_2": [64, 64, 12], "dungeon_tiles_3": [64, 64, 12],
	"dungeon_tiles_black": [64, 64, 12], "dungeon_tiles_blue": [64, 64, 12],
	"dungeon_tiles_green": [64, 64, 12], "dungeon_tiles_red": [64, 64, 12],
	"dungeon_tiles_white": [64, 64, 12], "dungeon_plaques": [201, 281, 4],
}

## THE CREATURES' SHEETS (part B, 2026-10-23): `world_creature_` + the 1997
## file's name in lower case, bodies and shadows alike (`BK_FWZ.SPR` ->
## world_creature_bk_fwz, `SFWZ.SPR` -> world_creature_sfwz), which file a
## creature wears being the creature book's (1.3
## `LoadCreatureEncounterSprites`, world_lair_monster_slots.c:38-279).
const CREATURE_PREFIX := "world_creature_"
## Frames on a creature's sheet: eight headings of five steps.
const CREATURE_FRAMES := 40
## [ours] A creature sheet's anchor when its sidecar is missing: the
## hero's, 61 (the 1997 sheets run 60-73).
const CREATURE_TOP := 61

## [ours] THE AMULETS' COLOURS WITHOUT THEIR SHEET (`Amsprite.spr`, or a
## screen's painted stones): a square of each colour, black, blue, green,
## red, white ([constant AdventurePlayer.COLORS]' order), so a count is
## never a bare number.
const AMULET_INKS: Array[Color] = [Color8(60, 50, 60), Color8(60, 120, 220), Color8(50, 160, 70),
	Color8(210, 50, 40), Color8(240, 236, 220)]

## THE PLACES' SHEETS — the villages', towns', cities', dungeons' and lairs'
## (`world_locatn01`-`07`) and the castles' — warmed on a worker thread as
## the world opens ([method WorldSoundscape.warm_arrival], [SkinWarmer]):
## each was read on the thread that draws the first time a place of its
## kind came into view, 7-18 ms (the 2x skin 31-63) of one frame of the
## walk. Nine sheets, about 15 MB of textures at 1x (60 MB with the 2x
## skin) that a walk across the map draws anyway — warmed sooner, not more.
const PLACE_SHEETS: Array[String] = ["world_locatn01", "world_locatn02", "world_locatn03",
	"world_locatn04", "world_locatn05", "world_locatn06", "world_locatn07",
	"world_castles1", "world_castles2"]

var _textures := {}
var _meta := {}


## Sheet [param key], or null when the skin lacks it or its grid is
## unknown (no sidecar and no [constant LAYOUT] row).
func texture(key: String) -> Texture2D:
	if not _textures.has(key):
		var sheet := GameSkin.texture(key)
		_textures[key] = sheet if sheet != null and _gridded(key) else null
	return _textures[key]


## WHETHER SHEET [param key] CAN BE DRAWN THIS FRAME WITHOUT A STALL (the
## smoothness pass, 0.50.66): true when it is in hand, when no place has it
## ([method texture] then answers null at once, as always), when the key is
## empty, or where no worker may decode ([method SkinWarmer.runs_here]:
## headless — the tests —, the web), where [method texture] reads it on
## demand as before; false while a worker decodes it — the first ask starts
## that, and past [constant SkinWarmer.MOST_WAIT_MS] the sheet is read on
## demand after all. A creature just come into view is drawn once its
## sheets are in hand, a frame or a few later, instead of the frame
## stalling on them (a new creature stands 4 tiles out, already in view, so
## nothing can be warmed before it is: [WorldLairs]' refill). One
## dictionary look-up once the sheet is in hand.
func sheet_ready(key: String) -> bool:
	if _textures.has(key) or key == "":
		return true
	if SkinWarmer.picture_pending(key):
		return false
	if not SkinWarmer.runs_here():
		return true
	var job := GameSkin.picture_job(key)
	if job.is_empty():
		texture(key)
		return true
	var wanted: Array[String] = [key]
	return SkinWarmer.warm(null, wanted, [], [], true) == null


## A square of amulet colour [param color] (0 black … 4 white,
## [constant AMULET_INKS]), [param side] across, for a screen to stand
## where the sheet's stone would.
static func amulet_disc(color: int, side: float) -> ColorRect:
	var disc := ColorRect.new()
	disc.color = AMULET_INKS[clampi(color, 0, AMULET_INKS.size() - 1)]
	disc.size = Vector2(side, side)
	disc.custom_minimum_size = disc.size
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return disc


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


## A frame's anchor, the height above its foot the original drew it at
## (a creature's: [method creature_top]);
## the format's -1 (no anchor) is 0, as the 1997 retail release reads it.
func top(key: String, frame: int) -> int:
	var tops: Array = _metadata(key).get("tops", [])
	if frame < 0 or frame >= tops.size():
		return 0
	return maxi(0, int(tops[frame]))


## Creature sheet [param stem]'s key: `"BK_FWZ"` -> `world_creature_bk_fwz`.
static func creature_key(stem: String) -> String:
	return CREATURE_PREFIX + stem.to_lower()


## The frame a creature shows facing 1997 heading [param heading] (0-7) on
## walk step [param step] (0-4): the hero's formula (1.3
## adventureWorldUi.c:2255-2280), so heading 0, a creature just come,
## draws like north-west.
static func creature_frame(heading: int, step: int) -> int:
	return ((heading + 2) & 7) * 5 + clampi(step, 0, 4)


## Frame [param frame] (0-39, clamped) of creature sheet [param key], in
## the sheet's own drawn size.
func creature_rect(key: String, frame: int) -> Rect2:
	return frame_rect(key, clampi(frame, 0, CREATURE_FRAMES - 1))


## Creature sheet [param key]'s anchor: frame 0's top clip, the height
## above the creature's feet every frame's top stands at (the other 39
## carry -1, 1997's "none"), or two thirds of the frame's height where
## the clip is taller than the frame (1.3 world_lair_monster_slots.c
## :262-267); [constant CREATURE_TOP] without a sidecar. A shadow is
## drawn at its BODY's anchor (the same lines copy it), so ask with the
## body's key for both.
func creature_top(key: String) -> int:
	var tops: Array = _metadata(key).get("tops", [])
	if tops.is_empty() or int(tops[0]) <= 0:
		return CREATURE_TOP
	var height := int(frame_size(key).y)
	return int(tops[0]) if int(tops[0]) <= height else height * 2 / 3


## Where a creature's frame stands from its feet: the frame is drawn at
## `feet - creature_anchor(body_key)` — half its width across, its anchor
## up ([method creature_top]; 1.3 adventureWorldUi.c:2262-2263).
func creature_anchor(key: String) -> Vector2:
	return Vector2(int(frame_size(key).x) / 2, creature_top(key))


## Creature table row [param row]'s cell (1 the Witch ... 56) in the
## wizards' window's pictures, `creature_thumbs` (cell = row - 1).
func thumb_rect(row: int) -> Rect2:
	return frame_rect("creature_thumbs", maxi(0, row - 1))


## Whether sheet [param key]'s grid is known: its sidecar, or a
## [constant LAYOUT] row.
func _gridded(key: String) -> bool:
	return _metadata(key).has("frame_width") or LAYOUT.has(key)


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
