extends GameTest
## WHAT THE AI KEEPS MANA OPEN FOR — an audit of `_held_reserve`.
##
## The counter-threshold logic is well covered (`test_ai_reactive.gd`):
## the AI counters a Shivan Dragon, lets a Grizzly Bears resolve, and the
## Apprentice does neither. What had far less coverage is the half that
## decides whether the mana is STILL THERE when the moment comes — and
## that is the half a player actually feels, because a counterspell you
## tapped out for is a counterspell you do not have.


func _wizard(seat: int) -> AiPlayer:
	var ai := AiPlayer.new(seat, AiProfile.wizard())
	g.set_agent(seat, ai)
	return ai


func test_a_counterspell_now_reserves_its_own_mana() -> void:
	# IT DID NOT UNTIL 2026-09-06. `_is_held_instant` excludes anything
	# that counters — rightly, because `_fire_held_instant` would cast it
	# at the opponent's end step into an empty stack — and `_held_reserve`
	# asked only that question. So the AI would tap out over a
	# Counterspell and then be unable to pay for it.
	var ai := _wizard(0)
	give_hand(0, "Counterspell")
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	advance_to_step(Mtg.Step.MAIN1)
	var reserve := ai._held_reserve(g)
	assert_false(reserve.is_empty(), "a Counterspell reserves its mana")
	assert_eq(float(reserve["value"]), AiProfile.wizard().counter_threshold,
		"worth what this profile would bother countering")


func test_a_removal_instant_IS_reserved_for() -> void:
	# The contrast: an instant that answers a creature reserves too, and
	# names its own cost.
	var ai := _wizard(0)
	give_hand(0, "Lightning Bolt")
	put_battlefield(0, "Mountain")
	# A creature the Bolt actually KILLS. `_best_victim` asks
	# `intent.kills`, so a 4/4 Serra Angel is no target for three damage
	# and refusing to reserve for it is right — the first draft of this
	# test got that wrong and the code was correct.
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var reserve := ai._held_reserve(g)
	assert_false(reserve.is_empty(), "a Bolt with a target reserves")
	assert_gt(float(reserve["value"]), 0.0, "and it is worth something")


func test_the_hold_bends_for_something_clearly_better() -> void:
	# THE BOUNDARY, PINNED FROM BOTH SIDES. `_try_cast_best` declines a
	# cast worth less than 1.5x the reserve — 7.5 for a Wizard. Below it
	# the mana stays open; above it the AI takes the better deal, which is
	# the whole reason the rule is a ratio and not a veto.
	#
	# (Phantom Monster is worth exactly 7.5 and so casts by a hair. It
	# made a poor test and a good demonstration that the number is live.)
	var ai := _wizard(0)
	give_hand(0, "Counterspell")
	var specter := give_hand(0, "Hypnotic Specter")   # 5.5, below the bar
	for i in range(4):
		put_battlefield(0, "Island")
	put_battlefield(0, "Swamp")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass", "5.5 is not worth the counter mana")
	assert_eq(specter.zone, Mtg.Zone.HAND)


func test_and_casts_what_is_worth_more_than_the_counter() -> void:
	var ai := _wizard(0)
	give_hand(0, "Counterspell")
	give_hand(0, "Serra Angel")                        # 10.0, above the bar
	for i in range(3):
		put_battlefield(0, "Island")
	for i in range(3):
		put_battlefield(0, "Plains")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Serra Angel",
		"a 10.0 flier beats holding a counter")
