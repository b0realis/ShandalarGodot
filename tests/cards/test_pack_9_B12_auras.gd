extends GameTest
## Pack 9 (the Tempest block), batch B12: the Exodus Auras in
## cards/sets/exo/_auras.gd — Bequeathal, Cunning, Curiosity, Cursed Flesh,
## Dizzying Gaze, Maniacal Rage, Paroxysm, Predatory Hunger, Robe of Mirrors
## and Shackles. Each card: not pending, its main effect, a refused or
## non-triggering case, and the interactions its text implies.

const CLAIMED := ["Bequeathal", "Cunning", "Curiosity", "Cursed Flesh", "Dizzying Gaze",
	"Maniacal Rage", "Paroxysm", "Predatory Hunger", "Robe of Mirrors", "Shackles"]

## Answers every yes/no with [member yes] and remembers the prompts.
class Seat extends DecisionAgent:
	var yes := true
	var asked: Array[String] = []
	func answer_yes_no(_g: MtgGame, _pid: int, prompt: String, _hint: bool) -> bool:
		asked.append(prompt)
		return yes

func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)

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

func _bolt(pid: int, target: TargetRef) -> void:
	var bolt := give_hand(pid, "Lightning Bolt")
	add_mana(pid, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(pid, bolt, [target]))
	resolve_stack()

func _pt(i: CardInstance) -> Array: return [i.cur_power, i.cur_toughness]

## Pass priority until the cleanup step holds a trigger on the stack (or the
## turn moved on — the caller asserts which).
func _to_cleanup_priority() -> void:
	var turn := g.turn_number
	var guard := 0
	while not (g.current_step() == Mtg.Step.CLEANUP and not g.stack.is_empty()) \
			and g.turn_number == turn and guard < 200:
		_advance_once()
		guard += 1

## [param pid]'s next upkeep, with its triggers on the stack.
func _to_upkeep_of(pid: int) -> void:
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
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)
		assert_true(c.is_aura(), "%s enchants something" % card_name)


# -------------------------------------------------------------- Bequeathal --

func test_bequeathal_draws_its_controller_two_when_the_creature_dies() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var aura := _enchant(0, "Bequeathal", bear, [Mtg.ManaColor.G])
	assert_eq(aura.attached_to, bear.id, "any creature, the opponent's too")
	var hand := g.players[0].hand.size()
	_bolt(0, TargetRef.card(bear))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].hand.size(), hand + 2, "you — the Aura's controller — draw two")
	assert_eq(g.players[1].hand.size(), 0)

func test_bequeathal_does_nothing_when_the_creature_is_bounced() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	_enchant(0, "Bequeathal", bear, [Mtg.ManaColor.G])
	var unsummon := give_hand(1, "Unsummon")
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, unsummon, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].hand.size(), 1, "only the Bear came back: it did not die")


# ----------------------------------------------------------------- Cunning --

func test_cunning_pumps_and_is_sacrificed_at_cleanup_after_its_creature_attacks() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := _enchant(0, "Cunning", bear, [Mtg.ManaColor.U, Mtg.ManaColor.G])
	assert_eq(_pt(bear), [5, 5])
	run_combat([bear.id])
	assert_eq(g.players[1].life, 15, "it attacked as a 5/5")
	assert_eq(aura.zone, Mtg.Zone.BATTLEFIELD, "not before the cleanup step")
	_to_cleanup_priority()
	assert_eq(g.current_step(), Mtg.Step.CLEANUP)
	resolve_stack()
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD, "sacrificed at the beginning of the next cleanup step")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)

func test_cunning_is_sacrificed_after_its_creature_blocks_but_stays_otherwise() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var wall := put_battlefield(1, "Grizzly Bears")
	# P1's Aura: cast on P1's own creature during P1's main phase.
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	var aura := _enchant(1, "Cunning", wall, [Mtg.ManaColor.U, Mtg.ManaColor.G])
	advance_to_next_turn()
	assert_eq(g.active_player, 0)
	assert_eq(aura.zone, Mtg.Zone.BATTLEFIELD, "no attack, no block: it stays")
	var giant := put_battlefield(0, "Hill Giant")
	run_combat([giant.id], {wall.id: giant.id})
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "a 5/5 blocker")
	_to_cleanup_priority()
	resolve_stack()
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD, "blocking counts too")


# --------------------------------------------------------------- Curiosity --

func test_curiosity_may_draw_when_the_creature_damages_an_opponent() -> void:
	var seat := _seat(0)
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	_enchant(0, "Curiosity", bear, [Mtg.ManaColor.U])
	run_combat([bear.id])
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	assert_eq(seat.asked.size(), 1)
	assert_eq(g.players[0].hand.size(), 1, "drew a card")

func test_curiosity_is_optional_and_ignores_damage_to_creatures() -> void:
	var seat := _seat(0)
	seat.yes = false
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	_enchant(0, "Curiosity", bear, [Mtg.ManaColor.U])
	run_combat([bear.id])
	resolve_stack()
	assert_eq(seat.asked.size(), 1)
	assert_eq(g.players[0].hand.size(), 0, "declined")
	advance_to_next_turn()
	advance_to_next_turn()
	var blocker := put_battlefield(1, "Hill Giant")
	seat.yes = true
	run_combat([bear.id], {blocker.id: bear.id})
	resolve_stack()
	assert_eq(seat.asked.size(), 1, "damage to a creature is not damage to an opponent")


# ------------------------------------------------------------ Cursed Flesh --

func test_cursed_flesh_shrinks_and_gives_fear() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	var elf := put_battlefield(1, "Llanowar Elves")
	_enchant(0, "Cursed Flesh", giant, [Mtg.ManaColor.B])
	assert_eq(_pt(giant), [2, 2])
	assert_true(giant.has_keyword(Mtg.Keyword.FEAR))
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ne(CombatState.block_illegality(g, bear, giant, 0), "", "a green creature can't block fear")
	_enchant(0, "Cursed Flesh", elf, [Mtg.ManaColor.B])
	assert_eq(elf.zone, Mtg.Zone.GRAVEYARD, "-1/-1 kills a 1/1")


# ----------------------------------------------------------- Dizzying Gaze --

func test_dizzying_gaze_lets_the_creature_ping_a_flyer_even_while_summoning_sick() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears", true)
	var aura := _enchant(0, "Dizzying Gaze", bear, [Mtg.ManaColor.R])
	var bird := put_synthetic(1, CardData.new("Test Bird", "{U}", Mtg.CardType.CREATURE).pt(1, 1) \
		.with_keywords([Mtg.Keyword.FLYING]))
	var ogre := put_battlefield(1, "Gray Ogre")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.activate_ability(0, aura, 0, [TargetRef.card(ogre)]), "")
	assert_ok(g.activate_ability(0, aura, 0, [TargetRef.card(bird)]))
	resolve_stack()
	assert_eq(bird.zone, Mtg.Zone.GRAVEYARD, "1 damage to target creature with flying")
	assert_false(bear.tapped, "not a {T} ability of the creature")

func test_dizzying_gaze_enchants_only_your_creature_and_falls_off_on_a_steal() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var theirs := put_battlefield(1, "Grizzly Bears")
	var gaze := give_hand(0, "Dizzying Gaze")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, gaze, [TargetRef.card(theirs)]), "")
	var mine := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.cast_spell(0, gaze, [TargetRef.card(mine)]))
	resolve_stack()
	assert_eq(gaze.attached_to, mine.id)
	g.change_control(mine, 1)
	g.check_state_based_actions()
	assert_eq(gaze.zone, Mtg.Zone.GRAVEYARD, "no longer a creature its controller controls (CR 303.4d)")


# ----------------------------------------------------------- Maniacal Rage --

func test_maniacal_rage_pumps_and_forbids_blocking() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	_enchant(0, "Maniacal Rage", bear, [Mtg.ManaColor.R, Mtg.ManaColor.R])
	assert_eq(_pt(bear), [4, 4])
	var attacker := put_battlefield(0, "Gray Ogre")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {bear.id: attacker.id}), "")
	assert_ok(g.declare_blockers(1, {}))


# ---------------------------------------------------------------- Paroxysm --

func test_paroxysm_destroys_the_creature_when_its_controller_reveals_a_land() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	_enchant(0, "Paroxysm", bear, [Mtg.ManaColor.R, Mtg.ManaColor.R])
	_to_upkeep_of(1)
	assert_false(g.stack.is_empty(), "the enchanted creature's controller's upkeep")
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the library is all Forests")

func test_paroxysm_pumps_on_a_nonland_and_never_fires_on_the_other_upkeep() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	_enchant(0, "Paroxysm", bear, [Mtg.ManaColor.R, Mtg.ManaColor.R])
	_to_upkeep_of(1)
	assert_true(g.stack.is_empty(), "not the enchanted creature's controller's upkeep")
	var top := give_hand(0, "Lightning Bolt")
	g.put_from_hand_on_top_of_library(top)
	_to_upkeep_of(0)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(_pt(bear), [5, 5], "+3/+3 until end of turn")
	assert_eq(g.players[0].library.back(), top, "revealed, not moved")
	advance_to_next_turn()
	assert_eq(_pt(bear), [2, 2])


# -------------------------------------------------------- Predatory Hunger --

func test_predatory_hunger_grows_on_each_opposing_creature_spell_only() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	_enchant(0, "Predatory Hunger", bear, [Mtg.ManaColor.G])
	var mine := give_hand(0, "Llanowar Elves")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, mine, []))
	resolve_stack()
	assert_eq(int(bear.counters.get("+1/+1", 0)), 0, "our own creature spell")
	advance_to_next_turn()
	var theirs := give_hand(1, "Grizzly Bears")
	add_mana(1, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(1, theirs, []))
	resolve_stack()
	assert_eq(int(bear.counters.get("+1/+1", 0)), 1, "an opponent's creature spell")
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(int(bear.counters.get("+1/+1", 0)), 1, "a noncreature spell")
	assert_eq(_pt(bear), [3, 3])


# --------------------------------------------------------- Robe of Mirrors --

func test_robe_of_mirrors_gives_shroud() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	_enchant(0, "Robe of Mirrors", bear, [Mtg.ManaColor.U])
	assert_true(bear.cur_shroud)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.card(bear)]), "")
	var giant := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(0, giant, [TargetRef.card(bear)]), "")


# ---------------------------------------------------------------- Shackles --

func test_shackles_keeps_the_creature_tapped_until_it_goes_home() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	g.tap_permanent(bear)
	var aura := _enchant(0, "Shackles", bear, [Mtg.ManaColor.W, Mtg.ManaColor.C, Mtg.ManaColor.C])
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_true(bear.tapped, "doesn't untap during its controller's untap step")
	advance_to_next_turn()
	assert_eq(g.active_player, 0)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(0, aura, 0))
	resolve_stack()
	assert_eq(aura.zone, Mtg.Zone.HAND, "{W}: back to its owner's hand")
	assert_true(g.players[0].hand.has(aura))
	advance_to_next_turn()
	assert_false(bear.tapped, "free again")
