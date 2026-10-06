extends GameTest
## Pack 9 (the Tempest block), batch B3: the twelve licids and Volrath's
## Curse — cards/sets/tmp/_licids.gd, sth/_licids.gd, exo/_licids.gd.
##
## The licid machinery itself (the identity swap, the special action, the
## journal, copies, two activations) is Pack 9 E3's and is pinned on
## synthetic cards in tests/unit/test_pack_9_engine_E3_*.gd. Here: each
## real licid's printed costs, its Aura line doing nothing while it is a
## creature and working once it is an Aura, hostile and friendly hosts, and
## Volrath's Curse's three bans and its ignore action.

const LICIDS := {
	"Enraging Licid": ["{R}", "{R}"],
	"Leeching Licid": ["{B}", "{B}"],
	"Nurturing Licid": ["{G}", "{G}"],
	"Quickening Licid": ["{1}{W}", "{W}"],
	"Stinging Licid": ["{1}{U}", "{U}"],
	"Calming Licid": ["{W}", "{W}"],
	"Convulsing Licid": ["{R}", "{R}"],
	"Corrupting Licid": ["{B}", "{B}"],
	"Gliding Licid": ["{U}", "{U}"],
	"Tempting Licid": ["{G}", "{G}"],
	"Dominating Licid": ["{1}{U}{U}", "{U}"],
	"Transmogrifying Licid": ["{1}", "{1}"],
}

## Answers a card question with [member pick] when it is offered.
class Picker extends DecisionAgent:
	var pick: CardInstance
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		if candidates.has(pick): return pick
		return null if candidates.is_empty() else candidates[0]

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


## Activate [param licid]'s licid ability (index 0) onto [param host] with
## [param mana] floating for its controller, and resolve it.
func _onto(licid: CardInstance, host: CardInstance, mana: Array) -> void:
	var pid := licid.controller_id
	g.priority_player = pid
	for m in mana: add_mana(pid, int(m))
	assert_ok(g.activate_ability(pid, licid, 0, [TargetRef.card(host)]))
	resolve_stack()
	assert_true(g.is_licid_aura(licid), "%s became an Aura" % licid.data.card_name)
	assert_eq(licid.attached_to, host.id)


func _end(licid: CardInstance, mana: Array) -> void:
	var pid := licid.controller_id
	g.priority_player = pid
	for m in mana: add_mana(pid, int(m))
	assert_ok(g.end_licid_effect(pid, licid))
	assert_true(licid.is_creature(), "%s is a creature again" % licid.data.card_name)


func _rows(pid: int, kind: String) -> Array:
	var out: Array = []
	for row in g.special_actions(pid):
		if String(row["kind"]) == kind: out.append(row)
	return out


# ----------------------------------------------------------------- claimed --

func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	var names: Array = LICIDS.keys()
	names.append("Volrath's Curse")
	for card_name in names:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		assert_false(_is_pending(c), "%s is still pending" % card_name)


func test_every_licid_ability_is_the_e3_builder_with_its_printed_costs() -> void:
	for card_name in LICIDS:
		var c := CardRegistry.get_card(card_name)
		var costs: Array = LICIDS[card_name]
		assert_not_null(c.licid_ability, card_name)
		assert_eq(c.activated_abilities[0], c.licid_ability, "%s: the licid ability is ability 0" % card_name)
		assert_eq(c.licid_ability.cost.text, costs[0], card_name)
		assert_true(c.licid_ability.tap_cost, card_name)
		assert_eq(str(c.licid_end_cost), costs[1], card_name)
		assert_eq(c.licid_steals, card_name == "Dominating Licid", card_name)
		assert_true(c.is_creature(), "%s is printed a creature" % card_name)
		assert_false(c.is_aura(), "%s is no printed Aura" % card_name)
		assert_true(c.oracle_text.begins_with(c.licid_ability.text), "%s's text" % card_name)
	assert_true(CardRegistry.get_card("Transmogrifying Licid").is_type(Mtg.CardType.ARTIFACT))
	var curse := CardRegistry.get_card("Volrath's Curse")
	assert_true(curse.is_aura())
	assert_false(curse.ignore_effect_sacrifice.is_empty(), "the Curse can be ignored")
	assert_true(curse.activation_ban.is_valid())


func test_a_licid_that_is_a_creature_lends_its_aura_line_to_nobody() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	var licids: Array[CardInstance] = []
	for card_name in LICIDS:
		licids.append(put_battlefield(0, card_name))
	g.recalculate()
	for bear in [mine, theirs]:
		assert_eq([bear.cur_power, bear.cur_toughness], [2, 2])
		assert_true(bear.cur_keywords.is_empty(), "no haste, first strike, flying or fear")
		assert_false(bear.cur_cant_attack)
		assert_false(bear.cur_cant_block_filter.is_valid())
		assert_false(bear.cur_must_be_blocked)
		assert_false(bear.is_type(Mtg.CardType.ARTIFACT))
	assert_eq(theirs.controller_id, 1, "Dominating Licid steals nothing as a creature")
	for licid in licids:
		assert_true(licid.is_creature(), licid.data.card_name)
		assert_true(licid.cur_keywords.is_empty(), "%s has no keyword of its own" % licid.data.card_name)
		assert_eq(licid.cur_power, licid.data.power, "%s is its printed size" % licid.data.card_name)
	# Leeching Licid's upkeep trigger has no host to read: no damage.
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq([g.players[0].life, g.players[1].life], [20, 20])


# ------------------------------------------------------------ Enraging Licid --

func test_enraging_licid_gives_a_sick_creature_haste_until_the_effect_ends() -> void:
	var licid := put_battlefield(0, "Enraging Licid")
	var bear := put_battlefield(0, "Grizzly Bears", true)
	assert_ne(CombatState.attack_illegality(g, bear, 1), "", "a sick bear stays home")
	_onto(licid, bear, [Mtg.ManaColor.R])
	assert_true(licid.tapped, "{T} was part of the cost")
	assert_true(bear.has_keyword(Mtg.Keyword.HASTE))
	assert_eq(CombatState.attack_illegality(g, bear, 1), "")
	_end(licid, [Mtg.ManaColor.R])
	assert_false(bear.has_keyword(Mtg.Keyword.HASTE))
	assert_eq(licid.attached_to, -1)


func test_a_summoning_sick_licid_cannot_pay_its_tap_cost() -> void:
	var licid := put_battlefield(0, "Enraging Licid", true)
	var bear := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.activate_ability(0, licid, 0, [TargetRef.card(bear)]))
	assert_true(licid.is_creature())
	assert_eq(g.players[0].mana_pool.total(), 1, "a refused activation pays nothing")


func test_the_licid_works_the_same_under_both_presets() -> void:
	for preset in ["fifth", "modern"]:
		_fresh()
		g.rules.set_preset(preset)
		var licid := put_battlefield(0, "Enraging Licid")
		var bear := put_battlefield(0, "Grizzly Bears", true)
		_onto(licid, bear, [Mtg.ManaColor.R])
		assert_eq(CombatState.attack_illegality(g, bear, 1), "", "%s: haste" % preset)
		_end(licid, [Mtg.ManaColor.R])
		assert_false(licid.summoning_sick, "%s: no zone change, no new sickness" % preset)
		assert_true(licid.tapped, "%s: still tapped from its activation" % preset)


# ---------------------------------------------------------- Quickening Licid --

func test_quickening_licid_costs_one_and_white_and_gives_first_strike() -> void:
	var licid := put_battlefield(0, "Quickening Licid")
	var bear := put_battlefield(0, "Grizzly Bears")
	var blocker := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.activate_ability(0, licid, 0, [TargetRef.card(bear)]), "")
	assert_false(licid.tapped, "{W} alone does not pay {1}{W}")
	_onto(licid, bear, [Mtg.ManaColor.C])   # with the {W} still floating
	assert_true(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	run_combat([bear.id], {blocker.id: bear.id})
	assert_eq(blocker.zone, Mtg.Zone.GRAVEYARD, "first strike kills the blocker first")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.damage, 0)


# ------------------------------------------------- Gliding / Corrupting Licid --

func test_gliding_licid_gives_flying_and_ending_it_grounds_the_creature() -> void:
	var licid := put_battlefield(0, "Gliding Licid")
	var bear := put_battlefield(0, "Grizzly Bears")
	var ground := put_battlefield(1, "Grizzly Bears")
	_onto(licid, bear, [Mtg.ManaColor.U])
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	assert_ne(CombatState.block_illegality(g, ground, bear, 1), "", "a ground bear can't block a flyer")
	_end(licid, [Mtg.ManaColor.U])
	assert_eq(CombatState.block_illegality(g, ground, bear, 1), "")


func test_corrupting_licid_gives_fear() -> void:
	var licid := put_battlefield(0, "Corrupting Licid")
	var bear := put_battlefield(0, "Grizzly Bears")
	var green := put_battlefield(1, "Grizzly Bears")
	var black := put_battlefield(1, "Scathe Zombies")
	var thopter := put_battlefield(1, "Ornithopter")
	_onto(licid, bear, [Mtg.ManaColor.B])
	assert_true(bear.has_keyword(Mtg.Keyword.FEAR))
	assert_ne(CombatState.block_illegality(g, green, bear, 1), "")
	assert_eq(CombatState.block_illegality(g, black, bear, 1), "", "a black creature may block it")
	assert_eq(CombatState.block_illegality(g, thopter, bear, 1), "", "an artifact creature may block it")


# ------------------------------------------------ Calming / Convulsing Licid --

func test_calming_licid_on_their_creature_keeps_it_from_attacking_only() -> void:
	var licid := put_battlefield(0, "Calming Licid")
	var theirs := put_battlefield(1, "Hill Giant")
	var mine := put_battlefield(0, "Grizzly Bears")
	_onto(licid, theirs, [Mtg.ManaColor.W])
	assert_eq(licid.controller_id, 0, "the licid stays its controller's")
	assert_eq(theirs.controller_id, 1)
	assert_ne(CombatState.attack_illegality(g, theirs, 0), "", "enchanted creature can't attack")
	assert_eq(CombatState.block_illegality(g, theirs, mine, 1), "", "it still blocks")
	_end(licid, [Mtg.ManaColor.W])
	assert_eq(CombatState.attack_illegality(g, theirs, 0), "")


func test_convulsing_licid_on_their_creature_keeps_it_from_blocking_only() -> void:
	var licid := put_battlefield(0, "Convulsing Licid")
	var theirs := put_battlefield(1, "Hill Giant")
	var mine := put_battlefield(0, "Grizzly Bears")
	_onto(licid, theirs, [Mtg.ManaColor.R])
	assert_ne(CombatState.block_illegality(g, theirs, mine, 1), "", "enchanted creature can't block")
	assert_eq(CombatState.attack_illegality(g, theirs, 0), "", "it still attacks")
	run_combat([mine.id])
	assert_eq(g.players[1].life, 18, "the bear walks past the giant")


# ------------------------------------------------------------ Tempting Licid --

func test_tempting_licid_makes_every_able_creature_block_the_host() -> void:
	var licid := put_battlefield(0, "Tempting Licid")
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	_onto(licid, giant, [Mtg.ManaColor.G])
	assert_true(giant.cur_must_be_blocked)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {}), "")
	assert_refused(g.declare_blockers(1, {bear.id: giant.id}), "")
	assert_ok(g.declare_blockers(1, {bear.id: giant.id, wall.id: giant.id}))


# ------------------------------------------------------------ Leeching Licid --

func test_leeching_licid_pings_the_hosts_controller_at_their_upkeep_only() -> void:
	var licid := put_battlefield(0, "Leeching Licid")
	var theirs := put_battlefield(1, "Grizzly Bears")
	_onto(licid, theirs, [Mtg.ManaColor.B])
	advance_to_next_turn()   # theirs
	assert_eq(g.players[1].life, 19, "their upkeep")
	assert_eq(g.players[0].life, 20)
	advance_to_next_turn()   # ours: not the host controller's upkeep
	assert_eq(g.players[1].life, 19)
	g.priority_player = 0
	_end(licid, [Mtg.ManaColor.B])
	advance_to_next_turn()   # theirs again, the licid a creature
	assert_eq(g.players[1].life, 19, "an ended licid enchants nothing")


func test_leeching_licid_on_your_own_creature_pings_you() -> void:
	var licid := put_battlefield(0, "Leeching Licid")
	var mine := put_battlefield(0, "Grizzly Bears")
	_onto(licid, mine, [Mtg.ManaColor.B])
	advance_to_next_turn()
	assert_eq(g.players[1].life, 20)
	advance_to_next_turn()
	assert_eq(g.players[0].life, 19, "enchanted creature's controller is you")


# ------------------------------------------------------------ Stinging Licid --

func test_stinging_licid_burns_the_hosts_controller_whenever_it_taps() -> void:
	var licid := put_battlefield(0, "Stinging Licid")
	var theirs := put_battlefield(1, "Llanowar Elves")
	_onto(licid, theirs, [Mtg.ManaColor.U, Mtg.ManaColor.C])
	g.priority_player = 1
	assert_ok(g.tap_for_mana(1, theirs))
	resolve_stack()
	assert_eq(g.players[1].life, 18, "tapping it for mana")
	assert_eq(g.players[0].life, 20)
	g.untap_permanent(theirs)
	resolve_stack()
	assert_eq(g.players[1].life, 18, "untapping is not becoming tapped")


func test_stinging_licid_on_your_attacker_burns_you() -> void:
	var licid := put_battlefield(0, "Stinging Licid")
	var bear := put_battlefield(0, "Grizzly Bears")
	_onto(licid, bear, [Mtg.ManaColor.U, Mtg.ManaColor.C])
	run_combat([bear.id])
	assert_eq(g.players[0].life, 18, "attacking tapped it")
	assert_eq(g.players[1].life, 18)


# ----------------------------------------------------------- Nurturing Licid --

func test_nurturing_licid_regenerates_its_host() -> void:
	var licid := put_battlefield(0, "Nurturing Licid")
	var bear := put_battlefield(0, "Grizzly Bears")
	_onto(licid, bear, [Mtg.ManaColor.G])
	var ability: ActivatedAbility = licid.cur_activated_abilities[0]
	assert_eq(ability.text, "{G}: Regenerate enchanted creature.", "the licid ability is gone")
	assert_true(ability.effects[0].is_regeneration, "usable in the 1997 regeneration window")
	assert_eq(ability.effects[0].ai_role, &"regenerate_host")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, licid, 0, []))
	resolve_stack()
	assert_eq(bear.regeneration_shields, 1)
	g.destroy(bear)
	g.check_state_based_actions()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "regenerated")
	assert_true(bear.tapped)
	assert_eq(licid.attached_to, bear.id)


func test_nurturing_licid_ended_in_response_regenerates_nothing() -> void:
	var licid := put_battlefield(0, "Nurturing Licid")
	var bear := put_battlefield(0, "Grizzly Bears")
	_onto(licid, bear, [Mtg.ManaColor.G])
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, licid, 0, []))
	_end(licid, [Mtg.ManaColor.G])   # a special action: the ability waits below
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(bear.regeneration_shields, 0, "it enchants nothing as the ability resolves")
	assert_eq(licid.regeneration_shields, 0)


func test_nurturing_licid_sacrificed_in_response_still_regenerates_what_it_enchanted() -> void:
	var licid := put_battlefield(0, "Nurturing Licid")
	var bear := put_battlefield(0, "Grizzly Bears")
	_onto(licid, bear, [Mtg.ManaColor.G])
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, licid, 0, []))
	g.destroy(licid)   # gone before the ability resolves
	resolve_stack()
	assert_eq(licid.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.regeneration_shields, 1, "the creature it enchanted as it last existed")


func test_nurturing_licids_regeneration_finds_no_host_while_it_is_a_creature() -> void:
	var licid := put_battlefield(0, "Nurturing Licid")
	var bear := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, licid, 1, []))
	resolve_stack()
	assert_eq(licid.regeneration_shields, 0, "not \"regenerate this creature\"")
	assert_eq(bear.regeneration_shields, 0)


func test_nurturing_licid_regenerates_in_the_1997_window() -> void:
	g.rules.set_preset("fifth")
	g.set_agent(0, Windowed.new())
	g.set_agent(1, Windowed.new())
	var licid := put_battlefield(0, "Nurturing Licid")
	var bear := put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")
	_onto(licid, bear, [Mtg.ManaColor.G])
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wurm.id: bear.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	var guard := 0
	while g.awaiting_damage_prevention and guard < 10:
		assert_ok(g.end_damage_prevention(g.priority_player))
		guard += 1
	assert_true(g.awaiting_regeneration, "the window opens for a regenerator")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, licid, 0, []))
	resolve_stack()
	guard = 0
	while (g.awaiting_regeneration or g.awaiting_damage_prevention) and guard < 10:
		assert_ok(g.end_damage_prevention(g.priority_player))
		guard += 1
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "regenerated")


# ---------------------------------------------------------- Dominating Licid --

func test_dominating_licid_steals_its_host_until_the_effect_ends() -> void:
	var licid := put_battlefield(0, "Dominating Licid")
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_refused(g.activate_ability(0, licid, 0, [TargetRef.card(giant)]), "")
	assert_false(licid.tapped, "{U}{U} does not pay {1}{U}{U}")
	_onto(licid, giant, [Mtg.ManaColor.C])
	assert_eq(giant.controller_id, 0, "you control enchanted creature")
	assert_true(g.players[0].battlefield.has(giant))
	_end(licid, [Mtg.ManaColor.U])
	assert_eq(giant.controller_id, 1, "it goes home when the effect ends")


func test_a_dominated_creature_goes_home_when_the_licid_is_destroyed() -> void:
	var licid := put_battlefield(0, "Dominating Licid")
	var giant := put_battlefield(1, "Hill Giant")
	_onto(licid, giant, [Mtg.ManaColor.U, Mtg.ManaColor.U, Mtg.ManaColor.C])
	var disenchant := give_hand(1, "Disenchant")
	g.priority_player = 1
	add_mana(1, Mtg.ManaColor.W)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, disenchant, [TargetRef.card(licid)]))
	resolve_stack()
	assert_eq(licid.zone, Mtg.Zone.GRAVEYARD)
	assert_true(licid.data.is_creature(), "a creature card in the graveyard")
	assert_eq(giant.controller_id, 1)


# ------------------------------------------------------ Transmogrifying Licid --

func test_transmogrifying_licid_makes_its_host_a_bigger_artifact() -> void:
	var licid := put_battlefield(0, "Transmogrifying Licid")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_true(licid.is_type(Mtg.CardType.ARTIFACT), "an artifact creature")
	_onto(licid, bear, [Mtg.ManaColor.C])
	assert_false(licid.is_type(Mtg.CardType.ARTIFACT), "as an Aura it is an enchantment only")
	assert_true(bear.is_type(Mtg.CardType.ARTIFACT))
	assert_true(bear.is_creature())
	assert_eq([bear.cur_power, bear.cur_toughness], [3, 3])
	var shatter := give_hand(0, "Shatter")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, shatter, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "artifact removal reaches the host")
	assert_eq(licid.zone, Mtg.Zone.GRAVEYARD, "the Aura goes with it (CR 704.5m)")


func test_transmogrifying_licid_ends_through_its_special_action_row() -> void:
	var licid := put_battlefield(0, "Transmogrifying Licid")
	var bear := put_battlefield(0, "Grizzly Bears")
	_onto(licid, bear, [Mtg.ManaColor.C])
	var rows := _rows(0, "licid_end")
	assert_eq(rows.size(), 1)
	assert_eq(String(rows[0]["label"]), "Pay {1}: end Transmogrifying Licid's effect")
	assert_ne(g.special_action_refusal(0, rows[0]), "", "no mana, no end")
	assert_refused(g.take_special_action(0, rows[0]))
	assert_true(g.is_licid_aura(licid))
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.take_special_action(0, rows[0]))
	assert_true(licid.is_creature())
	assert_true(licid.is_type(Mtg.CardType.ARTIFACT), "its printed self again")
	assert_false(bear.is_type(Mtg.CardType.ARTIFACT))
	assert_eq([bear.cur_power, bear.cur_toughness], [2, 2])
	assert_true(g.stack.is_empty(), "a special action uses no stack")


func test_a_licid_whose_host_dies_goes_to_its_owners_graveyard() -> void:
	var licid := put_battlefield(0, "Gliding Licid")
	var bear := put_battlefield(1, "Grizzly Bears")
	_onto(licid, bear, [Mtg.ManaColor.U])
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(licid.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.players[0].graveyard.has(licid))
	assert_eq(licid.data, licid.printed_data, "a Gliding Licid card again")


# ----------------------------------------------------------- Volrath's Curse --

func _curse(host: CardInstance) -> CardInstance:
	var curse := give_hand(0, "Volrath's Curse")
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, curse, [TargetRef.card(host)]))
	resolve_stack()
	assert_eq(curse.attached_to, host.id)
	return curse


func test_volraths_curse_enchants_only_a_creature() -> void:
	var forest := put_battlefield(1, "Forest")
	var curse := give_hand(0, "Volrath's Curse")
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, curse, [TargetRef.card(forest)]))
	assert_eq(curse.zone, Mtg.Zone.HAND)


func test_volraths_curse_stops_attacking_blocking_and_activating() -> void:
	var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
	var mine := put_battlefield(0, "Grizzly Bears")
	_curse(sorcerer)
	assert_ne(CombatState.attack_illegality(g, sorcerer, 0), "", "can't attack")
	assert_ne(CombatState.block_illegality(g, sorcerer, mine, 1), "", "can't block")
	g.priority_player = 1
	assert_refused(g.activate_ability(1, sorcerer, 0, [TargetRef.player(0)]), "Volrath's Curse")
	assert_false(sorcerer.tapped)
	assert_eq(g.players[0].life, 20)


func test_volraths_curse_stops_mana_abilities_too() -> void:
	var elves := put_battlefield(1, "Llanowar Elves")
	_curse(elves)
	g.priority_player = 1
	assert_refused(g.tap_for_mana(1, elves))
	assert_false(elves.tapped)
	assert_eq(g.players[1].mana_pool.total(), 0)


func test_volraths_curse_is_ignored_for_the_turn_by_a_sacrifice() -> void:
	var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
	var land := put_battlefield(1, "Forest")
	var curse := _curse(sorcerer)
	assert_true(_rows(0, "ignore_effect").is_empty(), "the Curse's controller has nothing to ignore")
	assert_refused(g.ignore_static_effect(0, curse))
	var rows := _rows(1, "ignore_effect")
	assert_eq(rows.size(), 1, "offered to the enchanted creature's controller")
	var seat := Picker.new()
	seat.pick = land
	g.set_agent(1, seat)
	g.priority_player = 1
	assert_ok(g.take_special_action(1, rows[0]))
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD, "a permanent of their choice")
	assert_true(g.stack.is_empty())
	assert_eq(CombatState.attack_illegality(g, sorcerer, 0), "", "free this turn")
	assert_ok(g.activate_ability(1, sorcerer, 0, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 19)
	advance_to_next_turn()   # theirs: bound again
	assert_ne(CombatState.attack_illegality(g, sorcerer, 0), "")
	assert_eq(_rows(1, "ignore_effect").size(), 1, "and may be ignored again")


func test_volraths_curse_may_be_ignored_by_sacrificing_the_cursed_creature() -> void:
	var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
	var curse := _curse(sorcerer)
	g.priority_player = 1
	# The Sorcerer itself is a permanent they control: it can pay.
	var seat := Picker.new()
	seat.pick = sorcerer
	g.set_agent(1, seat)
	assert_ok(g.ignore_static_effect(1, curse))
	assert_eq(sorcerer.zone, Mtg.Zone.GRAVEYARD, "the only permanent they had")
	assert_eq(curse.zone, Mtg.Zone.GRAVEYARD, "and the Curse fell off with it")


func test_volraths_curse_returns_to_its_owners_hand() -> void:
	var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
	var curse := _curse(sorcerer)
	assert_refused(g.activate_ability(0, curse, 0, []), "")
	assert_eq(curse.zone, Mtg.Zone.BATTLEFIELD, "no {1}{U}, no return")
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, curse, 0, []))
	resolve_stack()
	assert_eq(curse.zone, Mtg.Zone.HAND)
	assert_eq(CombatState.attack_illegality(g, sorcerer, 0), "")
	assert_eq(curse.data.activated_abilities[0].effects[0].ai_role, &"return_self_to_hand")


func test_volraths_curse_under_both_presets() -> void:
	for preset in ["fifth", "modern"]:
		_fresh()
		g.rules.set_preset(preset)
		var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
		var land := put_battlefield(1, "Forest")
		var curse := _curse(sorcerer)
		g.priority_player = 1
		assert_refused(g.activate_ability(1, sorcerer, 0, [TargetRef.player(0)]), "Volrath's Curse")
		var seat := Picker.new()
		seat.pick = land
		g.set_agent(1, seat)
		assert_ok(g.ignore_static_effect(1, curse))
		assert_ok(g.activate_ability(1, sorcerer, 0, [TargetRef.player(0)]))
		resolve_stack()
		assert_eq(g.players[0].life, 19, preset)
