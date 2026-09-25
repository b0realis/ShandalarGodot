extends GutTest
## Original Portal: trusted independent rules, with reprints sharing identity.

func after_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func test_portal_alone_and_alongside_every_previous_pack() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	assert_false(CardRegistry.has_card("Alabaster Dragon"))
	assert_true(CardPacks.set_enabled("pack-6", true))
	assert_eq(CardRegistry.names_in_set("por").size(), 200)
	assert_eq(CardRegistry.size(), 1193)
	for name in PortalPack.SHARED:
		var shared_names: Array[String] = [name]
		assert_eq(CardPacks.packs_required_by(shared_names), ["pack-6"])
	for row in PortalPack.records():
		assert_true(CardRegistry.has_card(row.name), row.name)
		var c := CardRegistry.get_card(row.name)
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", row.name)
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, true)
	assert_eq(CardRegistry.size(), 1898)
	assert_eq(CardRegistry.names_in_set("por").size(), 200)
	CardPacks.set_enabled("pack-6", false)
	assert_false(CardRegistry.has_card("Alabaster Dragon"))
	assert_true(CardRegistry.has_card("Storm Crow"))

func test_original_english_printings_and_native_keywords() -> void:
	CardPacks.set_enabled("pack-6", true)
	assert_eq(PortalPack.records().size(), 318)
	assert_eq(CardRegistry.get_card("Armored Pegasus").power, 1)
	assert_true(CardRegistry.get_card("Archangel").keywords.has(Mtg.Keyword.VIGILANCE))
	assert_true(CardRegistry.get_card("Anaconda").landwalk.has("swamp"))
	assert_true(CardRegistry.get_card("Cloak of Feathers").keywords.is_empty())
	assert_true(CardRegistry.get_card("Assassin's Blade").is_type(Mtg.CardType.INSTANT))
	assert_true(CardRegistry.get_card("Defiant Stand").is_type(Mtg.CardType.INSTANT))
