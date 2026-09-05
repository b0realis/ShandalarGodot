extends GameTest
## Wave-14 tests: combat instants (Morale, Piety, Marsh Gas), exile-on-
## death (Cyclopean Mummy — engine's exile_from_graveyard), upkeep
## machines (Brass Man, Junún Efreet, Sunken City), the untouchable
## (Uncle Istvan), and tap/untap/keyword utilities (Ali Baba, Flood,
## Flying Carpet, Jandor's Saddlebags).


# --------------------------------------------------------- combat instants --

func test_morale_lifts_the_attack() -> void:
	var lions := put_battlefield(0, "Savannah Lions")
	var home := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [lions.id]))
	var morale := give_hand(0, "Morale")
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, morale, []))
	resolve_stack()
	assert_eq(lions.cur_power, 3, "attacker pumped")
	assert_eq(home.cur_power, 2, "non-attacker untouched")


func test_piety_hardens_the_blockers() -> void:
	var attacker := put_battlefield(0, "War Mammoth")
	var blocker := put_battlefield(1, "Savannah Lions")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {blocker.id: attacker.id}))
	var piety := give_hand(1, "Piety")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.W)
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(1, piety, []))
	resolve_stack()
	assert_eq(blocker.cur_toughness, 4, "1 + 3")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(blocker.zone, Mtg.Zone.BATTLEFIELD, "survived the mammoth")
	assert_eq(attacker.damage, 2, "and traded its claws back")


func test_marsh_gas_weakens_everything() -> void:
	var mine := put_battlefield(0, "War Mammoth")
	var theirs := put_battlefield(1, "Grizzly Bears")
	var gas := give_hand(0, "Marsh Gas")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, gas, []))
	resolve_stack()
	assert_eq(mine.cur_power, 1, "both sides shrink")
	assert_eq(theirs.cur_power, 0)
	assert_eq(theirs.cur_toughness, 2, "toughness untouched")


# --------------------------------------------------------- Cyclopean Mummy --

func test_cyclopean_mummy_exiles_itself_on_death() -> void:
	var mummy := put_battlefield(0, "Cyclopean Mummy")
	g.destroy(mummy, false)
	resolve_stack()
	assert_eq(mummy.zone, Mtg.Zone.EXILE, "no Raise Dead for the mummy")
	assert_eq(g.players[0].graveyard.size(), 0)


# ---------------------------------------------------------- upkeep machines --

func test_brass_man_untaps_only_when_paid() -> void:
	var brass := put_battlefield(0, "Brass Man")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [brass.id]))
	advance_to_step(Mtg.Step.MAIN2)
	assert_true(brass.tapped)
	advance_to_next_turn()   # opponent's turn
	advance_to_next_turn()   # our turn: no mana — stays tapped
	assert_true(brass.tapped, "no {1} to pay")
	put_battlefield(0, "Plains")
	advance_to_next_turn()
	advance_to_next_turn()   # our upkeep auto-taps the plains for {1}
	assert_false(brass.tapped, "paid {1} — untapped")


func test_junun_efreet_needs_black_rent() -> void:
	var efreet := put_battlefield(0, "Junún Efreet")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.UPKEEP)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.UPKEEP)   # our upkeep: swamps pay {B}{B}
	resolve_stack()
	assert_eq(efreet.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(g.find_on_battlefield(0, "Swamp").tapped)


func test_sunken_city_boosts_blue_until_rent_runs_out() -> void:
	put_battlefield(0, "Sunken City")
	var monster := put_battlefield(0, "Phantom Monster")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_eq(monster.cur_power, 4, "blue creature +1/+1")
	assert_eq(bear.cur_power, 2, "green bear unboosted")
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.UPKEEP)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.UPKEEP)   # our upkeep: no {U}{U} anywhere
	resolve_stack()
	assert_eq(g.find_on_battlefield(0, "Sunken City"), null, "sacrificed")
	assert_eq(monster.cur_power, 3, "boost gone with the city")


# ------------------------------------------------------------- Uncle Istvan --

func test_uncle_istvan_shrugs_off_creatures() -> void:
	var istvan := put_battlefield(1, "Uncle Istvan")
	var mammoth := put_battlefield(0, "War Mammoth")
	run_combat([mammoth.id], {istvan.id: mammoth.id})
	assert_eq(istvan.damage, 0, "creature damage prevented")
	assert_eq(mammoth.damage, 1, "Istvan still claws back")
	# Non-creature damage still lands.
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(istvan)]))
	resolve_stack()
	assert_eq(istvan.zone, Mtg.Zone.GRAVEYARD, "a Bolt is not a creature")


# ------------------------------------------------------------ tap utilities --

func test_ali_baba_taps_walls() -> void:
	var ali := put_battlefield(0, "Ali Baba")
	var wall := put_battlefield(1, "Wall of Stone")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.activate_ability(0, ali, 0, [TargetRef.card(bear)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, ali, 0, [TargetRef.card(wall)]))
	resolve_stack()
	assert_true(wall.tapped)


func test_flood_taps_grounded_creatures() -> void:
	var flood := put_battlefield(0, "Flood")
	var bear := put_battlefield(1, "Grizzly Bears")
	var flyer := put_battlefield(1, "Phantom Monster")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_refused(g.activate_ability(0, flood, 0, [TargetRef.card(flyer)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, flood, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.tapped)


func test_flying_carpet_grants_flying() -> void:
	var carpet := put_battlefield(0, "Flying Carpet")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, carpet, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	assert_true(carpet.tapped)


func test_jandors_saddlebags_untap() -> void:
	var bags := put_battlefield(0, "Jandor's Saddlebags")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.tap_permanent(bear)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, bags, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_false(bear.tapped)
