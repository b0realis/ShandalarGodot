extends GameTest
## SAFE BLOCK, THEN FINISH IT (2026-09-10, [member
## AiProfile.reinforces_blocks]; `docs/forge/combat.md` P4).
##
## [method AiPlayer._best_block_for] is a LADDER and it returns on the
## first rung that answers, so the free absorb (rung 1.5 — a wall soaks
## the hit at zero cost) sits above the value trade and above the gang.
## A wall on the table therefore blocks alone every time and the rungs
## below it are never reached, however many bodies are standing at home.
## Reproduced before a line was written:
##
##     their Serra Angel 4/4    ours: Wall of Swords 3/5, Wall of Swords 3/5
##         _plan_blocks -> ["Wall of Swords"] ; band kills it: false
##           + Wall of Swords -> kills it: true ; that body dies: false
##
##     their Craw Wurm 6/4      ours: Wall of Stone 0/8, Water Elemental 5/4
##         _plan_blocks -> ["Wall of Stone"] ; band kills it: false
##           + Water Elemental -> kills it: true ; that body dies: true
##
## The first of those costs NOTHING — two walls that both live through a
## Serra Angel and together deal it exactly four — and the pilot declined
## it.
##
## THE NOTE'S OWN HEADLINE BOARD DOES NOT ADD UP, and that is recorded
## here rather than argued: a Wall of Stone is 0/8, so "Wall of Stone plus
## Grizzly Bears kill the Craw Wurm" is 0 + 2 against a toughness of 4.
## The knob refuses it on both arms and `test_a_gap_two_damage_cannot_close`
## is that arithmetic.
##
## Every behaviour below is pinned with the knob ON and with it OFF, and
## the OFF arm is the pilot as it was.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.reinforces_blocks = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.reinforces_blocks = false
	return profile


## The block plan the ladder makes for one attacker, as card names.
func _plan_names(ai: AiPlayer, attacker: CardInstance,
		free: Array[CardInstance]) -> Array:
	var used: Array[int] = []
	var attackers: Array[CardInstance] = [attacker]
	var plan := ai._plan_blocks(g, attackers, free, false, used)
	var names: Array = []
	for blocker_id in plan:
		if int(plan[blocker_id]) != attacker.id:
			continue
		names.append(g.find_instance(int(blocker_id)).data.card_name)
	names.sort()
	return names


func _bodies(pid: int, names: Array) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for n in names:
		out.append(put_battlefield(pid, n))
	return out


# ------------------------------------------------- the free reinforcement --

func test_two_walls_finish_the_serra_angel() -> void:
	var ai := _ai(_on())
	var angel := put_battlefield(1, "Serra Angel")
	var walls := _bodies(0, ["Wall of Swords", "Wall of Swords"])
	assert_eq(_plan_names(ai, angel, walls),
		["Wall of Swords", "Wall of Swords"],
		"both walls, because both live and together they deal four")
	var band: Array[CardInstance] = walls
	assert_true(ai._band_kills(g, angel, band), "and the Angel dies to it")
	for wall in walls:
		assert_false(ai._dies_to(g, wall, angel), "and neither wall is spent")


func test_off_one_wall_watches_the_angel_walk_away() -> void:
	var ai := _ai(_off())
	var angel := put_battlefield(1, "Serra Angel")
	var walls := _bodies(0, ["Wall of Swords", "Wall of Swords"])
	assert_eq(_plan_names(ai, angel, walls), ["Wall of Swords"],
		"the free absorb answers and the ladder returns")
	var band: Array[CardInstance] = [walls[0]]
	assert_false(ai._band_kills(g, angel, band), "the Angel lives")


# ------------------------------------------------ the priced reinforcement --

func test_the_body_that_dies_to_close_the_kill_is_taken() -> void:
	var ai := _ai(_on())
	var wurm := put_battlefield(1, "Craw Wurm")
	var ours := _bodies(0, ["Wall of Stone", "Water Elemental"])
	assert_eq(_plan_names(ai, wurm, ours),
		["Wall of Stone", "Water Elemental"])
	assert_true(ai._band_kills(g, wurm, ours), "6/4 dies to five damage")
	assert_true(ai._dies_to(g, ours[1], wurm), "and the Elemental is spent")
	# Relational on purpose: the evaluator's constants are a row of their
	# own (`docs/AI-next-wave.md`, wave 5) and this rule is about the
	# ORDER of two worths, not about either number.
	assert_lt(Evaluator.permanent_value(ours[1]),
		Evaluator.permanent_value(wurm),
		"worth strictly less than the prize, which is the whole rule")


func test_off_the_wall_soaks_it_and_the_wurm_comes_back() -> void:
	var ai := _ai(_off())
	var wurm := put_battlefield(1, "Craw Wurm")
	var ours := _bodies(0, ["Wall of Stone", "Water Elemental"])
	assert_eq(_plan_names(ai, wurm, ours), ["Wall of Stone"])
	var band: Array[CardInstance] = [ours[0]]
	assert_false(ai._band_kills(g, wurm, band))


func test_a_body_worth_as_much_as_the_prize_stays_home() -> void:
	# Forge's own bound (`AiBlockController.java:849`): the body that dies
	# has to be worth STRICTLY less than the attacker it kills. Ours for
	# theirs is not a reinforcement, it is a trade the ladder already
	# declined at rung 2.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		var wurm := put_battlefield(1, "Craw Wurm")
		var ours := _bodies(0, ["Wall of Stone", "Craw Wurm"])
		assert_almost_eq(Evaluator.permanent_value(ours[1]),
			Evaluator.permanent_value(wurm), 0.01, "worth exactly the prize")
		assert_eq(_plan_names(ai, wurm, ours), ["Wall of Stone"],
			"knob on" if on else "knob off")


func test_a_gap_two_damage_cannot_close() -> void:
	# `docs/forge/combat.md` P4's headline board, and the arithmetic that
	# refuses it: a Wall of Stone is 0/8 and a Grizzly Bears is 2/2, so
	# the pair deals TWO to a toughness of four. The row is recorded, not
	# forced.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		var wurm := put_battlefield(1, "Craw Wurm")
		var ours := _bodies(0, ["Wall of Stone", "Grizzly Bears"])
		assert_eq(_plan_names(ai, wurm, ours), ["Wall of Stone"],
			"knob on" if on else "knob off")


# --------------------------------------------- the bodies it never touches --

func test_a_regenerator_is_never_reinforced() -> void:
	# [method AiPlayer._shieldable]: their open mana against their cheapest
	# regeneration shield. Adding a body to kill something that will not
	# stay dead is the plainest waste there is.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		var bones := put_battlefield(1, "Drudge Skeletons")
		put_battlefield(1, "Swamp")
		var ours := _bodies(0, ["Wall of Stone", "Water Elemental"])
		assert_true(ai._shieldable(g, bones), "one Swamp is the shield")
		assert_eq(_plan_names(ai, bones, ours), ["Wall of Stone"],
			"knob on" if on else "knob off")


func test_an_indestructible_attacker_is_never_reinforced() -> void:
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		var wurm := put_battlefield(1, "Craw Wurm")
		var ours := _bodies(0, ["Wall of Stone", "Water Elemental"])
		# After the last permanent is placed: every entry recalculates the
		# live characteristics and would wipe a flag set before it.
		wurm.cur_indestructible = true
		assert_eq(_plan_names(ai, wurm, ours), ["Wall of Stone"],
			"knob on" if on else "knob off")


func test_a_band_that_already_paid_a_body_is_left_alone() -> void:
	# The chump and the trade are not what this is for: Forge records the
	# attacker in `blockedButUnkilled` from the SAFE block maker, and a
	# band with a corpse in it is not a safe block.
	var ai := _ai(_on())
	var wurm := put_battlefield(1, "Craw Wurm")
	var ours := _bodies(0, ["Grizzly Bears", "Water Elemental"])
	g.players[0].life = 4
	var used: Array[int] = []
	var attackers: Array[CardInstance] = [wurm]
	var plan := ai._plan_blocks(g, attackers, ours, true, used, true)
	assert_eq(plan.size(), 1, "the chump is one body and stays one body")
	assert_true(ai._dies_to(g, g.find_instance(int(plan.keys()[0])), wurm),
		"and that body is spent, which is why nothing joins it")


# ------------------------------------------- how it composes with the reads --

func test_their_open_mana_sizes_the_body_the_gang_has_to_kill() -> void:
	# [member AiProfile.reads_pumps] is read by [method
	# AiPlayer._band_kills], so the gap the reinforcement has to close is
	# the one their Swamps pay for and not the printed one. Behind three
	# Swamps the Shade is a 3/4, the wall alone does nothing to it, and
	# the whole board is what finishes it.
	var ai := _ai(_on())
	var shade := put_battlefield(1, "Frozen Shade")
	for _i in 3:
		put_battlefield(1, "Swamp")
	var ours := _bodies(0, ["Wall of Stone", "Grizzly Bears", "Hill Giant"])
	assert_eq(ai._pump_reach(g, shade), Vector2i(3, 3), "three Swamps")
	assert_eq(_plan_names(ai, shade, ours),
		["Grizzly Bears", "Hill Giant", "Wall of Stone"],
		"five damage against a toughness their mana put at four")


func test_and_their_pump_killing_OUR_body_is_still_not_read_on_defence() -> void:
	# The asymmetry [member AiProfile.reads_pumps] shipped with, arriving
	# here: the pump that decides whether THEIR body dies is read
	# everywhere, and the pump that decides whether OURS dies is read only
	# where a body of ours is being SENT into theirs. So the Bears above
	# counts as a SAFE reinforcement — it does not die to a printed 0/1 —
	# and the mana that would kill it is mana that did not reach our face.
	var ai := _ai(_on())
	var shade := put_battlefield(1, "Frozen Shade")
	for _i in 3:
		put_battlefield(1, "Swamp")
	var bears := put_battlefield(0, "Grizzly Bears")
	assert_false(ai._dies_to(g, bears, shade),
		"the block side reads the printed body, on purpose")


func test_without_the_read_the_ladder_never_needs_a_second_body() -> void:
	var profile := _on()
	profile.reads_pumps = false
	var ai := _ai(profile)
	var shade := put_battlefield(1, "Frozen Shade")
	for _i in 3:
		put_battlefield(1, "Swamp")
	var ours := _bodies(0, ["Wall of Stone", "Grizzly Bears", "Hill Giant"])
	assert_eq(ai._pump_reach(g, shade), Vector2i.ZERO, "nothing is read")
	assert_eq(_plan_names(ai, shade, ours), ["Grizzly Bears"],
		"a printed 0/1 dies to the cheapest body at rung 1")


func test_a_gap_their_mana_puts_out_of_reach_buys_nothing() -> void:
	# Six Swamps make the Shade a 6/7, which the whole board's five damage
	# does not answer — so the wall soaks it alone and no body is thrown
	# after it.
	var ai := _ai(_on())
	var shade := put_battlefield(1, "Frozen Shade")
	for _i in 6:
		put_battlefield(1, "Swamp")
	var ours := _bodies(0, ["Wall of Stone", "Grizzly Bears", "Hill Giant"])
	assert_eq(ai._pump_reach(g, shade), Vector2i(6, 6), "six Swamps")
	assert_eq(_plan_names(ai, shade, ours), ["Wall of Stone"])


func test_rampage_is_charged_before_the_second_body_is_bought() -> void:
	# CR 702.23: the body a gang meets is not the body it was declared
	# against. A Craw Wurm wearing rampage 2 is an 8/6 the moment a second
	# blocker joins, which kills the Wall of Stone as well — so the price
	# is two bodies, not one, and the pair is refused.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		var wurm := put_battlefield(1, "Craw Wurm")
		var ours := _bodies(0, ["Wall of Stone", "Water Elemental"])
		wurm.cur_rampage = 2
		assert_eq(_plan_names(ai, wurm, ours), ["Wall of Stone"],
			"knob on" if on else "knob off")


# ------------------------------------------------ the risk the note names --

func test_the_trick_on_the_attacker_takes_both_bodies() -> void:
	# `docs/forge/combat.md` P4's own risk paragraph, played out: the
	# second body is exposed to a combat trick, and a Giant Growth on the
	# Wurm takes the Elemental AND the wall the ladder had made safe.
	# Forge accepts the exposure; what bounds it is the price rule, which
	# is `test_a_body_worth_as_much_as_the_prize_stays_home` above.
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var wurm := put_battlefield(1, "Craw Wurm")
	var growth := give_hand(1, "Giant Growth")
	var ours := _bodies(0, ["Wall of Stone", "Water Elemental"])
	assert_eq(_plan_names(ai, wurm, ours),
		["Wall of Stone", "Water Elemental"], "the pair is declared")
	assert_true(ai._dies_to(g, ours[0], wurm, Vector2i.ZERO, Vector2i(3, 3)),
		"and a +3/+3 kills the wall too")
	assert_true(ai._dies_to(g, ours[1], wurm, Vector2i.ZERO, Vector2i(3, 3)),
		"and the Elemental with it")
	assert_false(ai._dies_to(g, wurm, ours[1], Vector2i(3, 3)),
		"while the Wurm walks away")
	assert_not_null(growth, "the card that does it is in their hand")
	assert_not_null(foe)


# --------------------------------------------- through the live declaration --

## Hand the turn to seat 1 and walk it to its declare-blockers.
func _their_swing(ai: AiPlayer, attacker: CardInstance) -> void:
	var guard := 0
	while (not g.awaiting_attackers or g.active_player != 1) \
			and not g.game_over and guard < 200:
		if g.awaiting_attackers:
			assert_ok(g.declare_attackers(g.active_player, []))
		elif g.awaiting_blockers:
			assert_ok(g.declare_blockers(g.opponent_of(g.active_player), {}))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_true(g.awaiting_attackers, "reached their declaration")
	assert_ok(g.declare_attackers(1, [attacker.id]))
	guard = 0
	while not g.awaiting_blockers and not g.game_over and guard < 60:
		if g.priority_player == 0:
			ai.act(g)
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	assert_true(g.awaiting_blockers, "reached the block declaration")


func _play_out_combat(ai: AiPlayer, foe: AiPlayer) -> void:
	var guard := 0
	while not g.game_over and g.current_step() <= Mtg.Step.COMBAT_END \
			and guard < 120:
		var mine := ai.act(g)
		var theirs := foe.act(g)
		if mine == "" and theirs == "":
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1


func test_the_angel_dies_in_a_real_combat() -> void:
	# The whole path, not the planner alone: their declaration, our block,
	# the damage step.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		var foe := _ai(AiProfile.wizard(), 1)
		var angel := put_battlefield(1, "Serra Angel")
		var walls := _bodies(0, ["Wall of Swords", "Wall of Swords"])
		_their_swing(ai, angel)
		assert_string_contains(ai.act(g),
			"declared 2 block(s)" if on else "declared 1 block(s)")
		_play_out_combat(ai, foe)
		assert_eq(angel.zone,
			Mtg.Zone.GRAVEYARD if on else Mtg.Zone.BATTLEFIELD,
			"knob on" if on else "knob off")
		for wall in walls:
			assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD,
				"and the walls cost nothing either way")
		assert_eq(g.players[0].life, 20, "no damage got past them")


# --------------------------------------------------- the knob is a knob --

func test_the_knob_reads_off_the_profile_by_name() -> void:
	var profile := AiProfile.wizard()
	assert_true(profile.reinforces_blocks, "on at the top rung")
	assert_eq(profile.apply_overrides("reinforces_blocks=off"), "")
	assert_false(profile.reinforces_blocks)
	assert_eq(profile.apply_overrides("reinforces_blocks=on"), "")
	assert_true(profile.reinforces_blocks)


func test_the_rungs_are_the_combat_reads_rungs() -> void:
	assert_false(AiProfile.apprentice().reinforces_blocks)
	assert_false(AiProfile.magician().reinforces_blocks)
	assert_true(AiProfile.sorcerer().reinforces_blocks)
	assert_true(AiProfile.wizard().reinforces_blocks)
