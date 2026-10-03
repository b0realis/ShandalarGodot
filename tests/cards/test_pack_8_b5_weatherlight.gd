extends GameTest
## Pack 8, batch B5 — Weatherlight global enchantments (cards/sets/wth/_misc.gd).

## A seat that prefers the named cards when it picks (costs included).
class Seat extends DecisionAgent:
	var prefer: Array = []

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		for name in prefer:
			for c in candidates:
				if c.data.card_name == name: return c
		return null if candidates.is_empty() else candidates[0]


var me: Seat


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	me = Seat.new()
	g.set_agent(0, me)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func test_serras_blessing_gives_your_creatures_vigilance() -> void:
	put_battlefield(0, "Serra's Blessing")
	var bears := put_battlefield(0, "Grizzly Bears")
	var foe_bears := put_battlefield(1, "Grizzly Bears")
	assert_true(bears.has_keyword(Mtg.Keyword.VIGILANCE))
	assert_false(foe_bears.has_keyword(Mtg.Keyword.VIGILANCE), "creatures YOU control")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	assert_false(bears.tapped)


func test_fervor_lets_your_new_creatures_attack() -> void:
	put_battlefield(0, "Fervor")
	var bears := put_battlefield(0, "Grizzly Bears", true)
	var foe_bears := put_battlefield(1, "Grizzly Bears", true)
	assert_true(bears.has_keyword(Mtg.Keyword.HASTE))
	assert_false(foe_bears.has_keyword(Mtg.Keyword.HASTE))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))


func test_dense_foliage_stops_spells_but_not_abilities() -> void:
	put_battlefield(0, "Dense Foliage")
	var bears := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.card(bears)]))
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(bears.damage, 1)


func test_infernal_tribute_sacrifices_a_nontoken_permanent_to_draw() -> void:
	var tribute := put_battlefield(0, "Infernal Tribute")
	var bears := put_battlefield(0, "Grizzly Bears")
	me.prefer = ["Grizzly Bears"]
	var hand := g.players[0].hand.size()
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, tribute, 0))
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "sacrificed as a cost")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1)
	# A token is no fodder: with only a token beside it, the Tribute itself goes.
	var token := g.create_token(0, CardData.new("Saproling", "", Mtg.CardType.CREATURE).pt(1, 1))[0]
	me.prefer = ["Saproling"]
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, tribute, 0))
	assert_eq(token.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(tribute.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 2)


func test_strands_of_night_reanimates_for_life_and_a_swamp() -> void:
	var strands := put_battlefield(0, "Strands of Night")
	var swamp := put_battlefield(0, "Swamp")
	var giant := give_hand(0, "Hill Giant")
	g.discard_cards(0, [giant])
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.activate_ability(0, strands, 0, [TargetRef.card(giant)]))
	assert_eq(swamp.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 18)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.controller_id, 0)


func test_strands_of_night_needs_a_swamp() -> void:
	var strands := put_battlefield(0, "Strands of Night")
	var giant := give_hand(0, "Hill Giant")
	g.discard_cards(0, [giant])
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_refused(g.activate_ability(0, strands, 0, [TargetRef.card(giant)]))
	assert_eq(g.players[0].life, 20)


func test_call_of_the_wild_puts_a_revealed_creature_into_play_else_buries_it() -> void:
	var call := put_battlefield(0, "Call of the Wild")
	var bears := give_hand(0, "Grizzly Bears")
	g.put_from_hand_on_top_of_library(bears)
	add_mana(0, Mtg.ManaColor.G, 4)
	assert_ok(g.activate_ability(0, call, 0))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	var forest: CardInstance = g.players[0].library.back()
	add_mana(0, Mtg.ManaColor.G, 4)
	assert_ok(g.activate_ability(0, call, 0))
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)


func test_downdraft_grounds_a_flyer_and_blows_up_the_sky() -> void:
	var draft := put_battlefield(0, "Downdraft")
	var angel := put_battlefield(1, "Serra Angel")
	var wall := put_battlefield(1, "Wall of Air")
	var bears := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, draft, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING))
	assert_ok(g.activate_ability(0, draft, 1))
	assert_eq(draft.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_eq(wall.damage, 2)
	assert_eq(angel.damage, 0, "it no longer has flying")
	assert_eq(bears.damage, 0)


func test_tranquil_grove_destroys_every_other_enchantment() -> void:
	var grove := put_battlefield(0, "Tranquil Grove")
	var crusade := put_battlefield(1, "Crusade")
	var moon := put_battlefield(0, "Bad Moon")
	add_mana(0, Mtg.ManaColor.G, 3)
	assert_ok(g.activate_ability(0, grove, 0))
	resolve_stack()
	assert_eq(crusade.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(moon.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(grove.zone, Mtg.Zone.BATTLEFIELD)


## Make the game's next coin flip come out [param win] for the flipper
## (MtgGame.flip_coin: `rng.randi() % 2 == 0` wins) by spending throwaway
## draws of the seeded RNG — setup only.
func _rig_next_flip(win: bool) -> void:
	for n in 64:
		var probe := RandomNumberGenerator.new()
		probe.seed = g.rng.seed
		probe.state = g.rng.state
		if ((probe.randi() % 2) == 0) == win: return
		g.rng.randi()
	fail_test("could not rig the flip")


func _cast_gambit() -> void:
	var gambit := give_hand(0, "Desperate Gambit")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, gambit, []))
	resolve_stack()


func test_desperate_gambit_won_doubles_the_sources_next_damage_only() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var foe_giant := put_battlefield(1, "Hill Giant")
	me.prefer = ["Hill Giant"]
	_rig_next_flip(true)
	_cast_gambit()
	g.deal_damage(foe_giant, TargetRef.player(0), 3)
	assert_eq(g.players[0].life, 17, "an opposing source is never chosen")
	g.deal_damage(giant, TargetRef.player(1), 3)
	assert_eq(g.players[1].life, 14, "doubled")
	g.deal_damage(giant, TargetRef.player(1), 3)
	assert_eq(g.players[1].life, 11, "only the next time")


func test_desperate_gambit_lost_prevents_the_sources_next_damage() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bears := put_battlefield(1, "Grizzly Bears")
	_rig_next_flip(false)
	_cast_gambit()
	g.deal_damage(giant, TargetRef.card(bears), 3)
	assert_eq(bears.damage, 0, "prevented")
	g.deal_damage(giant, TargetRef.player(1), 3)
	assert_eq(g.players[1].life, 17)


func test_desperate_gambit_without_a_source_does_nothing() -> void:
	_cast_gambit()
	assert_true(g.damage_effects.is_empty())

