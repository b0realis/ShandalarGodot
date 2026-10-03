extends GameTest
## Pack 8, batch B5 — Visions triggered permanents (cards/sets/vis/_triggers.gd):
## real stack triggers, intervening-"if" rechecks (CR 603.4), last known
## information (CR 603.6 / 608.2h) and whose choice each clause is.

## A seat whose answers a test scripts: yes/no (-1 follows the hint), an
## option index (-1 follows the hint) and card names to prefer.
class Seat extends DecisionAgent:
	var yes := -1
	var option := -1
	var prefer: Array = []
	var asked: Array = []

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
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	me = Seat.new()
	foe = Seat.new()
	g.set_agent(0, me)
	g.set_agent(1, foe)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


## Pass until [param pid]'s [param step] of a LATER turn (its triggers waiting).
func _to_step_later(pid: int, step: int) -> void:
	var start := g.turn_number
	var guard := 0
	while not g.game_over and guard < 800 and not (g.turn_number > start
			and g.active_player == pid and g.current_step() == step):
		_advance_once()
		guard += 1
	assert_lt(guard, 800, "never reached the step")


func _to_upkeep(pid: int) -> void:
	_to_step_later(pid, Mtg.Step.UPKEEP)


## Pass until [param pid]'s end step (this turn's when it is still ahead).
func _to_end(pid: int) -> void:
	var guard := 0
	while not g.game_over and guard < 800 and not (g.active_player == pid
			and g.current_step() == Mtg.Step.END):
		_advance_once()
		guard += 1
	assert_lt(guard, 800, "never reached the end step")


func _counter(i: CardInstance, kind: String) -> int:
	return int(i.counters.get(kind, 0))


# --------------------------------------------------------------- Dream Tides --

func test_dream_tides_locks_creatures_and_sells_nongreen_untaps() -> void:
	put_battlefield(0, "Dream Tides")
	var giant := put_battlefield(0, "Hill Giant")
	var bears := put_battlefield(0, "Grizzly Bears")
	var foe_giant := put_battlefield(1, "Hill Giant")
	for i in [giant, bears, foe_giant]: g.tap_permanent(i)
	_to_upkeep(1)
	resolve_stack()   # P1 has no mana: nothing untaps
	assert_true(foe_giant.tapped, "creatures don't untap during the untap step")
	_to_upkeep(0)
	assert_true(giant.tapped and bears.tapped)
	add_mana(0, Mtg.ManaColor.C, 2)
	resolve_stack()
	assert_false(giant.tapped, "paid {2}")
	assert_true(bears.tapped, "green creatures can't be bought back")


# ----------------------------------------------------------- Shrieking Drake --

func test_shrieking_drake_returns_a_creature_you_control() -> void:
	var drake := put_battlefield(0, "Shrieking Drake")
	resolve_stack()
	assert_eq(drake.zone, Mtg.Zone.HAND, "alone, it returns itself")
	var bears := put_battlefield(0, "Grizzly Bears")
	var foe_bears := put_battlefield(1, "Grizzly Bears")
	me.prefer = ["Grizzly Bears"]
	var second := put_battlefield(0, "Shrieking Drake")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.HAND)
	assert_eq(second.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(foe_bears.zone, Mtg.Zone.BATTLEFIELD, "only a creature you control")


# ---------------------------------------------------------- Waterspout Djinn --

func test_waterspout_djinn_needs_an_untapped_island_each_upkeep() -> void:
	var djinn := put_battlefield(0, "Waterspout Djinn")
	var island := put_battlefield(0, "Island")
	me.yes = 1
	_to_upkeep(0)
	resolve_stack()
	assert_eq(island.zone, Mtg.Zone.HAND)
	assert_eq(djinn.zone, Mtg.Zone.BATTLEFIELD)
	var second := put_battlefield(0, "Island")
	_to_upkeep(0)
	g.tap_permanent(second)   # tapped in response: no longer eligible
	resolve_stack()
	assert_eq(djinn.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(second.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------------------ Aku Djinn --

func test_aku_djinn_feeds_every_opposing_creature() -> void:
	var aku := put_battlefield(0, "Aku Djinn")
	var bears := put_battlefield(0, "Grizzly Bears")
	var foes := [put_battlefield(1, "Grizzly Bears"), put_battlefield(1, "Hill Giant")]
	_to_upkeep(0)
	resolve_stack()
	for i in foes: assert_eq(_counter(i, "+1/+1"), 1)
	assert_eq(_counter(bears, "+1/+1"), 0)
	assert_eq(_counter(aku, "+1/+1"), 0)


# ------------------------------------------------------- Brood of Cockroaches --

func test_brood_of_cockroaches_comes_back_at_the_next_end_step_for_a_life() -> void:
	var brood := put_battlefield(0, "Brood of Cockroaches")
	g.destroy(brood)
	resolve_stack()
	assert_eq(brood.zone, Mtg.Zone.GRAVEYARD)
	_to_end(0)
	resolve_stack()
	assert_eq(brood.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].life, 19)


func test_brood_of_cockroaches_exiled_meanwhile_still_costs_the_life() -> void:
	var brood := put_battlefield(0, "Brood of Cockroaches")
	g.destroy(brood)
	resolve_stack()
	g.exile_from_graveyard(brood)
	_to_end(0)
	resolve_stack()
	assert_eq(brood.zone, Mtg.Zone.EXILE)
	assert_eq(g.players[0].life, 19)


# ------------------------------------------------------------------ Nekrataal --

func test_nekrataal_kills_a_nonartifact_nonblack_creature_through_regeneration() -> void:
	var skeletons := put_battlefield(1, "Drudge Skeletons")
	var ornithopter := put_battlefield(1, "Ornithopter")
	var troll := put_battlefield(1, "Uthden Troll")
	g.pass_priority(0)
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(1, troll, 0))
	resolve_stack()
	assert_eq(troll.regeneration_shields, 1)
	var nek := put_battlefield(0, "Nekrataal")
	assert_true(nek.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(troll.zone, Mtg.Zone.GRAVEYARD, "can't be regenerated")
	assert_eq(skeletons.zone, Mtg.Zone.BATTLEFIELD, "black: not a legal target")
	assert_eq(ornithopter.zone, Mtg.Zone.BATTLEFIELD, "artifact: not a legal target")


func test_nekrataal_with_no_legal_target_puts_no_trigger_on_the_stack() -> void:
	put_battlefield(1, "Drudge Skeletons")
	put_battlefield(0, "Nekrataal")
	assert_true(g.stack.is_empty(), "CR 603.3d")


# ----------------------------------------------------------- Bogardan Phoenix --

func test_bogardan_phoenix_returns_once_then_is_exiled() -> void:
	var phoenix := put_battlefield(0, "Bogardan Phoenix")
	g.destroy(phoenix)
	resolve_stack()
	assert_eq(phoenix.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(_counter(phoenix, "death"), 1)
	g.destroy(phoenix)
	resolve_stack()
	assert_eq(phoenix.zone, Mtg.Zone.EXILE)


# ----------------------------------------------------------- Goblin Recruiter --

func test_goblin_recruiter_stacks_your_goblins_on_top_in_your_order() -> void:
	var raiders := give_hand(0, "Mons's Goblin Raiders")
	var brigade := give_hand(0, "Goblin Balloon Brigade")
	g.put_on_bottom_of_library(raiders)
	g.put_on_bottom_of_library(brigade)
	var revealed: Array = []
	g.information_revealed.connect(func(viewer: int, _title: String, names: Array) -> void:
		if viewer == -1: revealed.append_array(names))
	me.prefer = ["Mons's Goblin Raiders"]
	put_battlefield(0, "Goblin Recruiter")
	resolve_stack()
	var library := g.players[0].library
	assert_eq(library.back(), raiders, "the first named card is on top")
	assert_eq(library[library.size() - 2], brigade)
	assert_true(revealed.has("Mons's Goblin Raiders") and revealed.has("Goblin Balloon Brigade"))


# --------------------------------------------------------------------- Kookus --

func test_kookus_burns_and_must_attack_without_its_keeper() -> void:
	var kookus := put_battlefield(0, "Kookus")
	_to_upkeep(0)
	resolve_stack()
	assert_eq(g.players[0].life, 17)
	assert_true(kookus.must_attack_this_turn)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, kookus, 0))
	resolve_stack()
	assert_eq(kookus.cur_power, 4)


func test_kookus_is_quiet_while_you_control_keeper_of_kookus() -> void:
	put_battlefield(0, "Kookus")
	put_battlefield(0, "Keeper of Kookus")
	_to_upkeep(0)
	assert_true(g.stack.is_empty())
	assert_eq(g.players[0].life, 20)


func test_kookus_rechecks_the_keeper_on_resolution() -> void:
	var kookus := put_battlefield(0, "Kookus")
	_to_upkeep(0)
	assert_eq(g.stack.size(), 1)
	put_battlefield(0, "Keeper of Kookus")
	resolve_stack()
	assert_eq(g.players[0].life, 20, "the intervening if fails on resolution")
	assert_false(kookus.must_attack_this_turn)


# ------------------------------------------------------------ Lightning Cloud --

func test_lightning_cloud_pings_on_any_red_spell_for_red_mana() -> void:
	put_battlefield(0, "Lightning Cloud")
	var lions := put_battlefield(1, "Savannah Lions")
	me.yes = 1
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_eq(g.stack.size(), 2)
	resolve_stack()
	assert_eq(lions.zone, Mtg.Zone.GRAVEYARD, "the X/1 is the heuristic's target")
	assert_eq(g.players[1].life, 17)
	# Declined: no damage.
	me.yes = 0
	g.pass_priority(0)
	var second := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, second, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	assert_eq(g.players[0].life, 17)


# ------------------------------------------------------- Viashino Sandstalker --

func test_viashino_sandstalker_goes_home_at_each_end_step() -> void:
	var stalker := put_battlefield(0, "Viashino Sandstalker", true)
	assert_true(stalker.has_keyword(Mtg.Keyword.HASTE))
	_to_end(0)
	resolve_stack()
	assert_eq(stalker.zone, Mtg.Zone.HAND)
	var second := put_battlefield(0, "Viashino Sandstalker")
	_to_end(1)
	resolve_stack()
	assert_eq(second.zone, Mtg.Zone.HAND, "the opponent's end step too")


# -------------------------------------------------------------- Bull Elephant --

func test_bull_elephant_returns_two_forests_or_is_sacrificed() -> void:
	var forests := [put_battlefield(0, "Forest"), put_battlefield(0, "Forest")]
	me.yes = 1
	var elephant := put_battlefield(0, "Bull Elephant")
	resolve_stack()
	assert_eq(elephant.zone, Mtg.Zone.BATTLEFIELD)
	for f in forests: assert_eq(f.zone, Mtg.Zone.HAND)
	put_battlefield(0, "Forest")
	var second := put_battlefield(0, "Bull Elephant")
	resolve_stack()
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD, "one Forest is not two")


# ---------------------------------------------------------------------- Rowen --

func test_rowen_reveals_the_first_draw_and_draws_again_on_a_basic_land() -> void:
	put_battlefield(0, "Rowen")
	var revealed: Array = []
	g.information_revealed.connect(func(viewer: int, _title: String, names: Array) -> void:
		if viewer == -1: revealed.append_array(names))
	_to_upkeep(0)
	resolve_stack()
	var hand := g.players[0].hand.size()
	advance_to_step(Mtg.Step.DRAW)
	assert_eq(revealed, ["Forest"], "revealed as drawn, before anything resolves")
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 2, "the draw step's card and Rowen's")
	assert_eq(revealed.size(), 1, "only the FIRST card drawn each turn")


func test_rowen_draws_nothing_extra_for_a_nonland_first_draw() -> void:
	put_battlefield(0, "Rowen")
	var bolt := give_hand(0, "Lightning Bolt")
	g.put_from_hand_on_top_of_library(bolt)
	_to_upkeep(0)
	resolve_stack()
	var hand := g.players[0].hand.size()
	advance_to_step(Mtg.Step.DRAW)
	assert_true(g.stack.is_empty())
	assert_eq(g.players[0].hand.size(), hand + 1)


# ----------------------------------------------------- Stampeding Wildebeests --

func test_stampeding_wildebeests_returns_a_green_creature_each_upkeep() -> void:
	var beasts := put_battlefield(0, "Stampeding Wildebeests")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	_to_upkeep(0)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.HAND)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "not green")
	_to_upkeep(0)
	resolve_stack()
	assert_eq(beasts.zone, Mtg.Zone.HAND, "the only green creature left is itself")


# ----------------------------------------------------------- Uktabi Orangutan --

func test_uktabi_orangutan_destroys_target_artifact() -> void:
	var ring := put_battlefield(1, "Sol Ring")
	put_battlefield(0, "Uktabi Orangutan")
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)


# -------------------------------------------------------- Femeref Enchantress --

func test_femeref_enchantress_draws_for_each_enchantment_to_a_graveyard() -> void:
	put_battlefield(0, "Femeref Enchantress")
	var crusade := put_battlefield(1, "Crusade")
	var hand := g.players[0].hand.size()
	g.destroy(crusade)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1)
	var bears := put_battlefield(0, "Grizzly Bears")
	var strength := give_hand(0, "Holy Strength")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, strength, [TargetRef.card(bears)]))
	resolve_stack()
	var before := g.players[0].hand.size()
	g.destroy(bears)
	g.check_state_based_actions()   # the orphaned Aura goes (CR 704.5m)
	assert_eq(g.stack.size(), 1, "one trigger: the Aura, not the creature")
	resolve_stack()
	assert_eq(strength.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].hand.size(), before + 1, "the Aura counted; the creature did not")


func test_femeref_enchantress_ignores_an_enchantment_returned_to_hand() -> void:
	put_battlefield(0, "Femeref Enchantress")
	var crusade := put_battlefield(1, "Crusade")
	g.return_to_hand(crusade)
	assert_true(g.stack.is_empty())


# --------------------------------------------------------- Suleiman's Legacy --

func test_suleimans_legacy_destroys_djinns_and_efreets_now_and_later() -> void:
	var juzam := put_battlefield(1, "Juzám Djinn")
	var efreet := put_battlefield(1, "Serendib Efreet")
	var bears := put_battlefield(1, "Grizzly Bears")
	put_battlefield(0, "Suleiman's Legacy")
	resolve_stack()
	assert_eq(juzam.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(efreet.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	var aku := put_battlefield(0, "Aku Djinn")
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(aku.zone, Mtg.Zone.GRAVEYARD, "your own Djinn too")


# ------------------------------------------------------------ Tar Pit Warrior --

func test_tar_pit_warrior_is_sacrificed_by_any_spell_that_targets_it() -> void:
	var warrior := put_battlefield(0, "Tar Pit Warrior")
	var strength := give_hand(0, "Holy Strength")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, strength, [TargetRef.card(warrior)]))
	assert_eq(g.stack.size(), 2, "your own Aura spell targets it too")
	resolve_stack()
	assert_eq(warrior.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(strength.zone, Mtg.Zone.GRAVEYARD, "the Aura had nothing to enchant")


func test_tar_pit_warrior_sacrificed_by_a_copy_aimed_at_it() -> void:
	var warrior := put_battlefield(0, "Tar Pit Warrior")
	var bears := put_battlefield(0, "Grizzly Bears")
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(bears)]))
	assert_eq(g.stack.size(), 1, "the Warrior is not a target")
	g.pass_priority(0)
	foe.prefer = ["Tar Pit Warrior"]
	var fork := give_hand(1, "Fork")
	add_mana(1, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(1, fork, [TargetRef.card(growth)]))
	resolve_stack()
	assert_eq(warrior.zone, Mtg.Zone.GRAVEYARD, "the re-aimed copy made it a target (CR 707.10c)")
	assert_eq(bears.cur_power, 5, "the original still resolved")


# ----------------------------------------------------------------- Desolation --

func test_desolation_takes_a_land_from_each_player_who_tapped_one_for_mana() -> void:
	put_battlefield(0, "Desolation")
	var plains := put_battlefield(0, "Plains")
	var forest := put_battlefield(0, "Forest")
	var foe_plains := put_battlefield(1, "Plains")
	assert_ok(g.tap_for_mana(0, forest))
	g.tap_permanent(foe_plains)   # tapped, but not for mana
	me.prefer = ["Plains"]
	_to_end(0)
	resolve_stack()
	assert_eq(plains.zone, Mtg.Zone.GRAVEYARD, "the player's own choice")
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 18, "a Plains was sacrificed: 2 damage")
	assert_eq(foe_plains.zone, Mtg.Zone.BATTLEFIELD, "P1 never tapped a land for mana")
	assert_eq(g.players[1].life, 20)


func test_desolation_spares_life_when_a_non_plains_goes() -> void:
	put_battlefield(0, "Desolation")
	put_battlefield(0, "Plains")
	var foe_forest := put_battlefield(1, "Forest")
	var foe_plains := put_battlefield(1, "Plains")
	advance_to_next_turn()
	assert_ok(g.tap_for_mana(1, foe_plains))
	_to_end(1)
	resolve_stack()
	assert_eq(foe_forest.zone, Mtg.Zone.GRAVEYARD, "the heuristic keeps its Plains")
	assert_eq(foe_plains.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 20)
	assert_eq(g.players[0].life, 20)

