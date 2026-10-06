extends GameTest
## Pack 9 (the Tempest block), batch B2: what each Stronghold and Exodus
## buyback spell DOES (cards/sets/sth/_buyback.gd, cards/sets/exo/_buyback.gd)
## — Brush with Death, Change of Heart, Constant Mists, Fanning the Flames,
## Lab Rats, Mind Games, Mind Peel, Seething Anger, Verdant Touch, Allay,
## Flowstone Flood, Forbid, Pegasus Stampede, Reaping the Rewards,
## Shattering Pulse and Slaughter: each effect, its refused or illegal case,
## and the non-mana buybacks (a land, two cards, 4 life, 3 life and a card
## at random) validated before anything is paid (CR 601.2h). The buyback
## lifecycle, card by card, is tests/cards/test_pack_9_B2_buyback.gd.


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)


## Into the OPPONENT's turn, P0 holding priority in [param step].
func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)

func _pool() -> int: return g.players[0].mana_pool.total()

func _tokens(pid: int, token_name: String) -> Array:
	var out: Array = []
	for i in g.players[pid].battlefield:
		if i.is_token and i.data.card_name == token_name: out.append(i)
	return out


# ---------------------------------------------------------- Brush with Death --

func test_brush_with_death_drains_two_from_an_opponent() -> void:
	var brush := give_hand(0, "Brush with Death")
	add_mana(0, Mtg.ManaColor.B, 3)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, brush, [TargetRef.player(1)], 0, 1))
	assert_eq(_pool(), 0, "{2}{B} plus {2}{B}{B}")
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	assert_eq(g.players[0].life, 22)
	assert_eq(brush.zone, Mtg.Zone.HAND)

func test_brush_with_death_targets_an_opponent_only_and_a_coloured_buyback_needs_its_pips() -> void:
	var brush := give_hand(0, "Brush with Death")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 6)
	assert_refused(g.cast_spell(0, brush, [TargetRef.player(0)], 0, 0))
	assert_refused(g.cast_spell(0, brush, [TargetRef.player(1)], 0, 1), "not enough mana")
	assert_eq(_pool(), 7, "{2}{B}{B} on top needs two more black")


# ---------------------------------------------------------- Change of Heart --

func test_change_of_heart_stops_an_attack() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var heart := give_hand(0, "Change of Heart")
	_their_turn_at(Mtg.Step.UPKEEP)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, heart, [TargetRef.card(bears)], 0, 0))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(1, [bears.id]), "can't attack")
	assert_ok(g.declare_attackers(1, []))

func test_change_of_heart_does_not_remove_an_attacker() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	var heart := give_hand(1, "Change of Heart")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(1, heart, [TargetRef.card(bears)], 0, 0))
	resolve_stack()
	assert_true(g.combat.attackers.has(bears.id), "already attacking: it stays (ruling)")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 18)


# ----------------------------------------------------------- Constant Mists --

func test_constant_mists_fogs_and_its_buyback_eats_a_land_as_it_is_cast() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var forest := put_battlefield(1, "Forest")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	assert_ok(g.pass_priority(0))
	var mists := give_hand(1, "Constant Mists")
	add_mana(1, Mtg.ManaColor.G)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, mists, [], 0, 1))
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD, "the land is a cost (CR 601.2h)")
	resolve_stack()
	assert_eq(mists.zone, Mtg.Zone.HAND)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20)

func test_constant_mists_buyback_without_a_land_is_refused_but_the_spell_is_not() -> void:
	var mists := give_hand(0, "Constant Mists")
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, mists, [], 0, 1))
	assert_eq(_pool(), 2, "nothing paid")
	assert_ok(g.cast_spell(0, mists, [], 0, 0))


# ------------------------------------------------------- Fanning the Flames --

func test_fanning_the_flames_deals_x_and_pays_x_with_the_buyback_on_top() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	var fan := give_hand(0, "Fanning the Flames")
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_refused(g.cast_spell(0, fan, [TargetRef.card(giant)], 3, 1), "not enough mana")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, fan, [TargetRef.card(giant)], 3, 1))
	assert_eq(_pool(), 0, "{3}{R}{R} plus {3}")
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(fan.zone, Mtg.Zone.HAND)
	assert_false(fan.memory.has("x_value"), "X is forgotten off the stack")

func test_fanning_the_flames_is_a_sorcery() -> void:
	var fan := give_hand(0, "Fanning the Flames")
	_their_turn_at(Mtg.Step.UPKEEP)
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_refused(g.cast_spell(0, fan, [TargetRef.player(1)], 1, 0))


# ------------------------------------------------------------------ Lab Rats --

func test_lab_rats_makes_a_black_rat() -> void:
	var rats := give_hand(0, "Lab Rats")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, rats, [], 0, 1))
	resolve_stack()
	var made := _tokens(0, "Rat")
	assert_eq(made.size(), 1)
	var rat: CardInstance = made[0]
	assert_eq([rat.cur_power, rat.cur_toughness], [1, 1])
	assert_eq(rat.cur_colors, Mtg.ManaColor.B)
	assert_true(rat.has_subtype("rat"))
	assert_eq(rats.zone, Mtg.Zone.HAND)


# ---------------------------------------------------------------- Mind Games --

func test_mind_games_taps_an_artifact_creature_or_land() -> void:
	var icy := put_battlefield(1, "Icy Manipulator")
	var bears := put_battlefield(1, "Grizzly Bears")
	var land := put_battlefield(1, "Mountain")
	for victim in [icy, bears, land]:
		var games := give_hand(0, "Mind Games")
		add_mana(0, Mtg.ManaColor.U)
		assert_ok(g.cast_spell(0, games, [TargetRef.card(victim)], 0, 0))
		resolve_stack()
		assert_true(victim.tapped, victim.data.card_name)

func test_mind_games_refuses_an_enchantment() -> void:
	var crusade := put_battlefield(1, "Crusade")
	var games := give_hand(0, "Mind Games")
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(0, games, [TargetRef.card(crusade)], 0, 0))


# ----------------------------------------------------------------- Mind Peel --

func test_mind_peel_makes_target_player_discard_of_their_choice() -> void:
	var a := give_hand(1, "Forest")
	var b := give_hand(1, "Island")
	var peel := give_hand(0, "Mind Peel")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, peel, [TargetRef.player(1)], 0, 0))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 1)
	assert_true(a.zone == Mtg.Zone.GRAVEYARD or b.zone == Mtg.Zone.GRAVEYARD)

func test_mind_peel_may_target_its_caster_and_an_empty_hand_is_fine() -> void:
	var peel := give_hand(0, "Mind Peel")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, peel, [TargetRef.player(1)], 0, 0))
	resolve_stack()
	assert_eq(peel.zone, Mtg.Zone.GRAVEYARD)
	var mine := give_hand(0, "Forest")
	peel = give_hand(0, "Mind Peel")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, peel, [TargetRef.player(0)], 0, 0))
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "\"target player\": its caster too")


# ------------------------------------------------------------ Seething Anger --

func test_seething_anger_gives_plus_three_power() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var anger := give_hand(0, "Seething Anger")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, anger, [TargetRef.card(bears)], 0, 0))
	resolve_stack()
	assert_eq([bears.cur_power, bears.cur_toughness], [5, 2])


# ------------------------------------------------------------- Verdant Touch --

func test_verdant_touch_animates_a_land_indefinitely() -> void:
	var forest := put_battlefield(0, "Forest")
	var touch := give_hand(0, "Verdant Touch")
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, touch, [TargetRef.card(forest)], 0, 1))
	resolve_stack()
	assert_true(forest.is_creature())
	assert_true(forest.is_land(), "still a land")
	assert_eq([forest.cur_power, forest.cur_toughness], [2, 2])
	assert_eq(touch.zone, Mtg.Zone.HAND)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(forest.is_creature(), "no duration: it lasts (CR 611.2b)")
	assert_true(forest.is_land())

func test_verdant_touch_land_played_this_turn_cannot_attack() -> void:
	var forest := put_battlefield(0, "Forest", true)
	var touch := give_hand(0, "Verdant Touch")
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, touch, [TargetRef.card(forest)], 0, 0))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [forest.id]), "summoning sickness")

func test_verdant_touch_targets_lands_only() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var touch := give_hand(0, "Verdant Touch")
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, touch, [TargetRef.card(bears)], 0, 0))


# --------------------------------------------------------------------- Allay --

func test_allay_destroys_an_enchantment_and_nothing_else() -> void:
	var crusade := put_battlefield(1, "Crusade")
	var bears := put_battlefield(1, "Grizzly Bears")
	var allay := give_hand(0, "Allay")
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, allay, [TargetRef.card(bears)], 0, 0))
	assert_ok(g.cast_spell(0, allay, [TargetRef.card(crusade)], 0, 0))
	resolve_stack()
	assert_eq(crusade.zone, Mtg.Zone.GRAVEYARD)


# ----------------------------------------------------------- Flowstone Flood --

func test_flowstone_flood_buyback_pays_three_life_and_a_random_card() -> void:
	var land := put_battlefield(1, "Mountain")
	var spare := give_hand(0, "Island")
	var flood := give_hand(0, "Flowstone Flood")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, flood, [TargetRef.card(land)], 0, 1))
	assert_eq(g.players[0].life, 17, "3 life as it is cast")
	assert_eq(spare.zone, Mtg.Zone.GRAVEYARD, "the only other card, at random")
	resolve_stack()
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(flood.zone, Mtg.Zone.HAND)

func test_flowstone_flood_random_discard_is_the_games_roll() -> void:
	var land := put_battlefield(1, "Mountain")
	var hand: Array = []
	for card_name in ["Island", "Forest", "Swamp", "Plains"]:
		hand.append(give_hand(0, card_name))
	var flood := give_hand(0, "Flowstone Flood")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 3)
	var state := g.rng.state
	assert_ok(g.cast_spell(0, flood, [TargetRef.card(land)], 0, 1))
	assert_ne(g.rng.state, state, "rolled on the seeded game RNG")
	var gone := 0
	for card in hand:
		if card.zone == Mtg.Zone.GRAVEYARD: gone += 1
	assert_eq(gone, 1)
	assert_eq(flood.zone, Mtg.Zone.STACK, "never the spell itself")

func test_flowstone_flood_buyback_needs_a_card_and_the_life() -> void:
	var land := put_battlefield(1, "Mountain")
	var flood := give_hand(0, "Flowstone Flood")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.cast_spell(0, flood, [TargetRef.card(land)], 0, 1))
	assert_eq(g.players[0].life, 20, "no card to discard: nothing paid (ruling)")
	var spare := give_hand(0, "Island")
	g.players[0].life = 2
	assert_refused(g.cast_spell(0, flood, [TargetRef.card(land)], 0, 1), "life")
	assert_eq(spare.zone, Mtg.Zone.HAND)
	assert_eq(_pool(), 4)
	assert_ok(g.cast_spell(0, flood, [TargetRef.card(land)], 0, 0))


# -------------------------------------------------------------------- Forbid --

func test_forbid_counters_and_its_buyback_takes_two_other_cards() -> void:
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	var forbid := give_hand(0, "Forbid")
	var one := give_hand(0, "Forest")
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, forbid, [TargetRef.card(bolt)], 0, 1))
	assert_eq(one.zone, Mtg.Zone.HAND, "Forbid is not one of its own two cards")
	var two := give_hand(0, "Island")
	assert_ok(g.cast_spell(0, forbid, [TargetRef.card(bolt)], 0, 1))
	assert_eq(one.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(two.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20)
	assert_eq(forbid.zone, Mtg.Zone.HAND)

func test_forbid_targets_spells_only() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var forbid := give_hand(0, "Forbid")
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_refused(g.cast_spell(0, forbid, [TargetRef.card(bears)], 0, 0))


# ---------------------------------------------------------- Pegasus Stampede --

func test_pegasus_stampede_makes_a_flier_and_buys_back_with_a_land() -> void:
	var plains := put_battlefield(0, "Plains")
	var stampede := give_hand(0, "Pegasus Stampede")
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, stampede, [], 0, 1))
	assert_eq(plains.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	var made := _tokens(0, "Pegasus")
	assert_eq(made.size(), 1)
	var pegasus: CardInstance = made[0]
	assert_true(pegasus.has_keyword(Mtg.Keyword.FLYING))
	assert_eq(pegasus.cur_colors, Mtg.ManaColor.W)
	assert_eq([pegasus.cur_power, pegasus.cur_toughness], [1, 1])
	assert_eq(stampede.zone, Mtg.Zone.HAND)


# ------------------------------------------------------- Reaping the Rewards --

func test_reaping_the_rewards_gains_two_and_its_buyback_needs_a_land() -> void:
	var reap := give_hand(0, "Reaping the Rewards")
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.cast_spell(0, reap, [], 0, 1))
	var plains := put_battlefield(0, "Plains")
	assert_ok(g.cast_spell(0, reap, [], 0, 1))
	assert_eq(plains.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[0].life, 22)
	assert_eq(reap.zone, Mtg.Zone.HAND)


# --------------------------------------------------------- Shattering Pulse --

func test_shattering_pulse_destroys_an_artifact_only() -> void:
	var icy := put_battlefield(1, "Icy Manipulator")
	var bears := put_battlefield(1, "Grizzly Bears")
	var pulse := give_hand(0, "Shattering Pulse")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, pulse, [TargetRef.card(bears)], 0, 0))
	assert_ok(g.cast_spell(0, pulse, [TargetRef.card(icy)], 0, 0))
	resolve_stack()
	assert_eq(icy.zone, Mtg.Zone.GRAVEYARD)


# ----------------------------------------------------------------- Slaughter --

func test_slaughter_destroys_a_nonblack_creature_beyond_regeneration() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var slaughter := give_hand(0, "Slaughter")
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	bears.regeneration_shields = 1   # setup: a shield already up
	assert_ok(g.cast_spell(0, slaughter, [TargetRef.card(bears)], 0, 1))
	assert_eq(g.players[0].life, 16, "4 life as it is cast")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "it can't be regenerated")
	assert_eq(slaughter.zone, Mtg.Zone.HAND)

func test_slaughter_refuses_a_black_creature_and_a_short_life_total() -> void:
	var knight := put_battlefield(1, "Black Knight")
	var bears := put_battlefield(1, "Grizzly Bears")
	var slaughter := give_hand(0, "Slaughter")
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.cast_spell(0, slaughter, [TargetRef.card(knight)], 0, 0))
	g.players[0].life = 3
	assert_refused(g.cast_spell(0, slaughter, [TargetRef.card(bears)], 0, 1), "life")
	assert_eq(g.players[0].life, 3)
	assert_ok(g.cast_spell(0, slaughter, [TargetRef.card(bears)], 0, 0))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(slaughter.zone, Mtg.Zone.GRAVEYARD)
