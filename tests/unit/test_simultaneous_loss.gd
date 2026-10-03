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


# -------------------------------------------- bug pass 2026-10-03 ----------

## Both libraries down to [param left] cards, the rest exiled (setup only).
func _thin_libraries(left: int) -> void:
	for p in g.players:
		while p.library.size() > left:
			var c: CardInstance = p.library.pop_back()
			c.zone = Mtg.Zone.EXILE
			p.exile.append(c)


func test_both_seats_decking_on_one_wheel_of_fortune_is_a_draw() -> void:
	# CR 704.5b + 104.4a: drawing from an empty library is a state-based
	# loss, checked with life and poison in ONE simultaneous pass. Wheel of
	# Fortune empties both libraries in the same resolution, so both seats
	# lose at once — a draw. The old draw_cards lost the player on the spot
	# and _lose did not look at game_over, so the second seat's loss
	# rewrote the winner to P0 and game_ended fired twice ([1, 0]).
	advance_to_step(Mtg.Step.MAIN1)
	_thin_libraries(3)
	var ended: Array = []
	g.game_ended.connect(func(w: int) -> void: ended.append(w))
	var wheel := give_hand(0, "Wheel of Fortune")
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ok(g.cast_spell(0, wheel, []))
	resolve_stack()
	assert_true(g.game_over, "both duelists drew from an empty library")
	assert_true(g.is_draw, "at the same time: a draw")
	assert_eq(g.winner, -1, "nobody won")
	assert_eq(ended, [-1], "the game ended exactly once, as a draw")


func test_a_lone_empty_library_draw_still_loses_at_once() -> void:
	# The control: a turn-based draw from an empty library outside any
	# resolution is still an immediate loss for that seat.
	advance_to_step(Mtg.Step.MAIN1)
	_thin_libraries(0)
	g.draw_cards(1, 1)
	assert_true(g.game_over)
	assert_false(g.is_draw)
	assert_eq(g.winner, 0)


func test_a_loss_after_the_game_ended_changes_nothing() -> void:
	# _lose must not rewrite a finished game (a draw, or a win already
	# recorded) — the guard that let a second loss hand P0 the Wheel game.
	g.draw_game("test")
	g.lose_game(0, "test")
	assert_true(g.is_draw)
	assert_eq(g.winner, -1)


func test_psionic_blast_killing_both_duelists_is_a_draw() -> void:
	# CR 704.3: no state-based action mid-resolution. Psionic Blast deals 4
	# to the target and then 2 to its caster; both at 2 means both are at
	# or below 0 when the spell has finished — a draw, not a win for the
	# seat that was hit first (the old mid-resolution check ended the game
	# at the first packet, then the second packet's check overwrote it).
	advance_to_step(Mtg.Step.MAIN1)
	g.players[0].life = 2
	g.players[1].life = 2
	var blast := give_hand(0, "Psionic Blast")
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, blast, [TargetRef.player(1)]))
	resolve_stack()
	assert_true(g.game_over)
	assert_true(g.is_draw, "both at or below 0 when the spell finished")
	assert_eq(g.winner, -1)


func test_orcish_artillery_killing_both_duelists_is_a_draw() -> void:
	# The same for an activated ability's resolution (StackKind.ABILITY).
	advance_to_step(Mtg.Step.MAIN1)
	g.players[0].life = 3
	g.players[1].life = 2
	var gun := put_battlefield(0, "Orcish Artillery")
	assert_ok(g.activate_ability(0, gun, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_true(g.game_over)
	assert_true(g.is_draw, "2 to P1 and 3 to P0 landed together")
	assert_eq(g.winner, -1)


func test_a_creature_dealt_lethal_mid_resolution_dies_when_it_finishes() -> void:
	# The bracket defers creature deaths the same way, and they still
	# happen once the item has resolved.
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var gun := put_battlefield(0, "Orcish Artillery")
	assert_ok(g.activate_ability(0, gun, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the bear died after the resolution")
	assert_eq(g.players[0].life, 17, "and the artillery still hit its owner")
