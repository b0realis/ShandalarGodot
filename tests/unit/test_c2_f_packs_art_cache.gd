extends GutTest
## THE CARD PACKS' PICTURES ARE KEPT WITHIN A BOUND (robustness campaign of
## 2026-10-12, r5-1). [method GameSkin.card_art] keeps at most
## [constant GameSkin.ART_CACHE_CAP] pictures, least-recently-used first
## out, since a full browse of the Deck Builder once held 909 MB. A card
## pack's pictures go through another door, [method CardPacks.art_texture]
## (the Deck Builder's grid, the table's small cards, the preview, the
## printing chooser), and that door kept every picture it ever decoded —
## crops with their mipmaps and full-card scans alike — until a rescan: a
## long browse with packs on took a gigabyte, a crash on a 1 GB handheld.
## What these pin, through the real door with a small Pack 9 of tiny
## pictures mounted for the purpose:
##
##   1. More pictures than the bound are decoded; no more than the bound
##      are kept.
##   2. Least recently USED goes first: a picture asked for again stays.
##   3. Full-card scans count against the same bound.
##   4. Switching a pack off lets its pictures go.

const SCRATCH := "user://c2_f_packs_art_cache"
const ZIP := SCRATCH + "/pack9_tiny_art.zip"

var _report: Dictionary = {}
var _enabled: Array[String] = []
## [name, set] pairs whose pictures the tiny zip carries.
var _pairs: Array = []


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH))
	_enabled = Settings.enabled_card_packs()
	_report = CardPacks._available.get(TempestBlockPack.ID, {})
	if _report.is_empty():
		return
	var seen := {}
	for row in _report.get("cards", []):
		var key := String(row.set) + "|" + String(row.name)
		if seen.has(key):
			continue
		seen[key] = true
		_pairs.append([String(row.name), String(row.set)])
		if _pairs.size() >= GameSkin.ART_CACHE_CAP + 40:
			break
	var picture := Image.create(8, 8, false, Image.FORMAT_RGB8)
	picture.fill(Color(0.3, 0.5, 0.7))
	var jpg := picture.save_jpg_to_buffer()
	var packer := ZIPPacker.new()
	assert_eq(packer.open(ProjectSettings.globalize_path(ZIP)), OK)
	for pair in _pairs:
		for suffix in [".jpg", "_card.jpg"]:
			packer.start_file("%sart/%s/%s%s" % [TempestBlockPack.PREFIX, pair[1],
				CardPacks._snake(pair[0]), suffix])
			packer.write_file(jpg)
			packer.close_file()
	packer.close()
	# For the life of the process, as every mount is: the paths are Pack 9's
	# own, and only a report that says the pack has pictures ever asks there.
	assert_true(ProjectSettings.load_resource_pack(ProjectSettings.globalize_path(ZIP), false))
	var with_art := _report.duplicate()
	with_art["has_art"] = true
	CardPacks._available[TempestBlockPack.ID] = with_art


func after_all() -> void:
	if not _report.is_empty():
		CardPacks._available[TempestBlockPack.ID] = _report
	Settings.set_enabled_card_packs(_enabled)
	CardPacks._configure_registry()
	CardRegistry.ensure_loaded()
	CardPacks._art_cache.clear()
	if FileAccess.file_exists(ZIP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ZIP))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))


func before_each() -> void:
	CardPacks._art_cache.clear()
	if CardPacks.has_pack(TempestBlockPack.ID) and not CardPacks.is_enabled(TempestBlockPack.ID):
		CardPacks.set_enabled(TempestBlockPack.ID, true)


func _ready_or_skip() -> bool:
	assert_false(_report.is_empty(), "the wrapper's metadata-only Pack 9")
	if _report.is_empty() or not CardPacks.is_enabled(TempestBlockPack.ID):
		return false
	# Only the pairs the pack really answers for (a validated catalogue row).
	_pairs = _pairs.filter(func(pair: Array) -> bool:
		return CardPacks.art_path(pair[0], pair[1]) != "")
	assert_gt(_pairs.size(), GameSkin.ART_CACHE_CAP + 1, "enough pictures to pass the bound")
	return _pairs.size() > GameSkin.ART_CACHE_CAP + 1


# 1. The bound.

func test_more_pictures_than_the_bound_are_decoded_and_no_more_are_kept() -> void:
	if not _ready_or_skip():
		return
	var decoded := 0
	for pair in _pairs:
		if CardPacks.art_texture(pair[0], pair[1]) != null:
			decoded += 1
	assert_gt(decoded, GameSkin.ART_CACHE_CAP, "the browse decoded more than the bound")
	assert_eq(CardPacks._art_cache.size(), GameSkin.ART_CACHE_CAP,
		"and kept exactly the bound, like GameSkin.card_art")


# 2. Least recently used.

func test_a_picture_asked_for_again_stays_and_the_oldest_goes() -> void:
	if not _ready_or_skip():
		return
	var first: Texture2D = CardPacks.art_texture(_pairs[0][0], _pairs[0][1])
	var second: Texture2D = CardPacks.art_texture(_pairs[1][0], _pairs[1][1])
	assert_not_null(first)
	assert_not_null(second)
	for i in range(2, GameSkin.ART_CACHE_CAP):
		CardPacks.art_texture(_pairs[i][0], _pairs[i][1])
	assert_eq(CardPacks._art_cache.size(), GameSkin.ART_CACHE_CAP, "full, nothing dropped yet")
	assert_same(CardPacks.art_texture(_pairs[0][0], _pairs[0][1]), first,
		"asked for again: the same texture, from the cache")
	CardPacks.art_texture(_pairs[GameSkin.ART_CACHE_CAP][0], _pairs[GameSkin.ART_CACHE_CAP][1])
	assert_eq(CardPacks._art_cache.size(), GameSkin.ART_CACHE_CAP)
	assert_true(CardPacks._art_cache.values().has(first), "the one asked for again stays")
	assert_false(CardPacks._art_cache.values().has(second), "the least recently used went")


# 3. Full-card scans.

func test_full_card_scans_count_against_the_same_bound() -> void:
	if not _ready_or_skip():
		return
	var decoded := 0
	for pair in _pairs:
		if CardPacks.art_texture(pair[0], pair[1], true) != null:
			decoded += 1
		CardPacks.art_texture(pair[0], pair[1])
	assert_gt(decoded, GameSkin.ART_CACHE_CAP / 2)
	assert_eq(CardPacks._art_cache.size(), GameSkin.ART_CACHE_CAP,
		"crops and scans together within the one bound")


# 4. Switched off.

func test_switching_the_pack_off_lets_its_pictures_go() -> void:
	if not _ready_or_skip():
		return
	for i in 10:
		CardPacks.art_texture(_pairs[i][0], _pairs[i][1])
	assert_eq(CardPacks._art_cache.size(), 10)
	CardPacks.set_enabled(TempestBlockPack.ID, false)
	assert_eq(CardPacks._art_cache.size(), 0, "nothing is kept for a pack that is off")
	assert_null(CardPacks.art_texture(_pairs[0][0], _pairs[0][1]), "and nothing is drawn from it")
