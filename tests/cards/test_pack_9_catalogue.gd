extends GutTest
## The Tempest block (Pack 9): three sets in one pack, 574 new identities,
## and 27 shared reprints it provides when their original pack is off.
##
## The last test is the catalogue gate the card waves work towards: it
## fails while any Tempest, Stronghold or Exodus name still carries the
## dispatcher's `_pending` cast guard (cards/sets/<set>/_rules.gd).

const SETS := ["tmp", "sth", "exo"]
## The family modules every set's dispatcher asks, in this order.
const MODULES: Array[String] = ["_basic", "_spells", "_creatures", "_auras", "_artifacts",
	"_lands_mana", "_combat", "_triggers", "_choices", "_costs", "_buyback",
	"_shadow", "_licids", "_slivers", "_spikes", "_misc"]
const PENDING := "Tempest block rules integration is not yet complete for this card"

func after_each() -> void:
	CardPacks.set_current_deck_names([])
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _is_pending(c: CardData) -> bool:
	return c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"


func test_tempest_block_alone_and_alongside_every_previous_pack() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	assert_false(CardRegistry.has_card("Mirri, Cat Warrior"))
	assert_false(CardRegistry.has_card("Pacifism"))
	assert_eq(CardRegistry.size(), 897)
	assert_true(CardPacks.set_enabled("pack-9", true))
	assert_eq(CardRegistry.names_in_set("tmp").size(), 335)
	assert_eq(CardRegistry.names_in_set("sth").size(), 143)
	assert_eq(CardRegistry.names_in_set("exo").size(), 143)
	# The catalogue's sets arrive key-sorted, as Portal's two do (p02, por).
	assert_eq(CardRegistry.extra_set_order(), ["exo", "sth", "tmp"])
	# 574 new identities and the 27 shared reprints Pack 9 provides alone.
	assert_eq(TempestBlockPack.new_names().size(), 574)
	assert_eq(TempestBlockPack.shared().size(), 27)
	assert_eq(TempestBlockPack.records().size(), 621)
	assert_eq(TempestBlockPack.printings().size(), 636)
	assert_eq(TempestBlockPack.scripts().size(), 601)
	assert_eq(CardRegistry.size(), 897 + 574 + 27)
	# Every published name has a script and a provider: the registry knows
	# it, in the set that printed it.
	for row in TempestBlockPack.records():
		assert_true(CardRegistry.has_card(row.name), row.name)
		assert_true(CardRegistry.card_in_set(row.name, row.set), row.name)
	for name in TempestBlockPack.shared():
		if not CardRegistry.has_card(name): continue
		var c := CardRegistry.get_card(name)
		assert_true(SETS.has(c.set_code), "%s wears its block set alone" % name)
		assert_false(_is_pending(c), name)
		var one: Array[String] = [name]
		assert_eq(CardPacks.packs_required_by(one), ["pack-9"], name)
	# The fifteen core reprints keep their core scripts and need no pack.
	assert_eq(CardRegistry.get_card("Counterspell").set_code, "2ed")
	assert_true(CardRegistry.card_in_set("Counterspell", "tmp"))
	assert_eq(CardPacks.packs_required_by(["Counterspell", "Tranquility"]), [])
	assert_eq(CardPacks.packs_required_by(["Mirri, Cat Warrior", "Counterspell"]), ["pack-9"])
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, true)
	assert_eq(CardRegistry.size(), 2519 + 574)   # Packs 1-8, and the Tempest block's 574
	assert_eq(CardRegistry.names_in_set("tmp").size(), 335)
	CardPacks.set_enabled("pack-9", false)
	assert_eq(CardRegistry.size(), 2519)
	assert_false(CardRegistry.has_card("Mirri, Cat Warrior"))
	assert_true(CardRegistry.has_card("Pacifism"))


func test_original_packs_keep_their_scripts_and_any_one_provider_suffices() -> void:
	CardPacks.set_enabled("pack-9", true)
	CardPacks.set_enabled("pack-8", true)
	# A Mirage card the Tempest block reprints: the Mirage block is its
	# original pack, and its script and symbol win while both are on.
	assert_eq(TempestBlockPack.shared()["Pacifism"], "mir")
	assert_eq(CardRegistry.get_card("Pacifism").set_code, "mir")
	assert_true(CardRegistry.card_in_set("Pacifism", "tmp"))
	assert_eq(CardPacks.packs_required_by(["Pacifism"]), ["pack-8"])
	CardPacks.set_current_deck_names(["Pacifism", "Mirri, Cat Warrior"])
	assert_eq(CardPacks.disable_warning("pack-8"), "", "Pack 9 still provides Pacifism")
	assert_string_contains(CardPacks.disable_warning("pack-9"), "Mirri, Cat Warrior")
	assert_false(CardPacks.disable_warning("pack-9").contains("Pacifism"))
	CardPacks.set_enabled("pack-8", false)
	assert_eq(CardRegistry.get_card("Pacifism").set_code, "tmp")
	assert_eq(CardPacks.packs_required_by(["Pacifism"]), ["pack-9"])
	assert_string_contains(CardPacks.disable_warning("pack-9"), "Pacifism")
	# A deck saved under the Mirage block and opened with only Pack 9: the
	# declared Pack 8 requirement is met by the provider in play.
	var declared: Array[String] = ["pack-8"]
	var names: Array[String] = ["Pacifism", "Counterspell"]
	assert_eq(CardPacks.effective_requirements(declared, names), [] as Array[String])
	CardPacks.set_enabled("pack-9", false)
	assert_eq(CardPacks.packs_required_by(["Pacifism"]), ["pack-8"])
	assert_false(CardRegistry.has_card("Pacifism"))


## Coercion is Second Age's script (Pack 6), reprinted by Visions (Pack 8)
## and Tempest, so it has three providers; Dark Banishing is Ice Age's
## (Pack 3), in Mirage and Tempest as well.
func test_names_shared_by_three_packs() -> void:
	assert_eq(TempestBlockPack.shared()["Coercion"], "p02")
	assert_eq(TempestBlockPack.shared()["Dark Banishing"], "ice")
	assert_eq(MirageBlockPack.shared()["Coercion"], "p02")
	CardPacks.set_enabled("pack-9", true)
	CardPacks.set_enabled("pack-8", true)
	assert_eq(CardRegistry.get_card("Coercion").set_code, "vis", "the Mirage block walks before the Tempest block")
	assert_eq(CardPacks.packs_required_by(["Coercion"]), ["pack-8"])
	CardPacks.set_enabled("pack-6", true)
	assert_eq(CardRegistry.get_card("Coercion").set_code, "p02")
	assert_eq(CardPacks.packs_required_by(["Coercion"]), ["pack-6"])
	CardPacks.set_enabled("pack-6", false)
	CardPacks.set_enabled("pack-8", false)
	assert_eq(CardRegistry.get_card("Coercion").set_code, "tmp")
	assert_eq(CardPacks.packs_required_by(["Coercion", "Dark Banishing"]), ["pack-9"])
	CardPacks.set_enabled("pack-3", true)
	assert_eq(CardRegistry.get_card("Dark Banishing").set_code, "ice")
	assert_eq(CardPacks.packs_required_by(["Dark Banishing"]), ["pack-3"])


func test_pack_of_set_and_known_ids() -> void:
	for code in SETS:
		assert_eq(CardPacks.pack_of_set(code), "pack-9", code)
		assert_true(CardPacks._numbered_set(code), code)
	assert_true(CardPacks.known_ids().has("pack-9"))
	assert_eq(CardPacks.known_ids().back(), "pack-9", "the newest pack is last")
	assert_eq(CardPacks.file_name_for("pack-9"), "Pack-9-Tempest-Block.zip")
	assert_eq(CardPacks.label_for("pack-9"), "Pack 9")
	assert_eq(CardPacks.expansions().back(), TempestBlockPack)


func test_tempest_basic_lands_offer_four_numbered_pictures() -> void:
	CardPacks.set_enabled("pack-9", true)
	for land in ["Plains", "Island", "Swamp", "Mountain", "Forest"]:
		var ids: Array = []
		for choice in CardPacks.printing_choices(land):
			if String(choice.set) == "tmp": ids.append(String(choice.id))
		assert_eq(ids.size(), 4, land)
		for id in ids:
			assert_true(id.begins_with("tmp:"), id)
			assert_true(DeckPrintings.valid_id(id), id)
	var forests: Array = CardPacks.printing_choices("Forest").filter(func(c): return c.set == "tmp")
	assert_eq(forests.map(func(c): return String(c.id)), ["tmp:347", "tmp:348", "tmp:349", "tmp:350"])
	var mirri: Array = CardPacks.printing_choices("Mirri, Cat Warrior").filter(func(c): return c.set == "exo")
	assert_eq(mirri.size(), 1)


## Every scaffold matches the trusted snapshot it was written from: the
## exact Oracle text, the creature body and the types.
func test_every_new_card_file_matches_its_printed_record() -> void:
	CardPacks.set_enabled("pack-9", true)
	var additions := TempestBlockPack.new_names()
	var checked := 0
	for row in TempestBlockPack.records():
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
	assert_eq(checked, 574)
	assert_true(CardRegistry.get_card("Rootbreaker Wurm").keywords.has(Mtg.Keyword.TRAMPLE))
	assert_true(CardRegistry.get_card("Bayou Dragonfly").landwalk.has("swamp"))
	assert_true(CardRegistry.get_card("Bayou Dragonfly").keywords.has(Mtg.Keyword.FLYING))
	assert_true(CardRegistry.get_card("Wall of Razors").keywords.has(Mtg.Keyword.DEFENDER))
	# One protection keyword naming two colours (CR 702.16) is one mask.
	var paladin := CardRegistry.get_card("Paladin en-Vec")
	assert_true(paladin.keywords.has(Mtg.Keyword.FIRST_STRIKE))
	assert_eq(paladin.protection_from, Mtg.ManaColor.B | Mtg.ManaColor.R)
	assert_eq(CardRegistry.get_card("Soltari Monk").protection_from, Mtg.ManaColor.B)
	assert_ne(CardRegistry.get_card("Volrath's Stronghold").supertypes & Mtg.Supertype.LEGENDARY, 0)
	assert_ne(CardRegistry.get_card("Mirri, Cat Warrior").supertypes & Mtg.Supertype.LEGENDARY, 0)


## The header of every new card file carries the snapshot's exact Oracle
## text, line for line, under its name, cost, type line, rarity and set —
## and the promise that the ZIP supplies no script.
func test_every_header_carries_the_exact_oracle_text() -> void:
	var additions := TempestBlockPack.new_names()
	var checked := 0
	for row in TempestBlockPack.records():
		if not additions.has(String(row.name)): continue
		var path := "res://cards/sets/%s/%s.gd" % [row.set, TempestBlockPack.snake(String(row.name))]
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
			"## Trusted optional Pack 9 implementation; ZIPs never provide scripts.", path)
		assert_true(text.contains('return load("res://cards/sets/%s/_rules.gd").apply(c)' % row.set), path)
		assert_false(text.contains("class_name"), path)
	assert_eq(checked, 574)


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
		var stranger := CardData.new("Not a Tempest Block Card", "{1}", Mtg.CardType.CREATURE)
		stranger.pt(1, 1)
		load("res://cards/sets/%s/_rules.gd" % code).apply(stranger)
		assert_true(_is_pending(stranger), code + ": an unknown name stays fail-closed")
		assert_eq(String(stranger.cast_condition.call(null, 0)), PENDING)
	# A pending card is in the pool and visible, but its cast is refused
	# with the dispatcher's own words.
	CardPacks.set_enabled("pack-9", true)
	var dauthi := CardRegistry.get_card("Dauthi Slayer")
	if _is_pending(dauthi):
		assert_eq(String(dauthi.cast_condition.call(null, 0)), PENDING)


## The vanilla and keyword-only creatures `_basic.gd` lists are complete
## from the first day; every other name waits for its family module.
func test_basic_family_names_are_complete() -> void:
	CardPacks.set_enabled("pack-9", true)
	for name in ["Lowland Giant", "Rootbreaker Wurm", "Bayou Dragonfly", "Metallic Sliver",
			"Wall of Razors", "Youthful Knight", "Mirri, Cat Warrior", "Standing Troops",
			"Paladin en-Vec"]:
		assert_false(_is_pending(CardRegistry.get_card(name)), name)


## THE CATALOGUE GATE. Every published name of the three sets must have a
## completed rules handler: no `_pending` cast guard may remain. Expected
## to fail until the card-implementation waves are finished.
func test_no_tempest_block_card_is_pending() -> void:
	CardPacks.set_enabled("pack-9", true)
	var additions := TempestBlockPack.new_names()
	for code in SETS:
		var pending: Array[String] = []
		for name in CardRegistry.names_in_set(code):
			if not additions.has(name): continue
			if _is_pending(CardRegistry.get_card(name)): pending.append(name)
		assert_eq(pending, [] as Array[String],
			"%s: %d names still carry the pending rules guard" % [code, pending.size()])
