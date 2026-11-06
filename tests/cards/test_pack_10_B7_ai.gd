extends GameTest
## Pack 10 (the Urza block), batch B7: the AI metadata the Aura batch
## declares reaches the fair AI. Fiery Mantle's and Shiv's Embrace's {R}
## carry the `pump_host` role (mir/_auras.gd HostPump), Fortitude's and
## Gaea's Embrace's regeneration is a typed RegenerateEffect, and Fertile
## Ground's bonus is described to the mana planner as one more mana of the
## land's own colour — which is also the colour question's hint, so the
## plan the AI made is the mana it gets. Its hint on a colorless land reads
## the chooser's own hand only (docs/fair-play.md).


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

func _enchant(pid: int, aura_name: String, host: CardInstance, mana: Array) -> CardInstance:
	var aura := give_hand(pid, aura_name)
	for m in mana: add_mana(pid, int(m))
	assert_ok(g.cast_spell(pid, aura, [TargetRef.card(host)]))
	resolve_stack()
	return aura


func test_the_aura_pumps_declare_pump_host() -> void:
	for card_name in ["Fiery Mantle", "Shiv's Embrace"]:
		var ability: ActivatedAbility = CardRegistry.get_card(card_name).activated_abilities[0]
		var intent := EffectIntent.read(ability.effects, card_name)
		assert_true(intent.pump_host, card_name)
		assert_false(intent.unknown, card_name)

func test_the_aura_regenerations_are_typed() -> void:
	for card_name in ["Fortitude", "Gaea's Embrace"]:
		var ability: ActivatedAbility = CardRegistry.get_card(card_name).activated_abilities[0]
		assert_true(ability.effects[0] is RegenerateEffect, card_name)

func test_the_ai_casts_a_two_drop_off_one_fertile_forest() -> void:
	var ai := _ai()
	var forest := put_battlefield(0, "Forest")
	_enchant(0, "Fertile Ground", forest, [Mtg.ManaColor.G, Mtg.ManaColor.C])
	var bears := give_hand(0, "Grizzly Bears")
	assert_eq(ai.act(g), "cast Grizzly Bears")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)

func test_without_the_aura_one_forest_casts_no_two_drop() -> void:
	var ai := _ai()
	put_battlefield(0, "Forest")
	give_hand(0, "Grizzly Bears")
	assert_ne(ai.act(g), "cast Grizzly Bears")

## The colour a colorless land's bonus takes comes from the chooser's own
## hand: the opponent's hidden hand changes, the answer does not.
func test_the_colorless_hint_ignores_the_opponents_hidden_hand() -> void:
	var answers: Array[int] = []
	for filler in ["Counterspell", "Lightning Bolt"]:
		before_each()
		_ai()
		var factory := put_battlefield(0, "Mishra's Factory")
		_enchant(0, "Fertile Ground", factory, [Mtg.ManaColor.G, Mtg.ManaColor.C])
		give_hand(0, "Terror")
		give_hand(1, filler)
		give_hand(1, filler)
		assert_ok(g.tap_for_mana(0, factory))
		var made := 0
		for color in Mtg.WUBRG:
			if g.players[0].mana_pool.amount_of(color) > 0: made = color
		answers.append(made)
	assert_eq(answers[0], answers[1])
	assert_eq(answers[0], Mtg.ManaColor.B, "the color its own Terror asks for")
