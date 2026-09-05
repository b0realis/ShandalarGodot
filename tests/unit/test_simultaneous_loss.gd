extends GameTest
## BOTH DUELISTS LOSE AT ONCE — CR 104.4b, and the state-based action that
## has to notice it (CR 704.5a).
##
## "If all the players remaining in a game lose simultaneously, the game is
## a draw." Earthquake is the card that makes it happen: X damage to each
## creature without flying AND EACH PLAYER, symmetric, with the caster's own
## life in the blast. Two players at 3 and an Earthquake for 3 is a DRAW,
## not a win for whoever the engine happened to check second.
##
## Two things had to be right for that:
## - the sweeper must land ALL of its damage before anything is checked
##   (CR 704.3 — state-based actions are checked when a player WOULD get
##   priority, never in the middle of a resolution); and
## - the check must look at both seats before deciding, and call the game a
##   draw when both are doomed.
##
## The 1997 ruleset moves the life check to the end of the PHASE
## (RulesOptions.life_checked_at_phase_end, manual p.174), so the same
## question is asked there too — and that path already SAID "a draw" in the
## log while recording a winner.


func _quake(x: int) -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var quake := give_hand(0, "Earthquake")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, x)
	assert_ok(g.cast_spell(0, quake, [], x))
	resolve_stack()


func test_an_earthquake_that_kills_both_duelists_is_a_draw() -> void:
	g.players[0].life = 3
	g.players[1].life = 3
	_quake(3)
	assert_true(g.game_over, "the game ended")
	assert_true(g.is_draw, "and it is a draw, not a win")
	assert_eq(g.winner, -1, "nobody won")


func test_an_earthquake_that_kills_only_the_caster_still_loses_them_it() -> void:
	# The control: asymmetric lethal is still an ordinary loss.
	g.players[0].life = 3
	g.players[1].life = 9
	_quake(3)
	assert_true(g.game_over)
	assert_false(g.is_draw, "one survivor is not a draw")
	assert_eq(g.winner, 1)


func test_a_sweeper_lands_on_both_seats_before_anything_is_checked() -> void:
	# CR 704.3: nothing is checked mid-resolution, so the second player is
	# damaged even though the first is already dead on the board. Without
	# this the sweeper stopped at the first casualty and the survivor's life
	# total was simply wrong.
	g.players[0].life = 2
	g.players[1].life = 2
	_quake(5)
	assert_eq(g.players[0].life, -3, "the caster took the whole quake")
	assert_eq(g.players[1].life, -3, "and so did the opponent")
	assert_true(g.is_draw)


func test_both_at_zero_under_the_1997_phase_end_check_is_a_draw() -> void:
	# The 1997 fork: the life check happens at the end of the PHASE, so a
	# player may dip below zero and be healed back. Two players below zero
	# when the phase ends is still a draw — and this path used to log the
	# word "draw" while handing the win to P1.
	g.rules.life_checked_at_phase_end = true
	g.players[0].life = 3
	g.players[1].life = 3
	_quake(3)
	assert_false(g.game_over, "nobody has lost yet — the phase is not over")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_true(g.game_over, "the phase ended and the check fired")
	assert_true(g.is_draw, "and both being dead is a draw")
	assert_eq(g.winner, -1)


func test_a_draw_ends_the_game_only_once() -> void:
	# draw_game() and _lose() both end the game; whichever gets there first
	# must not be overwritten by the other.
	g.players[0].life = 3
	g.players[1].life = 3
	_quake(3)
	var endings := 0
	for line in g.log_lines:
		if line.begins_with("The game is a draw") or line.contains(" wins!"):
			endings += 1
	assert_eq(endings, 1, "the game announced its ending exactly once")
