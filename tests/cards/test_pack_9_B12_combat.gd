extends GameTest
## Pack 9 (the Tempest block), batch B12: the Exodus combat cards in
## cards/sets/exo/_combat.gd — Cinder Crawler, Crashing Boars, Elven
## Palisade, Elvish Berserker, Exalted Dragon, High Ground, Monstrous Hound,
## Pygmy Troll, Rabid Wolverines, Reckless Ogre, Reconnaissance, Scalding
## Salamander and Wall of Nets.

const CLAIMED := ["Cinder Crawler", "Crashing Boars", "Elven Palisade", "Elvish Berserker",
	"Exalted Dragon", "High Ground", "Monstrous Hound", "Pygmy Troll", "Rabid Wolverines",
	"Reckless Ogre", "Reconnaissance", "Scalding Salamander", "Wall of Nets"]

## Answers yes/no with [member yes]; a card ask with the candidate named
## [member pick] when there is one.
class Seat extends DecisionAgent:
	var yes := true
	var pick := ""
	var asked: Array[String] = []
	func answer_yes_no(_g: MtgGame, _pid: int, prompt: String, _hint: bool) -> bool:
		asked.append(prompt)
		return yes
	func answer_card(g: MtgGame, pid: int, candidates: Array[CardInstance], prompt: String) -> CardInstance:
		asked.append(prompt)
		for c in candidates:
			if c.data.card_name == pick: return c
		return super(g, pid, candidates, prompt)

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

func _pt(i: CardInstance) -> Array: return [i.cur_power, i.cur_toughness]

## P0 attacks with [param attackers]; P1 declares [param blocks]; returns in
## the declare blockers step with the triggers resolved.
func _to_blocks(attackers: Array, blocks: Dictionary) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, attackers))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, blocks))
	resolve_stack()

func _lands(pid: int, n: int, land := "Forest") -> void:
	for _k in n: put_battlefield(pid, land)


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# ---------------------------------------------------------- Cinder Crawler --

func test_cinder_crawler_pumps_only_while_blocked() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var crawler := put_battlefield(0, "Cinder Crawler")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.activate_ability(0, crawler, 0), "blocked")
	var wall := put_battlefield(1, "Hill Giant")
	_to_blocks([crawler.id], {wall.id: crawler.id})
	assert_eq(g.priority_player, 0)
	for _k in 2:
		add_mana(0, Mtg.ManaColor.R)
		assert_ok(g.activate_ability(0, crawler, 0))
		resolve_stack()
	assert_eq(_pt(crawler), [3, 2])

func test_cinder_crawler_is_refused_when_its_attack_goes_unblocked() -> void:
	var crawler := put_battlefield(0, "Cinder Crawler")
	_to_blocks([crawler.id], {})
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.activate_ability(0, crawler, 0), "blocked")


# ---------------------------------------------------------- Crashing Boars --

func test_crashing_boars_makes_the_defenders_chosen_creature_block_it() -> void:
	var seat := _seat(1)
	seat.pick = "Hill Giant"
	var boars := put_battlefield(0, "Crashing Boars")
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [boars.id]))
	resolve_stack()
	assert_true(seat.asked.size() >= 1, "the defending player chooses")
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {}), "must block")
	assert_refused(g.declare_blockers(1, {bear.id: boars.id}), "must block")
	assert_ok(g.declare_blockers(1, {giant.id: boars.id}))
	advance_to_next_turn()
	assert_false(boars.cur_must_be_blocked, "this turn only")

func test_crashing_boars_ignores_tapped_creatures_and_the_heuristic_picks_a_safe_block() -> void:
	var boars := put_battlefield(0, "Crashing Boars")
	var tapped_giant := put_battlefield(1, "Hill Giant")
	g.tap_permanent(tapped_giant)
	var bear := put_battlefield(1, "Grizzly Bears")
	var wall := put_synthetic(1, CardData.new("Test Wall", "{1}", Mtg.CardType.CREATURE).pt(0, 6) \
		.with_subtypes(["wall"]).with_keywords([Mtg.Keyword.DEFENDER]))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [boars.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	# The ranked default: the 0/6 survives the 4/4, so it is the one asked.
	assert_refused(g.declare_blockers(1, {bear.id: boars.id}), "must block")
	assert_ok(g.declare_blockers(1, {wall.id: boars.id}))
	assert_true(tapped_giant.tapped)

func test_crashing_boars_with_no_untapped_creature_asks_nothing() -> void:
	var boars := put_battlefield(0, "Crashing Boars")
	var giant := put_battlefield(1, "Hill Giant")
	g.tap_permanent(giant)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [boars.id]))
	resolve_stack()
	assert_false(boars.cur_must_be_blocked)
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))


# ----------------------------------------------------------- Elven Palisade --

func test_elven_palisade_sacrifices_a_forest_to_shrink_an_attacker() -> void:
	var palisade := put_battlefield(1, "Elven Palisade")
	var giant := put_battlefield(0, "Hill Giant")
	assert_refused(g.activate_ability(1, palisade, 0, [TargetRef.card(giant)]), "")
	var forest := put_battlefield(1, "Forest")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	assert_ok(g.pass_priority(0))
	assert_refused(g.activate_ability(1, palisade, 0, [TargetRef.card(put_battlefield(1, "Grizzly Bears"))]), "")
	assert_ok(g.activate_ability(1, palisade, 0, [TargetRef.card(giant)]))
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD, "the Forest is the cost")
	resolve_stack()
	assert_eq(_pt(giant), [0, 3])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20)


# --------------------------------------------------------- Elvish Berserker --

func test_elvish_berserker_grows_once_per_blocker_counted_on_resolution() -> void:
	var elf := put_battlefield(0, "Elvish Berserker")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Llanowar Elves")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [elf.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {a.id: elf.id, b.id: elf.id}))
	assert_eq(g.stack.size(), 1, "one trigger: it becomes blocked once")
	resolve_stack()
	assert_eq(_pt(elf), [3, 3])

func test_elvish_berserker_unblocked_gets_nothing() -> void:
	var elf := put_battlefield(0, "Elvish Berserker")
	run_combat([elf.id])
	assert_eq(_pt(elf), [1, 1])
	assert_eq(g.players[1].life, 19)


# ----------------------------------------------------------- Exalted Dragon --

func test_exalted_dragon_sacrifices_a_land_to_attack() -> void:
	var dragon := put_battlefield(0, "Exalted Dragon")
	var plains := put_battlefield(0, "Plains")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [dragon.id]))
	assert_eq(plains.zone, Mtg.Zone.GRAVEYARD, "paid as attackers are declared")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 15)

func test_exalted_dragon_cannot_attack_without_a_land() -> void:
	var dragon := put_battlefield(0, "Exalted Dragon")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [dragon.id]), "land")
	assert_ok(g.declare_attackers(0, []))


# -------------------------------------------------------------- High Ground --

func test_high_ground_lets_your_creatures_block_an_additional_creature() -> void:
	put_battlefield(1, "High Ground")
	var giant := put_battlefield(1, "Hill Giant")
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Llanowar Elves")
	assert_eq(g.blocks_allowed(giant), 2)
	assert_eq(g.blocks_allowed(a), 1, "the opponent's creatures are not yours")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [a.id, b.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: [a.id, b.id]}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "both blocked")

func test_high_ground_adds_to_a_printed_extra_block() -> void:
	put_battlefield(0, "High Ground")
	var giant := put_battlefield(0, "Two-Headed Giant of Foriys")
	assert_eq(g.blocks_allowed(giant), 3, "printed and granted additional blocks add up (CR 509.1b)")


# ---------------------------------------------------------- Monstrous Hound --

func test_monstrous_hound_attacks_and_blocks_only_with_more_lands() -> void:
	var hound := put_battlefield(0, "Monstrous Hound")
	_lands(0, 2)
	_lands(1, 2)
	g.recalculate()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [hound.id]), "")
	put_battlefield(0, "Forest")
	g.recalculate()
	assert_ok(g.declare_attackers(0, [hound.id]))

func test_monstrous_hound_blocks_only_with_more_lands_than_the_attacker() -> void:
	var hound := put_battlefield(1, "Monstrous Hound")
	var bear := put_battlefield(0, "Grizzly Bears")
	_lands(0, 3)
	_lands(1, 3)
	g.recalculate()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {hound.id: bear.id}), "")
	put_battlefield(1, "Forest")
	g.recalculate()
	assert_ok(g.declare_blockers(1, {hound.id: bear.id}))


# ------------------------------------------- Pygmy Troll / Rabid Wolverines --

func test_pygmy_troll_grows_for_each_blocker_and_regenerates() -> void:
	var troll := put_battlefield(0, "Pygmy Troll")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Llanowar Elves")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [troll.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {a.id: troll.id, b.id: troll.id}))
	assert_eq(g.stack.size(), 2, "one trigger per blocking creature")
	resolve_stack()
	assert_eq(_pt(troll), [3, 3])
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, troll, 0))
	resolve_stack()
	assert_eq(troll.regeneration_shields, 1)

func test_rabid_wolverines_grow_when_blocked_and_not_otherwise() -> void:
	var wolves := put_battlefield(0, "Rabid Wolverines")
	var bear := put_battlefield(1, "Grizzly Bears")
	_to_blocks([wolves.id], {bear.id: wolves.id})
	assert_eq(_pt(wolves), [5, 5])
	advance_to_next_turn()
	assert_eq(_pt(wolves), [4, 4])
	advance_to_next_turn()
	run_combat([wolves.id])
	assert_eq(_pt(wolves), [4, 4], "unblocked: nothing")


# ------------------------------------------------------------ Reckless Ogre --

func test_reckless_ogre_gets_three_only_attacking_alone() -> void:
	var ogre := put_battlefield(0, "Reckless Ogre")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [ogre.id, bear.id]))
	resolve_stack()
	assert_eq(_pt(ogre), [3, 2], "not alone")
	advance_to_next_turn()
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [ogre.id]))
	resolve_stack()
	assert_eq(_pt(ogre), [6, 2])


# ----------------------------------------------------------- Reconnaissance --

func test_reconnaissance_removes_your_attacker_from_combat_and_untaps_it() -> void:
	var recon := put_battlefield(0, "Reconnaissance")
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	assert_refused(g.activate_ability(0, recon, 0, [TargetRef.card(bear)]), "")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {theirs.id: bear.id}))
	assert_eq(g.priority_player, 0)
	assert_refused(g.activate_ability(0, recon, 0, [TargetRef.card(theirs)]), "")
	assert_ok(g.activate_ability(0, recon, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_false(g.combat.attackers.has(bear.id))
	assert_false(bear.tapped)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "out of combat: the Giant deals it nothing")
	assert_eq(theirs.damage, 0)


# ------------------------------------------------------ Scalding Salamander --

func test_scalding_salamander_pings_the_defenders_ground_creatures() -> void:
	var seat := _seat(0)
	var sal := put_battlefield(0, "Scalding Salamander")
	var mine := put_battlefield(0, "Llanowar Elves")
	var elf := put_battlefield(1, "Llanowar Elves")
	var bird := put_synthetic(1, CardData.new("Test Bird", "{U}", Mtg.CardType.CREATURE).pt(1, 1) \
		.with_keywords([Mtg.Keyword.FLYING]))
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [sal.id]))
	resolve_stack()
	assert_eq(seat.asked.size(), 1)
	assert_eq(elf.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.damage, 1)
	assert_eq(bird.zone, Mtg.Zone.BATTLEFIELD, "flying is spared")
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD, "only the defending player's")

func test_scalding_salamander_is_optional() -> void:
	var seat := _seat(0)
	seat.yes = false
	var sal := put_battlefield(0, "Scalding Salamander")
	var elf := put_battlefield(1, "Llanowar Elves")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [sal.id]))
	resolve_stack()
	assert_eq(elf.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------------- Wall of Nets --

func test_wall_of_nets_exiles_what_it_blocked_until_it_leaves() -> void:
	var wall := put_battlefield(1, "Wall of Nets")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id, giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: bear.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.EXILE, "blocked by the Wall: exiled at end of combat")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "unblocked: untouched")
	assert_eq(g.players[1].life, 17)
	g.destroy(wall)
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "returned when the Wall left")
	assert_eq(bear.controller_id, 0, "under its owner's control")

func test_wall_of_nets_that_blocked_nothing_exiles_nothing() -> void:
	var wall := put_battlefield(1, "Wall of Nets")
	var bear := put_battlefield(0, "Grizzly Bears")
	run_combat([bear.id])
	assert_true(g.stack.is_empty())
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(wall.data.has_keyword(Mtg.Keyword.DEFENDER))
