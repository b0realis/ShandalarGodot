extends GameTest
## Pack 9 (the Tempest block), batch B9: the Stronghold creatures of
## cards/sets/sth/_creatures.gd — the en-Kor redirects (metered, onto a
## creature you control; Shaman en-Kor's whole-event redirect onto itself
## from a source chosen on resolution), Silver Wyvern's retarget of a spell
## or ability (Pack 9 E7), the counter costs, Revenant's CDA, Skeleton
## Scavengers' "regenerates this way" rider and the rest. Each test drives
## the card through the public API and pins the clause that makes it that
## card, with its refused case.

const CLAIMED := ["Carnassid", "Dungeon Shade", "Endangered Armodon", "Flowstone Hellion",
	"Flowstone Mauler", "Flowstone Shambler", "Furnace Spirit", "Honor Guard",
	"Lancers en-Kor", "Mindwarper", "Morgue Thrull", "Nomads en-Kor", "Revenant",
	"Shaman en-Kor", "Shard Phoenix", "Silver Wyvern", "Skeleton Scavengers",
	"Skyshroud Archer", "Spirit en-Kor", "Spitting Hydra", "Stronghold Assassin",
	"Stronghold Taskmaster", "Tidal Warrior", "Walking Dream", "Warrior en-Kor"]


## A seat whose answers a test scripts: yes/no (-1 follows the hint), an
## option index (-1 follows the hint) and card names to prefer (else the
## first, ranked candidate).
class Seat extends DecisionAgent:
	var yes := -1
	var option := -1
	var prefer: Array = []
	var asked: Array = []
	var window := false

	func wants_damage_prevention_window() -> bool:
		return window

	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return hint if yes < 0 else yes == 1

	func answer_option(_game: MtgGame, _pid: int, prompt: String,
			_options: Array[String], hint: int) -> int:
		asked.append(prompt)
		return hint if option < 0 else option

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		for name in prefer:
			for c in candidates:
				if c.data.card_name == name: return c
		return null if candidates.is_empty() else candidates[0]


var me: Seat
var foe: Seat


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	CardRegistry.ensure_loaded()
	super()
	me = Seat.new()
	foe = Seat.new()
	g.set_agent(0, me)
	g.set_agent(1, foe)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)


## Exactly the mana [param card]'s cost asks for.
func fund(pid: int, card: CardInstance) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	if cost.generic > 0:
		add_mana(pid, Mtg.ManaColor.C, cost.generic)

## P0 casts [param card_name] at [param targets] and resolves everything.
func cast(card_name: String, targets: Array = [], pid := 0) -> CardInstance:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	var card := give_hand(pid, card_name)
	fund(pid, card)
	assert_ok(g.cast_spell(pid, card, targets))
	resolve_stack()
	return card

## Pass until [param pid]'s upkeep of a LATER turn, its triggers waiting.
func _to_upkeep(pid: int) -> void:
	var start := g.turn_number
	var guard := 0
	while not g.game_over and guard < 800 and not (g.turn_number > start
			and g.active_player == pid and g.current_step() == Mtg.Step.UPKEEP):
		_advance_once()
		guard += 1
	assert_lt(guard, 800, "never reached the upkeep")

func _pt(i: CardInstance) -> Array:
	return [i.cur_power, i.cur_toughness]


func test_claimed_cards_are_no_longer_pending() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending",
			"%s is still pending" % card_name)


# --- the self-pumps -----------------------------------------------------------

func test_honor_guard_and_dungeon_shade_buy_their_pumps() -> void:
	var guard := put_battlefield(0, "Honor Guard")
	var shade := put_battlefield(0, "Dungeon Shade")
	assert_refused(g.activate_ability(0, guard, 0), "")
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.activate_ability(0, guard, 0))
	assert_ok(g.activate_ability(0, shade, 0))
	assert_ok(g.activate_ability(0, shade, 0))
	resolve_stack()
	assert_eq(_pt(guard), [1, 2])
	assert_eq(_pt(shade), [3, 3])
	assert_true(shade.has_keyword(Mtg.Keyword.FLYING))
	advance_to_next_turn()
	assert_eq(_pt(guard), [1, 1], "until end of turn")


func test_flowstone_hellion_trades_toughness_for_power_for_free() -> void:
	var hellion := put_battlefield(0, "Flowstone Hellion")
	assert_true(hellion.has_keyword(Mtg.Keyword.HASTE))
	assert_ok(g.activate_ability(0, hellion, 0))
	assert_ok(g.activate_ability(0, hellion, 0))
	resolve_stack()
	assert_eq(_pt(hellion), [5, 1])
	assert_ok(g.activate_ability(0, hellion, 0))
	resolve_stack()
	assert_eq(hellion.zone, Mtg.Zone.GRAVEYARD, "a 6/0 dies")


func test_flowstone_mauler_shambler_and_furnace_spirit_pay_red() -> void:
	var mauler := put_battlefield(0, "Flowstone Mauler")
	var shambler := put_battlefield(0, "Flowstone Shambler")
	var spirit := put_battlefield(0, "Furnace Spirit")
	assert_true(mauler.has_keyword(Mtg.Keyword.TRAMPLE))
	assert_true(spirit.has_keyword(Mtg.Keyword.HASTE))
	assert_refused(g.activate_ability(0, shambler, 0), "")
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ok(g.activate_ability(0, mauler, 0))
	assert_ok(g.activate_ability(0, shambler, 0))
	assert_ok(g.activate_ability(0, spirit, 0))
	resolve_stack()
	assert_eq(_pt(mauler), [5, 4])
	assert_eq(_pt(shambler), [3, 1])
	assert_eq(_pt(spirit), [2, 1])


# --- the en-Kor ----------------------------------------------------------------

func test_en_kor_moves_one_point_per_activation_onto_a_creature_you_control() -> void:
	var nomads := put_battlefield(0, "Nomads en-Kor")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	assert_refused(g.activate_ability(0, nomads, 0, [TargetRef.card(giant)]), "")
	for n in 3:
		assert_ok(g.activate_ability(0, nomads, 0, [TargetRef.card(bear)]))
	resolve_stack()
	cast("Lightning Bolt", [TargetRef.card(nomads)])
	assert_eq(nomads.zone, Mtg.Zone.BATTLEFIELD, "every point went elsewhere")
	assert_eq(nomads.damage, 0)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "three points on a 2/2")


func test_one_en_kor_point_leaves_the_rest_of_the_event_alone() -> void:
	var warrior := put_battlefield(0, "Warrior en-Kor")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, warrior, 0, [TargetRef.card(bear)]))
	resolve_stack()
	cast("Lightning Bolt", [TargetRef.card(warrior)])
	assert_eq(bear.damage, 1)
	assert_eq(warrior.zone, Mtg.Zone.GRAVEYARD, "the other two still kill a 2/2")


func test_every_en_kor_carries_the_redirect_and_its_printed_keyword() -> void:
	var lancers := put_battlefield(0, "Lancers en-Kor")
	var spirit := put_battlefield(0, "Spirit en-Kor")
	assert_true(lancers.has_keyword(Mtg.Keyword.TRAMPLE))
	assert_true(spirit.has_keyword(Mtg.Keyword.FLYING))
	for card_name in ["Lancers en-Kor", "Nomads en-Kor", "Spirit en-Kor", "Warrior en-Kor", "Shaman en-Kor"]:
		var ability: ActivatedAbility = CardRegistry.get_card(card_name).activated_abilities[0]
		assert_eq(ability.cost.mana_value(), 0, card_name)
		assert_true(ability.effects[0].is_damage_prevention, "%s works in the 1997 prevention window" % card_name)
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, spirit, 0, [TargetRef.card(bear)]))
	resolve_stack()
	cast("Lightning Bolt", [TargetRef.card(spirit)])
	assert_eq(bear.damage, 1)


## The 1997 damage-prevention step (fifth): the Giant's damage waits, and
## the en-Kor's redirect — a prevention-family ability — may be used inside
## the window, onto another creature of ours.
func test_en_kor_redirects_inside_the_1997_damage_prevention_window() -> void:
	g.rules.set_preset("fifth")
	g.rules.damage_prevention_window = true
	foe.window = true
	var giant := put_battlefield(0, "Hill Giant")
	var nomads := put_battlefield(1, "Nomads en-Kor")
	var wall := put_battlefield(1, "Wall of Wood")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {nomads.id: giant.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention, "the damage waits")
	if g.priority_player != 1:
		assert_ok(g.pass_priority(g.priority_player))
	for n in 3:
		assert_ok(g.activate_ability(1, nomads, 0, [TargetRef.card(wall)]))
	var guard := 0
	while (g.awaiting_damage_prevention or not g.stack.is_empty()) and guard < 30:
		if g.stack.is_empty():
			assert_ok(g.end_damage_prevention(g.priority_player))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_eq(nomads.zone, Mtg.Zone.BATTLEFIELD, "all three points went to the Wall")
	assert_eq(nomads.damage, 0)
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "three damage on a 0/3")


func test_shaman_en_kor_takes_the_chosen_sources_next_hit() -> void:
	var shaman := put_battlefield(0, "Shaman en-Kor")
	var bear := put_battlefield(0, "Grizzly Bears")
	var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
	me.prefer = ["Prodigal Sorcerer"]
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, shaman, 1, [TargetRef.card(bear)]))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, sorcerer, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.damage, 0, "the ping was dealt to the Shaman instead")
	assert_eq(shaman.damage, 1)
	# One event only, and only from that source: a Bolt still lands.
	cast("Lightning Bolt", [TargetRef.card(bear)])
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_true(CardRegistry.get_card("Shaman en-Kor").activated_abilities[1].effects[0].is_damage_prevention)


func test_shaman_en_kor_ignores_any_other_source() -> void:
	var shaman := put_battlefield(0, "Shaman en-Kor")
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Prodigal Sorcerer")
	me.prefer = ["Prodigal Sorcerer"]
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, shaman, 1, [TargetRef.card(bear)]))
	resolve_stack()
	cast("Lightning Bolt", [TargetRef.card(bear)])
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the Bolt was not the chosen source")
	assert_eq(shaman.damage, 0)


func test_shaman_en_kor_gone_means_the_damage_stays_where_it_was_aimed() -> void:
	var shaman := put_battlefield(0, "Shaman en-Kor")
	var bear := put_battlefield(0, "Grizzly Bears")
	var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
	me.prefer = ["Prodigal Sorcerer"]
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, shaman, 1, [TargetRef.card(bear)]))
	resolve_stack()
	cast("Lightning Bolt", [TargetRef.card(shaman)])
	assert_eq(shaman.zone, Mtg.Zone.GRAVEYARD)
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, sorcerer, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.damage, 1, "no Shaman to take it: dealt as aimed")


# --- Silver Wyvern -------------------------------------------------------------

func test_silver_wyvern_sends_a_bolt_aimed_at_it_to_another_creature() -> void:
	var wyvern := put_battlefield(0, "Silver Wyvern")
	var giant := put_battlefield(1, "Hill Giant")
	assert_true(wyvern.has_keyword(Mtg.Keyword.FLYING))
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(wyvern)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, wyvern, 0, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(wyvern.damage, 0)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "the Bolt hit the Giant")


func test_silver_wyvern_cannot_target_a_spell_aimed_elsewhere() -> void:
	var wyvern := put_battlefield(0, "Silver Wyvern")
	var giant := put_battlefield(1, "Hill Giant")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(giant)]))
	assert_refused(g.activate_ability(0, wyvern, 0, [TargetRef.card(bolt)]), "")
	assert_refused(g.activate_ability(0, wyvern, 0, [TargetRef.card(giant)]), "")


func test_silver_wyvern_retargets_an_ability_onto_a_creature_never_a_player() -> void:
	var wyvern := put_battlefield(0, "Silver Wyvern")
	var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, sorcerer, 0, [TargetRef.card(wyvern)]))
	var ping: StackItem = g.stack[-1]
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, wyvern, 0, [TargetRef.ability(ping)]))
	resolve_stack()
	assert_eq(wyvern.damage, 0)
	assert_eq(sorcerer.zone, Mtg.Zone.GRAVEYARD, "the only other creature took the ping")
	assert_eq(g.players[0].life, 20)
	assert_eq(g.players[1].life, 20)


func test_silver_wyvern_with_no_other_creature_changes_nothing() -> void:
	var wyvern := put_battlefield(0, "Silver Wyvern")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(wyvern)]))
	assert_ok(g.activate_ability(0, wyvern, 0, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(wyvern.zone, Mtg.Zone.GRAVEYARD, "no creature to move it to: the Bolt stays aimed at the 4/3 Wyvern")


# --- blue ----------------------------------------------------------------------

func test_tidal_warrior_makes_a_land_an_island_until_end_of_turn() -> void:
	var sick := put_battlefield(0, "Tidal Warrior", true)
	var forest := put_battlefield(1, "Forest")
	assert_refused(g.activate_ability(0, sick, 0, [TargetRef.card(forest)]), "")
	var warrior := put_battlefield(0, "Tidal Warrior")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_refused(g.activate_ability(0, warrior, 0, [TargetRef.card(bear)]), "")
	assert_ok(g.activate_ability(0, warrior, 0, [TargetRef.card(forest)]))
	resolve_stack()
	assert_true(forest.has_subtype("island"))
	assert_false(forest.has_subtype("forest"), "it loses its old land type")
	assert_ok(g.tap_for_mana(1, forest))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.U), 1)
	advance_to_next_turn()
	assert_true(forest.has_subtype("forest"))
	assert_false(forest.has_subtype("island"))


func test_walking_dream_cannot_be_blocked() -> void:
	var dream := put_battlefield(0, "Walking Dream")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [dream.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {bear.id: dream.id}), "")
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.players[1].life, 17)


func test_walking_dream_stays_tapped_while_an_opponent_has_two_creatures() -> void:
	var dream := put_battlefield(0, "Walking Dream")
	put_battlefield(1, "Grizzly Bears")
	var second := put_battlefield(1, "Llanowar Elves")
	run_combat([dream.id])
	assert_true(dream.tapped)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.active_player, 0)
	assert_true(dream.tapped, "two creatures across the table: no untap")
	# With one creature left it untaps at the next untap step.
	cast("Lightning Bolt", [TargetRef.card(second)])
	advance_to_next_turn()
	advance_to_next_turn()
	assert_false(dream.tapped)


# --- black ---------------------------------------------------------------------

func test_mindwarper_spends_its_counters_on_sorcery_speed_discards() -> void:
	var warper := put_battlefield(0, "Mindwarper")
	assert_eq(_pt(warper), [3, 3], "three +1/+1 counters on a 0/0")
	give_hand(1, "Forest")
	give_hand(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, warper, 0, [TargetRef.player(1)]))
	assert_eq(int(warper.counters.get("+1/+1", 0)), 2, "the counter is a cost")
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 1)
	assert_eq(_pt(warper), [2, 2])
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, warper, 0, [TargetRef.player(1)]), "sorcery")


func test_morgue_thrull_mills_its_controller_three() -> void:
	var thrull := put_battlefield(0, "Morgue Thrull")
	var library := g.players[0].library.size()
	var theirs := g.players[1].library.size()
	assert_ok(g.activate_ability(0, thrull, 0))
	assert_eq(thrull.zone, Mtg.Zone.GRAVEYARD, "the sacrifice is the cost")
	resolve_stack()
	assert_eq(g.players[0].library.size(), library - 3)
	assert_eq(g.players[1].library.size(), theirs)
	assert_eq(g.players[0].graveyard.size(), 4)


func test_revenant_counts_creature_cards_in_your_graveyard() -> void:
	var dead: Array = [give_hand(0, "Grizzly Bears"), give_hand(0, "Hill Giant"), give_hand(0, "Forest")]
	g.discard_cards(0, dead)
	var foreign := give_hand(1, "Craw Wurm")
	g.discard_cards(1, [foreign])
	var revenant := put_battlefield(0, "Revenant")
	assert_true(revenant.has_keyword(Mtg.Keyword.FLYING))
	assert_eq(_pt(revenant), [2, 2], "two creature cards; the Forest and their Wurm don't count")
	g.discard_cards(0, [give_hand(0, "Llanowar Elves")])
	g.recalculate()
	assert_eq(_pt(revenant), [3, 3])


func test_skeleton_scavengers_regenerates_for_its_counters_and_grows() -> void:
	var skeleton := put_battlefield(0, "Skeleton Scavengers")
	assert_eq(_pt(skeleton), [1, 1])
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, skeleton, 0, [], 0), "X must be 1")
	assert_refused(g.activate_ability(0, skeleton, 0, [], 2), "X must be 1")
	assert_ok(g.activate_ability(0, skeleton, 0, [], 1))
	resolve_stack()
	assert_eq(skeleton.regeneration_shields, 1)
	cast("Lightning Bolt", [TargetRef.card(skeleton)])
	assert_eq(skeleton.zone, Mtg.Zone.BATTLEFIELD, "regenerated")
	assert_true(skeleton.tapped)
	assert_eq(int(skeleton.counters.get("+1/+1", 0)), 2, "it regenerated this way: one more counter")
	assert_eq(_pt(skeleton), [2, 2])
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, skeleton, 0, [], 1), "X must be 2")


func test_skeleton_scavengers_unused_shield_adds_no_counter() -> void:
	var skeleton := put_battlefield(0, "Skeleton Scavengers")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, skeleton, 0, [], 1))
	resolve_stack()
	advance_to_next_turn()
	assert_eq(skeleton.regeneration_shields, 0, "the shield expired at cleanup")
	assert_eq(int(skeleton.counters.get("+1/+1", 0)), 1)
	assert_true(g.delayed_triggers.is_empty(), "the rider expired with it")


func test_stronghold_assassin_sacrifices_a_creature_to_destroy_a_nonblack_one() -> void:
	var assassin := put_battlefield(0, "Stronghold Assassin")
	var bear := put_battlefield(0, "Grizzly Bears")
	var knight := put_battlefield(1, "Black Knight")
	var giant := put_battlefield(1, "Hill Giant")
	assert_refused(g.activate_ability(0, assassin, 0, [TargetRef.card(knight)]), "")
	me.prefer = ["Grizzly Bears"]
	assert_ok(g.activate_ability(0, assassin, 0, [TargetRef.card(giant)]))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the sacrifice is a cost")
	assert_true(assassin.tapped)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)


func test_stronghold_assassin_may_sacrifice_itself() -> void:
	var assassin := put_battlefield(0, "Stronghold Assassin")
	var giant := put_battlefield(1, "Hill Giant")
	assert_ok(g.activate_ability(0, assassin, 0, [TargetRef.card(giant)]))
	assert_eq(assassin.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)


func test_stronghold_taskmaster_shrinks_every_other_black_creature() -> void:
	var master := put_battlefield(0, "Stronghold Taskmaster")
	var zombies := put_battlefield(0, "Scathe Zombies")
	var knight := put_battlefield(1, "Black Knight")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_eq(_pt(master), [4, 3], "not itself")
	assert_eq(_pt(zombies), [1, 1], "ours too")
	assert_eq(_pt(knight), [1, 1])
	assert_eq(_pt(bear), [2, 2], "only black creatures")


# --- red -----------------------------------------------------------------------

func test_shard_phoenix_burns_the_ground_and_comes_home_in_your_upkeep() -> void:
	var phoenix := put_battlefield(0, "Shard Phoenix")
	var bear := put_battlefield(0, "Grizzly Bears")
	var angel := put_battlefield(1, "Serra Angel")
	var giant := put_battlefield(1, "Hill Giant")
	assert_ok(g.activate_ability(0, phoenix, 0))
	assert_eq(phoenix.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.damage, 2)
	assert_eq(angel.damage, 0, "creatures with flying are spared")
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_refused(g.activate_ability(0, phoenix, 1), "")
	_to_upkeep(0)
	resolve_stack()
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ok(g.activate_ability(0, phoenix, 1))
	resolve_stack()
	assert_eq(phoenix.zone, Mtg.Zone.HAND)


func test_shard_phoenix_returns_only_in_its_owners_upkeep() -> void:
	var phoenix := put_battlefield(0, "Shard Phoenix")
	assert_ok(g.activate_ability(0, phoenix, 0))
	resolve_stack()
	_to_upkeep(1)
	resolve_stack()
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_refused(g.activate_ability(0, phoenix, 1), "")
	assert_eq(phoenix.zone, Mtg.Zone.GRAVEYARD)


func test_spitting_hydra_spits_its_counters() -> void:
	var hydra := put_battlefield(0, "Spitting Hydra")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_eq(_pt(hydra), [4, 4])
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, hydra, 0, [TargetRef.player(1)]), "")
	assert_ok(g.activate_ability(0, hydra, 0, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, hydra, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_pt(hydra), [2, 2])


# --- green ---------------------------------------------------------------------

func test_carnassid_regenerates() -> void:
	var carnassid := put_battlefield(0, "Carnassid")
	assert_true(carnassid.has_keyword(Mtg.Keyword.TRAMPLE))
	assert_refused(g.activate_ability(0, carnassid, 0), "")
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, carnassid, 0))
	resolve_stack()
	g.destroy(carnassid)
	assert_eq(carnassid.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(carnassid.tapped)
	assert_true(CardRegistry.get_card("Carnassid").activated_abilities[0].effects[0].is_regeneration)


func test_endangered_armodon_goes_once_you_control_a_small_creature() -> void:
	var armodon := put_battlefield(0, "Endangered Armodon")
	put_battlefield(1, "Llanowar Elves")
	cast("Hill Giant")
	assert_eq(armodon.zone, Mtg.Zone.BATTLEFIELD, "their 1/1 and our 3/3 don't count")
	cast("Grizzly Bears")
	assert_eq(armodon.zone, Mtg.Zone.GRAVEYARD)


func test_endangered_armodon_counts_its_own_toughness() -> void:
	var bolted := put_battlefield(1, "Endangered Armodon")
	cast("Lightning Bolt", [TargetRef.card(bolted)])
	assert_eq(bolted.zone, Mtg.Zone.BATTLEFIELD, "damage does not lower toughness")
	var armodon := put_battlefield(0, "Endangered Armodon")
	# Setup: a -0/-3 until end of turn makes it a 4/2 (no small creature
	# arrives), then the state check.
	g.continuous.add_until_eot_pump(armodon.id, 0, -3, [])
	g.recalculate()
	g.check_state_based_actions()
	assert_eq(armodon.zone, Mtg.Zone.GRAVEYARD, "a 4/2 of its own")


func test_skyshroud_archer_shrinks_only_flyers() -> void:
	var archer := put_battlefield(0, "Skyshroud Archer")
	var angel := put_battlefield(1, "Serra Angel")
	var giant := put_battlefield(1, "Hill Giant")
	assert_refused(g.activate_ability(0, archer, 0, [TargetRef.card(giant)]), "")
	assert_ok(g.activate_ability(0, archer, 0, [TargetRef.card(angel)]))
	assert_true(archer.tapped)
	resolve_stack()
	assert_eq(_pt(angel), [3, 3])
	advance_to_next_turn()
	assert_eq(_pt(angel), [4, 4])
