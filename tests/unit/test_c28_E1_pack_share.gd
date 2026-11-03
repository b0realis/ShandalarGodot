extends GutTest
## THE PACK SHARE OF EVERY RANDOM CARD DRAW (0.60.14, the owner's pack
## rulings of 2026-11-03): each activated pack `min(20%, 60% / N)`, all
## packs `min(20% × N, 60%)`, the rest base cards — in shops, duel spoils
## and lairs ([PackShare]). Seeded counts over thousands of draws, each
## within two points of the rule.

const DRAWS := 10000
const SPREAD := 0.02

var _packs: Array[String] = []
var _owner := {}


func before_each() -> void:
	_packs = Settings.enabled_card_packs().duplicate()
	if _owner.is_empty():
		for card in FallenEmpiresPack.names(): _owner[card] = FallenEmpiresPack.ID
		for card in IceAgePack.new_names(): _owner[card] = IceAgePack.ID
		for card in HomelandsPack.new_names(): _owner[card] = HomelandsPack.ID
		for card in AlliancesPack.new_names(): _owner[card] = AlliancesPack.ID
		for card in PortalPack.new_names(): _owner[card] = PortalPack.ID
		for card in MirageBlockPack.new_names(): _owner[card] = MirageBlockPack.ID
		for card in TempestBlockPack.new_names(): _owner[card] = TempestBlockPack.ID


func after_each() -> void:
	_switch(_packs)
	AdventureSetup.forget()
	CardValue.forget()
	CardShop.forget()
	CardTrade.forget()
	LairEvent.forget()
	AdventurePacks.forget()


func _switch(on: Array) -> void:
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id) != (id in on):
			CardPacks.set_enabled(id, id in on)


## A hero of [param selected], those packs switched on, with a 60-card deck
## in use (no copy limit near).
func _hero(selected: Array) -> AdventurePlayer:
	_switch(selected)
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	var ids: Array[String] = []
	ids.assign(selected)
	setup.packs = ids
	var versions := {}
	for id in ids:
		versions[id] = "1"
	var record := setup.resolve(versions)
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	player.cards.clear()
	for i in 60:
		player.cards.append({"card": "Forest", "decks": [0]})
	return player


func _town(player: AdventurePlayer) -> int:
	for slot in player.world.sites.size():
		if int(player.world.sites[slot]["type"]) in [ShandalarWorld.TOWN, ShandalarWorld.CITY]:
			return slot
	return 1


## The share of [param cards] by side: "base", each pack's id, and "packs"
## for all pack cards; a Fifth Edition card counts to its own pack.
func _shares(cards: Array) -> Dictionary:
	var out := {"base": 0.0, "packs": 0.0}
	for card in cards:
		var side := "base" if CardTrade.in_adventure(String(card)) else String(_owner.get(card, "?"))
		out[side] = float(out.get(side, 0.0)) + 1.0
		if side != "base":
			out["packs"] = float(out["packs"]) + 1.0
	for key in out:
		out[key] = float(out[key]) / maxf(cards.size(), 1)
	return out


func _near(got: float, want: float, what: String, spread := SPREAD) -> void:
	var words := "%s: %.1f%% for %.1f%%" % [what, got * 100.0, want * 100.0]
	gut.p(words)
	assert_almost_eq(got, want, spread, words)


## [param draws] shop places of every kind in one town selling every colour.
func _shelves(selected: Array, draws := DRAWS) -> Array[String]:
	var player := _hero(selected)
	var rules := CardShop._draw_rules(player, _town(player))
	rules["sold"] = CardShop.COLOR_BITS.duplicate()
	var dice := MsvcRandom.new(20261103)
	var out: Array[String] = []
	for i in draws:
		out.append(CardShop._draw(i % 6, false, dice, rules))
	return out


func test_the_rule_s_numbers() -> void:
	assert_eq([PackShare.share(0), PackShare.share(1), PackShare.share(2), PackShare.share(3), PackShare.share(8)],
		[0, 20, 40, 60, 60])
	var dice := MsvcRandom.new(5)
	assert_eq(PackShare.side(dice, 0, [0, 0]), PackShare.NONE, "nothing fits")
	assert_eq(PackShare.side(dice, 3, [0, 0]), PackShare.BASE, "no pack card fits: a base card")
	assert_eq(PackShare.side(dice, 0, [0, 4]), 1, "no base card fits: a pack card")
	assert_eq(dice.state, 5, "no die for a side that cannot be")
	assert_eq(PackShare.pick(dice, ["Forest"], []), "Forest")


func test_one_pack_has_a_fifth_of_the_shop_places() -> void:
	var got := _shares(_shelves(["pack-2"]))
	_near(float(got["packs"]), 0.2, "Pack 2")
	assert_eq(float(got.get("?", 0.0)), 0.0, "every card is base or a chosen pack's")


func test_two_packs_have_two_fifths() -> void:
	var got := _shares(_shelves(["pack-2", "pack-3"]))
	_near(float(got["packs"]), 0.4, "all packs")
	_near(float(got.get("pack-2", 0.0)), 0.2, "Pack 2")
	_near(float(got.get("pack-3", 0.0)), 0.2, "Pack 3")


func test_three_packs_have_three_fifths_and_no_more() -> void:
	var got := _shares(_shelves(["pack-2", "pack-3", "pack-4"]))
	_near(float(got["packs"]), 0.6, "all packs")
	for id in ["pack-2", "pack-3", "pack-4"]:
		_near(float(got.get(id, 0.0)), 0.2, id)


func test_eight_packs_share_three_fifths() -> void:
	var all := ["pack-2", "pack-3", "pack-4", "pack-5", "pack-6", "pack-7", "pack-8", "pack-9"]
	var got := _shares(_shelves(all))
	_near(float(got["packs"]), 0.6, "all packs")
	for id in ["pack-5", "pack-6", "pack-8", "pack-9"]:
		_near(float(got.get(id, 0.0)), 0.075, id)
	# Fifth Edition's own share falls on its cards' packs: those four, 30%.
	_near(float(got.get("pack-2", 0.0)) + float(got.get("pack-3", 0.0)) + float(got.get("pack-4", 0.0)), 0.3, "Packs 2, 3, 4 and 7")


func test_duel_spoils_keep_the_share() -> void:
	for selected in [["pack-2"], ["pack-2", "pack-3", "pack-4"]]:
		var player := _hero(selected)
		var meeting := {"row": 1, "color": 3, "strength": 3 * DRAWS, "creature_ante": []}
		var cards := DuelSpoils.reward_cards(player, meeting, MsvcRandom.new(11))
		assert_gt(cards.size(), DRAWS, "picks")
		var got := _shares(cards.slice(0, DRAWS))
		_near(float(got["packs"]), PackShare.share(selected.size()) / 100.0, "spoils with %d packs" % selected.size())


func test_the_artifact_for_the_next_duel_keeps_the_share() -> void:
	var player := _hero(["pack-2", "pack-3", "pack-4"])
	var dice := MsvcRandom.new(17)
	var cards: Array[String] = []
	for i in 2000:
		cards.append(DuelSpoils._random_artifact(dice, player))
	_near(float(_shares(cards)["packs"]), 0.6, "the artifact for the next duel, three packs", 0.03)


func test_lair_draws_keep_the_share() -> void:
	var player := _hero(["pack-2", "pack-3", "pack-4"])
	var draws := {"the rare of any kind": [], "the lair's rare": [], "the treasure": []}
	var dice := MsvcRandom.new(3)
	for i in 2000:
		draws["the rare of any kind"].append(LairEvent.rare_of_any_kind(dice, {}, player))
		draws["the lair's rare"].append(LairEvent._lair_rare(player, dice, 1 + i % 5))
		draws["the treasure"].append(LairEvent._treasure(dice, 1 + i % 5, {}, player))
	for what in draws:
		_near(float(_shares(draws[what])["packs"]), 0.6, what + ", three packs", 0.03)


func test_a_place_no_pack_card_fits_takes_a_base_card_and_the_other_way() -> void:
	var player := _hero(["pack-2"])
	var rules := CardShop._draw_rules(player, _town(player))
	rules["sold"] = CardShop.COLOR_BITS.duplicate()
	var thallid := {"name": "Thallid", "facts": CardValue.facts(CardRegistry.get_card("Thallid"))}
	rules["base"] = [] as Array[Dictionary]
	rules["packs"] = [[thallid]]
	rules["stock"] = [thallid]
	for seed in range(1, 21):
		assert_eq(CardShop._draw(0, false, MsvcRandom.new(seed), rules), "Thallid", "no base card fits: the pack's")
	rules = CardShop._draw_rules(player, _town(player))
	rules["sold"] = CardShop.COLOR_BITS.duplicate()
	rules["packs"] = [[] as Array[Dictionary]]
	var dice := MsvcRandom.new(99)
	for place in 60:
		assert_true(CardTrade.in_adventure(CardShop._draw(place % 6, false, dice, rules)),
			"no pack card fits: a base card")
