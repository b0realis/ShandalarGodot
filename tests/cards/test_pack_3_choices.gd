extends GameTest

class Decline extends DecisionAgent:
	func answer_yes_no(_g: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool: return false

class ContinueChaos extends DecisionAgent:
	func answer_yes_no(_g: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool: return true

func test_game_of_chaos_stops_at_the_documented_thirty_flip_boundary() -> void:
	g.agents[0] = ContinueChaos.new()
	g.agents[1] = ContinueChaos.new()
	g.players[0].life = 2000000000
	g.players[1].life = 2000000000
	var spell := give_hand(0, "Game of Chaos")
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ok(g.cast_spell(0, spell, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[0].life + g.players[1].life, 4000000000)
	assert_eq(spell.zone, Mtg.Zone.GRAVEYARD)
	assert_false(g.game_over)

func before_each() -> void:
	CardPacks.set_enabled(IceAgePack.ID, true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled(IceAgePack.ID, false)

func test_freyalises_charm_draws_only_after_paying_for_opposing_black_cast() -> void:
	put_battlefield(0, "Freyalise's Charm")
	var ritual := give_hand(1, "Dark Ritual")
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(1, Mtg.ManaColor.B)
	g.priority_player = 1
	assert_ok(g.cast_spell(1, ritual))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 1)
	assert_eq(g.players[0].mana_pool.total(), 0)

func test_leshracs_sigil_discards_a_chosen_card_after_green_spell() -> void:
	put_battlefield(0, "Leshrac's Sigil")
	give_hand(1, "Island")
	var spell := give_hand(1, "Giant Growth")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(1, Mtg.ManaColor.G)
	g.priority_player = 1
	assert_ok(g.cast_spell(1, spell, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(g.players[1].hand.is_empty())
	assert_eq(g.players[0].mana_pool.total(), 0)

func test_mercenaries_opponent_pays_and_shields_only_that_source_once() -> void:
	var merc := put_battlefield(0, "Mercenaries")
	var other := put_battlefield(0, "Grizzly Bears")
	add_mana(1, Mtg.ManaColor.C, 3)
	g.priority_player = 1
	assert_ok(g.activate_ability(1, merc, 0))
	resolve_stack()
	g.deal_damage(other, TargetRef.player(1), 1)
	assert_eq(g.players[1].life, 19)
	g.deal_damage(merc, TargetRef.player(1), 3)
	assert_eq(g.players[1].life, 19)
	g.deal_damage(merc, TargetRef.player(1), 2)
	assert_eq(g.players[1].life, 17)

func test_pentagram_names_a_colorless_source_and_prevents_one_damage_event() -> void:
	var pentagram := put_battlefield(0, "Pentagram of the Ages")
	var ornithopter := put_battlefield(1, "Ornithopter")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, pentagram, 0))
	resolve_stack()
	g.deal_damage(ornithopter, TargetRef.player(0), 4)
	assert_eq(g.players[0].life, 20)
	g.deal_damage(ornithopter, TargetRef.player(0), 1)
	assert_eq(g.players[0].life, 19)

func test_royal_guard_redirect_survives_recalculation_but_not_bounce() -> void:
	var guard := put_battlefield(0, "Kjeldoran Royal Guard")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_ok(g.activate_ability(0, guard, 0))
	resolve_stack()
	g.recalculate()
	g.combat.attackers[bear.id] = true
	g.deal_damage(bear, TargetRef.player(0), 2, true)
	assert_eq(guard.damage, 2)
	assert_eq(g.players[0].life, 20)
	g.deal_damage(bear, TargetRef.player(0), 1, false)
	assert_eq(g.players[0].life, 19)
	g.return_to_hand(guard)
	g.deal_damage(bear, TargetRef.player(0), 2, true)
	assert_eq(g.players[0].life, 17)

func test_minion_of_leshrac_taps_only_if_upkeep_damage_lands() -> void:
	var minion := put_battlefield(0, "Minion of Leshrac")
	g.players[0].damage_prevention = 5
	g.dispatch_event(Mtg.EventType.UPKEEP_START, {"player": 0})
	resolve_stack()
	assert_false(minion.tapped)
	assert_eq(g.players[0].life, 20)
	g.dispatch_event(Mtg.EventType.UPKEEP_START, {"player": 0})
	resolve_stack()
	assert_true(minion.tapped)
	assert_eq(g.players[0].life, 15)

func test_game_of_chaos_single_flip_moves_exactly_one_life_each_way() -> void:
	var spell := give_hand(0, "Game of Chaos")
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ok(g.cast_spell(0, spell, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[0].life + g.players[1].life, 40)
	assert_eq(absi(g.players[0].life - 20), 1)

func test_amulet_of_quoz_can_be_avoided_by_ante_without_coin_flip() -> void:
	# Played FOR ANTE: in a duel that is not, an ante card does nothing and
	# nothing reaches the ante (the owner's ruling of 2026-10-21,
	# tests/unit/test_ruling_2026_10_21_ante_off.gd).
	g.ante_enabled = true
	var amulet := put_battlefield(0, "Amulet of Quoz")
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.UPKEEP)
	assert_ok(g.activate_ability(0, amulet, 0, [TargetRef.player(1)]))
	assert_eq(amulet.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[1].ante.size(), 1)
	assert_false(g.game_over)

func test_amulet_coin_flip_ends_the_game_if_opponent_declines_ante() -> void:
	# Played FOR ANTE: in a duel that is not, an ante card does nothing and
	# nothing reaches the ante (the owner's ruling of 2026-10-21,
	# tests/unit/test_ruling_2026_10_21_ante_off.gd).
	g.ante_enabled = true
	var amulet := put_battlefield(0, "Amulet of Quoz")
	g.agents[1] = Decline.new()
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.UPKEEP)
	assert_ok(g.activate_ability(0, amulet, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_true(g.game_over)
