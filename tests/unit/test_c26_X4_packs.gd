extends GutTest
## THE 0.60.13 BUG CAMPAIGN, X4 — packs and saves: a campaign's cards when
## its pack is off or gone (h3-1), the load list's days (h1-2), a creature's
## words on the island without the flag (h2-6), the Help (h3-3) and the shop
## place whose pack is unavailable (the owner's polish, 2026-11-03).

const FOLDER := "user://c26_x4_saves"

var _enabled_before: Array[String] = []
var _launch_before := false
## Pack reports taken out of [code]CardPacks._available[/code] by a test, put
## back after it: a pack "not installed".
var _hidden := {}


func before_each() -> void:
	_launch_before = AdventureExpansions.launch_enabled
	_enabled_before = Settings.enabled_card_packs().duplicate()
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	AdventurePlayer.saves_folder = FOLDER
	_clear()


func after_each() -> void:
	_clear()
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	for id in _hidden:
		CardPacks._available[id] = _hidden[id]
	_hidden.clear()
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id) != (id in _enabled_before):
			CardPacks.set_enabled(id, id in _enabled_before)
	AdventureExpansions.read_launch(PackedStringArray([AdventureExpansions.LAUNCH_FLAG]) if _launch_before else PackedStringArray())


func _clear() -> void:
	var dir := DirAccess.open(FOLDER)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
	AdventurePlayer.forget_saves()


## A cards-only Pack 2 campaign (no island), three Thallids in the deck in use.
func _hero() -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.player_name = "Mira Thorn"
	setup.seed_text = "48271"
	setup.packs = [FallenEmpiresPack.ID]
	var record := setup.resolve({FallenEmpiresPack.ID: "1.0.0"})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	for i in 3:
		player.cards.append({"card": "Thallid", "decks": [player.current_deck]})
	return player


## Pack [param id] as if it were not installed (its report put back after).
func _uninstall(id: String) -> void:
	CardPacks.set_enabled(id, false)
	_hidden[id] = CardPacks._available[id]
	CardPacks._available.erase(id)


# ------------------------------------------------------------------ h3-1 --

func test_a_campaign_whose_pack_is_off_enables_it_as_it_is_taken_up() -> void:
	var path := _hero().autosave()
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	assert_false(CardRegistry.has_card("Thallid"), "control: the pack is off")
	var screen := LoadAdventureScreen.open_save(path)
	assert_not_null(screen, "an installed pack never refuses the campaign")
	if screen == null:
		return
	assert_true(CardPacks.is_enabled(FallenEmpiresPack.ID), "the pack enabled, as setting out enables it")
	assert_true(CardRegistry.has_card("Thallid"))
	assert_string_contains(screen.arrival, "Pack 2 · Fallen Empires", "the arrival says so, naming the pack")
	assert_eq(screen.player.deck_cards().count("Thallid"), 3, "the deck whole again")
	screen.free()


func test_a_campaign_whose_pack_is_on_says_nothing_of_packs() -> void:
	var path := _hero().autosave()
	var screen := LoadAdventureScreen.open_save(path)
	assert_not_null(screen)
	if screen == null:
		return
	assert_eq(screen.arrival, "Mira Thorn takes up the adventure again.")
	screen.free()


func test_a_campaign_whose_pack_is_not_installed_is_refused_and_names_it() -> void:
	var player := _hero()
	player.packs.append({"id": TempestBlockPack.ID, "version": "1.0.0"})
	var path := player.autosave()
	_uninstall(TempestBlockPack.ID)
	var screen := LoadAdventureScreen.open_save(path)
	assert_null(screen, "a missing pack refuses (the owner, 2026-10-28)")
	if screen != null:
		screen.free()
	var answer := AdventurePacks.resume(AdventurePlayer.load_from(path))
	assert_string_contains(String(answer["refusal"]), "Pack 9 (Pack-9-Tempest-Block.zip)")
	assert_string_contains(String(answer["refusal"]), "Options › Card Packs")


func test_resume_ignores_pack_one_and_a_campaign_without_packs() -> void:
	var player := _hero()
	player.packs.clear()
	var none := AdventurePacks.resume(player)
	assert_eq(String(none["refusal"]), "")
	assert_eq((none["enabled"] as Array).size(), 0)
	player.packs = [{"id": "pack-1", "version": "1"}, "junk", {"id": 7}]
	assert_eq(String(AdventurePacks.resume(player)["refusal"]), "", "Pack 1 is never a campaign's")


func test_resume_names_two_missing_packs_and_a_pack_this_build_does_not_know() -> void:
	var player := _hero()
	player.packs = [{"id": "pack-77", "version": "1"}, {"id": TempestBlockPack.ID, "version": "1"}]
	_uninstall(TempestBlockPack.ID)
	var refusal := String(AdventurePacks.resume(player)["refusal"])
	assert_string_contains(refusal, "card packs Pack 77 and Pack 9 (Pack-9-Tempest-Block.zip)")
	assert_string_contains(refusal, "Add them in Options › Card Packs")


func test_no_duel_or_stake_counts_a_card_the_game_does_not_know() -> void:
	var player := _hero()
	var known := player.deck_cards().size()
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	assert_false(player.deck_cards().has("Thallid"), "the deck in use as a duel deals it")
	assert_eq(player.deck_cards().size(), known - 3)
	for at in CreatureMeeting.usable_cards(player):
		assert_true(CardRegistry.has_card(String(player.cards[at]["card"])), "never staked: " + String(player.cards[at]["card"]))
	# Every stake the dice could draw is a card in the duel.
	for row in [10, 20, 30, 40]:
		var meeting := CreatureMeeting.meet(player, row, 4, -1, player.position)
		for card in meeting["hero_ante"]:
			assert_true(CardRegistry.has_card(String(card)), "staked: " + String(card))
	var config := CreatureMeeting.duel_config(player, CreatureMeeting.meet(player, 10, 4, -1, player.position))
	assert_false((config.decks[0] as Array).has("Thallid"), "the duel deck holds only cards the game knows")
	assert_eq(player.deck_cards(true).count("Thallid"), 3, "a check that must refuse such a deck still sees them")


func test_the_dominant_color_skips_an_unknown_card_quietly() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	assert_eq(DuelConfig.dominant_color(["Thallid", "Thallid", "Thallid", "Lightning Bolt"]), "red",
		"no ERROR line for the unknown cards (they made the world's warm-up print them)")


# ------------------------------------------------------------------ h1-2 --

func test_the_load_list_counts_the_whole_journey_not_the_regions_clock() -> void:
	var player := _hero()
	player.quest_timer = 2 * WorldStatus.DAY
	player.journey_time = 42 * WorldStatus.DAY
	assert_eq(int(AdventurePlayer._summary(player.to_dict())["days"]), 42, "as the hero pane counts them")
	assert_eq(int(AdventurePlayer._summary(player.to_dict())["days"]), WorldStatus.days_on_road(player))
	var old := player.to_dict()
	old.erase("journey")
	old["version"] = 3
	assert_eq(int(AdventurePlayer._summary(old)["days"]), 2, "a save from before the journey's clock: its own")
	old["version"] = 4
	old["regions"] = {"refuge": {"clocks": {"quest_timer": 5 * WorldStatus.DAY}}}
	assert_eq(int(AdventurePlayer._summary(old)["days"]), 7, "version 4: the regions summed, as the load sums them")


func test_an_island_save_lists_the_days_of_the_whole_journey() -> void:
	_launch_on()
	var player := _island_hero()
	player.quest_timer = 40 * WorldStatus.DAY
	player.journey_time = 40 * WorldStatus.DAY
	assert_true(RefugeCampaign.travel(player))
	player.quest_timer += 2 * WorldStatus.DAY
	player.journey_time += 2 * WorldStatus.DAY
	var path := player.autosave()
	assert_eq(int(AdventurePlayer.save_at(path)["days"]), 42, "day 42 on the list, as the hero pane says")
	assert_true(RefugeCampaign.travel(player))
	assert_eq(int(AdventurePlayer._summary(player.to_dict())["days"]), 42, "and back home")


func test_an_old_island_save_lists_its_mainland_seed() -> void:
	_launch_on()
	var player := _island_hero()
	assert_true(RefugeCampaign.travel(player))
	var data := player.to_dict()
	data["world"]["seed_text"] = ""
	assert_eq(String(AdventurePlayer._summary(data)["seed_text"]), "48271",
		"an island saved before its seed text was kept (h1-3) shows the mainland's")


# ------------------------------------------------------------------ h2-6 --

func test_an_island_meeting_without_the_flag_still_has_words() -> void:
	_launch_on()
	var player := _island_hero()
	assert_true(RefugeCampaign.travel(player), "on the island")
	AdventureExpansions.read_launch(PackedStringArray())
	var meeting := CreatureMeeting.meet(player, 10, 1, -1, player.position)
	var said := CreatureMeeting.words(player, meeting)
	assert_false(said.is_empty(), "a meeting says something")
	assert_eq(said, CreatureMeeting.lines_of(CreatureMeeting.ROAMING))
	assert_false(" ".join(said).contains("expanded"), "nothing of the prototype")
	meeting["wins"] = CreatureMeeting.TRIBUTE_WINS
	assert_eq(CreatureMeeting.words(player, meeting), CreatureMeeting.lines_of(CreatureMeeting.ROAMING_TRIBUTE))
	_launch_on()
	meeting["wins"] = 0
	assert_ne(CreatureMeeting.words(player, meeting), CreatureMeeting.lines_of(CreatureMeeting.ROAMING),
		"with the flag the island's own words")


func _launch_on() -> void:
	AdventureExpansions.read_launch(PackedStringArray([AdventureExpansions.LAUNCH_FLAG]))


## A Pack 2 campaign with the island (the flag on), on the mainland.
func _island_hero() -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.expanded_adventure = true
	setup.packs = [FallenEmpiresPack.ID]
	setup.seed_text = "48271"
	var record := setup.resolve({FallenEmpiresPack.ID: "1"})
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))


# ------------------------------------------------------- the shop's place --

func test_a_shelf_card_whose_pack_is_gone_names_it_and_restocks_in_time() -> void:
	var player := _hero()
	var slot := _town(player)
	CardShop.offers(player, slot)
	var shop := CardShop.town_record(player, slot)
	shop["cards"][1] = "Thallid"
	shop["restock"][1] = CardShop.NEVER_FILLED
	player.gold = 10000
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	var answer := CardShop.buy(player, slot, 1)
	assert_false(answer["bought"])
	assert_eq(String(answer["said"]), "Enable this card's pack, Pack 2 · Fallen Empires, to buy it.")
	assert_eq(CardShop.offers(player, slot)[1], "Thallid", "it waits as a sold place, from when it was found so")
	# Its wait over, on a visit from another town: a card on offer takes it.
	player.quest_timer += 200
	player.last_town = -1
	var now := CardShop.offers(player, slot)[1]
	assert_ne(now, "Thallid")
	assert_true(now == "" or CardRegistry.has_card(now), "restocked with a card on offer: " + now)
	assert_false(shop.has(CardShop.UNAVAILABLE), "nothing waits any more")


func test_a_shelf_card_whose_pack_comes_back_is_on_offer_again() -> void:
	var player := _hero()
	var slot := _town(player)
	CardShop.offers(player, slot)
	var shop := CardShop.town_record(player, slot)
	shop["cards"][1] = "Thallid"
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	CardShop.offers(player, slot)
	assert_true(shop.has(CardShop.UNAVAILABLE))
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	player.quest_timer += 200
	player.last_town = -1
	assert_eq(CardShop.offers(player, slot)[1], "Thallid", "back before its wait was over")
	assert_false(shop.has(CardShop.UNAVAILABLE))


func test_the_shop_names_a_pack_not_installed_too() -> void:
	_uninstall(TempestBlockPack.ID)
	var card: String = TempestBlockPack.new_names()[0]
	assert_eq(AdventurePacks.card_pack(card), TempestBlockPack.ID)
	assert_eq(AdventurePacks.card_refusal(card), "Install this card's pack, Pack 9 (Pack-9-Tempest-Block.zip), to buy it.")
	assert_eq(CardShopPane.unavailable_words(card), "Pack 9\nunavailable")
	assert_eq(CardShopPane.unavailable_words("No Such Card"), "Pack unavailable")


## A town or city of [param player]'s world that sells cards.
func _town(player: AdventurePlayer) -> int:
	for slot in player.world.sites.size():
		if int(player.world.sites[slot]["type"]) in [ShandalarWorld.TOWN, ShandalarWorld.CITY]:
			return slot
	return 1
