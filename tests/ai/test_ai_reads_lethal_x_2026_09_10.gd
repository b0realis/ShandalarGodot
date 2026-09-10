extends GameTest
## "X EQUALS MY LIFE" — CHANNEL-FIREBALL (2026-09-10,
## [member AiProfile.reads_lethal_x]; wave 2, `docs/forge/casting.md` P6).
##
## WHAT WAS WRONG, reproduced at HEAD before a line was written. Channel
## grants the PLAYER a mana source rather than a permanent an ability
## ([member MtgPlayer.life_for_mana]), so it is a card-local effect with no
## [AddManaEffect] to test `is` against: [member EffectIntent.adds_mana]
## was false, the Dark Ritual gate never asked about it, and the card was
## cast as a plain three-point spell. A Wizard with Channel and Fireball in
## hand, two Forests and a Mountain on the table, the opponent at twenty:
##
##     act() -> 'cast Channel'
##     Channel GRAVEYARD, Fireball still in HAND, our life 20
##
## — and [method MtgGame.pay_life_for_mana] had never been called by any
## seat in this AI's life.
##
## WHAT IT IS NOW. A life-for-mana spell is cast only in a step where the
## life it opens makes an X burn in hand LETHAL, and once it is open the
## life is paid and the burn fired in ONE action, so no rung can pay life
## for mana it then fails to spend. The life is capped at
## `life − 1 − their attack`, which is the cap P6 names.
##
## THE DEFENDER'S HALF OF P6 IS NOT HERE, and both halves of the reason are
## on the record. The counter against a lethal X spell is one of
## [member AiProfile.counters_by_shape]'s ALWAYS clauses, exactly as P6
## asks ("counts it as ALWAYS (P2)"), and is pinned in
## `test_ai_counters_by_shape_2026_09_10.gd`. The Circle of Protection
## DID NOT REPRODUCE: with the 1997 prevention fork on, the shipped pilot
## already answers a Fireball for six at six life with the Circle and
## lives, because [method AiPlayer._packet_worth] prices a packet that
## kills us at [constant AiPlayer.LETHAL_WORTH]. That board is below, on
## both arms, so nobody builds it a second time.
##
## Every behaviour is pinned with the knob ON and with it OFF, and the OFF
## arm is the pilot as it shipped.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.reads_lethal_x = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.reads_lethal_x = false
	return profile


## Seat 0 is the pilot: [param forests] Forests and [param mountains]
## Mountains, Channel and Fireball in hand, seat 1 at [param their_life].
func _board(their_life: int, forests := 2, mountains := 1) -> void:
	g.players[1].life = their_life
	for _i in forests:
		put_battlefield(0, "Forest")
	for _i in mountains:
		put_battlefield(0, "Mountain")
	give_hand(0, "Channel")
	give_hand(0, "Fireball")
	advance_to_step(Mtg.Step.MAIN1)


## Let the pilot act until it passes, resolving whatever it puts up.
func _play_the_turn(ai: AiPlayer) -> Array[String]:
	var log: Array[String] = []
	var guard := 0
	while not g.game_over and guard < 20:
		var did := ai.act(g)
		if did == "" or did == "pass":
			break
		log.append(did)
		var inner := 0
		while not g.stack.is_empty() and inner < 12:
			assert_ok(g.pass_priority(g.priority_player))
			inner += 1
		guard += 1
	return log


func _in_hand(pid: int, card_name: String) -> bool:
	for inst in g.players[pid].hand:
		if inst.data.card_name == card_name:
			return true
	return false


# ------------------------------------------------------- the kill itself --

func test_the_life_is_paid_and_the_fireball_ends_the_game() -> void:
	var ai := _ai(_on())
	_board(6)
	var log := _play_the_turn(ai)
	assert_eq(log, ["cast Channel", "paid 6 life and cast Fireball for 6"])
	assert_true(g.game_over, "the opponent is at zero")
	assert_eq(g.players[1].life, 0)
	assert_eq(g.players[0].life, 14, "six life, and not one point more")


func test_off_the_channel_is_thrown_away() -> void:
	# The malfunction as the probe met it, so the null is the pilot as it
	# was: the card cast for its printed 3.00 and not one point of life
	# ever paid.
	var ai := _ai(_off())
	_board(6)
	var log := _play_the_turn(ai)
	assert_eq(log, ["cast Channel"])
	assert_false(g.game_over)
	assert_eq(g.players[0].life, 20, "no life was ever sold")
	assert_true(_in_hand(0, "Fireball"), "and the Fireball is still in hand")


# ------------------------------------------------------------- the refusal --

func test_a_channel_that_ends_nothing_is_kept() -> void:
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		_board(20)
		var log := _play_the_turn(ai)
		if on:
			assert_eq(log, [], "three lands do not reach twenty damage")
			assert_true(_in_hand(0, "Channel"))
		else:
			assert_eq(log, ["cast Channel"],
				"the null casts it into an empty board on the spot")


func test_the_board_that_already_pays_for_it_needs_no_life() -> void:
	# Four Mountains and two Forests reach X=2 with the Mountain's {R}
	# spare, so the Fireball wins on its own and the Channel stays in hand.
	var ai := _ai(_on())
	_board(2, 2, 4)
	var log := _play_the_turn(ai)
	assert_eq(log, ["cast Fireball"])
	assert_true(g.game_over)
	assert_eq(g.players[0].life, 20, "no life was sold for mana it had")
	assert_true(_in_hand(0, "Channel"))


func test_a_channel_with_no_burn_behind_it_is_kept() -> void:
	var ai := _ai(_on())
	g.players[1].life = 3
	for _i in 4:
		put_battlefield(0, "Forest")
	give_hand(0, "Channel")
	give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var log := _play_the_turn(ai)
	assert_false(log.has("cast Channel"), "no X burn, no reason")
	assert_true(_in_hand(0, "Channel"))


# ------------------------------------------------------------- the budget --

func test_the_life_is_capped_by_their_next_swing() -> void:
	# `life - 1 - their attack`. Two Serra Angels across the table swing
	# for eight into an empty board, so a pilot at twenty may sell eleven —
	# and a kill that wants twelve is not bought.
	var ai := _ai(_on())
	assert_eq(ai._life_for_mana_budget(g), 19, "an empty board sells all but one")
	for _i in 2:
		put_battlefield(1, "Serra Angel")
	assert_eq(ai._life_for_mana_budget(g), 11)


func test_a_kill_beyond_the_budget_is_refused() -> void:
	var ai := _ai(_on())
	_board(14)
	for _i in 2:
		put_battlefield(1, "Serra Angel")
	# Fourteen damage off one Mountain wants thirteen life, and the budget
	# is eleven.
	var log := _play_the_turn(ai)
	assert_false(log.has("cast Channel"))
	assert_true(_in_hand(0, "Channel"))


func test_a_kill_inside_the_budget_is_taken() -> void:
	var ai := _ai(_on())
	_board(9)
	for _i in 2:
		put_battlefield(1, "Serra Angel")
	var log := _play_the_turn(ai)
	assert_eq(log, ["cast Channel", "paid 9 life and cast Fireball for 9"])
	assert_true(g.game_over)
	assert_eq(g.players[0].life, 11, "one point clear of their whole swing")


func test_the_pilot_never_pays_life_it_cannot_spend() -> void:
	# The whole reason the payment and the cast are ONE action: a seat that
	# paid and then failed to cast would have burned its own life for
	# nothing, and there is no rung at which that is a weakness.
	for their_life in [2, 6, 9, 14, 20]:
		before_each()
		var ai := _ai(_on())
		_board(their_life)
		var before: int = g.players[0].life
		var log := _play_the_turn(ai)
		var paid: bool = before != g.players[0].life
		assert_true(not paid or g.game_over,
			"life sold at %d, and the game did not end (log %s)"
				% [their_life, log])


# ------------------------------------------- the sweeper that hits players --

func test_channel_hurricane_is_the_same_reading() -> void:
	# Two printed shapes reach a player's life with an X, and the pool holds
	# one of each behind a Channel: the aimed burn, and the sweeper that
	# hits PLAYERS. Summoner (1997) is the deck that puts the question —
	# one Channel, four Hurricanes.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		g.players[1].life = 4
		for _i in 4:
			put_battlefield(0, "Forest")
		give_hand(0, "Channel")
		give_hand(0, "Hurricane")
		advance_to_step(Mtg.Step.MAIN1)
		var log := _play_the_turn(ai)
		if on:
			assert_eq(log, ["cast Channel", "paid 3 life and cast Hurricane for 4"])
			assert_true(g.game_over)
			assert_eq(g.players[0].life, 13, "three sold, and four taken by our own")
		else:
			assert_eq(log, ["cast Channel"], "the null throws the card away")
			assert_false(g.game_over)


func test_a_hurricane_that_kills_us_too_is_refused() -> void:
	# The X lands on both faces. At six life a Hurricane for eight is not a
	# win, it is a draw at best and a loss at worst.
	var ai := _ai(_on())
	g.players[0].life = 6
	g.players[1].life = 8
	for _i in 4:
		put_battlefield(0, "Forest")
	give_hand(0, "Channel")
	give_hand(0, "Hurricane")
	advance_to_step(Mtg.Step.MAIN1)
	var log := _play_the_turn(ai)
	assert_false(log.has("cast Channel"))
	assert_false(g.game_over)


# ------------------------------------------------------------- the reader --

func test_the_reader_names_channel_and_nothing_else() -> void:
	var found: Array[String] = []
	for card_name in CardRegistry.all_names():
		var data := CardRegistry.get_card(card_name)
		if data == null or data.spell_effects.is_empty():
			continue
		if EffectIntent.read(data.spell_effects, card_name).mana_for_life:
			found.append(card_name)
	assert_eq(found, ["Channel"], "the pool's one life-for-mana spell")


func test_unknown_stays_set_for_channel() -> void:
	var data := CardRegistry.get_card("Channel")
	var intent := EffectIntent.read(data.spell_effects, "Channel")
	assert_true(intent.unknown, "every older reading is unchanged")
	assert_false(intent.adds_mana, "and it is not a Dark Ritual")


# ---------------------------------- the Circle half, which did not reproduce --

func test_the_circle_already_answers_a_lethal_fireball() -> void:
	# P6's other defender clause, measured against the tree and NOT BUILT.
	# With the 1997 damage-prevention fork on, the shipped pilot prevents
	# all six and lives — on BOTH arms — because a packet that kills us is
	# priced at LETHAL_WORTH. With the fork off there is no window for any
	# seat to act in, which is a ruleset and not an AI gap.
	for on in [true, false]:
		before_each()
		g.rules.damage_prevention_window = true
		var ai := _ai(_on() if on else _off(), 1)
		g.players[1].life = 6
		put_battlefield(1, "Circle of Protection: Red")
		for _i in 4:
			put_battlefield(1, "Plains")
		for _i in 7:
			put_battlefield(0, "Mountain")
		var spell := give_hand(0, "Fireball")
		advance_to_step(Mtg.Step.MAIN1)
		add_mana(0, Mtg.ManaColor.R, 1)
		add_mana(0, Mtg.ManaColor.C, 6)
		assert_ok(g.cast_spell(0, spell, [TargetRef.player(1)], 6))
		var guard := 0
		while not g.game_over and guard < 60:
			if g.priority_player == 1:
				if ai.act(g) == "":
					assert_ok(g.pass_priority(1))
			else:
				assert_ok(g.pass_priority(0))
			if g.stack.is_empty() and g.damage_pending.is_empty() \
					and not g.awaiting_damage_prevention:
				break
			guard += 1
		assert_false(g.game_over, "the Circle answered it")
		assert_eq(g.players[1].life, 6, "and not a point landed")
