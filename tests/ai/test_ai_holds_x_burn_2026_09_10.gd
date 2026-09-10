extends GameTest
## THE X BURN HELD FOR A BIGGER ONE (2026-09-10,
## [member AiProfile.holds_x_burn]; wave 1 row 7,
## `docs/forge/casting.md` P7).
##
## WHAT WAS WRONG, and it was reproduced before a line was written: a
## Wizard on THREE Mountains with a Fireball in hand and a Grizzly Bears
## across the table cast it for X=2 at the bear on turn three. One of the
## deck's two finishers, spent on a board a Lightning Bolt answers for one
## mana, at the moment the card is worth the least it will ever be worth.
## [method AiPlayer._size_x_burn] sizes X to the victim, which is right,
## and had no reading at all of whether the card was worth casting yet.
##
## WHAT IT IS NOW. While the LARGEST X the mana can reach is under the
## profile's number and the game is younger than twice that in turns, the
## burn is not pointed at a creature. Three things end the hold, and none
## of them is a constant of its own:
##
##  * LETHAL, which is not asked here at all — [method
##    AiPlayer._size_x_burn] returns the face before it looks for a
##    creature, so a burn that wins is never held.
##  * THEIR CLOCK ([method AiPlayer._in_danger]): the panic line
##    ([member AiProfile.chump_threshold], read a fourth time) against the
##    damage that would actually land through the blocks this seat would
##    make. A pilot about to die spends the card it was keeping.
##  * THE TURN. The hold expires on its own, so a Fireball is never held
##    for a game that has stopped being young.
##
## AND THE FACE ARM STILL RUNS under the hold: a burn worth throwing at a
## player within range of it is still thrown.
##
## THE REACH AND NOT THE SHOT. Gating on the X this routine would actually
## PAY was built first and is pinned here as the thing that was rejected:
## it refuses a Fireball for four at a Serra Angel for the whole of a
## game's first nine turns, which is a play `test_ai_capabilities.gd` has
## pinned as correct since the Fireball was first sized. Gating on the
## reach says the honest thing — while the card can only be small it is
## not the answer to anything yet — and leaves the sizing that was already
## right in charge once it is big.
##
## Nothing here names a card in the AI: the shape is
## [member EffectIntent.damage_uses_x], and everything else is the board.
## Every behaviour is pinned with the knob at 0, at the Sorcerer's 3 and
## at the Wizard's 5; at 0 the pilot does exactly what it did at HEAD,
## which is the null.


func _ai(number: int, seat := 0) -> AiPlayer:
	var profile := AiProfile.wizard()
	profile.holds_x_burn = number
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _mountains(n: int) -> void:
	for _i in n:
		put_battlefield(0, "Mountain")


func _theirs(card_name: String, n := 1) -> void:
	for _i in n:
		put_battlefield(1, card_name)


## The X the pilot paid, or -1 when it cast nothing.
func _top_x() -> int:
	if g.stack.is_empty():
		return -1
	return g.stack.back().x_value


## What the top of the stack is aimed at: `"player"`, a card name, or "".
func _aim() -> String:
	if g.stack.is_empty() or g.stack.back().targets.is_empty():
		return ""
	var ref: TargetRef = g.stack.back().targets[0]
	if ref.is_player:
		return "player"
	return g.find_instance(ref.instance_id).data.card_name


# ---------------------------------------------------------- the reproduction --

func test_the_two_point_fireball_at_a_bear_on_turn_three() -> void:
	# The null: three Mountains is a reach of two, and two is what it paid.
	var ai := _ai(0)
	give_hand(0, "Fireball")
	_mountains(3)
	_theirs("Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Fireball")
	assert_eq(_top_x(), 2)
	assert_eq(_aim(), "Grizzly Bears")


func test_the_hold_keeps_the_reach_at_both_rungs() -> void:
	for number in [3, 5]:
		before_each()
		var ai := _ai(number)
		var ball := give_hand(0, "Fireball")
		_mountains(3)
		_theirs("Grizzly Bears")
		advance_to_step(Mtg.Step.MAIN1)
		assert_eq(ai.act(g), "pass",
			"holds_x_burn=%d holds a reach of two" % number)
		assert_eq(ball.zone, Mtg.Zone.HAND)


func test_the_hold_lifts_when_the_reach_arrives() -> void:
	# The Sorcerer's three is reached on four Mountains, the Wizard's five
	# on six — and from there the sizing that was always right takes over.
	var sorcerer := _ai(3)
	give_hand(0, "Fireball")
	_mountains(4)
	_theirs("Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(sorcerer.act(g), "cast Fireball")
	assert_eq(_top_x(), 2, "the shot is still sized to the bear")

	before_each()
	var wizard := _ai(5)
	give_hand(0, "Fireball")
	_mountains(5)
	_theirs("Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(wizard.act(g), "pass", "a reach of four is still under five")

	before_each()
	var richer := _ai(5)
	give_hand(0, "Fireball")
	_mountains(6)
	_theirs("Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(richer.act(g), "cast Fireball")
	assert_eq(_top_x(), 2)


func test_the_serra_is_still_killed_for_four() -> void:
	# The play the SHOT reading refused, and the reason this knob reads the
	# reach instead. Eight Mountains is a reach of seven; four kills it.
	for number in [0, 3, 5]:
		before_each()
		var ai := _ai(number)
		give_hand(0, "Fireball")
		_mountains(8)
		var serra := put_battlefield(1, "Serra Angel")
		advance_to_step(Mtg.Step.MAIN1)
		assert_string_contains(ai.act(g), "cast Fireball",
			"holds_x_burn=%d must not decline a Serra Angel" % number)
		assert_eq(_top_x(), 4)
		resolve_stack()
		assert_eq(serra.zone, Mtg.Zone.GRAVEYARD)


# ----------------------------------------------------- what lifts the hold --

func test_the_hold_expires_with_the_game() -> void:
	var ai := _ai(5)
	give_hand(0, "Fireball")
	_mountains(3)
	_theirs("Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass")
	# turn_number counts a PLAYER's turn, so twice the Wizard's five is
	# turn ten — and turn eleven is the first of OURS past it.
	while g.turn_number < 11 and not g.game_over:
		advance_to_next_turn()
	assert_eq(g.turn_number, 11)
	assert_eq(g.active_player, 0, "and it is ours to spend")
	# Ten turns of draws put lands in the hand; the land drop comes first
	# and the Fireball is the next thing the main phase does.
	var did := ""
	for _i in 4:
		did = ai.act(g)
		if did == "" or did.contains("Fireball"):
			break
	assert_string_contains(did, "cast Fireball",
		"a game that has stopped being young holds nothing")


func test_the_panic_line_lifts_the_hold() -> void:
	var ai := _ai(5)
	give_hand(0, "Fireball")
	_mountains(3)
	_theirs("Grizzly Bears")
	g.players[0].life = 5   # at or under the Wizard's chump_threshold of 6
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Fireball",
		"a pilot at five life spends what it was keeping")


func test_their_clock_lifts_the_hold_and_our_blockers_put_it_back() -> void:
	# Three bears is six damage a turn. At eight life that is the panic
	# line next turn; behind three Walls of Stone it is nothing at all,
	# and the reading is the block plan this seat would actually make.
	var ai := _ai(5)
	give_hand(0, "Fireball")
	_mountains(4)
	_theirs("Grizzly Bears", 3)
	g.players[0].life = 8
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Fireball", "their clock is the danger")

	before_each()
	var walled := _ai(5)
	give_hand(0, "Fireball")
	_mountains(4)
	_theirs("Grizzly Bears", 3)
	for _i in 3:
		put_battlefield(0, "Wall of Stone")
	g.players[0].life = 8
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(walled.act(g), "pass",
		"a swing three walls eat is no clock, so the card waits")


func test_no_clock_and_full_life_is_no_danger() -> void:
	var ai := _ai(5)
	give_hand(0, "Fireball")
	_mountains(4)
	_theirs("Grizzly Bears", 3)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass", "six a turn against twenty is not danger yet")


func test_lethal_is_taken_before_the_hold_is_asked() -> void:
	var ai := _ai(5)
	give_hand(0, "Fireball")
	_mountains(6)
	put_battlefield(1, "Serra Angel")
	g.players[1].life = 5
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Fireball")
	assert_eq(_aim(), "player")
	resolve_stack()
	assert_true(g.game_over, "X = 5 at the face wins, and a win is never held")


func test_the_face_arm_still_runs_under_the_hold() -> void:
	# Five Mountains is a reach of four, under the Wizard's five, so the
	# bear does not get it — but a player at eight is within range of the
	# whole card, and that arm is untouched.
	var ai := _ai(5)
	give_hand(0, "Fireball")
	_mountains(5)
	_theirs("Grizzly Bears")
	g.players[1].life = 8
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Fireball")
	assert_eq(_aim(), "player", "the reach goes to the face, not to the bear")
	assert_eq(_top_x(), 4)

	before_each()
	var null_arm := _ai(0)
	give_hand(0, "Fireball")
	_mountains(5)
	_theirs("Grizzly Bears")
	g.players[1].life = 8
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(null_arm.act(g), "cast Fireball")
	assert_eq(_aim(), "Grizzly Bears",
		"the null spends it on the bear, as it always did")


# ----------------------------------------------------------- their clock --

func test_in_danger_reads_the_damage_that_would_land() -> void:
	var ai := _ai(5)
	assert_false(ai._in_danger(g), "an empty board at twenty is no danger")
	g.players[0].life = 6
	assert_true(ai._in_danger(g), "on the panic line with no board at all")
	g.players[0].life = 20
	_theirs("Grizzly Bears", 3)
	assert_false(ai._in_danger(g), "six a turn against twenty")
	g.players[0].life = 8
	assert_true(ai._in_danger(g), "six a turn against eight")
	for _i in 3:
		put_battlefield(0, "Wall of Stone")
	assert_false(ai._in_danger(g), "and none of it lands through three walls")


func test_a_defender_of_theirs_is_not_a_clock() -> void:
	var ai := _ai(5)
	g.players[0].life = 8
	_theirs("Wall of Stone", 3)
	assert_false(ai._in_danger(g), "walls do not attack")


# --------------------------------------------------------------- the ladder --

func test_the_rungs_are_the_ones_the_plan_named() -> void:
	assert_eq(AiProfile.apprentice().holds_x_burn, 0, "no layer at the bottom")
	assert_eq(AiProfile.magician().holds_x_burn, 0)
	assert_eq(AiProfile.sorcerer().holds_x_burn, 3)
	assert_eq(AiProfile.wizard().holds_x_burn, 5, "and the ladder is monotone")


func test_the_knob_is_reachable_from_the_deck_lab() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("holds_x_burn=0"), "")
	assert_eq(profile.holds_x_burn, 0)
	assert_eq(profile.apply_overrides("holds_x_burn=3"), "")
	assert_eq(profile.holds_x_burn, 3)
