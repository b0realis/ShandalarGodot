extends GutTest
## A PACK REQUIREMENT MUST NOT OUTLIVE THE LAST CARD THAT NEEDED IT
## (whole-game campaign 2026-10, w7-6).
##
## Build a deck with one Mirage card (Pack 8 on) and save it: the file says
## `# requires-pack: pack-8`. Open it again, take the Mirage card out and
## save: the file STILL said it — [method DeckModel.required_pack_ids]
## re-derived the packs the cards imply and then carried every declared id
## forward — and with Pack 8 off the battle setup screen refused a deck of
## nothing but core cards ("needs Pack 8"). A save now keeps a declared id
## this build knows only while a card in the deck still needs it
## ([method CardPacks.requirements_to_save]); an id it does not know is
## kept as written. What the gates do with a line a file declares is
## unchanged (2026-09-17: the setup screen honours it as written).

const NAME := "Campaign Stale Pack Deck"
const STALE := "user://decks/campaign_fix_persist_stale.deck"
var _was: Array[String] = []


func before_each() -> void:
	_was = Settings.enabled_card_packs()


func after_each() -> void:
	for path in [DeckStore.path_for(NAME), STALE]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Settings.set_enabled_card_packs(_was)
	CardPacks._configure_registry()
	CardRegistry.ensure_loaded()


func _only_enabled(ids: Array) -> void:
	var wanted: Array[String] = []
	for id in CardPacks.available_ids():
		if ids.has(id): wanted.append(id)
	Settings.set_enabled_card_packs(wanted)
	CardPacks._configure_registry()
	CardRegistry.ensure_loaded()


func _mirage_card() -> String:
	for n in MirageBlockPack.new_names():
		return n
	return ""


func _core_model(declared: Array[String]) -> DeckModel:
	var model := DeckModel.new()
	model.deck_name = NAME
	model.counts = {"Forest": 20, "Grizzly Bears": 4, "Giant Spider": 4,
		"War Mammoth": 4, "Craw Wurm": 4, "Durkwood Boars": 4}
	model.required_packs = declared
	return model


func test_a_save_drops_a_known_pack_no_card_in_the_deck_needs() -> void:
	for pack_on in [true, false]:
		_only_enabled([MirageBlockPack.ID] if pack_on else [])
		var model := _core_model([MirageBlockPack.ID] as Array[String])
		assert_eq(model.required_pack_ids(), [] as Array[String],
			"Pack 8 %s: no Mirage card left, no Pack 8" % ("on" if pack_on else "off"))
		assert_false(model.to_text().contains("# requires-pack:"), model.to_text())
		# One Mirage card in either pile keeps it.
		var mirage := _mirage_card()
		model.sideboard[mirage] = 1
		assert_eq(model.required_pack_ids(), [MirageBlockPack.ID] as Array[String],
			"a sideboard %s still needs Pack 8" % mirage)
		model.sideboard.erase(mirage)
		model.counts[mirage] = 1
		assert_eq(model.required_pack_ids(), [MirageBlockPack.ID] as Array[String])


func test_an_unknown_pack_id_is_kept_as_written() -> void:
	_only_enabled([])
	# A deck from a newer build names a pack this one does not know; its
	# cards are proxies here, and "needs Pack 99" is the better refusal.
	var model := _core_model(["pack-99", MirageBlockPack.ID] as Array[String])
	assert_eq(model.required_pack_ids(), ["pack-99"] as Array[String])
	assert_string_contains(model.to_text(), "# requires-pack: pack-99")


func test_pack_one_is_judged_by_its_four_cards_on_a_save() -> void:
	_only_enabled([])
	var model := _core_model([CardPacks.ID] as Array[String])
	assert_eq(model.required_pack_ids(), [] as Array[String],
		"no Chaos Orb, Word of Command, Shahrazad or Falling Star left")
	model.counts["Chaos Orb"] = 1
	assert_eq(model.required_pack_ids(), [CardPacks.ID] as Array[String])


func test_the_shared_reprint_rule_still_names_the_provider_in_play() -> void:
	# The bug pass of 2026-10-03 rule, unchanged: Pyroclasm declared under
	# Ice Age and saved with only Portal on names Portal.
	_only_enabled([PortalPack.ID])
	var model := DeckModel.new()
	model.deck_name = "Burn"
	model.counts = {"Pyroclasm": 4, "Mountain": 36}
	model.required_packs.assign([IceAgePack.ID])
	assert_eq(model.required_pack_ids(), [PortalPack.ID] as Array[String])
	_only_enabled([])
	assert_eq(model.required_pack_ids(), [IceAgePack.ID] as Array[String],
		"no other provider on: the declared original stands")


func test_removing_the_last_pack_card_frees_the_saved_deck() -> void:
	assert_true(CardPacks.set_enabled(MirageBlockPack.ID, true), "Pack 8 available to the suite")
	var mirage := ""
	for n in MirageBlockPack.new_names():
		if CardRegistry.has_card(n) and not CardRegistry.get_card(n).is_land():
			mirage = n
			break
	var model := _core_model([] as Array[String])
	assert_eq(model.add(mirage), "")
	assert_eq(DeckStore.save(model), "")
	var path := DeckStore.path_for(NAME)
	assert_string_contains(DeckStore.read_text(path), "# requires-pack: pack-8", "declared")
	var loaded := DeckStore.load_deck(path, [])
	assert_not_null(loaded)
	if loaded == null: return
	assert_eq(loaded.required_packs, [MirageBlockPack.ID] as Array[String], "read back from the file")
	assert_eq(loaded.remove(mirage), "")
	assert_eq(DeckStore.save(loaded), "")
	assert_false(DeckStore.read_text(path).contains("# requires-pack:"), DeckStore.read_text(path))
	CardPacks.set_enabled(MirageBlockPack.ID, false)
	var fresh: SetupScreen = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(fresh)
	await get_tree().process_frame
	assert_false(fresh._pack_paths.has(path), "not marked 'needs Pack 8'")
	assert_true(fresh._playable_paths.has(path), "a core deck plays with Pack 8 off")


## A file ALREADY written with the stale line (any build before this fix)
## opens in the Deck Builder without the pack question — nothing in it
## needs the pack — and its next save writes the line no more.
func test_a_deck_already_saved_stale_opens_and_saves_clean() -> void:
	_only_enabled([])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DeckStore.USER_DIR))
	var file := FileAccess.open(STALE, FileAccess.WRITE)
	file.store_string("# requires-pack: pack-8\nname: Stale Core\n36 Forest\n4 Grizzly Bears\n")
	file.close()
	var builder: DeckBuilderScreen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(builder)
	await get_tree().process_frame
	builder._load_deck(STALE)
	await get_tree().process_frame
	assert_false(is_instance_valid(builder._pack_requirement_notice), "no pack to ask for")
	assert_eq(builder.deck.deck_name, "Stale Core", "the deck opened")
	assert_false(builder.deck.to_text().contains("# requires-pack:"), builder.deck.to_text())
