extends GameTest
## Wave-21 tests: the combat-only archers (D'Avenant Archer, Lady Caleria,
## Tor Wauki), the Legends utility lands (Pendelhaven, Karakas, Hammerheim,
## Urborg), sacrifice-fueled and keyword-granting pumps (Fallen Angel,
## Emerald Dragonfly, Pixie Queen), artifact lockdown (Relic Barrier) and
## the wall that stops being one (Wall of Wonder).


func test_davenant_archer_only_shoots_in_combat() -> void:
	var archer := put_battlefield(0, "D'Avenant Archer")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, archer, 0, [TargetRef.card(bear)]),
		"Illegal target")


func test_lady_caleria_shoots_an_attacker_down() -> void:
	var caleria := put_battlefield(0, "Lady Caleria")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_next_turn()   # player 1's turn
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [bear.id]))
	resolve_stack()
	assert_ok(g.pass_priority(1))
	assert_ok(g.activate_ability(0, caleria, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "3 damage on a 2/2")


func test_tor_wauki_shoots_a_blocker() -> void:
	var wauki := put_battlefield(0, "Tor Wauki")
	var mine := put_battlefield(0, "Grizzly Bears")
	var blocker := put_battlefield(1, "Wall of Wood")   # 0/3
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [mine.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {blocker.id: mine.id}))
	assert_ok(g.activate_ability(0, wauki, 0, [TargetRef.card(blocker)]))
	resolve_stack()
	assert_eq(blocker.damage, 2)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(blocker.zone, Mtg.Zone.GRAVEYARD, "2 from Wauki + 2 from the bear")


func test_pendelhaven_only_pumps_one_ones() -> void:
	var pendelhaven := put_battlefield(0, "Pendelhaven")
	var bear := put_battlefield(0, "Grizzly Bears")
	var lions := put_battlefield(0, "Savannah Lions")   # 2/1
	var sprite := put_battlefield(0, "Mons's Goblin Raiders")   # 1/1
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, pendelhaven, 0, [TargetRef.card(bear)]),
		"Illegal target")
	assert_refused(g.activate_ability(0, pendelhaven, 0, [TargetRef.card(lions)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, pendelhaven, 0, [TargetRef.card(sprite)]))
	resolve_stack()
	assert_eq(sprite.cur_power, 2)
	assert_eq(sprite.cur_toughness, 3)


func test_pendelhaven_taps_for_green() -> void:
	var pendelhaven := put_battlefield(0, "Pendelhaven")
	assert_ok(g.tap_for_mana(0, pendelhaven))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 1)


func test_karakas_bounces_only_legends() -> void:
	var karakas := put_battlefield(0, "Karakas")
	var bear := put_battlefield(1, "Grizzly Bears")
	var legend := put_battlefield(1, "Jedit Ojanen")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, karakas, 0, [TargetRef.card(bear)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, karakas, 0, [TargetRef.card(legend)]))
	resolve_stack()
	assert_eq(legend.zone, Mtg.Zone.HAND)


func test_hammerheim_strips_landwalk() -> void:
	var hammerheim := put_battlefield(0, "Hammerheim")
	put_battlefield(0, "Swamp")
	var walker := put_battlefield(1, "Bog Wraith")   # swampwalk
	assert_true(walker.cur_landwalk.has("swamp"))
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, hammerheim, 0, [TargetRef.card(walker)]))
	resolve_stack()
	assert_eq(walker.cur_landwalk.size(), 0, "no more swampwalk this turn")
	advance_to_next_turn()
	assert_true(walker.cur_landwalk.has("swamp"), "back next turn")


func test_urborg_picks_which_ability_to_strip() -> void:
	var urborg := put_battlefield(0, "Urborg")
	var wraith := put_battlefield(1, "Bog Wraith")
	var knight := put_battlefield(1, "Black Knight")   # first strike
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, urborg, 0, [TargetRef.card(knight)]))
	resolve_stack()
	assert_false(knight.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	g.untap_permanent(urborg)
	assert_ok(g.activate_ability(0, urborg, 1, [TargetRef.card(wraith)]))
	resolve_stack()
	assert_eq(wraith.cur_landwalk.size(), 0)


func test_fallen_angel_eats_the_team() -> void:
	var angel := put_battlefield(0, "Fallen Angel")
	assert_true(angel.has_keyword(Mtg.Keyword.FLYING))
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, angel, 0, []))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "eaten as a cost")
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD,
		"and never itself while another body is on offer")
	resolve_stack()
	assert_eq(angel.cur_power, 5)
	assert_eq(angel.cur_toughness, 4)


func test_fallen_angel_may_eat_itself() -> void:
	# "Sacrifice a creature" means ANY creature you control, the Angel
	# included. It gains nothing by itself — the pump has no Angel left to
	# land on — but it is a cost the printed card allows, and it is a real
	# line the moment something counts creature deaths.
	var angel := put_battlefield(0, "Fallen Angel")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(g.creatures_died_this_turn, 0)
	assert_ok(g.activate_ability(0, angel, 0, []))
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD,
		"the only creature it could eat was itself")
	resolve_stack()
	assert_eq(g.creatures_died_this_turn, 1,
		"a creature really died — every death-counter in the pool sees it")


func test_emerald_dragonfly_gains_first_strike() -> void:
	var fly := put_battlefield(0, "Emerald Dragonfly")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.activate_ability(0, fly, 0, []))
	resolve_stack()
	assert_true(fly.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	advance_to_next_turn()
	assert_false(fly.has_keyword(Mtg.Keyword.FIRST_STRIKE))


func test_pixie_queen_grants_flying() -> void:
	var queen := put_battlefield(0, "Pixie Queen")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 3)
	assert_ok(g.activate_ability(0, queen, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))


func test_relic_barrier_taps_an_artifact() -> void:
	var barrier := put_battlefield(0, "Relic Barrier")
	var icy := put_battlefield(1, "Icy Manipulator")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, barrier, 0, [TargetRef.card(bear)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, barrier, 0, [TargetRef.card(icy)]))
	resolve_stack()
	assert_true(icy.tapped)


func test_wall_of_wonder_charges_into_the_red_zone() -> void:
	var wall := put_battlefield(0, "Wall of Wonder")
	assert_true(wall.has_keyword(Mtg.Keyword.DEFENDER))
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, wall, 0, []))
	resolve_stack()
	assert_eq(wall.cur_power, 5)
	assert_eq(wall.cur_toughness, 1)
	assert_false(wall.has_keyword(Mtg.Keyword.DEFENDER), "it may attack this turn")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wall.id]))
