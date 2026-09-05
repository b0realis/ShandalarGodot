extends GameTest
## The floating-effect DURATIONS beyond end of turn (CR 611.2b).
##
## `ContinuousEffects` used to know exactly two: end of turn and end of
## combat. The 1997 pool asks for two more, and both were ledgered as
## card-scoped simplifications until this file pinned them —
## "until your next upkeep" (Xenic Poltergeist, Erhnam Djinn) and no
## duration at all (Brine Hag's *"This effect lasts indefinitely."*).
##
## The engine half is pinned first, on a bare instance and a bare registry,
## then each card that pays for it.


# ---------------------------------------------------------------- the engine --

func test_an_indefinite_effect_survives_the_cleanup_step() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.continuous.add_until_eot_base_pt(bear.id, 0, 2, false,
		ContinuousEffects.Duration.INDEFINITE)
	g.recalculate()
	assert_eq(bear.cur_power, 0)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(bear.cur_power, 0, "an indefinite effect does not expire at cleanup")
	assert_eq(bear.cur_toughness, 2)


func test_an_ordinary_until_eot_effect_still_expires() -> void:
	# The control for the test above: the default duration is unchanged.
	var bear := put_battlefield(0, "Grizzly Bears")
	g.continuous.add_until_eot_base_pt(bear.id, 0, 2)
	g.recalculate()
	assert_eq(bear.cur_power, 0)
	advance_to_next_turn()
	assert_eq(bear.cur_power, 2, "end of turn is still end of turn")


func test_an_indefinite_effect_ends_when_its_object_leaves() -> void:
	# CR 400.7 — what comes back is a new object, and was never touched.
	var bear := put_battlefield(0, "Grizzly Bears")
	g.continuous.add_until_eot_base_pt(bear.id, 0, 2, false,
		ContinuousEffects.Duration.INDEFINITE)
	g.recalculate()
	assert_eq(bear.cur_power, 0)
	g.destroy(bear, false)
	g.check_state_based_actions()
	g._put_on_battlefield(bear, 0)
	g.recalculate()
	assert_eq(bear.cur_power, 2, "the effect did not follow the card back")


func test_until_your_next_upkeep_crosses_the_cleanup_step() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	g.continuous.add_until_eot_landwalk(bear.id, ["forest"], false,
		ContinuousEffects.Duration.UNTIL_UPKEEP_OF, 0)
	g.recalculate()
	assert_true(bear.cur_landwalk.has("forest"))
	advance_to_next_turn()   # player 1's turn — player 0's upkeep has not come
	assert_true(bear.cur_landwalk.has("forest"),
		"it must outlive the cleanup step, which is the whole point")


func test_until_your_next_upkeep_ends_at_that_players_upkeep() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	g.continuous.add_until_eot_landwalk(bear.id, ["forest"], false,
		ContinuousEffects.Duration.UNTIL_UPKEEP_OF, 0)
	g.recalculate()
	advance_to_next_turn()
	advance_to_next_turn()   # back round to player 0
	assert_false(bear.cur_landwalk.has("forest"),
		"player 0's upkeep ended it")


func test_the_upkeep_duration_names_a_player_not_just_a_turn() -> void:
	# An effect keyed to player 1 must ignore player 0's upkeep entirely.
	var bear := put_battlefield(0, "Grizzly Bears")
	g.continuous.add_until_eot_landwalk(bear.id, ["forest"], false,
		ContinuousEffects.Duration.UNTIL_UPKEEP_OF, 1)
	g.recalculate()
	advance_to_next_turn()   # player 1's turn: their upkeep ends it
	assert_false(bear.cur_landwalk.has("forest"))


# ------------------------------------------------------------- the cards --

func test_brine_hags_curse_lasts_indefinitely() -> void:
	# "...change the base power and toughness of all creatures that dealt
	# damage to it this turn to 0/2. (This effect lasts indefinitely.)"
	var hag := put_battlefield(1, "Brine Hag")        # 2/2
	var knight := put_battlefield(0, "Black Knight")  # 2/2 first strike
	run_combat([knight.id], {hag.id: knight.id})
	resolve_stack()
	assert_eq(knight.cur_power, 0, "flattened the turn it happened")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(knight.cur_power, 0, "and it is still flat two turns later")
	assert_eq(knight.cur_toughness, 2)


func test_xenic_poltergeist_animates_until_your_next_upkeep() -> void:
	# "{T}: Until your next upkeep, target noncreature artifact becomes an
	# artifact creature..." — the duration is the activator's next upkeep,
	# so the artifact is a creature through the whole intervening turn.
	var poltergeist := put_battlefield(0, "Xenic Poltergeist")
	var ring := put_battlefield(1, "Sol Ring")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, poltergeist, 0, [TargetRef.card(ring)]))
	resolve_stack()
	assert_true(ring.is_creature())
	advance_to_next_turn()   # the opponent's whole turn
	assert_true(ring.is_creature(),
		"it does not stop being a creature at the cleanup step")
	advance_to_next_turn()   # our upkeep comes round
	assert_false(ring.is_creature(), "our next upkeep ended it")


func test_erhnam_djinns_gift_outlives_the_djinn() -> void:
	# "...gains forestwalk until your next upkeep" is a one-shot effect
	# with its own duration, not a static of the Djinn's: answering the
	# Djinn does not take the forestwalk back.
	var djinn := put_battlefield(0, "Erhnam Djinn")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_next_turn()
	advance_to_next_turn()      # our upkeep hands out the gift
	assert_true(bear.cur_landwalk.has("forest"))
	g.destroy(djinn, false)
	g.check_state_based_actions()
	g.recalculate()
	assert_true(bear.cur_landwalk.has("forest"),
		"the gift is independent of its source")


func test_erhnam_djinns_gift_ends_at_the_next_upkeep() -> void:
	var djinn := put_battlefield(0, "Erhnam Djinn")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_true(bear.cur_landwalk.has("forest"))
	g.destroy(djinn, false)
	g.check_state_based_actions()
	advance_to_next_turn()
	advance_to_next_turn()      # our next upkeep, with no Djinn to renew it
	assert_false(bear.cur_landwalk.has("forest"),
		"one turn of forestwalk, then it lapses")


# ------------------------------------------- durationless GRANTED abilities --

func test_life_matrixs_shield_outlives_the_matrix() -> void:
	# "...and that creature GAINS 'Remove a matrix counter from this
	# creature: Regenerate this creature.'" No duration is stated, so the
	# grant lasts indefinitely (CR 611.2b) — destroying the Matrix cannot
	# take it back.
	var matrix := put_battlefield(0, "Life Matrix")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)
	resolve_stack()
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, matrix, 0, [TargetRef.card(bear)]))
	resolve_stack()
	g.destroy(matrix, false)
	g.check_state_based_actions()
	g.recalculate()
	assert_eq(matrix.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.cur_activated_abilities.size(), 1,
		"the grant is the creature's now, not the Matrix's")
	assert_ok(g.activate_ability(0, bear, 0, []))
	resolve_stack()
	assert_eq(int(bear.counters.get("matrix", 0)), 0)
	g.destroy(bear)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "it regenerated with no Matrix")


func test_a_granted_ability_does_not_follow_the_card_out_of_play() -> void:
	# CR 400.7 again: the grant is keyed to the OBJECT, not to the card.
	var matrix := put_battlefield(0, "Life Matrix")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)
	resolve_stack()
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, matrix, 0, [TargetRef.card(bear)]))
	resolve_stack()
	g.destroy(bear, false)
	g.check_state_based_actions()
	g._put_on_battlefield(bear, 0)
	g.recalculate()
	assert_eq(bear.cur_activated_abilities.size(), 0,
		"what came back is a new object and was never granted anything")


func test_venarian_golds_lock_is_the_auras_own_ability() -> void:
	# Both of the Gold's continuous lines say "ENCHANTED creature", so
	# both are abilities OF THE AURA: answering the Gold ends the lock at
	# once, and the sleep counters left on the creature are inert. (This
	# file's predecessor ledgered the opposite as a simplification; the
	# printed text says otherwise.)
	var bear := put_battlefield(1, "Grizzly Bears")
	var gold := give_hand(0, "Venarian Gold")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, gold, [TargetRef.card(bear)], 3))
	resolve_stack()
	assert_true(bear.tapped)
	assert_eq(int(bear.counters.get("sleep", 0)), 3)
	assert_true(bear.cur_skips_untap)
	g.destroy(gold, false)
	g.check_state_based_actions()
	g.recalculate()
	assert_eq(int(bear.counters.get("sleep", 0)), 3, "the counters stay put")
	assert_false(bear.cur_skips_untap,
		"but nothing reads them once the Aura is gone")
	advance_to_next_turn()
	assert_false(bear.tapped, "so it untaps on their next untap step")
