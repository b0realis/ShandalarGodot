extends GameTest
## THE OFFER, PRICED (2026-09-11, [member AiProfile.prices_offers]).
##
## THE PILOT HAD NEVER ANSWERED A "YOU MAY PAY" QUESTION IN ITS LIFE.
## [method DecisionAgent.answer_yes_no] returns the card author's hint,
## [AiPlayer] overrode it with nothing, and 68 card files put such a
## question to a seat. Reproduced at HEAD before a line was written — a
## Wizard in seat 0, four TAPPED Mana Vaults, a Sol Ring, a Mox Ruby,
## three Mountains and an Island, seven mana on the table and a Fireball
## in hand:
##
##     the script that owns answer_yes_no: res://engine/decision_agent.gd
##     [Upkeep] Pay {4} to untap Mana Vault? — yes   (four times)
##     -> Vaults untapped: 1 of 4
##     -> mana left for the whole turn: 3       (every offer declined: 7)
##     -> our life: 13                          (every offer declined: 12)
##
## Four mana for three, four times over, spent before the turn started:
## the seat ate its own board to untap ONE Vault and bought a single point
## of life with it. The Fireball went from X=6 to X=2.
##
## THE READING IS ONE SHAPE AND THE OTHER FOUR ARE RULED OUT, not deferred
## — an offer's two halves are comparable only in the SAME CURRENCY at the
## SAME BEAT, and a mana price against a mana source is the one pair in
## this pool that is (see [member AiProfile.prices_offers] for the survey
## and the rulings). Everything below is pinned with the knob ON and with
## it OFF, and the OFF arm is the pilot as it was.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.prices_offers = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.prices_offers = false
	return profile


## Put the game at a beat a rent is charged at — the reading fires nowhere
## else ([constant AiPlayer.OFFER_BEATS]).
func _at_upkeep() -> void:
	advance_to_step(Mtg.Step.UPKEEP)


# ------------------------------------------------- the price on the line --

func test_the_price_is_read_off_the_question_itself() -> void:
	assert_eq(EffectIntent.offer_price("Pay {4} to untap Mana Vault?"), "{4}")
	assert_eq(EffectIntent.offer_price("Pay {3}{B}{B}{B} to keep Cosmic Horror?"),
		"{3}{B}{B}{B}")
	assert_eq(EffectIntent.offer_price("Pay {G}{W}{U} to keep Arcades Sabboth?"),
		"{G}{W}{U}")


func test_a_price_that_is_not_mana_says_nothing() -> void:
	assert_eq(EffectIntent.offer_price("Pay 10 life to keep Bronze Tablet?"), "",
		"a life price is not this reader's currency")
	assert_eq(EffectIntent.offer_price("Sacrifice an Island to keep Elder Spawn?"), "")
	assert_eq(EffectIntent.offer_price("Discard a card to Mishra's War Machine?"), "")
	assert_eq(EffectIntent.offer_price("Pay {X} to keep it?"), "",
		"an X price is a count this reader will not do")


# ------------------------------------------------------------- the canary --

func test_the_vault_is_not_untapped_for_more_mana_than_it_makes() -> void:
	var ai := _ai(_on())
	var vault := put_battlefield(0, "Mana Vault")
	g.tap_permanent(vault)
	for i in 7:
		put_battlefield(0, "Mountain")
	_at_upkeep()
	assert_false(ai.answer_yes_no(g, 0, "Pay {4} to untap Mana Vault?", true),
		"four mana for a source that makes three")


func test_off_the_vault_is_always_untapped() -> void:
	var ai := _ai(_off())
	var vault := put_battlefield(0, "Mana Vault")
	g.tap_permanent(vault)
	for i in 7:
		put_battlefield(0, "Mountain")
	_at_upkeep()
	assert_true(ai.answer_yes_no(g, 0, "Pay {4} to untap Mana Vault?", true),
		"the hint, which is affordability and nothing else")


func test_the_whole_upkeep_keeps_the_turn_s_mana() -> void:
	# The reproduction board, played through the engine's own upkeep.
	_ai(_on())
	_ai(_on(), 1)
	var vaults := _vault_board()
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(_untapped(vaults), 0, "no Vault bought back")
	assert_eq(_reach(0), 7, "the whole board still stands for the turn")


func test_off_the_whole_upkeep_eats_the_turn_s_mana() -> void:
	_ai(_off())
	_ai(_off(), 1)
	var vaults := _vault_board()
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(_untapped(vaults), 1, "one Vault bought, with the other three's mana")
	assert_eq(_reach(0), 3, "three mana for a turn that had seven")


func _vault_board() -> Array[CardInstance]:
	var vaults: Array[CardInstance] = []
	for i in 4:
		var v := put_battlefield(0, "Mana Vault")
		g.tap_permanent(v)
		vaults.append(v)
	put_battlefield(0, "Sol Ring")
	put_battlefield(0, "Mox Ruby")
	for i in 3:
		put_battlefield(0, "Mountain")
	put_battlefield(0, "Island")
	return vaults


func _untapped(vaults: Array[CardInstance]) -> int:
	var out := 0
	for v in vaults:
		if not v.tapped:
			out += 1
	return out


func _reach(pid: int) -> int:
	var total := 0
	for inst in g.players[pid].battlefield:
		if inst.tapped:
			continue
		var best := 0
		for ability in inst.cur_mana_abilities:
			var made := 0
			for pair in ability.produces:
				made += int(pair[1])
			best = maxi(best, made)
		total += best
	return total


# ---------------------------------------------------------- the life gap --

func test_the_gap_is_paid_when_the_damage_is_worth_the_mana() -> void:
	# One mana short, and the point the Vault's draw-step line would deal
	# is worth a whole one at twelve life ([method AiPlayer._life_price]).
	var ai := _ai(_on())
	var vault := put_battlefield(0, "Mana Vault")
	g.tap_permanent(vault)
	for i in 7:
		put_battlefield(0, "Mountain")
	g.players[0].life = 12
	_at_upkeep()
	assert_true(ai.answer_yes_no(g, 0, "Pay {4} to untap Mana Vault?", true),
		"at twelve the point it saves is worth the mana it costs")


func test_the_gap_is_not_paid_one_point_higher() -> void:
	var ai := _ai(_on())
	var vault := put_battlefield(0, "Mana Vault")
	g.tap_permanent(vault)
	for i in 7:
		put_battlefield(0, "Mountain")
	g.players[0].life = 13
	_at_upkeep()
	assert_false(ai.answer_yes_no(g, 0, "Pay {4} to untap Mana Vault?", true),
		"half a point above twelve, and the mana is worth more")


func test_off_neither_life_total_changes_the_answer() -> void:
	var ai := _ai(_off())
	var vault := put_battlefield(0, "Mana Vault")
	g.tap_permanent(vault)
	for i in 7:
		put_battlefield(0, "Mountain")
	for life in [20, 13, 12, 3]:
		g.players[0].life = life
		assert_true(ai.answer_yes_no(g, 0, "Pay {4} to untap Mana Vault?", true),
			"the hint at %d life" % life)


# --------------------------------------------------------------- the rent --

func test_a_rent_above_what_the_source_makes_is_refused() -> void:
	# Energy Flux's {2} on a Mox: one mana a turn, rented for two.
	var ai := _ai(_on())
	put_battlefield(0, "Mox Ruby")
	for i in 7:
		put_battlefield(0, "Mountain")
	_at_upkeep()
	assert_false(ai.answer_yes_no(g, 0, "Pay {2} to keep Mox Ruby?", true))


func test_a_rent_the_source_makes_back_is_paid() -> void:
	var ai := _ai(_on())
	put_battlefield(0, "Sol Ring")
	for i in 7:
		put_battlefield(0, "Mountain")
	_at_upkeep()
	assert_true(ai.answer_yes_no(g, 0, "Pay {2} to keep Sol Ring?", true),
		"two mana a turn for two")


func test_off_every_rent_is_paid() -> void:
	var ai := _ai(_off())
	put_battlefield(0, "Mox Ruby")
	put_battlefield(0, "Sol Ring")
	for i in 7:
		put_battlefield(0, "Mountain")
	_at_upkeep()
	assert_true(ai.answer_yes_no(g, 0, "Pay {2} to keep Mox Ruby?", true))
	assert_true(ai.answer_yes_no(g, 0, "Pay {2} to keep Sol Ring?", true))


func test_a_rent_on_a_source_that_cannot_untap_buys_a_card_back() -> void:
	# A KEEP offer hands us nothing a tapped, locked source was going to
	# give anyway — renting one is renting the back of the card.
	var ai := _ai(_on())
	var vault := put_battlefield(0, "Mana Vault")
	g.tap_permanent(vault)
	g.recalculate()
	for i in 7:
		put_battlefield(0, "Mountain")
	_at_upkeep()
	assert_true(vault.cur_skips_untap, "its own static, read live")
	assert_false(ai.answer_yes_no(g, 0, "Pay {2} to keep Mana Vault?", true))


func test_an_untapped_source_is_worth_its_own_rent() -> void:
	var ai := _ai(_on())
	put_battlefield(0, "Mana Vault")
	for i in 7:
		put_battlefield(0, "Mountain")
	_at_upkeep()
	assert_true(ai.answer_yes_no(g, 0, "Pay {2} to keep Mana Vault?", true),
		"three mana for two")


# ----------------------------------------------- what is NOT this currency --

func test_a_body_is_never_priced_in_mana() -> void:
	# Brass Man's {1}, Island Fish Jasconius's {U}{U}{U}, a Paralyze on a
	# Serra Angel: untapping a body buys a block and an attack, which is
	# the combat search's question and not a price.
	var on := _ai(_on())
	var off := _ai(_off(), 1)
	put_battlefield(0, "Serra Angel")
	put_battlefield(1, "Serra Angel")
	for i in 7:
		put_battlefield(0, "Mountain")
		put_battlefield(1, "Mountain")
	_at_upkeep()
	assert_true(on.answer_yes_no(g, 0, "Pay {4} to untap Serra Angel?", true))
	assert_true(off.answer_yes_no(g, 1, "Pay {4} to untap Serra Angel?", true))


func test_a_mana_creature_is_a_body_too() -> void:
	var ai := _ai(_on())
	put_battlefield(0, "Llanowar Elves")
	for i in 7:
		put_battlefield(0, "Forest")
	_at_upkeep()
	assert_true(ai.answer_yes_no(g, 0, "Pay {4} to untap Llanowar Elves?", true),
		"one mana against four, and still not this reading's question")


func test_a_permanent_that_does_more_than_make_mana_is_left_alone() -> void:
	var on := _ai(_on())
	var off := _ai(_off(), 1)
	put_battlefield(0, "Jayemdae Tome")
	put_battlefield(1, "Jayemdae Tome")
	for i in 7:
		put_battlefield(0, "Mountain")
		put_battlefield(1, "Mountain")
	_at_upkeep()
	assert_true(on.answer_yes_no(g, 0, "Pay {2} to keep Jayemdae Tome?", true),
		"a card a turn is not mana")
	assert_true(off.answer_yes_no(g, 1, "Pay {2} to keep Jayemdae Tome?", true))


func test_a_land_is_never_this_reading() -> void:
	var ai := _ai(_on())
	var mountain := put_battlefield(0, "Mountain")
	g.tap_permanent(mountain)
	for i in 7:
		put_battlefield(0, "Forest")
	_at_upkeep()
	assert_true(ai.answer_yes_no(g, 0, "Pay {4} to untap Mountain?", true),
		"Evaluator.land_value prices a land by four things that are not its mana")


# ------------------------------------------------------------- the subject --

func test_a_question_that_names_no_permanent_of_ours_is_left_alone() -> void:
	var ai := _ai(_on())
	put_battlefield(0, "Mana Vault")
	for i in 7:
		put_battlefield(0, "Mountain")
	_at_upkeep()
	assert_true(ai.answer_yes_no(g, 0, "Pay {3} to draw a card?", true))
	assert_true(ai.answer_yes_no(g, 0, "Pay {W}{W} for a life?", true))
	assert_true(ai.answer_yes_no(g, 0, "Pay {1} to gain 1 life?", true))


func test_a_permanent_across_the_table_is_not_our_purchase() -> void:
	var ai := _ai(_on())
	put_battlefield(1, "Mox Ruby")
	for i in 7:
		put_battlefield(0, "Mountain")
	_at_upkeep()
	assert_true(ai.answer_yes_no(g, 0, "Pay {2} to keep Mox Ruby?", true),
		"theirs, so there is no subject on our side to price")


func test_the_longest_name_on_the_table_wins() -> void:
	var ai := _ai(_on())
	put_battlefield(0, "Mana Vault")
	var crypt := put_battlefield(0, "Mana Crypt")
	for i in 7:
		put_battlefield(0, "Mountain")
	_at_upkeep()
	assert_eq(ai._offer_subject(g, "Pay {2} to keep Mana Crypt?"), crypt)


# ---------------------------------------------------------------- the beat --

func test_the_same_question_outside_a_beat_is_a_one_off() -> void:
	# Scarwood Bandits' {2} buys the permanent outright; the stock against
	# the stream, in the other direction.
	var ai := _ai(_on())
	put_battlefield(0, "Mox Ruby")
	for i in 7:
		put_battlefield(0, "Mountain")
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(ai.answer_yes_no(g, 0, "Pay {2} to keep Mox Ruby?", true))
	_at_upkeep()
	assert_false(ai.answer_yes_no(g, 0, "Pay {2} to keep Mox Ruby?", true),
		"the same question, at a beat that comes round again")


func test_the_beats_are_the_toll_s_own() -> void:
	assert_eq(AiPlayer.OFFER_BEATS,
		[Mtg.Step.UPKEEP, Mtg.Step.DRAW, Mtg.Step.END] as Array[int],
		"EffectIntent.TOLL_BEATS, written as steps")


# ------------------------------------------------------ one-directional --

func test_a_hint_of_no_is_never_overturned() -> void:
	# A hint of NO is the card author's own refusal; a printed question is
	# no reason to argue with one upward.
	var ai := _ai(_on())
	put_battlefield(0, "Sol Ring")
	for i in 7:
		put_battlefield(0, "Mountain")
	_at_upkeep()
	assert_false(ai.answer_yes_no(g, 0, "Pay {1} to keep Sol Ring?", false))
	assert_true(ai.answer_yes_no(g, 0, "Pay {1} to keep Sol Ring?", true),
		"and the same question with a yes hint is still a yes")


func test_a_board_with_no_such_offer_answers_the_same_on_both_arms() -> void:
	# THE NULL: with the knob ON and nothing of the shape on the table,
	# every answer is the answer it was.
	var on := _ai(_on())
	var off := _ai(_off(), 1)
	for i in 7:
		put_battlefield(0, "Forest")
		put_battlefield(1, "Forest")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	_at_upkeep()
	for prompt in ["Pay {4} to untap Mana Vault?", "Pay {2} to keep Mox Ruby?",
			"Pay {1} to gain 1 life?", "Pay {G}{W}{U} to keep Arcades Sabboth?"]:
		assert_eq(on.answer_yes_no(g, 0, prompt, true),
			off.answer_yes_no(g, 1, prompt, true), prompt)


# --------------------------------------------------------------- the census --

func test_the_pool_prints_one_rent_a_mana_source_pays_itself() -> void:
	# What the reading actually reaches, counted rather than claimed — the
	# way `test_ai_minds_the_vise_2026_09_10.gd` counts its three hand
	# tolls. Twenty-four cards print a mana escape at one of the beats;
	# exactly one of them is a permanent whose whole worth is the mana it
	# makes, and it is the card the regression of `b3d3f18` was measured on.
	var ai := _ai(_on())
	var priced: Array = []
	var mana_only: Array = []
	for card_name in CardRegistry.all_names():
		var data := CardRegistry.get_card(card_name)
		var escape := ""
		for trig in data.triggered_abilities:
			if not EffectIntent.TOLL_BEATS.has(trig.event_type):
				continue
			escape = String(EffectIntent.toll_of_line(trig.text)["escape"])
			if escape != "":
				break
		if escape == "":
			continue
		priced.append(card_name)
		if ai._makes_only_mana(put_battlefield(0, card_name)):
			mana_only.append(card_name)
	assert_eq(priced.size(), 24, "cards whose own line names a mana escape at a beat")
	assert_eq(mana_only, ["Mana Vault"],
		"and the one of them the purchase can be counted in mana for")


func test_the_pool_holds_seventeen_permanents_that_only_make_mana() -> void:
	# The other half of the reach: what an upkeep rent put on a permanent
	# (Energy Flux's {2} on every artifact) can be priced about.
	var ai := _ai(_on())
	var found: Array = []
	for card_name in CardRegistry.all_names():
		if CardRegistry.get_card(card_name).mana_abilities.is_empty():
			continue
		if ai._makes_only_mana(put_battlefield(0, card_name)):
			found.append(card_name)
	found.sort()
	assert_eq(found, ["Black Lotus", "Black Mana Battery", "Blue Mana Battery",
		"Celestial Prism", "Fellwar Stone", "Green Mana Battery", "Mana Crypt",
		"Mana Vault", "Mox Emerald", "Mox Jet", "Mox Pearl", "Mox Ruby",
		"Mox Sapphire", "Red Mana Battery", "Sol Ring", "Standing Stones",
		"White Mana Battery"])


# ------------------------------------------------------------ the presets --

func test_the_rungs_carry_it_from_the_sorcerer_up() -> void:
	# A capability, like counts_cards and counts_the_race: counting what a
	# price buys before paying it is a layer of play, and the bottom two
	# rungs paying every rent they can afford is the same honest weakness
	# as the Apprentice never holding an instant.
	assert_false(AiProfile.apprentice().prices_offers)
	assert_false(AiProfile.magician().prices_offers)
	assert_true(AiProfile.sorcerer().prices_offers)
	assert_true(AiProfile.wizard().prices_offers)


func test_the_lab_can_reach_it_by_name() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("prices_offers=off"), "")
	assert_false(profile.prices_offers)
	assert_eq(profile.apply_overrides("prices_offers=on"), "")
	assert_true(profile.prices_offers)
