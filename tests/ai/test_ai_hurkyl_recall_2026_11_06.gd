extends GameTest
## HURKYL'S RECALL AT AN EMPTY BOARD (the owner's report, 2026-11-06): "ai
## casts Hurkyl's Recall even if I don't have any artifacts on the table".
## The card described nothing of what it does, so the pilot priced it at its
## printed worth like any spell and cast it in its main phase at a player
## who owned no artifact. It now declares its shape
## (`player_artifact_bounce`) and is worth the artifacts the target owns
## ([method AiPlayer._player_artifact_bounce_worth], forecasts_tactics).


func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _islands(n := 3) -> void:
	for _i in n:
		put_battlefield(0, "Island")


func _cast_now(ai: AiPlayer, card: CardInstance) -> bool:
	advance_to_step(Mtg.Step.MAIN1)
	for _i in 4:
		if card.zone != Mtg.Zone.HAND:
			break
		ai.act(g)
	return card.zone != Mtg.Zone.HAND


func test_no_artifact_anywhere_keeps_it_in_hand() -> void:
	_islands()
	put_battlefield(1, "Grizzly Bears")
	var recall := give_hand(0, "Hurkyl's Recall")
	assert_false(_cast_now(_ai(), recall), "nothing to send home: Hurkyl's Recall stays in hand")


func test_only_our_own_artifact_keeps_it_in_hand() -> void:
	_islands()
	put_battlefield(0, "Jalum Tome")
	var recall := give_hand(0, "Hurkyl's Recall")
	assert_false(_cast_now(_ai(), recall), "their side owns no artifact: not cast for nothing")


func test_their_artifact_is_sent_home() -> void:
	_islands()
	var engine := put_battlefield(1, "Juggernaut")
	var recall := give_hand(0, "Hurkyl's Recall")
	var ai := _ai()
	assert_true(_cast_now(ai, recall), "their Juggernaut is worth the Recall")
	resolve_stack()
	assert_eq(engine.zone, Mtg.Zone.HAND, "and it went home")


func test_the_reading_ignores_their_hand() -> void:
	# Fair play: the worth reads the battlefield only — whatever they hold.
	for held in ["Juggernaut", "Grizzly Bears"]:
		super.before_each()
		_islands()
		give_hand(1, held)
		var recall := give_hand(0, "Hurkyl's Recall")
		assert_false(_cast_now(_ai(), recall), "%s in their hand changes nothing" % held)


func test_the_null_arm_casts_it_as_before() -> void:
	# With the gate off the pilot plays exactly as before the reading.
	_islands()
	var recall := give_hand(0, "Hurkyl's Recall")
	assert_true(_cast_now(_ai(false), recall), "gate off: priced at its printed worth, as before")
