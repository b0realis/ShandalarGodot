extends GameTest
## Pack 8 (the Mirage block), batch B6: the Mirage Auras in
## cards/sets/mir/_auras.gd — Favorable Destiny, Pacifism, Ritual of Steel,
## Ward of Lights, Mind Harness, Soar, Thirst, Binding Agony, Enfeeblement,
## Grave Servitude, Agility, Consuming Ferocity, Lightning Reflexes, Armor of
## Thorns, Decomposition and Wellspring.
##
## The five flash-rider Auras are driven down BOTH paths: cast in a main
## phase with an empty stack (a sorcery could have been cast: the Aura
## stays) and cast at instant speed (sacrificed at the beginning of the next
## cleanup step, AFTER damage wears off, from the stack, with a window to
## respond — CR 514.3a).

const CLAIMED := ["Favorable Destiny", "Pacifism", "Ritual of Steel", "Ward of Lights",
	"Mind Harness", "Soar", "Thirst", "Binding Agony", "Enfeeblement", "Grave Servitude",
	"Agility", "Consuming Ferocity", "Lightning Reflexes", "Armor of Thorns", "Decomposition", "Wellspring"]

## Answers every yes/no with [member yes] and every colour with [member color]
## (0 = follow the hint), and remembers the hints it was given.
class Seat extends DecisionAgent:
	var yes := true
	var color := 0
	var color_hints: Array[int] = []
	var asked: Array[String] = []
	func answer_yes_no(_g: MtgGame, _pid: int, prompt: String, _hint: bool) -> bool:
		asked.append(prompt)
		return yes
	func answer_color(_g: MtgGame, _pid: int, _prompt: String, hint: int) -> int:
		color_hints.append(hint)
		return color if color != 0 else hint

func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)

func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

func _enchant(pid: int, aura_name: String, host: CardInstance, mana: Array) -> CardInstance:
	var aura := give_hand(pid, aura_name)
	for m in mana: add_mana(pid, int(m))
	assert_ok(g.cast_spell(pid, aura, [TargetRef.card(host)]))
	resolve_stack()
	return aura

func _bolt(pid: int, target: TargetRef) -> CardInstance:
	var bolt := give_hand(pid, "Lightning Bolt")
	add_mana(pid, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(pid, bolt, [target]))
	return bolt

## Pass priority until the cleanup step holds a trigger on the stack (or the
## turn moved on — the caller asserts which). The E3 tests' helper.
func _to_cleanup_priority() -> void:
	var turn := g.turn_number
	var guard := 0
	while not (g.current_step() == Mtg.Step.CLEANUP and not g.stack.is_empty()) \
			and g.turn_number == turn and guard < 200:
		_advance_once()
		guard += 1

## P0 attacks with [param attacker]; P1 blocks with [param blocker]; returns
## with P0 holding priority in the declare blockers step.
func _to_blocks(attacker: CardInstance, blocker: CardInstance) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	var blocks := {}
	if blocker != null: blocks[blocker.id] = attacker.id
	assert_ok(g.declare_blockers(1, blocks))
	assert_eq(g.current_step(), Mtg.Step.DECLARE_BLOCKERS)
	assert_eq(g.priority_player, 0)

## [param pid]'s next upkeep, with its triggers on the stack.
func _to_my_next_upkeep(pid := 0) -> void:
	var turn := g.turn_number
	var guard := 0
	while g.turn_number == turn and guard < 400:
		_advance_once()
		guard += 1
	while not (g.active_player == pid and g.current_step() == Mtg.Step.UPKEEP) and guard < 400:
		_advance_once()
		guard += 1
	assert_eq(g.active_player, pid)
	assert_eq(g.current_step(), Mtg.Step.UPKEEP)


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)
		assert_true(c.is_aura(), "%s enchants something" % card_name)


# ------------------------------------------------------------------- Agility --

func test_agility_gives_plus_one_and_flanking_that_shrinks_a_blocker() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var blocker := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	_enchant(0, "Agility", bear, [Mtg.ManaColor.R, Mtg.ManaColor.R])
	assert_eq([bear.cur_power, bear.cur_toughness], [3, 3])
	assert_eq(Flanking.instances(bear), 1)
	_to_blocks(bear, blocker)
	assert_false(g.stack.is_empty(), "the flanking trigger is on the stack (CR 702.25a)")
	resolve_stack()
	assert_eq([blocker.cur_power, blocker.cur_toughness], [2, 2], "the blocker without flanking gets -1/-1")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(blocker.zone, Mtg.Zone.GRAVEYARD, "a 3/3 kills the shrunken 2/2")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "and survives its 2 damage")

func test_agility_on_a_flanking_creature_is_a_second_instance() -> void:
	var knight := put_synthetic(0, CardData.new("Test Knight", "{1}{W}", Mtg.CardType.CREATURE).pt(2, 2) \
		.with_keywords([Mtg.Keyword.FLANKING]))
	var blocker := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	_enchant(0, "Agility", knight, [Mtg.ManaColor.R, Mtg.ManaColor.R])
	assert_eq(Flanking.instances(knight), 2, "never deduplicated (CR 702.25b)")
	_to_blocks(knight, blocker)
	resolve_stack()
	assert_eq([blocker.cur_power, blocker.cur_toughness], [1, 1])


# --------------------------------------------------------- Favorable Destiny --

func test_favorable_destiny_pumps_only_a_white_creature() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var unicorn := put_battlefield(0, "Pearled Unicorn")
	var bear := put_battlefield(0, "Grizzly Bears")
	_enchant(0, "Favorable Destiny", unicorn, [Mtg.ManaColor.W, Mtg.ManaColor.W])
	assert_eq([unicorn.cur_power, unicorn.cur_toughness], [3, 4], "+1/+2 while white")
	_enchant(0, "Favorable Destiny", bear, [Mtg.ManaColor.W, Mtg.ManaColor.W])
	assert_eq([bear.cur_power, bear.cur_toughness], [2, 2], "a green creature gets nothing")

func test_favorable_destiny_shroud_needs_another_creature_its_controller_controls() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var unicorn := put_battlefield(0, "Pearled Unicorn")
	put_battlefield(1, "Grizzly Bears")   # an opponent's creature does not count
	_enchant(0, "Favorable Destiny", unicorn, [Mtg.ManaColor.W, Mtg.ManaColor.W])
	assert_false(unicorn.cur_shroud, "alone: no shroud")
	var friend := put_battlefield(0, "Grizzly Bears")
	g.recalculate()
	assert_true(unicorn.cur_shroud, "another creature of its controller's: shroud")
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_refused(g.cast_spell(1, bolt, [TargetRef.card(unicorn)]))
	g.destroy(friend)
	assert_false(unicorn.cur_shroud, "the other creature left: shroud gone")
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(unicorn)]))


# ------------------------------------------------------------------ Pacifism --

func test_pacifism_stops_attacking_and_blocking() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	_enchant(0, "Pacifism", giant, [Mtg.ManaColor.W, Mtg.ManaColor.W])
	var mine := put_battlefield(0, "Pearled Unicorn")
	_enchant(0, "Pacifism", mine, [Mtg.ManaColor.W, Mtg.ManaColor.W])
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [mine.id]))
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {giant.id: bear.id}), "")
	assert_ok(g.declare_blockers(1, {}))


# ------------------------------------------------------------- Ritual of Steel --

func test_ritual_of_steel_gives_plus_zero_two_and_a_card_next_upkeep() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var before := g.players[0].hand.size()
	_enchant(0, "Ritual of Steel", bear, [Mtg.ManaColor.W, Mtg.ManaColor.W, Mtg.ManaColor.W])
	assert_eq([bear.cur_power, bear.cur_toughness], [2, 4])
	assert_eq(g.players[0].hand.size(), before, "no card yet")
	advance_to_next_turn()   # P1's turn: the NEXT turn's upkeep has passed
	assert_eq(g.players[0].hand.size(), before + 1, "the slow cantrip arrived in the next turn's upkeep")


# ------------------------------------------------------------- Ward of Lights --

func test_ward_of_lights_main_phase_cast_gives_lasting_protection() -> void:
	var seat := _seat(0)
	seat.color = Mtg.ManaColor.R
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var ward := _enchant(0, "Ward of Lights", bear, [Mtg.ManaColor.W, Mtg.ManaColor.W])
	assert_false(bool(ward.memory.get("flash_cast", false)))
	assert_ne(bear.cur_protection & Mtg.ManaColor.R, 0, "protection from the chosen colour")
	assert_eq(ward.zone, Mtg.Zone.BATTLEFIELD, "a white Ward is not removed by protection from red")
	advance_to_next_turn()
	assert_eq(ward.zone, Mtg.Zone.BATTLEFIELD, "cast at sorcery speed: kept")
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.card(bear)]), "")

func test_ward_of_lights_in_response_to_a_bolt_saves_the_creature_then_goes() -> void:
	var seat := _seat(0)
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var bolt := give_hand(1, "Lightning Bolt")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(1))
	var ward := give_hand(0, "Ward of Lights")
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(0, ward, [TargetRef.card(bear)]))
	assert_true(bool(ward.memory.get("flash_cast", false)), "the stack was not empty")
	resolve_stack()
	assert_eq(seat.color_hints, [Mtg.ManaColor.R], "the hint reads the red spell aimed at the creature")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "the Bolt's target is illegal: it does nothing")
	assert_eq(bear.damage, 0)
	_to_cleanup_priority()
	assert_eq(g.current_step(), Mtg.Step.CLEANUP)
	assert_eq(g.stack.size(), 1, "the sacrifice waits on the stack")
	assert_eq(ward.zone, Mtg.Zone.BATTLEFIELD)
	resolve_stack()
	assert_eq(ward.zone, Mtg.Zone.GRAVEYARD, "sacrificed at the beginning of the next cleanup step")
	assert_eq(bear.cur_protection & Mtg.ManaColor.R, 0)

func test_ward_of_lights_sheds_an_aura_of_the_chosen_colour_but_not_itself() -> void:
	var seat := _seat(0)
	seat.color = Mtg.ManaColor.G
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var armor := _enchant(0, "Armor of Thorns", bear, [Mtg.ManaColor.G, Mtg.ManaColor.G])
	assert_eq(bear.cur_power, 4)
	var ward := _enchant(0, "Ward of Lights", bear, [Mtg.ManaColor.W, Mtg.ManaColor.W])
	assert_eq(armor.zone, Mtg.Zone.GRAVEYARD, "the green Aura falls off a creature with protection from green (CR 702.16d)")
	assert_eq(ward.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.cur_power, 2)


# --------------------------------------------------------------- Mind Harness --

func test_mind_harness_steals_only_a_red_or_green_creature() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	var unicorn := put_battlefield(1, "Pearled Unicorn")
	var harness := give_hand(0, "Mind Harness")
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(0, harness, [TargetRef.card(unicorn)]))
	assert_ok(g.cast_spell(0, harness, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.controller_id, 0, "You control enchanted creature")
	g.destroy(harness)
	assert_eq(giant.controller_id, 1, "control returns when the Aura leaves")

func test_mind_harness_cumulative_upkeep_paid_then_declined() -> void:
	var seat := _seat(0)
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	var harness := _enchant(0, "Mind Harness", giant, [Mtg.ManaColor.U])
	_to_my_next_upkeep()
	add_mana(0, Mtg.ManaColor.C)
	resolve_stack()
	assert_eq(int(harness.counters.get("age", 0)), 1)
	assert_eq(harness.zone, Mtg.Zone.BATTLEFIELD, "paid {1}")
	assert_eq(giant.controller_id, 0)
	seat.yes = false
	_to_my_next_upkeep()
	resolve_stack()
	assert_eq(harness.zone, Mtg.Zone.GRAVEYARD, "declined: sacrificed")
	assert_eq(giant.controller_id, 1, "and the creature goes home")

func test_mind_harness_falls_off_a_creature_that_stops_being_red_or_green() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var harness := _enchant(0, "Mind Harness", bear, [Mtg.ManaColor.U])
	assert_eq(bear.controller_id, 0)
	# Grave Servitude makes it black (a sorcery-speed cast: P0 controls it now).
	_enchant(0, "Grave Servitude", bear, [Mtg.ManaColor.B, Mtg.ManaColor.B])
	assert_eq(harness.zone, Mtg.Zone.GRAVEYARD, "no longer a red or green creature (CR 704.5m)")
	assert_eq(bear.controller_id, 1)


# ----------------------------------------------------------------------- Soar --

func test_soar_main_phase_cast_stays() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var soar := _enchant(0, "Soar", bear, [Mtg.ManaColor.U, Mtg.ManaColor.U])
	assert_eq([bear.cur_power, bear.cur_toughness], [2, 3])
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	advance_to_next_turn()
	assert_eq(soar.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))

func test_soar_cast_as_a_surprise_blocker_on_the_opponents_turn_goes_at_that_cleanup() -> void:
	advance_to_next_turn()   # P1's turn
	var angel := put_battlefield(1, "Serra Angel")
	var bear := put_battlefield(0, "Craw Wurm")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [angel.id]))
	assert_ok(g.pass_priority(1))
	var soar := give_hand(0, "Soar")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, soar, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {bear.id: angel.id}))
	advance_to_step(Mtg.Step.END)
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD, "a 6/5 flier blocked and killed it")
	assert_eq(soar.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_next_turn()
	assert_eq(soar.zone, Mtg.Zone.GRAVEYARD, "sacrificed at that turn's cleanup step")
	assert_true(g.players[0].graveyard.has(soar))


# --------------------------------------------------------------------- Thirst --

func test_thirst_taps_locks_and_asks_for_blue_each_upkeep() -> void:
	var seat := _seat(0)
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	var thirst := _enchant(0, "Thirst", giant, [Mtg.ManaColor.U, Mtg.ManaColor.U, Mtg.ManaColor.U])
	assert_true(giant.tapped, "tapped as the Aura enters")
	advance_to_next_turn()   # P1's untap step passed
	assert_true(giant.tapped, "doesn't untap during its controller's untap step")
	_to_my_next_upkeep()
	add_mana(0, Mtg.ManaColor.U)
	resolve_stack()
	assert_eq(thirst.zone, Mtg.Zone.BATTLEFIELD, "paid {U}")
	seat.yes = false
	_to_my_next_upkeep()
	resolve_stack()
	assert_eq(thirst.zone, Mtg.Zone.GRAVEYARD, "not paid: sacrificed")
	advance_to_next_turn()
	assert_false(giant.tapped, "free again at its controller's next untap step")


# --------------------------------------------------------------- Binding Agony --

func test_binding_agony_mirrors_damage_to_the_creatures_controller() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var wurm := put_battlefield(1, "Craw Wurm")
	_enchant(0, "Binding Agony", wurm, [Mtg.ManaColor.B, Mtg.ManaColor.B])
	_bolt(0, TargetRef.card(wurm))
	resolve_stack()
	assert_eq(wurm.damage, 3)
	assert_eq(g.players[1].life, 17, "that much damage to that creature's controller")
	assert_eq(g.players[0].life, 20)

func test_binding_agony_still_deals_damage_when_the_creature_dies() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_next_turn()   # P1's main phase
	var agony := _enchant(1, "Binding Agony", bear, [Mtg.ManaColor.B, Mtg.ManaColor.B])
	_bolt(1, TargetRef.card(bear))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(agony.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 17, "3 damage was dealt, the Aura deals 3 as it last existed")
	assert_eq(g.players[1].life, 20)


# ---------------------------------------------------------------- Enfeeblement --

func test_enfeeblement_shrinks_and_kills() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var wurm := put_battlefield(1, "Craw Wurm")
	var bear := put_battlefield(1, "Grizzly Bears")
	_enchant(0, "Enfeeblement", wurm, [Mtg.ManaColor.B, Mtg.ManaColor.B])
	assert_eq([wurm.cur_power, wurm.cur_toughness], [4, 2])
	_enchant(0, "Enfeeblement", bear, [Mtg.ManaColor.B, Mtg.ManaColor.B])
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------------- Grave Servitude --

func test_grave_servitude_makes_it_black_and_three_one_stronger() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var servitude := _enchant(0, "Grave Servitude", bear, [Mtg.ManaColor.B, Mtg.ManaColor.B])
	assert_eq([bear.cur_power, bear.cur_toughness], [5, 1])
	assert_eq(bear.cur_colors, Mtg.ManaColor.B, "is black — instead of green (CR 105.3)")
	var terror := give_hand(1, "Terror")
	add_mana(1, Mtg.ManaColor.B, 2)
	assert_ok(g.pass_priority(0))
	assert_refused(g.cast_spell(1, terror, [TargetRef.card(bear)]))
	advance_to_next_turn()
	assert_eq(servitude.zone, Mtg.Zone.BATTLEFIELD, "main-phase cast: kept")

func test_grave_servitude_cast_in_combat_is_sacrificed_and_the_colour_returns() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	var servitude := _enchant(0, "Grave Servitude", bear, [Mtg.ManaColor.B, Mtg.ManaColor.B])
	assert_true(bool(servitude.memory.get("flash_cast", false)))
	run_combat([bear.id])
	assert_eq(g.players[1].life, 15)
	advance_to_next_turn()
	assert_eq(servitude.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.cur_colors, Mtg.ManaColor.G)
	assert_eq(bear.cur_power, 2)


# --------------------------------------------------------- Consuming Ferocity --

func test_consuming_ferocity_refuses_a_wall() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var wall := put_battlefield(1, "Wall of Stone")
	var ferocity := give_hand(0, "Consuming Ferocity")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_refused(g.cast_spell(0, ferocity, [TargetRef.card(wall)]))

func test_consuming_ferocity_counts_up_then_burns_and_destroys_without_regeneration() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var troll := put_battlefield(1, "Uthden Troll")
	var ferocity := _enchant(0, "Consuming Ferocity", troll, [Mtg.ManaColor.R, Mtg.ManaColor.R])
	assert_eq(troll.cur_power, 3, "+1/+0")
	_to_my_next_upkeep()
	resolve_stack()
	assert_eq(int(troll.counters.get("+1/+0", 0)), 1)
	assert_eq(troll.cur_power, 4)
	assert_eq(g.players[1].life, 20, "fewer than three counters: nothing else")
	g.add_counters(troll, "+1/+0")   # setup: the second upkeep's counter
	_to_my_next_upkeep()
	# The troll's controller regenerates it in response; it doesn't matter.
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(1, troll, 0))
	resolve_stack()
	assert_eq(g.players[1].life, 14, "it deals damage equal to its power (2+1+3) to its controller")
	assert_eq(troll.zone, Mtg.Zone.GRAVEYARD, "destroyed, and it can't be regenerated")
	assert_eq(ferocity.zone, Mtg.Zone.GRAVEYARD)


# --------------------------------------------------------- Lightning Reflexes --

func test_lightning_reflexes_after_blocks_wins_the_fight_then_goes() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var blocker := put_battlefield(1, "Grizzly Bears")
	_to_blocks(bear, blocker)
	var reflexes := give_hand(0, "Lightning Reflexes")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, reflexes, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_eq(bear.cur_power, 3)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(blocker.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "first strike: the blocker never struck back")
	advance_to_next_turn()
	assert_eq(reflexes.zone, Mtg.Zone.GRAVEYARD)

func test_lightning_reflexes_main_phase_cast_stays() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var reflexes := _enchant(0, "Lightning Reflexes", bear, [Mtg.ManaColor.R, Mtg.ManaColor.R])
	advance_to_next_turn()
	assert_eq(reflexes.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE))


# ------------------------------------------------------------ Armor of Thorns --

func test_armor_of_thorns_cast_after_blocks_its_creature_survives_the_cleanup_sacrifice() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	_to_blocks(bear, giant)
	var armor := give_hand(0, "Armor of Thorns")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, armor, [TargetRef.card(bear)]))
	assert_true(bool(armor.memory.get("flash_cast", false)))
	resolve_stack()
	assert_eq([bear.cur_power, bear.cur_toughness], [4, 4])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.damage, 3)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	_to_cleanup_priority()
	assert_eq(g.current_step(), Mtg.Step.CLEANUP)
	assert_eq(bear.damage, 0, "damage wore off first (CR 514.2)")
	assert_eq(g.stack.size(), 1, "then the sacrifice trigger, on the stack")
	assert_eq(g.priority_player, 0, "the active player may respond")
	resolve_stack()
	assert_eq(armor.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "a 2/2 with no damage survives")
	assert_eq(bear.cur_toughness, 2)

func test_armor_of_thorns_flash_rider_under_the_fifth_edition_rules() -> void:
	g.rules.set_edition("fifth")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	_to_blocks(bear, giant)
	var armor := give_hand(0, "Armor of Thorns")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, armor, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	advance_to_next_turn()
	assert_eq(armor.zone, Mtg.Zone.GRAVEYARD, "the same cleanup sacrifice")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "after the damage wore off")

func test_armor_of_thorns_main_phase_cast_stays_and_refuses_a_black_creature() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var zombie := put_battlefield(0, "Scathe Zombies")
	var armor := give_hand(0, "Armor of Thorns")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(0, armor, [TargetRef.card(zombie)]))
	assert_ok(g.cast_spell(0, armor, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_next_turn()
	assert_eq(armor.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.cur_power, 4)

func test_armor_of_thorns_on_a_creature_that_turns_black_falls_off() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var armor := _enchant(0, "Armor of Thorns", bear, [Mtg.ManaColor.G, Mtg.ManaColor.G])
	_enchant(0, "Grave Servitude", bear, [Mtg.ManaColor.B, Mtg.ManaColor.B])
	assert_eq(armor.zone, Mtg.Zone.GRAVEYARD, "enchant nonblack creature: illegal now (CR 704.5m)")
	assert_eq([bear.cur_power, bear.cur_toughness], [5, 1])

func test_armor_of_thorns_fizzles_when_its_target_turns_black_in_response() -> void:
	# CR 608.2b: an Aura spell whose only target became illegal does not resolve.
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var armor := give_hand(0, "Armor of Thorns")
	var servitude := give_hand(0, "Grave Servitude")
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, armor, [TargetRef.card(bear)]))
	assert_ok(g.cast_spell(0, servitude, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(servitude.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(armor.zone, Mtg.Zone.GRAVEYARD, "its target was black when it tried to resolve")
	assert_eq(bear.cur_power, 5)


# -------------------------------------------------------------- Decomposition --

func test_decomposition_gives_a_black_creature_life_upkeep_and_a_death_toll() -> void:
	var seat := _seat(1)
	advance_to_step(Mtg.Step.MAIN1)
	var zombie := put_battlefield(1, "Scathe Zombies")
	var bear := put_battlefield(1, "Grizzly Bears")
	var decomposition := give_hand(0, "Decomposition")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(0, decomposition, [TargetRef.card(bear)]))
	assert_ok(g.cast_spell(0, decomposition, [TargetRef.card(zombie)]))
	resolve_stack()
	advance_to_next_turn()   # P1's upkeep: the creature's controller pays
	assert_eq(int(zombie.counters.get("age", 0)), 1)
	assert_eq(g.players[1].life, 19, "Cumulative upkeep—Pay 1 life, paid by the creature's controller")
	assert_eq(g.players[0].life, 20)
	seat.yes = false
	advance_to_next_turn()
	advance_to_next_turn()   # P1's next upkeep: declined
	assert_eq(zombie.zone, Mtg.Zone.GRAVEYARD, "sacrificed")
	assert_eq(decomposition.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 17, "dies: its controller loses 2 life")


# ----------------------------------------------------------------- Wellspring --

func test_wellspring_borrows_the_land_on_entry_and_each_of_your_upkeeps() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var forest := put_battlefield(1, "Forest")
	g.tap_permanent(forest)
	var wellspring := _enchant(0, "Wellspring", forest, [Mtg.ManaColor.G, Mtg.ManaColor.G, Mtg.ManaColor.W])
	assert_eq(forest.controller_id, 0, "control until end of turn")
	advance_to_next_turn()
	assert_eq(forest.controller_id, 1, "back to its owner")
	assert_false(forest.tapped, "its owner untapped it")
	g.tap_permanent(forest)
	_to_my_next_upkeep()
	resolve_stack()
	assert_eq(forest.controller_id, 0)
	assert_false(forest.tapped, "untapped at the beginning of your upkeep")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(0, forest))
	assert_eq(wellspring.zone, Mtg.Zone.BATTLEFIELD)
