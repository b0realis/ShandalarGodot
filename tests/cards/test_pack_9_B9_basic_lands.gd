extends GameTest
## Pack 9 (the Tempest block), batch B9: the Stronghold names of
## cards/sets/sth/_basic.gd (Skyshroud Falcon, Wall of Razors, Youthful
## Knight — printed characteristics only) and cards/sets/sth/_lands_mana.gd
## (Mox Diamond's entry payment, Skyshroud Troopers, Volrath's Stronghold).

const CLAIMED := ["Skyshroud Falcon", "Wall of Razors", "Youthful Knight",
	"Mox Diamond", "Skyshroud Troopers", "Volrath's Stronghold"]


## A seat whose card answers a test scripts: names to prefer (else the
## first candidate), or a declined question.
class Seat extends DecisionAgent:
	var prefer: Array = []
	var decline := false
	var asked: Array = []

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		if decline: return null
		for name in prefer:
			for c in candidates:
				if c.data.card_name == name: return c
		return null if candidates.is_empty() else candidates[0]


var me: Seat


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	CardRegistry.ensure_loaded()
	super()
	me = Seat.new()
	g.set_agent(0, me)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)


func test_claimed_cards_are_no_longer_pending() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending",
			"%s is still pending" % card_name)


# --------------------------------------------------------------- _basic --

func test_the_keyword_creatures_carry_their_printed_keywords() -> void:
	var falcon := put_battlefield(0, "Skyshroud Falcon")
	var wall := put_battlefield(0, "Wall of Razors")
	var knight := put_battlefield(0, "Youthful Knight")
	assert_eq([falcon.cur_power, falcon.cur_toughness], [1, 1])
	assert_true(falcon.has_keyword(Mtg.Keyword.FLYING))
	assert_true(falcon.has_keyword(Mtg.Keyword.VIGILANCE))
	assert_eq([wall.cur_power, wall.cur_toughness], [4, 1])
	assert_true(wall.has_keyword(Mtg.Keyword.DEFENDER))
	assert_true(wall.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_eq([knight.cur_power, knight.cur_toughness], [2, 1])
	assert_true(knight.has_keyword(Mtg.Keyword.FIRST_STRIKE))


func test_wall_of_razors_cannot_attack_and_the_falcon_attacks_untapped() -> void:
	var wall := put_battlefield(0, "Wall of Razors")
	var falcon := put_battlefield(0, "Skyshroud Falcon")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [wall.id]), "")
	assert_ok(g.declare_attackers(0, [falcon.id]))
	assert_false(falcon.tapped, "vigilance")


# ---------------------------------------------------------- Mox Diamond --

func test_mox_diamond_enters_by_discarding_a_land_card() -> void:
	var mox := give_hand(0, "Mox Diamond")
	var forest := give_hand(0, "Forest")
	var bear := give_hand(0, "Grizzly Bears")
	assert_ok(g.cast_spell(0, mox))
	resolve_stack()
	assert_eq(mox.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD, "the land card was discarded instead")
	assert_eq(bear.zone, Mtg.Zone.HAND, "only a land card may pay")
	assert_ok(g.tap_for_mana(0, mox, 1))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 1, "any colour (WUBRG rows)")
	assert_eq(mox.data.mana_abilities.size(), 5)


func test_mox_diamond_without_a_land_card_goes_to_the_graveyard() -> void:
	var mox := give_hand(0, "Mox Diamond")
	var bear := give_hand(0, "Grizzly Bears")
	assert_ok(g.cast_spell(0, mox))
	resolve_stack()
	assert_eq(mox.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.HAND)


func test_mox_diamond_discard_may_be_declined() -> void:
	var mox := give_hand(0, "Mox Diamond")
	var forest := give_hand(0, "Forest")
	me.decline = true
	assert_ok(g.cast_spell(0, mox))
	resolve_stack()
	assert_eq(mox.zone, Mtg.Zone.GRAVEYARD, "if you don't, its owner's graveyard")
	assert_eq(forest.zone, Mtg.Zone.HAND)


func test_mox_diamond_put_onto_the_battlefield_still_asks() -> void:
	var mox := give_hand(0, "Mox Diamond")
	var island := give_hand(0, "Island")
	g.put_from_hand_into_play(mox, 0)
	assert_eq(mox.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(island.zone, Mtg.Zone.GRAVEYARD)


# -------------------------------------------------- Skyshroud Troopers --

func test_skyshroud_troopers_tap_for_green_once_unsick() -> void:
	var sick := put_battlefield(0, "Skyshroud Troopers", true)
	assert_refused(g.tap_for_mana(0, sick), "")
	var troopers := put_battlefield(0, "Skyshroud Troopers")
	assert_ok(g.tap_for_mana(0, troopers))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 1)


# ------------------------------------------------- Volrath's Stronghold --

func test_volraths_stronghold_taps_for_colorless() -> void:
	var hold := put_battlefield(0, "Volrath's Stronghold")
	assert_true((hold.data.supertypes & Mtg.Supertype.LEGENDARY) != 0)
	assert_ok(g.tap_for_mana(0, hold))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 1)


func test_volraths_stronghold_puts_a_creature_card_on_top_of_your_library() -> void:
	var hold := put_battlefield(0, "Volrath's Stronghold")
	var bear := give_hand(0, "Grizzly Bears")
	var forest := give_hand(0, "Forest")
	var theirs := give_hand(1, "Hill Giant")
	g.discard_cards(0, [bear, forest])
	g.discard_cards(1, [theirs])
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, hold, 0, [TargetRef.card(forest)]), "")
	assert_refused(g.activate_ability(0, hold, 0, [TargetRef.card(theirs)]), "")
	assert_ok(g.activate_ability(0, hold, 0, [TargetRef.card(bear)]))
	assert_true(hold.tapped)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].library.back(), bear, "on top")
