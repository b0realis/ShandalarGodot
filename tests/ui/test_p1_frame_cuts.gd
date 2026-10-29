extends GutTest
## THE FRAMES' PIECES CUT CLEAN (the polish pass, 2026-10-28; the owner's
## polish list, item 7): a 1-px purple line stood at the right end of the
## "Your Ante" plaque, with the 1997 skin and the 2x one alike —
## `preduel_frame`'s magenta key column (x = 129, just right of the hero's
## plaque, 1..128) taken in at the edge of the piece drawn scaled and
## filtered. Every piece of the two frame sheets is now clipped to its
## region ([method EncounterStage.cut_of]): the meeting's and the room's
## stage, the clues' small faces, the ruled town's face over its picture.
## A stand-in sheet of the key colour: the code path, not the picture (the
## headless renderer draws nothing to read back; the screenshots of the
## polish pass show the plaque).

## The caches swapped for a test, put back after it.
var _swapped: Array = []


func after_each() -> void:
	for swap in _swapped:
		var cache: Dictionary = swap["cache"]
		if swap["had"]:
			cache[swap["key"]] = swap["value"]
		else:
			cache.erase(swap["key"])
	_swapped.clear()


func _swap(cache: Dictionary, key: String, value: Variant) -> void:
	_swapped.append({"cache": cache, "key": key, "had": cache.has(key), "value": cache.get(key)})
	cache[key] = value


## A frame sheet of 1997's size, all of it the magenta key.
func _sheet() -> Texture2D:
	var img := Image.create(640, 480, false, Image.FORMAT_RGBA8)
	img.fill(Color8(207, 57, 215))
	return ImageTexture.create_from_image(img)


## [param part] is a piece of the sheet clipped to its region.
func _clipped(part: Node, why: String) -> void:
	var shown := part as TextureRect
	assert_not_null(shown, why + ": a piece of the sheet")
	if shown == null:
		return
	var cut := shown.texture as AtlasTexture
	assert_not_null(cut, why + ": cut from the sheet")
	if cut == null:
		return
	assert_true(cut.filter_clip, why + ": clipped to its region, no key line taken in at its edge")


func test_the_meeting_s_plaques_and_frame_are_cut_clean() -> void:
	_swap(GameSkin._texture_cache, "preduel_frame", _sheet())
	var stage := EncounterStage.new()
	add_child_autofree(stage)
	stage.ante_plaques()
	stage.creature_face(1)
	var hero := stage.part("HeroPlaque") as TextureRect
	_clipped(hero, "Your Ante")
	if hero != null and hero.texture is AtlasTexture:
		assert_eq((hero.texture as AtlasTexture).region, EncounterStage.HERO_PLAQUE,
			"the plaque itself, 1..128 across: the cut is not moved, only clipped")
	for part_name in ["CreaturePlaque", "FaceFrame", "NameBanner"]:
		_clipped(stage.part(part_name), part_name)


func test_the_clues_small_face_is_cut_clean() -> void:
	_swap(GameSkin._texture_cache, "preduel_frame", _sheet())
	var page := CluesPane.CluePage.new()
	add_child_autofree(page)
	page.small_face(1, Rect2(10, 10, 60, 60), "Small")
	_clipped(page.part("SmallFrame"), "the clue page's small frame")


func test_a_ruled_town_s_face_frame_is_cut_clean() -> void:
	_swap(GameSkin._texture_cache, "preduel_frame_tinted", _sheet())
	var pane := VisitPane.new()
	pane.place = {"kind": "village", "name": "Nowhere", "subtitle": "Village", "picture": "",
		"lines": [], "actions": [["leave", "Leave the village", true]]}
	add_child_autofree(pane)
	await get_tree().process_frame
	pane.show_face(1)
	_clipped(pane.find_child("FaceFrame", true, false), "the tinted frame (Prdfrmc.pic)")
	_clipped(pane.find_child("FaceBanner", true, false), "the tinted banner")
