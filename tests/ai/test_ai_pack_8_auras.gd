extends GameTest
## THE MIRAGE BLOCK'S AURAS, AIMED (Pack 8, 2026-10-03). An Aura nobody
## classified defaults to OUR OWN board ([method EffectIntent.aura_aim]),
## so every Pack 8 Aura was swept from its oracle text: the ones that hurt,
## hold or punish their host's controller are rows of
## [constant EffectIntent.AURA_HOSTILE] (Pacifism, Enfeeblement, Apathy,
## Thirst, Mortal Wound, Teferi's Curse ...), the rest are on the
## every-pack invariant's reviewed-friendly list
## (tests/cards/test_every_pack_invariants_2026_09_25.gd). The action:
## Pacifism goes on their best attacker and never on ours.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func _ai() -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func test_pacifism_goes_on_their_best_attacker() -> void:
	var ai := _ai()
	put_battlefield(0, "Plains")
	put_battlefield(0, "Plains")
	var ours := put_battlefield(0, "Serra Angel")
	put_battlefield(1, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")
	var pacifism := give_hand(0, "Pacifism")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Pacifism")
	resolve_stack()
	assert_eq(pacifism.attached_to, wurm.id, "their biggest body")
	assert_true(ours.attachments.is_empty())


func test_pacifism_never_goes_on_our_own() -> void:
	var ai := _ai()
	put_battlefield(0, "Plains")
	put_battlefield(0, "Plains")
	put_battlefield(0, "Serra Angel")
	var pacifism := give_hand(0, "Pacifism")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(pacifism.zone, Mtg.Zone.HAND, "nothing of theirs to hold: kept")


func test_the_sweep_aims_each_side() -> void:
	for name in ["Pacifism", "Enfeeblement", "Apathy", "Thirst", "Mortal Wound",
			"Teferi's Curse", "Betrayal", "Death Watch", "Mana Chains"]:
		assert_eq(EffectIntent.aura_aim(CardRegistry.get_card(name)), EffectIntent.Aim.HOSTILE, name)
	for name in ["Agility", "Armor of Thorns", "Mystic Veil", "Ward of Lights",
			"Spider Climb", "Fire Whip", "Vanishing", "Cloak of Invisibility"]:
		assert_eq(EffectIntent.aura_aim(CardRegistry.get_card(name)), EffectIntent.Aim.FRIENDLY, name)
