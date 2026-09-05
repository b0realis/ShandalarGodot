extends GameTest
## 2026-09 audit pins, batch B: the Legends shelf and two Astral ("past")
## cards. Every test here quotes the printed line it protects and failed
## before the fix in the card file named above it; the handful marked
## SIMPLIFIED pin a shortcut the engine cannot express today, so they stay
## green on purpose and carry their ledger row in the comment.


## A seat that declines every optional choice — the "If the player does
## not" half of every "you may" clause.
## Overrides answer_card, the documented extension point — the choose_*
## funnel above it is what puts each question on the record (§1.3).
class DecliningAgent extends DecisionAgent:
	func answer_card(_game: MtgGame, _pid: int, _candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		return null


func _count_on_battlefield(pid: int, card_name: String) -> int:
	var n := 0
	for inst in g.players[pid].battlefield:
		if inst.data.card_name == card_name:
			n += 1
	return n


# ---------------------------------------------------------- Hazezon Tamar --

func test_hazezon_sands_arrive_even_when_he_is_sacrificed_in_response() -> void:
	# "create X ... tokens at the beginning of your next upkeep" is a DELAYED
	# trigger (CR 603.7a): it is independent of Hazezon, so sacrificing him
	# with the trigger on the stack — the card's signature line, since his
	# leave-trigger then finds no Sand Warriors to exile — still pays out.
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var hazezon := put_battlefield(0, "Hazezon Tamar")
	resolve_stack()                       # the arrival arms the delayed trigger
	advance_to_next_turn()                # the opponent's turn
	advance_to_step(Mtg.Step.UPKEEP)      # our next upkeep
	assert_eq(g.stack.size(), 1, "the sandstorm is waiting on the stack")
	g.sacrifice_permanent(hazezon)
	resolve_stack()
	assert_eq(_count_on_battlefield(0, "Sand Warrior"), 2, "one per land")


func test_hazezon_sands_arrive_after_he_is_already_dead() -> void:
	# Same rule, one turn earlier: the delayed trigger outlives its source
	# whatever happens to it before the upkeep arrives.
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var hazezon := put_battlefield(0, "Hazezon Tamar")
	resolve_stack()
	g.destroy(hazezon, false)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(hazezon.zone, Mtg.Zone.GRAVEYARD)
	advance_to_next_turn()
	advance_to_next_turn()                # our next upkeep goes by
	resolve_stack()
	assert_eq(_count_on_battlefield(0, "Sand Warrior"), 2,
		"the delayed trigger does not care that Hazezon is gone")


# ---------------------------------------------------------------- The Abyss --

func test_the_abyss_cannot_eat_a_creature_with_protection_from_black() -> void:
	# "destroy TARGET nonartifact creature": protection's T of DEBT
	# (CR 702.16b) makes a pro-black creature an illegal choice.
	put_battlefield(0, "The Abyss")
	var knight := put_battlefield(1, "White Knight")
	advance_to_next_turn()                # the opponent's upkeep
	resolve_stack()
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD, "pro-black cannot be targeted")


func test_the_abyss_takes_the_only_legal_creature() -> void:
	put_battlefield(0, "The Abyss")
	var knight := put_battlefield(1, "White Knight")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_next_turn()
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the legal target is the one that dies")
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------------- Takklemaggot --

func test_takklemaggot_lets_the_victim_pick_their_worst_creature() -> void:
	# "that creature's CONTROLLER chooses a creature that this card could
	# enchant" — the victim chooses, so they hand over their least valuable
	# body, not their best.
	var host := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")               # their best
	var runt := put_battlefield(1, "Mons's Goblin Raiders")     # their worst
	var maggot := give_hand(0, "Takklemaggot")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, maggot, [TargetRef.card(host)]))
	resolve_stack()
	g.destroy(host, false)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(maggot.attached_to, runt.id, "the victim gives up the 1/1")
	assert_eq(giant.attachments.size(), 0)
	assert_eq(maggot.controller_id, 0, "still ours")


func test_takklemaggot_skips_a_creature_it_could_not_enchant() -> void:
	# "a creature that this card COULD ENCHANT": protection's E of DEBT
	# (CR 702.16e) rules out the pro-black Wall, so the plague passes it by.
	var host := put_battlefield(1, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Light")             # 1/5, pro-black
	var runt := put_battlefield(1, "Mons's Goblin Raiders")
	var maggot := give_hand(0, "Takklemaggot")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, maggot, [TargetRef.card(host)]))
	resolve_stack()
	g.destroy(host, false)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(maggot.zone, Mtg.Zone.BATTLEFIELD, "it found a legal host")
	assert_eq(maggot.attached_to, runt.id)
	assert_eq(wall.attachments.size(), 0, "it can never land on the pro-black Wall")


# ------------------------------------------------------------------ Urborg --

func test_urborg_swampwalk_mode_strips_swampwalk_only() -> void:
	# Lifted 2026-09-02 (the "Landwalk stripping" ledger row): the floating
	# ability-loss carries a land-type list, so "loses swampwalk" leaves a
	# forestwalker alone.
	var urborg := put_battlefield(0, "Urborg")
	var dryads := put_battlefield(1, "Shanodin Dryads")   # forestwalk only
	assert_true(dryads.cur_landwalk.has("forest"))
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, urborg, 1, [TargetRef.card(dryads)]))
	resolve_stack()
	assert_eq(dryads.cur_landwalk, ["forest"],
		"'loses swampwalk' strips swampwalk and nothing else")


# -------------------------------------------------------------- Telekinesis --

func test_two_telekinesis_add_up_to_four_skipped_untaps() -> void:
	# "doesn't untap during its controller's next TWO untap steps" — a second
	# copy adds two more (CR 614-style stacking of independent effects).
	var bear := put_battlefield(1, "Grizzly Bears")
	var first := give_hand(0, "Telekinesis")
	var second := give_hand(0, "Telekinesis")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_ok(g.cast_spell(0, first, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.skip_untaps, 2)
	assert_ok(g.cast_spell(0, second, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.skip_untaps, 4, "the second lock adds to the first")


# ------------------------------------------------------------- Triassic Egg --

func test_triassic_egg_honours_a_declined_hatch() -> void:
	# "You MAY put a creature card from your hand onto the battlefield."
	g.set_agent(0, DecliningAgent.new())
	var egg := put_battlefield(0, "Triassic Egg")
	egg.counters["hatchling"] = 2
	var angel := give_hand(0, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, egg, 1, []))
	resolve_stack()
	assert_eq(egg.zone, Mtg.Zone.GRAVEYARD, "the sacrifice was a cost, paid either way")
	assert_eq(angel.zone, Mtg.Zone.HAND, "a declined 'may' leaves the card in hand")


# -------------------------------------------------------- Wall of Tombstones --

func test_wall_of_tombstones_locks_its_toughness_in_at_upkeep() -> void:
	# "AT THE BEGINNING OF YOUR UPKEEP, change this creature's base toughness
	# to 1 plus the number of creature cards in your graveyard." The value is
	# fixed when the trigger resolves and lasts indefinitely — it does not
	# follow the graveyard around during the turn.
	var wall := put_battlefield(0, "Wall of Tombstones")
	var bear := put_battlefield(0, "Grizzly Bears")
	var lions := put_battlefield(0, "Savannah Lions")
	g.destroy(bear, false)
	g.destroy(lions, false)
	g.recalculate()
	assert_eq(wall.cur_toughness, 1, "no upkeep has happened yet: still a printed 0/1")
	advance_to_next_turn()
	advance_to_next_turn()                # our upkeep locks in 1 + two corpses
	resolve_stack()
	assert_eq(wall.cur_toughness, 3)
	var giant := put_battlefield(0, "Hill Giant")
	g.destroy(giant, false)
	g.recalculate()
	assert_eq(wall.cur_toughness, 3, "a mid-turn corpse waits for the next upkeep")


# ------------------------------------------------------------------ Stangg --

func test_stangg_ignores_a_stangg_twin_that_is_not_his() -> void:
	# "Sacrifice Stangg when THAT TOKEN leaves the battlefield" — that one,
	# not any permanent that happens to be named Stangg Twin.
	var stangg := give_hand(0, "Stangg")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, stangg, []))
	resolve_stack()
	var twin := g.find_on_battlefield(0, "Stangg Twin")
	assert_not_null(twin)
	# A second Stangg cannot exist (the 1997 legend rule buries the newer
	# one), so the rival Twin is minted directly — and without the legendary
	# supertype, so the legend rule does not bury it before it can be killed.
	# The bug matched on NAME alone, so this was enough to kill our Stangg.
	var rival := g.create_token(1, CardData.new(
		"Stangg Twin", "{R}{G}", Mtg.CardType.CREATURE).pt(3, 4).oracle(""))[0]
	g.destroy(rival, false)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(stangg.zone, Mtg.Zone.BATTLEFIELD, "someone else's Twin is not ours")
	assert_eq(twin.zone, Mtg.Zone.BATTLEFIELD)


# --------------------------------------------------------- Ivory Guardians --

func test_ivory_guardians_ignore_a_token_red_permanent() -> void:
	# "as long as an opponent controls a NONTOKEN red permanent".
	var guardians := put_battlefield(0, "Ivory Guardians")
	var egg := put_battlefield(1, "Rukh Egg")        # {3}{R}: a red NONTOKEN
	g.recalculate()
	assert_eq(guardians.cur_power, 4, "a nontoken red permanent switches them on")
	g.destroy(egg, false)
	g.check_state_based_actions()
	resolve_stack()
	advance_to_step(Mtg.Step.END)                    # the Rukh hatches
	resolve_stack()
	var rukh := g.find_on_battlefield(1, "Rukh")
	assert_not_null(rukh, "the 4/4 red Bird token arrived")
	assert_true(rukh.is_token)
	g.recalculate()
	assert_eq(guardians.cur_power, 3, "a TOKEN red permanent does not count")
	assert_eq(guardians.cur_toughness, 3)


# ------------------------------------------------------- Beasts of Bogardan --

func test_beasts_of_bogardan_ignore_token_white_permanents() -> void:
	# Same clause, white side. Hazezon's Sand Warriors are red, green AND
	# white tokens — and thanks to the delayed trigger they can be on the
	# battlefield with no nontoken white permanent in sight.
	var beasts := put_battlefield(0, "Beasts of Bogardan")
	put_battlefield(1, "Forest")
	put_battlefield(1, "Forest")
	var hazezon := put_battlefield(1, "Hazezon Tamar")
	resolve_stack()
	g.recalculate()
	assert_eq(beasts.cur_power, 4, "Hazezon himself is a nontoken white permanent")
	advance_to_step(Mtg.Step.MAIN1)       # still our own turn
	advance_to_step(Mtg.Step.UPKEEP)      # the opponent's upkeep, sandstorm pending
	assert_eq(g.stack.size(), 1, "the sandstorm is waiting on the stack")
	g.sacrifice_permanent(hazezon)
	resolve_stack()
	assert_eq(_count_on_battlefield(1, "Sand Warrior"), 2)
	g.recalculate()
	assert_eq(beasts.cur_power, 3, "white TOKENS do not count")
	put_battlefield(1, "Savannah Lions")
	g.recalculate()
	assert_eq(beasts.cur_power, 4, "a nontoken white creature does")


# ------------------------------------------------- Glyph of Reincarnation --

func test_glyph_of_reincarnation_waits_for_the_postcombat_main() -> void:
	# "Cast this spell only AFTER COMBAT" — the end-of-combat step is still
	# part of the combat phase (CR 511), so the Glyph is not castable yet.
	var wall := put_battlefield(1, "Wall of Stone")
	var glyph := give_hand(1, "Glyph of Reincarnation")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(1, glyph, [TargetRef.card(wall)]), "after combat")
	advance_to_step(Mtg.Step.MAIN2)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(1, glyph, [TargetRef.card(wall)]))


# ------------------------------------------------------ Necropolis of Azar --

func test_necropolis_spends_a_husk_counter_as_a_cost() -> void:
	# "{5}, REMOVE A HUSK COUNTER: ..." — an activation cost (CR 601.2h), so
	# a second activation off one counter is illegal instead of resolving
	# into nothing.
	var necropolis := put_battlefield(0, "Necropolis of Azar")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	g.destroy(bear, false)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(int(necropolis.counters.get("husk", 0)), 1)
	add_mana(0, Mtg.ManaColor.C, 10)
	assert_ok(g.activate_ability(0, necropolis, 0, []))
	assert_eq(int(necropolis.counters.get("husk", 0)), 0,
		"the counter is gone the moment the ability is activated")
	assert_refused(g.activate_ability(0, necropolis, 0, []), "husk")
	resolve_stack()
	assert_eq(_count_on_battlefield(0, "Spawn of Azar"), 1, "one husk, one Spawn")


# ------------------------------------------------------------- Aswan Jaguar --

func test_aswan_jaguar_rolls_over_more_than_the_deck() -> void:
	# SIMPLIFIED (ledger row reported with this audit): the printed trigger
	# reads "a random creature type from those in target opponent's DECK",
	# but RandomEffects.creature_type_of scans library + hand + battlefield +
	# graveyard, and this card may not narrow it without an engine change.
	var bear := put_battlefield(1, "Grizzly Bears")   # only on the BATTLEFIELD
	var jaguar := put_battlefield(0, "Aswan Jaguar")
	resolve_stack()
	assert_eq(String(jaguar.memory.get("type", "")), "bear",
		"SIMPLIFIED: a type that is nowhere in the opponent's deck can be rolled")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# -------------------------------------------------------- Al-abara's Carpet --

func test_al_abaras_carpet_covers_attackers_declared_later() -> void:
	# "Prevent ALL damage that would be dealt to you THIS TURN by attacking
	# creatures without flying" is a duration effect, not one shield per
	# attacker already on the table: activating it in the main phase must
	# still stop the whole ground wave that follows.
	var carpet := put_battlefield(1, "Al-abara's Carpet")
	var giant := put_battlefield(0, "Hill Giant")           # 3/3
	var minotaur := put_battlefield(0, "Hurloon Minotaur")  # 2/3
	var angel := put_battlefield(0, "Serra Angel")          # 4/4 flying
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(1, carpet, 0, []))
	resolve_stack()
	run_combat([giant.id, minotaur.id, angel.id])
	assert_eq(g.players[1].life, 16, "only the flier gets through")
