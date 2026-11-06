extends GameTest
## Pack 10 (the Urza block), batch B4: the AI metadata the Legacy creature
## batch declares reaches the fair AI. Fleeting Image's return carries the
## `self_bounce` role (engine/ai/alliances_tactics.gd, Selenia's shape);
## Mother of Runes carries the `protection` role
## (engine/ai/homelands_tactics.gd) over every colour, and its colour hint
## names the colour of the opposing spell aimed at the creature. An
## opposing spell is answered from the public stack; the null arm (gate
## off) leaves the pilot as it was, and the answer does not move when the
## opponent's hidden hand changes (docs/fair-play.md).


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai

## P1 casts [param spell] at [param target] and passes: P0 (the AI) holds
## priority over it.
func _aimed_at(target: CardInstance, spell: String, color: int) -> CardInstance:
	assert_ok(g.pass_priority(0))
	var card := give_hand(1, spell)
	add_mana(1, color)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, card, [TargetRef.card(target)]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	return card


func test_the_ai_returns_fleeting_image_from_a_bolt() -> void:
	var ai := _ai()
	var image := put_battlefield(0, "Fleeting Image")
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	var bolt := _aimed_at(image, "Lightning Bolt", Mtg.ManaColor.R)
	assert_eq(ai.act(g), "activated Fleeting Image")
	resolve_stack()
	assert_eq(image.zone, Mtg.Zone.HAND)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)

func test_the_null_arm_lets_the_bolt_through_the_image() -> void:
	var ai := _ai(false)
	var image := put_battlefield(0, "Fleeting Image")
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	_aimed_at(image, "Lightning Bolt", Mtg.ManaColor.R)
	assert_ne(ai.act(g), "activated Fleeting Image")

func test_the_ai_mother_shields_its_creature_from_a_terror() -> void:
	var ai := _ai()
	put_battlefield(0, "Mother of Runes")
	var giant := put_battlefield(0, "Craw Wurm")
	var terror := _aimed_at(giant, "Terror", Mtg.ManaColor.B)
	assert_eq(ai.act(g), "activated Mother of Runes")
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.cur_protection, Mtg.ManaColor.B)
	assert_eq(terror.zone, Mtg.Zone.GRAVEYARD)

func test_the_null_arm_lets_the_terror_through() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Mother of Runes")
	var giant := put_battlefield(0, "Craw Wurm")
	_aimed_at(giant, "Terror", Mtg.ManaColor.B)
	assert_ne(ai.act(g), "activated Mother of Runes")

## The opponent's hidden hand is not read: two different hands, the same
## answer.
func test_the_answer_ignores_the_opponents_hidden_hand() -> void:
	var answers: Array[String] = []
	for filler in ["Grizzly Bears", "Shivan Dragon"]:
		before_each()
		var ai := _ai()
		put_battlefield(0, "Mother of Runes")
		var giant := put_battlefield(0, "Craw Wurm")
		give_hand(1, filler)
		_aimed_at(giant, "Terror", Mtg.ManaColor.B)
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1])
	assert_eq(answers[0], "activated Mother of Runes")
