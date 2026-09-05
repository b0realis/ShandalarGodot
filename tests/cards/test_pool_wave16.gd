extends GameTest
## Wave-16 tests: the basilisk-gaze family (Cockatrice, Thicket Basilisk,
## Venom, Abomination — "destroy at end of combat" via the engine's doom
## queue), block-shaped triggers (Wall of Dust's attack ban, Murk
## Dwellers' unblocked pump, Elder Land Wurm's permanent defender loss),
## block restrictions (Elven Riders, Seeker) and Tawnos's Wand.


# ------------------------------------------------------------ basilisk gaze --

func test_thicket_basilisk_gaze_kills_after_combat() -> void:
	var basilisk := put_battlefield(0, "Thicket Basilisk")
	var mammoth := put_battlefield(1, "War Mammoth")
	run_combat([basilisk.id], {mammoth.id: basilisk.id})
	assert_eq(mammoth.zone, Mtg.Zone.GRAVEYARD,
		"3/3 survives the 2 damage but not the gaze")
	assert_eq(basilisk.zone, Mtg.Zone.BATTLEFIELD, "2/4 shrugs off 3 damage")


func test_basilisk_gaze_spares_walls() -> void:
	var basilisk := put_battlefield(0, "Thicket Basilisk")
	var wall := put_battlefield(1, "Wall of Stone")
	run_combat([basilisk.id], {wall.id: basilisk.id})
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD, "non-Wall clause — walls immune")


func test_gaze_can_be_regenerated_away() -> void:
	var basilisk := put_battlefield(0, "Thicket Basilisk")
	var skel := put_battlefield(1, "Drudge Skeletons")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [basilisk.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {skel.id: basilisk.id}))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.B, 2)
	assert_ok(g.activate_ability(1, skel, 0, []))
	assert_ok(g.activate_ability(1, skel, 0, []))
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN2)
	# Shield #1 eats the basilisk's combat damage, shield #2 the gaze.
	assert_eq(skel.zone, Mtg.Zone.BATTLEFIELD,
		"the shield ate the end-of-combat destruction")


func test_cockatrice_flies_and_petrifies() -> void:
	var cockatrice := put_battlefield(1, "Cockatrice")
	var angel := put_battlefield(0, "Serra Angel")
	run_combat([angel.id], {cockatrice.id: angel.id})
	assert_eq(cockatrice.zone, Mtg.Zone.GRAVEYARD, "4 damage kills the 2/4")
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD, "…but the gaze still lands")


func test_abomination_hates_green_and_white() -> void:
	var abomination := put_battlefield(1, "Abomination")
	var mammoth := put_battlefield(0, "War Mammoth")   # green
	run_combat([mammoth.id], {abomination.id: mammoth.id})
	assert_eq(mammoth.zone, Mtg.Zone.GRAVEYARD, "green blocker-victim")
	# A black creature is safe from it (3/3 survives the 2/6's claws too).
	var abomination2 := put_battlefield(1, "Abomination")
	var wraith := put_battlefield(0, "Bog Wraith")
	advance_to_next_turn()
	advance_to_next_turn()
	run_combat([wraith.id], {abomination2.id: wraith.id})
	assert_eq(wraith.zone, Mtg.Zone.BATTLEFIELD, "black — no trigger")


func test_venom_arms_any_creature() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var venom := give_hand(0, "Venom")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, venom, [TargetRef.card(bear)]))
	resolve_stack()
	var mammoth := put_battlefield(1, "War Mammoth")
	run_combat([bear.id], {mammoth.id: bear.id})
	assert_eq(mammoth.zone, Mtg.Zone.GRAVEYARD, "the OTHER creature dies")


# ------------------------------------------------------- block-shaped triggers --

func test_wall_of_dust_grounds_what_it_blocks() -> void:
	var wall := put_battlefield(1, "Wall of Dust")
	var mammoth := put_battlefield(0, "War Mammoth")
	run_combat([mammoth.id], {wall.id: mammoth.id})
	assert_eq(mammoth.zone, Mtg.Zone.BATTLEFIELD, "1 damage only")
	advance_to_next_turn()   # opponent's turn
	advance_to_next_turn()   # OUR next turn: the mammoth must sit out
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [mammoth.id]), "can't attack this turn")
	advance_to_next_turn()
	advance_to_next_turn()   # the turn after: free again
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [mammoth.id]))


func test_murk_dwellers_pump_when_unblocked() -> void:
	var dwellers := put_battlefield(0, "Murk Dwellers")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [dwellers.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	resolve_stack()
	assert_eq(dwellers.cur_power, 4, "2 + 2 while unblocked")
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_eq(g.players[1].life, 16, "hit for 4")
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(dwellers.cur_power, 2, "until end of COMBAT — gone in main 2")


func test_murk_dwellers_stay_small_when_blocked() -> void:
	var dwellers := put_battlefield(0, "Murk Dwellers")
	var wall := put_battlefield(1, "Wall of Stone")
	run_combat([dwellers.id], {wall.id: dwellers.id})
	assert_eq(wall.damage, 2, "no pump when blocked")


func test_elder_land_wurm_wakes_up_after_blocking() -> void:
	var wurm := put_battlefield(1, "Elder Land Wurm")
	var mammoth := put_battlefield(0, "War Mammoth")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(1, []), "only the active player")
	assert_ok(g.declare_attackers(0, [mammoth.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wurm.id: mammoth.id}))
	resolve_stack()
	assert_false(wurm.has_keyword(Mtg.Keyword.DEFENDER), "defender lost forever")
	advance_to_next_turn()   # the wurm controller's turn
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [wurm.id]))


# --------------------------------------------------------- block restrictions --

func test_elven_riders_dodge_ground_troops() -> void:
	var riders := put_battlefield(0, "Elven Riders")
	var bear := put_battlefield(1, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	var flyer := put_battlefield(1, "Phantom Monster")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [riders.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {bear.id: riders.id}), "except by")
	assert_ok(g.declare_blockers(1, {wall.id: riders.id, flyer.id: riders.id}))


func test_seeker_restricts_to_artifact_or_white() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var seeker := give_hand(0, "Seeker")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, seeker, [TargetRef.card(bear)]))
	resolve_stack()
	var enemy_bear := put_battlefield(1, "Grizzly Bears")
	var lions := put_battlefield(1, "Savannah Lions")
	var wall := put_battlefield(1, "Living Wall")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {enemy_bear.id: bear.id}), "except by")
	assert_ok(g.declare_blockers(1, {lions.id: bear.id, wall.id: bear.id}))


# ------------------------------------------------------------- Tawnos's Wand --

func test_tawnos_wand_sneaks_the_small_through() -> void:
	var wand := put_battlefield(0, "Tawnos's Wand")
	var lions := put_battlefield(0, "Savannah Lions")
	var mammoth := put_battlefield(0, "War Mammoth")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, wand, 0, [TargetRef.card(mammoth)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, wand, 0, [TargetRef.card(lions)]))
	resolve_stack()
	var blocker := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [lions.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {blocker.id: lions.id}), "can't be blocked")
