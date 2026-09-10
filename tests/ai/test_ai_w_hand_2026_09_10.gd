extends GameTest
## THE HAND'S WEIGHT, EXPOSED FOR A SWEEP (2026-09-10, casting note P11).
##
## [constant Evaluator.W_HAND] is 1.5 — a card in hand against a point of
## life — where Forge's own evaluator weights the same card at 2.5 times
## its life point (`docs/forge/casting.md` §6.2). Which of the two is
## right is a MEASUREMENT, not an argument, and the Deck Lab measures a
## number by putting it on a seat: so [method Evaluator.position_score]
## takes an optional [AiProfile] and reads [member AiProfile.w_hand] from
## it, exactly the "thread an AiProfile through rather than editing
## constants" the evaluator's own header asks for.
##
## IT IS NOT A KNOB. Every preset ships the constant's own value, no rung
## moves it, and nothing in the game sets it — `--sweep w_hand=1.5,2.0,2.5`
## is the only thing that ever does. What this file pins is that the
## default is inert (the shipped pilot scores byte for byte as it did) and
## that a profile carrying another value is actually read, at both of the
## two places the weight is spent.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _weighted(value: float) -> AiProfile:
	var profile := AiProfile.wizard()
	profile.w_hand = value
	return profile


# ======================================================== the default --

func test_every_preset_ships_the_constant() -> void:
	# The field's default IS Evaluator.W_HAND; this is the pin that keeps
	# the two from drifting apart (they cannot name each other — the
	# evaluator reads the profile, so the profile may not read the
	# evaluator).
	assert_eq(Evaluator.W_HAND, 1.5)
	for profile in [AiProfile.apprentice(), AiProfile.magician(),
			AiProfile.sorcerer(), AiProfile.wizard()]:
		assert_eq(profile.w_hand, Evaluator.W_HAND, profile.profile_name)


func test_the_default_profile_scores_exactly_as_no_profile() -> void:
	for _i in 4:
		give_hand(0, "Grizzly Bears")
	give_hand(1, "Grizzly Bears")
	put_battlefield(0, "Serra Angel")
	put_battlefield(1, "Hill Giant")
	assert_eq(Evaluator.position_score(g, 0),
		Evaluator.position_score(g, 0, AiProfile.wizard()),
		"the shipped pilot scores as the constant does")


# ========================================================= it is read --

func test_position_score_prices_the_hand_lead_at_the_profiles_weight() -> void:
	# Three cards of lead and nothing else on the table: the score IS the
	# weight times three, whatever the weight is.
	for _i in 3:
		give_hand(0, "Grizzly Bears")
	assert_almost_eq(Evaluator.position_score(g, 0, _weighted(1.5)), 4.5, 0.001)
	assert_almost_eq(Evaluator.position_score(g, 0, _weighted(2.0)), 6.0, 0.001)
	assert_almost_eq(Evaluator.position_score(g, 0, _weighted(2.5)), 7.5, 0.001)
	# And from the other seat it is the same lead with the other sign.
	assert_almost_eq(Evaluator.position_score(g, 1, _weighted(2.5)), -7.5, 0.001)


func test_the_leveller_prices_a_card_in_hand_at_the_same_weight() -> void:
	# Balance's own reading ([method AiPlayer._level_value]) spends the
	# weight too, and a sweep that moved one and not the other would be
	# measuring two numbers at once. Four cards of theirs against our one
	# (the Balance itself is on the stack by then, CR 601.2a).
	var pilot := _weighted(1.5)
	var ai := _ai(pilot)
	var balance := give_hand(0, "Balance")
	for _i in 4:
		give_hand(1, "Grizzly Bears")
	var at_15 := ai._level_value(g, balance)
	pilot.w_hand = 2.5
	var at_25 := ai._level_value(g, balance)
	assert_almost_eq(at_25 - at_15, 4.0, 0.001, "four cards, one point of weight each")


# ========================================================== the sweep --

func test_the_lab_can_put_a_number_on_the_seat() -> void:
	var profile := AiProfile.wizard()
	assert_eq(typeof(profile.get("w_hand")), TYPE_FLOAT,
		"the sweep reads a knob's type off a probe profile")
	assert_eq(profile.apply_overrides("w_hand=2.5"), "")
	assert_eq(profile.w_hand, 2.5)
	assert_eq(profile.apply_overrides("w_hand=1.5"), "")
	assert_eq(profile.w_hand, 1.5)
