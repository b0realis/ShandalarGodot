extends GameTest
## THE COMPUTER PILOT'S FIVE (review of 2026-10-21, findings ai-1 to ai-5).
## The owner's ruling on the review: *"All! ... Document each fix"*.
##
##  ai-1 CARD-COMBOS' "mana for the hand" sized its loop by the mana value
##       of every card in hand that is no loop piece — Counterspells held
##       for a response, a Serra Angel with no white source, a three-mana
##       card on a loop that makes two a round — and the mana nothing spent
##       burned under a mana-burn rule (the player's default preset): 6
##       life for an Ornithopter cast four times, 3 twice in a Deck Lab
##       Power Artifact game. The loop now runs for the cards the main-phase
##       ranking would cast with its mana, and under mana burn never makes
##       more {C} than those cards' generic costs spend.
##  ai-2 The Wizard's one-ply cast veto read "Sacrifice a creature: 1
##       damage" (Goblin Bombardment) and "{T}, Sacrifice an artifact: 2
##       damage" (Orcish Mechanics) as removal its owner could fire with
##       nothing to sacrifice, and held every small creature all game.
##  ai-3 Shrieking Drake's arrival returned the Drake itself — the AI's
##       answer to the ordered ask was always the first candidate — so the
##       Drake was cast once per blue source a turn for nothing.
##  ai-4 Mana Drain's payout was never priced: a six-mana Book of Rass was
##       drained with nothing in hand to spend six colourless on, and the
##       payout burned for 6 at the next main phase.
##  ai-5 A second Power Artifact was priced as completing the loop on the
##       Monolith the first already enchants — where it does nothing — and
##       a second Ashnod's Altar as progress beside the first.

const CC := preload("res://engine/ai/card_combos.gd")
const PACKS := ["pack-3", "pack-5", "pack-6", "pack-8", "pack-9"]
const BURN_PRESETS := ["modern_mana_burn", "fifth"]


func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, id in PACKS)


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null


func _fresh(preset: String) -> void:
	before_each()
	g.rules.set_preset(preset)


func _profile(rung: String, combos := true) -> AiProfile:
	var p: AiProfile
	match rung:
		"apprentice": p = AiProfile.apprentice()
		"magician": p = AiProfile.magician()
		"sorcerer": p = AiProfile.sorcerer()
		_: p = AiProfile.wizard()
	p.mistake_chance = 0.0
	p.develops_late = false
	p.plays_combos = combos
	return p


## Both seats computer pilots; seat 0's is returned.
func _pilots(rung := "wizard", combos := true) -> AiPlayer:
	var ai := AiPlayer.new(0, _profile(rung, combos))
	g.set_agent(0, ai)
	g.set_agent(1, AiPlayer.new(1, _profile("wizard", false)))
	return ai


## Let both pilots play until seat 0's turn is over (or the game is).
func _play_our_turn(cap := 4000) -> void:
	var a0: AiPlayer = g.agents[0]
	var a1: AiPlayer = g.agents[1]
	var turn := g.turn_number
	var rounds := 0
	while not g.game_over and g.turn_number == turn and rounds < cap:
		var said0 := a0.act(g)
		var said1 := a1.act(g)
		if said0 == "" and said1 == "" and not g.game_over:
			break
		rounds += 1
	assert_lt(rounds, cap, "the turn ran away")


func _logged(text: String) -> int:
	var n := 0
	for line in g.log_lines:
		if line.contains(text):
			n += 1
	return n


func _renewed_thopter() -> void:
	put_battlefield(0, "Enduring Renewal")
	put_battlefield(0, "Ashnod's Altar")
	give_hand(0, "Ornithopter")


# ========================================================= ai-1 mana for the hand --

func test_no_loop_mana_for_counterspells_held_for_a_response() -> void:
	for preset in BURN_PRESETS:
		_fresh(preset)
		_pilots()
		_renewed_thopter()
		put_battlefield(0, "Island")
		put_battlefield(0, "Island")
		for i in 3:
			give_hand(0, "Counterspell")
		_play_our_turn()
		assert_eq(_logged("mana for the hand"), 0, "%s: no loop for held Counterspells" % preset)
		assert_eq(g.players[0].life, 20, "%s: nothing burned" % preset)


func test_no_loop_mana_for_a_card_with_no_source_of_its_colour() -> void:
	for preset in BURN_PRESETS:
		_fresh(preset)
		_pilots()
		_renewed_thopter()
		var angel := give_hand(0, "Serra Angel")   # {3}{W}{W}, and no white source
		_play_our_turn()
		assert_eq(angel.zone, Mtg.Zone.HAND, preset)
		assert_eq(g.players[0].life, 20, "%s: nothing burned for an uncastable Angel" % preset)


## Two {C} a round and a three-mana card: two rounds make four and one
## burns; one round is short. With no land the loop is not run at all...
func test_the_loop_never_makes_mana_past_what_the_hand_spends() -> void:
	for preset in BURN_PRESETS:
		_fresh(preset)
		_pilots()
		_renewed_thopter()
		give_hand(0, "Jalum Tome")
		_play_our_turn()
		assert_eq(g.players[0].life, 20, "%s: no {C} left over to burn" % preset)


## ...and with one Mountain, one round and the Mountain pay for the Tome.
func test_one_round_and_a_land_pay_for_the_hand() -> void:
	for preset in BURN_PRESETS:
		_fresh(preset)
		_pilots()
		_renewed_thopter()
		put_battlefield(0, "Mountain")
		var tome := give_hand(0, "Jalum Tome")
		_play_our_turn()
		assert_eq(tome.zone, Mtg.Zone.BATTLEFIELD, "%s: two from the loop, one from the Mountain" % preset)
		assert_eq(g.players[0].life, 20, "%s: nothing burned" % preset)


## Under the modern rules nothing burns, and the hand is still paid for.
func test_without_mana_burn_the_hand_is_still_paid_for() -> void:
	_fresh("modern")
	_pilots()
	_renewed_thopter()
	var juggernaut := give_hand(0, "Juggernaut")
	_play_our_turn()
	assert_eq(juggernaut.zone, Mtg.Zone.BATTLEFIELD, "four from the loop")


# ================================================ ai-2 the answer that cannot be paid --

func _held_against(their_card: String, our_lands: String, ours: String) -> CardInstance:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	g.set_agent(1, AiPlayer.new(1, AiProfile.wizard()))
	put_battlefield(0, our_lands)
	put_battlefield(0, our_lands)
	put_battlefield(1, their_card)   # and nothing of theirs for its cost to eat
	var body := give_hand(0, ours)
	assert_false(ai._answered_on_arrival(g, body.data),
		"%s with nothing to sacrifice is no answer to %s" % [their_card, ours])
	_play_our_turn()
	return body


func test_an_unfed_bombardment_holds_no_savannah_lions() -> void:
	var lions := _held_against("Goblin Bombardment", "Plains", "Savannah Lions")
	assert_eq(lions.zone, Mtg.Zone.BATTLEFIELD, "the Wizard casts its Lions")


func test_an_unfed_orcish_mechanics_holds_no_grizzly_bears() -> void:
	var bears := _held_against("Orcish Mechanics", "Forest", "Grizzly Bears")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "the Wizard casts its Bears")


## A pinger whose cost is mana alone is still the answer it was.
func test_a_mana_pinger_still_answers_a_one_toughness_body() -> void:
	var ai := _pilots()
	put_battlefield(1, "Prodigal Sorcerer")
	assert_true(ai._answered_on_arrival(g, CardRegistry.get_card("Savannah Lions")))


# ==================================================== ai-3 the Drake that returns itself --

func _drake_casts() -> int:
	return _logged("casts Shrieking Drake")


func test_a_lone_drake_is_not_cast_to_return_itself() -> void:
	for rung in ["apprentice", "magician", "sorcerer", "wizard"]:
		for combos in [true, false]:
			before_each()
			_pilots(rung, combos)
			put_battlefield(0, "Island")
			var drake := give_hand(0, "Shrieking Drake")
			_play_our_turn()
			assert_eq(_drake_casts(), 0, "%s combos=%s: one blue mana for nothing" % [rung, combos])
			assert_eq(drake.zone, Mtg.Zone.HAND)


func test_a_drake_beside_a_plain_creature_is_not_cast_again_and_again() -> void:
	for rung in ["apprentice", "magician", "sorcerer", "wizard"]:
		before_each()
		_pilots(rung)
		for i in 3:
			put_battlefield(0, "Island")
		var bears := put_battlefield(0, "Grizzly Bears")
		give_hand(0, "Shrieking Drake")
		_play_our_turn()
		assert_eq(_drake_casts(), 0, "%s: three Islands, three Drakes for nothing" % rung)
		assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, rung)


## A body whose arrival is worth having again (Man-o'-War, with a creature
## of theirs to bounce) is the one the Drake returns — and the Drake stays.
func test_the_drake_returns_a_creature_whose_arrival_is_worth_repeating() -> void:
	for rung in ["apprentice", "wizard"]:
		before_each()
		_pilots(rung, false)
		put_battlefield(0, "Island")
		# The Man-o'-War's own arrival is spent on a first Wurm; a second
		# one is what its next arrival would bounce.
		put_battlefield(1, "Craw Wurm")
		var jelly := put_battlefield(0, "Man-o'-War")
		resolve_stack()
		put_battlefield(1, "Craw Wurm")
		assert_eq(jelly.zone, Mtg.Zone.BATTLEFIELD)
		var drake := give_hand(0, "Shrieking Drake")
		_play_our_turn()
		assert_eq(_drake_casts(), 1, rung)
		assert_eq(drake.zone, Mtg.Zone.BATTLEFIELD, "%s: the Drake stays" % rung)
		assert_eq(jelly.zone, Mtg.Zone.HAND, "%s: the Man-o'-War goes back for another bounce" % rung)


## An arrival our own table pays out on (Pandemonium: a damage each time)
## is a reason to cast the Drake even when it returns itself.
func test_a_drake_under_pandemonium_is_still_cast() -> void:
	_pilots("wizard", false)
	put_battlefield(0, "Pandemonium")
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	give_hand(0, "Shrieking Drake")
	_play_our_turn()
	assert_gt(_drake_casts(), 0, "each arrival deals a damage")
	assert_lt(g.players[1].life, 20)


## The loop runner's own use is untouched: Aluren + Pandemonium + Drake
## still burns them out.
func test_the_drake_loop_still_runs() -> void:
	_pilots()
	put_battlefield(0, "Aluren")
	put_battlefield(0, "Pandemonium")
	give_hand(0, "Shrieking Drake")
	g.players[1].life = 8
	_play_our_turn()
	assert_eq(g.winner, 0, "eight rounds of the loop")


# ===================================================== ai-4 the payout that burns --

## Seat 1 holds Mana Drain over two Islands; seat 0 casts [param spell]
## off [param land]s; seat 1 answers, then plays on through its own first
## main phase. Returns the spell.
func _drain(preset: String, spell: String, land: String, lands: int,
		hand: Array = []) -> CardInstance:
	_fresh(preset)
	var a0 := AiPlayer.new(0, AiProfile.wizard())
	var a1 := AiPlayer.new(1, AiProfile.wizard())
	g.set_agent(0, a0)
	g.set_agent(1, a1)
	put_battlefield(1, "Island")
	put_battlefield(1, "Island")
	give_hand(1, "Mana Drain")
	for card_name in hand:
		give_hand(1, card_name)
	for i in lands:
		put_battlefield(0, land)
	var card := give_hand(0, spell)
	for perm in g.players[0].battlefield:
		if perm.is_land(): g.tap_for_mana(0, perm, 0)
	assert_ok(g.cast_spell(0, card, []))
	var guard := 0
	while not g.stack.is_empty() and guard < 50:
		if g.priority_player == 1:
			a1.act(g)
		else:
			g.pass_priority(g.priority_player)
		guard += 1
	guard = 0
	while not g.game_over and guard < 4000 \
			and not (g.active_player == 1 and g.current_step() == Mtg.Step.COMBAT_BEGIN):
		if a0.act(g) == "" and a1.act(g) == "":
			break
		guard += 1
	return card


func test_a_harmless_six_drop_is_not_drained_into_six_burn() -> void:
	for preset in BURN_PRESETS:
		var book := _drain(preset, "Book of Rass", "Mountain", 6)
		assert_eq(_logged("casts Mana Drain"), 0, "%s: six life for a Book of Rass" % preset)
		assert_eq(book.zone, Mtg.Zone.BATTLEFIELD, preset)
		assert_eq(g.players[1].life, 20, "%s: no payout burned" % preset)


## The real threat is still countered, burn and all.
func test_a_real_threat_is_still_drained() -> void:
	var angel := _drain("modern_mana_burn", "Serra Angel", "Plains", 5)
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD, "a Serra Angel is worth the payout's burn")


## Without mana burn the payout costs nothing, and the Book is drained.
func test_without_mana_burn_the_payout_is_free() -> void:
	var book := _drain("modern", "Book of Rass", "Mountain", 6)
	assert_eq(book.zone, Mtg.Zone.GRAVEYARD, "drained as before")


## With a card in hand that spends the payout, the Drain is a Drain again.
func test_a_payout_the_hand_spends_is_no_burn() -> void:
	var book := _drain("modern_mana_burn", "Book of Rass", "Mountain", 6, ["Juggernaut", "Jalum Tome"])
	assert_eq(book.zone, Mtg.Zone.GRAVEYARD, "a Juggernaut and a Tome spend the six")


# ===================================================== ai-5 the second copy of a piece --

func test_a_second_power_artifact_on_the_same_monolith_is_no_combo_play() -> void:
	var ai := _pilots()
	var mono := put_battlefield(0, "Basalt Monolith")
	var aura := give_hand(0, "Power Artifact")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(mono)]))
	resolve_stack()
	var second := give_hand(0, "Power Artifact")
	assert_null(CC.spell_choice(g, ai, second), "the Monolith's slot is filled; a second does nothing")


func test_a_second_power_artifact_goes_on_the_bare_monolith() -> void:
	var ai := _pilots()
	var first := put_battlefield(0, "Basalt Monolith")
	var bare := put_battlefield(0, "Basalt Monolith")
	var aura := give_hand(0, "Power Artifact")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(first)]))
	resolve_stack()
	var second := give_hand(0, "Power Artifact")
	var choice: Variant = CC.spell_choice(g, ai, second)
	assert_true(choice is Dictionary and not (choice as Dictionary).is_empty(), "a second loop")
	var aimed := ((choice as Dictionary)["targets"] as Array)[0] as TargetRef
	assert_eq(aimed.instance_id, bare.id, "the bare Monolith, not the enchanted one")
	assert_gte(float((choice as Dictionary)["value"]), CC.COMPLETE_WORTH, "it completes a second loop")


func test_a_second_altar_is_no_progress() -> void:
	var ai := _pilots()
	put_battlefield(0, "Ashnod's Altar")
	give_hand(0, "Enduring Renewal")
	var second := give_hand(0, "Ashnod's Altar")
	assert_null(CC.spell_choice(g, ai, second), "the Altar's slot is filled")


func test_the_hill_giant_before_a_second_power_artifact() -> void:
	var ai := _pilots()
	for n in ["Island", "Island", "Mountain", "Mountain"]:
		put_battlefield(0, n)
	var mono := put_battlefield(0, "Basalt Monolith")
	var aura := give_hand(0, "Power Artifact")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(mono)]))
	resolve_stack()
	mono.tapped = true   # its mana spent already this turn
	var second := give_hand(0, "Power Artifact")
	var giant := give_hand(0, "Hill Giant")
	assert_string_contains(ai.act(g), "Hill Giant")
	assert_eq(second.zone, Mtg.Zone.HAND)
	assert_ne(giant.zone, Mtg.Zone.HAND)
