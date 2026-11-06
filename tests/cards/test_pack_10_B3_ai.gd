extends GameTest
## Pack 10 (the Urza block), batch B3: the AI metadata the creature batch
## declares reaches the fair AI. Viashino Sandswimmer's flip carries the
## `self_bounce` role (engine/ai/alliances_tactics.gd): an opposing spell
## aimed at it is answered from the public stack — on a win it is back in
## hand, on a loss it is gone before the spell lands, and the spell is
## wasted either way. Elvish Piper's cheat carries Norwood Priestess's
## `green_creature_from_hand` reading (engine/ai/second_age_tactics.gd),
## which prices the green creature cards of the AI's own hand. The null arm
## (gate off) leaves the pilot as it was, and the answer does not move when
## the opponent's hidden hand changes (docs/fair-play.md).


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


func test_sandswimmer_declares_self_bounce() -> void:
	var e: EffectBase = CardRegistry.get_card("Viashino Sandswimmer").activated_abilities[0].effects[0]
	assert_eq(e.ai_role, &"self_bounce")

func test_the_ai_flips_its_sandswimmer_away_from_a_bolt() -> void:
	var ai := _ai()
	var swimmer := put_battlefield(0, "Viashino Sandswimmer")
	put_battlefield(0, "Mountain")
	var bolt := _aimed_at(swimmer, "Lightning Bolt", Mtg.ManaColor.R)
	assert_eq(ai.act(g), "activated Viashino Sandswimmer")
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_ne(swimmer.zone, Mtg.Zone.BATTLEFIELD, "returned or sacrificed before the Bolt")
	assert_eq(swimmer.damage, 0)

func test_the_null_arm_lets_the_bolt_through() -> void:
	var ai := _ai(false)
	var swimmer := put_battlefield(0, "Viashino Sandswimmer")
	put_battlefield(0, "Mountain")
	_aimed_at(swimmer, "Lightning Bolt", Mtg.ManaColor.R)
	assert_ne(ai.act(g), "activated Viashino Sandswimmer")

## The opponent's hidden hand is not read: two different hands, the same
## answer.
func test_the_answer_ignores_the_opponents_hidden_hand() -> void:
	var answers: Array[String] = []
	for filler in ["Grizzly Bears", "Shivan Dragon"]:
		before_each()
		var ai := _ai()
		var swimmer := put_battlefield(0, "Viashino Sandswimmer")
		put_battlefield(0, "Mountain")
		give_hand(1, filler)
		_aimed_at(swimmer, "Lightning Bolt", Mtg.ManaColor.R)
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1])
	assert_eq(answers[0], "activated Viashino Sandswimmer")


func test_piper_declares_the_creature_from_hand_reading() -> void:
	var e: EffectBase = CardRegistry.get_card("Elvish Piper").activated_abilities[0].effects[0]
	assert_eq(e.ai_role, &"green_creature_from_hand")

func test_the_ai_pipes_a_big_green_creature_in() -> void:
	var ai := _ai()
	var piper := put_battlefield(0, "Elvish Piper")
	put_battlefield(0, "Forest")
	var wurm := give_hand(0, "Craw Wurm")
	var guard := 0
	var acted := ""
	while acted != "activated Elvish Piper" and guard < 6 and g.priority_player == 0 and g.current_step() == Mtg.Step.MAIN1:
		acted = ai.act(g)
		guard += 1
	assert_eq(acted, "activated Elvish Piper")
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(piper.tapped)

func test_the_piper_null_arm_keeps_the_wurm_in_hand() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Elvish Piper")
	put_battlefield(0, "Forest")
	give_hand(0, "Craw Wurm")
	var guard := 0
	var seen: Array[String] = []
	while guard < 6 and g.priority_player == 0 and g.current_step() == Mtg.Step.MAIN1:
		var acted := ai.act(g)
		seen.append(acted)
		guard += 1
		if acted == "" or acted.begins_with("pass"):
			break
	assert_false(seen.has("activated Elvish Piper"))

## The Piper reading prices the AI's own hand only: two different opposing
## hands and library tops, the same first action.
func test_the_piper_answer_ignores_their_hidden_cards() -> void:
	var answers: Array[String] = []
	for filler in ["Grizzly Bears", "Shivan Dragon"]:
		before_each()
		var ai := _ai()
		put_battlefield(0, "Elvish Piper")
		put_battlefield(0, "Forest")
		give_hand(0, "Craw Wurm")
		give_hand(1, filler)
		g.put_from_hand_on_top_of_library(give_hand(1, filler))
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1])
