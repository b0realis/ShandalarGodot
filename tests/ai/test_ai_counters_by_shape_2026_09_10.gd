extends GameTest
## COUNTER BY WHAT THE SPELL DOES (2026-09-10,
## [member AiProfile.counters_by_shape]; wave 2, `docs/forge/casting.md`
## P2).
##
## WHAT WAS WRONG, reproduced at HEAD before a line was written — a Wizard
## on eight Islands with one Counterspell in hand, and the printed worth
## [method Evaluator.card_value] answers with:
##
##     Wrath of God 5.00 · Fireball 2.50 · Time Walk 3.00 · Wheel 4.00
##     Serra Angel 10.00 · Hill Giant 6.00 · Control Magic 5.00
##
##     a) Wrath of God, four Serra Angels of ours on the table
##          wizard  (bar 5.0) -> 'responded with Counterspell'
##          sorcerer(bar 5.5) -> ''
##     b) Fireball for 8 at our face, we are at 8 life   -> ''
##     c) Time Walk                                      -> ''
##     d) Wheel of Fortune, our hand 7 and theirs 0      -> ''
##     e) Serra Angel, a Swords to Plowshares in hand    -> 'Counterspell'
##
## A cost reading is the wrong instrument at both ends. The four spells
## that decide a game print almost nothing, so a Sorcerer watched its whole
## board go to a five-mana sorcery and every rung died to a Fireball it
## held the answer to; and the ten-point Serra Angel ate the counter with a
## one-mana answer in hand and a Plains untapped.
##
## WHAT IT IS NOW. [method AiPlayer._counter_shape] answers ALWAYS, NEVER
## or "ask the bar" before the bar is asked. ALWAYS: a sweeper that clears
## more of ours than of theirs, damage at our face that is lethal or
## crosses the panic line, a draw that decks us, an extra turn, and a wheel
## while our hand is the fuller. NEVER: a card in hand that answers the
## spell later and
## cheaper, with the mana for it planned and not merely hoped for. Between
## them the threshold is exactly what it was.
##
## P2's SIXTH ALWAYS CLAUSE — the control-stealing aura — DID NOT
## REPRODUCE and was not built; the board that proves it is below.
##
## It COMPOSES with [member AiProfile.ranks_counters] rather than replacing
## it: this decides WHETHER a spell deserves a counter, that one decides
## WHICH counter answers it.
##
## Every behaviour below is pinned with the knob ON and with it OFF, and
## the OFF arm is the pilot as it shipped.


func _ai(profile: AiProfile, seat := 1) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.counters_by_shape = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.counters_by_shape = false
	return profile


## Seat 1 is the counter-holding pilot: [param islands] untapped Islands
## and one Counterspell in hand.
func _pilot(islands := 8) -> void:
	for _i in islands:
		put_battlefield(1, "Island")
	give_hand(1, "Counterspell")


## Seat 0 casts [param card_name] for [param x], at [param targets].
func _they_cast(card_name: String, x := 0, targets: Array = []) -> CardInstance:
	var spell := give_hand(0, card_name)
	advance_to_step(Mtg.Step.MAIN1)
	var cost := spell.data.cost_for(x)
	for colour in cost.colored:
		add_mana(0, int(colour), int(cost.colored[colour]))
	if cost.generic > 0:
		add_mana(0, Mtg.ManaColor.C, cost.generic)
	if x > 0 and spell.data.x_color == 0:
		add_mana(0, Mtg.ManaColor.C, x * maxi(cost.x_count, 1))
	assert_ok(g.cast_spell(0, spell, targets, x))
	assert_ok(g.pass_priority(0))
	return spell


# ---------------------------------------------------------- the sweeper --

func test_the_wrath_that_clears_our_board_is_always_countered() -> void:
	# The Sorcerer's bar is 5.5 and Wrath of God prints 5.00, so the whole
	# board went — the reproduction, and the fix, on one profile.
	for on in [true, false]:
		before_each()
		var profile := AiProfile.sorcerer()
		profile.counters_by_shape = on
		var ai := _ai(profile)
		_pilot()
		for _i in 4:
			put_battlefield(1, "Serra Angel")
		_they_cast("Wrath of God")
		if on:
			assert_string_contains(ai._try_counter(g), "Counterspell",
				"four Serra Angels are worth more than any bar")
		else:
			assert_eq(ai._try_counter(g), "",
				"the null lets a 5.00 sorcery through a 5.5 bar")


func test_a_sweeper_that_costs_them_more_than_us_is_left_alone() -> void:
	# The clause is not "a sweeper": it is a sweeper that clears OUR board.
	# One Grizzly Bears of ours against four Serra Angels of theirs is
	# their mistake, and the Counterspell stays in hand for it.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		_pilot()
		put_battlefield(1, "Grizzly Bears")
		for _i in 4:
			put_battlefield(0, "Serra Angel")
		_they_cast("Wrath of God")
		assert_string_contains(ai._try_counter(g), "Counterspell",
			"Wrath of God clears the Wizard's own 5.0 bar either way")
		assert_eq(ai._counter_shape(g, g.stack.back()), AiPlayer.SHAPE_BAR,
			"but the SHAPE reading says nothing about it")


# ----------------------------------------------------- the burn at our face --

func test_a_lethal_fireball_at_our_face_is_always_countered() -> void:
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		_pilot()
		g.players[1].life = 8
		for _i in 9:
			put_battlefield(0, "Mountain")
		_they_cast("Fireball", 8, [TargetRef.player(1)])
		if on:
			assert_string_contains(ai._try_counter(g), "Counterspell",
				"eight damage at eight life is the game")
		else:
			assert_eq(ai._try_counter(g), "",
				"the null prices Fireball at 2.50 and passes")


func test_burn_that_crosses_the_panic_line_is_always_countered() -> void:
	# Not lethal, but it puts a Wizard (chump_threshold 6, aggression 0.5)
	# on its own panic line — the same reading the prevention window makes
	# of a waiting packet one step later.
	var ai := _ai(_on())
	_pilot()
	g.players[1].life = 9
	for _i in 5:
		put_battlefield(0, "Mountain")
	_they_cast("Fireball", 4, [TargetRef.player(1)])
	assert_string_contains(ai._try_counter(g), "Counterspell")


func test_burn_we_can_afford_is_left_to_the_bar() -> void:
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		_pilot()
		for _i in 5:
			put_battlefield(0, "Mountain")
		_they_cast("Fireball", 4, [TargetRef.player(1)])
		assert_eq(ai._try_counter(g), "",
			"four damage at twenty life is not worth a card, either arm")


func test_burn_at_their_own_face_is_not_our_business() -> void:
	var ai := _ai(_on())
	_pilot()
	g.players[0].life = 3
	for _i in 5:
		put_battlefield(0, "Mountain")
	_they_cast("Fireball", 3, [TargetRef.player(0)])
	assert_eq(ai._counter_shape(g, g.stack.back()), AiPlayer.SHAPE_BAR)


# ------------------------------------------------------- the extra turn --

func test_an_extra_turn_is_always_countered() -> void:
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		_pilot()
		_they_cast("Time Walk")
		if on:
			assert_string_contains(ai._try_counter(g), "Counterspell",
				"a turn is an untap, a draw, a land drop and an attack")
		else:
			assert_eq(ai._try_counter(g), "",
				"the null prices Time Walk at 3.00 and passes")


# ------------------------------------------------------------- the wheel --

func test_a_wheel_into_our_full_hand_is_always_countered() -> void:
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		_pilot()
		for _i in 6:
			give_hand(1, "Serra Angel")
		_they_cast("Wheel of Fortune")
		if on:
			assert_string_contains(ai._try_counter(g), "Counterspell",
				"seven cards of ours for seven of theirs, and they hold none")
		else:
			assert_eq(ai._try_counter(g), "",
				"the null prices Wheel of Fortune at 4.00 and passes")


func test_a_wheel_into_our_empty_hand_is_a_gift_and_is_left_alone() -> void:
	# The arithmetic is `their hand - our hand`, so with nothing but the
	# counter in ours the refill is THEIRS to regret.
	var ai := _ai(_on())
	_pilot()
	for _i in 4:
		give_hand(0, "Serra Angel")
	_they_cast("Wheel of Fortune")
	assert_eq(ai._counter_shape(g, g.stack.back()), AiPlayer.SHAPE_BAR)


func test_a_reroll_nets_nobody_anything_and_is_not_a_clause() -> void:
	# Winds of Change gives each player back exactly what it took.
	var ai := _ai(_on())
	_pilot()
	for _i in 6:
		give_hand(1, "Serra Angel")
	_they_cast("Winds of Change")
	assert_eq(ai._counter_shape(g, g.stack.back()), AiPlayer.SHAPE_BAR)


# ----------------------------------------------------- the draw that decks us --

func test_a_braingeyser_that_empties_our_library_is_always_countered() -> void:
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		_pilot()
		g.players[1].library.resize(4)
		for _i in 9:
			put_battlefield(0, "Island")
		_they_cast("Braingeyser", 6, [TargetRef.player(1)])
		if on:
			assert_string_contains(ai._try_counter(g), "Counterspell",
				"they win at our next draw step, CR 704.5b")
		else:
			assert_eq(ai._try_counter(g), "",
				"the null prices Braingeyser at 3.00 and passes")


func test_a_draw_our_library_survives_is_left_to_the_bar() -> void:
	var ai := _ai(_on())
	_pilot()
	for _i in 9:
		put_battlefield(0, "Island")
	_they_cast("Braingeyser", 6, [TargetRef.player(1)])
	assert_eq(ai._counter_shape(g, g.stack.back()), AiPlayer.SHAPE_BAR,
		"thirty cards, and six of them is a gift of six cards to us")


# ------------------------------------------- the steal that was ALREADY read --

func test_the_steal_needs_no_clause_of_its_own() -> void:
	# P2's sixth ALWAYS clause, measured against the tree and NOT BUILT.
	# Control Magic prices at 5.00 and a Sorcerer's bar is 5.5 — but
	# [method AiPlayer._try_counter] raises the threat to the worth of any
	# card of OURS the top spell TARGETS, a line written for the
	# counter-war, and a Control Magic names our Serra Angel. So the Angel's
	# 10.00 is the number the bar is asked, on BOTH arms, and a second copy
	# of the reading would fire only where the bar itself refuses. Pinned
	# here so nobody builds it twice.
	for on in [true, false]:
		before_each()
		var profile := AiProfile.sorcerer()
		profile.counters_by_shape = on
		var ai := _ai(profile)
		_pilot()
		var angel := put_battlefield(1, "Serra Angel")
		_they_cast("Control Magic", 0, [TargetRef.card(angel)])
		assert_string_contains(ai._try_counter(g), "Counterspell",
			"the target's own worth was already the threat")
		assert_eq(ai._counter_shape(g, g.stack.back()), AiPlayer.SHAPE_BAR,
			"and the shape reading says nothing about it")


# ------------------------------------------------------- Weissman's rule --

func test_the_counter_is_kept_when_the_hand_answers_the_creature() -> void:
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		_pilot()
		put_battlefield(1, "Plains")
		give_hand(1, "Swords to Plowshares")
		_they_cast("Serra Angel")
		if on:
			assert_eq(ai._try_counter(g), "",
				"one white mana answers it later; the counter is for what "
				+ "nothing else in hand can touch")
		else:
			assert_string_contains(ai._try_counter(g), "Counterspell",
				"the null spends the counter on a spell it holds the answer to")


func test_the_answer_with_no_mana_for_it_is_no_answer() -> void:
	# THE RISK THE NOTE NAMED: a Terror in hand and not one Swamp on the
	# table is a card, not an answer.
	var ai := _ai(_on())
	_pilot()
	give_hand(1, "Terror")
	_they_cast("Serra Angel")
	assert_string_contains(ai._try_counter(g), "Counterspell",
		"no black source: the counter is the only answer there is")


func test_the_answer_a_protection_blanks_is_no_answer() -> void:
	# Terror cannot touch a black creature; the reading is the printed
	# filter put to the card on the stack.
	var ai := _ai(_on())
	_pilot()
	for _i in 2:
		put_battlefield(1, "Swamp")
	give_hand(1, "Terror")
	_they_cast("Frozen Shade")
	assert_eq(ai._counter_shape(g, g.stack.back()), AiPlayer.SHAPE_BAR,
		"a nonblack-only removal is no answer to a black creature")


func test_an_answer_dearer_than_the_counter_is_not_taken() -> void:
	# The rule is "later AND CHEAPER". A four-mana removal spell in hand is
	# not a reason to let a Serra Angel resolve.
	var ai := _ai(_on())
	_pilot()
	for _i in 4:
		put_battlefield(1, "Swamp")
	give_hand(1, "Royal Assassin")
	_they_cast("Serra Angel")
	assert_string_contains(ai._try_counter(g), "Counterspell")


func test_the_last_card_in_hand_is_always_cast() -> void:
	# The discipline becomes a loss the moment the counter is all we have.
	var ai := _ai(_on())
	for _i in 8:
		put_battlefield(1, "Island")
	put_battlefield(1, "Plains")
	give_hand(1, "Counterspell")
	_they_cast("Serra Angel")
	assert_eq(g.players[1].hand.size(), 1)
	assert_string_contains(ai._try_counter(g), "Counterspell")


func test_a_sorcery_can_never_be_answered_later() -> void:
	# Nothing is left on the table to point a Swords at.
	var ai := _ai(_on())
	_pilot()
	put_battlefield(1, "Plains")
	give_hand(1, "Swords to Plowshares")
	for _i in 4:
		put_battlefield(1, "Serra Angel")
	_they_cast("Wrath of God")
	assert_string_contains(ai._try_counter(g), "Counterspell")


func test_never_never_beats_always() -> void:
	# A lethal Fireball with a Swords to Plowshares in hand is still a
	# lethal Fireball: ALWAYS is asked first and NEVER is never reached.
	var ai := _ai(_on())
	_pilot()
	put_battlefield(1, "Plains")
	give_hand(1, "Swords to Plowshares")
	g.players[1].life = 8
	for _i in 9:
		put_battlefield(0, "Mountain")
	_they_cast("Fireball", 8, [TargetRef.player(1)])
	assert_eq(ai._counter_shape(g, g.stack.back()), AiPlayer.SHAPE_ALWAYS)
	assert_string_contains(ai._try_counter(g), "Counterspell")


# ------------------------------------------------------ the composition --

func test_the_ranking_still_picks_which_counter_answers() -> void:
	# [member AiProfile.ranks_counters] decides WHICH; this knob decides
	# WHETHER. Against a tapped-out caster the Power Sink is the card that
	# stops a Time Walk for two, and the Mana Drain stays in hand.
	var ai := _ai(_on())
	for _i in 8:
		put_battlefield(1, "Island")
	give_hand(1, "Mana Drain")
	give_hand(1, "Power Sink")
	_they_cast("Time Walk")
	assert_string_contains(ai._try_counter(g), "Power Sink")


func test_the_counter_war_reading_is_untouched() -> void:
	# An opposing counterspell aimed at OUR spell is priced by the prize,
	# and that reading predates this knob and is unchanged on both arms.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		_pilot()
		put_battlefield(1, "Plains")
		var ours := give_hand(1, "Serra Angel")
		advance_to_next_turn()          # seat 1's own main phase
		advance_to_step(Mtg.Step.MAIN1)
		add_mana(1, Mtg.ManaColor.W, 2)
		add_mana(1, Mtg.ManaColor.C, 3)
		assert_ok(g.cast_spell(1, ours, []))
		assert_ok(g.pass_priority(1))
		var theirs := give_hand(0, "Counterspell")
		add_mana(0, Mtg.ManaColor.U, 2)
		assert_ok(g.cast_spell(0, theirs, [TargetRef.card(ours)]))
		assert_ok(g.pass_priority(0))
		assert_string_contains(ai._try_counter(g), "Counterspell",
			"the prize is a Serra Angel, on both arms")
