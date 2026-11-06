extends GameTest
## Pack 10 (the Urza block), batch B12: what the AI does with the batch's
## activations today. None of the batch's code reads anything hidden — the
## triggers read the public stack and board, the hint-free activations are
## priced by the shared EffectIntent reader — so these pin behaviour, not
## fairness: the AI does not throw away its Opal Acrolith creature with the
## free "{0}: becomes an enchantment", and never sculpts its own creature
## (today it does not activate Soul Sculptor at all — a Stage 4 policy item;
## when it does, the target must be the opponent's).

const W := Mtg.ManaColor.W
const G := Mtg.ManaColor.G


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

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


func test_the_ai_keeps_its_acrolith_a_creature() -> void:
	var acrolith := put_battlefield(0, "Opal Acrolith")
	g.continuous.add_type_change(acrolith.id, {"set_types": Mtg.CardType.CREATURE,
		"set_subtypes": ["soldier"]})
	g.continuous.add_until_eot_base_pt(acrolith.id, 2, 4, false, ContinuousEffects.Duration.INDEFINITE)
	g.recalculate()
	var ai := _ai()
	for k in 3:
		var did := ai.act(g)
		resolve_stack()
		assert_true(acrolith.is_creature(), "step %d (%s): still a creature" % [k, did])


func test_the_ai_aims_soul_sculptor_at_the_opponent() -> void:
	var sculptor := put_battlefield(0, "Soul Sculptor")
	var mine := put_battlefield(0, "Serra Angel")
	var theirs := put_battlefield(1, "Craw Wurm")
	put_battlefield(0, "Plains")
	put_battlefield(0, "Plains")
	var ai := _ai()
	for k in 3:
		ai.act(g)
		resolve_stack()
	assert_true(mine.is_creature(), "never its own creature")
	if sculptor.tapped:
		assert_false(theirs.is_creature(), "the opponent's Wurm is the enchantment")
