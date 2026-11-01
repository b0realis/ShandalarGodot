extends GutTest
## Regional reward lists and unavailable saved stock through the real panes.

var player: AdventurePlayer
var pack_was_enabled := false

func before_each() -> void:
	pack_was_enabled = CardPacks.is_enabled(FallenEmpiresPack.ID)
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	var record := setup.resolve({})
	player = AdventurePlayer.begin(record, AdventureSetup.make_world(record))

func after_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, pack_was_enabled)

func test_choose_any_card_list_includes_island_cards_only_when_unlocked() -> void:
	var pane := EncounterPane.new()
	pane.player = player
	add_child_autofree(pane)
	pane._pick_any()
	assert_false(pane._list.cards.has("Thallid"))
	assert_true(RefugeCampaign.travel(player))
	pane._pick_any()
	assert_true(pane._list.cards.has("Thallid"))
	assert_true(pane._list.cards.has("Grizzly Bears"))
	pane._close_list()
	await get_tree().process_frame

func test_shop_disables_unknown_saved_card_and_restores_it_when_pack_returns() -> void:
	assert_true(RefugeCampaign.travel(player))
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
