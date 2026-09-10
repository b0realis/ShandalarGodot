extends GameTest
## THE SHELTER CAST AND THE TWIN (2026-09-10) — the two rows the third
## pass left open on [member AiProfile.trusts_abyss]
## (`docs/ai-difficulty.md` §5, `docs/AI-next-wave.md`), closed as an
## EXTENSION of that knob rather than a knob of their own.
##
## The knob's promise is one sentence: *the counter is kept because the
## feeder answers this creature*. Both faults are boards where the feeder
## does NOT answer it, and both were reproduced before a line was written.
##
##  * THE TWIN. `_is_next_meal(second Sengir Vampire) = true` with a
##    Sengir Vampire already on their table — so the counter was kept and
##    the feeder ate ONE of the two, leaving a Sengir Vampire standing.
##  * THE SHELTER CAST. The meal on the board as it stands is `Serra
##    Angel(10.0)`; a Mesa Pegasus resolves and it is `Mesa Pegasus(3.8)`.
##    The Angel we declined to counter walks away, and the Pegasus's own
##    printed worth of 3.8 is under the profile's bar of 5.0, so [method
##    AiPlayer._try_counter] returned before it ever asked about the
##    feeder.
##
## WHY IT IS THIS KNOB AND NOT ANOTHER. A second knob would mean a seat
## that keeps a counter on a promise a DIFFERENT knob is responsible for
## keeping — two rules for one sentence. Off, [method
## AiPlayer._try_counter] never consults the feeder at all and neither
## reading is reachable: the pilot prices every spell as printed, which is
## what the Deck Lab's null arm replays.


func _ai(profile: AiProfile, seat := 1) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.trusts_abyss = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.trusts_abyss = false
	return profile


## Seat 1 holds a Counterspell with {U}{U} open; seat 0 casts
## [param card_name] in its main phase and passes priority to seat 1.
func _they_cast(card_name: String) -> CardInstance:
	give_hand(1, "Counterspell")
	put_battlefield(1, "Island")
	put_battlefield(1, "Island")
	var spell := give_hand(0, card_name)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.B, 4)
	add_mana(0, Mtg.ManaColor.C, 6)
	assert_ok(g.cast_spell(0, spell, []))
	assert_ok(g.pass_priority(0))
	return spell


# --------------------------------------------------------------- the twin --

func test_a_second_copy_is_not_answered_by_the_feeder() -> void:
	var ai := _ai(_on())
	put_battlefield(1, "The Abyss")
	put_battlefield(0, "Sengir Vampire")
	var twin := _they_cast("Sengir Vampire")
	assert_string_contains(ai.act(g), "responded with Counterspell",
		"the feeder eats one a turn: a body of the same worth survives")
	resolve_stack()
	assert_eq(twin.zone, Mtg.Zone.GRAVEYARD)


func test_the_lone_copy_is_still_let_through() -> void:
	# The knob's own promise, unchanged: with nothing beside it the
	# newcomer IS the meal and the counter is kept.
	var ai := _ai(_on())
	put_battlefield(1, "The Abyss")
	var lone := _they_cast("Sengir Vampire")
	assert_eq(ai.act(g), "pass")
	assert_eq(g.players[1].hand.size(), 1, "Counterspell still in hand")
	resolve_stack()
	assert_eq(lone.zone, Mtg.Zone.BATTLEFIELD)


func test_off_the_twin_is_countered_for_the_ordinary_reason() -> void:
	var ai := _ai(_off())
	put_battlefield(1, "The Abyss")
	put_battlefield(0, "Sengir Vampire")
	var twin := _they_cast("Sengir Vampire")
	assert_string_contains(ai.act(g), "responded with Counterspell")
	resolve_stack()
	assert_eq(twin.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------- the shelter cast --

func test_the_one_drop_that_saves_the_angel_is_countered() -> void:
	var ai := _ai(_on())
	put_battlefield(1, "The Abyss")
	put_battlefield(0, "Serra Angel")
	var pegasus := _they_cast("Mesa Pegasus")
	assert_string_contains(ai.act(g), "responded with Counterspell",
		"a Mesa Pegasus that saves a Serra Angel is a Serra Angel")
	resolve_stack()
	assert_eq(pegasus.zone, Mtg.Zone.GRAVEYARD)


func test_off_the_one_drop_is_beneath_the_bar() -> void:
	# The null, and the reason the reading has to be read BEFORE the bar:
	# 3.8 against a Wizard's 5.0.
	var ai := _ai(_off())
	put_battlefield(1, "The Abyss")
	put_battlefield(0, "Serra Angel")
	var pegasus := _they_cast("Mesa Pegasus")
	assert_eq(ai.act(g), "pass")
	assert_eq(g.players[1].hand.size(), 1, "Counterspell still in hand")
	resolve_stack()
	assert_eq(pegasus.zone, Mtg.Zone.BATTLEFIELD)


func test_the_swing_is_what_the_displacement_buys_them() -> void:
	var ai := _ai(_on())
	put_battlefield(1, "The Abyss")
	var angel := put_battlefield(0, "Serra Angel")
	var pegasus := give_hand(0, "Mesa Pegasus")
	assert_almost_eq(ai._shelter_swing(g, pegasus, 0),
		Evaluator.permanent_value(angel) - Evaluator.permanent_value(pegasus),
		0.01, "the dear body lives and the cheap one dies in its place")


func test_a_one_drop_that_shelters_nothing_swings_nothing() -> void:
	var ai := _ai(_on())
	put_battlefield(1, "The Abyss")
	var pegasus := give_hand(0, "Mesa Pegasus")
	assert_almost_eq(ai._shelter_swing(g, pegasus, 0), 0.0, 0.01,
		"an empty board: it displaces nobody")
	put_battlefield(0, "Llanowar Elves")
	assert_almost_eq(ai._shelter_swing(g, pegasus, 0), 0.0, 0.01,
		"and a CHEAPER body of theirs is still the meal")


func test_a_body_the_feeder_cannot_eat_shelters_nothing() -> void:
	# White Knight has protection from black, so the Abyss cannot take it
	# in place of anything: the filter and the printed protection are read
	# off the spell exactly as [method AiPlayer._is_next_meal] reads them.
	var ai := _ai(_on())
	put_battlefield(1, "The Abyss")
	put_battlefield(0, "Serra Angel")
	var knight := give_hand(0, "White Knight")
	assert_almost_eq(ai._shelter_swing(g, knight, 0), 0.0, 0.01)
	var statue := give_hand(0, "Clay Statue")
	assert_almost_eq(ai._shelter_swing(g, statue, 0), 0.0, 0.01,
		"an artifact creature is outside the Abyss's own filter")


func test_without_a_feeder_there_is_no_shelter_to_read() -> void:
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		put_battlefield(0, "Serra Angel")
		var pegasus := give_hand(0, "Mesa Pegasus")
		assert_almost_eq(ai._shelter_swing(g, pegasus, 0), 0.0, 0.01)


func test_the_saved_counter_still_has_its_purpose() -> void:
	# The knob's own point, unmoved: the feeder cannot eat a Disenchant.
	var ai := _ai(_on())
	var abyss := put_battlefield(1, "The Abyss")
	give_hand(1, "Counterspell")
	put_battlefield(1, "Island")
	put_battlefield(1, "Island")
	var spell := give_hand(0, "Disenchant")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 1)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(abyss)]))
	assert_ok(g.pass_priority(0))
	assert_string_contains(ai.act(g), "responded with Counterspell")
	resolve_stack()
	assert_eq(abyss.zone, Mtg.Zone.BATTLEFIELD)
