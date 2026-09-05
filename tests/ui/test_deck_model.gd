extends GutTest
## The deck under construction: counts, the 1997 limits, the Stats
## window's numbers, and the round trip through the deck file format — a
## deck saved by the builder must be a deck the battle-setup screen can
## load and play, so that round trip is pinned here.


var deck: DeckModel


func before_each() -> void:
	CardRegistry.ensure_loaded()
	deck = DeckModel.new()


func _add(card_name: String, times := 1) -> String:
	var last := ""
	for _i in times:
		last = deck.add(card_name)
	return last


func test_a_new_deck_is_empty_and_called_new_deck() -> void:
	assert_eq(deck.total(), 0)
	assert_eq(deck.deck_name, "New Deck", "@NEWDECK")


func test_add_and_remove_count_cards() -> void:
	assert_eq(deck.add("Lightning Bolt"), "", "adding succeeds quietly")
	assert_eq(deck.count_of("Lightning Bolt"), 1)
	assert_eq(deck.total(), 1)
	assert_eq(deck.remove("Lightning Bolt"), "")
	assert_eq(deck.total(), 0)
	assert_false(deck.counts.has("Lightning Bolt"), "a zero count is dropped")


func test_removing_a_card_that_is_not_there_is_refused() -> void:
	assert_ne(deck.remove("Lightning Bolt"), "", "a refusal, not a crash")


func test_remove_all_clears_the_column() -> void:
	_add("Lightning Bolt", 3)
	assert_eq(deck.remove_all("Lightning Bolt"), "")
	assert_eq(deck.total(), 0)


func test_unknown_cards_are_refused() -> void:
	var refusal := deck.add("Chaos Orb")
	assert_ne(refusal, "", "not in the implemented pool")
	assert_eq(deck.total(), 0)


func test_the_deck_builder_does_not_impose_a_four_of_rule() -> void:
	# The manual, ch.10: "in Shandalar, there are few restrictions on the
	# contents of your dueling deck. Any deck you can dream up, you can
	# build and play." The duplicate table is SHANDALAR's, not this
	# screen's, and is reported as advice below.
	assert_eq(_add("Lightning Bolt", 9), "", "nine Bolts is a legal build")
	assert_eq(deck.count_of("Lightning Bolt"), 9)


func test_shandalar_duplicate_allowance_follows_the_manuals_table() -> void:
	assert_eq(DeckModel.duplicates_allowed(10), 1, "1-19 cards: one copy")
	assert_eq(DeckModel.duplicates_allowed(30), 2, "20-39: two")
	assert_eq(DeckModel.duplicates_allowed(45), 3, "40-59: three")
	assert_eq(DeckModel.duplicates_allowed(60), 4, "60 and up: four")
	assert_eq(DeckModel.duplicates_allowed(60, true), 0,
		"the Tome of Enlightenment lifts the limit entirely at 60+")
	assert_eq(DeckModel.duplicates_allowed(45, true), 4, "the Tome eases it by one")


func test_the_duplicate_advisory_names_the_offenders() -> void:
	_add("Lightning Bolt", 9)
	_add("Mountain", 35)
	var advice := deck.over_duplicate_limit()
	assert_eq(advice.size(), 1, "only the Bolts")
	assert_string_contains(advice[0], "Lightning Bolt")


func test_basic_lands_are_exempt_from_the_duplicate_rule() -> void:
	assert_true(DeckModel.exempt_from_duplicates("Mountain"), "a basic land")
	assert_false(DeckModel.exempt_from_duplicates("Lightning Bolt"))
	_add("Mountain", 40)
	assert_eq(deck.over_duplicate_limit(), [], "as many basics as you like")


func test_a_short_deck_is_refused_in_the_1997_words() -> void:
	_add("Mountain", 10)
	assert_false(deck.is_legal())
	assert_eq(deck.problems()[0],
		"Your deck must have at least 40 cards to be used in the duel.",
		"@TOOFEWCARDS, verbatim")


func test_a_forty_card_deck_is_legal() -> void:
	_add("Mountain", 20)
	_add("Forest", 20)
	assert_eq(deck.total(), DeckModel.MIN_CARDS)
	assert_true(deck.is_legal(), "the minimum deck is legal")
	assert_eq(deck.problems().size(), 0)


func test_the_total_ceiling_is_the_duels_own() -> void:
	assert_eq(DeckModel.MAX_TOTAL, 500)
	assert_eq(DeckModel.MAX_UNIQUE, 200)
	deck.counts["Mountain"] = DeckModel.MAX_TOTAL
	assert_ne(deck.add("Forest"), "", "the 501st card is refused")


# ---------------------------------------------------------------- stats --

func test_the_stats_matrix_counts_type_by_color() -> void:
	_add("Mountain", 4)
	_add("Lightning Bolt", 3)
	_add("Shivan Dragon", 1)
	assert_eq(deck.type_color_count(Mtg.CardType.LAND, 0), 4,
		"a land is colourless")
	assert_eq(deck.type_color_count(Mtg.CardType.INSTANT, Mtg.ManaColor.R), 3)
	assert_eq(deck.type_color_count(Mtg.CardType.CREATURE, Mtg.ManaColor.R), 1)
	assert_eq(deck.type_color_count(Mtg.CardType.CREATURE, Mtg.ManaColor.W), 0)


func test_the_stats_window_has_the_1997_rows_and_columns() -> void:
	assert_eq(DeckModel.STAT_ROWS.size(), 6, "@STATSSCREEN types, less Interrupts")
	assert_eq(DeckModel.STAT_COLUMNS.size(), 6, "five colours plus Colorless")


func test_mana_sources_answers_can_this_deck_cast_itself() -> void:
	_add("Mountain", 4)
	_add("Sol Ring", 1)
	assert_eq(deck.mana_sources()[Mtg.ManaColor.R], 4, "Mountains make {R}")
	assert_eq(deck.mana_sources()[Mtg.ManaColor.W], 0)
	assert_eq(deck.mana_sources()[0], 1, "Sol Ring is a colourless source")


func test_the_mana_curve_buckets_the_spells() -> void:
	_add("Mountain", 4)
	_add("Lightning Bolt", 3)
	_add("Shivan Dragon", 1)
	var curve := deck.mana_curve()
	assert_eq(curve.size(), 8, "0 through 7+")
	assert_eq(curve[1], 3, "three one-drops (Lightning Bolt)")
	assert_eq(curve[6], 1, "Shivan Dragon is {4}{R}{R}")
	assert_eq(curve[0], 0, "lands are not on the curve")


func test_type_totals() -> void:
	_add("Mountain", 4)
	_add("Lightning Bolt", 3)
	_add("Shivan Dragon", 1)
	assert_eq(deck.land_count(), 4)
	assert_eq(deck.creature_count(), 1)
	assert_eq(deck.spell_count(), 3)
	assert_eq(deck.non_creature_count(), 7)


# ------------------------------------------------------------- the file --

func test_sort_deck_puts_lands_first_then_color() -> void:
	# "Sort Deck rearranges the cards in order by color, putting like
	# cards together. Lands are always at the beginning."
	_add("Lightning Bolt", 2)
	_add("Serra Angel", 1)
	_add("Mountain", 4)
	assert_eq(deck.names(), ["Mountain", "Serra Angel", "Lightning Bolt"],
		"land, then white, then red")


func test_the_deck_writes_the_projects_deck_format() -> void:
	deck.deck_name = "Test Deck"
	_add("Lightning Bolt", 3)
	_add("Mountain", 17)
	var text := deck.to_text()
	assert_string_contains(text, "name: Test Deck")
	assert_string_contains(text, "3 Lightning Bolt")
	assert_string_contains(text, "17 Mountain")


func test_round_trips_through_the_deck_loader() -> void:
	deck.deck_name = "Round Trip"
	_add("Lightning Bolt", 4)
	_add("Shivan Dragon", 2)
	_add("Mountain", 34)
	var reloaded := DeckList.new()
	reloaded.parse(deck.to_text(), "fallback", true)
	assert_eq(reloaded.errors, [], "the builder never writes a deck we cannot read")
	assert_eq(reloaded.deck_name, "Round Trip")
	assert_eq(reloaded.cards.size(), 40)
	var back := DeckModel.from_deck_list(reloaded)
	assert_eq(back.count_of("Lightning Bolt"), 4)
	assert_eq(back.count_of("Mountain"), 34)
	assert_eq(back.deck_name, "Round Trip")


func test_every_shipped_deck_loads_into_the_builder() -> void:
	# LENIENT since 2026-09-02, because that is the load the builder
	# actually does ([method DeckStore.load_deck]): the ported
	# `decks/tournament/`, `decks/community/` and
	# `decks/extended_community/` decks name cards this pool does not
	# hold yet, which a strict load reports as errors and the builder
	# carries as proxies. `test_decks_1997.gd` pins which are proxy-free.
	var paths := DeckStore.all_deck_paths()
	assert_gt(paths.size(), 0, "the project ships decks to edit")
	for path in paths:
		var loaded := DeckList.load_file(path, false)
		assert_eq(loaded.errors, [], path)
		var model := DeckModel.from_deck_list(loaded)
		assert_eq(model.total(), loaded.cards.size(), path)


func test_expanded_cards_feed_a_duel() -> void:
	_add("Lightning Bolt", 2)
	_add("Mountain", 3)
	var expanded := deck.to_card_list()
	assert_eq(expanded.size(), 5)
	assert_eq(expanded.count("Lightning Bolt"), 2)


func test_clear_deck_wipes_the_surface_only() -> void:
	deck.deck_name = "Doomed"
	_add("Mountain", 4)
	deck.clear()
	assert_eq(deck.total(), 0)
	assert_eq(deck.deck_name, "New Deck")


# ======================================================= SCREENSHOT PASS ==
# [QoL] The notes field, the two export formats and the extra statistics
# the Stats window graphs.

func test_notes_ride_as_comment_lines_an_old_reader_skips() -> void:
	deck.deck_name = "Noted"
	deck.notes = "Weak to artifacts.\nSwap in Disenchant."
	_add("Mountain", 4)
	var text := deck.to_text()
	assert_string_contains(text, "# note: Weak to artifacts.")
	assert_string_contains(text, "# note: Swap in Disenchant.")
	# The reader that matters: DeckList is engine code and knows nothing
	# about notes, so it must simply skip them.
	var back := DeckList.new()
	back.parse(text, "fallback", true)
	assert_eq(back.errors, [], "no line of a noted deck is an error")
	assert_eq(back.cards.size(), 4)
	assert_eq(back.deck_name, "Noted")
	assert_eq(DeckModel.notes_from_text(text), deck.notes, "and they read back")


func test_a_deck_with_no_notes_reads_back_as_none() -> void:
	_add("Mountain", 2)
	assert_false(deck.to_text().contains("# note:"))
	assert_eq(DeckModel.notes_from_text(deck.to_text()), "")


func test_the_decklist_export_round_trips() -> void:
	deck.deck_name = "Burn"
	_add("Lightning Bolt", 4)
	_add("Mountain", 20)
	var back := DeckList.new()
	back.parse(deck.to_dec_text(), "fallback", true)
	assert_eq(back.errors, [], "a community reader takes it")
	assert_eq(back.deck_name, "Burn", "// NAME : names it")
	assert_eq(back.cards.count("Lightning Bolt"), 4)
	assert_eq(back.cards.size(), 24)


func test_the_1997_export_round_trips_through_the_microprose_parser() -> void:
	deck.deck_name = "Old School"
	_add("Mountain", 3)
	var back := DeckList.new()
	back.parse_dck(deck.to_dck_text(DeckStore.dck_ids()), "fallback", true)
	assert_eq(back.errors, [], "the .dck parser takes it")
	assert_eq(back.deck_name, "Old School")
	assert_eq(back.cards.count("Mountain"), 3)


func test_a_card_with_no_known_microprose_id_still_exports() -> void:
	_add("Mountain", 1)
	var text := deck.to_dck_text({})
	assert_string_contains(text, ".0\t1\tMountain")
	var back := DeckList.new()
	back.parse_dck(text, "fallback", true)
	assert_eq(back.errors, [], "id 0 is tolerated; names are authoritative")


func test_the_average_casting_cost_ignores_land() -> void:
	_add("Lightning Bolt", 2)          # mana value 1
	_add("Mountain", 20)               # no cost at all
	assert_almost_eq(deck.average_cost(), 1.0, 0.001,
		"twenty lands must not drag the average to nothing")


func test_the_average_of_an_empty_deck_is_zero_not_a_crash() -> void:
	assert_eq(deck.average_cost(), 0.0)
	assert_eq(deck.land_ratio(), 0.0)


func test_the_land_ratio_is_the_number_a_builder_checks() -> void:
	_add("Mountain", 17)
	_add("Lightning Bolt", 23)
	assert_almost_eq(deck.land_ratio(), 17.0 / 40.0, 0.001)


func test_type_counts_report_every_stats_row() -> void:
	_add("Mountain", 4)
	_add("Lightning Bolt", 2)
	var types := deck.type_counts()
	assert_eq(int(types[Mtg.CardType.LAND]), 4)
	assert_eq(int(types[Mtg.CardType.INSTANT]), 2)
	for row in DeckModel.STAT_ROWS:
		assert_true(types.has(int(row[1])), "%s is counted" % row[0])


func test_a_duplicated_model_carries_its_notes() -> void:
	deck.notes = "keep me"
	assert_eq(deck.duplicate_model().notes, "keep me",
		"or Undo and Clear/Restore would silently eat them")


# ==================================================== SECOND AUDIT PASS ==

func test_extra_copies_names_only_what_is_over_the_limit() -> void:
	# `@EXTRACARDSDIALOG`'s list, as data — what `Remove Extra Cards` cuts.
	_add("Mountain", 40)                   # basics are exempt
	_add("Lightning Bolt", 7)
	_add("Giant Growth", 2)
	assert_eq(DeckModel.duplicates_allowed(deck.total()), 3,
		"a 49-card deck allows three")
	var over := deck.extra_copies()
	assert_eq(int(over.get("Lightning Bolt", 0)), 4, "four too many")
	assert_false(over.has("Giant Growth"), "two is inside the limit")
	assert_false(over.has("Mountain"),
		"'This limitation does not apply to basic lands, of course'")


func test_remove_extra_cards_cuts_every_stack_to_the_allowance() -> void:
	_add("Mountain", 40)
	_add("Lightning Bolt", 7)
	_add("Elvish Archers", 6)
	var limit := DeckModel.duplicates_allowed(deck.total())
	var removed := deck.trim_duplicates()
	assert_eq(removed, (7 - limit) + (6 - limit), "it says what it took")
	assert_eq(deck.count_of("Lightning Bolt"), limit)
	assert_eq(deck.count_of("Elvish Archers"), limit)
	assert_eq(deck.count_of("Mountain"), 40, "basics untouched")
	assert_true(deck.over_duplicate_limit().is_empty(), "and the advice clears")


func test_remove_extra_cards_does_not_chase_its_own_tail() -> void:
	# The allowance is scaled by DECK SIZE, so trimming can lower it.
	# Re-reading the list mid-cut would take more than the dialog said.
	_add("Lightning Bolt", 40)
	_add("Giant Growth", 25)               # 65 cards: four of each allowed
	assert_eq(DeckModel.duplicates_allowed(deck.total()), 4)
	deck.trim_duplicates()
	assert_eq(deck.count_of("Lightning Bolt"), 4)
	assert_eq(deck.count_of("Giant Growth"), 4)


func test_move_by_color_out_of_deck_takes_a_whole_colour() -> void:
	# `@DECKSURFACE_ADVENTURE` / `@GROUPMOVE`.
	_add("Lightning Bolt", 4)
	_add("Giant Growth", 4)
	_add("Black Lotus", 1)                 # colourless: @GROUPMOVE's "Artifact"
	_add("Mountain", 10)
	assert_eq(deck.remove_by_color([Mtg.ManaColor.R]), 4)
	assert_eq(deck.count_of("Lightning Bolt"), 0)
	assert_eq(deck.count_of("Mountain"), 10, "a land has no colour")
	assert_eq(deck.remove_by_color([0]), 1, "and Artifact means colourless")
	assert_eq(deck.count_of("Black Lotus"), 0)
	assert_eq(deck.count_of("Giant Growth"), 4, "nothing else moved")


func test_sort_deck_order_survives_the_decorated_sort() -> void:
	# `names()` now computes each rank once and sorts alongside it rather
	# than inside the comparator (4.2 ms -> 0.5 ms on 200 unique cards).
	# The ORDER must be the one the manual describes, unchanged.
	_add("Lightning Bolt", 1)
	_add("Mountain", 1)
	_add("Giant Growth", 1)
	_add("Forest", 1)
	_add("Ancestral Recall", 1)
	var order := deck.names()
	assert_eq(order.size(), 5)
	assert_true(order[0] == "Forest" or order[0] == "Mountain",
		"Lands are always at the beginning")
	assert_true(order[1] == "Forest" or order[1] == "Mountain")
	assert_eq(order[2], "Ancestral Recall", "then WUBRG: blue")
	assert_eq(order[3], "Lightning Bolt", "then red")
	assert_eq(order[4], "Giant Growth", "then green")


# ============================================================ THIRD PASS ==
# Two queries that answer in ONE walk what the screen used to ask for a
# card at a time. Both are pinned against the per-card queries they
# replace, on a deck deliberately full of the awkward cases: an artifact
# creature (two ROWS), a gold card (two COLUMNS), basic land (colourless)
# and a colourless spell.

func _awkward_deck() -> void:
	for card_name in ["Clockwork Beast", "Lightning Bolt", "Mountain",
			"Forest", "Black Lotus", "Birds of Paradise", "Ancestral Recall",
			"Wrath of God", "Sol Ring", "Air Elemental"]:
		if CardRegistry.has_card(card_name):
			_add(card_name, 3)


func test_the_headline_counts_are_the_counts_they_replace() -> void:
	_awkward_deck()
	var tally := deck.headline_counts()
	assert_eq(int(tally["total"]), deck.total(), "total")
	assert_eq(int(tally["land"]), deck.land_count(), "land")
	assert_eq(int(tally["creature"]), deck.creature_count(), "creature")
	assert_eq(int(tally["spell"]), deck.spell_count(), "spell")
	assert_eq(int(tally["land"]) + int(tally["creature"]) + int(tally["spell"]),
		deck.total(), "and the three add up to the deck")


func test_the_headline_counts_of_an_empty_deck_are_zero() -> void:
	var tally := deck.headline_counts()
	for key in ["total", "land", "creature", "spell"]:
		assert_eq(int(tally[key]), 0, key)


func test_the_stat_matrix_is_the_cell_by_cell_matrix() -> void:
	_awkward_deck()
	var matrix := deck.type_color_matrix()
	assert_eq(matrix.size(), DeckModel.STAT_ROWS.size())
	for r in DeckModel.STAT_ROWS.size():
		var line: Array = matrix[r]
		assert_eq(line.size(), DeckModel.STAT_COLUMNS.size())
		for c in DeckModel.STAT_COLUMNS.size():
			assert_eq(int(line[c]), deck.type_color_count(
				int(DeckModel.STAT_ROWS[r][1]), int(DeckModel.STAT_COLUMNS[c][1])),
				"%s x %s" % [DeckModel.STAT_ROWS[r][0], DeckModel.STAT_COLUMNS[c][0]])


func test_an_artifact_creature_is_in_both_rows_as_1997_counts_it() -> void:
	# The 1997 matrix double-counts it too, which is why a row does not add
	# up to the deck size — see type_color_matrix's own note.
	if not CardRegistry.has_card("Clockwork Beast"):
		return
	_add("Clockwork Beast", 2)
	var matrix := deck.type_color_matrix()
	var creature_row := -1
	var artifact_row := -1
	for r in DeckModel.STAT_ROWS.size():
		if int(DeckModel.STAT_ROWS[r][1]) == Mtg.CardType.CREATURE:
			creature_row = r
		elif int(DeckModel.STAT_ROWS[r][1]) == Mtg.CardType.ARTIFACT:
			artifact_row = r
	var creatures := 0
	var artifacts := 0
	for c in DeckModel.STAT_COLUMNS.size():
		creatures += int(matrix[creature_row][c])
		artifacts += int(matrix[artifact_row][c])
	assert_eq(creatures, 2, "counted as a creature")
	assert_eq(artifacts, 2, "and as an artifact")


# ================================== THIRD AUDIT PASS (2026-09-01) ==
# THE ROUND TRIP, FIELD BY FIELD. `to_text()` wrote the banner, `name:`,
# the `# note:` lines and the card counts — and nothing else. `DeckList`
# parses `SB:` sideboard lines and `DeckGroups` reads `# group:`, so
# LOADING a deck that had either and SAVING it destroyed it silently.
# Both fields had just gone live: `Side&board between duels` plays the
# sideboard between the duels of a best-of-N match, and `# group:` decides
# the heading a deck files under in the battle-setup list.
#
# The test below is deliberately a WHOLE-FILE round trip rather than a
# check of the two fields that were missing. A test that asserts "the
# sideboard survives" catches this bug and nothing else; a test that
# asserts "the file that comes out parses to the same thing as the file
# that went in" catches the NEXT field somebody adds.

func _round_trip(path: String) -> Array:
	# in: the file as `DeckList` reads it. out: the same deck after a full
	# pass through the builder — DeckStore.load_deck -> DeckModel ->
	# to_text() -> DeckList.parse.
	#
	# BOTH READS ARE LENIENT since the proxy pass (2026-09-01), and it
	# makes no difference at all to a deck of real cards: strict and
	# lenient parse a clean file identically. What it adds is that a deck
	# holding PROXIES can be round-tripped by the same helper, and a proxy
	# is exactly the kind of entry a "does every field survive?" test has
	# to cover — it is the newest thing a deck file can carry.
	var before := DeckList.load_file(path, false)
	var report: Array = []
	var model := DeckStore.load_deck(path, report)
	assert_not_null(model, path)
	var after := DeckList.new()
	after.parse(model.to_text(), "fallback", false)
	return [before, after, model]


## Every field of the file at [param path], through the builder and back.
## Pulled out of the shipped-deck test so a PROXY deck is measured by
## exactly the same yardstick rather than by a parallel one of its own.
func _assert_survives(path: String) -> DeckModel:
	var trip := _round_trip(path)
	var before: DeckList = trip[0]
	var after: DeckList = trip[1]
	var model: DeckModel = trip[2]
	assert_eq(after.errors, [], "%s: the builder writes a readable file" % path)
	assert_eq(after.deck_name, before.deck_name, "%s: name" % path)
	var in_cards := before.cards.duplicate()
	var out_cards := after.cards.duplicate()
	in_cards.sort()
	out_cards.sort()
	assert_eq(out_cards, in_cards, "%s: every maindeck card" % path)
	var in_side := before.sideboard.duplicate()
	var out_side := after.sideboard.duplicate()
	in_side.sort()
	out_side.sort()
	assert_eq(out_side, in_side, "%s: every sideboard card" % path)
	# ...the proxies, which are the newest field and the one a strict
	# reader cannot even see.
	assert_eq(after.proxies, before.proxies, "%s: every proxy" % path)
	# ...and the two fields that ride as `#` comments, which DeckList
	# skips and so cannot report itself.
	var raw := DeckStore.read_text(path)
	assert_eq(DeckGroups.raw_in(model.to_text()), DeckGroups.raw_in(raw),
		"%s: the `# group:` declaration" % path)
	assert_eq(DeckModel.notes_from_text(model.to_text()),
		DeckModel.notes_from_text(raw), "%s: the `# note:` lines" % path)
	return model


func test_a_shipped_deck_survives_the_builder_field_by_field() -> void:
	var paths := DeckStore.deck_paths_in(DeckStore.SHIPPED_DIR)
	assert_gt(paths.size(), 0, "the project ships decks to round-trip")
	for path in paths:
		var model := _assert_survives(path)
		assert_false(model.has_proxies(),
			"%s is all real cards" % path.get_file())


func test_every_shipped_deck_really_has_both_fields_to_lose() -> void:
	# The round trip above proves nothing if the decks carry neither field.
	for path in DeckStore.deck_paths_in(DeckStore.SHIPPED_DIR):
		var listed := DeckList.load_file(path, true)
		assert_eq(listed.sideboard.size(), 15,
			"%s carries a real sideboard" % path.get_file())
		assert_ne(DeckGroups.raw_in(DeckStore.read_text(path)), "",
			"%s declares a group" % path.get_file())


func test_the_sideboard_is_written_as_SB_lines() -> void:
	deck.deck_name = "Sided"
	_add("Mountain", 4)
	assert_eq(deck.add_side("Shatter"), "")
	assert_eq(deck.add_side("Shatter"), "")
	var text := deck.to_text()
	assert_string_contains(text, "SB: 2 Shatter")
	var back := DeckList.new()
	back.parse(text, "fallback", true)
	assert_eq(back.errors, [])
	assert_eq(back.cards.size(), 4, "the sideboard did not leak into the deck")
	assert_eq(back.sideboard.size(), 2)


func test_a_deck_with_no_sideboard_writes_no_SB_line() -> void:
	_add("Mountain", 4)
	assert_false(deck.to_text().contains("SB:"))


func test_the_group_declaration_is_carried_but_never_authored() -> void:
	# The boundary the earlier pass drew: `User-created` is DERIVED from
	# the file's PATH, so a deck file cannot claim to be a 1997 original by
	# writing a line. Carrying an existing declaration through a save is
	# right; letting the builder MAKE one is not.
	deck.deck_name = "Carried"
	_add("Mountain", 4)
	assert_false(deck.to_text().contains("# group:"),
		"a deck the builder made from nothing declares nothing")
	deck.group = DeckGroups.ORIGINALS
	assert_string_contains(deck.to_text(), "# group: 1997 originals")
	# ...and carrying it still cannot forge the heading, because a deck the
	# builder saves lands in user://decks and the path decides.
	assert_eq(DeckGroups.of("user://decks/carried.deck"), DeckGroups.USER)


func test_an_unrecognised_group_line_is_carried_verbatim() -> void:
	# `declared_in` drops a value no heading matches, which is what stops a
	# typo inventing one. The BUILDER must still not rewrite the file it
	# was asked to keep.
	assert_eq(DeckGroups.declared_in("# group: Nonsense\n"), "")
	assert_eq(DeckGroups.raw_in("# group: Nonsense\n"), "Nonsense")
	deck.group = "Nonsense"
	assert_string_contains(deck.to_text(), "# group: Nonsense")


func test_clear_deck_takes_the_sideboard_and_the_group_with_it() -> void:
	deck.group = DeckGroups.STARTER
	_add("Mountain", 4)
	deck.add_side("Shatter")
	deck.clear()
	assert_eq(deck.side_total(), 0)
	assert_eq(deck.group, "")


func test_a_duplicated_model_carries_every_field() -> void:
	# This is what UNDO keeps. A field missing here is a field the player
	# loses by pressing Undo.
	deck.deck_name = "Whole"
	deck.notes = "note"
	deck.group = DeckGroups.STARTER
	_add("Mountain", 3)
	deck.add_side("Shatter")
	var copy := deck.duplicate_model()
	assert_eq(copy.deck_name, "Whole")
	assert_eq(copy.notes, "note")
	assert_eq(copy.group, DeckGroups.STARTER)
	assert_eq(copy.count_of("Mountain"), 3)
	assert_eq(copy.side_count_of("Shatter"), 1)
	copy.add_side("Shatter")
	assert_eq(deck.side_count_of("Shatter"), 1, "and the copy is not the same pile")


# ==================================================== the sideboard pile ==

func test_cards_move_both_ways_between_the_piles() -> void:
	_add("Lightning Bolt", 2)
	assert_eq(deck.to_sideboard("Lightning Bolt"), "")
	assert_eq(deck.count_of("Lightning Bolt"), 1)
	assert_eq(deck.side_count_of("Lightning Bolt"), 1)
	assert_eq(deck.to_deck("Lightning Bolt"), "")
	assert_eq(deck.count_of("Lightning Bolt"), 2)
	assert_eq(deck.side_count_of("Lightning Bolt"), 0)


func test_moving_a_card_that_is_not_there_is_refused_not_crashed() -> void:
	assert_ne(deck.to_sideboard("Lightning Bolt"), "")
	assert_ne(deck.to_deck("Lightning Bolt"), "")
	assert_eq(deck.total(), 0)
	assert_eq(deck.side_total(), 0)


func test_a_refused_move_loses_no_card() -> void:
	# The deck at the 1997 ceiling cannot take the card back, and the copy
	# must stay in the sideboard rather than evaporating in transit.
	for _i in DeckModel.MAX_TOTAL:
		deck.counts["Mountain"] = deck.count_of("Mountain") + 1
	deck.add_side("Shatter")
	assert_ne(deck.to_deck("Shatter"), "", "a full deck refuses")
	assert_eq(deck.side_count_of("Shatter"), 1, "and the card is still there")


func test_copies_are_counted_across_both_piles() -> void:
	_add("Lightning Bolt", 4)
	deck.add_side("Lightning Bolt")
	assert_eq(deck.count_of("Lightning Bolt"), 4)
	assert_eq(deck.copies_of("Lightning Bolt"), 5,
		"four in the deck and one in the sideboard is five copies")


func test_the_duplicate_advice_counts_the_sideboard() -> void:
	# Shandalar's allowance for a 40-card deck is three. Two in the deck
	# and two in the sideboard is four copies and over it, even though
	# neither pile alone is.
	_add("Lightning Bolt", 2)
	_add("Mountain", 38)
	deck.add_side("Lightning Bolt")
	deck.add_side("Lightning Bolt")
	assert_eq(DeckModel.duplicates_allowed(40), 3)
	var advice := deck.over_duplicate_limit()
	assert_eq(advice.size(), 1, "the pair over the line is reported")
	assert_string_contains(advice[0], "Lightning Bolt")
	assert_string_contains(advice[0], "sideboard")


func test_remove_extra_cards_cuts_the_sideboard_first() -> void:
	_add("Lightning Bolt", 2)
	_add("Mountain", 38)
	deck.add_side("Lightning Bolt")
	deck.add_side("Lightning Bolt")
	assert_eq(deck.trim_duplicates(), 1, "one copy over the allowance of 3")
	assert_eq(deck.count_of("Lightning Bolt"), 2, "the deck keeps its two")
	assert_eq(deck.side_count_of("Lightning Bolt"), 1, "the spare goes")


func test_the_fifteen_card_sideboard_rule_is_advice_and_never_a_refusal() -> void:
	# Fifteen is modern Magic's convention, not a 1997 rule — see the class
	# doc. So it is stated and never enforced.
	_add("Mountain", 40)
	for _i in DeckModel.SIDEBOARD_SIZE:
		assert_eq(deck.add_side("Shatter"), "")
	assert_eq(deck.sideboard_advice(), [] as Array[String], "fifteen is fine")
	assert_eq(deck.add_side("Shatter"), "", "and a sixteenth is not refused")
	assert_eq(deck.sideboard_advice().size(), 1, "it is reported instead")
	assert_eq(deck.problems(), [] as Array[String],
		"...and never as one of the DUEL's own 1997 refusals")


func test_the_sideboard_expands_for_a_duel_config() -> void:
	deck.add_side("Shatter")
	deck.add_side("Shatter")
	deck.add_side("Terror")
	var expanded := deck.to_side_list()
	assert_eq(expanded.size(), 3)
	assert_eq(expanded.count("Shatter"), 2)


func test_the_two_exports_carry_the_sideboard_too() -> void:
	deck.deck_name = "Exported"
	_add("Mountain", 4)
	deck.add_side("Shatter")
	deck.add_side("Shatter")
	var dec := DeckList.new()
	dec.parse(deck.to_dec_text(), "fallback", true)
	assert_eq(dec.errors, [])
	assert_eq(dec.sideboard.count("Shatter"), 2, ".dec carries `SB:`")
	var dck := DeckList.new()
	dck.parse_dck(deck.to_dck_text(DeckStore.dck_ids()), "fallback", true)
	assert_eq(dck.errors, [])
	assert_eq(dck.cards.count("Mountain"), 4)
	assert_eq(dck.sideboard.count("Shatter"), 2,
		"the 1997 file's `.vNone` section is the sideboard")


# ================================= [QoL] PROXIES (2026-09-01) ==
# A proxy ([ProxyCard]) is an ordinary entry in `counts` / `sideboard`
# whose name the registry does not know. That representation is what
# makes it round-trip for free — nothing is written to mark it — so the
# tests that matter here are the ones that prove NOTHING IS LOST in each
# of the three formats, and that every count rule still applies to it.
#
# `NOT_A_CARD` is deliberately not a real Magic card: a name that
# GRADUATES into the pool would turn these tests green for the wrong
# reason, and the pool grows every week.

const NOT_A_CARD := "Zzz Notional Behemoth"
const ALSO_NOT := "Zzz Notional Sprite"


func test_a_proxy_is_refused_unless_it_is_asked_for() -> void:
	# A typo in a search box must never become a proxy by accident, so
	# `add` still refuses; `add_proxy` is the deliberate door.
	assert_ne(deck.add(NOT_A_CARD), "", "not in the card pool")
	assert_eq(deck.total(), 0)
	assert_eq(deck.add_proxy(NOT_A_CARD), "", "asked for, and accepted")
	assert_eq(deck.count_of(NOT_A_CARD), 1)
	assert_eq(deck.proxy_names(), [NOT_A_CARD] as Array[String])
	assert_true(deck.has_proxies())


func test_a_proxy_needs_a_name() -> void:
	assert_ne(deck.add_proxy(""), "", "a refusal, not an entry")
	assert_ne(deck.add_proxy("   "), "")
	assert_eq(deck.total(), 0)


func test_a_proxy_counts_like_a_card_everywhere_it_is_counted() -> void:
	for _i in 3:
		deck.add_proxy(NOT_A_CARD)
	deck.add_proxy_side(NOT_A_CARD)
	assert_eq(deck.total(), 3, "three cards in the deck")
	assert_eq(deck.unique(), 1)
	assert_eq(deck.side_total(), 1)
	assert_eq(deck.copies_of(NOT_A_CARD), 4, "both piles, as any card is")
	assert_eq(deck.headline_counts()["total"], 3)


func test_the_statistics_simply_skip_a_proxy() -> void:
	# It has no cost, no type and no colour to measure. The numbers must
	# describe the cards that are really there rather than counting the
	# stand-in as a colourless nothing.
	_add("Mountain", 4)
	for _i in 4:
		deck.add_proxy(NOT_A_CARD)
	assert_eq(deck.land_count(), 4, "the four lands, not eight")
	assert_eq(deck.creature_count(), 0)
	assert_eq(deck.headline_counts()["spell"], 4,
		"a proxy is neither land nor creature, so it lands in `spell`")
	assert_eq(deck.mana_curve()[0], 0, "and it curves nowhere at all")
	assert_almost_eq(deck.average_cost(), 0.0, 0.001)


func test_a_proxy_sorts_after_every_real_card() -> void:
	# It has no colour to claim, so there is no column of `S&ort deck`'s
	# colour order it belongs in — and the cards still to be replaced
	# gathered at the end are the easiest to find.
	_add("Mountain", 1)
	_add("Serra Angel", 1)
	deck.add_proxy(NOT_A_CARD)
	assert_eq(deck.names(), ["Mountain", "Serra Angel", NOT_A_CARD])


func test_a_proxy_crosses_to_the_sideboard_and_back() -> void:
	deck.add_proxy(NOT_A_CARD)
	assert_eq(deck.to_sideboard(NOT_A_CARD), "", "across")
	assert_eq(deck.side_count_of(NOT_A_CARD), 1)
	assert_eq(deck.count_of(NOT_A_CARD), 0)
	assert_eq(deck.to_deck(NOT_A_CARD), "", "and back")
	assert_eq(deck.count_of(NOT_A_CARD), 1)
	assert_eq(deck.side_count_of(NOT_A_CARD), 0)


func test_shandalars_duplicate_advice_counts_proxies() -> void:
	# The owner's call, and it is the right one: a proxy stands in for a
	# card, so a deck built with stand-ins should still be a
	# legal-LOOKING deck — the player hears about a fifth copy while they
	# are still building rather than on the day the card graduates.
	_add("Mountain", 60)
	for _i in 5:
		deck.add_proxy(NOT_A_CARD)
	var over := deck.extra_copies()
	assert_true(over.has(NOT_A_CARD), "five of one card is one too many")
	assert_eq(int(over[NOT_A_CARD]), 1)
	assert_eq(deck.trim_duplicates(), 1, "and `Remove Extra Cards` cuts it")
	assert_eq(deck.count_of(NOT_A_CARD), 4)


func test_a_deck_of_proxies_says_it_cannot_be_played() -> void:
	for _i in 40:
		deck.add_proxy(NOT_A_CARD)
	assert_eq(deck.problems(), [] as Array[String],
		"forty cards is the right SIZE — the 1997 refusals have nothing to say")
	assert_ne(deck.proxy_problem(), "",
		"...and it still cannot be duelled with")
	assert_string_contains(deck.proxy_problem(), NOT_A_CARD,
		"the refusal names what has to be replaced")


func test_a_real_deck_has_no_proxy_problem() -> void:
	_add("Mountain", 40)
	assert_eq(deck.proxy_problem(), "")
	assert_false(deck.has_proxies())
	assert_eq(deck.proxy_names(), [] as Array[String])


func test_undo_keeps_the_proxies() -> void:
	# `duplicate_model` is what Undo, `Copy deck to` and `Clear deck` all
	# keep — a field missing there is a field the player loses.
	deck.add_proxy(NOT_A_CARD)
	deck.add_proxy_side(ALSO_NOT)
	var copy := deck.duplicate_model()
	assert_eq(copy.count_of(NOT_A_CARD), 1)
	assert_eq(copy.side_count_of(ALSO_NOT), 1)
	assert_eq(copy.proxy_names().size(), 2)


# ------------------------------- the three formats, with proxies in them --

func test_a_proxy_round_trips_through_the_deck_format() -> void:
	deck.deck_name = "Proxied"
	_add("Mountain", 4)
	for _i in 2:
		deck.add_proxy(NOT_A_CARD)
	deck.add_proxy_side(ALSO_NOT)
	var text := deck.to_text()
	assert_string_contains(text, "2 %s" % NOT_A_CARD,
		"the name goes in verbatim, with no marker of any kind")
	assert_string_contains(text, "SB: 1 %s" % ALSO_NOT)
	var back := DeckList.new()
	back.parse(text, "fallback", false)
	assert_eq(back.errors, [])
	assert_eq(back.deck_name, "Proxied")
	assert_eq(back.cards.count(NOT_A_CARD), 2)
	assert_eq(back.sideboard.count(ALSO_NOT), 1)
	assert_eq(back.proxies.size(), 2, "and both read back as proxies")
	var model := DeckModel.from_deck_list(back)
	assert_eq(model.count_of(NOT_A_CARD), 2)
	assert_eq(model.side_count_of(ALSO_NOT), 1)


func test_a_proxy_round_trips_through_the_decklist_export() -> void:
	deck.deck_name = "Proxied Dec"
	for _i in 3:
		deck.add_proxy(NOT_A_CARD)
	deck.add_proxy_side(ALSO_NOT)
	var back := DeckList.new()
	back.parse(deck.to_dec_text(), "fallback", false)
	assert_eq(back.errors, [])
	assert_eq(back.deck_name, "Proxied Dec")
	assert_eq(back.cards.count(NOT_A_CARD), 3)
	assert_eq(back.sideboard.count(ALSO_NOT), 1)


func test_a_proxy_round_trips_through_the_1997_dck_export() -> void:
	# THE `.dck` ID QUESTION. `to_dck_text` wants a numeric MicroProse id
	# per card and a proxy has none — so it takes `.0`, which is not a new
	# rule but the one already there for any card the 371-entry table does
	# not name (`tools/deck_convert.gd` emits the same). The original's own
	# loader tolerates it because NAMES ARE AUTHORITATIVE in that format
	# and the ids are ignored on read, which is also why a proxy survives
	# the trip intact.
	deck.deck_name = "Proxied Dck"
	_add("Mountain", 2)
	for _i in 3:
		deck.add_proxy(NOT_A_CARD)
	deck.add_proxy_side(ALSO_NOT)
	var text := deck.to_dck_text(DeckStore.dck_ids())
	assert_string_contains(text, ".0\t3\t%s" % NOT_A_CARD,
		"no id, so id 0 — exactly as an unknown real card is written")
	var back := DeckList.new()
	back.parse_dck(text, "fallback", false)
	assert_eq(back.errors, [], "the MicroProse parser reads it back")
	assert_eq(back.deck_name, "Proxied Dck")
	assert_eq(back.cards.count(NOT_A_CARD), 3)
	assert_eq(back.cards.count("Mountain"), 2)
	assert_eq(back.sideboard.count(ALSO_NOT), 1,
		"the `.vNone` section carries it")


func test_a_deck_with_proxies_survives_the_builder_field_by_field() -> void:
	# The SAME yardstick the shipped decks are held to, on a deck that
	# holds every field at once — a title, notes, a group, a sideboard,
	# and proxies in both piles.
	var path := "user://decks/_gut_proxy_trip.deck"
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(DeckStore.USER_DIR))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("# group: 1997 originals\nname: Proxy Trip\n"
		+ "# note: waiting on two cards\n"
		+ "20 Mountain\n4 Lightning Bolt\n3 %s\n"
		% NOT_A_CARD + "\nSB: 2 Shatter\nSB: 1 %s\n" % ALSO_NOT)
	file.close()
	var model := _assert_survives(path)
	assert_eq(model.count_of(NOT_A_CARD), 3, "the maindeck proxy, all copies")
	assert_eq(model.side_count_of(ALSO_NOT), 1, "and the sideboard one")
	assert_eq(model.notes, "waiting on two cards")
	assert_eq(model.proxy_names(), [NOT_A_CARD, ALSO_NOT] as Array[String])
	assert_ne(model.proxy_problem(), "", "and it knows it cannot be played")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
