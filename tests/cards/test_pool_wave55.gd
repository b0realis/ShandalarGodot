extends GameTest
## Wave-55 tests: Fourth Edition and The Dark remainders — a land that
## unmakes an attack, a Barge that drowns its passengers, a Tower that shrugs
## off Walls, a Festival that calls off the war, and the Worms that end land
## drops. Two engine additions carry them: floating BLOCK RESTRICTIONS and a
## game-level "creatures can't attack this turn".


func test_registry_loaded_wave55() -> void:
	for name in ["Detonate", "Oasis", "Angry Mob", "Goblin Rock Sled",
			"Fellwar Stone", "Mind Bomb", "Maze of Ith", "War Barge",
			"Martyr's Cry", "Tower of Coireall", "Festival",
			"Worms of the Earth"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ----------------------------------------------------------------- Detonate --

func test_detonate_blows_up_a_matching_artifact() -> void:
	var ring := put_battlefield(1, "Sol Ring")     # mana value 1
	var spell := give_hand(0, "Detonate")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(ring)], 1))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 19, "and its controller takes X")


func test_detonate_misses_the_wrong_mana_value() -> void:
	var ring := put_battlefield(1, "Sol Ring")
	var spell := give_hand(0, "Detonate")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 3)
	# "target artifact with mana value X" is a targeting restriction
	# (CR 115.4) — the mismatch is refused at cast, not at resolution
	# (audit 2026-09).
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(ring)], 3))
	assert_eq(ring.zone, Mtg.Zone.BATTLEFIELD, "X must match exactly")


# -------------------------------------------------------------------- Oasis --

func test_oasis_shields_a_creature() -> void:
	var oasis := put_battlefield(0, "Oasis")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, oasis, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.prevention, 1)


# ---------------------------------------------------------------- Angry Mob --

func test_angry_mob_grows_on_your_turn() -> void:
	put_battlefield(1, "Swamp")
	put_battlefield(1, "Swamp")
	var mob := put_battlefield(0, "Angry Mob")
	assert_eq(mob.cur_power, 4, "2 plus their two Swamps")
	advance_to_next_turn()
	assert_eq(mob.cur_power, 2, "just 2 on their turn")


# ------------------------------------------------------- Goblin Rock Sled --

func test_goblin_rock_sled_needs_a_mountain_to_attack() -> void:
	var sled := put_battlefield(0, "Goblin Rock Sled")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [sled.id]), "Mountain")
	put_battlefield(1, "Mountain")
	assert_ok(g.declare_attackers(0, [sled.id]))


func test_goblin_rock_sled_stalls_after_attacking() -> void:
	var sled := put_battlefield(0, "Goblin Rock Sled")
	put_battlefield(1, "Mountain")
	run_combat([sled.id])
	resolve_stack()
	assert_true(sled.tapped)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(sled.tapped, "it doesn't untap after a swing")


# ------------------------------------------------------------ Fellwar Stone --

func test_fellwar_stone_borrows_their_colour() -> void:
	put_battlefield(1, "Forest")
	var stone := put_battlefield(0, "Fellwar Stone")
	assert_ok(g.tap_for_mana(0, stone))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 1)


func test_fellwar_stone_makes_nothing_with_nothing_to_copy() -> void:
	# "Add one mana of any color that a land an opponent controls could
	# produce": with no such colour there is no mana to add (audit 2026-09 —
	# this used to fall back to {C}).
	var stone := put_battlefield(0, "Fellwar Stone")
	assert_ok(g.tap_for_mana(0, stone))
	assert_eq(g.players[0].mana_pool.total(), 0)


# ---------------------------------------------------------------- Mind Bomb --

func test_mind_bomb_burns_both_players() -> void:
	var bomb := give_hand(0, "Mind Bomb")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, bomb, []))
	resolve_stack()
	assert_eq(g.players[0].life, 17)
	assert_eq(g.players[1].life, 17)


# -------------------------------------------------------------- Maze of Ith --

func test_maze_of_ith_calls_off_an_attack() -> void:
	var attacker := put_battlefield(0, "Hill Giant")
	var blocker := put_battlefield(1, "Grizzly Bears")
	var maze := put_battlefield(1, "Maze of Ith")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, maze, 0, [TargetRef.card(attacker)]))
	resolve_stack()
	assert_false(attacker.tapped, "untapped")
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {blocker.id: attacker.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(blocker.damage, 0, "no damage either way")
	assert_eq(attacker.damage, 0)


# --------------------------------------------------------------- War Barge --

func test_war_barge_ferries_and_drowns() -> void:
	var barge := put_battlefield(0, "War Barge")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, barge, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.cur_landwalk.has("island"))
	g.destroy(barge)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the passenger goes down with it")


# ------------------------------------------------------------ Martyr's Cry --

func test_martyrs_cry_exiles_the_white_and_pays_for_them() -> void:
	var white := put_battlefield(1, "Serra Angel")
	var green := put_battlefield(1, "Grizzly Bears")
	var cry := give_hand(0, "Martyr's Cry")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	var hand := g.players[1].hand.size()
	assert_ok(g.cast_spell(0, cry, []))
	resolve_stack()
	assert_eq(white.zone, Mtg.Zone.EXILE)
	assert_eq(green.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].hand.size(), hand + 1, "they drew for their martyr")


# ------------------------------------------------------- Tower of Coireall --

func test_tower_of_coireall_walks_past_walls() -> void:
	var tower := put_battlefield(0, "Tower of Coireall")
	var runner := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, tower, 0, [TargetRef.card(runner)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [runner.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {wall.id: runner.id}),
		"can't be blocked except by")


# ----------------------------------------------------------------- Festival --

func test_festival_calls_off_the_war() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var festival := give_hand(0, "Festival")
	# Walk to the OPPONENT's upkeep (advance_to_next_turn would sail past it).
	var guard := 0
	while (g.turn_number < 2 or g.current_step() != Mtg.Step.UPKEEP) and guard < 200:
		_advance_once()
		guard += 1
	assert_eq(g.active_player, 1)
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, festival, []))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(1, [bear.id]), "can't attack this turn")


# ----------------------------------------------------- Worms of the Earth --

func test_worms_of_the_earth_stop_land_drops() -> void:
	# Tested on the Worms' own turn: their upkeep already passed, so the
	# escape clause hasn't had a chance to break them yet.
	put_battlefield(0, "Worms of the Earth")
	var land := give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.play_land(0, land), "Worms of the Earth")


func test_worms_of_the_earth_can_be_bought_off_with_lands() -> void:
	# LANDS FIRST: "Lands can't enter the battlefield" is a real ban now, so
	# a Forest cannot be set up behind the Worms — not even by a test
	# helper, which puts permanents down through the same arrival path.
	var a := put_battlefield(1, "Forest")
	var b := put_battlefield(1, "Forest")
	var worms := put_battlefield(0, "Worms of the Earth")
	advance_to_next_turn()      # their upkeep: they pay two lands
	resolve_stack()
	assert_eq(worms.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)
