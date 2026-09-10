extends GameTest
## THE FINISHER (2026-09-10, [member AiProfile.checks_before_casting];
## docs/ROADMAP.md, "THE DECK, THIRD PASS" §6 — THE ANGEL).
##
## The one-ply veto asks whether the POSITION a cast leaves us in is worse
## than the one we are in, and it had exactly one answer to read: an
## activated ability on THEIR battlefield. Two boards it could not see,
## both reproduced on HEAD before a line was written:
##
##     OUR OWN APPETITE. `decks/variants/the_deck_serra.deck` plays three
##     copies of the pool's one feeder, and the feeder eats at EVERY
##     player's upkeep — its controller's included. Five lands, The Abyss
##     of OURS on the table, a Serra Angel in hand:
##         act: cast Serra Angel   -> at our next upkeep: GRAVEYARD
##     Fifty games of that deck against White Knights: 56 Angels cast, 33
##     of them destroyed at our own upkeep with our own enchantment on the
##     table, and the two Angels attacked 29 times between them.
##
##     THE RACE. Five lands, a Counterspell and a Serra Angel in hand,
##     three Savannah Lions and a Serra Angel of theirs on the table:
##         act: cast Serra Angel
##     Ten power against our twenty life is two turns; the Angel needs
##     five. The card the deck wins with, spent to buy one combat.
##
## Every behaviour below is pinned with the knob ON and with it OFF, and
## the OFF arm is the pilot as it was.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.checks_before_casting = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.checks_before_casting = false
	return profile


## The RACE half's candidate. It is a FIELD and not a rung — every preset
## ships it false ([member AiProfile.holds_the_closer], and
## `test_every_preset_ships_the_race_half_at_its_null` below), because the
## Lab refused it: a wash on The Deck's own pair and a loss of about a
## point and a quarter on Blue Skies, the one starter that holds a
## counterspell beside its creatures.
func _closer_on() -> AiProfile:
	var profile := _on()
	profile.holds_the_closer = true
	return profile


## Walk our own first main phase, letting the pilot take every action it
## wants, and answer with what it did.
func _play_main(ai: AiPlayer) -> String:
	var said: Array = []
	var guard := 0
	while not g.awaiting_attackers and not g.game_over and guard < 40:
		if g.priority_player == 0:
			var line := ai.act(g)
			if line != "":
				said.append(line)
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	return " | ".join(said)


func _lands(pid: int, count: int, card_name := "Plains") -> void:
	for i in count:
		put_battlefield(pid, card_name)


## Five lands that make {3}{W}{W} and two that make {U}{U}, which is a
## Serra Angel and a Counterspell in the same hand.
func _control_mana() -> void:
	_lands(0, 5, "Tundra")
	_lands(0, 2, "Island")


# ------------------------------------------ the appetite already in play --

func test_the_angel_waits_while_our_own_abyss_is_hungry() -> void:
	var ai := _ai(_on())
	var angel := give_hand(0, "Serra Angel")
	_lands(0, 5)
	put_battlefield(0, "The Abyss")
	assert_true(ai._fed_on_arrival(g, angel),
		"our own feeder eats at OUR upkeep too")
	_play_main(ai)
	assert_eq(angel.zone, Mtg.Zone.HAND, "the card is still ours")


func test_off_the_angel_is_cast_into_our_own_abyss() -> void:
	# The malfunction as the probe found it, so the null is the pilot as
	# it was.
	var ai := _ai(_off())
	var angel := give_hand(0, "Serra Angel")
	_lands(0, 5)
	put_battlefield(0, "The Abyss")
	assert_string_contains(_play_main(ai), "cast Serra Angel")
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)


func test_the_abyss_really_does_eat_it_at_our_own_upkeep() -> void:
	# What the veto is refusing, played out: the arithmetic of the hold is
	# only worth anything if the body really does die.
	var ai := _ai(_off())
	g.set_agent(1, AiPlayer.new(1, _off()))
	var angel := put_battlefield(0, "Serra Angel")
	put_battlefield(0, "The Abyss")
	_lands(0, 5)
	assert_eq(ai._upkeep_meals(g, 0, g.players[0].battlefield)[0], angel,
		"the only nonartifact creature we control is the meal")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD, "fed to our own enchantment")


func test_a_cheaper_body_of_ours_shelters_the_angel() -> void:
	# [method AiPlayer._is_next_meal]'s own rule, asked of our side: the
	# feeder takes ONE body a turn and takes the worst, so a Savannah
	# Lions standing beside the Angel is what the Abyss eats.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		var angel := give_hand(0, "Serra Angel")
		_lands(0, 5)
		put_battlefield(0, "The Abyss")
		put_battlefield(0, "Savannah Lions")
		assert_false(ai._fed_on_arrival(g, angel), "the Lions is eaten first")
		assert_string_contains(_play_main(ai), "cast Serra Angel")


func test_an_artifact_creature_is_no_meal() -> void:
	# The card's own filter, unchanged: "target NONARTIFACT creature".
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		var golem := give_hand(0, "Clockwork Beast")
		_lands(0, 6)
		put_battlefield(0, "The Abyss")
		assert_false(ai._fed_on_arrival(g, golem))
		assert_string_contains(_play_main(ai), "cast Clockwork Beast")


func test_a_noncreature_spell_is_never_held_by_either_half() -> void:
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		var tome := give_hand(0, "Jayemdae Tome")
		give_hand(0, "Counterspell")
		_lands(0, 6, "Tundra")
		put_battlefield(0, "The Abyss")
		assert_false(ai._fed_on_arrival(g, tome))
		assert_false(ai._holds_the_closer(g, tome))
		assert_string_contains(_play_main(ai), "cast Jayemdae Tome")


# ------------------------------------------------------------- the race --

func test_the_closer_waits_while_their_board_can_race_it() -> void:
	var ai := _ai(_closer_on())
	var angel := give_hand(0, "Serra Angel")
	give_hand(0, "Counterspell")
	_control_mana()
	_lands(1, 4)
	for i in 3:
		put_battlefield(1, "Savannah Lions")
	put_battlefield(1, "Serra Angel")
	assert_true(ai._out_raced(g, angel),
		"ten power a turn against twenty life; the Angel needs five turns")
	assert_true(ai._holds_the_closer(g, angel))
	_play_main(ai)
	assert_eq(angel.zone, Mtg.Zone.HAND)


func test_off_the_closer_is_committed_into_the_race() -> void:
	var ai := _ai(_off())
	var angel := give_hand(0, "Serra Angel")
	give_hand(0, "Counterspell")
	_control_mana()
	_lands(1, 4)
	for i in 3:
		put_battlefield(1, "Savannah Lions")
	put_battlefield(1, "Serra Angel")
	assert_string_contains(_play_main(ai), "cast Serra Angel")


func test_a_hand_with_no_answer_in_it_has_nothing_to_wait_for() -> void:
	# The one line that keeps this off every aggro deck in the pool: an
	# attacker held back by a hand that cannot follow it up is not a
	# finisher waiting for its moment.
	for on in [true, false]:
		before_each()
		var ai := _ai(_closer_on() if on else _off())
		var angel := give_hand(0, "Serra Angel")
		_control_mana()
		for i in 3:
			put_battlefield(1, "Savannah Lions")
		put_battlefield(1, "Serra Angel")
		assert_false(ai._holds_the_closer(g, angel), "no counter in hand")
		assert_string_contains(_play_main(ai), "cast Serra Angel")


func test_a_board_that_cannot_reach_us_is_no_race() -> void:
	for on in [true, false]:
		before_each()
		var ai := _ai(_closer_on() if on else _off())
		var angel := give_hand(0, "Serra Angel")
		give_hand(0, "Counterspell")
		_control_mana()
		put_battlefield(1, "Savannah Lions")
		assert_false(ai._out_raced(g, angel),
			"two power for five turns is ten, and we are at twenty")
		assert_string_contains(_play_main(ai), "cast Serra Angel")


func test_the_panic_line_lifts_the_hold() -> void:
	# A desperate play is allowed to be desperate — Forge's own escape,
	# and here it is the whole answer to "but the Angel BLOCKS".
	for on in [true, false]:
		before_each()
		var ai := _ai(_closer_on() if on else _off())
		var angel := give_hand(0, "Serra Angel")
		give_hand(0, "Counterspell")
		_control_mana()
		for i in 3:
			put_battlefield(1, "Savannah Lions")
		put_battlefield(1, "Serra Angel")
		g.players[0].life = 4
		assert_true(ai._in_danger(g))
		assert_string_contains(_play_main(ai), "cast Serra Angel")


# -------------------------------------------------------------- the lock --

func test_a_moat_of_ours_is_the_lock_and_the_angel_goes() -> void:
	for on in [true, false]:
		before_each()
		var ai := _ai(_closer_on() if on else _off())
		var angel := give_hand(0, "Serra Angel")
		give_hand(0, "Counterspell")
		_control_mana()
		put_battlefield(0, "Moat")
		for i in 3:
			put_battlefield(1, "Savannah Lions")
		assert_true(ai._board_is_locked(g),
			"a static of ours, and nothing of theirs may attack")
		assert_string_contains(_play_main(ai), "cast Serra Angel")


func test_a_flier_of_theirs_walks_over_the_moat() -> void:
	var ai := _ai(_closer_on())
	var angel := give_hand(0, "Serra Angel")
	give_hand(0, "Counterspell")
	_control_mana()
	put_battlefield(0, "Moat")
	for i in 4:
		put_battlefield(1, "Serra Angel")
	assert_false(ai._board_is_locked(g), "four fliers are not held by a Moat")
	assert_true(ai._holds_the_closer(g, angel))


func test_the_feeder_that_eats_their_one_attacker_is_a_lock() -> void:
	# "a Moat or an Abyss on the table": the other shape of the same
	# sentence, read through [method AiPlayer._upkeep_meals].
	var ai := _ai(_closer_on())
	var angel := give_hand(0, "Serra Angel")
	give_hand(0, "Counterspell")
	_control_mana()
	put_battlefield(0, "The Abyss")
	put_battlefield(0, "Savannah Lions")   # our own meal, so the Angel is not it
	put_battlefield(1, "Hypnotic Specter")
	assert_true(ai._board_is_locked(g),
		"their one attacker is the meal at their own upkeep")
	assert_false(ai._holds_the_closer(g, angel))


func test_two_attackers_and_one_feeder_is_not_a_lock() -> void:
	var ai := _ai(_closer_on())
	var angel := give_hand(0, "Serra Angel")
	give_hand(0, "Counterspell")
	_control_mana()
	put_battlefield(0, "The Abyss")
	put_battlefield(0, "Savannah Lions")
	put_battlefield(1, "Hypnotic Specter")
	put_battlefield(1, "Serra Angel")
	assert_false(ai._board_is_locked(g), "it eats one body a turn")


# ------------------------------------------------------ what a closer is --

func test_a_bigger_body_of_ours_means_this_one_is_not_the_closer() -> void:
	var ai := _ai(_closer_on())
	var bears := give_hand(0, "Grizzly Bears")
	give_hand(0, "Counterspell")
	_control_mana()
	put_battlefield(0, "Serra Angel")
	for i in 3:
		put_battlefield(1, "Savannah Lions")
	assert_false(ai._is_the_closer(g, bears),
		"the game does not end with the Bears while the Angel stands")
	assert_false(ai._holds_the_closer(g, bears))


func test_a_board_that_already_closes_faster_holds_nothing_back() -> void:
	var ai := _ai(_closer_on())
	var angel := give_hand(0, "Serra Angel")
	give_hand(0, "Counterspell")
	_control_mana()
	for i in 3:
		put_battlefield(0, "Savannah Lions")   # six power, against the Angel's four
	for i in 3:
		put_battlefield(1, "Savannah Lions")
	assert_false(ai._is_the_closer(g, angel),
		"our own table is the faster clock")
	assert_false(ai._holds_the_closer(g, angel))


func test_the_race_arithmetic() -> void:
	var ai := _ai(_closer_on())
	var angel := give_hand(0, "Serra Angel")
	put_battlefield(1, "Savannah Lions")
	put_battlefield(1, "Savannah Lions")
	# Their life 20 / the Angel's 4 power = five turns; four power a turn
	# for five turns is twenty, and we are at twenty.
	assert_true(ai._out_raced(g, angel))
	g.players[0].life = 21
	assert_false(ai._out_raced(g, angel), "one life more and they are a turn short")


func test_a_wall_of_theirs_is_no_racer() -> void:
	var ai := _ai(_closer_on())
	var angel := give_hand(0, "Serra Angel")
	for i in 4:
		put_battlefield(1, "Wall of Stone")
	assert_false(ai._out_raced(g, angel), "a Defender never attacks")


# ------------------------------------------------- the knob is the gate --

func test_off_reads_none_of_it() -> void:
	# The null is the null: with the knob off the whole reading is behind
	# one `if` and the pilot is the one that shipped.
	var ai := _ai(_off())
	var angel := give_hand(0, "Serra Angel")
	give_hand(0, "Counterspell")
	_control_mana()
	put_battlefield(0, "The Abyss")
	for i in 3:
		put_battlefield(1, "Savannah Lions")
	var intent := EffectIntent.read(angel.data.spell_effects, angel.data.card_name)
	assert_false(ai._cast_veto(g, angel, intent, [], 0))


func test_on_the_same_board_vetoes() -> void:
	var ai := _ai(_on())
	var angel := give_hand(0, "Serra Angel")
	give_hand(0, "Counterspell")
	_control_mana()
	put_battlefield(0, "The Abyss")
	for i in 3:
		put_battlefield(1, "Savannah Lions")
	var intent := EffectIntent.read(angel.data.spell_effects, angel.data.card_name)
	assert_true(ai._cast_veto(g, angel, intent, [], 0))


# ------------------------------------------------- the rungs and the null --

func test_every_preset_ships_the_race_half_at_its_null() -> void:
	# THE NUMBERS REFUSED THE RACE (`docs/ai-difficulty.md` §4). On the
	# Serra variant against White Knights it is +0.1 ±2.9 at 2 000 games an
	# arm — inside its own interval — and on the five-deck starter matrix
	# it costs Blue Skies, the one starter holding a counterspell beside
	# its creatures, about fifty games of four thousand. A capability is as
	# good or better one rung up; this one is not. So the field ships at
	# the null everywhere, the way [member AiProfile.develops_late] and
	# [member AiProfile.crack_back_margin] do, and the question stays one
	# Deck Lab command.
	assert_false(AiProfile.apprentice().holds_the_closer)
	assert_false(AiProfile.magician().holds_the_closer)
	assert_false(AiProfile.sorcerer().holds_the_closer)
	assert_false(AiProfile.wizard().holds_the_closer)


func test_the_shipped_wizard_commits_the_closer_into_the_race() -> void:
	# The null, played rather than asserted: the pilot the game ships casts
	# the Angel on the board the rule was written about.
	var ai := _ai(AiProfile.wizard())
	var angel := give_hand(0, "Serra Angel")
	give_hand(0, "Counterspell")
	_control_mana()
	for i in 3:
		put_battlefield(1, "Savannah Lions")
	put_battlefield(1, "Serra Angel")
	assert_false(ai._holds_the_closer(g, angel), "the field ships off")
	assert_string_contains(_play_main(ai), "cast Serra Angel")


func test_the_shipped_wizard_still_refuses_our_own_abyss() -> void:
	# ...and the half that DID ship is on at the top of the ladder, where
	# `checks_before_casting` lives.
	var ai := _ai(AiProfile.wizard())
	var angel := give_hand(0, "Serra Angel")
	_lands(0, 5)
	put_battlefield(0, "The Abyss")
	assert_true(ai._fed_on_arrival(g, angel))
	_play_main(ai)
	assert_eq(angel.zone, Mtg.Zone.HAND)


func test_the_sorcerer_has_neither_half() -> void:
	# `checks_before_casting` is the Wizard's alone — the ladder's shape,
	# unchanged by this row.
	assert_false(AiProfile.sorcerer().checks_before_casting)
	assert_true(AiProfile.wizard().checks_before_casting)


func test_both_halves_are_reachable_from_the_deck_lab() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("holds_the_closer=on"), "")
	assert_true(profile.holds_the_closer)
	assert_eq(profile.apply_overrides("holds_the_closer=off"), "")
	assert_false(profile.holds_the_closer)
	assert_eq(profile.apply_overrides("checks_before_casting=off"), "")
	assert_false(profile.checks_before_casting)
