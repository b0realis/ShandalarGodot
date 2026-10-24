extends GutTest
## THE CREATURES' SHEETS ON THE WORLD MAP (part B, 2026-10-23): what
## [WorldArt] tells the map about a creature's sheet — its key, the frame
## a heading and a step show, that frame's rectangle, and the anchor the
## frame stands on above the creature's feet (1.3
## `LoadCreatureEncounterSprites`, world_lair_monster_slots.c:38-279, and
## the drawing at adventureWorldUi.c:2255-2280) — and the wizards' window's
## creature pictures by table row. No skin is read: the sheets' sidecars
## are put in [GameSkin]'s cache and taken out again.

const BODY := "world_creature_bk_kht"
const THUMBS := "creature_thumbs"

var _kept := {}


func before_each() -> void:
	_kept = {}
	for key in [BODY, THUMBS]:
		_kept[key] = GameSkin._meta_cache.get(key)


func after_each() -> void:
	for key in _kept:
		if _kept[key] == null:
			GameSkin._meta_cache.erase(key)
		else:
			GameSkin._meta_cache[key] = _kept[key]


## The sidecar the importer writes for a creature sheet, its first frame's
## top clip [param top0] and -1 for the other 39.
func _sidecar(top0: int) -> Dictionary:
	var tops: Array = [top0]
	for i in 39:
		tops.append(-1)
	return {"cols": 5, "rows": 8, "frames": 40, "frame_width": 154, "frame_height": 108, "tops": tops}


func test_the_key_is_the_file_s_name_in_lower_case() -> void:
	assert_eq(WorldArt.creature_key("BK_FWZ"), "world_creature_bk_fwz")
	assert_eq(WorldArt.creature_key("SFWZ"), "world_creature_sfwz", "a shadow's the same way")
	assert_eq(WorldArt.creature_key("M_CEN2"), "world_creature_m_cen2")
	assert_true(WorldArt.LAYOUT.has(WorldArt.creature_key("DG_WUG")), "every sheet has a built-in grid")
	assert_eq(WorldArt.LAYOUT[WorldArt.creature_key("S_DG")], WorldArt.LAYOUT["world_ego_m"],
		"the hero's grid")


func test_a_heading_and_a_step_pick_the_hero_s_frame() -> void:
	assert_eq(WorldArt.creature_frame(0, 0), 10, "heading 0, a creature just come, draws like north-west")
	assert_eq(WorldArt.creature_frame(6, 0), 0)
	assert_eq(WorldArt.creature_frame(7, 4), 9)
	assert_eq(WorldArt.creature_frame(5, 2), 37)
	assert_eq(WorldArt.creature_frame(3, 9), 29, "a step past the fifth is the fifth")


func test_a_frame_is_cut_on_the_built_in_grid_without_its_sidecar() -> void:
	GameSkin._meta_cache[BODY] = {}
	var art := WorldArt.new()
	assert_eq(art.creature_rect(BODY, 0), Rect2(0, 0, 154, 108))
	assert_eq(art.creature_rect(BODY, 7), Rect2(308, 108, 154, 108), "row 1, column 2")
	assert_eq(art.creature_rect(BODY, 39), Rect2(616, 756, 154, 108), "the last frame")
	assert_eq(art.creature_rect(BODY, 45), art.creature_rect(BODY, 39), "no frame past the 40th")
	assert_eq(art.creature_rect(BODY, -3), art.creature_rect(BODY, 0))


func test_the_anchor_is_frame_0_s_top_clip() -> void:
	GameSkin._meta_cache[BODY] = _sidecar(73)
	var art := WorldArt.new()
	assert_eq(art.creature_top(BODY), 73, "the knight's anchor, though frames 1-39 carry -1")
	assert_eq(art.creature_anchor(BODY), Vector2(77, 73), "half the frame across, the anchor up")
	assert_eq(art.creature_rect(BODY, 39), Rect2(616, 756, 154, 108), "the sidecar's grid")


func test_a_clip_taller_than_the_frame_is_two_thirds_of_it() -> void:
	# 1.3 world_lair_monster_slots.c:262-267.
	GameSkin._meta_cache[BODY] = _sidecar(200)
	assert_eq(WorldArt.new().creature_top(BODY), 72)


func test_without_a_sidecar_the_anchor_is_the_hero_s() -> void:
	GameSkin._meta_cache[BODY] = {}
	assert_eq(WorldArt.new().creature_top(BODY), WorldArt.CREATURE_TOP)
	GameSkin._meta_cache[BODY] = _sidecar(-1)
	assert_eq(WorldArt.new().creature_top(BODY), 61, "no anchor in the file either")


func test_a_creature_s_picture_by_its_table_row() -> void:
	GameSkin._meta_cache[THUMBS] = {}
	var art := WorldArt.new()
	assert_eq(art.thumb_rect(1), Rect2(0, 0, 80, 64), "the Witch, row 1, cell 0")
	assert_eq(art.thumb_rect(9), Rect2(0, 64, 80, 64), "the Priestess, the second row's first")
	assert_eq(art.thumb_rect(55), Rect2(480, 384, 80, 64), "Arzakon, cell 54")
	assert_eq(art.thumb_rect(0), art.thumb_rect(1), "no cell before the first")
