extends GameTest
## THE TWO LEFTOVERS OF THE THIRD PUMP PASS (2026-09-09, the fourth pass at
## [member AiProfile.pumps_to_attack]; both were named in
## `docs/ai-difficulty.md` §5 and at their own sites in the code).
##
## ONE — A BODY IN A GANG WAS PRICED AT NO BREATH. [method
## AiPlayer._combat_self_pumps] asks a blocker whether the breath wins its
## trade, and "its trade" meant "does this body kill the attacker ALONE".
## The block ladder's third rung declares a GANG, on the probe's sizes,
## where no single body has to kill anything — so the pilot declared the
## gang and then bought nothing for it. Reproduced on the third pass's own
## board: a Carrion Ants and a Scathe Zombies in front of a Force of
## Nature with six Swamps open, the declaration pricing the swarm at six
## breaths and the gang at exactly the eight damage an 8/8 needs — and the
## recovery bought NOTHING. Both bodies died at 0/1 and 2/2, five
## trampled through, the trampler walked away, and all six Swamps were
## still untapped. [method AiPlayer._band_kills] is the ladder's own gang
## question written down as a predicate, and the recovery, the residue
## ([method AiPlayer._absorbed_by]) and the declaration now share it.
##
## TWO — AN UNBLOCKED FIREBREATHER SPENT THE COUNTERSPELL'S MANA. Every
## other breath in the file is priced against [method
## AiPlayer._pump_reserve] — the second main phase's best cast AND the
## held instant or counter the reactive game is waiting on. [method
## AiPlayer._offensive_combat_response] booked only the first of the two,
## a note of 36058fc's that outlived two passes. Reproduced: a Carrion
## Ants unblocked behind four Swamps and two Islands with a Counterspell
## in hand — the declaration priced it at FOUR breaths and the recovery
## bought SIX, tapping every land, and the counter could not be paid for.
##
## AND ONE THING RULED RATHER THAN BUILT, pinned here so it is not
## reopened: [method AiPlayer._offensive_combat_response] does NOT consult
## the pump plan. It spends off it — measured below — and it costs
## nothing, because by the time it runs the bodies it serves are UNBLOCKED
## and every point they buy is face damage, which is fungible between
## them. The reasoning is at the site.
##
## Every behaviour is pinned with the knob ON and with it OFF. Neither fix
## can move the null: the gang question is asked only in the plan's own
## pass, which does not exist below Sorcerer, and the reserve falls back
## to the second main phase alone.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.pumps_to_attack = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.pumps_to_attack = false
	return profile


func _lands(seat: int, land_name: String, count: int) -> void:
	for _i in count:
		put_battlefield(seat, land_name)


func _untapped_lands(seat: int) -> int:
	var n := 0
	for inst in g.players[seat].battlefield:
		if inst.is_land() and not inst.tapped:
			n += 1
	return n


func _free() -> Array[CardInstance]:
	var free: Array[CardInstance] = []
	for inst in g.players[0].battlefield:
		if inst.is_creature() and not inst.tapped:
			free.append(inst)
	return free


func _mine(card_name: String) -> CardInstance:
	for inst in g.players[0].battlefield:
		if inst.data.card_name == card_name:
			return inst
	return null


func _attacking() -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for id in g.combat.attackers:
		var a := g.find_instance(id)
		if a != null and a.zone == Mtg.Zone.BATTLEFIELD:
			out.append(a)
	return out


func _cycle_to_attack(seat: int) -> void:
	var guard := 0
	while (not g.awaiting_attackers or g.active_player != seat) \
			and not g.game_over and guard < 200:
		if g.awaiting_attackers:
			assert_ok(g.declare_attackers(g.active_player, []))
		elif g.awaiting_blockers:
			assert_ok(g.declare_blockers(g.opponent_of(g.active_player), {}))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_true(g.awaiting_attackers, "reached a declaration")
	assert_eq(g.active_player, seat, "and it is the right seat's")


func _reach_blockers(ai: AiPlayer) -> void:
	var guard := 0
	while not g.awaiting_blockers and not g.game_over and guard < 60:
		if g.priority_player == 0:
			ai.act(g)
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	assert_true(g.awaiting_blockers, "reached the block declaration")


func _play_out_combat(ai: AiPlayer, foe: AiPlayer) -> void:
	var guard := 0
	while not g.game_over and g.current_step() <= Mtg.Step.COMBAT_DAMAGE \
			and guard < 120:
		var mine := ai.act(g)
		var theirs := foe.act(g)
		if mine == "" and theirs == "":
			break
		guard += 1


## Their swing: [param bodies] and [param count] of [param land_name] on
## our side, [param attackers] on theirs, us at [param life], stopped on
## our block declaration.
func _swing(ai: AiPlayer, land_name: String, count: int, bodies: Array,
		attackers: Array, life := 20) -> Array[CardInstance]:
	for card_name in bodies:
		put_battlefield(0, card_name)
	_lands(0, land_name, count)
	_cycle_to_attack(1)
	g.players[0].life = life
	var theirs: Array[CardInstance] = []
	var ids: Array = []
	for card_name in attackers:
		var inst := put_battlefield(1, card_name)
		theirs.append(inst)
		ids.append(inst.id)
	assert_ok(g.declare_attackers(1, ids))
	_reach_blockers(ai)
	return theirs


## OUR swing, declared by hand so the test names the attackers: the plan
## is written down exactly where [method AiPlayer._attack_choice_once_pumped]
## writes it, and nothing blocks.
func _our_unblocked_attack(ai: AiPlayer, bodies: Array) -> Array[CardInstance]:
	var mine: Array[CardInstance] = []
	for card_name in bodies:
		mine.append(put_battlefield(0, card_name))
	_cycle_to_attack(0)
	var ours: Array[CardInstance] = []
	var ids: Array = []
	for inst in mine:
		ours.append(inst)
		ids.append(inst.id)
	ai._remember_pump_plan(g, ai._pump_shares(g, ours))
	assert_ok(g.declare_attackers(0, ids))
	_reach_blockers(ai)
	assert_ok(g.declare_blockers(1, {}))
	return ours


# ------------------------------------------- one: the gang's own breath --

func test_the_gang_buys_the_breaths_the_block_was_declared_on() -> void:
	# THE REPORT'S BOARD. Six Swamps, a Carrion Ants and a Scathe Zombies,
	# a Force of Nature (8/8 trample) coming. The ladder's gang rung reads
	# the probe's 6/7 beside the 2/2 and declares the block on eight
	# damage — exactly what an 8/8 needs. Before this pass the recovery
	# asked each body whether it killed the trampler ALONE, neither does,
	# and it bought nothing: both blockers died, five trampled through and
	# every Swamp was still untapped.
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var theirs := _swing(ai, "Swamp", 6, ["Carrion Ants", "Scathe Zombies"],
		["Force of Nature"], 12)
	assert_string_contains(ai.act(g), "declared 2 block(s)", "the gang is made")
	_play_out_combat(ai, foe)
	assert_eq(theirs[0].zone, Mtg.Zone.GRAVEYARD, "the trampler died")
	assert_eq(g.players[0].life, 12, "and nothing came through it")
	assert_eq(_untapped_lands(0), 0, "six Swamps bought the six breaths")
	assert_eq(_mine("Carrion Ants").cur_power, 6, "the swarm is the size it was declared")


func test_off_the_same_gang_is_never_declared_at_all() -> void:
	# The null. With no probe there is no share, a 0/1 and a 2/2 are what
	# the ladder sees, and no gang of them kills an 8/8 — so the ladder
	# chumps with one body and takes seven. Pinned so the fix above can be
	# seen to live inside the knob and nowhere else.
	var ai := _ai(_off())
	var foe := _ai(AiProfile.wizard(), 1)
	var theirs := _swing(ai, "Swamp", 6, ["Carrion Ants", "Scathe Zombies"],
		["Force of Nature"], 12)
	assert_string_contains(ai.act(g), "declared 1 block(s)")
	_play_out_combat(ai, foe)
	assert_eq(theirs[0].zone, Mtg.Zone.BATTLEFIELD, "the trampler walks away")
	assert_eq(g.players[0].life, 5, "seven through")
	assert_eq(_untapped_lands(0), 6, "and six Swamps never spent")


func test_the_residue_reads_the_breaths_the_gang_will_buy() -> void:
	# The reading, taken where the declaration takes it. [method
	# AiPlayer._absorbed_by] is asked with the BAND now, and only the band
	# changes the answer: a body with no share is what it looks like
	# either way, and asked alone the swarm is still the 0/1 it was
	# printed as.
	var ai := _ai(_on())
	var theirs := _swing(ai, "Swamp", 6, ["Carrion Ants", "Scathe Zombies"],
		["Force of Nature"], 12)
	var free := _free()
	var shares := ai._pump_shares(g, free)
	var mark := g.make_mark()
	for id in shares:
		var bonus: Vector2i = Vector2i(shares[id]["bonus"]) * int(shares[id]["count"])
		g.continuous.add_until_eot_pump(int(id), bonus.x, bonus.y)
	g.recalculate()
	var ants := _mine("Carrion Ants")
	var zombies := _mine("Scathe Zombies")
	var band: Array[CardInstance] = [ants, zombies]
	assert_eq(ai._absorbed_by(g, ants, theirs[0], shares), 1,
		"alone, the swarm buys nothing and absorbs its printed point")
	assert_eq(ai._absorbed_by(g, ants, theirs[0], shares, band), 7,
		"in the band it buys all six and stops the whole assignment")
	assert_eq(ai._absorbed_by(g, zombies, theirs[0], shares, band), 2,
		"a body with no share is what it looks like, band or none")
	assert_eq(ai._damage_after_value_blocks(g, _attacking(), free, shares), 0,
		"so the panic line reads nothing through, and nothing comes through")
	g.unmake_to(mark)
	g.end_search()


func test_a_gang_that_cannot_kill_still_buys_nothing_on_either_arm() -> void:
	# THE DIRECTION GUARD, and it is the whole reason the third pass left
	# this open rather than guessing at it. A Colossus of Sardia is a 9/9,
	# and the swarm's six breaths beside the Zombies' two reach EIGHT — so
	# the gang does not kill, no breath is on the path to a kill, and the
	# recovery must buy nothing at all. The residue must stay the printed
	# toughness with it: under-reading what we absorb is the safe way to
	# be wrong, and this pass must not have made it the other one.
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		var theirs := _swing(ai, "Swamp", 6, ["Carrion Ants", "Scathe Zombies"],
			["Colossus of Sardia"], 20)
		var ants := _mine("Carrion Ants")
		var zombies := _mine("Scathe Zombies")
		var shares := ai._pump_shares(g, _free())
		var band: Array[CardInstance] = [ants, zombies]
		var mark := g.make_mark()
		for id in shares:
			var bonus: Vector2i = Vector2i(shares[id]["bonus"]) * int(shares[id]["count"])
			g.continuous.add_until_eot_pump(int(id), bonus.x, bonus.y)
		g.recalculate()
		assert_eq(ai._absorbed_by(g, ants, theirs[0], shares, band), 1,
			"the residue is the printed point (%s)" % profile.profile_name)
		g.unmake_to(mark)
		g.end_search()
		ai._remember_pump_plan(g, shares)
		assert_ok(g.declare_blockers(0,
			{ants.id: theirs[0].id, zombies.id: theirs[0].id}))
		assert_eq(ai._combat_self_pumps(g), "",
			"nothing is bought (%s)" % profile.profile_name)
		assert_eq(_untapped_lands(0), 6,
			"and every Swamp is kept (%s)" % profile.profile_name)


func test_a_band_of_one_is_the_alone_question_it_always_was() -> void:
	# [method AiPlayer._band_kills] is [method AiPlayer._dies_to] for a
	# single body, which is what both readings fall back to when there is
	# no gang — and what keeps every block this file does not touch where
	# it was. Asked of a body that kills and one that does not, on both
	# arms.
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		var bears := put_battlefield(0, "Grizzly Bears")
		var wall := put_battlefield(0, "Wall of Stone")
		var giant := put_battlefield(1, "Hill Giant")
		var one: Array[CardInstance] = [bears]
		var other: Array[CardInstance] = [wall]
		assert_eq(ai._band_kills(g, giant, one),
			ai._dies_to(g, giant, bears),
			"a 2/2 against a 3/3 (%s)" % profile.profile_name)
		assert_eq(ai._band_kills(g, giant, other),
			ai._dies_to(g, giant, wall),
			"a 0/8 against a 3/3 (%s)" % profile.profile_name)
		var both: Array[CardInstance] = [bears, wall]
		assert_false(ai._band_kills(g, giant, one), "neither kills it alone")
		assert_false(ai._band_kills(g, giant, both),
			"and a 2/2 with a 0/8 beside it still does not")
		assert_true(ai._band_kills(g, giant, one, {bears.id: Vector2i(1, 0)}),
			"one more point of power and it does")


func test_the_gang_question_is_the_plans_own_pass() -> void:
	# WHERE THE NULL LIVES. The gang is priced with every mate at the size
	# the DECLARATION allotted it, so the question belongs to the pass
	# that honours the plan — and below Sorcerer there is no plan and no
	# such pass. Same board, same hand-declared gang, and the knob is the
	# only difference: on, the swarm buys its six; off, it buys none.
	for knob in [true, false]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		var foe := _ai(AiProfile.wizard(), 1)
		var theirs := _swing(ai, "Swamp", 6, ["Carrion Ants", "Scathe Zombies"],
			["Force of Nature"], 12)
		var ants := _mine("Carrion Ants")
		var zombies := _mine("Scathe Zombies")
		ai._remember_pump_plan(g, ai._pump_shares(g, _free()))
		assert_ok(g.declare_blockers(0,
			{ants.id: theirs[0].id, zombies.id: theirs[0].id}))
		_play_out_combat(ai, foe)
		if knob:
			assert_eq(theirs[0].zone, Mtg.Zone.GRAVEYARD, "on: the trampler died")
			assert_eq(g.players[0].life, 12, "on: nothing through")
		else:
			assert_eq(theirs[0].zone, Mtg.Zone.BATTLEFIELD, "off: it walks away")
			assert_eq(g.players[0].life, 7, "off: five trampled through")
			assert_eq(_untapped_lands(0), 6, "off: and six Swamps kept")


# ------------------------------------- two: the counterspell's own mana --

func test_the_unblocked_firebreather_leaves_the_counter_its_mana() -> void:
	# Four Swamps, two Islands, a Counterspell in hand and a Carrion Ants
	# swinging into an open lane. [method AiPlayer._pump_reserve] books
	# {U}{U} for the counter, so the declaration prices the swarm at four
	# breaths — and the recovery now buys exactly those four.
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	_lands(0, "Swamp", 4)
	_lands(0, "Island", 2)
	var counter := give_hand(0, "Counterspell")
	var ours := _our_unblocked_attack(ai, ["Carrion Ants"])
	assert_eq(int(ai._pump_shares(g, ours).get(ours[0].id, {}).get("count", 0)), 4,
		"the declaration prices four, not six")
	_play_out_combat(ai, foe)
	assert_eq(ours[0].cur_power, 4, "and four is what it bought")
	assert_eq(g.players[1].life, 16)
	assert_eq(_untapped_lands(0), 2, "the two Islands are still there")
	assert_false(ai._plan_taps(g, counter.data.cost, 0).is_empty(),
		"so the Counterspell can still be paid for")


func test_off_the_unblocked_firebreather_still_spends_the_counters_mana() -> void:
	# The null, and it is the malfunction the note of 36058fc described:
	# only the second main phase is booked, so all six lands go into two
	# extra points of face damage and the counter is dead in hand.
	var ai := _ai(_off())
	var foe := _ai(AiProfile.wizard(), 1)
	_lands(0, "Swamp", 4)
	_lands(0, "Island", 2)
	var counter := give_hand(0, "Counterspell")
	var ours := _our_unblocked_attack(ai, ["Carrion Ants"])
	_play_out_combat(ai, foe)
	assert_eq(ours[0].cur_power, 6, "six breaths")
	assert_eq(g.players[1].life, 14)
	assert_eq(_untapped_lands(0), 0)
	assert_true(ai._plan_taps(g, counter.data.cost, 0).is_empty(),
		"and the Counterspell cannot be cast")


func test_the_second_main_phase_is_still_booked_on_both_arms() -> void:
	# The booking this routine already had is untouched: a Sengir Vampire
	# in hand behind six Swamps is the second main phase's best cast, and
	# the breath may spend only what that cast does not need — one Swamp,
	# on either arm.
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		var foe := _ai(AiProfile.wizard(), 1)
		_lands(0, "Swamp", 6)
		give_hand(0, "Sengir Vampire")
		var ours := _our_unblocked_attack(ai, ["Carrion Ants"])
		_play_out_combat(ai, foe)
		assert_eq(ours[0].cur_power, 1,
			"one breath, and the Vampire keeps its five (%s)" % profile.profile_name)
		assert_eq(_untapped_lands(0), 5, profile.profile_name)


func test_the_lethal_breath_spends_the_counters_mana_anyway() -> void:
	# The one case where a reserve is worth nothing: the pumps ARE the
	# game. Their life is six, the swarm is unblocked behind six lands,
	# and a counter kept for a turn that will not happen is a card kept
	# for nobody. Both arms, because the lethal clause predates the knob.
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		var foe := _ai(AiProfile.wizard(), 1)
		_lands(0, "Swamp", 4)
		_lands(0, "Island", 2)
		give_hand(0, "Counterspell")
		g.players[1].life = 6
		var ours := _our_unblocked_attack(ai, ["Carrion Ants"])
		_play_out_combat(ai, foe)
		assert_eq(ours[0].cur_power, 6,
			"every land went into the kill (%s)" % profile.profile_name)
		assert_true(g.players[1].life <= 0 or g.game_over,
			"and the game is over (%s)" % profile.profile_name)


func test_the_plan_is_not_consulted_by_the_unblocked_attacker_by_ruling() -> void:
	# THE RULING, PINNED SO IT IS NOT REOPENED. Two unblocked
	# firebreathers behind four Swamps, split two and two by the
	# declaration — and [method AiPlayer._offensive_combat_response] pours
	# all four into the first body it meets. It is off the plan and it
	# costs nothing: the bodies are unblocked, every point they buy is
	# face damage, and four points land whichever body carries them. The
	# same total on both arms, and the same on the plan or off it.
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		var foe := _ai(AiProfile.wizard(), 1)
		_lands(0, "Swamp", 4)
		var ours := _our_unblocked_attack(ai, ["Carrion Ants", "Vampire Bats"])
		if profile.pumps_to_attack:
			assert_eq(ai._pump_plan_for(g, ours[0]), 2, "the plan says two")
			assert_eq(ai._pump_plan_for(g, ours[1]), 2, "and two")
		_play_out_combat(ai, foe)
		assert_eq(ours[0].cur_power + ours[1].cur_power, 4,
			"four points of power, however they were split (%s)"
				% profile.profile_name)
		assert_eq(g.players[1].life, 16,
			"and four damage lands either way (%s)" % profile.profile_name)
		assert_eq(_untapped_lands(0), 0, profile.profile_name)
