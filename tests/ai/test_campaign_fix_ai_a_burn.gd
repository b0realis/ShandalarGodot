extends GameTest
## THE WHOLE-GAME CAMPAIGN, fix-ai-a: BURN (2026-10-07). Pins for two
## hunt findings, each beside the gate's null arm ([member
## AiProfile.forecasts_tactics] off: the pilot as it was) and a
## hidden-information permutation (docs/fair-play.md: the opponent's
## unrevealed hand never changes the answer):
##  * w6-3 THE VOLLEY: two Lightning Bolts at a six-life opponent are
##    lethal together though neither is alone; the held-instant reading
##    asked one spell at a time and passed (main phase), or spent one on a
##    creature (their end step). Prevention on the table is read through
##    the engine's own prediction.
##  * w2-8 THE CLEANUP: an instant the hand-size discard would throw away
##    is fired first, and the discard ranks a card by how soon it can be
##    cast — a six-drop on two lands goes before a castable Bolt.


func _ai(profile: AiProfile = null, seat := 0) -> AiPlayer:
	var p := profile if profile != null else AiProfile.wizard()
	p.develops_late = false
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


func _null() -> AiProfile:
	var p := AiProfile.wizard()
	p.forecasts_tactics = false
	return p


## Act for seat 0 until it passes; the opponent passes back after each
## resolution so seat 0 keeps priority in the same step.
func _act_until_pass(ai: AiPlayer, limit := 12) -> Array:
	var did: Array = []
	for i in limit:
		if g.game_over:
			break
		var a := ai.act(g)
		did.append(a)
		if a == "pass" or a == "":
			break
		resolve_stack()
		if g.priority_player == 1 and not g.game_over:
			g.pass_priority(1)
	return did


func _two_bolts_board(their_hand: Array = []) -> Dictionary:
	var a := give_hand(0, "Lightning Bolt")
	var b := give_hand(0, "Lightning Bolt")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	var bears := put_battlefield(1, "Grizzly Bears")
	for card_name in their_hand:
		give_hand(1, String(card_name))
	g.players[1].life = 6
	return {"a": a, "b": b, "bears": bears}


func _to_their_end_step() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.END) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


# ------------------------------------------------------------ w6-3 volley --

func test_two_bolts_are_lethal_together_in_our_main_phase() -> void:
	var ai := _ai()
	_two_bolts_board()
	advance_to_step(Mtg.Step.MAIN1)
	var did := _act_until_pass(ai)
	assert_true(g.game_over and g.winner == 0,
		"two Bolts, two Mountains, opponent at 6: the game ends now (%s, life %d)" % [str(did), g.players[1].life])


func test_two_bolts_are_lethal_together_at_their_end_step() -> void:
	var ai := _ai()
	var board := _two_bolts_board()
	_to_their_end_step()
	var did := _act_until_pass(ai)
	assert_true(g.game_over and g.winner == 0,
		"the last moment before our untap: both Bolts at the face (%s, life %d)" % [str(did), g.players[1].life])
	assert_eq((board["bears"] as CardInstance).zone, Mtg.Zone.BATTLEFIELD,
		"no Bolt was spent on the Bears")


## The 1997 rules (mana burn): the same volley, paid exactly.
func test_two_bolts_are_lethal_together_under_fifth() -> void:
	g.rules.set_edition("fifth")
	var ai := _ai()
	_two_bolts_board()
	advance_to_step(Mtg.Step.MAIN1)
	var did := _act_until_pass(ai)
	# The 1997 damage windows may still be open over the last Bolt: the
	# life total is the measure.
	assert_lte(g.players[1].life, 0, "fifth: %s, life %d" % [str(did), g.players[1].life])
	assert_eq(g.players[0].life, 20, "no mana burned")


## The null arm: the pilot as it was — the Bolts are held in our main.
func test_gate_off_holds_the_bolts_in_our_main_phase() -> void:
	var ai := _ai(_null())
	_two_bolts_board()
	advance_to_step(Mtg.Step.MAIN1)
	var did := _act_until_pass(ai)
	assert_eq(did, ["pass"], "gate off: each Bolt alone is not lethal and is held")
	assert_eq(g.players[1].life, 6)


## One Bolt alone is not a volley: it is still held for its moment.
func test_one_bolt_short_of_lethal_is_still_held() -> void:
	var ai := _ai()
	give_hand(0, "Lightning Bolt")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	put_battlefield(1, "Grizzly Bears")
	g.players[1].life = 6
	advance_to_step(Mtg.Step.MAIN1)
	var did := _act_until_pass(ai)
	assert_eq(did, ["pass"])
	assert_eq(g.players[1].life, 6)


## A public prevention pool (Healing Salve's shield) is read: two Bolts
## against six life behind a 1-point shield deal five — not a volley.
func test_a_visible_prevention_shield_spoils_the_volley() -> void:
	var ai := _ai()
	_two_bolts_board()
	g.players[1].damage_prevention = 1
	advance_to_step(Mtg.Step.MAIN1)
	var did := _act_until_pass(ai)
	assert_eq(did, ["pass"], "five damage at six life behind a shield is no win")
	assert_false(g.game_over)


## Fair play: what the opponent HOLDS (unrevealed) does not move the volley.
func test_their_hidden_hand_does_not_change_the_volley() -> void:
	var lines: Array = []
	for their_hand in [[], ["Healing Salve"], ["Circle of Protection: Red", "Counterspell"]]:
		before_each()
		var ai := _ai()
		_two_bolts_board(their_hand)
		advance_to_step(Mtg.Step.MAIN1)
		lines.append(ai.act(g))
	assert_eq(lines[0], lines[1], "the hidden Healing Salve changed the first action")
	assert_eq(lines[0], lines[2], "the hidden Circle changed the first action")
	assert_string_contains(String(lines[0]), "Lightning Bolt")


## The volley spends the Bolts at the FACE even with a fine target on the
## table — the cast the action takes names the opponent.
func test_the_volley_aims_at_the_face() -> void:
	var ai := _ai()
	_two_bolts_board()
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Lightning Bolt")
	assert_false(g.stack.is_empty())
	if g.stack.is_empty():
		return
	var top: StackItem = g.stack.back()
	assert_true(top.targets.size() == 1 and top.targets[0].is_player and top.targets[0].player_id == 1,
		"the first Bolt of the volley goes at the opponent")


# ------------------------------------------------------------ w2-8 cleanup --

## Drive seat 0's own turn 1 to its end (seat 1 passes).
func _drive_own_turn(ai: AiPlayer) -> void:
	var guard := 0
	while g.turn_number == 1 and guard < 80:
		if g.priority_player == 0 or g.awaiting_attackers:
			var did := ai.act(g)
			if did == "":
				if g.priority_player == 0: g.pass_priority(0)
				elif g.awaiting_attackers: g.declare_attackers(0, [])
		else:
			g.pass_priority(g.priority_player)
		guard += 1


## The probe's board: eight cards at our own cleanup, two of them Bolts,
## two Mountains: no Bolt is discarded unused.
func test_cleanup_discards_the_six_drop_before_the_castable_bolt() -> void:
	for n in 2: put_battlefield(0, "Mountain")
	var wurms: Array = []
	for n in 6: wurms.append(give_hand(0, "Craw Wurm"))
	var a := give_hand(0, "Lightning Bolt")
	var b := give_hand(0, "Lightning Bolt")
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN2)
	_drive_own_turn(ai)
	assert_eq(a.zone == Mtg.Zone.GRAVEYARD and g.players[1].life == 20, false,
		"a Bolt was discarded unused")
	assert_eq(b.zone == Mtg.Zone.GRAVEYARD and g.players[1].life == 20, false,
		"a Bolt was discarded unused")
	var discarded := 0
	for w in wurms:
		if (w as CardInstance).zone == Mtg.Zone.GRAVEYARD: discarded += 1
	assert_eq(discarded + int(g.players[1].life < 20), 1,
		"one card went: a Craw Wurm the two lands cannot cast for four turns")


## The ranking itself, and its null arm.
func test_discard_ranks_by_castability() -> void:
	for n in 2: put_battlefield(0, "Mountain")
	give_hand(0, "Craw Wurm")
	var inc := give_hand(0, "Lightning Bolt")
	var ai := _ai()
	var out := ai.answer_discard(g, 0, 1)
	assert_eq(out.size(), 1)
	assert_eq(out[0].data.card_name, "Craw Wurm", "four turns from castable, the Wurm goes")
	var old := _ai(_null())
	assert_eq(old.answer_discard(g, 0, 1)[0], inc, "gate off: the printed value ranks (the old answer)")


## An instant the cleanup would throw away is fired first: seven Bears
## (castable) and a Bolt, eight cards, two Mountains — the Bolt goes at
## the face rather than into the graveyard unused.
func test_the_doomed_instant_is_fired_before_the_discard() -> void:
	for n in 2: put_battlefield(0, "Mountain")
	for n in 7: give_hand(0, "Grizzly Bears")
	var shock := give_hand(0, "Lightning Bolt")
	give_hand(1, "Healing Salve")
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN2)
	_drive_own_turn(ai)
	assert_eq(shock.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 17, "the Bolt was fired at the face before the cleanup")
	assert_eq(g.players[0].hand.size(), 7)


func test_gate_off_discards_the_doomed_instant() -> void:
	for n in 2: put_battlefield(0, "Mountain")
	for n in 7: give_hand(0, "Grizzly Bears")
	var shock := give_hand(0, "Lightning Bolt")
	var ai := _ai(_null())
	advance_to_step(Mtg.Step.MAIN2)
	_drive_own_turn(ai)
	assert_eq(shock.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20, "gate off: the Bolt is discarded, as before")
