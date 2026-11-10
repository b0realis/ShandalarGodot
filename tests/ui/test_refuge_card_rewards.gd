extends GutTest
## Regional reward lists and unavailable saved stock through the real panes.

var player: AdventurePlayer
var pack_was_enabled := false


func before_each() -> void:
	pack_was_enabled = CardPacks.is_enabled(FallenEmpiresPack.ID)
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	var setup := AdventureSetup.new()
	setup.adventures = ["refuge"]
	setup.packs = ["pack-2"]
	setup.seed_text = "48271"
	var record := setup.resolve({"pack-2": "1"})
	player = AdventurePlayer.begin(record, AdventureSetup.make_world(record))

func after_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, pack_was_enabled)

## Adventure plugins (2026-11-10, §0.2): the ticked pack's cards are in the
## list on the mainland as on the island; the plugin never withholds them.
func test_choose_any_card_list_includes_the_ticked_packs_cards_everywhere() -> void:
	var pane := EncounterPane.new()
	pane.player = player
	add_child_autofree(pane)
	pane._pick_any()
	assert_true(pane._list.cards.has("Thallid"), "on the mainland")
	assert_true(_refuge().travel(player))
	pane._pick_any()
	assert_true(pane._list.cards.has("Thallid"))
	assert_true(pane._list.cards.has("Grizzly Bears"))
	pane._close_list()
	await get_tree().process_frame

func test_shop_disables_unknown_saved_card_and_restores_it_when_pack_returns() -> void:
	assert_true(_refuge().travel(player))
	CardShop.offers(player, 1)
	CardShop.town_record(player, 1)["cards"][0] = "Thallid"
	player.gold = 10000
	var pane := CardShopPane.new()
	pane.player = player
	pane.slot = 1
	add_child_autofree(pane)
	pane.choose(0)
	assert_false(pane._buy.disabled)
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	pane.refresh()
	assert_true(pane._buy.disabled)
	assert_string_contains(pane.ask_text(), "Enable this card's pack")
	await get_tree().process_frame
	assert_false(bool(pane._row.get_child(0).get_meta("available")))
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	pane.refresh()
	await get_tree().process_frame
	assert_true(bool(pane._row.get_child(0).get_meta("available")))
	assert_false(pane._buy.disabled)

func test_island_builder_counts_live_nonlands_and_journal_clues_use_distinct_inks() -> void:
	assert_true(_refuge().travel(player))
	var builder := AdventureBuilder.new()
	builder.player = player
	add_child_autofree(builder)
	await get_tree().process_frame
	builder.deck.clear()
	builder.deck.add("Thallid")
	builder.deck.add("Grizzly Bears")
	builder.deck.add("Forest")
	assert_string_contains(builder._resting_line(), "FE nonlands 1/2")
	builder.deck.add("Grizzly Bears")
	assert_string_contains(builder._resting_line(), "need 2")
	var stats := HeroStats.new()
	stats.player = player
	add_child_autofree(stats)
	var clue := stats._journal_label("Seek the vault.", {"event": "clue", "highlight": true})
	var quest := stats._journal_label("Carry the warrant.", {"event": "quest_clue", "highlight": true})
	assert_ne(clue.get_theme_color("font_color"), quest.get_theme_color("font_color"))
	assert_eq(quest.get_theme_color("font_color"), HeroStats.GOLD)
	clue.free()
	quest.free()
	builder.queue_free()
	stats.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func test_stale_trade_is_refused_and_removed_from_the_real_pane() -> void:
	assert_true(_refuge().travel(player))
	player.amulets["green"] = 10
	var pane := CardTradePane.new()
	pane.player = player
	pane.way = CardTrade.TOWN
	pane.color = "green"
	add_child_autofree(pane)
	pane.choose("Thallid")
	assert_false(pane._yes.disabled)
	var count := player.cards.size()
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	pane.trade_chosen()
	assert_eq(player.amulets["green"], 10)
	assert_eq(player.cards.size(), count)
	assert_eq(pane.chosen, "")
	assert_true(pane._yes.disabled)
	assert_false(pane._large.visible)
	assert_string_contains(pane._note.text, "no longer available")
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	pane.refresh()
	pane.choose("Thallid")
	pane.trade_chosen()
	assert_eq(player.cards.size(), count + 1)
	assert_eq(player.amulets["green"], 9)

## The prototype plugin's interpreter ([DataRegion]).
func _refuge() -> DataRegion:
	return AdventureExpansions.provider("refuge") as DataRegion
