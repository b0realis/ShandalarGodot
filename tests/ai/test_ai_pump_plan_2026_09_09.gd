extends GameTest
## THE TWO THINGS THE FIREBREATHER'S PROBE LEFT STANDING (2026-09-09, the
## third pass at [member AiProfile.pumps_to_attack] and both of them named
## as open in `docs/ai-difficulty.md` §5 the day the block half landed).
##
## Both come from the same seam. The declaration probes ([method
## AiPlayer._attack_choice_once_pumped], [method
## AiPlayer._block_choice_once_pumped]) hang the WHOLE bonus each body's
## share of the open mana can reach and make the declaration on that
## board; [method AiPlayer._combat_self_pumps] then buys the breaths for
## real, one at a time, and it buys FEWER than the probe hung — a
## toughness bonus only when it saves the body, a power bonus only when it
## wins the trade. Where the ladder asks a kill-or-survive QUESTION the
## two agree by construction. Where it reads a MAGNITUDE they do not, and
## there are exactly two such readings.
##
## ONE — THE TRAMPLER'S OVERFLOW. [method
## AiPlayer._damage_after_value_blocks] (the panic line) and the chump
## rung's price both measure a trampler's surplus against the blocker's
## toughness, and inside the probe that is the toughness the probe put
## there. Measured before this landed: a Carrion Ants behind six Swamps
## and a Scathe Zombies ganging a Force of Nature read the swing as ZERO
## through — a 6/7 and a 2/2 stop eight — and took FIVE, because neither
## body kills an 8/8 alone, so nothing was ever bought and the swarm
## blocked at 0/1 with six Swamps still untapped. Put a Hill Giant beside
## the Force of Nature and stand the pilot at 8 life and the under-read is
## fatal: the residue reads 3, the chump rung stays priced, the spare body
## keeps its life, and eight damage arrives on a pilot that had eight —
## `over=true`. Under-reading lethal is the dangerous direction.
## [method AiPlayer._absorbed_by] asks the recovery's own question
## instead, and both readings go through it.
##
## TWO — THE POOL. [method AiPlayer._pump_shares] divides ONE pool among
## several bodies and the declaration is made on that division; [method
## AiPlayer._combat_self_pumps] then priced every body against the WHOLE
## remaining pool, so the first body down the battlefield could spend what
## the second was priced with. Measured before this landed: a Carrion Ants
## and a Vampire Bats behind four Swamps, split two and two, the Ants
## blocking a 3/2 and the Bats a 2/2 flier — the Ants took THREE Swamps to
## save itself, a save the plan had never priced and the ladder had not
## blocked for, and the Bats stayed a 0/1, killed nothing and died for
## nothing. The split is written down at the declaration
## ([member AiPlayer._pump_plan]) and spent down one activation at a time,
## with a second uncapped pass for the mana no plan wanted.
##
## AND THE THIRD CARD OF THAT REPORT, closed by RULING rather than by
## code: Rainbow Knights' `{W}{W}` still has no row, and the reason is
## written out below where the arithmetic can be seen.
##
## Every behaviour is pinned with the knob ON and with it OFF. Neither fix
## can move the null: the trample reading is inert without the probe's
## shares, and the plan pass is skipped outright below Sorcerer.


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


## The attackers in the order [method AiPlayer._declare_blocks] hands them
## to the ladder — biggest first.
func _attacking() -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for id in g.combat.attackers:
		var a := g.find_instance(id)
		if a != null and a.zone == Mtg.Zone.BATTLEFIELD:
			out.append(a)
	out.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return a.cur_power > b.cur_power)
	return out


func _their_turn() -> void:
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
	assert_eq(g.active_player, 1, "and it is their turn")


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


## Their swing, made on their turn so nothing on it has seen an upkeep:
## [param bodies] and [param count] of [param land_name] on our side,
## [param attackers] on theirs, us at [param life], stopped on our block
## declaration. Returns the attackers as instances.
func _swing(ai: AiPlayer, land_name: String, count: int, bodies: Array,
		attackers: Array, life := 20) -> Array[CardInstance]:
	for card_name in bodies:
		put_battlefield(0, card_name)
	_lands(0, land_name, count)
	_their_turn()
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


## Our creature named [param card_name] — the tests below own one of each.
func _mine(card_name: String) -> CardInstance:
	for inst in g.players[0].battlefield:
		if inst.data.card_name == card_name:
			return inst
	return null


# ------------------------------------------ one: the trampler's overflow --

func test_the_trample_the_pilot_read_as_stopped_used_to_kill_it() -> void:
	# THE REPORT'S OWN BOARD. A Force of Nature (8/8 trample) and a Hill
	# Giant come at a pilot on eight life with a Carrion Ants behind six
	# Swamps, a Scathe Zombies and one spare body. The ladder gangs the
	# swarm and the Zombies onto the Force of Nature — and the probe's
	# 6/7 and the 2/2 look like ten points of blocker, so the residue
	# read three and the chump rung stayed priced. What actually landed
	# was eight: NEITHER body kills an 8/8 on its own, so
	# _combat_self_pumps bought nothing at all and the swarm stood there
	# as a 0/1 with all six Swamps up.
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	_swing(ai, "Swamp", 6,
		["Carrion Ants", "Scathe Zombies", "Hurloon Minotaur"],
		["Force of Nature", "Hill Giant"], 8)
	assert_string_contains(ai.act(g), "declared 3 block(s)",
		"the spare goes in front of the Hill Giant")
	_play_out_combat(ai, foe)
	assert_false(g.game_over, "the pilot is alive")
	assert_eq(g.players[0].life, 3, "five trampled through and the rest was stopped")


func test_off_the_same_swing_is_read_off_the_printed_board() -> void:
	# The null, and it is a different game entirely: with no probe there
	# is no share to hang, the ladder reads a 0/1 and a 2/2, and the panic
	# line reads the whole eleven points coming. Pinned so the fix above
	# can be seen to live inside the knob and nowhere else.
	var ai := _ai(_off())
	var foe := _ai(AiProfile.wizard(), 1)
	_swing(ai, "Swamp", 6,
		["Carrion Ants", "Scathe Zombies", "Hurloon Minotaur"],
		["Force of Nature", "Hill Giant"], 8)
	assert_string_contains(ai.act(g), "declared 3 block(s)")
	_play_out_combat(ai, foe)
	assert_eq(g.players[0].life, 1, "seven through, and six Swamps never spent")
	assert_eq(_untapped_lands(0), 6)


func test_the_residue_is_what_the_recovery_will_actually_stop() -> void:
	# The reading itself, taken where the declaration takes it: on the
	# probe's board, with the shares in hand and without them. Nought is
	# the old answer, five is the true one, and five is what lands.
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	_swing(ai, "Swamp", 6, ["Carrion Ants", "Scathe Zombies"],
		["Force of Nature"], 12)
	var attackers := _attacking()
	var free := _free()
	var shares := ai._pump_shares(g, free)
	var mark := g.make_mark()
	for id in shares:
		var bonus: Vector2i = Vector2i(shares[id]["bonus"]) * int(shares[id]["count"])
		g.continuous.add_until_eot_pump(int(id), bonus.x, bonus.y)
	g.recalculate()
	assert_eq(ai._damage_after_value_blocks(g, attackers, free), 0,
		"the old reading: a 6/7 and a 2/2 stop all eight")
	assert_eq(ai._damage_after_value_blocks(g, attackers, free, shares), 5,
		"the true one: neither kills it alone, so neither buys a breath")
	assert_eq(ai._absorbed_by(g, _mine("Carrion Ants"), attackers[0], shares), 1,
		"the swarm absorbs the toughness it is printed with")
	assert_eq(ai._absorbed_by(g, _mine("Scathe Zombies"), attackers[0], shares), 2,
		"and a body with no share is what it looks like")
	g.unmake_to(mark)
	g.end_search()
	assert_string_contains(ai.act(g), "declared 2 block(s)", "the gang is still made")
	_play_out_combat(ai, foe)
	assert_eq(g.players[0].life, 7, "five, exactly as the reading now says")


func test_the_breath_that_wins_the_trade_is_counted_because_it_is_bought() -> void:
	# NOT a blanket "price it at the printed body". A Craw Giant (6/4
	# trample) against the swarm behind five Swamps is a trade the ladder
	# takes, and _combat_self_pumps buys the FOUR breaths that kill a
	# four-toughness body — so the swarm really is a 4/5 when the damage
	# is divided and only one point comes past it. Reading that as five
	# would panic a pilot that is fine.
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var theirs := _swing(ai, "Swamp", 5, ["Carrion Ants"], ["Craw Giant"])
	var attackers := _attacking()
	var free := _free()
	var shares := ai._pump_shares(g, free)
	var mark := g.make_mark()
	for id in shares:
		var bonus: Vector2i = Vector2i(shares[id]["bonus"]) * int(shares[id]["count"])
		g.continuous.add_until_eot_pump(int(id), bonus.x, bonus.y)
	g.recalculate()
	assert_eq(ai._damage_after_value_blocks(g, attackers, free, shares), 1,
		"four breaths bought, one point past")
	g.unmake_to(mark)
	g.end_search()
	assert_string_contains(ai.act(g), "declared 1 block(s)")
	_play_out_combat(ai, foe)
	assert_eq(theirs[0].zone, Mtg.Zone.GRAVEYARD, "the Giant died")
	assert_eq(g.players[0].life, 19, "one point past, as read")
	assert_eq(_untapped_lands(0), 1, "the fifth Swamp was never needed")


func test_a_body_the_breaths_save_still_absorbs_the_whole_swing() -> void:
	# The other end of the same ladder: a War Mammoth (3/3 trample) into
	# the swarm behind six Swamps. The pump SAVES the body, so
	# _combat_self_pumps buys it in full and a body that lives stops
	# everything assigned to it. Nought before, nought after — the fix
	# must not make the pilot panic about a block that works.
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	_swing(ai, "Swamp", 6, ["Carrion Ants"], ["War Mammoth"])
	var attackers := _attacking()
	var free := _free()
	var shares := ai._pump_shares(g, free)
	var mark := g.make_mark()
	for id in shares:
		var bonus: Vector2i = Vector2i(shares[id]["bonus"]) * int(shares[id]["count"])
		g.continuous.add_until_eot_pump(int(id), bonus.x, bonus.y)
	g.recalculate()
	assert_eq(ai._damage_after_value_blocks(g, attackers, free, shares), 0)
	assert_eq(ai._damage_after_value_blocks(g, attackers, free), 0,
		"and the old reading agreed here, which is why it went unseen")
	g.unmake_to(mark)
	g.end_search()
	assert_string_contains(ai.act(g), "declared 1 block(s)")
	_play_out_combat(ai, foe)
	assert_eq(g.players[0].life, 20, "nothing at all came through")
	assert_eq(_untapped_lands(0), 3, "three breaths, and three Swamps kept")


func test_with_no_share_the_reading_is_the_toughness_it_always_was() -> void:
	# The null of [method AiPlayer._absorbed_by] itself: hand it no shares
	# and it is `cur_toughness - damage`, which is the line it replaced.
	var ai := _ai(_off())
	var foe := _ai(AiProfile.wizard(), 1)
	var theirs := _swing(ai, "Swamp", 6, ["Carrion Ants", "Scathe Zombies"],
		["Force of Nature"], 12)
	assert_eq(ai._absorbed_by(g, _mine("Carrion Ants"), theirs[0], {}), 1)
	assert_eq(ai._absorbed_by(g, _mine("Scathe Zombies"), theirs[0], {}), 2)
	assert_string_contains(ai.act(g), "declared 1 block(s)",
		"and the null chumps the Force of Nature with the cheapest thing it has")
	_play_out_combat(ai, foe)
	assert_eq(g.players[0].life, 5)


# --------------------------------------------------- two: the one pool --

func test_the_first_body_no_longer_spends_what_the_second_was_priced_with() -> void:
	# THE REPORT'S SECOND BOARD. Four Swamps, a Carrion Ants and a Vampire
	# Bats, split two and two by the probe; a 3/2 comes at the swarm and a
	# 2/2 flier at the bats, and the ladder declares both trades on those
	# sizes. Before this, the Ants priced itself against all four Swamps,
	# discovered it could SAVE itself for three — a save no rung had asked
	# for — and left the bats a single Swamp, which buys no trade at all.
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var theirs := _swing(ai, "Swamp", 4, ["Carrion Ants", "Vampire Bats"],
		["Radjan Spirit", "Crimson Manticore"])
	var free := _free()
	var shares := ai._pump_shares(g, free)
	assert_eq(int(shares[_mine("Carrion Ants").id]["count"]), 2, "two for the swarm")
	assert_eq(int(shares[_mine("Vampire Bats").id]["count"]), 2, "two for the bats")
	assert_string_contains(ai.act(g), "declared 2 block(s)")
	assert_eq(ai._pump_plan.size(), 2, "and the split is written down")
	_play_out_combat(ai, foe)
	assert_eq(_untapped_lands(0), 0, "every Swamp went where it was allotted")
	assert_eq(theirs[0].zone, Mtg.Zone.GRAVEYARD, "the 3/2 died")
	assert_eq(theirs[1].zone, Mtg.Zone.GRAVEYARD, "and so did the flier")


func test_off_the_pair_declares_nothing_and_keeps_its_four_swamps() -> void:
	# The null of the same board: with no probe a 0/1 and a 0/1 kill
	# nothing and survive nothing, every value rung refuses them, and five
	# damage lands.
	var ai := _ai(_off())
	var foe := _ai(AiProfile.wizard(), 1)
	var theirs := _swing(ai, "Swamp", 4, ["Carrion Ants", "Vampire Bats"],
		["Radjan Spirit", "Crimson Manticore"])
	assert_string_contains(ai.act(g), "declared 0 block(s)")
	_play_out_combat(ai, foe)
	assert_eq(g.players[0].life, 15)
	assert_eq(_untapped_lands(0), 4)
	assert_eq(theirs[0].zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(theirs[1].zone, Mtg.Zone.BATTLEFIELD)


func test_the_recovery_off_still_prices_against_the_whole_pool() -> void:
	# THE FIX IN ISOLATION, on one board and both arms, with the blocks
	# declared by hand so that the ladder is out of the way and only
	# [method AiPlayer._combat_self_pumps] is under test. Off, the swarm
	# prices itself against all four Swamps and takes three of them to
	# save a body nobody asked it to save; on, it takes the two it was
	# allotted and the bats gets the other two and its trade.
	for knob in [false, true]:
		before_each()
		var ai := _ai(_on() if knob else _off())
		var foe := _ai(AiProfile.wizard(), 1)
		var theirs := _swing(ai, "Swamp", 4, ["Carrion Ants", "Vampire Bats"],
			["Radjan Spirit", "Crimson Manticore"])
		var ants := _mine("Carrion Ants")
		var bats := _mine("Vampire Bats")
		if knob:
			ai._remember_pump_plan(g, ai._pump_shares(g, _free()))
		assert_ok(g.declare_blockers(0, {ants.id: theirs[0].id, bats.id: theirs[1].id}))
		_play_out_combat(ai, foe)
		if knob:
			assert_eq(_untapped_lands(0), 0, "on: two and two, and both trades made")
			assert_eq(theirs[1].zone, Mtg.Zone.GRAVEYARD, "on: the flier died")
		else:
			assert_eq(_untapped_lands(0), 1, "off: the swarm took three of the four")
			assert_eq(ants.zone, Mtg.Zone.BATTLEFIELD, "off: and saved itself with them")
			assert_eq(theirs[1].zone, Mtg.Zone.BATTLEFIELD, "off: the flier walked away")


func test_the_leftover_pass_still_spends_what_the_plan_did_not_want() -> void:
	# NOT A FIX — A GUARD. Serving the plan first must not lock a body
	# OUT of mana no plan wanted, which is exactly what a single capped
	# pass would do. A Granite Gargoyle's {R}: +0/+1 buys no attack and no
	# power, so [method AiPlayer._pump_shares] never prices it and its
	# allotment is nothing; the Carrion Ants beside it takes the whole
	# pool. The Gargoyle must still get the Mountain that saves it, out of
	# the second, uncapped pass — and it does, on both arms.
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		var foe := _ai(AiProfile.wizard(), 1)
		var theirs := _swing(ai, "Mountain", 4,
			["Carrion Ants", "Granite Gargoyle"],
			["Grizzly Bears", "Crimson Manticore"])
		var gargoyle := _mine("Granite Gargoyle")
		ai.act(g)
		_play_out_combat(ai, foe)
		assert_eq(gargoyle.zone, Mtg.Zone.BATTLEFIELD,
			"the Gargoyle bought its point of toughness (%s)" % profile.profile_name)
		assert_eq(theirs[1].zone, Mtg.Zone.GRAVEYARD, "and ate the flier")


func test_a_plan_from_another_turn_is_no_plan() -> void:
	# The stamp. A plan is only ever spent in the combat it was made for;
	# read a turn later it is empty, and the recovery falls back to the
	# uncapped pass it had before this knob existed.
	var ai := _ai(_on())
	_swing(ai, "Swamp", 4, ["Carrion Ants", "Vampire Bats"],
		["Radjan Spirit", "Crimson Manticore"])
	var ants := _mine("Carrion Ants")
	ai._remember_pump_plan(g, ai._pump_shares(g, _free()))
	assert_eq(ai._pump_plan_for(g, ants), 2, "two breaths, this turn")
	ai._pump_plan_turn -= 1
	assert_eq(ai._pump_plan_for(g, ants), 0, "and nothing at all from any other")


# ------------------------------- three: the bonus that guarantees nothing --

func test_rainbow_knights_is_priced_at_its_floor_and_the_floor_is_zero() -> void:
	# THE RULING, WITH THE ARITHMETIC IN IT (2026-09-09, and it stands).
	# Rainbow Knights' third ability is "{W}{W}: +0/+0, +1/+0 or +2/+0
	# until end of turn chosen at random", and the roll happens when the
	# ability RESOLVES — after the mana is spent and, for anything this
	# knob does, after the declaration is already made. The contract of
	# [constant EffectIntent.CARD_LOCAL_PUMPS] is what ONE activation
	# GUARANTEES, because every reader of it is a DECLARATION: the attack
	# cohort, the block ladder, the lethal probe. For a commitment that
	# cannot be taken back the only sound number is the FLOOR, and the
	# share of games a higher number blunders in is the probability mass
	# below it — a third of them at the mean, on a uniform roll of three.
	#
	# The floor here is zero, and a row that says zero is a row that says
	# nothing: [method AiPlayer._self_pump_of] refuses a bonus with no
	# power in it, which is the same refusal the card gets today with no
	# row at all. So the ruling is "the floor, and therefore no row" — not
	# an omission, and not a thing to be half-built later.
	var rolls := {0: 0, 1: 0, 2: 0}
	for _i in 300:
		var roll := RandomEffects.roll(g, 3)
		assert_true(rolls.has(roll), "the roll is 0, 1 or 2 and nothing else")
		rolls[roll] += 1
	assert_gt(rolls[0], 0, "and zero is one of the three: the floor is nothing")
	assert_true(EffectIntent.card_local_pump("Rainbow Knights").is_empty(),
		"so there is no row, by ruling")
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		var knights := put_battlefield(0, "Rainbow Knights")
		_lands(0, "Plains", 4)
		put_battlefield(1, "Hill Giant")
		var mine: Array[CardInstance] = [knights]
		assert_true(ai._pump_shares(g, mine).is_empty(),
			"no share on either arm (%s)" % profile.profile_name)
		var guard := 0
		while not g.awaiting_attackers and not g.game_over and guard < 40:
			if g.priority_player == 0:
				ai.act(g)
			else:
				assert_ok(g.pass_priority(1))
			guard += 1
		assert_string_contains(ai.act(g), "declared 0 attacker(s)",
			"a 2/1 stays home in front of a 3/3, whatever the mana says")
		assert_true(g.combat.attackers.is_empty())
