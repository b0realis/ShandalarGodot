extends GameTest
## Pack 9 (the Tempest block), batch B3: the sixteen Slivers of
## cards/sets/tmp/_slivers.gd and cards/sets/sth/_slivers.gd.
##
## Every grant is pinned the same way: both players' Slivers have it, the
## granting Sliver included; a non-Sliver does not; a Sliver entering
## later has it at once; it ends when the granting Sliver leaves. "All
## Sliver creatures" and "All Slivers" are told apart by a synthetic
## noncreature permanent with the Sliver type. Then each granted ability
## is used, by its own Sliver's controller, on that Sliver.

const SLIVERS := ["Armor Sliver", "Barbed Sliver", "Clot Sliver", "Heart Sliver",
	"Horned Sliver", "Mindwhip Sliver", "Mnemonic Sliver", "Muscle Sliver",
	"Talon Sliver", "Winged Sliver", "Acidic Sliver", "Crystalline Sliver",
	"Hibernation Sliver", "Sliver Queen", "Spined Sliver", "Victual Sliver"]

## The granted keyword of each keyword lord ("All Sliver creatures have …").
const KEYWORDS := {
	"Heart Sliver": Mtg.Keyword.HASTE,
	"Horned Sliver": Mtg.Keyword.TRAMPLE,
	"Talon Sliver": Mtg.Keyword.FIRST_STRIKE,
	"Winged Sliver": Mtg.Keyword.FLYING,
}

## The granted ability of each ability lord, and whether it reaches every
## Sliver ("All Slivers") or only the creatures ("All Sliver creatures").
const GRANTS := {
	"Armor Sliver": ["{2}: This creature gets +0/+1 until end of turn.", true],
	"Barbed Sliver": ["{2}: This creature gets +1/+0 until end of turn.", true],
	"Clot Sliver": ["{2}: Regenerate this permanent.", false],
	"Mindwhip Sliver": ["{2}, Sacrifice this permanent: Target player discards a card at random. Activate only as a sorcery.", false],
	"Mnemonic Sliver": ["{2}, Sacrifice this permanent: Draw a card.", false],
	"Acidic Sliver": ["{2}, Sacrifice this permanent: This permanent deals 2 damage to any target.", false],
	"Hibernation Sliver": ["Pay 2 life: Return this permanent to its owner's hand.", false],
	"Victual Sliver": ["{2}, Sacrifice this permanent: You gain 4 life.", false],
}

## Asks for the 1997 damage-prevention and regeneration windows.
class Windowed extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)


func _fresh() -> void:
	super.before_each()
	advance_to_step(Mtg.Step.MAIN1)


func _is_pending(c: CardData) -> bool:
	return c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"


## A noncreature permanent with the Sliver type: "All Slivers" reaches it,
## "All Sliver creatures" does not.
static func _totem() -> CardData:
	return CardData.new("Synthetic Sliver Totem", "{1}", Mtg.CardType.ARTIFACT).with_subtypes(["sliver"])


## The index of the ability with [param text] on [param inst], or -1.
func _index(inst: CardInstance, text: String) -> int:
	for i in inst.cur_activated_abilities.size():
		if inst.cur_activated_abilities[i].text == text: return i
	return -1


func _count(inst: CardInstance, text: String) -> int:
	var n := 0
	for ability in inst.cur_activated_abilities:
		if ability.text == text: n += 1
	return n


## Activate [param inst]'s ability [param text] for its controller with
## [param generic] colourless mana floating.
func _use(inst: CardInstance, text: String, generic: int, targets: Array = []) -> String:
	var pid := inst.controller_id
	g.priority_player = pid
	if generic > 0: add_mana(pid, Mtg.ManaColor.C, generic)
	var index := _index(inst, text)
	assert_ne(index, -1, "%s has \"%s\"" % [inst.data.card_name, text])
	return g.activate_ability(pid, inst, index, targets)


# ----------------------------------------------------------------- claimed --

func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in SLIVERS:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		assert_false(_is_pending(c), "%s is still pending" % card_name)
		assert_true(c.subtypes.has("sliver"), card_name)
	for card_name in KEYWORDS:
		for ability in CardRegistry.get_card(card_name).static_abilities:
			assert_true(ability.changes_abilities, "%s's grant is layer 6" % card_name)
	for card_name in GRANTS:
		for ability in CardRegistry.get_card(card_name).static_abilities:
			assert_true(ability.changes_abilities, "%s's grant is layer 6" % card_name)


# --------------------------------------------------------- keyword grants --

func test_keyword_slivers_grant_every_sliver_creature_on_both_sides() -> void:
	for lord_name in KEYWORDS:
		_fresh()
		var keyword: int = KEYWORDS[lord_name]
		var lord := put_battlefield(0, lord_name)
		var mine := put_battlefield(0, "Metallic Sliver")
		var theirs := put_battlefield(1, "Metallic Sliver")
		var bear := put_battlefield(0, "Grizzly Bears")
		var totem := put_synthetic(1, _totem())
		for sliver in [lord, mine, theirs]:
			assert_true(sliver.has_keyword(keyword), "%s: %s has it" % [lord_name, sliver])
		assert_false(bear.has_keyword(keyword), "%s: a bear is no Sliver" % lord_name)
		assert_false(totem.has_keyword(keyword), "%s: only Sliver creatures" % lord_name)
		var later := put_battlefield(1, "Metallic Sliver")
		assert_true(later.has_keyword(keyword), "%s: a Sliver entering later" % lord_name)
		g.return_to_hand(lord)
		for sliver in [mine, theirs, later]:
			assert_false(sliver.has_keyword(keyword), "%s: gone with the lord" % lord_name)


func test_heart_sliver_lets_a_new_sliver_attack_at_once() -> void:
	put_battlefield(0, "Heart Sliver")
	var fresh := put_battlefield(0, "Metallic Sliver", true)
	assert_eq(CombatState.attack_illegality(g, fresh, 1), "")
	run_combat([fresh.id])
	assert_eq(g.players[1].life, 19)


func test_talon_sliver_first_strike_wins_the_fight() -> void:
	put_battlefield(1, "Talon Sliver")
	var theirs := put_battlefield(1, "Metallic Sliver")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.add_counters(theirs, "+1/+1", 1)   # a 2/2 first striker
	run_combat([bear.id], {theirs.id: bear.id})
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the opponent's Sliver struck first")
	assert_eq(theirs.damage, 0)


func test_winged_sliver_flies_and_horned_sliver_tramples() -> void:
	put_battlefield(0, "Winged Sliver")
	put_battlefield(0, "Horned Sliver")
	var big := put_battlefield(0, "Metallic Sliver")
	g.add_counters(big, "+1/+1", 3)   # 4/4
	var bear := put_battlefield(1, "Grizzly Bears")
	var hawk := put_battlefield(1, "Ornithopter")
	assert_ne(CombatState.block_illegality(g, bear, big, 1), "", "a bear can't block a flyer")
	run_combat([big.id], {hawk.id: big.id})
	assert_eq(hawk.zone, Mtg.Zone.GRAVEYARD, "a flyer may block it")
	assert_eq(g.players[1].life, 18, "2 to the 0/2 Ornithopter, 2 trample over it")


# --------------------------------------------------------- Muscle Sliver --

func test_muscle_sliver_pumps_every_sliver_creature_on_both_sides() -> void:
	var lord := put_battlefield(0, "Muscle Sliver")
	var mine := put_battlefield(0, "Metallic Sliver")
	var theirs := put_battlefield(1, "Metallic Sliver")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_eq([lord.cur_power, lord.cur_toughness], [2, 2], "itself included")
	assert_eq([mine.cur_power, mine.cur_toughness], [2, 2])
	assert_eq([theirs.cur_power, theirs.cur_toughness], [2, 2])
	assert_eq([bear.cur_power, bear.cur_toughness], [2, 2], "unchanged")
	var second := put_battlefield(1, "Muscle Sliver")
	assert_eq([mine.cur_power, theirs.cur_power, second.cur_power], [3, 3, 3], "two lords, +2/+2")
	g.return_to_hand(lord)
	g.return_to_hand(second)
	assert_eq([mine.cur_power, mine.cur_toughness], [1, 1])


# -------------------------------------------------------- ability grants --

func test_ability_slivers_grant_every_sliver_on_both_sides() -> void:
	for lord_name in GRANTS:
		_fresh()
		var text: String = GRANTS[lord_name][0]
		var creatures_only: bool = GRANTS[lord_name][1]
		var lord := put_battlefield(0, lord_name)
		var mine := put_battlefield(0, "Metallic Sliver")
		var theirs := put_battlefield(1, "Metallic Sliver")
		var bear := put_battlefield(1, "Grizzly Bears")
		var totem := put_synthetic(0, _totem())
		for sliver in [lord, mine, theirs]:
			assert_eq(_count(sliver, text), 1, "%s: %s has it once" % [lord_name, sliver])
		assert_eq(_count(bear, text), 0, "%s: a bear is no Sliver" % lord_name)
		assert_eq(_count(totem, text), 0 if creatures_only else 1,
			"%s: %s" % [lord_name, "Sliver creatures only" if creatures_only else "every Sliver"])
		var later := put_battlefield(1, "Metallic Sliver")
		assert_eq(_count(later, text), 1, "%s: a Sliver entering later" % lord_name)
		var second := put_battlefield(1, lord_name)
		assert_eq(_count(mine, text), 2, "%s: two lords grant it twice" % lord_name)
		g.return_to_hand(lord)
		g.return_to_hand(second)
		for sliver in [mine, theirs, later, totem]:
			assert_eq(_count(sliver, text), 0, "%s: gone with the lords" % lord_name)


func test_armor_and_barbed_pump_the_sliver_that_activates() -> void:
	put_battlefield(0, "Armor Sliver")
	put_battlefield(0, "Barbed Sliver")
	var mine := put_battlefield(0, "Metallic Sliver")
	var theirs := put_battlefield(1, "Metallic Sliver")
	assert_refused(_use(theirs, GRANTS["Armor Sliver"][0], 0), "")
	assert_ok(_use(theirs, GRANTS["Armor Sliver"][0], 2))
	resolve_stack()
	assert_eq([theirs.cur_power, theirs.cur_toughness], [1, 2], "their Sliver, their activation")
	assert_eq([mine.cur_power, mine.cur_toughness], [1, 1])
	assert_ok(_use(mine, GRANTS["Barbed Sliver"][0], 2))
	assert_ok(_use(mine, GRANTS["Barbed Sliver"][0], 2))
	resolve_stack()
	assert_eq([mine.cur_power, mine.cur_toughness], [3, 1])
	advance_to_next_turn()
	assert_eq([mine.cur_power, theirs.cur_toughness], [1, 1], "until end of turn")


func test_clot_sliver_regenerates_the_sliver_that_activates() -> void:
	put_battlefield(1, "Clot Sliver")
	var mine := put_battlefield(0, "Metallic Sliver")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_eq(_index(bear, GRANTS["Clot Sliver"][0]), -1)
	assert_ok(_use(mine, GRANTS["Clot Sliver"][0], 2))
	resolve_stack()
	assert_eq(mine.regeneration_shields, 1)
	g.destroy(mine)
	g.check_state_based_actions()
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD, "regenerated, though the lord is theirs")
	assert_true(mine.tapped)
	assert_ok(_use(mine, GRANTS["Clot Sliver"][0], 2))
	resolve_stack()
	var wrath := give_hand(0, "Wrath of God")
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, wrath))
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "Wrath of God: it can't be regenerated")


func test_clots_granted_regeneration_works_in_the_1997_window() -> void:
	g.rules.set_preset("fifth")
	g.set_agent(0, Windowed.new())
	g.set_agent(1, Windowed.new())
	put_battlefield(0, "Clot Sliver")
	var mine := put_battlefield(0, "Metallic Sliver")
	var wurm := put_battlefield(1, "Craw Wurm")
	var ability: ActivatedAbility = mine.cur_activated_abilities[_index(mine, GRANTS["Clot Sliver"][0])]
	assert_true(ability.effects[0].is_regeneration)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [mine.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wurm.id: mine.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	var guard := 0
	while g.awaiting_damage_prevention and guard < 10:
		assert_ok(g.end_damage_prevention(g.priority_player))
		guard += 1
	assert_true(g.awaiting_regeneration, "the window opens for a regenerator")
	assert_ok(_use(mine, GRANTS["Clot Sliver"][0], 2))
	resolve_stack()
	guard = 0
	while (g.awaiting_regeneration or g.awaiting_damage_prevention) and guard < 10:
		assert_ok(g.end_damage_prevention(g.priority_player))
		guard += 1
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD, "regenerated")


func test_mindwhip_sliver_is_a_sorcery_speed_random_discard() -> void:
	put_battlefield(0, "Mindwhip Sliver")
	var mine := put_battlefield(0, "Metallic Sliver")
	var theirs := put_battlefield(1, "Metallic Sliver")
	give_hand(1, "Lightning Bolt")
	give_hand(1, "Giant Growth")
	var text: String = GRANTS["Mindwhip Sliver"][0]
	assert_ok(_use(mine, text, 2, [TargetRef.player(1)]))
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 1, "one card at random")
	assert_eq(g.players[1].graveyard.size(), 1)
	# Their Sliver, on our turn: not as a sorcery.
	assert_refused(_use(theirs, text, 2, [TargetRef.player(0)]), "sorcery")
	assert_eq(theirs.zone, Mtg.Zone.BATTLEFIELD)
	# Ours with something on the stack: not as a sorcery either.
	var other := put_battlefield(0, "Metallic Sliver")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	g.priority_player = 0
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_refused(_use(other, text, 2, [TargetRef.player(1)]), "sorcery")
	resolve_stack()


func test_mnemonic_sliver_draws_for_the_slivers_controller() -> void:
	put_battlefield(0, "Mnemonic Sliver")
	var theirs := put_battlefield(1, "Metallic Sliver")
	var before := g.players[1].hand.size()
	assert_ok(_use(theirs, GRANTS["Mnemonic Sliver"][0], 2))
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].hand.size(), before + 1, "its controller draws")
	assert_eq(g.players[0].hand.size(), 0)


func test_acidic_sliver_sacrifices_a_sliver_for_two_damage() -> void:
	put_battlefield(0, "Acidic Sliver")
	var mine := put_battlefield(0, "Metallic Sliver")
	var bear := put_battlefield(1, "Grizzly Bears")
	var text: String = GRANTS["Acidic Sliver"][0]
	assert_refused(_use(mine, text, 0, [TargetRef.card(bear)]), "")
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD, "a refused activation sacrifices nothing")
	assert_ok(_use(mine, text, 2, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "2 damage from the sacrificed Sliver")
	var theirs := put_battlefield(1, "Metallic Sliver")
	assert_ok(_use(theirs, text, 2, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 18, "their Sliver burns us")


func test_victual_sliver_sacrifices_a_sliver_for_four_life() -> void:
	var lord := put_battlefield(1, "Victual Sliver")
	assert_ok(_use(lord, GRANTS["Victual Sliver"][0], 2))
	resolve_stack()
	assert_eq(lord.zone, Mtg.Zone.GRAVEYARD, "the lord can sacrifice itself")
	assert_eq(g.players[1].life, 24)


func test_hibernation_sliver_bounces_the_sliver_that_pays() -> void:
	put_battlefield(0, "Hibernation Sliver")
	var mine := put_battlefield(0, "Metallic Sliver")
	var theirs := put_battlefield(1, "Metallic Sliver")
	var text: String = GRANTS["Hibernation Sliver"][0]
	assert_eq(mine.cur_activated_abilities[_index(mine, text)].effects[0].ai_role, &"self_bounce")
	assert_ok(_use(theirs, text, 0))
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.HAND)
	assert_true(g.players[1].hand.has(theirs), "its owner's hand")
	assert_eq(g.players[1].life, 18, "its controller paid")
	g.adjust_life(0, -19)
	assert_refused(_use(mine, text, 0), "")
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD, "one life can't pay two")
	g.adjust_life(0, 2)
	assert_ok(_use(mine, text, 0))
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].life, 1)


func test_hibernation_in_response_saves_a_sliver_from_removal() -> void:
	put_battlefield(1, "Hibernation Sliver")
	var theirs := put_battlefield(1, "Metallic Sliver")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(theirs)]))
	assert_ok(_use(theirs, GRANTS["Hibernation Sliver"][0], 0))
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.HAND, "the Bolt lost its target")


# ---------------------------------------------------- Crystalline Sliver --

func test_crystalline_sliver_shrouds_every_sliver_from_everyone() -> void:
	var lord := put_battlefield(0, "Crystalline Sliver")
	var mine := put_battlefield(0, "Metallic Sliver")
	var theirs := put_battlefield(1, "Metallic Sliver")
	var bear := put_battlefield(1, "Grizzly Bears")
	var totem := put_synthetic(1, _totem())
	for sliver in [lord, mine, theirs, totem]:
		assert_true(sliver.cur_shroud, "%s has shroud" % sliver)
	assert_false(bear.cur_shroud)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.card(theirs)]))
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(0, growth, [TargetRef.card(mine)]), "")
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	g.return_to_hand(lord)
	assert_false(theirs.cur_shroud, "gone with the lord")
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(mine)]))
	resolve_stack()
	assert_eq(mine.cur_power, 4)


# ----------------------------------------------------------- Sliver Queen --

func test_sliver_queen_makes_colorless_sliver_tokens_the_lords_reach() -> void:
	var queen := put_battlefield(0, "Sliver Queen")
	put_battlefield(1, "Muscle Sliver")
	assert_true((queen.cur_supertypes & Mtg.Supertype.LEGENDARY) != 0)
	assert_refused(g.activate_ability(0, queen, 0, []), "")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, queen, 0, []))
	resolve_stack()
	var tokens: Array[CardInstance] = []
	for inst in g.players[0].battlefield:
		if inst.is_token: tokens.append(inst)
	assert_eq(tokens.size(), 1)
	var token := tokens[0]
	assert_true(token.has_subtype("sliver"))
	assert_true(token.is_creature())
	assert_eq(token.cur_colors, 0, "colorless")
	assert_eq([token.cur_power, token.cur_toughness], [2, 2], "their Muscle Sliver pumps it too")
	assert_eq(queen.cur_power, 8)


# ----------------------------------------------------------- Spined Sliver --

func test_spined_sliver_grows_a_blocked_sliver_per_blocker() -> void:
	put_battlefield(1, "Spined Sliver")   # theirs: it still sees our Slivers
	var mine := put_battlefield(0, "Metallic Sliver")
	var free := put_battlefield(0, "Metallic Sliver")
	var bear := put_battlefield(0, "Grizzly Bears")
	var b1 := put_battlefield(1, "Grizzly Bears")
	var b2 := put_battlefield(1, "Grizzly Bears")
	var b3 := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [mine.id, free.id, bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {b1.id: mine.id, b2.id: mine.id, b3.id: bear.id}))
	resolve_stack()
	assert_eq([mine.cur_power, mine.cur_toughness], [3, 3], "two blockers: +2/+2")
	assert_eq([free.cur_power, free.cur_toughness], [1, 1], "unblocked: nothing")
	assert_eq([bear.cur_power, bear.cur_toughness], [2, 2], "a bear is no Sliver")


func test_two_spined_slivers_trigger_twice_for_their_own_attacker() -> void:
	advance_to_next_turn()   # theirs
	var spined := put_battlefield(1, "Spined Sliver")
	put_battlefield(1, "Spined Sliver")
	var wall := put_battlefield(0, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [spined.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {wall.id: spined.id}))
	resolve_stack()
	assert_eq([spined.cur_power, spined.cur_toughness], [4, 4], "+1/+1 from each Spined Sliver")
	advance_to_next_turn()
	assert_eq([spined.cur_power, spined.cur_toughness], [2, 2], "until end of turn")
