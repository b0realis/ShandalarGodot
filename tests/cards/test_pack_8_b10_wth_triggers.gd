extends GameTest
## Pack 8, batch B10: the Weatherlight triggered abilities
## (cards/sets/wth/_triggers.gd). Every trigger is a real stack object:
## the tests assert it is on the stack before it resolves, that "you" is
## the trigger's controller (a stolen creature's last controller when it
## dies), that a trigger touching its source checks the source is still the
## same object, and that Urborg Stalker's intervening "if" is checked
## twice. Circling Vultures' discard is the E7 hand special action.

const DONE := ["Angelic Renewal", "Mistmoon Griffin", "Peacekeeper", "Serenity", "Merfolk Traders",
	"Noble Benefactor", "Pendrell Mists", "Sage Owl", "Timid Drake", "Tolarian Serpent", "Abyssal Gatekeeper",
	"Barrow Ghoul", "Festering Evil", "Fledgling Djinn", "Odylic Wraith", "Urborg Stalker", "Aether Flash",
	"Bogardan Firefiend", "Cinder Giant", "Goblin Bomb", "Hurloon Shaman", "Lava Hounds", "Roc Hatchling",
	"Barishi", "Fallow Wurm", "Harvest Wurm", "Liege of the Hollows", "Llanowar Sentinel", "Rogue Elephant",
	"Striped Bears", "Sylvan Hierophant", "Veteran Explorer", "Straw Golem", "Circling Vultures"]


## Answers every yes/no with [member says], picks cards by name in the
## order of [member picks] (else the first candidate), and names
## [member number] when asked for one (-1: the hint).
class Seat extends DecisionAgent:
	var says := true
	var picks: Array[String] = []
	var number := -1
	var asked: Array[String] = []
	func answer_yes_no(_g: MtgGame, _pid: int, prompt: String, _hint: bool) -> bool:
		asked.append(prompt)
		return says
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		while not picks.is_empty():
			var want: String = picks.pop_front()
			for c in candidates:
				if c.data.card_name == want: return c
		return null if candidates.is_empty() else candidates[0]
	func answer_option(_g: MtgGame, _pid: int, _prompt: String, options: Array[String], hint: int) -> int:
		if number < 0: return hint
		return options.find(str(number))


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func _pending(name: String) -> bool:
	var c := CardRegistry.get_card(name)
	return c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"

func cast(name: String, targets: Array = [], pid := 0, x := 0) -> CardInstance:
	var c := give_hand(pid, name)
	for color in Mtg.WUBRG: add_mana(pid, color, 20)
	if g.priority_player != pid: assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.cast_spell(pid, c, targets, x))
	resolve_stack()
	return c

## Cast without resolving, so the test can watch the trigger arrive.
func cast_only(name: String, pid := 0) -> CardInstance:
	var c := give_hand(pid, name)
	for color in Mtg.WUBRG: add_mana(pid, color, 20)
	if g.priority_player != pid: assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.cast_spell(pid, c, []))
	assert_ok(g.pass_priority(pid))
	assert_ok(g.pass_priority(g.opponent_of(pid)))
	return c

func grave(pid: int, name: String) -> CardInstance:
	var inst := _make_instance(pid, name)
	g.put_into_graveyard(inst)
	return inst

func library_card(pid: int, name: String) -> CardInstance:
	var inst := _make_instance(pid, name)
	inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.push_front(inst)
	return inst

func to_upkeep(pid: int) -> void:
	var guard := 0
	while g.current_step() == Mtg.Step.UPKEEP and not g.game_over and guard < 50:
		_advance_once()   # leave the upkeep we may be standing in
		guard += 1
	while not (g.current_step() == Mtg.Step.UPKEEP and g.active_player == pid) and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "never reached the upkeep")

func seat(pid: int) -> Seat:
	var s := Seat.new()
	g.agents[pid] = s
	return s


func test_batch_triggers_are_all_claimed() -> void:
	for name in DONE: assert_false(_pending(name), name)


func test_circling_vultures_is_discarded_any_time_you_could_cast_an_instant() -> void:
	var vultures := give_hand(1, "Circling Vultures")
	var bear := give_hand(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.discard_as_special_action(1, vultures), "priority")
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	assert_refused(g.discard_as_special_action(1, bear))
	assert_ok(g.discard_as_special_action(1, vultures))
	assert_eq(vultures.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.priority_player, 1, "a special action keeps priority (CR 116.3)")
	assert_eq(g.stack.size(), 1, "it never used the stack")
	resolve_stack()
	assert_eq(g.players[1].life, 17)


func test_circling_vultures_upkeep_eats_the_top_creature_card_or_dies() -> void:
	var vultures := cast("Circling Vultures")
	var top := grave(0, "Hill Giant")
	to_upkeep(0)
	resolve_stack()
	assert_eq(top.zone, Mtg.Zone.EXILE)
	assert_eq(vultures.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(vultures.has_keyword(Mtg.Keyword.FLYING))
	to_upkeep(0)
	resolve_stack()
	assert_eq(vultures.zone, Mtg.Zone.GRAVEYARD, "nothing left to exile: sacrificed")


# ------------------------------------------------------------- white --

func test_angelic_renewal_trades_itself_for_the_dead_creature() -> void:
	var renewal := put_battlefield(0, "Angelic Renewal")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.destroy(bear)
	assert_false(g.stack.is_empty())
	resolve_stack()
	assert_eq(renewal.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_angelic_renewal_is_optional_and_ignores_other_graveyards() -> void:
	var renewal := put_battlefield(0, "Angelic Renewal")
	var theirs := put_battlefield(1, "Grizzly Bears")
	g.destroy(theirs)
	assert_true(g.stack.is_empty(), "not put into YOUR graveyard")
	var s := seat(0)
	s.says = false
	var bear := put_battlefield(0, "Grizzly Bears")
	g.destroy(bear)
	resolve_stack()
	assert_eq(renewal.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_angelic_renewal_that_already_left_returns_nothing() -> void:
	var renewal := put_battlefield(0, "Angelic Renewal")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.destroy(bear)
	g.destroy(renewal)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "no sacrifice, no return")


func test_mistmoon_griffin_exiles_itself_and_raises_the_top_creature() -> void:
	var bear := grave(0, "Grizzly Bears")
	grave(0, "Lightning Bolt")
	var griffin := put_battlefield(0, "Mistmoon Griffin")
	g.destroy(griffin)
	assert_false(g.stack.is_empty())
	resolve_stack()
	assert_eq(griffin.zone, Mtg.Zone.EXILE)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_mistmoon_griffin_stolen_raises_from_the_thiefs_graveyard() -> void:
	var mine := grave(0, "Grizzly Bears")
	var theirs := grave(1, "Hill Giant")
	var griffin := put_battlefield(1, "Mistmoon Griffin")
	g.change_control(griffin, 0)
	g.destroy(griffin)
	resolve_stack()
	assert_eq(griffin.zone, Mtg.Zone.EXILE, "exiled from its owner's graveyard")
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD, "'your graveyard' is the last controller's")
	assert_eq(mine.controller_id, 0)
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD)


func test_peacekeeper_stops_all_attacks_and_charges_upkeep() -> void:
	var keeper := put_battlefield(0, "Peacekeeper")
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [bear.id]))
	assert_ok(g.declare_attackers(0, []))
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(1, [theirs.id]))
	assert_ok(g.declare_attackers(1, []))
	to_upkeep(0)
	assert_false(g.stack.is_empty())
	resolve_stack()
	assert_eq(keeper.zone, Mtg.Zone.GRAVEYARD, "no {1}{W}: sacrificed")


func test_peacekeeper_paid_upkeep_keeps_it() -> void:
	var keeper := put_battlefield(0, "Peacekeeper")
	to_upkeep(0)
	add_mana(0, Mtg.ManaColor.W, 2)
	resolve_stack()
	assert_eq(keeper.zone, Mtg.Zone.BATTLEFIELD)


func test_serenity_destroys_artifacts_and_enchantments_without_regeneration() -> void:
	var serenity := put_battlefield(0, "Serenity")
	var ring := put_battlefield(1, "Sol Ring")
	var golem := put_battlefield(1, "Matopi Golem")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_next_turn()
	assert_eq(serenity.zone, Mtg.Zone.BATTLEFIELD, "only YOUR upkeep")
	to_upkeep(0)
	golem.regeneration_shields = 1
	resolve_stack()
	for i in [serenity, ring, golem]: assert_eq(i.zone, Mtg.Zone.GRAVEYARD, i.data.card_name)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# -------------------------------------------------------------- blue --

func test_merfolk_traders_draws_then_discards() -> void:
	var before := g.players[0].hand.size()
	var trader := cast_only("Merfolk Traders")
	assert_false(g.stack.is_empty(), "the trigger waits on the stack")
	resolve_stack()
	assert_eq(trader.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].hand.size(), before, "drew one, discarded one")
	assert_eq(g.players[0].graveyard.size(), 1)


func test_noble_benefactor_lets_each_player_tutor() -> void:
	var mine := library_card(0, "Lightning Bolt")
	var theirs := library_card(1, "Hill Giant")
	var s0 := seat(0)
	s0.picks = ["Lightning Bolt"]
	var s1 := seat(1)
	s1.picks = ["Hill Giant"]
	var benefactor := put_battlefield(0, "Noble Benefactor")
	g.destroy(benefactor)
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.HAND)
	assert_eq(theirs.zone, Mtg.Zone.HAND)


func test_noble_benefactor_search_is_optional() -> void:
	var s1 := seat(1)
	s1.says = false
	var theirs := library_card(1, "Hill Giant")
	var hand := g.players[1].hand.size()
	g.destroy(put_battlefield(0, "Noble Benefactor"))
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[1].hand.size(), hand)


func test_pendrell_mists_taxes_every_creature_and_stacks() -> void:
	advance_to_next_turn()
	put_battlefield(1, "Pendrell Mists")
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	to_upkeep(0)
	assert_eq(g.stack.size(), 1, "only the active player's creature")
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "no {1}: sacrificed")
	assert_eq(theirs.zone, Mtg.Zone.BATTLEFIELD)
	put_battlefield(0, "Pendrell Mists")
	var bear := put_battlefield(0, "Grizzly Bears")
	to_upkeep(0)
	assert_eq(g.stack.size(), 2, "two Mists, two taxes")
	add_mana(0, Mtg.ManaColor.C, 1)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "paid one tax, not the other")


func test_sage_owl_reorders_the_top_four() -> void:
	var cards: Array[CardInstance] = []
	for name in ["Grizzly Bears", "Hill Giant", "Lightning Bolt", "Black Knight"]:
		var inst := _make_instance(0, name)
		inst.zone = Mtg.Zone.LIBRARY
		g.players[0].library.append(inst)
		cards.append(inst)
	var s := seat(0)
	s.picks = ["Grizzly Bears", "Lightning Bolt", "Hill Giant", "Black Knight"]
	cast("Sage Owl")
	var lib := g.players[0].library
	assert_eq(lib[lib.size() - 1], cards[0], "Grizzly Bears chosen first: next draw")
	assert_eq(lib[lib.size() - 2], cards[2])
	assert_eq(lib[lib.size() - 3], cards[1])
	assert_eq(lib[lib.size() - 4], cards[3])
	assert_eq(lib.size(), 34)


func test_timid_drake_runs_home_when_another_creature_enters() -> void:
	var drake := put_battlefield(0, "Timid Drake")
	cast_only("Grizzly Bears", 0)
	assert_false(g.stack.is_empty())
	resolve_stack()
	assert_eq(drake.zone, Mtg.Zone.HAND)
	var again := cast("Timid Drake")
	assert_eq(again.zone, Mtg.Zone.BATTLEFIELD, "its own arrival is not ANOTHER creature")


func test_timid_drake_triggers_on_an_opponents_creature_too() -> void:
	var drake := put_battlefield(0, "Timid Drake")
	advance_to_next_turn()
	cast_only("Grizzly Bears", 1)
	resolve_stack()
	assert_eq(drake.zone, Mtg.Zone.HAND)


func test_tolarian_serpent_mills_seven_each_upkeep() -> void:
	put_battlefield(0, "Tolarian Serpent")
	var lib := g.players[0].library.size()
	to_upkeep(0)
	resolve_stack()
	assert_eq(g.players[0].library.size(), lib - 7, "seven milled before this turn's draw")


# ------------------------------------------------------------- black --

func test_abyssal_gatekeeper_makes_each_player_sacrifice() -> void:
	var gate := put_battlefield(0, "Abyssal Gatekeeper")
	var mine := put_battlefield(0, "Hill Giant")
	var small := put_battlefield(1, "Grizzly Bears")
	var big := put_battlefield(1, "Hill Giant")
	g.destroy(gate)
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(small.zone, Mtg.Zone.GRAVEYARD, "the default choice is the cheapest creature")
	assert_eq(big.zone, Mtg.Zone.BATTLEFIELD)


func test_barrow_ghoul_eats_the_top_creature_card_or_dies() -> void:
	var ghoul := put_battlefield(0, "Barrow Ghoul")
	var bottom := grave(0, "Grizzly Bears")
	var top := grave(0, "Hill Giant")
	grave(0, "Lightning Bolt")
	to_upkeep(0)
	resolve_stack()
	assert_eq(top.zone, Mtg.Zone.EXILE, "the creature card nearest the top")
	assert_eq(bottom.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(ghoul.zone, Mtg.Zone.BATTLEFIELD)
	g.exile_from_graveyard(bottom)
	to_upkeep(0)
	resolve_stack()
	assert_eq(ghoul.zone, Mtg.Zone.GRAVEYARD, "no creature card left: sacrificed")


func test_festering_evil_pings_everything_and_blows_up_for_three() -> void:
	var evil := put_battlefield(0, "Festering Evil")
	var bear := put_battlefield(1, "Grizzly Bears")
	to_upkeep(0)
	resolve_stack()
	assert_eq(g.players[0].life, 19)
	assert_eq(g.players[1].life, 19)
	assert_eq(bear.damage, 1)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.activate_ability(0, evil, 0, []))
	resolve_stack()
	assert_eq(evil.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 16)
	assert_eq(g.players[1].life, 16)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_fledgling_djinn_hurts_its_controller() -> void:
	put_battlefield(0, "Fledgling Djinn")
	to_upkeep(0)
	assert_false(g.stack.is_empty())
	resolve_stack()
	assert_eq(g.players[0].life, 19)


func test_fledgling_djinn_still_deals_its_damage_after_leaving() -> void:
	var djinn := put_battlefield(0, "Fledgling Djinn")
	to_upkeep(0)
	g.destroy(djinn)
	resolve_stack()
	assert_eq(g.players[0].life, 19, "last known information (CR 608.2h)")


func test_timid_drake_that_already_left_is_not_moved() -> void:
	var drake := put_battlefield(0, "Timid Drake")
	cast_only("Grizzly Bears", 0)
	g.destroy(drake)
	resolve_stack()
	assert_eq(drake.zone, Mtg.Zone.GRAVEYARD, "a new object in the graveyard (CR 400.7)")


func test_odylic_wraith_hit_makes_the_player_discard() -> void:
	var wraith := put_battlefield(0, "Odylic Wraith")
	assert_true(wraith.cur_landwalk.has("swamp"))
	give_hand(1, "Lightning Bolt")
	g.deal_damage(wraith, TargetRef.player(1), 2)
	assert_false(g.stack.is_empty())
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 0)
	g.deal_damage(wraith, TargetRef.card(put_battlefield(1, "Hill Giant")), 2)
	assert_true(g.stack.is_empty(), "damage to a creature does nothing")


func test_urborg_stalker_checks_its_if_on_trigger_and_resolution() -> void:
	put_battlefield(0, "Urborg Stalker")
	var bear := put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Forest")
	to_upkeep(1)
	assert_false(g.stack.is_empty())
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	to_upkeep(1)
	assert_false(g.stack.is_empty())
	g.destroy(bear)   # the condition fails before it resolves
	resolve_stack()
	assert_eq(g.players[1].life, 19, "rechecked on resolution (CR 603.4)")
	to_upkeep(1)
	assert_true(g.stack.is_empty(), "only a land left: it does not trigger")
	to_upkeep(0)
	assert_eq(g.players[0].life, 20, "the Stalker itself is black: its controller is spared")


# --------------------------------------------------------------- red --

func test_aether_flash_burns_each_entering_creature() -> void:
	put_battlefield(0, "Aether Flash")
	var bear := cast_only("Grizzly Bears", 0)
	assert_false(g.stack.is_empty())
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	var giant := cast("Hill Giant")
	assert_eq(giant.damage, 2)


func test_bogardan_firefiend_aims_its_death_at_a_creature() -> void:
	var fiend := put_battlefield(0, "Bogardan Firefiend")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.destroy(fiend)
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the default aim is the enemy creature")


func test_bogardan_firefiend_fizzles_when_the_target_is_gone() -> void:
	var fiend := put_battlefield(0, "Bogardan Firefiend")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.destroy(fiend)
	g.return_to_hand(bear)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_true(g.stack.is_empty(), "fizzled (CR 608.2b)")


func test_cinder_giant_burns_only_its_own_other_creatures() -> void:
	var giant := put_battlefield(0, "Cinder Giant")
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	to_upkeep(0)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.damage, 0)
	assert_eq(theirs.damage, 0)


func test_goblin_bomb_fuse_and_detonation() -> void:
	var bomb := put_battlefield(0, "Goblin Bomb")
	assert_refused(g.activate_ability(0, bomb, 0, [TargetRef.player(1)]))
	bomb.counters["fuse"] = 5
	assert_ok(g.activate_ability(0, bomb, 0, [TargetRef.player(1)]))
	assert_eq(bomb.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[1].life, 0)


func test_goblin_bomb_upkeep_flip_moves_the_fuse() -> void:
	var bomb := put_battlefield(0, "Goblin Bomb")
	var s := seat(0)
	var seen := {}
	for turn in 6:
		to_upkeep(0)
		var before := int(bomb.counters.get("fuse", 0))
		resolve_stack()
		var after := int(bomb.counters.get("fuse", 0))
		assert_true(after == before + 1 or after == maxi(before - 1, 0), "one step either way")
		seen[after - before] = true
	assert_true(seen.size() >= 1)
	s.says = false
	var before := int(bomb.counters.get("fuse", 0))
	to_upkeep(0)
	resolve_stack()
	assert_eq(int(bomb.counters.get("fuse", 0)), before, "declining the flip changes nothing")


func test_hurloon_shaman_makes_each_player_sacrifice_a_land() -> void:
	var shaman := put_battlefield(0, "Hurloon Shaman")
	var mine := put_battlefield(0, "Mountain")
	var theirs := put_battlefield(1, "Island")
	g.destroy(shaman)
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD)


func test_lava_hounds_bite_their_caster() -> void:
	var hounds := cast_only("Lava Hounds")
	assert_false(g.stack.is_empty())
	resolve_stack()
	assert_eq(g.players[0].life, 16)
	assert_true(hounds.has_keyword(Mtg.Keyword.HASTE))


func test_roc_hatchling_hatches_after_four_upkeeps() -> void:
	var roc := cast("Roc Hatchling")
	assert_eq(int(roc.counters.get("shell", 0)), 4)
	assert_eq([roc.cur_power, roc.cur_toughness], [0, 1])
	for n in 4:
		assert_false(roc.has_keyword(Mtg.Keyword.FLYING))
		to_upkeep(0)
		resolve_stack()
	assert_eq(int(roc.counters.get("shell", 0)), 0)
	assert_eq([roc.cur_power, roc.cur_toughness], [3, 3])
	assert_true(roc.has_keyword(Mtg.Keyword.FLYING))


# ------------------------------------------------------------- green --

func test_barishi_exiles_itself_and_shuffles_creature_cards_home() -> void:
	var bear := grave(0, "Grizzly Bears")
	var bolt := grave(0, "Lightning Bolt")
	var barishi := put_battlefield(0, "Barishi")
	g.destroy(barishi)
	resolve_stack()
	assert_eq(barishi.zone, Mtg.Zone.EXILE)
	assert_eq(bear.zone, Mtg.Zone.LIBRARY)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)


func test_fallow_wurm_needs_a_land_card_discarded() -> void:
	var land := give_hand(0, "Forest")
	var wurm := cast("Fallow Wurm")
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD)
	var second := cast("Fallow Wurm")
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD, "no land card left: sacrificed")


func test_harvest_wurm_needs_a_basic_land_card_back() -> void:
	var forest := grave(0, "Forest")
	var wurm := cast("Harvest Wurm")
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(forest.zone, Mtg.Zone.HAND)
	var second := cast("Harvest Wurm")
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD)


func test_rogue_elephant_needs_a_forest() -> void:
	var forest := put_battlefield(0, "Forest")
	var elephant := cast("Rogue Elephant")
	assert_eq(elephant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	var second := cast("Rogue Elephant")
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD)


func test_liege_of_the_hollows_squirrels_for_mana_paid() -> void:
	var s0 := seat(0)
	s0.number = 2
	var s1 := seat(1)
	s1.number = 0
	add_mana(0, Mtg.ManaColor.G, 3)
	add_mana(1, Mtg.ManaColor.R, 4)
	var liege := put_battlefield(0, "Liege of the Hollows")
	g.destroy(liege)
	resolve_stack()
	var squirrels := 0
	for i in g.players[0].battlefield:
		if i.data.card_name == "Squirrel": squirrels += 1
	assert_eq(squirrels, 2)
	assert_eq(g.players[0].mana_pool.total(), 1)
	assert_eq(g.players[1].battlefield.size(), 0)
	assert_eq(g.players[1].mana_pool.total(), 4)


func test_liege_of_the_hollows_default_pays_everything() -> void:
	add_mana(1, Mtg.ManaColor.R, 3)
	g.destroy(put_battlefield(0, "Liege of the Hollows"))
	resolve_stack()
	assert_eq(g.players[1].battlefield.size(), 3)
	assert_eq(g.players[0].battlefield.size(), 0, "no mana, no squirrels")


func test_llanowar_sentinel_fetches_a_copy_for_one_green() -> void:
	var copy := library_card(0, "Llanowar Sentinel")
	var first := cast("Llanowar Sentinel")
	assert_eq(first.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(copy.zone, Mtg.Zone.BATTLEFIELD)
	resolve_stack()


func test_llanowar_sentinel_payment_is_optional() -> void:
	var s := seat(0)
	s.says = false
	var copy := library_card(0, "Llanowar Sentinel")
	cast("Llanowar Sentinel")
	assert_eq(copy.zone, Mtg.Zone.LIBRARY)


func test_striped_bears_draw_on_entry() -> void:
	var before := g.players[0].hand.size()
	cast_only("Striped Bears")
	assert_false(g.stack.is_empty())
	resolve_stack()
	assert_eq(g.players[0].hand.size(), before + 1)


func test_sylvan_hierophant_returns_another_creature_card() -> void:
	var giant := grave(0, "Hill Giant")
	var hierophant := put_battlefield(0, "Sylvan Hierophant")
	g.destroy(hierophant)
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(hierophant.zone, Mtg.Zone.EXILE)
	assert_eq(giant.zone, Mtg.Zone.HAND)


func test_sylvan_hierophant_without_another_target_does_nothing() -> void:
	var hierophant := put_battlefield(0, "Sylvan Hierophant")
	g.destroy(hierophant)
	assert_true(g.stack.is_empty(), "no legal target: removed (CR 603.3d)")
	assert_eq(hierophant.zone, Mtg.Zone.GRAVEYARD, "so it is not exiled either")


func test_veteran_explorer_ramps_both_players() -> void:
	var mine: Array[CardInstance] = [library_card(0, "Plains"), library_card(0, "Island")]
	var theirs := library_card(1, "Swamp")
	var explorer := put_battlefield(0, "Veteran Explorer")
	var lands_before := g.players[0].battlefield.size()
	g.destroy(explorer)
	resolve_stack()
	assert_eq(g.players[0].battlefield.size(), lands_before - 1 + 2, "two basics for the controller")
	assert_eq(g.players[1].battlefield.size(), 2, "and up to two for the opponent")


func test_veteran_explorer_search_is_optional() -> void:
	var s1 := seat(1)
	s1.says = false
	g.destroy(put_battlefield(0, "Veteran Explorer"))
	resolve_stack()
	assert_eq(g.players[1].battlefield.size(), 0)


# ---------------------------------------------------------- artifact --

func test_straw_golem_falls_apart_on_an_opponents_creature_spell() -> void:
	var golem := put_battlefield(0, "Straw Golem")
	cast("Grizzly Bears", [], 0)
	assert_eq(golem.zone, Mtg.Zone.BATTLEFIELD, "your own creature spell is fine")
	cast("Lightning Bolt", [TargetRef.player(0)], 1)
	assert_eq(golem.zone, Mtg.Zone.BATTLEFIELD, "a noncreature spell is fine")
	advance_to_next_turn()
	var bear := give_hand(1, "Grizzly Bears")
	add_mana(1, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(1, bear, []))
	assert_eq(g.stack.size(), 2, "the trigger sits above the spell")
	resolve_stack()
	assert_eq(golem.zone, Mtg.Zone.GRAVEYARD)
