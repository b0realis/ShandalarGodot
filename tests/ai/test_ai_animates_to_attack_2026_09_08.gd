extends GameTest
## THE FACTORY ANIMATED FOR NOTHING (2026-09-08, The Deck's third pass).
## An animation is priced as the attack it enables, and in 150
## instrumented games 29 of 834 Mishra's Factory animations declared no
## attack that turn. Twenty-one of them were the MANA PLANNER: the next
## thing the pilot paid for (a Disrupting Scepter, three mana) tapped the
## body it had just bought. Five were the CRACK-BACK SEARCH holding an
## animated body home as next turn's blocker — a body that is a land
## again at cleanup. The rest were the two readers disagreeing about
## the same board (docs/ROADMAP.md, "The Deck, third pass").
##
## Three readings under one knob, [member AiProfile.animates_to_attack]:
## the body animated to attack is not a mana source until the attack is
## declared ([method AiPlayer._attackers_excluded]); a creature-until-
## end-of-turn is no blocker on their turn in the crack-back model
## ([method AiPlayer._build_combat_model]); and the animation is bought
## only when the declaration itself, asked under the journal, would send
## it ([method AiPlayer._would_attack_once_animated]). Each behaviour is
## pinned twice: with the knob and without it.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.animates_to_attack = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.animates_to_attack = false
	return profile


func _lands(seat: int, land_name: String, count: int) -> void:
	for _i in count:
		put_battlefield(seat, land_name)


## Walk priority from our first main phase to the attack declaration.
func _reach_attackers(ai: AiPlayer) -> void:
	var guard := 0
	while not g.awaiting_attackers and not g.game_over and guard < 40:
		if g.priority_player == 0:
			ai.act(g)
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	assert_true(g.awaiting_attackers, "reached the declaration")


# ------------------------------------------- the planner and the body --

func test_the_next_payment_leaves_the_animated_body_alone() -> void:
	# The census's commonest waste: Factory animated, Scepter paid for
	# with the Factory, "declares no attackers". Three Forests and the
	# Factory: the animation takes one Forest, and the Scepter's {3} can
	# then only be met by tapping the body — which the planner refuses.
	var ai := _ai(_on())
	var factory := put_battlefield(0, "Mishra's Factory")
	_lands(0, "Forest", 3)
	put_battlefield(0, "Disrupting Scepter")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Mishra's Factory")   # their hand is empty: no Scepter yet
	resolve_stack()
	assert_true(factory.is_creature())
	give_hand(1, "Island")
	assert_eq(ai.act(g), "pass", "the Scepter cannot be paid for without the body")
	assert_false(factory.tapped, "the body animated to attack is not a mana source")
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker")
	assert_true(g.combat.attackers.has(factory.id))


func test_off_the_next_payment_taps_the_animated_body() -> void:
	# The waste itself, pinned so the knob's null is the pilot as it was.
	var ai := _ai(_off())
	var factory := put_battlefield(0, "Mishra's Factory")
	_lands(0, "Forest", 3)
	put_battlefield(0, "Disrupting Scepter")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Mishra's Factory")
	resolve_stack()
	give_hand(1, "Island")
	assert_eq(ai.act(g), "activated Disrupting Scepter")
	resolve_stack()
	assert_true(factory.tapped, "the planner tapped the body it had just bought")
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 0 attacker")
	assert_false(g.combat.attackers.has(factory.id))


func test_after_combat_the_body_taps_like_any_land() -> void:
	# The exclusion is for the attack; once it has been declared there is
	# nothing left to protect. A Factory animated in the second main
	# phase (a scratch animation — the pilot never buys one there) pays
	# for the Scepter like any land.
	var ai := _ai(_on())
	var factory := put_battlefield(0, "Mishra's Factory")
	_lands(0, "Forest", 2)
	put_battlefield(0, "Disrupting Scepter")
	give_hand(1, "Island")
	advance_to_step(Mtg.Step.MAIN2)
	g.continuous.add_until_eot_animation(factory.id, Mtg.CardType.CREATURE, 2, 2)
	g.recalculate()
	assert_true(factory.is_creature())
	assert_eq(ai.act(g), "activated Disrupting Scepter")
	assert_true(factory.tapped)


func test_a_body_paid_for_the_second_animation_is_not_the_first() -> void:
	# Two Factories, two Forests: the first animation is paid with a
	# Forest, the second with the other Forest — never with the first
	# body, which was bought to attack. (The Forests come first on the
	# battlefield: among equal sources the planner takes them in order,
	# and a plain land before a Factory is a tie-break it does not yet
	# know — docs/ROADMAP.md, "The Deck, third pass", still open.)
	var ai := _ai(_on())
	_lands(0, "Forest", 2)
	var first := put_battlefield(0, "Mishra's Factory")
	var second := put_battlefield(0, "Mishra's Factory")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Mishra's Factory")
	resolve_stack()
	assert_eq(ai.act(g), "activated Mishra's Factory")
	resolve_stack()
	assert_true(first.is_creature() and second.is_creature())
	assert_false(first.tapped)
	assert_false(second.tapped)
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 2 attacker")


# ---------------------------------------- the crack-back and the body --

func test_an_animated_body_is_no_blocker_on_their_turn() -> void:
	# They swung with two Bears and we are at four: the crack-back gate is
	# open. Holding the animated Factory home "saves" us only in a model
	# that thinks it will be a creature on their turn. It will not be, so
	# the search sends it: two damage now is worth more than nothing.
	var ai := _ai(_on())
	var factory := put_battlefield(0, "Mishra's Factory")
	_lands(0, "Forest", 1)
	g.players[0].life = 4
	for _i in 2:
		var bears := put_battlefield(1, "Grizzly Bears")
		bears.tapped = true
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Mishra's Factory")
	resolve_stack()
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker")
	assert_true(g.combat.attackers.has(factory.id))


func test_off_the_search_holds_the_animated_body_home() -> void:
	# The phantom blocker: the mana spent, the body held, the attack
	# never declared — five of the census's twenty-nine.
	var ai := _ai(_off())
	var factory := put_battlefield(0, "Mishra's Factory")
	_lands(0, "Forest", 1)
	g.players[0].life = 4
	for _i in 2:
		var bears := put_battlefield(1, "Grizzly Bears")
		bears.tapped = true
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Mishra's Factory")
	resolve_stack()
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 0 attacker")
	assert_false(g.combat.attackers.has(factory.id))


func test_a_printed_creature_is_still_a_blocker_on_their_turn() -> void:
	# The reading is about the DURATION of a creature-hood, not about
	# lands: a Bears of ours at four life against two tapped Bears of
	# theirs is held home by the search exactly as before.
	var ai := _ai(_on())
	var bears := put_battlefield(0, "Grizzly Bears")
	g.players[0].life = 4
	for _i in 2:
		var theirs := put_battlefield(1, "Grizzly Bears")
		theirs.tapped = true
	advance_to_step(Mtg.Step.MAIN1)
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 0 attacker")
	assert_false(g.combat.attackers.has(bears.id))


func test_creature_until_end_of_turn_reads_the_duration() -> void:
	var factory := put_battlefield(0, "Mishra's Factory")
	var bears := put_battlefield(0, "Grizzly Bears")
	var rack := put_battlefield(0, "Cursed Rack")
	assert_false(g.continuous.creature_until_end_of_turn(factory.id), "a land")
	assert_false(g.continuous.creature_until_end_of_turn(bears.id), "a printed creature")
	g.continuous.add_until_eot_animation(factory.id, Mtg.CardType.CREATURE, 2, 2)
	g.recalculate()
	assert_true(g.continuous.creature_until_end_of_turn(factory.id), "animated until end of turn")
	# Xenic Poltergeist's "until your next upkeep" outlasts cleanup: on
	# their turn the artifact is still a creature and still blocks.
	g.continuous.add_until_eot_animation(rack.id, Mtg.CardType.CREATURE, 4, 4, [],
		false, ContinuousEffects.Duration.UNTIL_UPKEEP_OF, 0)
	g.recalculate()
	assert_true(rack.is_creature())
	assert_false(g.continuous.creature_until_end_of_turn(rack.id), "outlasts the turn")
	g.continuous.expire_until_eot()
	g.recalculate()
	assert_false(g.continuous.creature_until_end_of_turn(factory.id), "expired")
	assert_false(factory.is_creature())


# ------------------------------------------- the declaration's answer --

func test_the_animation_is_not_bought_under_our_own_moat() -> void:
	# Moat stops creatures without flying, ours included. The blocker
	# count saw an empty board and bought the body every turn; the
	# declaration knows better, and the probe asks it.
	var ai := _ai(_on())
	var factory := put_battlefield(0, "Mishra's Factory")
	put_battlefield(0, "Moat")
	_lands(0, "Forest", 2)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass")
	assert_false(factory.is_creature(), "no animation was bought")


func test_off_the_animation_is_bought_under_our_own_moat() -> void:
	var ai := _ai(_off())
	var factory := put_battlefield(0, "Mishra's Factory")
	put_battlefield(0, "Moat")
	_lands(0, "Forest", 2)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Mishra's Factory")
	resolve_stack()
	assert_true(factory.is_creature())
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 0 attacker")


func test_an_empty_board_is_still_animated_and_attacked() -> void:
	# The probe agrees with the blocker count where the count was right.
	var ai := _ai(_on())
	var factory := put_battlefield(0, "Mishra's Factory")
	_lands(0, "Forest", 2)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Mishra's Factory")
	resolve_stack()
	assert_true(factory.is_creature())
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker")
	assert_true(g.combat.attackers.has(factory.id))


func test_a_blocker_that_eats_the_body_still_refuses_it() -> void:
	# The count's own refusal stands in front of the probe: a land traded
	# for a Bears is a mana source the control deck needed.
	var ai := _ai(_on())
	put_battlefield(0, "Mishra's Factory")
	_lands(0, "Forest", 2)
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass")


func test_the_probe_leaves_the_game_as_it_found_it() -> void:
	# The animation is tried under the journal and unmade: no journal
	# stays open, no animation stays registered, no log line was written,
	# and the random stream has not moved.
	var ai := _ai(_on())
	var factory := put_battlefield(0, "Mishra's Factory")
	put_battlefield(0, "Moat")
	_lands(0, "Forest", 2)
	advance_to_step(Mtg.Step.MAIN1)
	var state_before := g.rng.state
	var lines_before := g.log_lines.size()
	assert_eq(ai.act(g), "pass")
	assert_eq(g.rng.state, state_before, "no random number was drawn")
	assert_eq(g.log_lines.size(), lines_before, "the probe wrote no log line")
	assert_null(g.undo_log, "the journal was handed back")
	assert_null(g.continuous.journal)
	assert_false(g.continuous.creature_until_end_of_turn(factory.id))
	assert_false(factory.is_creature())
	assert_false(factory.tapped)


func test_the_probe_keeps_a_search_already_in_progress() -> void:
	# A caller that has a journal open keeps it: the probe nests a mark
	# and unmakes to it, and does not end the outer search.
	var ai := _ai(_on())
	put_battlefield(0, "Mishra's Factory")
	put_battlefield(0, "Moat")
	_lands(0, "Forest", 2)
	advance_to_step(Mtg.Step.MAIN1)
	var mark := g.make_mark()
	assert_eq(ai.act(g), "pass")
	assert_not_null(g.undo_log, "the outer journal is still open")
	g.unmake_to(mark)
	g.end_search()
	assert_null(g.undo_log)


# ---------------------------------------------------------- the ladder --

func test_the_ladder() -> void:
	assert_false(AiProfile.apprentice().animates_to_attack)
	assert_false(AiProfile.magician().animates_to_attack)
	assert_true(AiProfile.sorcerer().animates_to_attack)
	assert_true(AiProfile.wizard().animates_to_attack)


func test_the_override() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("animates_to_attack=off"), "")
	assert_false(profile.animates_to_attack)
	assert_eq(profile.apply_overrides("animates_to_attack=on"), "")
	assert_true(profile.animates_to_attack)
