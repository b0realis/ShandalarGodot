extends GameTest
## THE AI SLIPS SEEN IN PLAY (the polish pass, 2026-10-28; ledger duel-047,
## docs/whole-project-review-2026-10-21.md "The computer opponent" and
## docs/hunt-campaign-2026-10-21.md "Suspected — the computer"). Each is
## reproduced on a test hand first, then held:
##
##  1. SYLVAN LIBRARY, THEN WHEEL OF FORTUNE — it paid 4 life to keep a
##     card and then cast Wheel of Fortune in the same main phase,
##     discarding it. A card the wheel will throw away is put back: the
##     wheel's seven draw it again.
##  2. A SECOND ASHNOD'S ALTAR WITH COMBOS OFF — the Wizard cast a second,
##     useless Altar ahead of a Hill Giant.
##  3. HERMIT DRUID MILLING ITSELF — with no basic land left in the library
##     the Druid reveals the whole library into the graveyard.
##  4. MANA FLARE BURN — both pilots burned 1–2 life most turns. Measured
##     (twelve Wizard duels under a standing Flare, 29 burns): every burn
##     was the mana an odd cost leaves when each land makes two, on a board
##     with no other source to round it off; where one exists the planner
##     already uses it (the pins below). No slip of the pilot's — the AI
##     package may teach it to spend such a mana.
##
## Fair information only (docs/fair-play.md): the pilot's own registered
## list (`deck_names`), its own hand and the public zones; the hidden
## library ORDER is never read, and the substitution tests below move it
## without moving a decision.


func _ai(seat := 0, combos := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.plays_combos = combos
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


func _lands(name: String, n: int, seat := 0) -> void:
	for _i in n: put_battlefield(seat, name)


## Seat [param pid]'s library and registered list replaced by [param names]
## (the list also names [param also], the cards of ours already elsewhere).
func _library(pid: int, names: Array, also: Array = []) -> void:
	for inst in g.players[pid].library:
		g._instances.erase(inst.id)
	g.players[pid].library.clear()
	g.players[pid].deck_names.clear()
	for n in names:
		var inst := _make_instance(pid, n)
		inst.zone = Mtg.Zone.LIBRARY
		g.players[pid].library.append(inst)
		g.players[pid].deck_names.append(n)
	for n in also:
		g.players[pid].deck_names.append(n)


# ======================================================= 3. Hermit Druid --

func _druid_board() -> AiPlayer:
	CardPacks.set_enabled("pack-9", true)
	var ai := _ai()
	put_battlefield(0, "Hermit Druid")
	_lands("Forest", 1)
	advance_to_step(Mtg.Step.MAIN1)
	return ai


func after_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func test_hermit_druid_never_digs_a_library_with_no_basic_land_left() -> void:
	var ai := _druid_board()
	var spells: Array = []
	for _i in 20: spells.append("Grizzly Bears")
	# The list's only basic is the Forest on the table: the library holds none.
	_library(0, spells, ["Forest", "Hermit Druid"])
	assert_ne(ai.act(g), "activated Hermit Druid",
		"the reveal would put all twenty cards into the graveyard")
	assert_eq(g.players[0].library.size(), 20)


func test_hermit_druid_still_digs_when_basics_remain() -> void:
	var ai := _druid_board()
	var cards: Array = []
	for _i in 14: cards.append("Grizzly Bears")
	for _i in 6: cards.append("Forest")
	_library(0, cards, ["Forest", "Hermit Druid"])
	assert_eq(ai.act(g), "activated Hermit Druid")


func test_hermit_druid_waits_when_one_basic_would_cost_half_the_library() -> void:
	var ai := _druid_board()
	var cards: Array = []
	for _i in 29: cards.append("Grizzly Bears")
	cards.append("Forest")
	_library(0, cards, ["Forest", "Hermit Druid"])
	assert_ne(ai.act(g), "activated Hermit Druid",
		"one basic in thirty: half the library on average")


func test_the_druids_reading_never_looks_at_the_library_order() -> void:
	# Same list, same zones, the one basic moved from the bottom to the top:
	# the decision cannot move (the order is hidden).
	var answers: Array[String] = []
	for top in [false, true]:
		before_each()
		var ai := _druid_board()
		var cards: Array = []
		for _i in 29: cards.append("Grizzly Bears")
		if top: cards.append("Forest")
		else: cards.push_front("Forest")
		_library(0, cards, ["Forest", "Hermit Druid"])
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1])


# =========================================== 2. a second Ashnod's Altar --

## The board the probe found (tests/_hunt/P5): a Grizzly Bears and three
## Mountains beside the first Altar, the Hill Giant one mana short without
## the Bears — the Wizard cast the second Altar, combos on or off.
func test_with_combos_off_a_second_altar_does_not_go_ahead_of_a_creature() -> void:
	for combos in [false, true]:
		before_each()
		var ai := _ai(0, combos)
		put_battlefield(0, "Ashnod's Altar")
		put_battlefield(0, "Grizzly Bears")
		_lands("Mountain", 3)
		var second := give_hand(0, "Ashnod's Altar")
		give_hand(0, "Hill Giant")
		advance_to_step(Mtg.Step.MAIN1)
		for _i in 3:
			if ai.act(g) == "pass":
				break
			resolve_stack()
		assert_eq(second.zone, Mtg.Zone.HAND,
			"a second Altar sacrifices nothing the first cannot (combos %s)" % combos)


func test_a_second_altar_is_not_cast_into_spare_mana_either() -> void:
	var ai := _ai(0, false)
	put_battlefield(0, "Ashnod's Altar")
	_lands("Mountain", 7)
	var second := give_hand(0, "Ashnod's Altar")
	var giant := give_hand(0, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	for _i in 4:
		if ai.act(g) == "pass":
			break
		resolve_stack()
	assert_ne(giant.zone, Mtg.Zone.HAND, "the Hill Giant is cast")
	assert_eq(second.zone, Mtg.Zone.HAND, "and the Altar is not cast after it")


func test_a_first_altar_is_still_a_card_worth_casting() -> void:
	var ai := _ai(0, false)
	_lands("Mountain", 3)
	give_hand(0, "Ashnod's Altar")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "cast Ashnod's Altar")


# ================================== 1. Sylvan Library, then Wheel of Fortune --

## Sylvan Library on seat 0's table from its first main phase on (so the
## turn-1 draw step asks nothing), [param hand] in its hand and
## [param theirs] cards in the other seat's.
func _library_draw(hand: Array, lands := 3, theirs := 5) -> AiPlayer:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Sylvan Library")
	_lands("Mountain", lands)
	for n in hand: give_hand(0, n)
	for _i in theirs: give_hand(1, "Grizzly Bears")
	return ai


## On to seat 0's next turn: the Library's trigger asks and resolves in
## its draw step.
func _through_our_draw_step() -> void:
	advance_to_next_turn()
	advance_to_next_turn()
	resolve_stack()


func test_the_library_puts_back_what_a_wheel_this_turn_would_discard() -> void:
	_library_draw(["Wheel of Fortune"])
	var life := g.players[0].life
	_through_our_draw_step()
	assert_eq(g.players[0].life, life, "no life paid for cards the wheel throws away")


func test_the_library_still_pays_with_no_wheel_in_hand() -> void:
	_library_draw(["Hill Giant"])
	var life := g.players[0].life
	_through_our_draw_step()
	assert_eq(g.players[0].life, life - 8, "two cards kept at four life each")


func test_a_wheel_it_cannot_cast_this_turn_changes_nothing() -> void:
	_library_draw(["Wheel of Fortune"], 1)
	var life := g.players[0].life
	_through_our_draw_step()
	assert_eq(g.players[0].life, life - 8, "one land: the wheel waits")


func test_a_wheel_the_pilot_would_not_cast_changes_nothing() -> void:
	# Our hand the fuller even with the two cards put back, theirs empty:
	# the Wizard does not wheel cards over to the other seat (a swing
	# against us), so the Library's cards are worth their life as before.
	_library_draw(["Wheel of Fortune", "Hill Giant", "Gray Ogre", "Craw Wurm", "Shatter"], 3, 0)
	var life := g.players[0].life
	_through_our_draw_step()
	assert_eq(g.players[0].life, life - 8)


func test_the_put_back_never_reads_the_library_order() -> void:
	# The cards under the two drawn ones moved: the answer cannot move.
	var lives: Array[int] = []
	for flip in [false, true]:
		before_each()
		_library_draw(["Wheel of Fortune"])
		if flip:
			g.players[0].library.reverse()
		var life := g.players[0].life
		_through_our_draw_step()
		lives.append(life - g.players[0].life)
	assert_eq(lives[0], lives[1])


func test_a_wheel_drawn_this_turn_is_never_the_card_put_back() -> void:
	# The Library offers the cards drawn this turn, and a wheel among them
	# may be the card the price is asked about: it is paid for, not put
	# back to "save" the life (the probe's seed 511: the Wizard put its own
	# Wheel of Fortune back on top and cast a Hill Giant).
	var ai := _library_draw(["Hill Giant"])
	g.players[0].library.append(_make_instance(0, "Wheel of Fortune"))
	g.players[0].library.back().zone = Mtg.Zone.LIBRARY
	_through_our_draw_step()
	var wheel_in_hand := false
	for card in g.players[0].hand:
		wheel_in_hand = wheel_in_hand or card.data.card_name == "Wheel of Fortune"
	assert_true(wheel_in_hand, "the wheel drawn this turn stays in hand")
	assert_not_null(ai)


# ============================================================ 4. Mana Flare --

## Seat 0 casts [param card_name] from [param table] under the other seat's
## Mana Flare; the mana left floating after the cast.
func _flare_float(table: Array, card_name: String) -> int:
	var ai := _ai()
	put_battlefield(1, "Mana Flare")
	for n in table: put_battlefield(0, n)
	give_hand(0, card_name)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "cast %s" % card_name)
	resolve_stack()
	return g.players[0].mana_pool.total()


func test_under_a_flare_an_odd_cost_is_rounded_off_by_a_mox() -> void:
	assert_eq(_flare_float(["Mountain", "Mountain", "Mountain", "Mox Ruby"], "Wall of Stone"), 0,
		"one Mountain (two red) and the Mox: three, nothing over")


func test_under_a_flare_lands_alone_leave_the_odd_mana() -> void:
	assert_eq(_flare_float(["Mountain", "Mountain", "Mountain"], "Wall of Stone"), 1,
		"two Mountains make four: the one over is arithmetic, not a slip")


func test_a_wheel_with_no_red_source_changes_nothing() -> void:
	# Three Forests: the Wheel of Fortune cannot be cast this turn, so the
	# Library's cards are paid for as before.
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Sylvan Library")
	_lands("Forest", 3)
	give_hand(0, "Wheel of Fortune")
	for _i in 5: give_hand(1, "Grizzly Bears")
	var life := g.players[0].life
	_through_our_draw_step()
	assert_eq(g.players[0].life, life - 8, "no red source: the wheel waits")
	assert_not_null(ai)
