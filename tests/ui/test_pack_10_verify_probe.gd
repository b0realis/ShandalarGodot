extends GutTest
## `--verify-pack-10` (game/main.gd): the Urza block's export probe. The
## door is taken before the title screen is built, and the probe's own
## checks ([method MainScreen.pack_10_probe]) — run here against the suite's
## metadata-only Pack 10 fixture — load all 609 dormant scripts and the nine
## UI textures, count the names still carrying the `_pending` rules guard
## (one failure line while any is left), report the fixture's absent
## pictures as its only other failures, and leave the enabled-pack
## selection as it found it. The real ZIP's run (SHANDALAR_PACK_10, an
## isolated profile, `--verify-pack-10`) is the release check.

func after_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


## How many of the 591 new names carry the dispatcher's `_pending` guard
## right now — the number the probe must report, whatever stage the card
## waves have reached (0 is the catalogue gate's finish line).
func _pending_now() -> int:
	var was := CardPacks.is_enabled(UrzaBlockPack.ID)
	CardPacks.set_enabled(UrzaBlockPack.ID, true)
	var pending := 0
	for name in UrzaBlockPack.new_names():
		var card := CardRegistry.get_card(name)
		if card != null and card.cast_condition.is_valid() and card.cast_condition.get_method() == "_pending":
			pending += 1
	CardPacks.set_enabled(UrzaBlockPack.ID, was)
	return pending


func test_the_flag_is_routed_before_the_title_is_built() -> void:
	var source := FileAccess.get_file_as_string("res://game/main.gd")
	assert_true(source.contains('const VERIFY_PACK_10_FLAG := "--verify-pack-10"'))
	var route := source.find("has(VERIFY_PACK_10_FLAG)")
	assert_gt(route, -1, "the flag is routed in _ready")
	assert_lt(route, source.find('GameSkin.texture("title_background")'),
		"before anything of the title screen is built")
	assert_gt(source.find("_verify_exported_pack_10()", route), route)


func test_the_probe_passes_everything_but_the_pictures_and_pending_rules_on_the_fixture() -> void:
	assert_true(CardPacks.has_pack(UrzaBlockPack.ID), "the suite's Pack 10 fixture is discovered")
	CardPacks.set_enabled("pack-6", true)
	var before := Settings.enabled_card_packs()
	var report := MainScreen.pack_10_probe()
	var counts: Dictionary = report["counts"]
	var failures: Array = report["failures"]
	assert_eq(int(counts.identities), MainScreen.PACK_10_POOL, "Pack 10 alone, in memory")
	assert_eq(int(counts.scripts), MainScreen.PACK_10_SCRIPTS, "591 new names and 18 shared reprints")
	assert_eq(int(counts.textures), 9, "three set glyphs and six Extras medallions")
	assert_eq(Settings.enabled_card_packs(), before, "the selection is restored")
	assert_true(CardPacks.is_enabled("pack-6"))
	assert_false(CardPacks.is_enabled(UrzaBlockPack.ID))
	var pending := _pending_now()
	assert_eq(int(counts.pending), pending, "the probe counts what the registry holds")
	var pending_lines := failures.filter(func(why) -> bool: return String(why).begins_with("rules pending:"))
	assert_eq(pending_lines.size(), 1 if pending > 0 else 0, "one line for every pending name, or none")
	var other: Array = failures.filter(func(why) -> bool: return not String(why).begins_with("rules pending:"))
	if int(counts.art) == MainScreen.PACK_10_ART:
		assert_eq(other, [], "a developer's real ZIP passes whole")
	else:
		assert_eq(int(counts.art), 0, "the fixture carries no pictures")
		assert_between(other.size(), 1, 2)
		for why in other:
			assert_true(String(why).begins_with("artwork:") \
				or String(why).begins_with("skin/cardart fallbacks:"), String(why))


## THE FIRST TWO-DIGIT PACK (2026-11-06): `--verify-pack-10` and
## `--verify-pack-1` are two doors. The routes compare whole arguments
## (`has`), so the one is never read as the other, and the launch help
## names 10 as one number, after 9.
func test_pack_10_and_pack_1_are_two_flags() -> void:
	var args := PackedStringArray(["--verify-pack-10"])
	assert_true(args.has(MainScreen.VERIFY_PACK_10_FLAG))
	assert_false(args.has(MainScreen.VERIFY_PACK_1_FLAG), "pack 10 is not pack 1")
	assert_eq(MainScreen.VERIFY_PACK_FLAGS.back(), MainScreen.VERIFY_PACK_10_FLAG, "the newest pack is last")
	assert_true(LaunchHelp.TOOL_FLAGS.has("--verify-pack-10"))
	assert_false(LaunchHelp.asked(args), "the probe's switch is a tool's, not a request for the help")
	var text := MainScreen.launch_help("0.0.0")
	assert_string_contains(text, "1,2,3,4,5,8,9,10")
