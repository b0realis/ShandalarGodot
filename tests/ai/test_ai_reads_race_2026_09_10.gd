extends GameTest
## WHO IS THE BEATDOWN (2026-09-10, [member AiProfile.reads_race];
## `docs/forge/combat.md` P1).
##
## Rung 2 of [method AiPlayer._best_block_for] takes a trade nothing
## forces on it whenever the blocker is worth no more than
## `attacker_value + 0.5`, and that margin is the same number at twenty
## life as at four. Reproduced before a line was written, one board and
## its mirror:
##
##     their Craw Wurm 6/4 | our Serra Angel 4/4, us at 20 and them at 4
##         our_clock 1, their_clock 4 -- we win next turn
##         block: [Serra Angel] -- the body that wins the game, given away
##
##     their Erhnam Djinn 4/5 | our Craw Wurm 6/4, us at 8 and them at 20
##         our_clock 4, their_clock 2 -- two turns from dying
##         block: [] -- the Wurm is worth ONE POINT more, so it lets it by
##
## On, [method AiPlayer._trade_margin] moves that margin in P1's own three
## states — demand a gain, allow a small loss, or leave it alone — with a
## dead band of a turn between them and [constant AiPlayer.RACE_HORIZON]
## under all of it.
##
## AND P1'S OTHER HALF WAS BUILT, MEASURED AND REFUSED. Its headline is
## the ATTACK bar, [method AiPlayer._combat_tolerance] moved by the same
## clock difference plus one for a clock they cannot block; over the eight
## starter matchups it moves most it ended 42 games in a win against 170
## in a loss, so the tolerance is the arithmetic it always was.
## `test_the_attack_bar_is_not_this_knobs_business` pins that on both arms
## so the refusal is not quietly re-opened, and
## `test_the_flier_they_cannot_block_is_not_answered_here` pins the board
## `crack_back_margin` was refused on, which this row was named as the
## answer to and is not.
##
## Every behaviour below is pinned with the knob ON and with it OFF, and
## the OFF arm is the pilot as it was.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.reads_race = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.reads_race = false
	return profile


func _board(ours: Array, theirs: Array, my_life: int, their_life: int) -> void:
	g.players[0].life = my_life
	g.players[1].life = their_life
	for n in ours:
		put_battlefield(0, n)
	for n in theirs:
		put_battlefield(1, n)


func _their_untapped() -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for inst in g.players[1].battlefield:
		if inst.is_creature() and not inst.tapped:
			out.append(inst)
	return out


## What the ladder puts in front of their one attacker.
func _block(ai: AiPlayer) -> Array[int]:
	var free: Array[CardInstance] = []
	for inst in g.players[0].battlefield:
		if inst.is_creature():
			free.append(inst)
	var used: Array[int] = []
	return ai._best_block_for(g, g.players[1].battlefield[0], free, used, false)


## The deterministic half of the attack declaration, as card names.
func _declaration(ai: AiPlayer) -> Array:
	var candidates := ai._attack_candidates(g, 1)
	var names: Array = []
	for id in ai._attack_choice(g, candidates, 1):
		names.append(g.find_instance(int(id)).data.card_name)
	names.sort()
	return names


# ------------------------------------------------------------- the clocks --

func test_the_clocks_are_the_two_life_totals_over_the_two_reaches() -> void:
	var ai := _ai(_on())
	_board(["Craw Wurm"], ["Erhnam Djinn"], 8, 6)
	# 6 life over 6 power is one turn; 8 life over 4 is two.
	assert_eq(ai._race_clocks(g, 1), Vector2i(1, 2))
	assert_eq(ai._race_reach(g, 0, 1), 6)
	assert_eq(ai._race_reach(g, 1, 0), 4)


func test_a_wall_is_no_reach_and_no_reach_is_a_clock_of_never() -> void:
	var ai := _ai(_on())
	_board(["Wall of Stone"], ["Grizzly Bears"], 20, 20)
	assert_eq(ai._race_reach(g, 0, 1), 0, "a defender never swings")
	assert_eq(ai._race_clocks(g, 1), Vector2i(AiPlayer.RACE_NEVER, 10))


func test_two_boards_that_cannot_kill_each_other_are_not_a_race() -> void:
	var ai := _ai(_on())
	_board([], [], 20, 20)
	assert_eq(ai._race_clocks(g, 1),
		Vector2i(AiPlayer.RACE_NEVER, AiPlayer.RACE_NEVER))
	assert_eq(ai._trade_margin(g), 0.5,
		"never against never is no race at all, and the control pair rests on it")


func test_the_tapped_body_still_counts_because_it_untaps_first() -> void:
	var ai := _ai(_on())
	_board([], ["Craw Wurm"], 20, 20)
	g.players[1].battlefield[0].tapped = true
	assert_eq(ai._race_reach(g, 1, 0), 6,
		"a clock is a question about the turns ahead")


# --------------------------------------------------- the voluntary trade --

func test_winning_the_race_we_do_not_give_the_body_away() -> void:
	# Their Craw Wurm 6/4 into our Serra Angel 4/4: both die, and the two
	# are worth the same, so rung 2's +0.5 takes the trade. We are one
	# turn from winning; the margin is -0.5 and the trade must GAIN.
	var ai := _ai(_on())
	_board(["Serra Angel"], ["Craw Wurm"], 20, 4)
	assert_eq(ai._race_clocks(g, 1), Vector2i(1, 4))
	assert_eq(ai._trade_margin(g), -0.5)
	assert_eq(_block(ai), [] as Array[int],
		"the Angel keeps itself and we take six")


func test_off_the_same_angel_trades() -> void:
	var ai := _ai(_off())
	_board(["Serra Angel"], ["Craw Wurm"], 20, 4)
	assert_eq(ai._trade_margin(g), 0.5, "the incumbent, at every life total")
	assert_eq(_block(ai), [g.players[0].battlefield[0].id] as Array[int],
		"+0.5 at any life, which is the null")


func test_losing_the_race_we_pay_more_to_stop_the_clock() -> void:
	# Their Erhnam Djinn 4/5 (9.0) into our Craw Wurm 6/4 (10.0): both
	# die and the blocker is worth a point MORE, which rung 2's +0.5
	# refuses. Two turns from dying, the margin is +1.5 and it is taken.
	var ai := _ai(_on())
	_board(["Craw Wurm"], ["Erhnam Djinn"], 8, 20)
	assert_eq(ai._race_clocks(g, 1), Vector2i(4, 2))
	assert_eq(ai._trade_margin(g), 1.5)
	assert_eq(_block(ai), [g.players[0].battlefield[0].id] as Array[int],
		"a point of value for a turn of clock")


func test_off_the_same_wurm_lets_the_djinn_through() -> void:
	var ai := _ai(_off())
	_board(["Craw Wurm"], ["Erhnam Djinn"], 8, 20)
	assert_eq(ai._trade_margin(g), 0.5)
	assert_eq(_block(ai), [] as Array[int],
		"10.0 is more than 9.0 + 0.5, at eight life as at twenty")


func test_a_turn_apart_is_not_a_race_and_the_margin_does_not_move() -> void:
	# THE DEAD BAND: P1 asks for a gain only when their clock is more than
	# a turn longer than ours, and this board is a dead heat inside the
	# horizon.
	var ai := _ai(_on())
	_board(["Craw Wurm"], ["Craw Wurm"], 12, 12)
	assert_eq(ai._race_clocks(g, 1), Vector2i(2, 2))
	assert_eq(ai._trade_margin(g), 0.5, "inside a turn of each other, nothing moves")


# ------------------------------------------------------------ the horizon --

func test_a_clock_past_the_horizon_is_not_a_race_at_all() -> void:
	# THE SUITE PUT THIS HERE. A Rasputin Dreamweaver 4/1 in front of a
	# Hill Giant on a 20-20 board reads five turns against seven — the
	# maximum shift, for a difference nobody will still be in by then —
	# and the first cut demanded a gain out of a trade this suite has
	# pinned as right since the 2026-09-04 audit.
	var ai := _ai(_on())
	_board(["Grizzly Bears", "Grizzly Bears"], ["Hill Giant"], 20, 20)
	assert_eq(ai._race_clocks(g, 1), Vector2i(5, 7))
	assert_eq(ai._trade_margin(g), 0.5,
		"the margin the 2026-09-04 audit calibrated, untouched")


func test_the_horizon_is_the_faster_clock_and_not_the_gap() -> void:
	var ai := _ai(_on())
	# Four turns is inside it; one point of their life further away is not.
	_board(["Craw Wurm"], ["Grizzly Bears"], 20, 24)
	assert_eq(ai._race_clocks(g, 1), Vector2i(4, 10))
	assert_eq(ai._trade_margin(g), -0.5, "four turns is inside the horizon")
	g.players[1].life = 25
	assert_eq(ai._race_clocks(g, 1), Vector2i(5, 10))
	assert_eq(ai._trade_margin(g), 0.5,
		"one point further away and there is no race to read")


# ------------------------------------- what the Lab refused (P1's own half) --

func test_the_attack_bar_is_not_this_knobs_business() -> void:
	# P1's headline half — the tolerance moved by the clock difference —
	# was built and REFUSED on measurement (42 games won to 170 lost over
	# the eight starter matchups it moved most). The appetite is the same
	# number on both arms, and every board this file reads it on is one
	# where the refused version would have moved it.
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		_board(["Craw Wurm"], ["Erhnam Djinn"], 8, 6)
		assert_eq(ai._race_clocks(g, 1), Vector2i(1, 2), "we win the race")
		assert_eq(ai._combat_tolerance(g), 0.0,
			"aggression and posture, and nothing else (%s)" % profile.profile_name)
		assert_eq(ai._attack_risk(g, g.players[0].battlefield[0],
			_their_untapped(), 1), 1.0, "a 6/4 for a 4/5 is one point down")
		assert_eq(_declaration(ai), [],
			"the same declaration on both arms")


func test_the_flier_they_cannot_block_is_not_answered_here() -> void:
	# `crack_back_margin`'s own reproduction, and the row this one was
	# named as the answer to: our Air Elemental into two Craw Wurms at 14
	# life, four damage traded for twelve. The clocks say we are losing it
	# by three turns and the declaration does not move on either arm,
	# because [method AiPlayer._attack_is_reasonable] returns on
	# `risk < 0` — nothing over there may block it — before any appetite
	# is read at all. The race read does not make P8's question
	# answerable, and this pins that rather than leaving it implied.
	for profile in [_on(), _off()]:
		before_each()
		var ai := _ai(profile)
		_board(["Air Elemental"], ["Craw Wurm", "Craw Wurm"], 14, 20)
		assert_eq(ai._race_clocks(g, 1), Vector2i(5, 2))
		assert_eq(ai._attack_risk(g, g.players[0].battlefield[0],
			_their_untapped(), 1), -1.0, "nothing they have may block it")
		assert_eq(_declaration(ai), ["Air Elemental"],
			"the same swing on both arms")
