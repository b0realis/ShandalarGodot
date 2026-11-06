extends GameTest
## Pack 10 (the Urza block), batch B2: the AI metadata the batch's cards
## declare. Every effect is typed (engine/ai/effect_intent.gd reads it) or
## carries an [member EffectBase.ai_role] for the Stage 4 policy; the
## shapes that already have a reader are read (Victimize's and Landslide's
## precondition `needs_own_permanent`, Persecute's aimed `discard`, the
## sweeps, the removal, the counters); Parch's mode picker reads the public
## board, and the AI pilot reveals from its own hand only.

const B2 := ["Flicker", "Scour", "Solidarity", "Donate", "Fatigue", "Quash", "Rescue",
	"Bubbling Muck", "Encroach", "Eradicate", "Soul Feast", "Landslide", "Reckless Abandon",
	"Sowing Salt", "Trumpet Blast", "Wake of Destruction", "Magnify", "Multani's Decree",
	"Plow Under", "Splinter", "Catastrophe", "Persecute", "Victimize", "Parch", "Pyromancy",
	"Jasmine Seer", "Scent of Jasmine", "Brine Seer", "Scent of Brine", "Nightshade Seer",
	"Scent of Nightshade", "Cinder Seer", "Scent of Cinder", "Ivy Seer", "Rofellos's Gift",
	"Scent of Ivy"]


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

func _effects(card_name: String) -> Array:
	var data := CardRegistry.get_card(card_name)
	var effects: Array = data.spell_effects.duplicate()
	for m in data.modes: effects.append_array(m["effects"])
	for ability in data.activated_abilities: effects.append_array(ability.effects)
	return effects

func _intent(card_name: String) -> EffectIntent:
	var data := CardRegistry.get_card(card_name)
	if data.is_modal(): return EffectIntent.read(data.modes[0]["effects"], card_name)
	if not data.spell_effects.is_empty(): return EffectIntent.read(data.spell_effects, card_name)
	return EffectIntent.read(data.activated_abilities[0].effects, card_name)


func test_every_b2_effect_is_typed_or_role_tagged() -> void:
	for card_name in B2:
		var effects := _effects(card_name)
		assert_false(effects.is_empty(), card_name)
		for e in effects:
			var intent := EffectIntent.read([e], card_name)
			assert_true(not intent.unknown or e.ai_role != &"",
				"%s: typed or role-tagged" % card_name)

func test_the_existing_readers_see_the_shapes() -> void:
	assert_true(_intent("Scour").removes)
	assert_true(_intent("Eradicate").removal_ignores_regeneration, "exile")
	assert_true(_intent("Quash").counters)
	assert_true(_intent("Wake of Destruction").removes)
	assert_not_null(_intent("Catastrophe").sweeper)
	assert_not_null(_intent("Multani's Decree").sweeper)
	assert_eq(_intent("Soul Feast").life_loss, 4)
	assert_eq(_intent("Soul Feast").life_gain, 4)
	assert_eq(_intent("Parch").damage, 2)
	assert_eq(_intent("Reckless Abandon").damage, 4)
	assert_true(_intent("Rescue").bounces)
	assert_eq(_intent("Encroach").discards, 1)
	assert_eq(_intent("Persecute").discards, 1)
	assert_not_null(EffectIntent.tactical_effect(CardRegistry.get_card("Trumpet Blast").spell_effects))
	assert_not_null(EffectIntent.tactical_effect(CardRegistry.get_card("Magnify").spell_effects))
	assert_not_null(EffectIntent.tactical_effect(CardRegistry.get_card("Solidarity").spell_effects))

func test_victimize_and_landslide_declare_what_they_need_on_the_battlefield() -> void:
	var victimize := _intent("Victimize")
	var landslide := _intent("Landslide")
	assert_true(victimize.needs_own.is_valid())
	assert_true(landslide.needs_own.is_valid())
	if not victimize.needs_own.is_valid() or not landslide.needs_own.is_valid(): return
	var bear := put_battlefield(0, "Grizzly Bears")
	var mountain := put_battlefield(0, "Mountain")
	assert_true(victimize.needs_own.call(bear))
	assert_false(victimize.needs_own.call(mountain))
	assert_true(landslide.needs_own.call(mountain))
	assert_false(landslide.needs_own.call(bear))


# --------------------------------------------------------- Parch's mode picker --

func test_parchs_mode_picker_takes_the_blue_creature_two_damage_would_not_kill() -> void:
	var data := CardRegistry.get_card("Parch")
	assert_true(data.ai_mode_picker.is_valid())
	if not data.ai_mode_picker.is_valid(): return
	assert_eq(int(data.ai_mode_picker.call(g, 0)), 0, "nothing blue: two to any target")
	put_battlefield(1, "Merfolk of the Pearl Trident")
	assert_eq(int(data.ai_mode_picker.call(g, 0)), 0, "a 1/1 dies to the two")
	put_battlefield(1, "Air Elemental")
	assert_eq(int(data.ai_mode_picker.call(g, 0)), 1, "a 4/4 blue flier needs the four")

func test_parchs_picker_ignores_our_own_blue_creatures() -> void:
	put_battlefield(0, "Air Elemental")
	var data := CardRegistry.get_card("Parch")
	assert_eq(int(data.ai_mode_picker.call(g, 0)), 0)


# ------------------------------------------------------------- the AI pilot --

## The AI reveals every card of the color from its own hand — the opponent's
## hidden hand changes nothing (docs/fair-play.md).
func test_the_ai_reveals_from_its_own_hand_whatever_the_opponent_holds() -> void:
	for on in [true, false]:
		var gained: Array[int] = []
		for their in [[], ["Serra Angel", "Savannah Lions", "Crusade"]]:
			before_each()
			_ai(on)
			for card_name in their: give_hand(1, card_name)
			give_hand(0, "Serra Angel")
			give_hand(0, "Savannah Lions")
			var scent := give_hand(0, "Scent of Jasmine")
			add_mana(0, Mtg.ManaColor.W)
			assert_ok(g.cast_spell(0, scent))
			resolve_stack()
			gained.append(g.players[0].life - 20)
		assert_eq(gained, [4, 4] as Array[int], "gate %s" % on)

## Catastrophe's choice, answered by the AI pilot, is the card's own
## board-trade hint (public board only).
func test_the_ai_answers_catastrophe_from_the_public_board() -> void:
	_ai()
	var wurm := put_battlefield(0, "Craw Wurm")
	for n in 3: put_battlefield(1, "Forest")
	give_hand(1, "Shivan Dragon")
	var card := give_hand(0, "Catastrophe")
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, card))
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_null(g.find_on_battlefield(1, "Forest"))
