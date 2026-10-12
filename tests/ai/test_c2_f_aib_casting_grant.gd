extends GameTest
## THE CASTING GRANT (bug-hunt campaign 2026-10-12, b5-3;
## engine/ai/tempest_spells.gd `casting_grant_choice`, [member
## AiProfile.forecasts_tactics]).
##
## Dream Halls ("Rather than pay the mana cost for a spell, its controller
## may discard a card that shares a color with that spell") and Aluren
## ("Any player may cast creature spells with mana value 3 or less without
## paying their mana costs") change neither side's board, so the symmetric
## static's projection read them as nothing and the generic value cast
## them — Dream Halls into a hand that could use none of it, the opponent's
## licids then cast for a discard. Pinned here, under both rules presets:
##  * a grant that serves only the opponent's public hand is held;
##  * one our own hand would use more is left to the generic value (cast);
##  * the opponent's hidden hand (identities) and both libraries' order
##    move nothing; the reading leaves the game and its random stream as
##    it found them;
##  * the gate off is the null arm.

const TS := preload("res://engine/ai/tempest_spells.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-9", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.mistake_chance = 0.0
	p.develops_late = false
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _play_main(ai: AiPlayer) -> Array:
	var lines: Array = []
	var turn := g.turn_number
	for k in 12:
		if g.game_over or g.turn_number != turn or g.current_step() != Mtg.Step.MAIN1:
			break
		if g.priority_player == 0:
			var did := ai.act(g)
			lines.append(did)
			if did == "" or did == "pass":
				break
		else:
			g.pass_priority(g.priority_player)
		resolve_stack()
	return lines


## The hunt's board (p9_buyback v p9_licids, seed 5101, turn 9): Dream Halls
## with one blue spell and no second blue card; five cards across the
## table and two licids on their side.
func _halls_board(their_hand: Array) -> CardInstance:
	for n in ["Island", "Island", "Island", "Mountain", "Mountain"]:
		put_battlefield(0, n)
	var halls := give_hand(0, "Dream Halls")
	give_hand(0, "Whim of Volrath")
	give_hand(0, "Island")
	for n in their_hand:
		give_hand(1, n)
	put_battlefield(1, "Nurturing Licid")
	put_battlefield(1, "Quickening Licid")
	advance_to_step(Mtg.Step.MAIN1)
	return halls


const LICID_HAND := ["Jackal Pup", "Convulsing Licid", "Calming Licid", "Skyshroud Troopers", "Plains"]


func _dream_halls_is_not_a_gift(preset: String) -> void:
	g.rules.set_preset(preset)
	var ai := _ai()
	var halls := _halls_board(LICID_HAND)
	var lines := _play_main(ai)
	assert_eq(halls.zone, Mtg.Zone.HAND,
		"%s: nothing of ours uses the discard row; five cards across the table can (%s)" % [preset, lines])


func test_dream_halls_is_not_a_gift() -> void:
	_dream_halls_is_not_a_gift("modern_mana_burn")


func test_dream_halls_is_not_a_gift_under_the_1997_rules() -> void:
	_dream_halls_is_not_a_gift("fifth")


func test_dream_halls_is_cast_when_it_serves_us() -> void:
	var ai := _ai()
	for n in ["Island", "Island", "Island", "Mountain", "Mountain"]:
		put_battlefield(0, n)
	var halls := give_hand(0, "Dream Halls")
	# Two dear blue spells we cannot pay for, each paid by discarding the
	# other's spare blue card: the grant is our engine.
	give_hand(0, "Mahamoti Djinn")
	give_hand(0, "Mahamoti Djinn")
	give_hand(0, "Counterspell")
	give_hand(1, "Jackal Pup")
	put_battlefield(1, "Nurturing Licid")
	advance_to_step(Mtg.Step.MAIN1)
	assert_gt(TS.grant_uses(g, ai, halls), 1, "both Djinns would come through its row")
	assert_null(TS.casting_grant_choice(g, ai, halls), "ours beats their one card")


func test_dream_halls_waits_on_an_empty_reading_only_when_they_hold_cards() -> void:
	var ai := _ai()
	var halls := _halls_board([])
	assert_null(TS.casting_grant_choice(g, ai, halls), "an empty hand across the table takes nothing")


func test_aluren_is_held_against_a_creature_deck_with_nothing_of_ours() -> void:
	var ai := _ai()
	for n in ["Forest", "Forest", "Forest", "Forest"]:
		put_battlefield(0, n)
	var aluren := give_hand(0, "Aluren")
	give_hand(0, "Craw Wurm")
	for k in 4: give_hand(1, "Mountain")
	put_battlefield(1, "Jackal Pup")
	put_battlefield(1, "Mogg Fanatic")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(TS.grant_uses(g, ai, aluren), 0, "a Craw Wurm is no creature of mana value 3 or less")
	var got: Variant = TS.spell_choice(g, ai, aluren, 0, 0)
	assert_true(got is Dictionary and (got as Dictionary).is_empty(), "held: %s" % [got])


func test_aluren_is_cast_into_our_own_hand_of_small_creatures() -> void:
	var ai := _ai()
	for n in ["Forest", "Forest", "Forest", "Forest"]:
		put_battlefield(0, n)
	var aluren := give_hand(0, "Aluren")
	for n in ["Grizzly Bears", "Llanowar Elves", "Elvish Archers", "Grizzly Bears"]:
		give_hand(0, n)
	give_hand(1, "Mountain")
	put_battlefield(1, "Jackal Pup")
	advance_to_step(Mtg.Step.MAIN1)
	assert_gte(TS.grant_uses(g, ai, aluren), 3)
	assert_null(TS.casting_grant_choice(g, ai, aluren))


# -------------------------------------------------------- fair play, gate --

func test_their_hidden_hand_and_the_libraries_move_nothing() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		var hand: Array = LICID_HAND if variant == 0 \
			else ["Island", "Island", "Swamp", "Swamp", "Forest"]
		var halls := _halls_board(hand)
		if variant == 1:
			g.players[0].library.reverse()
			g.players[1].library.reverse()
		var got: Variant = TS.casting_grant_choice(g, ai, halls)
		answers.append("null" if got == null else ("held" if (got as Dictionary).is_empty() else str(got)))
		after_each()
	assert_eq(answers[0], answers[1], "the identities of their hidden hand changed the reading")
	assert_eq(answers[0], "held")


func test_the_reading_leaves_the_game_as_it_found_it() -> void:
	var ai := _ai()
	var halls := _halls_board(LICID_HAND)
	var state := g.rng.state
	var board := g.players[0].battlefield.size()
	var hand := g.players[0].hand.size()
	TS.casting_grant_choice(g, ai, halls)
	TS.grant_uses(g, ai, halls)
	assert_eq(g.rng.state, state)
	assert_null(g.undo_log, "no search journal left open")
	assert_eq(halls.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].battlefield.size(), board)
	assert_eq(g.players[0].hand.size(), hand)
	assert_true(g.players[0].hand.has(halls))
	assert_eq(g.payment_rows(0, g.find_in_hand(0, "Whim of Volrath")).size(),
		CardRegistry.get_card("Whim of Volrath").modes.size() if CardRegistry.get_card("Whim of Volrath").is_modal() else 1,
		"no granted row left behind")


func test_the_null_arm_casts_as_before() -> void:
	var ai := _ai(false)
	var halls := _halls_board(LICID_HAND)
	assert_null(TS.spell_choice(g, ai, halls, 0, 0))
