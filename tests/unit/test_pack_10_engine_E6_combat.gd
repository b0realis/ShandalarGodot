extends GameTest
## COMBAT (Pack 10 engine package E6), pinned on synthetic cards:
##
## * WHO ASSIGNS — "Rather than the attacking player, you assign the
##   combat damage of each creature attacking you. You can divide that
##   creature's combat damage as you choose among any of the creatures
##   blocking it." (Defensive Formation): [member
##   MtgPlayer.assigns_attackers_damage], a static's live value written by
##   [method CombatState.defender_assigns_damage]. [method
##   MtgGame._collect_damage_requests] then hands each attacker's division
##   to the defending player, in any order — the defensive-banding path
##   (CR 510.1a-d, 702.22j; a trampler may be held on its blockers, CR
##   702.19c's "may").
## * COMPANIONS — "This creature can't attack unless a creature with
##   greater power also attacks" and its block twin (Okk): [member
##   CardInstance.cur_attack_companion] / [member
##   CardInstance.cur_block_companion], written by [method
##   CombatState.attack_companion] / [method CombatState.block_companion]
##   and checked as attackers and blockers are declared (CR 508.1c,
##   509.1b; powers as they are then). The AI's declaration repairs drop a
##   creature without its companion.
## * FORCED UNBLOCKED DAMAGE — "X target blocked creatures assign their
##   combat damage this turn as though they weren't blocked" (Outmaneuver):
##   [member CardInstance.cur_damage_as_unblocked_forced], bound to each
##   target until end of turn by [method
##   CombatState.assign_as_though_unblocked_this_turn]. All of its damage
##   goes to the defending player, no question asked; its blockers still
##   deal theirs, and it stays blocked (CR 509.1h, 510.1a-c).

const CombatDeclaration := preload("res://engine/core/combat_declaration.gd")
const F := preload("res://cards/sets/fem/_rules.gd")


## A seat that wants to be asked for every division — what HumanAgent does.
class PromptAgent extends DecisionAgent:
	func wants_to_assign_combat_damage() -> bool:
		return true


# ------------------------------------------------------------ the cards --

static func _creature(name: String, power: int, toughness: int,
		keywords: Array = [], cost := "{1}{G}") -> CardData:
	return CardData.new(name, cost, Mtg.CardType.CREATURE) \
		.pt(power, toughness).with_keywords(keywords)


static func _formation() -> CardData:
	return CardData.new("Test Formation", "{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(CombatState.defender_assigns_damage())


static func _okk(name := "Test Okk") -> CardData:
	return CardData.new(name, "{1}{R}", Mtg.CardType.CREATURE).pt(4, 4) \
		.static_ability(CombatState.attack_companion(CombatState.has_greater_power,
			"a creature with greater power",
			"This creature can't attack unless a creature with greater power also attacks.")) \
		.static_ability(CombatState.block_companion(CombatState.has_greater_power,
			"a creature with greater power",
			"This creature can't block unless a creature with greater power also blocks."))


## "All creatures have base power and toughness 1/1" WITHOUT Humility's
## ability loss — the companion predicate then compares the live 1/1s.
static func _equaliser() -> CardData:
	return CardData.new("Test Equaliser", "{2}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.base_pt_for(_any_creature, 1, 1,
			"All creatures have base power and toughness 1/1."))


static func _any_creature(_game: MtgGame, _source: CardInstance, inst: CardInstance) -> bool:
	return inst.is_creature()


## Outmaneuver's shape: "X target blocked creatures assign their combat
## damage this turn as though they weren't blocked."
static func _outmaneuver() -> CardData:
	var aim := F.Action.new(_outmaneuver_resolve,
		"X target blocked creatures assign their combat damage this turn as though they weren't blocked",
		TargetSpec.creature("target blocked creature").with_game_filter(CombatState.is_blocked_attacker))
	aim.x_targets()
	return CardData.new("Test Outmaneuver", "{X}{R}", Mtg.CardType.INSTANT).spell(aim)


static func _outmaneuver_resolve(game: MtgGame, source: CardInstance, _pid: int,
		t: TargetRef, _x: int) -> void:
	CombatState.assign_as_though_unblocked_this_turn(game, source, t.instance_id)


## "You may have this creature assign its combat damage as though it
## weren't blocked" (Thorn Elemental) — the OPTIONAL form.
static func _thorn() -> CardData:
	return _creature("Test Thorn", 4, 4) \
		.static_ability(StaticAbility.new(_may_bypass, "You may have this creature assign its combat damage as though it weren't blocked."))


static func _may_bypass(_game: MtgGame, source: CardInstance) -> void:
	source.cur_damage_as_unblocked = true


# ------------------------------------------------------------- helpers --

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)


func _to_blockers(attacker_ids: Array) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, attacker_ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)


## Attack with [param attacker], block it with [param blockers], and walk
## into the damage step.
func _blocked(attacker: CardInstance, blockers: Array) -> void:
	_to_blockers([attacker.id])
	var map := {}
	for b in blockers:
		map[(b as CardInstance).id] = attacker.id
	assert_ok(g.declare_blockers(1, map))


# ================================================ the defender assigns ==

func test_the_formation_hands_the_division_to_the_defender() -> void:
	g.set_agent(0, PromptAgent.new())
	g.set_agent(1, PromptAgent.new())
	put_synthetic(1, _formation())
	assert_true(g.players[1].assigns_attackers_damage, "a static's live value")
	assert_false(g.players[0].assigns_attackers_damage)
	var giant := put_battlefield(0, "Hill Giant")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	_blocked(giant, [a, b])
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_assignment)
	var request := g.damage_assignment_request()
	assert_eq(request.source, giant)
	assert_eq(int(request.assigner), 1, "the defending player assigns")
	assert_true(bool(request.free_order), "divided as the defender chooses")
	assert_refused(g.assign_combat_damage(0, {a.id: 3}), "not yours to assign")
	assert_ok(g.assign_combat_damage(1, {b.id: 3}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(a.zone, Mtg.Zone.BATTLEFIELD, "the defender kept this one alive")
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)


func test_without_it_the_attacker_assigns() -> void:
	g.set_agent(0, PromptAgent.new())
	var giant := put_battlefield(0, "Hill Giant")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	_blocked(giant, [a, b])
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	var request := g.damage_assignment_request()
	assert_eq(int(request.assigner), 0)
	assert_false(bool(request.free_order))


## The 2009-2024 order (CR 510.1c) binds the ATTACKING player only: the
## defender's division is free under every preset.
func test_the_defenders_division_ignores_the_assignment_order() -> void:
	g.rules.free_damage_assignment = false
	g.set_agent(1, PromptAgent.new())
	put_synthetic(1, _formation())
	var giant := put_battlefield(0, "Hill Giant")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	_blocked(giant, [a, b])
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_assignment)
	assert_ok(g.assign_combat_damage(1, {a.id: 1, b.id: 2}))


func test_both_presets_hand_it_over() -> void:
	for edition in ["modern", "fifth"]:
		before_each()
		g.rules.set_edition(edition)
		g.set_agent(1, PromptAgent.new())
		put_synthetic(1, _formation())
		var giant := put_battlefield(0, "Hill Giant")
		var a := put_battlefield(1, "Grizzly Bears")
		var b := put_battlefield(1, "Grizzly Bears")
		_blocked(giant, [a, b])
		advance_to_step(Mtg.Step.COMBAT_DAMAGE)
		assert_eq(int(g.damage_assignment_request().assigner), 1, edition)


## The agents' default answer for a free division piles the whole packet
## on the ONE body its owner minds losing least: a 4/4 that would kill both
## Bears lethal-first kills one.
func test_the_agent_default_spares_a_blocker() -> void:
	put_synthetic(1, _formation())
	var brute := put_synthetic(0, _creature("Test Brute", 4, 4))
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	_blocked(brute, [a, b])
	advance_to_step(Mtg.Step.COMBAT_END)
	var dead := int(a.zone == Mtg.Zone.GRAVEYARD) + int(b.zone == Mtg.Zone.GRAVEYARD)
	assert_eq(dead, 1, "one Bear survives the defender's division")


func test_the_attacker_kills_both_without_it() -> void:
	var brute := put_synthetic(0, _creature("Test Brute", 4, 4))
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	_blocked(brute, [a, b])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)


## CR 702.19c: trample lets the ASSIGNING player put the excess on the
## player; the defender may keep it all on the blocker instead.
func test_a_trampler_may_be_held_on_its_blocker() -> void:
	put_synthetic(1, _formation())
	var mammoth := put_battlefield(0, "War Mammoth")
	var elf := put_battlefield(1, "Llanowar Elves")
	_blocked(mammoth, [elf])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "nothing trampled over")
	assert_eq(elf.zone, Mtg.Zone.GRAVEYARD)


func test_the_human_defender_may_hold_a_trampler() -> void:
	g.set_agent(1, PromptAgent.new())
	put_synthetic(1, _formation())
	var mammoth := put_battlefield(0, "War Mammoth")
	var elf := put_battlefield(1, "Llanowar Elves")
	_blocked(mammoth, [elf])
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_assignment, "a trampler's excess is a question")
	assert_eq(int(g.damage_assignment_request().assigner), 1)
	assert_ok(g.assign_combat_damage(1, {elf.id: 3}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20)


func test_the_attacking_players_own_formation_changes_nothing() -> void:
	g.set_agent(0, PromptAgent.new())
	put_synthetic(0, _formation())
	var giant := put_battlefield(0, "Hill Giant")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	_blocked(giant, [a, b])
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_eq(int(g.damage_assignment_request().assigner), 0, "\"each creature attacking YOU\"")


func test_the_formation_leaving_returns_the_choice() -> void:
	var formation := put_synthetic(1, _formation())
	g.destroy(formation)
	g.recalculate()
	assert_false(g.players[1].assigns_attackers_damage, "rebuilt every pass")


## "You may have it assign its combat damage as though it weren't blocked"
## stays its controller's choice; declined, the division is the defender's.
func test_an_optional_bypass_under_the_formation() -> void:
	g.set_agent(0, PromptAgent.new())
	g.set_agent(1, PromptAgent.new())
	put_synthetic(1, _formation())
	var thorn := put_synthetic(0, _thorn())
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	_blocked(thorn, [a, b])
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	var request := g.damage_assignment_request()
	assert_eq(String(request.get("special", "")), "bypass")
	assert_eq(int(request.assigner), 0, "the bypass is its controller's")
	assert_eq(int(request.normal_assigner), 1, "the ordinary division is the defender's")
	# Declining: the whole packet to the blockers hands the division over.
	assert_ok(g.assign_combat_damage(0, {a.id: 4}))
	assert_true(g.awaiting_damage_assignment)
	assert_eq(int(g.damage_assignment_request().assigner), 1)
	assert_ok(g.assign_combat_damage(1, {b.id: 4}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(a.zone, Mtg.Zone.BATTLEFIELD, "the defender's division, not the attacker's")
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20)


func test_the_ai_reads_the_defenders_division() -> void:
	put_synthetic(1, _formation())
	var mammoth := put_battlefield(0, "War Mammoth")
	var elf := put_battlefield(1, "Llanowar Elves")
	_blocked(mammoth, [elf])
	var ai := AiPlayer.new(1, AiProfile.wizard())
	assert_eq(int(ai._declared_damage(g).get(mammoth.id, 0)), 0,
		"no spill when the defender divides")


# ========================================================= companions ==

func test_okk_cant_attack_alone() -> void:
	var okk := put_synthetic(0, _okk())
	assert_eq(okk.cur_attack_companion.size(), 1)
	assert_ne(CombatState.attack_illegality(g, okk, 1), "", "no other creature could attack")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [okk.id]), "greater power")
	assert_true(g.awaiting_attackers, "the refusal changed nothing")


func test_okk_cant_attack_without_its_companion() -> void:
	var okk := put_synthetic(0, _okk())
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Craw Wurm")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [okk.id]),
		"Test Okk can't attack unless a creature with greater power also attacks")
	assert_refused(g.declare_attackers(0, [okk.id, bear.id]),
		"Test Okk can't attack unless a creature with greater power also attacks")
	assert_true(g.awaiting_attackers)
	assert_true(g.combat.attackers.is_empty(), "the refusal changed nothing")


func test_okk_cant_attack_beside_smaller_creatures() -> void:
	var okk := put_synthetic(0, _okk())
	var bear := put_battlefield(0, "Grizzly Bears")
	var twin := put_synthetic(0, _creature("Test Four", 4, 4))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [okk.id, bear.id]), "greater power")
	assert_refused(g.declare_attackers(0, [okk.id, twin.id]), "greater power")
	assert_ok(g.declare_attackers(0, [bear.id]))


func test_okk_attacks_beside_a_bigger_creature() -> void:
	var okk := put_synthetic(0, _okk())
	var wurm := put_battlefield(0, "Craw Wurm")
	assert_eq(CombatState.attack_illegality(g, okk, 1), "")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [okk.id, wurm.id]))
	assert_true(g.combat.attackers.has(okk.id))


func test_a_tapped_companion_does_not_count() -> void:
	var okk := put_synthetic(0, _okk())
	var wurm := put_battlefield(0, "Craw Wurm")
	wurm.tapped = true
	assert_ne(CombatState.attack_illegality(g, okk, 1), "")


## Powers are compared as the attackers are declared (CR 508.1c): a pump
## first makes the Bears the bigger creature.
func test_powers_are_read_as_declared() -> void:
	var okk := put_synthetic(0, _okk())
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 5)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [okk.id, bear.id]))


func test_the_block_twin() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var okk := put_synthetic(1, _okk())
	var small := put_battlefield(1, "Llanowar Elves")
	var wurm := put_battlefield(1, "Craw Wurm")
	_to_blockers([bear.id])
	assert_refused(g.declare_blockers(1, {okk.id: bear.id}),
		"Test Okk can't block unless a creature with greater power also blocks")
	assert_refused(g.declare_blockers(1, {okk.id: bear.id, small.id: bear.id}), "greater power")
	assert_true(g.awaiting_blockers)
	assert_ok(g.declare_blockers(1, {okk.id: bear.id, wurm.id: bear.id}))


func test_the_block_feasibility() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var okk := put_synthetic(1, _okk())
	assert_ne(CombatState.block_illegality(g, okk, bear, 1), "", "nobody bigger to block beside it")
	var wurm := put_battlefield(1, "Craw Wurm")
	assert_eq(CombatState.block_illegality(g, okk, bear, 1), "")
	wurm.tapped = true
	assert_ne(CombatState.block_illegality(g, okk, bear, 1), "")


## Humility takes Okk's abilities away (CR 613.1f), its restriction with
## them: it attacks alone.
func test_humility_removes_the_restriction() -> void:
	CardPacks.set_enabled("pack-9", true)
	var okk := put_synthetic(0, _okk())
	put_battlefield(1, "Humility")
	assert_true(okk.cur_attack_companion.is_empty(), "no abilities, no restriction")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [okk.id]))


## An effect that only sets every creature to 1/1 leaves the ability: a
## 1/1 beside another 1/1 has no companion with greater power.
func test_equal_bodies_have_no_greater_companion() -> void:
	var okk := put_synthetic(0, _okk())
	var wurm := put_battlefield(0, "Craw Wurm")
	put_synthetic(1, _equaliser())
	assert_eq(okk.cur_power, 1)
	assert_eq(wurm.cur_power, 1)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [okk.id, wurm.id]), "greater power")


func test_the_attack_repair_drops_a_creature_without_its_companion() -> void:
	var okk := put_synthetic(0, _okk())
	var bear := put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(0, "Craw Wurm")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_eq(CombatDeclaration.repair_attacks(g, 0, [okk.id, bear.id]), [bear.id])
	assert_eq(CombatDeclaration.repair_attacks(g, 0, [okk.id]), [])
	var kept := CombatDeclaration.repair_attacks(g, 0, [okk.id, wurm.id])
	assert_eq(kept.size(), 2)
	assert_true(kept.has(okk.id) and kept.has(wurm.id))


## "Attacks this turn if able" beside the restriction (CR 508.1d): the most
## requirements are obeyed by sending the companion along too.
func test_a_required_okk_brings_a_companion() -> void:
	var okk := put_synthetic(0, _okk())
	var wurm := put_battlefield(0, "Craw Wurm")
	okk.must_attack_this_turn = true
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, []), "Test Okk")
	assert_refused(g.declare_attackers(0, [wurm.id]), "Test Okk")
	var repaired := CombatDeclaration.repair_attacks(g, 0, [])
	assert_true(repaired.has(okk.id) and repaired.has(wurm.id), "a volunteer joins it")
	assert_ok(g.declare_attackers(0, repaired))


func test_a_required_okk_alone_is_excused() -> void:
	var okk := put_synthetic(0, _okk())
	okk.must_attack_this_turn = true
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, []))


func test_the_block_repair_drops_a_creature_without_its_companion() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var okk := put_synthetic(1, _okk())
	var wurm := put_battlefield(1, "Craw Wurm")
	_to_blockers([bear.id])
	assert_eq(CombatDeclaration.repair_blocks(g, 1, {okk.id: bear.id}), {})
	var kept := CombatDeclaration.repair_blocks(g, 1, {okk.id: bear.id, wurm.id: bear.id})
	assert_eq(kept.size(), 2)


# ======================================================== Outmaneuver ==

func _outmaneuver_on(attackers: Array) -> CardInstance:
	var spell := give_synthetic(0, _outmaneuver())
	var refs: Array = []
	for a in attackers:
		refs.append(TargetRef.card(a))
	add_mana(0, Mtg.ManaColor.R, 1 + attackers.size())
	assert_ok(g.cast_spell(0, spell, refs, attackers.size()))
	resolve_stack()
	return spell


func test_a_blocked_creature_deals_its_damage_to_the_player() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	_blocked(giant, [bear])
	_outmaneuver_on([giant])
	assert_true(giant.cur_damage_as_unblocked_forced)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 17, "all three to the defending player")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "nothing assigned to its blocker")
	assert_eq(bear.damage, 0)
	assert_eq(giant.damage, 2, "the blocker still deals its damage")


func test_it_stays_blocked() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	_blocked(giant, [bear])
	_outmaneuver_on([giant])
	assert_true(g.combat.was_blocked(g.combat.band_of(giant.id)), "CR 509.1h")


func test_no_question_is_asked() -> void:
	g.set_agent(0, PromptAgent.new())
	g.set_agent(1, PromptAgent.new())
	var giant := put_battlefield(0, "Hill Giant")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Llanowar Elves")
	_blocked(giant, [a, b])
	_outmaneuver_on([giant])
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_false(g.awaiting_damage_assignment, "forced: no division to make")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 17)


func test_a_trampler_hits_for_all_of_it() -> void:
	var mammoth := put_battlefield(0, "War Mammoth")
	var wall := put_synthetic(1, _creature("Test Wall", 0, 6))
	_blocked(mammoth, [wall])
	_outmaneuver_on([mammoth])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 17)
	assert_eq(wall.damage, 0)


func test_the_bodyguard_does_not_take_a_blocked_creatures_damage() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	var guard := put_battlefield(1, "Veteran Bodyguard")
	_blocked(giant, [bear])
	_outmaneuver_on([giant])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 17, "only UNBLOCKED creatures' damage is the Bodyguard's")
	assert_eq(guard.damage, 0)


func test_the_formation_and_outmaneuver_together() -> void:
	g.set_agent(1, PromptAgent.new())
	put_synthetic(1, _formation())
	var giant := put_battlefield(0, "Hill Giant")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	_blocked(giant, [a, b])
	_outmaneuver_on([giant])
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_false(g.awaiting_damage_assignment, "nothing to divide among blockers")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 17)


func test_only_blocked_creatures_are_targets() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(0, "Grizzly Bears")
	var blocker := put_battlefield(1, "Grizzly Bears")
	_to_blockers([giant.id, bear.id])
	assert_ok(g.declare_blockers(1, {blocker.id: giant.id}))
	var spell := give_synthetic(0, _outmaneuver())
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(bear)], 1))
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(blocker)], 1))
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(giant)], 1))


func test_two_targets() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(0, "Grizzly Bears")
	var a := put_battlefield(1, "Llanowar Elves")
	var b := put_battlefield(1, "Llanowar Elves")
	_to_blockers([giant.id, bear.id])
	assert_ok(g.declare_blockers(1, {a.id: giant.id, b.id: bear.id}))
	_outmaneuver_on([giant, bear])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 15)


func test_it_wears_off_at_end_of_turn() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	_blocked(giant, [bear])
	_outmaneuver_on([giant])
	advance_to_next_turn()
	assert_false(giant.cur_damage_as_unblocked_forced)


func test_a_new_object_is_not_bound() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	_blocked(giant, [bear])
	_outmaneuver_on([giant])
	g.return_to_hand(giant)
	g.players[0].hand.erase(giant)
	g._put_on_battlefield(giant, 0)
	g.recalculate()
	assert_false(giant.cur_damage_as_unblocked_forced, "CR 400.7")


func test_a_search_rewinds_it() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var source := put_battlefield(0, "Mountain")
	var mark := g.make_mark()
	CombatState.assign_as_though_unblocked_this_turn(g, source, giant.id)
	assert_true(giant.cur_damage_as_unblocked_forced)
	g.unmake_to(mark)
	g.end_search()
	g.recalculate()
	assert_false(giant.cur_damage_as_unblocked_forced)


func test_the_ai_reads_forced_damage_as_landing() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	_blocked(giant, [bear])
	_outmaneuver_on([giant])
	var ai := AiPlayer.new(1, AiProfile.wizard())
	assert_eq(int(ai._declared_damage(g).get(giant.id, 0)), 3)
