extends GameTest
## THE WHEEL FIELD (2026-09-10, [member EffectIntent.wheels]; wave 2's
## first row, `docs/forge/casting.md` P5).
##
## A spell that empties EACH player's hand and refills it had no reading
## at all. Probed at HEAD, over the pool's own cards:
##
##     Wheel of Fortune   unknown=true draws=0 extra_turns=0 value=4.00
##     Timetwister        unknown=true draws=0 extra_turns=0 value=4.00
##     Winds of Change    unknown=true draws=0 extra_turns=0 value=2.50
##
## — three symmetric hand-refills read as nothing, priced by
## [method Evaluator.card_value] alone, with the seven cards they take off
## our side and the seven they hand the other invisible to every reader.
## [method EffectIntent._aimed_discard] refuses them on purpose (its
## "target player" prefix is what separates an aimed discard from a
## symmetric one), and until this field there was nowhere else for them to
## be read.
##
## It is a READER and not a knob: nothing here is gated, because a field
## that says what a card does is not a difficulty. Its first consumer is
## [member AiProfile.counters_by_shape], whose ALWAYS clause is pinned in
## `test_ai_counters_by_shape_2026_09_10.gd` on both arms.
##
## The count and not a flag, because the two shapes differ: a FIXED refill
## (seven) hands whoever has the emptier hand a pile of cards, while a
## REROLL gives each player back exactly what it took and nets nobody
## anything. A reader that answered seven for both would be wrong about
## the second.


func _read(card_name: String) -> EffectIntent:
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, "unknown card: %s" % card_name)
	return EffectIntent.read(data.spell_effects, card_name)


# ------------------------------------------------------- the three wheels --

func test_wheel_of_fortune_is_seven_cards_each() -> void:
	assert_eq(_read("Wheel of Fortune").wheels, 7,
		"each player discards their hand, then draws seven cards")


func test_timetwister_is_seven_cards_each() -> void:
	# The shuffle-in is a different route to the same hand: the field says
	# what each player ENDS UP holding, which is what the arithmetic wants.
	assert_eq(_read("Timetwister").wheels, 7)


func test_winds_of_change_is_a_reroll_and_not_a_refill() -> void:
	assert_eq(_read("Winds of Change").wheels, EffectIntent.WHEEL_REDRAW,
		"each player draws back exactly what it shuffled in")


# -------------------------------------------------- what is NOT a wheel --

func test_a_discard_that_never_refills_is_not_a_wheel() -> void:
	# Mind Bomb: "each player discards up to three cards or takes the
	# difference in damage". Symmetric, and no card comes back.
	assert_eq(_read("Mind Bomb").wheels, 0)


func test_a_hand_emptied_onto_the_battlefield_is_not_a_wheel() -> void:
	# Eureka empties each hand of PERMANENTS onto the table and draws
	# nothing at all.
	assert_eq(_read("Eureka").wheels, 0)


func test_an_aimed_discard_is_not_a_wheel() -> void:
	# The "target player" prefix is what separates the two readings, and
	# the aimed discard keeps its own.
	var mind_twist := _read("Mind Twist")
	assert_eq(mind_twist.wheels, 0)
	assert_eq(mind_twist.discards, -1, "and it is still an X discard")


func test_a_plain_draw_spell_is_not_a_wheel() -> void:
	assert_eq(_read("Braingeyser").wheels, 0)
	assert_eq(_read("Ancestral Recall").wheels, 0)


func test_the_whole_pool_holds_exactly_three_wheels() -> void:
	# A census rather than a list: the reading is off the effect's own
	# line, so a card that grows one is found here rather than in a duel.
	var found: Array[String] = []
	for card_name in CardRegistry.all_names():
		var data := CardRegistry.get_card(card_name)
		if data == null or data.spell_effects.is_empty():
			continue
		if EffectIntent.read(data.spell_effects, card_name).wheels != 0:
			found.append(card_name)
	found.sort()
	assert_eq(found, ["Timetwister", "Wheel of Fortune", "Winds of Change"],
		"the pool's three symmetric hand-refills, and nothing else")


# --------------------------------------------- the word `unknown` stays --

func test_unknown_stays_set_so_every_older_reading_is_unchanged() -> void:
	# Exactly the ruling [method EffectIntent._aimed_discard] makes: a row
	# in CARD_LOCAL would stop the effect being `unknown`, and the harm
	# reading and the target picker both gate on that word.
	for card_name in ["Wheel of Fortune", "Timetwister", "Winds of Change"]:
		var intent := _read(card_name)
		assert_true(intent.unknown, "%s is still unknown" % card_name)
		assert_true(intent.is_harmful(), "%s still reads removal-shaped"
			% card_name)
