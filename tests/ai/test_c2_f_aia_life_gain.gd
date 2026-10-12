extends GameTest
## LIFE GAIN IS WORTH WHAT IT IS NEEDED FOR (robustness campaign
## 2026-10-12, b5-6; [member AiProfile.forecasts_tactics]).
##
## A pure life-gain spell was priced at its printed worth or at X x 1.5 — a
## life point dearer than the AI's own price of a point of life — so Stream
## of Life went for one life at 20 with nothing across the table (six times
## in the 1997 enemy decks), and Healing Salve's "gain 3" at 19. Now the
## gain is priced at [method AiPlayer._life_price] for the life it is
## gained at, and nothing at all at full life with no creature of theirs to
## take it away. Gate off: the old prices. Read off the public board only.


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


## Forest + Swamp, Stream of Life (X = 1 at most) and an Onulet ({3}, not
## castable); [param threat] on their side, [param life] ours.
func _stream(on: bool, life: int, threat := "", their_hand: Array = []) -> Dictionary:
	before_each()
	var ai := _ai(on)
	g.players[0].life = life
	put_battlefield(0, "Forest")
	put_battlefield(0, "Swamp")
	var stream := give_hand(0, "Stream of Life")
	give_hand(0, "Onulet")
	put_battlefield(1, "Mountain")
	put_battlefield(1, "Mountain")
	if threat != "":
		put_battlefield(1, threat)
	for n in their_hand: give_hand(1, n)
	advance_to_step(Mtg.Step.MAIN1)
	var lines := _play_main(ai)
	return {"lines": lines, "cast": stream.zone != Mtg.Zone.HAND, "life": g.players[0].life}


func test_stream_of_life_is_not_spent_for_one_point_at_twenty() -> void:
	var on := _stream(true, 20)
	assert_false(bool(on["cast"]), "a card for 1 life at 20, nothing on their board (%s)" % [on["lines"]])
	var off := _stream(false, 20)
	assert_true(bool(off["cast"]), "gate off: the old price casts it (%s)" % [off["lines"]])


func test_it_is_cast_when_the_life_is_needed() -> void:
	var low := _stream(true, 5, "Hill Giant")
	assert_true(bool(low["cast"]), "5 life in front of a Hill Giant: the point is worth it (%s)" % [low["lines"]])


func test_life_below_twenty_with_a_threat_still_prices_the_gain() -> void:
	# Not a refusal of life gain: with a creature across the table the gain
	# keeps its price — the reaper's rate for the life it is gained at.
	var ai := _ai()
	g.players[0].life = 15
	put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	assert_almost_eq(ai._life_gain_worth(g, 4), 4.0 * ai._life_price(15), 0.0001)
	g.players[0].life = 20
	assert_gt(ai._life_gain_worth(g, 4), 0.0, "20 life, but a creature to take it away")


func test_full_life_and_an_empty_board_is_no_need() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai._life_gain_worth(g, 3), 0.0)
	g.players[0].life = 19
	assert_gt(ai._life_gain_worth(g, 3), 0.0, "below full life, gain is worth its price")


func test_healing_salve_gain_mode_at_full_life_waits() -> void:
	var ai := _ai()
	put_battlefield(0, "Plains")
	var salve := give_hand(0, "Healing Salve")
	advance_to_step(Mtg.Step.MAIN1)
	var lines := _play_main(ai)
	assert_eq(salve.zone, Mtg.Zone.HAND, "gain 3 at 20, nothing across the table (%s)" % [lines])


func test_their_hidden_hand_does_not_move_the_price() -> void:
	var seen: Array = []
	for their_hand in [[], ["Lightning Bolt", "Fireball"], ["Shivan Dragon"]]:
		seen.append(_stream(true, 20, "", their_hand)["lines"])
	assert_eq(seen[1], seen[0], "hidden burn changed the play")
	assert_eq(seen[2], seen[0], "a hidden Dragon changed the play")
