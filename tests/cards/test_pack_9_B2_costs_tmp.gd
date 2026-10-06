extends GameTest
## Pack 9 (the Tempest block), batch B2: the Tempest cost cards
## (cards/sets/tmp/_costs.gd) — Abandon Hope, Aluren, Chill, the five
## Medallions, Goblin Bombardment, Harrow, Pegasus Refuge, Rootwater
## Shaman, Scorched Earth, Skyshroud Condor, Spontaneous Combustion and
## Tooth and Claw: each card's effect, its refused case (a cost that cannot
## be paid changes nothing — CR 601.2h, 602.2b), and the 1997 rule that a
## tapped artifact's static ability stops (the Medallions, under `fifth`).


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)


func _pool(pid := 0) -> int: return g.players[pid].mana_pool.total()

## Into the OPPONENT's turn, P0 holding priority in [param step].
func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)

func _cost(pid: int, card_name: String) -> int:
	var data := CardRegistry.get_card(card_name)
	var pay := g.spell_payment(pid, data, 0, 1, null, 0)
	return (pay["cost"] as ManaCost).mana_value() + int(pay["extra"])

func _tokens(pid: int, token_name: String) -> Array:
	var out: Array = []
	for i in g.players[pid].battlefield:
		if i.is_token and i.data.card_name == token_name: out.append(i)
	return out


func test_every_tempest_cost_card_is_claimed() -> void:
	for card_name in ["Abandon Hope", "Aluren", "Chill", "Emerald Medallion", "Goblin Bombardment",
			"Harrow", "Jet Medallion", "Pearl Medallion", "Pegasus Refuge", "Rootwater Shaman",
			"Ruby Medallion", "Sapphire Medallion", "Scorched Earth", "Skyshroud Condor",
			"Spontaneous Combustion", "Tooth and Claw"]:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# --------------------------------------------------------------- Medallions --

func test_each_medallion_discounts_its_colour_for_its_controller_only() -> void:
	var rows := {"Pearl Medallion": "Serra Angel", "Sapphire Medallion": "Mahamoti Djinn",
		"Jet Medallion": "Sengir Vampire", "Ruby Medallion": "Shivan Dragon",
		"Emerald Medallion": "Craw Wurm"}
	for medallion in rows:
		before_each()
		var spell: String = rows[medallion]
		var printed := _cost(0, spell)
		put_battlefield(0, medallion)
		assert_eq(_cost(0, spell), printed - 1, "%s: {1} less" % medallion)
		assert_eq(_cost(1, spell), printed, "%s: not the opponent's spells" % medallion)
		assert_eq(_cost(0, "Grizzly Bears") if medallion != "Emerald Medallion" else _cost(0, "Hill Giant"),
			2 if medallion != "Emerald Medallion" else 4, "%s: another colour pays in full" % medallion)

func test_a_medallion_never_reduces_a_coloured_pip_and_two_stack() -> void:
	put_battlefield(0, "Emerald Medallion")
	assert_eq(_cost(0, "Giant Growth"), 1, "{G} stays {G}")
	assert_eq(_cost(0, "Grizzly Bears"), 1, "{1}{G} becomes {G}")
	put_battlefield(0, "Emerald Medallion")
	assert_eq(_cost(0, "Craw Wurm"), 4, "{4}{G}{G} less two")
	assert_eq(_cost(0, "Grizzly Bears"), 1, "never below its pips")

func test_a_medallion_casts_the_discounted_spell() -> void:
	put_battlefield(0, "Ruby Medallion")
	var giant := give_hand(0, "Hill Giant")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, giant))
	assert_eq(_pool(), 0, "{3}{R} less {1}")
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)

func test_a_tapped_medallion_stops_under_the_1997_rules_only() -> void:
	var medallion := put_battlefield(0, "Jet Medallion")
	g.tap_permanent(medallion)
	g.rules.set_preset("modern")
	g.recalculate()
	assert_eq(_cost(0, "Sengir Vampire"), 4, "modern: a tapped artifact still works")
	g.rules.set_preset("fifth")
	g.recalculate()
	assert_eq(_cost(0, "Sengir Vampire"), 5, "fifth: its static stops while tapped")


# --------------------------------------------------------------------- Chill --

func test_chill_taxes_every_red_spell() -> void:
	put_battlefield(1, "Chill")
	assert_eq(_cost(0, "Lightning Bolt"), 3)
	assert_eq(_cost(1, "Lightning Bolt"), 3, "its controller's too")
	assert_eq(_cost(0, "Grizzly Bears"), 2)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.player(1)]), "not enough mana")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))


# ------------------------------------------------------------- Abandon Hope --

func test_abandon_hope_discards_x_then_takes_x_of_their_choice_of_ours() -> void:
	var mine: Array = [give_hand(0, "Forest"), give_hand(0, "Island")]
	var theirs: Array = [give_hand(1, "Serra Angel"), give_hand(1, "Shivan Dragon"), give_hand(1, "Mountain")]
	var hope := give_hand(0, "Abandon Hope")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, hope, [TargetRef.player(1)], 2))
	for card in mine:
		assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "X cards discarded as it is cast")
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 1, "two of the three chosen")
	var gone := 0
	for card in theirs:
		if card.zone == Mtg.Zone.GRAVEYARD: gone += 1
	assert_eq(gone, 2)

func test_abandon_hope_needs_x_cards_to_discard_and_an_opponent() -> void:
	give_hand(0, "Forest")
	var hope := give_hand(0, "Abandon Hope")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.cast_spell(0, hope, [TargetRef.player(1)], 2))
	assert_eq(_pool(), 4, "nothing paid")
	assert_refused(g.cast_spell(0, hope, [TargetRef.player(0)], 1), "")
	give_hand(1, "Island")
	assert_ok(g.cast_spell(0, hope, [TargetRef.player(1)], 0))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 1, "X = 0: look, take nothing")


# ------------------------------------------------------------------- Aluren --

func test_aluren_lets_any_player_cast_small_creatures_free_at_instant_speed() -> void:
	for preset in ["modern", "fifth"]:
		before_each()
		g.rules.set_preset(preset)
		put_battlefield(0, "Aluren")
		var bears := give_hand(1, "Grizzly Bears")
		var wurm := give_hand(1, "Craw Wurm")
		_p1_at_instant_speed()
		assert_eq(g.payment_rows(1, bears).size(), 2, preset)
		assert_true(g.has_flash(1, bears), "%s: flash through Aluren's row" % preset)
		assert_ok(g.cast_spell(1, bears, [], 0, 1))
		resolve_stack()
		assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, preset)
		assert_eq(bears.controller_id, 1)
		assert_eq(g.payment_rows(1, wurm).size(), 1, "%s: mana value 6" % preset)
		assert_false(g.has_flash(1, wurm))

func test_aluren_flash_never_comes_with_the_printed_cost() -> void:
	put_battlefield(0, "Aluren")
	var bears := give_hand(1, "Grizzly Bears")
	_p1_at_instant_speed()
	add_mana(1, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(1, bears, [], 0, 0))
	assert_eq(_pool(1), 2)
	assert_ok(g.cast_spell(1, bears, [], 0, 1))
	assert_eq(_pool(1), 2, "free")

## P0's main phase, P0 passing: P1 holds priority on P0's turn — an
## instant-speed moment for P1.
func _p1_at_instant_speed() -> void:
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)


# -------------------------------------------------------- Goblin Bombardment --

func test_goblin_bombardment_flings_a_creature_for_one() -> void:
	var bombardment := put_battlefield(0, "Goblin Bombardment")
	var bears := put_battlefield(0, "Grizzly Bears")
	var elf := put_battlefield(0, "Llanowar Elves")
	assert_ok(g.activate_ability(0, bombardment, 0, [TargetRef.player(1)]))
	assert_true(bears.zone == Mtg.Zone.GRAVEYARD or elf.zone == Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_ok(g.activate_ability(0, bombardment, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	assert_refused(g.activate_ability(0, bombardment, 0, [TargetRef.player(1)]))


# ------------------------------------------------------------------- Harrow --

func test_harrow_trades_a_land_for_two_untapped_basics() -> void:
	var swamp := put_battlefield(0, "Swamp")
	var harrow := give_hand(0, "Harrow")
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, harrow))
	assert_eq(swamp.zone, Mtg.Zone.GRAVEYARD, "the land is the additional cost")
	var library_before := g.players[0].library.size()
	resolve_stack()
	var lands := 0
	for i in g.players[0].battlefield:
		if i.is_land():
			lands += 1
			assert_false(i.tapped, "they enter untapped")
	assert_eq(lands, 2)
	assert_eq(g.players[0].library.size(), library_before - 2)
	assert_true(g.land_drop_available(0), "not land drops (ruling)")

func test_harrow_needs_a_land_to_sacrifice() -> void:
	var harrow := give_hand(0, "Harrow")
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.cast_spell(0, harrow))
	assert_eq(_pool(), 3)


# ----------------------------------------------------------- Pegasus Refuge --

func test_pegasus_refuge_turns_a_card_into_a_pegasus() -> void:
	var refuge := put_battlefield(0, "Pegasus Refuge")
	var spare := give_hand(0, "Forest")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, refuge, 0))
	assert_eq(spare.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	var made := _tokens(0, "Pegasus")
	assert_eq(made.size(), 1)
	assert_true((made[0] as CardInstance).has_keyword(Mtg.Keyword.FLYING))
	assert_eq((made[0] as CardInstance).cur_colors, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, refuge, 0))
	assert_eq(_pool(), 2, "no card to discard: nothing paid")


# --------------------------------------------------------- Rootwater Shaman --

func test_rootwater_shaman_gives_its_controllers_creature_auras_flash() -> void:
	put_battlefield(0, "Rootwater Shaman")
	var bears := put_battlefield(0, "Grizzly Bears")
	var strength := give_hand(0, "Holy Strength")
	var growth := give_hand(0, "Wild Growth")
	var theirs := give_hand(1, "Holy Strength")
	assert_true(g.has_flash(0, strength))
	assert_false(g.has_flash(0, growth), "enchant land is not enchant creature")
	assert_false(g.has_flash(1, theirs), "\"you may\": its controller only")
	_their_turn_at(Mtg.Step.UPKEEP)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, strength, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(strength.attached_to, bears.id)
	add_mana(0, Mtg.ManaColor.G)
	var land := put_battlefield(0, "Forest")
	assert_refused(g.cast_spell(0, growth, [TargetRef.card(land)]))


# ------------------------------------------------------------ Scorched Earth --

func test_scorched_earth_discards_x_lands_to_destroy_x_lands() -> void:
	var a := put_battlefield(1, "Mountain")
	var b := put_battlefield(1, "Island")
	var c := put_battlefield(1, "Plains")
	var discards: Array = [give_hand(0, "Forest"), give_hand(0, "Swamp")]
	var earth := give_hand(0, "Scorched Earth")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, earth, [TargetRef.card(a), TargetRef.card(b)], 2))
	for card in discards:
		assert_eq(card.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(c.zone, Mtg.Zone.BATTLEFIELD)

func test_scorched_earth_counts_land_cards_only() -> void:
	var a := put_battlefield(1, "Mountain")
	give_hand(0, "Grizzly Bears")
	var earth := give_hand(0, "Scorched Earth")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, earth, [TargetRef.card(a)], 1))
	assert_eq(_pool(), 2)
	assert_ok(g.cast_spell(0, earth, [], 0))   # X can be 0 (ruling)


# ---------------------------------------------------------- Skyshroud Condor --

func test_skyshroud_condor_needs_another_spell_first() -> void:
	var condor := give_hand(0, "Skyshroud Condor")
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, condor), "another spell")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, condor))
	resolve_stack()
	assert_eq(condor.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(condor.has_keyword(Mtg.Keyword.FLYING))

func test_skyshroud_condor_counts_this_turn_only_and_its_own_spells() -> void:
	var bolt := give_hand(1, "Lightning Bolt")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	var condor := give_hand(0, "Skyshroud Condor")
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, condor), "another spell")


# ---------------------------------------------------- Spontaneous Combustion --

func test_spontaneous_combustion_sacrifices_one_and_burns_every_creature() -> void:
	var fodder := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var angel := put_battlefield(1, "Serra Angel")
	var combustion := give_hand(0, "Spontaneous Combustion")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, combustion))
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(angel.damage, 3)
	assert_eq(g.players[1].life, 20, "creatures only")

func test_spontaneous_combustion_needs_a_creature() -> void:
	var combustion := give_hand(0, "Spontaneous Combustion")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, combustion))
	assert_eq(_pool(), 3)


# ----------------------------------------------------------- Tooth and Claw --

func test_tooth_and_claw_makes_a_carnivore_from_two_creatures() -> void:
	var claw := put_battlefield(0, "Tooth and Claw")
	var a := put_battlefield(0, "Grizzly Bears")
	assert_refused(g.activate_ability(0, claw, 0))
	assert_eq(a.zone, Mtg.Zone.BATTLEFIELD, "one creature is not two")
	var b := put_battlefield(0, "Llanowar Elves")
	assert_ok(g.activate_ability(0, claw, 0))
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	var made := _tokens(0, "Carnivore")
	assert_eq(made.size(), 1)
	var beast: CardInstance = made[0]
	assert_eq([beast.cur_power, beast.cur_toughness], [3, 1])
	assert_eq(beast.cur_colors, Mtg.ManaColor.R)
	assert_true(beast.has_subtype("beast"))
