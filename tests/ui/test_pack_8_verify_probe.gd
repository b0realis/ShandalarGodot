extends GutTest
## `--verify-pack-8` (game/main.gd): the Mirage block's export probe. The
## door is taken before the title screen is built, and the probe's own
## checks ([method MainScreen.pack_8_probe]) — run here against the suite's
## metadata-only Pack 8 fixture — load all 652 dormant scripts, find no
## pending rules, the nine UI textures, the payment modes (Fireblast's
## alternative row and a flash-rider Aura's cleanup sacrifice, executed) and
## the AI metadata, report the fixture's absent pictures as its ONLY
## failures, and leave the enabled-pack selection as it found it. The real
## ZIP's run is the release check (docs/pack-8-mirage-block.md).

func after_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func test_the_flag_is_routed_before_the_title_is_built() -> void:
	var source := FileAccess.get_file_as_string("res://game/main.gd")
	assert_true(source.contains('const VERIFY_PACK_8_FLAG := "--verify-pack-8"'))
	var route := source.find("has(VERIFY_PACK_8_FLAG)")
	assert_gt(route, -1, "the flag is routed in _ready")
	assert_lt(route, source.find('GameSkin.texture("title_background")'),
		"before anything of the title screen is built")
	assert_gt(source.find("_verify_exported_pack_8()", route), route)


func test_the_probe_passes_everything_but_the_pictures_on_the_fixture() -> void:
	assert_true(CardPacks.has_pack(MirageBlockPack.ID), "the suite's Pack 8 fixture is discovered")
	CardPacks.set_enabled("pack-6", true)
	var before := Settings.enabled_card_packs()
	var report := MainScreen.pack_8_probe()
	var counts: Dictionary = report["counts"]
	var failures: Array = report["failures"]
	assert_eq(int(counts.identities), MainScreen.PACK_8_POOL, "Pack 8 alone, in memory")
	assert_eq(int(counts.scripts), MainScreen.PACK_8_SCRIPTS, "621 new names and 31 shared reprints")
	assert_eq(int(counts.pending), 0, "no `_pending` cast guard left")
	assert_eq(int(counts.textures), 9, "three set glyphs and six Extras medallions")
	assert_eq(int(counts.payment), 5, "four loaded payment shapes and the executed probe")
	assert_eq(int(counts.ai), 5)
	if int(counts.art) == MainScreen.PACK_8_ART:
		assert_eq(failures, [], "a developer's real ZIP passes whole")
	else:
		assert_eq(int(counts.art), 0, "the fixture carries no pictures")
		assert_between(failures.size(), 1, 2)
		for why in failures:
			assert_true(String(why).begins_with("artwork:") \
				or String(why).begins_with("skin/cardart fallbacks:"), String(why))
	assert_eq(Settings.enabled_card_packs(), before, "the selection is restored")
	assert_true(CardPacks.is_enabled("pack-6"))
	assert_false(CardPacks.is_enabled(MirageBlockPack.ID))


func test_the_payment_probe_plays_fireblast_and_the_flash_rider() -> void:
	CardPacks.set_enabled(MirageBlockPack.ID, true)
	assert_eq(MainScreen._pack_8_play_probe(), "")
