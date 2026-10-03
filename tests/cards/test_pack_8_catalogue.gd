extends GutTest
## The Mirage block (Pack 8): three sets in one pack, 621 new identities,
## and 31 shared reprints it provides when their original pack is off.
##
## The last test is the catalogue gate the card waves work towards: it
## fails while any Mirage, Visions or Weatherlight name still carries the
## dispatcher's `_pending` cast guard (cards/sets/<set>/_rules.gd).

const SETS := ["mir", "vis", "wth"]

func after_each() -> void:
	CardPacks.set_current_deck_names([])
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _is_pending(c: CardData) -> bool:
	return c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"


func test_mirage_block_alone_and_alongside_every_previous_pack() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	assert_false(CardRegistry.has_card("Bösium Strip"))
	assert_false(CardRegistry.has_card("Archangel"))
	assert_eq(CardRegistry.size(), 897)
	assert_true(CardPacks.set_enabled("pack-8", true))
	assert_eq(CardRegistry.names_in_set("mir").size(), 335)
	assert_eq(CardRegistry.names_in_set("vis").size(), 167)
	assert_eq(CardRegistry.names_in_set("wth").size(), 167)
	assert_eq(CardRegistry.extra_set_order(), ["mir", "vis", "wth"])
	# 621 new identities and the 31 shared reprints Pack 8 provides alone.
	assert_eq(MirageBlockPack.new_names().size(), 621)
	assert_eq(MirageBlockPack.shared().size(), 31)
	assert_eq(MirageBlockPack.records().size(), 669)
	assert_eq(MirageBlockPack.printings().size(), 684)
	assert_eq(CardRegistry.size(), 897 + 621 + 31)
	for row in MirageBlockPack.records():
		assert_true(CardRegistry.has_card(row.name), row.name)
		assert_true(CardRegistry.card_in_set(row.name, row.set), row.name)
	for name in MirageBlockPack.shared():
		if not CardRegistry.has_card(name): continue
		var c := CardRegistry.get_card(name)
		assert_true(SETS.has(c.set_code), "%s wears its block set alone" % name)
		assert_false(_is_pending(c), name)
		var one: Array[String] = [name]
		assert_eq(CardPacks.packs_required_by(one), ["pack-8"], name)
	# The twelve core reprints keep their core scripts and need no pack.
	assert_eq(CardRegistry.get_card("Disenchant").set_code, "2ed")
	assert_true(CardRegistry.card_in_set("Disenchant", "mir"))
	assert_eq(CardPacks.packs_required_by(["Disenchant", "Sandstorm"]), [])
	assert_eq(CardPacks.packs_required_by(["Bösium Strip", "Disenchant"]), ["pack-8"])
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, true)
	assert_eq(CardRegistry.size(), 1898 + 621)
	assert_eq(CardRegistry.names_in_set("mir").size(), 335)
	CardPacks.set_enabled("pack-8", false)
	assert_eq(CardRegistry.size(), 1898)
	assert_false(CardRegistry.has_card("Bösium Strip"))
	assert_true(CardRegistry.has_card("Archangel"))


func test_original_packs_keep_their_scripts_and_any_one_provider_suffices() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardPacks.set_enabled("pack-6", true)
	assert_eq(MirageBlockPack.shared()["Archangel"], "por")
	assert_eq(CardRegistry.get_card("Archangel").set_code, "por")
	assert_true(CardRegistry.card_in_set("Archangel", "vis"))
	assert_eq(CardPacks.packs_required_by(["Archangel"]), ["pack-6"])
	CardPacks.set_current_deck_names(["Archangel", "Bösium Strip"])
	assert_eq(CardPacks.disable_warning("pack-6"), "", "Pack 8 still provides Archangel")
	assert_string_contains(CardPacks.disable_warning("pack-8"), "Bösium Strip")
	assert_false(CardPacks.disable_warning("pack-8").contains("Archangel"))
	CardPacks.set_enabled("pack-6", false)
	assert_eq(CardRegistry.get_card("Archangel").set_code, "vis")
	assert_eq(CardPacks.packs_required_by(["Archangel"]), ["pack-8"])
	assert_string_contains(CardPacks.disable_warning("pack-8"), "Archangel")
	# A deck saved under Portal and opened with only Pack 8: the declared
	# Portal requirement is met by the provider in play.
	var declared: Array[String] = ["pack-6"]
	var names: Array[String] = ["Archangel", "Disenchant"]
	assert_eq(CardPacks.effective_requirements(declared, names), [] as Array[String])
	CardPacks.set_enabled("pack-8", false)
	assert_eq(CardPacks.packs_required_by(["Archangel"]), ["pack-6"])
	assert_false(CardRegistry.has_card("Archangel"))


func test_ice_age_names_shared_by_three_packs() -> void:
	for name in ["Flare", "Incinerate", "Ray of Command", "Dark Banishing"]:
		assert_eq(MirageBlockPack.shared().get(name, ""), "ice", name)
	CardPacks.set_enabled("pack-8", true)
	CardPacks.set_enabled("pack-7", true)
	assert_eq(CardRegistry.get_card("Flare").set_code, "5ed", "Fifth Edition walks before the block")
	assert_eq(CardPacks.packs_required_by(["Flare"]), ["pack-7"])
	CardPacks.set_enabled("pack-3", true)
	assert_eq(CardRegistry.get_card("Flare").set_code, "ice")
	assert_eq(CardPacks.packs_required_by(["Flare"]), ["pack-3"])
	CardPacks.set_enabled("pack-3", false)
	CardPacks.set_enabled("pack-7", false)
	assert_eq(CardRegistry.get_card("Flare").set_code, "mir")
	assert_eq(CardPacks.packs_required_by(["Flare", "Memory Lapse"]), ["pack-8"])


func test_pack_of_set_and_known_ids() -> void:
	for code in SETS:
		assert_eq(CardPacks.pack_of_set(code), "pack-8", code)
		assert_true(CardPacks._numbered_set(code), code)
	assert_true(CardPacks.known_ids().has("pack-8"))
	assert_eq(CardPacks.file_name_for("pack-8"), "Pack-8-Mirage-Block.zip")
	assert_eq(CardPacks.label_for("pack-8"), "Pack 8")


func test_mirage_basic_lands_offer_four_numbered_pictures() -> void:
	CardPacks.set_enabled("pack-8", true)
	for land in ["Plains", "Island", "Swamp", "Mountain", "Forest"]:
		var ids: Array = []
		for choice in CardPacks.printing_choices(land):
			if String(choice.set) == "mir": ids.append(String(choice.id))
		assert_eq(ids.size(), 4, land)
		for id in ids:
			assert_true(id.begins_with("mir:"), id)
			assert_true(DeckPrintings.valid_id(id), id)
	var archangel: Array = CardPacks.printing_choices("Archangel").filter(func(c): return c.set == "vis")
	assert_eq(archangel.size(), 1)


## Every scaffold matches the trusted snapshot it was written from: the
## exact Oracle text (Unicode included), the creature body and the types.
func test_every_new_card_file_matches_its_printed_record() -> void:
	CardPacks.set_enabled("pack-8", true)
	var additions := MirageBlockPack.new_names()
	for row in MirageBlockPack.records():
		if not additions.has(String(row.name)): continue
		var c := CardRegistry.get_card(String(row.name))
		if c == null: continue
		assert_eq(c.set_code, String(row.set), row.name)
		assert_eq(c.oracle_text, String(row.oracle_text if row.oracle_text != null else ""), row.name)
		var type_line := String(row.type_line)
		assert_eq(c.is_creature(), type_line.contains("Creature"), row.name)
		assert_eq(c.is_land(), type_line.contains("Land"), row.name)
		assert_eq(c.is_type(Mtg.CardType.ARTIFACT), type_line.contains("Artifact"), row.name)
		assert_eq(c.is_type(Mtg.CardType.ENCHANTMENT), type_line.contains("Enchantment"), row.name)
		assert_eq((c.supertypes & Mtg.Supertype.LEGENDARY) != 0, type_line.begins_with("Legendary"), row.name)
		if c.is_creature() and String(row.power).is_valid_int() and String(row.toughness).is_valid_int():
			assert_eq([c.power, c.toughness], [int(row.power), int(row.toughness)], row.name)
	assert_true(CardRegistry.get_card("Iron Tusk Elephant").keywords.has(Mtg.Keyword.TRAMPLE))
	assert_true(CardRegistry.get_card("Warthog").landwalk.has("swamp"))
	assert_eq(CardRegistry.get_card("Cerulean Wyvern").protection_from, Mtg.ManaColor.G)
	assert_true(CardRegistry.get_card("Teremko Griffin").keywords.has(Mtg.Keyword.BANDING))
	assert_ne(CardRegistry.get_card("Bazaar of Wonders").supertypes & Mtg.Supertype.WORLD, 0)
	assert_ne(CardRegistry.get_card("Teferi's Isle").supertypes & Mtg.Supertype.LEGENDARY, 0)


## The vanilla and keyword-only creatures `_basic.gd` lists are complete
## from the first day; every other name waits for its family module.
func test_basic_family_names_are_complete() -> void:
	CardPacks.set_enabled("pack-8", true)
	for name in ["Iron Tusk Elephant", "Teremko Griffin", "Phyrexian Walker", "Longbow Archer",
			"Benalish Infantry", "Razortooth Rats"]:
		assert_false(_is_pending(CardRegistry.get_card(name)), name)


## THE CATALOGUE GATE. Every published name of the three sets must have a
## completed rules handler: no `_pending` cast guard may remain. Expected
## to fail until the card-implementation waves are finished.
func test_no_mirage_block_card_is_pending() -> void:
	CardPacks.set_enabled("pack-8", true)
	var additions := MirageBlockPack.new_names()
	for code in SETS:
		var pending: Array[String] = []
		for name in CardRegistry.names_in_set(code):
			if not additions.has(name): continue
			if _is_pending(CardRegistry.get_card(name)): pending.append(name)
		assert_eq(pending, [] as Array[String],
			"%s: %d names still carry the pending rules guard" % [code, pending.size()])
