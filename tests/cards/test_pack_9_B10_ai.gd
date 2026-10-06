extends GameTest
## Pack 9 (the Tempest block), batch B10: the AI metadata the Stronghold
## batch declares reaches the fair AI. Hornet Cannon's Hornet carries the
## `hasty_token` role (a main-phase-one attacker), Conviction's return the
## `self_bounce` role (an opposing spell aimed at it is answered from the
## public stack), and the two token makers' bodies are visible to the
## planner (EffectIntent.makes_token). The null arm (gate off) leaves the
## pilot as it was, and the answer does not move when the opponent's
## hidden hand changes (docs/fair-play.md).


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

func _conviction_on_a_bear() -> CardInstance:
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Plains")
	var conviction := give_hand(0, "Conviction")
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(0, conviction, [TargetRef.card(bear)]))
	resolve_stack()
	return conviction


func test_the_token_makers_bodies_are_visible_to_the_planner() -> void:
	for card_name in ["Hornet Cannon", "Volrath's Laboratory"]:
		var ability: ActivatedAbility = CardRegistry.get_card(card_name).activated_abilities[0]
		var intent := EffectIntent.read(ability.effects, card_name)
		assert_false(intent.makes_token.is_empty(), card_name)
		assert_gt(int(intent.makes_token.get("toughness", 0)), 0, card_name)

func test_the_ai_fires_hornet_cannon_in_its_first_main_phase() -> void:
	var ai := _ai()
	put_battlefield(0, "Hornet Cannon")
	for _k in 3: put_battlefield(0, "Mountain")
	assert_eq(ai.act(g), "activated Hornet Cannon")

func test_the_null_arm_leaves_hornet_cannon_alone() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Hornet Cannon")
	for _k in 3: put_battlefield(0, "Mountain")
	assert_ne(ai.act(g), "activated Hornet Cannon")

func test_the_ai_saves_conviction_from_a_disenchant() -> void:
	var ai := _ai()
	var conviction := _conviction_on_a_bear()
	var disenchant := _aimed_at(conviction, "Disenchant", Mtg.ManaColor.W)
	assert_eq(ai.act(g), "activated Conviction")
	resolve_stack()
	assert_eq(conviction.zone, Mtg.Zone.HAND)
	assert_eq(disenchant.zone, Mtg.Zone.GRAVEYARD)

func test_the_null_arm_lets_the_disenchant_through() -> void:
	var ai := _ai(false)
	var conviction := _conviction_on_a_bear()
	_aimed_at(conviction, "Disenchant", Mtg.ManaColor.W)
	assert_ne(ai.act(g), "activated Conviction")

## The opponent's hidden hand is not read: two different hands, the same
## answer.
func test_the_answer_ignores_the_opponents_hidden_hand() -> void:
	var answers: Array[String] = []
	for filler in ["Grizzly Bears", "Shivan Dragon"]:
		before_each()
		var ai := _ai()
		var conviction := _conviction_on_a_bear()
		give_hand(1, filler)
		_aimed_at(conviction, "Disenchant", Mtg.ManaColor.W)
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1])
	assert_eq(answers[0], "activated Conviction")
