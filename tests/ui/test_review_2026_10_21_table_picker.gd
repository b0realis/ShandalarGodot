extends GutTest
## TEST HANDS: ONLY A PERMANENT GOES ON THE TABLE (review 2026-10-21,
## engine-5, the screen's half).
##
## The picker for `On the table` listed every card of the deck — or of the
## pool, with `Any card in the pool` — so a Lightning Bolt could be put on
## the battlefield and stayed there as a permanent for the rest of the
## duel, where `Destroy target permanent` could see it: a state no game
## can reach. The table's picker now lists permanents only; the hand, the
## graveyard and the top of the library still list everything. (The
## engine's half — [DuelPosition] refusing a non-permanent on the table,
## for a test saved before this — is `engine/duel_position.gd`'s.)

var bench: TestHandsScreen


func before_each() -> void:
	Settings.clear_value(TestHandsScreen.LAST_KEY)
	# White Knights in Seat 1: Swords to Plowshares and Disenchant are its
	# instants, Serra Angel and Plains its permanents.
	var config := DuelConfig.vs_ai_default(AiProfile.wizard())
	bench = load("res://game/test_hands_screen.tscn").instantiate()
	bench.config = config
	add_child_autofree(bench)
	await get_tree().process_frame


func after_each() -> void:
	Settings.clear_value(TestHandsScreen.LAST_KEY)


func _listed(zone: String, search: String, any := false) -> Array[String]:
	bench.open_picker(0, zone)
	bench._picker_any.button_pressed = any
	bench._picker_search.text = search
	bench._fill_picker()
	var out: Array[String] = []
	for i in bench._picker_list.item_count:
		var meta: Variant = bench._picker_list.get_item_metadata(i)
		if meta != null:
			out.append(String(meta))
	bench.close_picker()
	return out


func test_the_tables_picker_leaves_out_the_decks_instants() -> void:
	var table := _listed(DuelPosition.TABLE, "")
	assert_false(table.has("Swords to Plowshares"), "an instant is not a permanent")
	assert_false(table.has("Disenchant"))
	assert_true(table.has("Serra Angel"), "a creature is")
	assert_true(table.has("Plains"), "and a land is")


func test_the_tables_picker_leaves_out_the_pools_instants_and_sorceries() -> void:
	assert_eq(_listed(DuelPosition.TABLE, "Lightning Bolt", true), [] as Array[String],
		"Any card in the pool: still no instant")
	assert_eq(_listed(DuelPosition.TABLE, "Wrath of God", true), [] as Array[String],
		"and no sorcery")
	assert_true(_listed(DuelPosition.TABLE, "Ashnod's Altar", true).has("Ashnod's Altar"),
		"an artifact is a permanent")


func test_the_other_places_still_list_every_card() -> void:
	assert_true(_listed(DuelPosition.HAND, "").has("Swords to Plowshares"))
	assert_true(_listed(DuelPosition.GRAVEYARD, "Lightning Bolt", true).has("Lightning Bolt"))
	assert_true(_listed(DuelPosition.LIBRARY_TOP, "Wrath of God", true).has("Wrath of God"))
