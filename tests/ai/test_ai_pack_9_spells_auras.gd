extends GameTest
## Pack 9 (the Tempest block), the fair AI's AURAS (stage 4, casting).
##
## 1. THE SIDE OF THE TABLE. The Pack 9 Auras that hurt, hold or punish
##    their host's controller are in [constant EffectIntent.AURA_HOSTILE]
##    (Torment's -3/-0, Contempt's bounce at end of combat, Volrath's
##    Curse's attack/block/activation ban, Shackles' "doesn't untap",
##    Paroxysm's upkeep coin of a top card); unclassified they aimed at
##    our own board, and Torment shrank our own best attacker.
## 2. THE DOWNSIDE CLAUSE. Tahngarth's Rage reads "+3/+0 as long as it's
##    attacking. Otherwise, it gets -2/-1": the pump reader saw the +3/+0
##    and the picker hung it on our own Llanowar Elves, which died to the
##    -1 toughness (CR 704.5f). The worst toughness change of the Aura is
##    now the one the toughness guard asks
##    ([method EffectIntent.aura_worst_toughness]).
## 3. SHADOW AS A GIFT. "Enchanted creature has shadow" is an attacker's
##    gift ([constant EffectIntent.AURA_GRANTS]): a creature with shadow
##    blocks only creatures with shadow (CR 702.28b), so a Wall gains
##    nothing from it.
## The gate is [member AiProfile.forecasts_tactics]; with it off the
## toughness guard is the pre-Pack-9 one. The opponent's hidden hand never
## moves a decision.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-9", true)
	super()


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


func _host_of(aura: CardInstance) -> CardInstance:
	return g.find_instance(aura.attached_to)


# ------------------------------------------------------- the side of the table --

func test_the_pack_9_punishers_aim_across_the_table() -> void:
	for card_name in ["Torment", "Contempt", "Volrath's Curse", "Shackles", "Paroxysm"]:
		var data := CardRegistry.get_card(card_name)
		assert_eq(EffectIntent.aura_aim(data), EffectIntent.Aim.HOSTILE, card_name)
		assert_true(EffectIntent.aura_is_classified(data), card_name)


func test_the_pack_9_gifts_stay_on_our_side() -> void:
	for card_name in ["Hero's Resolve", "Conviction", "Cunning", "Shimmering Wings",
			"Tahngarth's Rage", "Cursed Flesh", "Spinal Graft", "Maniacal Rage"]:
		assert_eq(EffectIntent.aura_aim(CardRegistry.get_card(card_name)),
			EffectIntent.Aim.FRIENDLY, card_name)


func test_torment_shrinks_their_attacker_not_ours() -> void:
	var ai := _ai()
	var ours := put_battlefield(0, "Hill Giant")
	var theirs := put_battlefield(1, "Grizzly Bears")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	var torment := give_hand(0, "Torment")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Torment")
	resolve_stack()
	assert_eq(_host_of(torment), theirs, "their Bears, not our Giant")
	assert_eq(ours.cur_power, 3)


func test_torment_ignores_their_hidden_hand() -> void:
	var picks: Array = []
	for hand in [["Lightning Bolt", "Shivan Dragon"], ["Forest"], []]:
		g = null
		before_each()
		var ai := _ai()
		put_battlefield(0, "Hill Giant")
		put_battlefield(1, "Grizzly Bears")
		put_battlefield(0, "Swamp")
		put_battlefield(0, "Swamp")
		var torment := give_hand(0, "Torment")
		for card_name in hand: give_hand(1, card_name)
		advance_to_step(Mtg.Step.MAIN1)
		ai.act(g)
		resolve_stack()
		var host := _host_of(torment)
		picks.append(host.data.card_name if host != null else "")
	assert_eq(picks, ["Grizzly Bears", "Grizzly Bears", "Grizzly Bears"])


# ---------------------------------------------------------- the downside clause --

func test_the_worst_toughness_of_tahngarths_rage_is_minus_one() -> void:
	assert_eq(EffectIntent.aura_worst_toughness(CardRegistry.get_card("Tahngarth's Rage")), -1)
	assert_eq(EffectIntent.aura_worst_toughness(CardRegistry.get_card("Hero's Resolve")), 5)
	assert_eq(EffectIntent.aura_worst_toughness(CardRegistry.get_card("Cursed Flesh")), -1)
	assert_eq(EffectIntent.aura_worst_toughness(CardRegistry.get_card("Shimmering Wings")), 0)


func test_tahngarths_rage_never_kills_our_own_x_1() -> void:
	var ai := _ai()
	var elves := put_battlefield(0, "Llanowar Elves")
	put_battlefield(0, "Mountain")
	var rage := give_hand(0, "Tahngarth's Rage")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	resolve_stack()
	assert_eq(rage.zone, Mtg.Zone.HAND, "-2/-1 when not attacking kills a 1/1")
	assert_eq(elves.zone, Mtg.Zone.BATTLEFIELD)


func test_tahngarths_rage_goes_on_a_body_that_survives_it() -> void:
	var ai := _ai()
	put_battlefield(0, "Llanowar Elves")
	var bears := put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Mountain")
	var rage := give_hand(0, "Tahngarth's Rage")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Tahngarth's Rage")
	resolve_stack()
	assert_eq(_host_of(rage), bears)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


func test_the_null_arm_keeps_the_old_guard() -> void:
	# Gate off: the pre-Pack-9 picker, which reads only the printed pump.
	var ai := _ai(false)
	put_battlefield(0, "Llanowar Elves")
	put_battlefield(0, "Mountain")
	var rage := give_hand(0, "Tahngarth's Rage")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_ne(rage.zone, Mtg.Zone.HAND, "the old reading casts it")


# ------------------------------------------------------------- shadow as a gift --

func test_has_shadow_is_an_attackers_gift() -> void:
	var cloak := CardData.new("Test Shade Cloak", "{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.oracle("Enchant creature\nEnchanted creature has shadow.")
	var gifts := EffectIntent.aura_gifts(cloak)
	assert_eq(gifts.size(), 1)
	assert_eq(int(gifts[0]["keyword"]), Mtg.Keyword.SHADOW)
	assert_true(bool(gifts[0]["attack_only"]))
	var wall := put_battlefield(0, "Wall of Stone")
	var bears := put_battlefield(0, "Grizzly Bears")
	assert_false(EffectIntent.aura_fits(cloak, wall), "a Wall gains nothing from shadow")
	assert_true(EffectIntent.aura_fits(cloak, bears))
