extends GameTest
## Pack 9 bug pass (fix-licid; h4's unconfirmed note) — the two card-local
## [method CounterEffect.affects_spell] overrides, Hydroblast/Pyroblast's
## conditional counter (cards/sets/ice/_spells.gd ConditionalCounter) and
## Burnout's (cards/sets/all/_spells.gd), tested only the colour and so
## told the AI that a spell which CAN'T BE COUNTERED (Scragnoth, CR 101.2)
## would be. The engine already left such a spell on the stack (MtgGame.
## counter_spell); the AI read the override and threw the Blast away.
## Scragnoth is green, so the real case is a recoloured one (Chaoslace);
## Burnout's is pinned on a synthetic blue instant that can't be countered.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled(IceAgePack.ID, true)      # Hydroblast, Pyroblast
	CardPacks.set_enabled(AlliancesPack.ID, true)   # Burnout
	CardPacks.set_enabled("pack-9", true)           # Scragnoth
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai() -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


## To P1's first main phase, P1 holding priority.
func _to_their_main() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	g.priority_player = 1


## P1 casts Scragnoth and makes it red with Chaoslace, which resolves; P0
## then holds priority over the red Scragnoth spell.
func _red_scragnoth() -> CardInstance:
	_to_their_main()
	var scragnoth := give_hand(1, "Scragnoth")
	add_mana(1, Mtg.ManaColor.G, 6)
	assert_ok(g.cast_spell(1, scragnoth, []))
	var lace := give_hand(1, "Chaoslace")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, lace, [TargetRef.card(scragnoth)]))
	assert_ok(g.pass_priority(1))
	assert_ok(g.pass_priority(0))   # Chaoslace resolves
	assert_eq(lace.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.stack.size(), 1)
	assert_ne(scragnoth.cur_colors & Mtg.ManaColor.R, 0, "precondition: a red spell")
	g.priority_player = 1
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	return scragnoth


static func _blast_counter(blast: CardInstance) -> CounterEffect:
	return blast.data.modes[0]["effects"][0]


func test_hydroblast_does_not_affect_a_red_spell_that_cant_be_countered() -> void:
	var ai := _ai()
	var scragnoth := _red_scragnoth()
	var blast := give_hand(0, "Hydroblast")
	add_mana(0, Mtg.ManaColor.U)
	assert_false(_blast_counter(blast).affects_spell(scragnoth),
		"red, but it can't be countered")
	assert_null(ai._counter_spec(g, blast, TargetRef.card(scragnoth)), "no answer to it")
	ai.act(g)
	assert_eq(blast.zone, Mtg.Zone.HAND, "the Blast is kept")
	resolve_stack()
	assert_eq(scragnoth.zone, Mtg.Zone.BATTLEFIELD)


func test_hydroblast_still_affects_a_red_spell_that_can_be_countered() -> void:
	_to_their_main()
	var giant := give_hand(1, "Hill Giant")
	add_mana(1, Mtg.ManaColor.R, 4)
	assert_ok(g.cast_spell(1, giant, []))
	var blast := give_hand(0, "Hydroblast")
	assert_true(_blast_counter(blast).affects_spell(giant))
	var pyro := give_hand(0, "Pyroblast")
	assert_false(_blast_counter(pyro).affects_spell(giant), "Pyroblast: not blue")


## A blue instant that can't be countered — no such card in the pool.
static func _blue_instant(uncounterable: bool) -> CardData:
	var c := CardData.new("Synthetic Blue Instant", "{U}", Mtg.CardType.INSTANT) \
		.spell(DrawEffect.new(1))
	if uncounterable:
		c.with_cant_be_countered()
	return c


func test_burnout_does_not_affect_a_blue_instant_that_cant_be_countered() -> void:
	var ai := _ai()
	_to_their_main()
	var instant := give_synthetic(1, _blue_instant(true))
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, instant, []))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	var burnout := give_hand(0, "Burnout")
	add_mana(0, Mtg.ManaColor.R, 2)
	var effect: CounterEffect = burnout.data.spell_effects[0]
	assert_false(effect.affects_spell(instant), "blue, but it can't be countered")
	assert_null(ai._counter_spec(g, burnout, TargetRef.card(instant)))


func test_burnout_still_affects_a_blue_instant_that_can_be() -> void:
	_to_their_main()
	var instant := give_synthetic(1, _blue_instant(false))
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, instant, []))
	var burnout := give_hand(0, "Burnout")
	var effect: CounterEffect = burnout.data.spell_effects[0]
	assert_true(effect.affects_spell(instant))
