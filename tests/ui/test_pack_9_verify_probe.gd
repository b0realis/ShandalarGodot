extends GutTest
## `--verify-pack-9` (game/main.gd): the Tempest block's export probe. The
## door is taken before the title screen is built, and the probe's own
## checks ([method MainScreen.pack_9_probe]) — run here against the suite's
## metadata-only Pack 9 fixture — load all 601 dormant scripts and the nine
## UI textures, count the names still carrying the `_pending` rules guard
## (one failure line while any is left), report the fixture's absent
## pictures as its only other failures, and leave the enabled-pack
## selection as it found it. The real ZIP's run (SHANDALAR_PACK_9, an
## isolated profile, `--verify-pack-9`) is the release check.

func after_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


## How many of the 574 new names carry the dispatcher's `_pending` guard
## right now — the number the probe must report, whatever stage the card
## waves have reached (0 is the catalogue gate's finish line).
func _pending_now() -> int:
	var was := CardPacks.is_enabled(TempestBlockPack.ID)
	CardPacks.set_enabled(TempestBlockPack.ID, true)
	var pending := 0
	for name in TempestBlockPack.new_names():
		var card := CardRegistry.get_card(name)
		if card != null and card.cast_condition.is_valid() and card.cast_condition.get_method() == "_pending":
			pending += 1
	CardPacks.set_enabled(TempestBlockPack.ID, was)
	return pending


func test_the_flag_is_routed_before_the_title_is_built() -> void:
	var source := FileAccess.get_file_as_string("res://game/main.gd")
	assert_true(source.contains('const VERIFY_PACK_9_FLAG := "--verify-pack-9"'))
	var route := source.find("has(VERIFY_PACK_9_FLAG)")
	assert_gt(route, -1, "the flag is routed in _ready")
	assert_lt(route, source.find('GameSkin.texture("title_background")'),
		"before anything of the title screen is built")
	assert_gt(source.find("_verify_exported_pack_9()", route), route)


func test_the_probe_passes_everything_but_the_pictures_and_pending_rules_on_the_fixture() -> void:
	assert_true(CardPacks.has_pack(TempestBlockPack.ID), "the suite's Pack 9 fixture is discovered")
	CardPacks.set_enabled("pack-6", true)
	var before := Settings.enabled_card_packs()
	var report := MainScreen.pack_9_probe()
	var counts: Dictionary = report["counts"]
	var failures: Array = report["failures"]
	assert_eq(int(counts.identities), MainScreen.PACK_9_POOL, "Pack 9 alone, in memory")
	assert_eq(int(counts.scripts), MainScreen.PACK_9_SCRIPTS, "574 new names and 27 shared reprints")
	assert_eq(int(counts.textures), 9, "three set glyphs and six Extras medallions")
	assert_eq(Settings.enabled_card_packs(), before, "the selection is restored")
	assert_true(CardPacks.is_enabled("pack-6"))
	assert_false(CardPacks.is_enabled(TempestBlockPack.ID))
	var pending := _pending_now()
	assert_eq(int(counts.pending), pending, "the probe counts what the registry holds")
	var pending_lines := failures.filter(func(why) -> bool: return String(why).begins_with("rules pending:"))
	assert_eq(pending_lines.size(), 1 if pending > 0 else 0, "one line for every pending name, or none")
	var other: Array = failures.filter(func(why) -> bool: return not String(why).begins_with("rules pending:"))
	if int(counts.art) == MainScreen.PACK_9_ART:
		assert_eq(other, [], "a developer's real ZIP passes whole")
	else:
		assert_eq(int(counts.art), 0, "the fixture carries no pictures")
		assert_between(other.size(), 1, 2)
		for why in other:
			assert_true(String(why).begins_with("artwork:") \
				or String(why).begins_with("skin/cardart fallbacks:"), String(why))
