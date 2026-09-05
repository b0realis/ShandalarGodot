extends GameTest
## Wave-71 tests: Goblin Wizard (an until-EOT protection grant), Remove
## Enchantments (a three-group sweep), Reincarnation (a floating delayed
## dies-trigger), Sentinel (an INDEFINITE base-toughness set) and Backdraft
## (per-source damage amounts, the bookkeeping the ROADMAP owed).


## Says yes to everything, and picks a CARD by name where it can.
class EagerPicker extends DecisionAgent:
	var wanted := ""

	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String,
			_hint: bool) -> bool:
		return true

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		for inst in candidates:
			if inst.data.card_name == wanted:
				return inst
		return null if candidates.is_empty() else candidates[0]


func test_registry_loaded_wave71() -> void:
	for name in ["Goblin Wizard", "Remove Enchantments", "Reincarnation",
			"Sentinel", "Backdraft"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ---------------------------------------------------------- Goblin Wizard --

func test_goblin_wizard_cheats_a_goblin_into_play() -> void:
	var agent := EagerPicker.new()
	agent.wanted = "Goblin King"
	g.set_agent(0, agent)
	var wizard := put_battlefield(0, "Goblin Wizard")
	var king := give_hand(0, "Goblin King")
	give_hand(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, wizard, 0))
	resolve_stack()
	assert_eq(king.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(king.summoning_sick, "it entered properly")


func test_goblin_wizard_only_offers_goblins() -> void:
	g.set_agent(0, EagerPicker.new())
	var wizard := put_battlefield(0, "Goblin Wizard")
	var bear := give_hand(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, wizard, 0))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.HAND, "a bear is no Goblin")


func test_goblin_wizard_grants_protection_from_white() -> void:
	var wizard := put_battlefield(0, "Goblin Wizard")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, wizard, 1, [TargetRef.card(wizard)]))
	resolve_stack()
	assert_eq(wizard.cur_protection & Mtg.ManaColor.W, Mtg.ManaColor.W)
	# The protection really works: a white spell can no longer target it.
	var swords := give_hand(1, "Swords to Plowshares")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.W)
	assert_refused(g.cast_spell(1, swords, [TargetRef.card(wizard)]),
		"Illegal target")


func test_goblin_wizards_protection_ends_with_the_turn() -> void:
	var wizard := put_battlefield(0, "Goblin Wizard")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, wizard, 1, [TargetRef.card(wizard)]))
	resolve_stack()
	advance_to_next_turn()
	assert_eq(wizard.cur_protection & Mtg.ManaColor.W, 0)


# ----------------------------------------------------- Remove Enchantments --

func test_remove_enchantments_returns_your_own_and_kills_theirs() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var my_aura := put_battlefield(0, "Holy Strength")
	g.attach_aura_from_anywhere(my_aura, mine, 0)
	var their_aura := put_battlefield(1, "Weakness")
	g.attach_aura_from_anywhere(their_aura, mine, 1)
	var spell := give_hand(0, "Remove Enchantments")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, spell, []))
	resolve_stack()
	assert_eq(my_aura.zone, Mtg.Zone.HAND, "yours comes home")
	assert_eq(their_aura.zone, Mtg.Zone.GRAVEYARD, "theirs is destroyed")


func test_remove_enchantments_returns_your_own_enchantment() -> void:
	var moat := put_battlefield(0, "Moat")
	var spell := give_hand(0, "Remove Enchantments")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, spell, []))
	resolve_stack()
	assert_eq(moat.zone, Mtg.Zone.HAND)


func test_remove_enchantments_leaves_their_own_board_alone() -> void:
	var theirs := put_battlefield(1, "Grizzly Bears")
	var their_aura := put_battlefield(1, "Holy Strength")
	g.attach_aura_from_anywhere(their_aura, theirs, 1)
	var spell := give_hand(0, "Remove Enchantments")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, spell, []))
	resolve_stack()
	assert_eq(their_aura.zone, Mtg.Zone.BATTLEFIELD,
		"not yours, not on your permanent, not attacking")


# ------------------------------------------------------------ Reincarnation --

func test_reincarnation_raises_a_creature_when_the_target_dies() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var dead := give_hand(0, "Serra Angel")
	g.players[0].hand.erase(dead)
	dead.zone = Mtg.Zone.GRAVEYARD
	g.players[0].graveyard.append(dead)
	var spell := give_hand(0, "Reincarnation")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear)]))
	resolve_stack()
	g.destroy(bear)
	assert_eq(dead.zone, Mtg.Zone.BATTLEFIELD, "the Angel came back")


func test_reincarnation_pays_the_creatures_own_owner() -> void:
	var theirs := put_battlefield(1, "Grizzly Bears")
	var dead := give_hand(1, "Serra Angel")
	g.players[1].hand.erase(dead)
	dead.zone = Mtg.Zone.GRAVEYARD
	g.players[1].graveyard.append(dead)
	var spell := give_hand(0, "Reincarnation")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(theirs)]))
	resolve_stack()
	g.destroy(theirs)
	assert_eq(dead.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(dead.controller_id, 1, "under ITS OWNER's control")


func test_reincarnation_expires_at_end_of_turn() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var dead := give_hand(0, "Serra Angel")
	g.players[0].hand.erase(dead)
	dead.zone = Mtg.Zone.GRAVEYARD
	g.players[0].graveyard.append(dead)
	var spell := give_hand(0, "Reincarnation")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_next_turn()
	g.destroy(bear)
	assert_eq(dead.zone, Mtg.Zone.GRAVEYARD, "'this turn' has passed")


# ------------------------------------------------------------- Sentinel --

func test_sentinel_measures_the_creature_it_faces() -> void:
	var sentinel := put_battlefield(0, "Sentinel")
	var giant := put_battlefield(1, "Hill Giant")     # 3/3
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [sentinel.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: sentinel.id}))
	assert_ok(g.activate_ability(0, sentinel, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(sentinel.cur_toughness, 4, "1 plus the Giant's power")
	assert_eq(sentinel.cur_power, 1, "power is untouched")


func test_sentinels_measurement_lasts_indefinitely() -> void:
	var sentinel := put_battlefield(0, "Sentinel")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [sentinel.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: sentinel.id}))
	assert_ok(g.activate_ability(0, sentinel, 0, [TargetRef.card(giant)]))
	resolve_stack()
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(sentinel.cur_toughness, 4, "the effect lasts indefinitely")


func test_sentinel_refuses_a_creature_it_is_not_facing() -> void:
	var sentinel := put_battlefield(0, "Sentinel")
	var bystander := put_battlefield(1, "Hill Giant")
	assert_refused(g.activate_ability(0, sentinel, 0,
		[TargetRef.card(bystander)]), "Illegal target")


# ------------------------------------------------------------- Backdraft --

func test_backdraft_burns_for_half_a_sorcerys_damage() -> void:
	# p1 casts an Earthquake for 4, then p0 answers with Backdraft.
	var quake := give_hand(1, "Earthquake")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.R)
	add_mana(1, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(1, quake, [], 4))
	resolve_stack()
	assert_eq(g.players[0].life, 16)
	var backdraft := give_hand(0, "Backdraft")
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, backdraft, []))
	resolve_stack()
	# The Earthquake dealt 4 to each player: 8 total, halved to 4.
	assert_eq(g.players[1].life, 16 - 4)


func test_backdraft_does_nothing_without_a_burning_sorcery() -> void:
	var backdraft := give_hand(0, "Backdraft")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, backdraft, []))
	resolve_stack()
	assert_eq(g.players[1].life, 20)
	assert_eq(g.players[0].life, 20)


func test_damage_amounts_are_recorded_per_source() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(int(g.damage_dealt_this_turn.get(bolt.id, 0)), 3)
	advance_to_next_turn()
	assert_eq(int(g.damage_dealt_this_turn.get(bolt.id, 0)), 0,
		"the record is per-turn")
