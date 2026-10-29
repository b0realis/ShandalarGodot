extends GameTest
## THE BUG CAMPAIGN OF 0.50.65, F5 — four slips of the computer the hunt
## (k5) reproduced after the polish pass, each held here:
##
##  k5-2 A CLONE WITH NO SHAPE THAT LIVES — Clone, Vesuvan Doppelganger and
##       Copy Artifact were cast with nothing to copy, or only legends the
##       1997 rule buries the copy of; the arrival (rightly) declined them,
##       so the card entered as printed and died, or stayed a blank
##       enchantment (`AiPlayer._copy_shape_missing`).
##  k5-3 SYLVAN LIBRARY, THEN A WHEEL, COUNTED ONE CARD SHORT — the hand the
##       wheel was promised with left out the turn's normal draw too, so
##       both cards went back for a Wheel of Fortune whose swing then read
##       0 (`AiPlayer._keep_price_moves`).
##  k5-4 WINDS OF CHANGE IS NO SUCH WHEEL — it deals back exactly what each
##       hand held, so a card put back is lost to it.
##  k5-5 HERMIT DRUID AND THE PUBLIC PLACES — a basic in the ante or phased
##       out was read as still in the library (`TempestTactics.basics_left`).
##
## Fair information only (docs/fair-play.md): the battlefield, our own hand
## and list, the ante and the phased-out permanents are all public or ours;
## the face of a face-down permanent never moves the Clone's decision.


const TEMPEST_TACTICS := preload("res://engine/ai/tempest_tactics.gd")
const LEGEND := "Sir Shandlar of Eberyn"


func _ai(seat := 0) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


func after_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


## Seat 0's first main phase played out by [param ai]: what it did.
func _main(ai: AiPlayer, n := 6) -> Array[String]:
	advance_to_step(Mtg.Step.MAIN1)
	var out: Array[String] = []
	for _i in n:
		var said := ai.act(g)
		out.append(said)
		if said == "pass":
			break
		resolve_stack()
	return out


# =================================================== k5-2 the copy cards --

func test_a_clone_is_not_cast_with_only_a_legend_to_copy() -> void:
	var ai := _ai()
	for _i in 4: put_battlefield(0, "Island")
	put_battlefield(1, LEGEND)
	var clone := give_hand(0, "Clone")
	var acts := _main(ai)
	assert_false(acts.has("cast Clone"), "the only shape buries the copy: %s" % [acts])
	assert_eq(clone.zone, Mtg.Zone.HAND)


func test_a_clone_is_not_cast_onto_an_empty_board() -> void:
	var ai := _ai()
	for _i in 4: put_battlefield(0, "Island")
	var clone := give_hand(0, "Clone")
	var acts := _main(ai)
	assert_false(acts.has("cast Clone"), "nothing to copy: a 0/0: %s" % [acts])
	assert_eq(clone.zone, Mtg.Zone.HAND)


func test_a_doppelganger_is_not_cast_with_only_our_own_legend_in_play() -> void:
	# The Lab's pair2_seed50: its own Princess Lucrezia the only creature.
	var ai := _ai()
	for _i in 5: put_battlefield(0, "Island")
	put_battlefield(0, "Princess Lucrezia")
	var dop := give_hand(0, "Vesuvan Doppelganger")
	var acts := _main(ai)
	assert_false(acts.has("cast Vesuvan Doppelganger"), "%s" % [acts])
	assert_eq(dop.zone, Mtg.Zone.HAND)


func test_copy_artifact_is_not_cast_with_no_artifact_in_play() -> void:
	var ai := _ai()
	for _i in 4: put_battlefield(0, "Island")
	put_battlefield(1, "Grizzly Bears")
	var copy := give_hand(0, "Copy Artifact")
	var acts := _main(ai)
	assert_false(acts.has("cast Copy Artifact"), "a blank enchantment: %s" % [acts])
	assert_eq(copy.zone, Mtg.Zone.HAND)


func test_an_artifact_in_play_is_a_shape_for_copy_artifact() -> void:
	var ai := _ai()
	var copy := give_hand(0, "Copy Artifact")
	assert_true(ai._copy_shape_missing(g, copy))
	put_battlefield(1, "Jayemdae Tome")
	assert_false(ai._copy_shape_missing(g, copy))
	assert_false(ai._copy_shape_missing(g, give_hand(0, "Grizzly Bears")),
		"a card that enters as itself is never refused here")


func test_a_clone_is_still_cast_when_a_shape_lives() -> void:
	var ai := _ai()
	for _i in 4: put_battlefield(0, "Island")
	put_battlefield(1, LEGEND)
	put_battlefield(1, "Hill Giant")
	var clone := give_hand(0, "Clone")
	var acts := _main(ai)
	assert_true(acts.has("cast Clone"), "%s" % [acts])
	assert_eq(clone.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(clone.data.card_name, "Hill Giant", "the shape that lives, not the legend")


func test_a_face_down_creature_is_a_shape_whatever_it_hides() -> void:
	# A face-down permanent copies as a nameless 2/2 (CR 707.2): what it
	# hides — a legend or not — must not move the cast (rule 8).
	var answers: Array = []
	for hidden in [LEGEND, "Hill Giant"]:
		before_each()
		var ai := _ai()
		for _i in 4: put_battlefield(0, "Island")
		g.turn_face_down(put_battlefield(1, hidden))
		var clone := give_hand(0, "Clone")
		answers.append([ai._copy_shape_missing(g, clone), _main(ai).has("cast Clone")])
	assert_eq(answers[0], answers[1])
	assert_eq(answers[0], [false, true], "a face-down 2/2 is a shape that lives")


# ===================================== k5-3 / k5-4 the Library and a wheel --

## Sylvan Library and three Mountains on seat 0's table from its first main
## phase on, [param hand] in its hand, [param theirs] cards in the other
## seat's (one more by our next turn: their own draw), and three spells on
## top of our library — the turn's draw and the Library's two, no land
## among them.
func _library_draw(hand: Array, theirs: int) -> AiPlayer:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Sylvan Library")
	for _i in 3: put_battlefield(0, "Mountain")
	for n in hand: give_hand(0, n)
	for _i in theirs: give_hand(1, "Grizzly Bears")
	for _i in 3:
		var spell := _make_instance(0, "Grizzly Bears")
		spell.zone = Mtg.Zone.LIBRARY
		g.players[0].library.append(spell)
	return ai


## On to seat 0's next turn: the Library asks and resolves in its draw step.
func _through_our_draw_step() -> void:
	advance_to_next_turn()
	advance_to_next_turn()
	resolve_stack()


func test_the_library_pays_when_the_wheel_would_move_nothing() -> void:
	# k5's repro: their hand at two, ours Wheel, Gray Ogre and the three
	# drawn cards. Both put back, our hand at the cast is three, the wheel's
	# swing 2 - 2 = 0 and the cast refuses it — so the life is worth paying.
	var ai := _library_draw(["Wheel of Fortune", "Gray Ogre"], 1)
	var life := g.players[0].life
	_through_our_draw_step()
	assert_eq(g.players[1].hand.size(), 2)
	assert_eq(g.players[0].life, life - 8, "no wheel this turn: both cards kept at 4 life")
	assert_eq(g.players[0].hand.size(), 5)
	assert_false(_main(ai).has("cast Wheel of Fortune"))


func test_the_library_still_puts_back_for_a_wheel_it_casts() -> void:
	# The control: their hand at three, the swing after the put-back is 1,
	# and the wheel is cast in the same main phase.
	var ai := _library_draw(["Wheel of Fortune", "Gray Ogre"], 2)
	var life := g.players[0].life
	_through_our_draw_step()
	assert_eq(g.players[0].life, life, "both cards put back")
	assert_true(_main(ai).has("cast Wheel of Fortune"), "and the wheel is cast")


func test_winds_of_change_is_not_a_wheel_the_library_puts_back_for() -> void:
	# Winds of Change deals each hand back exactly what it held: a card put
	# back is one card fewer, not the first of seven.
	_library_draw(["Winds of Change"], 4)
	var life := g.players[0].life
	_through_our_draw_step()
	assert_eq(g.players[0].life, life - 8, "both cards kept at 4 life")


# ======================================== k5-5 Hermit Druid's basics left --

func _druid_board() -> AiPlayer:
	CardPacks.set_enabled("pack-9", true)
	var ai := _ai()
	put_battlefield(0, "Hermit Druid")
	put_battlefield(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	return ai


## Seat 0's library and registered list replaced by [param names] (the list
## also names [param also], the cards of ours already elsewhere).
func _library(names: Array, also: Array) -> void:
	for inst in g.players[0].library:
		g._instances.erase(inst.id)
	g.players[0].library.clear()
	g.players[0].deck_names.clear()
	for n in names:
		var inst := _make_instance(0, n)
		inst.zone = Mtg.Zone.LIBRARY
		g.players[0].library.append(inst)
		g.players[0].deck_names.append(n)
	for n in also:
		g.players[0].deck_names.append(n)


func _spells(n: int) -> Array:
	var out: Array = []
	for _i in n: out.append("Grizzly Bears")
	return out


func test_a_basic_in_the_ante_is_not_counted_in_the_library() -> void:
	var ai := _druid_board()
	_library(_spells(29) + ["Forest", "Forest"], ["Forest", "Hermit Druid"])
	assert_eq(g.stake_named_ante(0, ["Forest"]).size(), 1)
	assert_eq(TEMPEST_TACTICS.basics_left(g, 0), 1, "one Forest left in thirty")
	assert_ne(ai.act(g), "activated Hermit Druid",
		"one basic in thirty: half the library on average")
	assert_eq(g.players[0].library.size(), 30)


func test_two_anted_basics_leave_the_druid_nothing_to_find() -> void:
	# The Lab's `--ante 2`: no basic left in the library, the reveal would
	# put every card of it into the graveyard.
	var ai := _druid_board()
	_library(_spells(30) + ["Forest", "Forest"], ["Forest", "Hermit Druid"])
	assert_eq(g.stake_named_ante(0, ["Forest", "Forest"]).size(), 2)
	assert_eq(TEMPEST_TACTICS.basics_left(g, 0), 0)
	assert_ne(ai.act(g), "activated Hermit Druid")
	assert_eq(g.players[0].library.size(), 30)


func test_a_phased_out_basic_is_not_counted_in_the_library() -> void:
	var ai := _druid_board()
	_library(_spells(30), ["Forest", "Forest", "Forest", "Hermit Druid"])
	for _i in 2:
		assert_true(g.phase_out(put_battlefield(0, "Forest")))
	assert_eq(TEMPEST_TACTICS.basics_left(g, 0), 0, "both are phased out, not in the library")
	assert_ne(ai.act(g), "activated Hermit Druid")
	assert_eq(g.players[0].library.size(), 30)


func test_the_druid_still_digs_past_an_ante_when_basics_remain() -> void:
	var ai := _druid_board()
	_library(_spells(14) + ["Forest", "Forest", "Forest", "Forest", "Forest", "Forest", "Forest"],
		["Forest", "Hermit Druid"])
	g.stake_named_ante(0, ["Forest"])
	assert_eq(TEMPEST_TACTICS.basics_left(g, 0), 6)
	assert_eq(ai.act(g), "activated Hermit Druid")
