extends GameTest
## Pack 9 (the Tempest block), batch B4: the AI metadata the Tempest
## creature batch declares reaches the fair AI. Giant Crab's shroud,
## Selenia's return and Knight of Dawn's protection carry the
## `self_bounce` role (engine/ai/alliances_tactics.gd): an opposing spell
## aimed at them is answered from the public stack. The null arm (gate off)
## leaves the pilot as it was, and the answer does not move when the
## opponent's hidden hand changes (docs/fair-play.md).


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
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


func test_the_ai_shrouds_its_giant_crab_against_a_bolt() -> void:
	var ai := _ai()
	var crab := put_battlefield(0, "Giant Crab")
	put_battlefield(0, "Island")
	var bolt := _aimed_at(crab, "Lightning Bolt", Mtg.ManaColor.R)
	assert_eq(ai.act(g), "activated Giant Crab")
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(crab.damage, 0)

func test_the_null_arm_lets_the_bolt_through() -> void:
	var ai := _ai(false)
	var crab := put_battlefield(0, "Giant Crab")
	put_battlefield(0, "Island")
	_aimed_at(crab, "Lightning Bolt", Mtg.ManaColor.R)
	assert_ne(ai.act(g), "activated Giant Crab")

func test_the_ai_sends_selenia_home_from_a_bolt() -> void:
	var ai := _ai()
	var selenia := put_battlefield(0, "Selenia, Dark Angel")
	_aimed_at(selenia, "Lightning Bolt", Mtg.ManaColor.R)
	assert_eq(ai.act(g), "activated Selenia, Dark Angel")
	resolve_stack()
	assert_eq(selenia.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].life, 18)

func test_the_ai_knight_takes_protection_from_the_terrors_color() -> void:
	var ai := _ai()
	var knight := put_battlefield(0, "Knight of Dawn")
	put_battlefield(0, "Plains")
	put_battlefield(0, "Plains")
	var terror := _aimed_at(knight, "Terror", Mtg.ManaColor.B)
	assert_eq(ai.act(g), "activated Knight of Dawn")
	resolve_stack()
	assert_eq(terror.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(knight.cur_protection, Mtg.ManaColor.B)

## The opponent's hidden hand is not read: two different hands, the same
## answer.
func test_the_answer_ignores_the_opponents_hidden_hand() -> void:
	var answers: Array[String] = []
	for filler in ["Grizzly Bears", "Shivan Dragon"]:
		before_each()
		var ai := _ai()
		var crab := put_battlefield(0, "Giant Crab")
		put_battlefield(0, "Island")
		give_hand(1, filler)
		_aimed_at(crab, "Lightning Bolt", Mtg.ManaColor.R)
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1])
	assert_eq(answers[0], "activated Giant Crab")
