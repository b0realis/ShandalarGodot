extends GameTest
## THE BLOCK THAT WAS STILL DECLARED AT PRINTED SIZE, and the three
## firebreathers the reader could not see (2026-09-09, the second half of
## [member AiProfile.pumps_to_attack]).
##
## The morning's pass fixed the ATTACK: a Carrion Ants with four Swamps
## untapped is judged at the size its share of the open mana can reach and
## sent ([method AiPlayer._attack_choice_once_pumped]). The BLOCK was left
## exactly as it was — [method AiPlayer._plan_blocks] and [method
## AiPlayer._best_block_for] read [member CardInstance.cur_power] and
## [member CardInstance.cur_toughness] straight down the ladder — so the
## same swarm, with SIX Swamps open and a Craw Wurm coming at it, declared
## no block at all and took six to the face, when a 6/7 eats a 6/4 and
## walks away. Measured before this landed, at 20 life: `declared 0
## block(s)`, life 20 → 14, six Swamps still untapped. Lower the life to 8
## and the chump rung opened instead: the swarm went under the Wurm as a
## 0/1 and [method AiPlayer._combat_self_pumps] paid to rescue a body that
## had already been thrown away — the block it would have MADE as a 6/7
## was never planned.
##
## THE PANIC LINE IS READ INSIDE THE PROBE, and that is the care the
## previous author flagged. [method AiPlayer._damage_after_value_blocks]
## runs the same ladder, so growing the blockers moves it too: the Wurm
## stops being six points through and the chump rung never opens. That is
## the point rather than a side effect — reading the panic at printed size
## while planning the blocks at reach size is the one combination that
## would be wrong, spending two bodies where one would do. Both readings
## are taken on one board, inside one journal ([method
## AiPlayer._block_choice]).
##
## AND THE READER'S HALF. Dragon Whelp and Nalathni Dragon pump themselves
## through a `class X extends EffectBase` inside their own card file
## rather than through a [PumpEffect], because the breath carries a FUSE
## the shared effect cannot express — *"if this ability has been activated
## four or more times this turn, sacrifice this creature at the beginning
## of the next end step"*. So [member EffectIntent.pump_self] was false for
## both and NO pump path had ever touched them. They are read now, through
## [constant EffectIntent.CARD_LOCAL_PUMPS] and gated on the same knob;
## the fuse hands every reader three breaths and no more, and the fourth
## is for the attack that ends the game and for nothing else. Rainbow
## Knights, the third card of the report, is refused by rule and pinned
## refused below.
##
## Every behaviour here is pinned with the knob ON and with it OFF,
## because an ungated reading in the reader's own tables would have moved
## the null the Deck Lab measures this knob against.


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


## Our creatures that could block right now — the list [method
## AiPlayer._declare_blocks] builds and hands the probe.
func _free() -> Array[CardInstance]:
	var free: Array[CardInstance] = []
	for inst in g.players[0].battlefield:
		if inst.is_creature() and not inst.tapped:
			free.append(inst)
	return free


func _attacking() -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for id in g.combat.attackers:
		var a := g.find_instance(id)
		if a != null and a.zone == Mtg.Zone.BATTLEFIELD:
			out.append(a)
	return out


## Hand the turn to seat 1 and walk it to its declare-attackers.
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


## Walk from their declared attack to OUR declare-blockers.
func _reach_blockers(ai: AiPlayer) -> void:
	var guard := 0
	while not g.awaiting_blockers and not g.game_over and guard < 60:
		if g.priority_player == 0:
			ai.act(g)
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	assert_true(g.awaiting_blockers, "reached the block declaration")


## Both seats act until the combat damage is behind us.
func _play_out_combat(ai: AiPlayer, foe: AiPlayer) -> void:
	var guard := 0
	while not g.game_over and g.current_step() <= Mtg.Step.COMBAT_DAMAGE \
			and guard < 120:
		var mine := ai.act(g)
		var theirs := foe.act(g)
		if mine == "" and theirs == "":
			break
		guard += 1


## Walk priority from our first main phase to OUR attack declaration.
func _reach_attackers(ai: AiPlayer) -> void:
	var guard := 0
	while not g.awaiting_attackers and not g.game_over and guard < 40:
		if g.priority_player == 0:
			ai.act(g)
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	assert_true(g.awaiting_attackers, "reached the declaration")


## Set up "a Craw Wurm swings at a Carrion Ants with [param swamps] Swamps
## open", with us at [param life], and stop on our block declaration.
func _wurm_at_the_swarm(ai: AiPlayer, swamps: int, life := 20) -> CardInstance:
	var wurm := put_battlefield(1, "Craw Wurm")
	g.players[0].life = life
	_their_turn()
	assert_ok(g.declare_attackers(1, [wurm.id]))
	_reach_blockers(ai)
	return wurm


# ------------------------------------ the block the swarm never declared --

func test_the_swarm_eats_the_wurm_it_used_to_let_through() -> void:
	# The report's other half. Six Swamps make the 0/1 a 6/7, which kills
	# a 6/4 and lives — and at 20 life the chump rung is shut, so the only
	# ladder rung that can be firing is "kill it and live".
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var ants := put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 6)
	var wurm := _wurm_at_the_swarm(ai, 6)
	assert_string_contains(ai.act(g), "declared 1 block")
	assert_eq(int(g.combat.blocks.get(ants.id, -1)), wurm.id, "the swarm is in front of it")
	_play_out_combat(ai, foe)
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD, "the Wurm died")
	assert_eq(ants.zone, Mtg.Zone.BATTLEFIELD, "and the swarm lived")
	assert_eq(ants.cur_power, 6, "six breaths bought with six Swamps")
	assert_eq(g.players[0].life, 20, "nothing got through")


func test_off_the_wurm_walks_past_a_swarm_that_could_have_eaten_it() -> void:
	# The malfunction as it stood this morning, pinned so the null is the
	# pilot as it was.
	var ai := _ai(_off())
	var foe := _ai(AiProfile.wizard(), 1)
	var ants := put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 6)
	var wurm := _wurm_at_the_swarm(ai, 6)
	assert_string_contains(ai.act(g), "declared 0 block")
	assert_true(g.combat.blocks.is_empty())
	_play_out_combat(ai, foe)
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD, "nothing was traded")
	assert_eq(g.players[0].life, 14, "and six landed on us")
	assert_eq(_untapped_lands(0), 6, "with the mana never for anything")


func test_the_swarm_kills_a_minotaur_and_keeps_the_swamp_it_did_not_need() -> void:
	# _combat_self_pumps buys the breaths one at a time against the real
	# board, so the block planned at four is paid for at three: a 3/4 kills
	# a 2/3 and survives it, and the fourth Swamp stays up.
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var ants := put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 4)
	var minotaur := put_battlefield(1, "Hurloon Minotaur")
	g.players[0].life = 20
	_their_turn()
	assert_ok(g.declare_attackers(1, [minotaur.id]))
	_reach_blockers(ai)
	assert_string_contains(ai.act(g), "declared 1 block")
	_play_out_combat(ai, foe)
	assert_eq(minotaur.zone, Mtg.Zone.GRAVEYARD, "the Minotaur died")
	assert_eq(ants.zone, Mtg.Zone.BATTLEFIELD, "the swarm lived")
	assert_eq(_untapped_lands(0), 1, "and one Swamp was never needed")


func test_off_the_minotaur_walks_past_it_too() -> void:
	var ai := _ai(_off())
	var foe := _ai(AiProfile.wizard(), 1)
	put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 4)
	var minotaur := put_battlefield(1, "Hurloon Minotaur")
	_their_turn()
	assert_ok(g.declare_attackers(1, [minotaur.id]))
	_reach_blockers(ai)
	assert_string_contains(ai.act(g), "declared 0 block")
	_play_out_combat(ai, foe)
	assert_eq(minotaur.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 18)


# --------------------------------------------------------- the panic line --

func test_the_panic_line_is_read_at_the_size_the_block_will_be() -> void:
	# THE CARE the previous author flagged. _damage_after_value_blocks runs
	# the same ladder, so the probe moves it: read off the printed board
	# the Wurm is six points through and we are desperate at 8 life; read
	# inside the probe the swarm stops all six and we are not. The
	# assertion is the residue itself, both ways, on one board.
	var ai := _ai(_on())
	put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 6)
	_wurm_at_the_swarm(ai, 6, 8)
	var attackers := _attacking()
	var free := _free()
	assert_eq(ai._damage_after_value_blocks(g, attackers, free), 6,
		"at printed size a 0/1 stops nothing")
	assert_true(g.players[0].life - 6 <= ai.profile.chump_threshold,
		"which is what used to open the chump rung")
	# The same reading, taken where the declaration takes it.
	var bonuses := ai._reachable_pumps(g, free)
	var mark := g.make_mark()
	for id in bonuses:
		g.continuous.add_until_eot_pump(int(id), bonuses[id].x, bonuses[id].y)
	g.recalculate()
	assert_eq(ai._damage_after_value_blocks(g, attackers, free), 0,
		"and at reach size nothing lands at all")
	g.unmake_to(mark)
	g.end_search()
	assert_eq(ai._damage_after_value_blocks(g, attackers, free), 6,
		"the board is the board again")


func test_with_the_chump_rung_shut_the_swarm_still_makes_the_block() -> void:
	# PLANNED, NOT PANICKED. At 8 life the chump rung would open on its
	# own and muddy the reading, so it is shut by hand
	# ([member AiProfile.chump_threshold] = 0, the knob that owns that
	# rung) and the question is asked bare: with NO rung that throws a
	# body away, does the ladder still put the swarm in front of the Wurm?
	# The null cannot — a 0/1 kills nothing and survives nothing, so every
	# value rung refuses it and six lands on us. The knob's arm blocks on
	# rung 1, "kill it and live", which is what a 6/7 does to a 6/4.
	var ai := _ai(_off())
	ai.profile.chump_threshold = 0
	var foe := _ai(AiProfile.wizard(), 1)
	put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 6)
	var wurm := _wurm_at_the_swarm(ai, 6, 8)
	assert_string_contains(ai.act(g), "declared 0 block",
		"the null has no rung that fits a 0/1")
	_play_out_combat(ai, foe)
	assert_eq(g.players[0].life, 2, "and six landed on us")
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)

	before_each()
	var ai2 := _ai(_on())
	ai2.profile.chump_threshold = 0
	var foe2 := _ai(AiProfile.wizard(), 1)
	var ants2 := put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 6)
	var wurm2 := _wurm_at_the_swarm(ai2, 6, 8)
	assert_string_contains(ai2.act(g), "declared 1 block",
		"the block is a value block, not a panic")
	_play_out_combat(ai2, foe2)
	assert_eq(wurm2.zone, Mtg.Zone.GRAVEYARD, "the Wurm died")
	assert_eq(ants2.zone, Mtg.Zone.BATTLEFIELD, "the swarm lived")
	assert_eq(g.players[0].life, 8, "and nothing got through")


func test_the_panic_spends_the_body_the_mana_cannot_make_big() -> void:
	# Where the pump cannot buy a block at all, the chump rung is still
	# the chump rung — but it spends a DIFFERENT body, and that difference
	# is this knob's whole story in one board. Two Swamps make the swarm a
	# 2/3, which neither kills a 6/4 nor survives it, so both arms panic
	# at 8 life. The null throws the swarm under the Wurm — a 0/1 is the
	# cheapest thing it owns — and [method AiPlayer._combat_self_pumps]
	# cannot rescue what it threw: two breaths win nothing. The knob's arm
	# prices the swarm at the 2/3 it can pay for, finds the 1/1 cheaper,
	# and spends that instead; the firebreather is still on the table next
	# turn, with its Swamps.
	var ai := _ai(_off())
	var foe := _ai(AiProfile.wizard(), 1)
	var goblins := put_battlefield(0, "Mons's Goblin Raiders")
	var ants := put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 2)
	var wurm := _wurm_at_the_swarm(ai, 2, 8)
	assert_string_contains(ai.act(g), "declared 1 block")
	assert_eq(int(g.combat.blocks.get(ants.id, -1)), wurm.id,
		"the null spends the swarm")
	_play_out_combat(ai, foe)
	assert_eq(ants.zone, Mtg.Zone.GRAVEYARD, "and cannot rescue it")
	assert_eq(goblins.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD, "the Wurm walks away")

	before_each()
	var ai2 := _ai(_on())
	var foe2 := _ai(AiProfile.wizard(), 1)
	var goblins2 := put_battlefield(0, "Mons's Goblin Raiders")
	var ants2 := put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 2)
	var wurm2 := _wurm_at_the_swarm(ai2, 2, 8)
	assert_string_contains(ai2.act(g), "declared 1 block")
	assert_eq(int(g.combat.blocks.get(goblins2.id, -1)), wurm2.id,
		"the knob's arm spends the 1/1")
	_play_out_combat(ai2, foe2)
	assert_eq(goblins2.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(ants2.zone, Mtg.Zone.BATTLEFIELD, "and keeps the firebreather")
	assert_eq(_untapped_lands(0), 2, "with its Swamps")


# --------------------------------------------------------- the block traps --

func test_a_body_that_cannot_pay_blocks_as_it_always_did() -> void:
	# The reach is the mana, and there is none: both arms read the same
	# board and make the same (empty) declaration.
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		put_battlefield(0, "Carrion Ants")
		var wurm := _wurm_at_the_swarm(ai, 0)
		assert_string_contains(ai.act(g), "declared 0 block", str(profile))
		assert_true(g.combat.blocks.is_empty(), str(profile))
		assert_eq(wurm.cur_power, 6)


func test_a_pump_that_does_not_change_the_outcome_buys_no_block() -> void:
	# One Swamp makes the swarm a 1/2. It still kills nothing and survives
	# nothing, so the ladder refuses the block on both arms and the Swamp
	# is still up afterwards.
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		var foe := _ai(AiProfile.wizard(), 1)
		put_battlefield(0, "Carrion Ants")
		_lands(0, "Swamp", 1)
		_wurm_at_the_swarm(ai, 1)
		assert_string_contains(ai.act(g), "declared 0 block", str(profile))
		_play_out_combat(ai, foe)
		assert_eq(g.players[0].life, 14, str(profile))
		assert_eq(_untapped_lands(0), 1, "and the Swamp bought nothing")


func test_a_toughness_only_pump_grows_no_blocker() -> void:
	# A Granite Gargoyle's {R}: +0/+1 is refused by _self_pump_of on the
	# block for the same reason it is refused on the attack: the reading
	# wants a POWER bonus, and a bonus that only keeps a body alive is
	# what _combat_self_pumps buys AFTER the blocks are known, priced
	# against the damage actually coming. So the probe never grows it, and
	# both arms make the same declaration off the same printed board.
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		var gargoyle := put_battlefield(0, "Granite Gargoyle")
		_lands(0, "Mountain", 4)
		var bears := put_battlefield(1, "Grizzly Bears")
		_their_turn()
		assert_ok(g.declare_attackers(1, [bears.id]))
		_reach_blockers(ai)
		assert_true(ai._self_pump_of(g, gargoyle).is_empty(),
			"+0/+1 is no block the ladder can plan")
		assert_false(ai._reachable_pumps(g, _free()).has(gargoyle.id), str(profile))
		assert_string_contains(ai.act(g), "declared 0 block", str(profile))
		assert_eq(gargoyle.cur_toughness, 2, "and it was never grown for nothing")


func test_the_attacking_firebreather_is_never_ours_to_pump() -> void:
	# The probe's pool is our untapped bodies. Theirs is not in it, and a
	# Frozen Shade of theirs is read at the size THEY left it.
	var ai := _ai(_on())
	var shade := put_battlefield(1, "Frozen Shade")
	put_battlefield(1, "Swamp")
	put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 4)
	_their_turn()
	assert_ok(g.declare_attackers(1, [shade.id]))
	_reach_blockers(ai)
	var free := _free()
	assert_false(free.has(shade), "not a body of ours")
	assert_false(ai._reachable_pumps(g, free).has(shade.id), "and never grown by us")
	ai.act(g)
	assert_eq(shade.cur_power, 0, "their Shade is the size they left it")


func test_the_counterspells_mana_is_not_block_mana() -> void:
	# Two Islands and a Counterspell in hand: {1} for a breath and {U}{U}
	# for the counter do not both fit, so the breath is not counted and the
	# 0/1 does not walk in front of anything. The held instant books on
	# THEIR turn exactly as it books on ours — more so, since theirs is the
	# turn it is being held for.
	var ai := _ai(_on())
	put_battlefield(0, "Carrion Ants")
	_lands(0, "Island", 2)
	give_hand(0, "Counterspell")
	var minotaur := put_battlefield(1, "Hurloon Minotaur")
	_their_turn()
	assert_ok(g.declare_attackers(1, [minotaur.id]))
	_reach_blockers(ai)
	assert_true(ai._reachable_pumps(g, _free()).is_empty(),
		"the counter's mana is spoken for")
	assert_string_contains(ai.act(g), "declared 0 block")


func test_the_second_main_phase_books_nothing_on_their_turn() -> void:
	# The one reserve that had to learn whose turn it is. A Hypnotic
	# Specter in hand keeps four Swamps back from the ATTACK (the second
	# main phase is a phase of OUR turn and it will cast it there) — but on
	# THEIR turn there is no such phase, our lands untap before there is,
	# and keeping the mana back would spend it on nothing at all.
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var ants := put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 4)
	give_hand(0, "Hypnotic Specter")
	var minotaur := put_battlefield(1, "Hurloon Minotaur")
	_their_turn()
	assert_ok(g.declare_attackers(1, [minotaur.id]))
	_reach_blockers(ai)
	assert_eq(ai._reachable_pumps(g, _free()).get(ants.id, Vector2i.ZERO),
		Vector2i(4, 4), "every Swamp is the block's on their turn")
	assert_string_contains(ai.act(g), "declared 1 block")
	_play_out_combat(ai, foe)
	assert_eq(minotaur.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(ants.zone, Mtg.Zone.BATTLEFIELD)


func test_one_pool_grows_one_swarm_on_the_block_too() -> void:
	# Two Carrion Ants in front of four Swamps are not both a 4/5: the mana
	# a body is priced with comes off the table before the next is priced,
	# and the second gets nothing.
	var ai := _ai(_on())
	put_battlefield(0, "Carrion Ants")
	put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 4)
	_wurm_at_the_swarm(ai, 4)
	var bonuses := ai._reachable_pumps(g, _free())
	assert_eq(bonuses.size(), 1, "one pool, one swarm")
	for id in bonuses:
		assert_eq(bonuses[id], Vector2i(4, 4))


func test_the_block_probe_leaves_the_game_as_it_found_it() -> void:
	# No journal stays open, no bonus stays registered, no mana is tapped
	# for a reading, no log line is written and the random stream has not
	# moved. Nothing is paid for until _combat_self_pumps buys it.
	var ai := _ai(_on())
	var ants := put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 6)
	_wurm_at_the_swarm(ai, 6)
	var state_before := g.rng.state
	var lines_before := g.log_lines.size()
	var used: Array[int] = []
	var chosen := ai._block_choice_once_pumped(g, _attacking(), _free(), used)
	assert_eq(chosen.size(), 1, "the swarm is put in front of it")
	assert_eq(g.rng.state, state_before, "no random number was drawn")
	assert_eq(g.log_lines.size(), lines_before, "the probe wrote no log line")
	assert_null(g.undo_log, "the journal was handed back")
	assert_null(g.continuous.journal)
	assert_eq(ants.cur_power, 0, "the body is the body again")
	assert_eq(ants.cur_toughness, 1)
	assert_eq(_untapped_lands(0), 6, "and not one Swamp was tapped for a reading")


func test_the_block_probe_keeps_a_search_already_in_progress() -> void:
	var ai := _ai(_on())
	var ants := put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 6)
	_wurm_at_the_swarm(ai, 6)
	var mark := g.make_mark()
	var used: Array[int] = []
	assert_eq(ai._block_choice_once_pumped(g, _attacking(), _free(), used).size(), 1)
	assert_not_null(g.undo_log, "the outer journal is still open")
	g.unmake_to(mark)
	g.end_search()
	assert_null(g.undo_log)
	assert_eq(ants.cur_power, 0)


func test_the_breaths_are_paid_for_and_nothing_is_left_floating() -> void:
	# Mana burn is the 1997 "fifth" ruleset's own rule and the reason a
	# plan is never bigger than the cost: the pool is empty after the
	# block and no life was lost to it.
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	put_battlefield(0, "Carrion Ants")
	_lands(0, "Swamp", 6)
	_wurm_at_the_swarm(ai, 6)
	assert_string_contains(ai.act(g), "declared 1 block")
	_play_out_combat(ai, foe)
	assert_eq(g.players[0].mana_pool.total(), 0, "nothing was left floating")
	assert_eq(g.players[0].life, 20, "so nothing burned")


# --------------------------- the three firebreathers the reader cannot see --

func test_the_reader_still_sees_no_pump_and_the_pilot_does() -> void:
	# The row is not in CARD_LOCAL and deliberately: a row there makes the
	# reader stop calling the effect `unknown`, and this effect IS unknown
	# to the harm reading, the target picker and the ability scorer. Only
	# the pump paths read the fourth table.
	var ai := _ai(_on())
	for card_name in ["Dragon Whelp", "Nalathni Dragon"]:
		var body := put_battlefield(0, card_name)
		var ability: ActivatedAbility = body.cur_activated_abilities[0]
		var intent := EffectIntent.read(ability.effects, card_name)
		assert_false(intent.pump_self, "%s: the reader sees no PumpEffect" % card_name)
		assert_true(intent.unknown, "%s: and calls the effect unknown" % card_name)
		assert_eq(ai._self_pump_of(g, body).get("bonus", Vector2i.ZERO),
			Vector2i(1, 0), "%s: the pilot reads the breath" % card_name)


func test_off_neither_dragon_is_visible_at_all() -> void:
	var ai := _ai(_off())
	for card_name in ["Dragon Whelp", "Nalathni Dragon"]:
		var body := put_battlefield(0, card_name)
		assert_true(ai._self_pump_of(g, body).is_empty(),
			"%s: the null sees a PumpEffect and nothing else" % card_name)
		assert_eq(ai._activations_left(g, body, 0), -1,
			"%s: and no cap either" % card_name)


func test_the_whelp_breathes_three_and_keeps_itself() -> void:
	# Six Mountains, an empty board opposite, them at 12: three breaths is
	# five damage and the fourth would be a dragon for one more point. The
	# fuse is not lit and three Mountains are still up.
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var whelp := put_battlefield(0, "Dragon Whelp")
	_lands(0, "Mountain", 6)
	g.players[1].life = 12
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai._activations_left(g, whelp, 0), 3, "three breaths, then the fuse")
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker")
	_play_out_combat(ai, foe)
	assert_eq(int(whelp.memory.get("breaths", 0)), 3, "three, and not the fourth")
	assert_eq(g.players[1].life, 7, "two printed and three breathed")
	assert_eq(whelp.zone, Mtg.Zone.BATTLEFIELD, "the dragon is still ours")
	assert_eq(_untapped_lands(0), 3, "with the mana of the fourth breath unspent")


func test_the_whelp_stops_at_exactly_lethal() -> void:
	# Them at 5: 2 printed and three breathed is exactly the game, so the
	# fourth is not bought for the sake of buying it.
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var whelp := put_battlefield(0, "Dragon Whelp")
	_lands(0, "Mountain", 6)
	g.players[1].life = 5
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker")
	_play_out_combat(ai, foe)
	assert_true(g.players[1].life <= 0, "the game ended on the attack")
	assert_eq(int(whelp.memory.get("breaths", 0)), 3, "no breath was wasted")


func test_the_fuse_is_lit_when_the_fourth_breath_is_the_game() -> void:
	# Them at 8: three breaths reach 5 and the game does not end, six
	# reach 8 and it does. A dragon sacrificed at the end step of a game
	# that ended in this combat cost nothing at all — the one reading
	# allowed past the fuse (_pumps_are_lethal, may_light_fuse).
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var whelp := put_battlefield(0, "Dragon Whelp")
	_lands(0, "Mountain", 6)
	g.players[1].life = 8
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai._activations_left(g, whelp, 0, true), -1,
		"the lethal probe is not bound by the fuse")
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker")
	_play_out_combat(ai, foe)
	assert_true(g.players[1].life <= 0, "eight damage from a 2/3")
	assert_true(int(whelp.memory.get("breaths", 0)) >= 4, "and the fuse was lit for it")


func test_off_the_whelp_swings_for_two_and_breathes_nothing() -> void:
	for life in [5, 8, 12]:
		before_each()
		var ai := _ai(_off())
		var foe := _ai(AiProfile.wizard(), 1)
		var whelp := put_battlefield(0, "Dragon Whelp")
		_lands(0, "Mountain", 6)
		g.players[1].life = life
		advance_to_step(Mtg.Step.MAIN1)
		_reach_attackers(ai)
		assert_string_contains(ai.act(g), "declared 1 attacker", str(life))
		_play_out_combat(ai, foe)
		assert_eq(int(whelp.memory.get("breaths", 0)), 0, "no breath at %d" % life)
		assert_eq(g.players[1].life, life - 2, "two damage at %d" % life)
		assert_eq(_untapped_lands(0), 6, "six Mountains for nothing at %d" % life)


func test_a_blocked_whelp_breathes_to_win_the_trade_and_no_further() -> void:
	# _combat_self_pumps, which had never seen this card either. A Wall of
	# Air is a 0/5 flier: three breaths make the Whelp a 5/3 and kill it,
	# which is the third breath and not the fourth. A blocked trade is
	# never worth a dragon, so the fuse stays cold whatever the mana says.
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var whelp := put_battlefield(0, "Dragon Whelp")
	_lands(0, "Mountain", 6)
	var wall := put_battlefield(1, "Wall of Air")
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker")
	_play_out_combat(ai, foe)
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "the Wall died")
	assert_eq(whelp.zone, Mtg.Zone.BATTLEFIELD, "the dragon lived")
	assert_eq(int(whelp.memory.get("breaths", 0)), 3, "three breaths, never four")
	assert_eq(_untapped_lands(0), 3)


func test_off_a_blocked_whelp_bounces_off_the_wall() -> void:
	var ai := _ai(_off())
	var foe := _ai(AiProfile.wizard(), 1)
	var whelp := put_battlefield(0, "Dragon Whelp")
	_lands(0, "Mountain", 6)
	var wall := put_battlefield(1, "Wall of Air")
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	ai.act(g)
	_play_out_combat(ai, foe)
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD, "nothing was traded")
	assert_eq(int(whelp.memory.get("breaths", 0)), 0)
	assert_eq(_untapped_lands(0), 6)


func test_the_fuse_counts_the_breaths_already_taken_this_turn() -> void:
	# The count is the card's own memory (CardInstance.ability_uses is
	# only kept for an ability with a max_per_turn and this one has none),
	# and it is stamped with the turn, so a breath a turn is harmless
	# forever.
	var ai := _ai(_on())
	var whelp := put_battlefield(0, "Dragon Whelp")
	_lands(0, "Mountain", 6)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai._activations_left(g, whelp, 0), 3)
	whelp.memory["breaths"] = 2
	whelp.memory["breaths_turn"] = g.turn_number
	assert_eq(ai._activations_left(g, whelp, 0), 1, "two spent, one safe left")
	whelp.memory["breaths"] = 3
	assert_eq(ai._activations_left(g, whelp, 0), 0, "the next one is the fuse")
	assert_eq(ai._activations_left(g, whelp, 0, true), -1, "unless the game ends on it")
	whelp.memory["breaths_turn"] = g.turn_number - 1
	assert_eq(ai._activations_left(g, whelp, 0), 3, "last turn's breaths are not this turn's")


func test_the_declaration_sizes_the_whelp_at_three_not_at_the_mana() -> void:
	# Six Mountains would pay for six breaths. The declaration is offered
	# three, because the other three cost a dragon.
	var ai := _ai(_on())
	var whelp := put_battlefield(0, "Dragon Whelp")
	_lands(0, "Mountain", 6)
	advance_to_step(Mtg.Step.MAIN1)
	var mine: Array[CardInstance] = [whelp]
	assert_eq(ai._reachable_pumps(g, mine).get(whelp.id, Vector2i.ZERO),
		Vector2i(3, 0), "three breaths, whatever the mana says")


func test_a_nalathni_dragon_is_read_by_the_same_row() -> void:
	# Nothing in the AI names a card: the second dragon is the first
	# dragon's row, and the pilot cannot tell them apart.
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var dragon := put_battlefield(0, "Nalathni Dragon")
	_lands(0, "Mountain", 6)
	g.players[1].life = 12
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai._activations_left(g, dragon, 0), 3)
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker")
	_play_out_combat(ai, foe)
	assert_eq(int(dragon.memory.get("breaths", 0)), 3, "three breaths, never four")
	assert_eq(g.players[1].life, 8, "one printed and three breathed")
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD)


func test_rainbow_knights_stays_invisible_on_both_arms() -> void:
	# THE THIRD CARD OF THE REPORT, refused by rule and not by omission.
	# Its {W}{W} is "+0/+0, +1/+0 or +2/+0 chosen at random", rolled when
	# the ability RESOLVES — so what two white mana guarantee is nothing,
	# and a declaration sized on the average walks a 2/1 into a blocker
	# that eats it one time in three. A one-ply board reading cannot price
	# a coin flip honestly: the rule that keeps Camouflage out of
	# EffectIntent.WINDOW_SHAPES and Orcish Catapult in the AI's hand. Its
	# OTHER ability ({1}: first strike) is a real PumpEffect and is
	# refused by the reading every pump path already keeps — no power.
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		var knights := put_battlefield(0, "Rainbow Knights")
		_lands(0, "Plains", 6)
		advance_to_step(Mtg.Step.MAIN1)
		assert_eq(knights.cur_activated_abilities.size(), 2, "two abilities")
		var first := EffectIntent.read(knights.cur_activated_abilities[0].effects,
			"Rainbow Knights")
		assert_true(first.pump_self, "the first is a PumpEffect the reader sees")
		assert_eq(first.pump_power, 0, "and it grants no power")
		assert_true(ai._self_pump_of(g, knights).is_empty(), "neither ability is a breath")
		assert_true(EffectIntent.card_local_pump("Rainbow Knights").is_empty(),
			"and there is no row for the random one")
		var mine: Array[CardInstance] = [knights]
		assert_false(ai._reachable_pumps(g, mine).has(knights.id))


func test_the_table_is_the_only_place_a_card_is_named() -> void:
	# Two rows, both dragons, and the row states the bonus ONE activation
	# grants plus the fuse — what the reader would have read off a
	# PumpEffect, had the breath fitted in one.
	assert_eq(EffectIntent.CARD_LOCAL_PUMPS.size(), 2)
	for card_name in ["Dragon Whelp", "Nalathni Dragon"]:
		var row := EffectIntent.card_local_pump(card_name)
		assert_eq(int(row["power"]), 1, card_name)
		assert_eq(int(row["toughness"]), 0, card_name)
		assert_eq(int(row["fuse"]), 4, card_name)
		assert_true(CardRegistry.has_card(card_name), "%s is in the pool" % card_name)
	assert_true(EffectIntent.card_local_pump("Carrion Ants").is_empty(),
		"a card the reader can already see needs no row")
