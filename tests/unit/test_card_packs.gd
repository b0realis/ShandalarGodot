extends GutTest
## Pack 1 is present in the test wrapper but starts disabled. These tests
## pin both sides of the live registry switch and the published catalog.

var _was_enabled := false


func before_all() -> void:
	_was_enabled = Settings.enabled_card_packs().has(CardPacks.ID)
	assert_true(CardPacks.has_pack(CardPacks.ID),
		"the exact Pack 1 ZIP must be available before Godot starts")


func before_each() -> void:
	CardPacks.set_enabled(CardPacks.ID, false)


func after_all() -> void:
	CardPacks.set_enabled(CardPacks.ID, _was_enabled)


func test_pack_one_reports_the_audited_counts() -> void:
	var info := CardPacks.info(CardPacks.ID)
	assert_eq(info.get("file_name"), CardPacks.FILE_NAME)
	assert_eq(info.get("version"), CardPacks.PACK_VERSION)
	assert_eq(info.get("minimum_game_version"), CardPacks.MINIMUM_GAME_VERSION)
	assert_eq(info.get("checksums", {}).get("algorithm"), "sha256")
	assert_eq(info.get("checksums", {}).get("metadata", {}).size(), 3)
	assert_eq(String(info.get("checksums", {}).get("artwork", {}) \
		.get("sha256", "")).length(), 64)
	assert_eq(int(info["counts"]["published_printings"]), 1305)
	assert_eq(int(info["counts"]["named_set_entries"]), 1270)
	assert_eq(int(info["counts"]["distinct_cards"]), 901)
	assert_eq(int(info["counts"]["pack_card_entries"]), 373)
	assert_eq(int(info["counts"]["reprint_entries"]), 369)
	assert_eq(int(info["counts"]["new_rules_identities"]), 4)


func test_disabled_is_the_unchanged_897_card_pool() -> void:
	assert_false(CardPacks.is_enabled(CardPacks.ID))
	assert_eq(CardRegistry.size(), 897)
	assert_eq(CardRegistry.named_set_entry_count(), 897)
	for name in CardPacks.ADDED_NAMES:
		assert_false(CardRegistry.has_card(name), String(name))


func test_enabled_adds_four_identities_and_every_named_set_checklist() -> void:
	assert_true(CardPacks.set_enabled(CardPacks.ID, true))
	assert_true(CardPacks.is_enabled(CardPacks.ID))
	assert_eq(CardRegistry.size(), 901)
	assert_eq(CardRegistry.named_set_entry_count(), 1270)
	assert_eq(CardRegistry.published_printing_count(), 1305)
	for name in CardPacks.ADDED_NAMES:
		assert_true(CardRegistry.has_card(name), String(name))
	assert_eq(CardRegistry.names_in_set("2ed").size(), 292)
	assert_eq(CardRegistry.names_in_set("4ed").size(), 368)
	assert_eq(CardRegistry.names_in_set("arn").size(), 78)
	assert_eq(CardRegistry.names_in_set("atq").size(), 85)
	assert_eq(CardRegistry.names_in_set("leg").size(), 310)
	assert_eq(CardRegistry.names_in_set("drk").size(), 119)
	assert_eq(CardRegistry.names_in_set("past").size(), 12)
	assert_eq(CardRegistry.names_in_set("phpr").size(), 6)


func test_cross_set_reprints_share_one_card_identity() -> void:
	CardPacks.set_enabled(CardPacks.ID, true)
	assert_true(CardRegistry.card_in_set("Disenchant", "2ed"))
	assert_true(CardRegistry.card_in_set("Disenchant", "4ed"))
	assert_eq(CardRegistry.all_names().count("Disenchant"), 1)


func test_deck_filter_finds_a_reprint_under_its_pack_set() -> void:
	CardPacks.set_enabled(CardPacks.ID, true)
	var filter := DeckFilter.new()
	for code in CardRegistry.SET_ORDER:
		if code != "4ed":
			filter.toggle_set(code)
	assert_true(filter.matches_set(CardRegistry.get_card("Disenchant")),
		"the existing rules identity appears in its Pack 1 Fourth Edition checklist")
	assert_false(filter.matches_set(CardRegistry.get_card("Ancestral Recall")),
		"a card absent from Fourth Edition stays filtered out")


func test_disable_reloads_the_base_pool_immediately() -> void:
	CardPacks.set_enabled(CardPacks.ID, true)
	assert_eq(CardRegistry.size(), 901)
	CardPacks.set_enabled(CardPacks.ID, false)
	assert_eq(CardRegistry.size(), 897)
	assert_false(CardRegistry.has_card("Chaos Orb"))
	assert_false(Settings.has_value("enabled_card_packs"),
		"disabling the final pack does not materialise an empty default")


## A ZIP THAT DECLARES MORE THAN IT HOLDS (bug pass 2026-10-03). Packs 6
## and 7 read the central directory's declared sizes before `ZIPReader`
## allocates a byte (`PortalPack._bounded_zip`); Packs 1-5 went straight
## to `read_file`, so a pack-named ZIP whose entry declared gigabytes was
## allocated whole at startup. Every pack now refuses an over-size entry
## by its directory alone — the guard's own refusal, not the file-list one
## a later check would have given.
func test_every_pack_reads_the_directory_before_any_entry() -> void:
	var dir := "user://bounded_zip_test"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var zeros := PackedByteArray()
	zeros.resize(9 * 1024 * 1024)       # past the 8 MB an entry may unpack to
	for file_name in [CardPacks.FILE_NAME, FallenEmpiresPack.FILE_NAME,
			IceAgePack.FILE_NAME, HomelandsPack.FILE_NAME, AlliancesPack.FILE_NAME,
			PortalPack.FILE_NAME, FifthEditionPack.FILE_NAME, MirageBlockPack.FILE_NAME]:
		var path := dir.path_join(file_name)
		var zip := ZIPPacker.new()
		assert_eq(zip.open(ProjectSettings.globalize_path(path)), OK)
		zip.start_file("card_packs/manifest.json")
		zip.write_file(zeros)
		zip.close_file()
		zip.close()
		var report := CardPacks.inspect(ProjectSettings.globalize_path(path))
		assert_false(bool(report.get("ok", true)), file_name)
		assert_string_contains(String(report.get("why", "")), "size limit",
			"%s: refused by the directory guard" % file_name)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))


## The bound is each layout's own entry count: the real packs, where this
## machine has them, still pass it.
func test_the_real_packs_fit_their_bounds() -> void:
	var checked := 0
	for pack in [[CardPacks.ID, CardPacks.MAX_ENTRIES],
			[FallenEmpiresPack.ID, FallenEmpiresPack.MAX_ENTRIES],
			[IceAgePack.ID, IceAgePack.MAX_ENTRIES],
			[HomelandsPack.ID, HomelandsPack.MAX_ENTRIES],
			[AlliancesPack.ID, AlliancesPack.MAX_ENTRIES]]:
		for path in CardPacks.candidate_paths(String(pack[0])):
			if FileAccess.file_exists(path):
				assert_true(PortalPack.bounded_zip(path, int(pack[1])), path)
				checked += 1
	# Pack 8 carries its own byte budget as well as its own entry count.
	for path in CardPacks.candidate_paths(MirageBlockPack.ID):
		if FileAccess.file_exists(path):
			assert_true(PortalPack.bounded_zip(path, MirageBlockPack.MAX_ENTRIES, MirageBlockPack.MAX_BYTES), path)
			checked += 1
	if checked == 0:
		pass_test("no real pack on this machine")
