extends GutTest
## The Urza block (Pack 10): three sets in one pack, 591 new identities,
## and 18 shared reprints it provides when their original pack is off.
##
## The last test is the catalogue gate the card waves work towards: it
## fails while any Urza's Saga, Urza's Legacy or Urza's Destiny name still
## carries the dispatcher's `_pending` cast guard (cards/sets/<set>/_rules.gd).

const SETS := ["usg", "ulg", "uds"]
## The family modules every set's dispatcher asks, in this order.
const MODULES: Array[String] = ["_basic", "_spells", "_creatures", "_auras", "_enchantments",
	"_opal", "_artifacts", "_lands_mana", "_combat", "_triggers", "_choices", "_costs", "_echo",
	"_cycling", "_untap", "_misc"]
const PENDING := "Urza block rules integration is not yet complete for this card"
## The vanilla and keyword-only creatures `_basic.gd` claims, set by set.
const BASIC := {
	"usg": ["Argothian Swine", "Blanchwood Treefolk", "Coral Merfolk", "Crazed Skirge",
		"Goblin Spelunkers", "Guma", "Pegasus Charger", "Serra Zealot", "Thundering Giant",
		"Voice of Grace", "Voice of Law"],
	"ulg": ["Defender of Chaos", "Defender of Law", "Giant Cockroach", "Plague Beetle",
		"Weatherseed Faeries", "Yavimaya Wurm"],
	"uds": ["Goblin Berserker", "Goliath Beetle", "Plated Spider", "Squirming Mass",
		"Tormented Angel", "Voice of Duty", "Voice of Reason", "Wild Colos"],
}

func after_each() -> void:
	CardPacks.set_current_deck_names([])
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _is_pending(c: CardData) -> bool:
	return c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"


func test_urza_block_alone_and_alongside_every_previous_pack() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	assert_false(CardRegistry.has_card("Gaea's Cradle"))
	assert_false(CardRegistry.has_card("Pacifism"))
	assert_eq(CardRegistry.size(), 897)
	assert_true(CardPacks.set_enabled("pack-10", true))
	assert_eq(CardRegistry.names_in_set("usg").size(), 335)
	assert_eq(CardRegistry.names_in_set("ulg").size(), 143)
	assert_eq(CardRegistry.names_in_set("uds").size(), 143)
	# The catalogue's sets arrive key-sorted, as the earlier blocks' do.
	assert_eq(CardRegistry.extra_set_order(), ["uds", "ulg", "usg"])
	# 591 new identities and the 18 shared reprints Pack 10 provides alone.
	assert_eq(UrzaBlockPack.new_names().size(), 591)
	assert_eq(UrzaBlockPack.shared().size(), 18)
	assert_eq(UrzaBlockPack.records().size(), 621)
	assert_eq(UrzaBlockPack.printings().size(), 636)
	assert_eq(UrzaBlockPack.scripts().size(), 609)
	assert_eq(CardRegistry.size(), 897 + 591 + 18)
	assert_eq(CardRegistry.named_set_entry_count(), 897 + 621, "the title's set entries with Pack 10 alone")
	# Every published name has a script and a provider: the registry knows
	# it, in the set that printed it.
	for row in UrzaBlockPack.records():
		assert_true(CardRegistry.has_card(row.name), row.name)
		assert_true(CardRegistry.card_in_set(row.name, row.set), row.name)
	for name in UrzaBlockPack.shared():
		if not CardRegistry.has_card(name): continue
		var c := CardRegistry.get_card(name)
		assert_true(SETS.has(c.set_code), "%s wears its block set alone" % name)
		assert_false(_is_pending(c), name)
		var one: Array[String] = [name]
		assert_eq(CardPacks.packs_required_by(one), ["pack-10"], name)
	# The seven core reprints keep their core scripts and need no pack.
	assert_eq(CardRegistry.get_card("Dark Ritual").set_code, "2ed")
	assert_true(CardRegistry.card_in_set("Dark Ritual", "usg"))
	assert_eq(CardPacks.packs_required_by(["Dark Ritual", "Presence of the Master"]), [])
	assert_eq(CardPacks.packs_required_by(["Gaea's Cradle", "Dark Ritual"]), ["pack-10"])
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, true)
	assert_eq(CardRegistry.size(), 3093 + 591)   # Packs 1-9, and the Urza block's 591
	assert_eq(CardRegistry.names_in_set("usg").size(), 335)
	CardPacks.set_enabled("pack-10", false)
	assert_eq(CardRegistry.size(), 3093)
	assert_false(CardRegistry.has_card("Gaea's Cradle"))
	assert_true(CardRegistry.has_card("Pacifism"))


## No new identity registers without Pack 10, whatever else is on: every
## other pack enabled, not one of the 591 names is in the pool.
func test_no_new_name_registers_without_pack_ten() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, id != "pack-10")
	assert_false(CardPacks.is_enabled("pack-10"))
	var found: Array[String] = []
	for name in UrzaBlockPack.new_names():
		if CardRegistry.has_card(name): found.append(name)
	assert_eq(found, [] as Array[String])
	for code in SETS:
		assert_eq(CardRegistry.names_in_set(code).size(), 0, code)
	CardPacks.set_enabled("pack-10", true)
	for name in UrzaBlockPack.new_names():
		if not CardRegistry.has_card(name): found.append(name)
	assert_eq(found, [] as Array[String], "every one registers with Pack 10 on")


func test_original_packs_keep_their_scripts_and_any_one_provider_suffices() -> void:
	CardPacks.set_enabled("pack-10", true)
	CardPacks.set_enabled("pack-6", true)
	# A Portal card the Urza block reprints: Portal is its original pack,
	# and its script and symbol win while both are on.
	assert_eq(UrzaBlockPack.shared()["Lava Axe"], "por")
	assert_eq(CardRegistry.get_card("Lava Axe").set_code, "por")
	assert_true(CardRegistry.card_in_set("Lava Axe", "ulg"))
	assert_eq(CardPacks.packs_required_by(["Lava Axe"]), ["pack-6"])
	CardPacks.set_current_deck_names(["Lava Axe", "Gaea's Cradle"])
	assert_eq(CardPacks.disable_warning("pack-6"), "", "Pack 10 still provides Lava Axe")
	assert_string_contains(CardPacks.disable_warning("pack-10"), "Gaea's Cradle")
	assert_false(CardPacks.disable_warning("pack-10").contains("Lava Axe"))
	CardPacks.set_enabled("pack-6", false)
	assert_eq(CardRegistry.get_card("Lava Axe").set_code, "ulg")
	assert_eq(CardPacks.packs_required_by(["Lava Axe"]), ["pack-10"])
	assert_string_contains(CardPacks.disable_warning("pack-10"), "Lava Axe")
	# A deck saved under Portal and opened with only Pack 10: the declared
	# Pack 6 requirement is met by the provider in play.
	var declared: Array[String] = ["pack-6"]
	var names: Array[String] = ["Lava Axe", "Dark Ritual"]
	assert_eq(CardPacks.effective_requirements(declared, names), [] as Array[String])
	CardPacks.set_enabled("pack-10", false)
	assert_eq(CardPacks.packs_required_by(["Lava Axe"]), ["pack-6"])
	assert_false(CardRegistry.has_card("Lava Axe"))


## The providers do not depend on the order the packs were switched on:
## the registry walks the packs in number order every time.
func test_providers_are_the_same_in_both_enable_orders() -> void:
	var orders := [["pack-3", "pack-10"], ["pack-10", "pack-3"]]
	for order in orders:
		for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
		for id in order: CardPacks.set_enabled(String(id), true)
		assert_eq(CardRegistry.get_card("Pit Trap").set_code, "ice", str(order))
		assert_true(CardRegistry.card_in_set("Pit Trap", "usg"), str(order))
		assert_eq(CardPacks.packs_required_by(["Pit Trap"]), ["pack-3"], str(order))
		assert_eq(CardPacks.packs_required_by(["Pit Trap", "Gaea's Cradle"]), ["pack-3", "pack-10"], str(order))
	orders = [["pack-6", "pack-10"], ["pack-10", "pack-6"]]
	for order in orders:
		for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
		for id in order: CardPacks.set_enabled(String(id), true)
		for name in UrzaBlockPack.shared():
			var source := String(UrzaBlockPack.shared()[name])
			if source in ["por", "p02"]:
				assert_eq(CardRegistry.get_card(name).set_code, source, "%s %s" % [name, str(order)])


## Pacifism is Mirage's script (Pack 8), reprinted by Tempest (Pack 9) and
## Urza's Saga, so it has three providers: the original pack first, then
## the Tempest block, then the Urza block.
func test_names_shared_by_three_packs() -> void:
	assert_eq(UrzaBlockPack.shared()["Pacifism"], "mir")
	assert_eq(TempestBlockPack.shared()["Pacifism"], "mir")
	CardPacks.set_enabled("pack-10", true)
	CardPacks.set_enabled("pack-9", true)
	assert_eq(CardRegistry.get_card("Pacifism").set_code, "tmp", "the Tempest block walks before the Urza block")
	assert_eq(CardPacks.packs_required_by(["Pacifism"]), ["pack-9"])
	CardPacks.set_enabled("pack-8", true)
	assert_eq(CardRegistry.get_card("Pacifism").set_code, "mir")
	assert_eq(CardPacks.packs_required_by(["Pacifism"]), ["pack-8"])
	CardPacks.set_enabled("pack-8", false)
	CardPacks.set_enabled("pack-9", false)
	assert_eq(CardRegistry.get_card("Pacifism").set_code, "usg")
	assert_eq(CardPacks.packs_required_by(["Pacifism"]), ["pack-10"])
	# Exhaustion is in both Portal sets: Portal's own script is the one.
	assert_eq(UrzaBlockPack.shared()["Exhaustion"], "por")
	assert_eq(CardRegistry.get_card("Exhaustion").set_code, "usg")
	CardPacks.set_enabled("pack-6", true)
	assert_eq(CardRegistry.get_card("Exhaustion").set_code, "por")


func test_pack_of_set_and_known_ids() -> void:
	for code in SETS:
		assert_eq(CardPacks.pack_of_set(code), "pack-10", code)
		assert_true(CardPacks._numbered_set(code), code)
	assert_true(CardPacks.known_ids().has("pack-10"))
	assert_eq(CardPacks.known_ids().back(), "pack-10", "the newest pack is last")
	assert_eq(CardPacks.file_name_for("pack-10"), "Pack-10-Urza-Block.zip")
	assert_eq(CardPacks.label_for("pack-10"), "Pack 10")
	assert_eq(CardPacks.expansions().back(), UrzaBlockPack)


func test_urza_basic_lands_offer_four_numbered_pictures() -> void:
	CardPacks.set_enabled("pack-10", true)
	for land in ["Plains", "Island", "Swamp", "Mountain", "Forest"]:
		var ids: Array = []
		for choice in CardPacks.printing_choices(land):
			if String(choice.set) == "usg": ids.append(String(choice.id))
		assert_eq(ids.size(), 4, land)
		for id in ids:
			assert_true(id.begins_with("usg:"), id)
			assert_true(DeckPrintings.valid_id(id), id)
	var forests: Array = CardPacks.printing_choices("Forest").filter(func(c): return c.set == "usg")
	assert_eq(forests.map(func(c): return String(c.id)), ["usg:347", "usg:348", "usg:349", "usg:350"])
	var cradle: Array = CardPacks.printing_choices("Gaea's Cradle").filter(func(c): return c.set == "usg")
	assert_eq(cradle.size(), 1)


## Every scaffold matches the trusted snapshot it was written from: the
## exact Oracle text, the creature body and the types.
func test_every_new_card_file_matches_its_printed_record() -> void:
	CardPacks.set_enabled("pack-10", true)
	var additions := UrzaBlockPack.new_names()
	var checked := 0
	for row in UrzaBlockPack.records():
		if not additions.has(String(row.name)): continue
		var c := CardRegistry.get_card(String(row.name))
		assert_not_null(c, row.name)
		if c == null: continue
		checked += 1
		assert_eq(c.set_code, String(row.set), row.name)
		assert_eq(c.oracle_text, String(row.oracle_text if row.oracle_text != null else ""), row.name)
		assert_eq(c.cost.text, String(row.mana_cost if row.mana_cost != null else ""), row.name)
		var type_line := String(row.type_line)
		assert_eq(c.is_creature(), type_line.contains("Creature"), row.name)
		assert_eq(c.is_land(), type_line.contains("Land"), row.name)
		assert_eq(c.is_type(Mtg.CardType.ARTIFACT), type_line.contains("Artifact"), row.name)
		assert_eq(c.is_type(Mtg.CardType.ENCHANTMENT), type_line.contains("Enchantment"), row.name)
		assert_eq(c.is_type(Mtg.CardType.INSTANT), type_line.contains("Instant"), row.name)
		assert_eq(c.is_type(Mtg.CardType.SORCERY), type_line.contains("Sorcery"), row.name)
		assert_eq((c.supertypes & Mtg.Supertype.LEGENDARY) != 0, type_line.begins_with("Legendary"), row.name)
		var printed_subtypes: Array = []
		if type_line.contains(" — "):
			for word in type_line.split(" — ")[1].split(" "):
				printed_subtypes.append(word.to_lower())
		for subtype in printed_subtypes:
			assert_true(c.subtypes.has(subtype), "%s is a %s" % [row.name, subtype])
		if c.is_creature() and String(row.power).is_valid_int() and String(row.toughness).is_valid_int():
			assert_eq([c.power, c.toughness], [int(row.power), int(row.toughness)], row.name)
	assert_eq(checked, 591)
	assert_true(CardRegistry.get_card("Yavimaya Wurm").keywords.has(Mtg.Keyword.TRAMPLE))
	assert_true(CardRegistry.get_card("Plague Beetle").landwalk.has("swamp"))
	assert_true(CardRegistry.get_card("Crazed Skirge").keywords.has(Mtg.Keyword.FLYING))
	assert_true(CardRegistry.get_card("Crazed Skirge").keywords.has(Mtg.Keyword.HASTE))
	assert_true(CardRegistry.get_card("Plated Spider").keywords.has(Mtg.Keyword.REACH))
	assert_true(CardRegistry.get_card("Defender of Law").keywords.has(Mtg.Keyword.FLASH))
	assert_eq(CardRegistry.get_card("Defender of Law").protection_from, Mtg.ManaColor.R)
	assert_eq(CardRegistry.get_card("Voice of Grace").protection_from, Mtg.ManaColor.B)
	assert_ne(CardRegistry.get_card("Gaea's Cradle").supertypes & Mtg.Supertype.LEGENDARY, 0)
	var karn := CardRegistry.get_card("Karn, Silver Golem")
	assert_ne(karn.supertypes & Mtg.Supertype.LEGENDARY, 0)
	assert_true(karn.is_type(Mtg.CardType.ARTIFACT) and karn.is_creature())


## The header of every new card file carries the snapshot's exact Oracle
## text, line for line, under its name, cost, type line, rarity and set —
## and the promise that the ZIP supplies no script.
func test_every_header_carries_the_exact_oracle_text() -> void:
	var additions := UrzaBlockPack.new_names()
	var checked := 0
	for row in UrzaBlockPack.records():
		if not additions.has(String(row.name)): continue
		var path := "res://cards/sets/%s/%s.gd" % [row.set, UrzaBlockPack.snake(String(row.name))]
		var text := FileAccess.get_file_as_string(path)
		assert_ne(text, "", path)
		if text == "": continue
		checked += 1
		var lines := text.split("\n")
		assert_eq(lines[0], "extends CardScript", path)
		assert_eq(lines[1], "## %s — %s — %s (%s, %s)." % [row.name,
			String(row.mana_cost if row.mana_cost != null else ""), row.type_line, row.rarity, row.set], path)
		var oracle := String(row.oracle_text if row.oracle_text != null else "")
		var expected: Array[String] = []
		if oracle == "":
			expected.append("## Oracle: (No rules text.)")
		else:
			var first := true
			for line in oracle.split("\n"):
				expected.append(("## Oracle: " if first else "##         ") + line)
				first = false
		for i in expected.size():
			assert_eq(lines[2 + i], expected[i], "%s header line %d" % [row.name, i + 1])
		assert_eq(lines[2 + expected.size()],
			"## Trusted optional Pack 10 implementation; ZIPs never provide scripts.", path)
		assert_true(text.contains('return load("res://cards/sets/%s/_rules.gd").apply(c)' % row.set), path)
		assert_false(text.contains("class_name"), path)
	assert_eq(checked, 591)


## Each set's dispatcher asks the sixteen family modules in the fixed order
## and refuses — puts the `_pending` cast guard on — any name none claims.
func test_each_dispatcher_is_fail_closed() -> void:
	for code in SETS:
		var source := FileAccess.get_file_as_string("res://cards/sets/%s/_rules.gd" % code)
		var asked: Array[String] = []
		var at := source.find("preload(\"res://cards/sets/%s/_" % code)
		while at != -1:
			var start := at + ("preload(\"res://cards/sets/%s/" % code).length()
			asked.append(source.substr(start, source.find(".gd", start) - start))
			at = source.find("preload(\"res://cards/sets/%s/_" % code, start)
		assert_eq(asked, MODULES, code + " asks its modules in order")
		for module in MODULES:
			assert_true(FileAccess.file_exists("res://cards/sets/%s/%s.gd" % [code, module]), code + module)
		var stranger := CardData.new("Not an Urza Block Card", "{1}", Mtg.CardType.CREATURE)
		stranger.pt(1, 1)
		load("res://cards/sets/%s/_rules.gd" % code).apply(stranger)
		assert_true(_is_pending(stranger), code + ": an unknown name stays fail-closed")
		assert_eq(String(stranger.cast_condition.call(null, 0)), PENDING)
	# A pending card is in the pool and visible, but its cast is refused
	# with the dispatcher's own words.
	CardPacks.set_enabled("pack-10", true)
	var cradle := CardRegistry.get_card("Gaea's Cradle")
	if _is_pending(cradle):
		assert_eq(String(cradle.cast_condition.call(null, 0)), PENDING)


## The vanilla and keyword-only creatures `_basic.gd` lists are complete
## from the first day; every other name waits for its family module. Each
## listed card's whole Oracle text is keywords its file already sets.
func test_basic_family_names_are_complete() -> void:
	CardPacks.set_enabled("pack-10", true)
	for code in BASIC:
		var source := FileAccess.get_file_as_string("res://cards/sets/%s/_basic.gd" % code)
		for name in BASIC[code]:
			var c := CardRegistry.get_card(name)
			assert_not_null(c, name)
			if c == null: continue
			assert_eq(c.set_code, code, name)
			assert_true(c.is_creature(), name)
			assert_false(_is_pending(c), name)
			assert_true(source.contains('"%s"' % name), "%s is claimed by %s/_basic.gd" % [name, code])
	var giant := CardRegistry.get_card("Giant Cockroach")
	assert_eq([giant.power, giant.toughness], [4, 2])
	assert_eq(giant.oracle_text, "")
	var berserker := CardRegistry.get_card("Goblin Berserker")
	assert_true(berserker.keywords.has(Mtg.Keyword.FIRST_STRIKE) and berserker.keywords.has(Mtg.Keyword.HASTE))
	assert_true(CardRegistry.get_card("Squirming Mass").keywords.has(Mtg.Keyword.FEAR))
	assert_true(CardRegistry.get_card("Goblin Spelunkers").landwalk.has("mountain"))
	assert_eq(CardRegistry.get_card("Defender of Chaos").protection_from, Mtg.ManaColor.W)
	assert_eq(CardRegistry.get_card("Voice of Reason").protection_from, Mtg.ManaColor.U)


## THE CATALOGUE GATE. Every published name of the three sets must have a
## completed rules handler: no `_pending` cast guard may remain. Expected
## to fail until the card-implementation waves are finished.
func test_no_urza_block_card_is_pending() -> void:
	CardPacks.set_enabled("pack-10", true)
	var additions := UrzaBlockPack.new_names()
	for code in SETS:
		var pending: Array[String] = []
		for name in CardRegistry.names_in_set(code):
			if not additions.has(name): continue
			if _is_pending(CardRegistry.get_card(name)): pending.append(name)
		assert_eq(pending, [] as Array[String],
			"%s: %d names still carry the pending rules guard" % [code, pending.size()])
