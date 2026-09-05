extends GameTest
## The 2026-09 fidelity pass: one test per card whose `SIMPLIFIED:` marker
## and ledger row were LIFTED, each pinning the printed behaviour that was
## missing (CONTRIBUTING.md rule 6 — marker, row and test, every time).
##
## The pass's engine-level lifts are pinned separately, next to the
## mechanism they paid for: `tests/unit/test_effect_durations.gd` for the
## CR 611.2b durations, and this file for everything card-shaped.


# ------------------------------------------------------ Disrupting Scepter --

func test_disrupting_scepter_only_works_on_your_turn() -> void:
	# "Activate only during your turn" — an ordinary `your_turn_only()`
	# rider, refused before any cost is paid.
	var scepter := put_battlefield(0, "Disrupting Scepter")
	give_hand(1, "Forest")
	advance_to_next_turn()          # the opponent's turn
	assert_eq(g.active_player, 1)
	assert_ok(g.pass_priority(1))   # now it is ours to act in
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, scepter, 0, [TargetRef.player(1)]),
		"during your turn")
	assert_false(scepter.tapped, "a refused activation pays nothing")


func test_disrupting_scepter_still_works_on_yours() -> void:
	var scepter := put_battlefield(0, "Disrupting Scepter")
	var toss := give_hand(1, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(g.active_player, 0)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, scepter, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(toss.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------------- Voodoo Doll --

func test_voodoo_dolls_x_must_be_the_pin_count() -> void:
	# "X is the number of pin counters on this artifact" is a constraint on
	# the announcement (CR 601.2b), not a suggestion: naming X = 0 used to
	# fire the Doll for free.
	var doll := put_battlefield(0, "Voodoo Doll")
	doll.counters["pin"] = 3
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 8)
	assert_refused(g.activate_ability(0, doll, 0, [TargetRef.player(1)], 0),
		"X must be 3")
	assert_eq(g.players[1].life, 20, "and nothing was dealt")
	assert_false(doll.tapped)


func test_voodoo_doll_fires_at_the_right_x() -> void:
	var doll := put_battlefield(0, "Voodoo Doll")
	doll.counters["pin"] = 3
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 6)   # {X}{X} with X=3 is six mana
	assert_ok(g.activate_ability(0, doll, 0, [TargetRef.player(1)], 3))
	resolve_stack()
	assert_eq(g.players[1].life, 17)


# ------------------------------------------------------ Old Man of the Sea --

func test_old_man_loses_a_creature_that_outgrows_him() -> void:
	# "...for as long as this creature remains tapped AND that creature's
	# power remains less than or equal to this creature's power." Both
	# halves are continuing conditions, so the leash is a state-based
	# check, not a one-off test at activation.
	var old_man := put_battlefield(0, "Old Man of the Sea")   # 2/3
	var bear := put_battlefield(1, "Grizzly Bears")           # 2/2
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, old_man, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.controller_id, 0, "stolen")
	var growth := give_hand(1, "Giant Growth")
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.pass_priority(0))   # the owner responds
	assert_ok(g.cast_spell(1, growth, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 5)
	assert_eq(bear.controller_id, 1,
		"it outgrew him, so it goes straight back")


func test_old_man_keeps_a_creature_that_stays_small() -> void:
	var old_man := put_battlefield(0, "Old Man of the Sea")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, old_man, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.controller_id, 0)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(bear.controller_id, 0, "he stayed tapped and it stayed small")


# ----------------------------------------------------------- Power Artifact --

func test_power_artifact_cannot_make_an_ability_free() -> void:
	# "This effect can't reduce the mana in that cost to less than one
	# mana." Without the floor a {2} ability became {0} — an infinite the
	# printed card forbids.
	var doll := put_battlefield(0, "Voodoo Doll")   # {X}{X}, {T}, no floor case
	var jar := put_battlefield(0, "Jalum Tome")     # {2}, {T}: draw then discard
	var aura := give_hand(0, "Power Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(jar.cur_activated_abilities[0].cost.generic, 2)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(jar)]))
	resolve_stack()
	assert_eq(jar.cur_activated_abilities[0].cost.generic, 1,
		"{2} falls to {1}, never to {0}")
	assert_eq(doll.cur_activated_abilities[0].cost.generic, 0,
		"and nothing else on the board is touched")


func test_power_artifact_still_powers_the_basalt_monolith_loop() -> void:
	# The floor closes the free-ability line and nothing else: {3} still
	# falls to {1} while the Monolith taps for three.
	var monolith := put_battlefield(0, "Basalt Monolith")
	var aura := give_hand(0, "Power Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(monolith)]))
	resolve_stack()
	assert_eq(monolith.cur_activated_abilities[0].cost.generic, 1)
	assert_ok(g.tap_for_mana(0, monolith))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 3)
	assert_ok(g.activate_ability(0, monolith, 0, []))
	resolve_stack()
	assert_false(monolith.tapped, "untapped again for one of its own three")
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 2,
		"the loop still nets two mana a cycle")


# ----------------------------------------------------------- Blazing Effigy --

func test_blazing_effigy_counts_damage_it_dealt_in_combat_too() -> void:
	# "X is 3 plus the amount of damage dealt to this creature this turn by
	# other sources named Blazing Effigy" — ANY damage, not only the
	# dies-trigger's. A pumped Effigy that bit in combat counts, which the
	# old card-memory ledger could not see.
	var mine := put_battlefield(0, "Blazing Effigy")     # 0/3
	var theirs := put_battlefield(1, "Blazing Effigy")   # 0/3
	var colossus := put_battlefield(0, "Colossus of Sardia")   # 9/9
	advance_to_step(Mtg.Step.MAIN1)
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(mine)]))
	resolve_stack()
	assert_eq(mine.cur_power, 3)
	run_combat([mine.id], {theirs.id: mine.id})
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD, "3 combat damage killed the 0/3")
	assert_eq(colossus.damage, 6,
		"3 plus the 3 the OTHER Effigy bit it for in combat")


func test_blazing_effigy_ignores_a_bite_from_anything_else() -> void:
	# "by other sources NAMED Blazing Effigy" — a Grizzly Bears bite is
	# damage on the same creature and must not count.
	var effigy := put_battlefield(1, "Blazing Effigy")        # 0/3
	var bear := put_battlefield(0, "Grizzly Bears")           # 2/2
	var colossus := put_battlefield(0, "Colossus of Sardia")  # 9/9, the target
	run_combat([bear.id], {effigy.id: bear.id})
	resolve_stack()
	assert_eq(effigy.damage, 2, "bitten, but not by an Effigy")
	g.destroy(effigy, false)
	resolve_stack()
	assert_eq(colossus.damage, 3, "exactly three — the bear's 2 does not count")


# ------------------------------------------------------------ Urza's Miter --

func test_urzas_miter_pays_out_on_a_destruction() -> void:
	# "Whenever an artifact you control is put into a graveyard from the
	# battlefield, IF IT WASN'T SACRIFICED, you may pay {3}."
	put_battlefield(0, "Urza's Miter")
	var ring := put_battlefield(0, "Sol Ring")
	for _i in 3:
		put_battlefield(0, "Forest")
	var before := g.players[0].hand.size()
	g.destroy(ring)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), before + 1, "destroyed, so it draws")


func test_urzas_miter_pays_nothing_on_a_sacrifice() -> void:
	put_battlefield(0, "Urza's Miter")
	var ring := put_battlefield(0, "Sol Ring")
	for _i in 3:
		put_battlefield(0, "Forest")
	var before := g.players[0].hand.size()
	g.sacrifice_permanent(ring)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), before,
		"every sacrifice outlet in the pool used to be a cantrip")


# ----------------------------------------------------------------- Kismet --

func test_kismet_taps_an_opponents_land_as_it_enters() -> void:
	put_battlefield(0, "Kismet")
	advance_to_next_turn()          # the opponent's turn
	var land := give_hand(1, "Forest")
	assert_ok(g.play_land(1, land))
	assert_true(land.tapped, "it arrives tapped")
	assert_false(put_battlefield(0, "Forest").tapped, "ours are untouched")


func test_kismet_never_trips_a_became_tapped_trigger() -> void:
	# "Enter TAPPED" is a REPLACEMENT (CR 614.1c): the permanent is never
	# untapped, so a Psychic Venom on it does not sting. The old
	# implementation tapped it a moment after it arrived and fired.
	put_battlefield(0, "Kismet")
	var wind := put_battlefield(0, "Haunting Wind")
	assert_not_null(wind)
	advance_to_next_turn()
	var life_before := g.players[1].life
	var ring := give_hand(1, "Sol Ring")
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, ring, []))
	resolve_stack()
	assert_true(ring.tapped, "Kismet still taps it")
	assert_eq(g.players[1].life, life_before,
		"but nothing ever saw it BECOME tapped")


# ---------------------------------------------------------------- Imprison --

func test_imprison_counters_the_hosts_tap_ability() -> void:
	# "Whenever a player activates an ability of enchanted creature with
	# {T} in its activation cost that isn't a mana ability, you may pay
	# {1}. If you do, counter that ability."
	var tim := put_battlefield(1, "Prodigal Sorcerer")   # {T}: 1 damage
	var aura := give_hand(0, "Imprison")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(tim)]))
	resolve_stack()
	advance_to_next_turn()            # their turn; they may use the Sorcerer
	add_mana(0, Mtg.ManaColor.C)      # the toll, held by the Aura's controller
	assert_ok(g.activate_ability(1, tim, 0, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "the ping was countered")
	assert_eq(aura.zone, Mtg.Zone.BATTLEFIELD, "and the Aura was paid for")


func test_imprison_dies_when_the_toll_goes_unpaid() -> void:
	var tim := put_battlefield(1, "Prodigal Sorcerer")
	var aura := give_hand(0, "Imprison")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(tim)]))
	resolve_stack()
	advance_to_next_turn()            # no mana this time
	assert_ok(g.activate_ability(1, tim, 0, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD, "the price of letting it go")
	assert_eq(g.players[0].life, 19, "and the ping landed")


func test_imprison_ignores_a_mana_ability() -> void:
	# "...that isn't a mana ability." A mana ability never uses the stack,
	# so there is nothing to counter and the Aura is not put to the choice.
	var elf := put_battlefield(1, "Llanowar Elves")
	var aura := give_hand(0, "Imprison")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(elf)]))
	resolve_stack()
	advance_to_next_turn()
	assert_ok(g.tap_for_mana(1, elf))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.G), 1)
	assert_eq(aura.zone, Mtg.Zone.BATTLEFIELD, "no toll, no destruction")


# --------------------------------- Fortified Area / Wall of Caltrops --

func test_fortified_area_makes_its_walls_band() -> void:
	# "Wall creatures you control get +1/+0 and have banding." The banding
	# is the point: with it, the WALLS' controller divides the attacker's
	# damage (CR 702.22f-h), so a gang block loses one Wall instead of two.
	put_battlefield(1, "Fortified Area")
	var stone := put_battlefield(1, "Wall of Stone")   # 0/8 -> 1/8
	var wood := put_battlefield(1, "Wall of Wood")     # 0/3 -> 1/3
	var wurm := put_battlefield(0, "Craw Wurm")        # 6/4
	assert_true(wood.has_keyword(Mtg.Keyword.BANDING))
	assert_eq(wood.cur_power, 1, "and the anthem is real too")
	run_combat([wurm.id], {stone.id: wurm.id, wood.id: wurm.id})
	assert_eq(stone.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(wood.zone, Mtg.Zone.GRAVEYARD,
		"all six went onto the cheap Wall; the big one held")
	assert_eq(wurm.damage, 2, "and it took both Walls' point back")


func test_wall_of_caltrops_bands_a_wall_only_gang() -> void:
	# "...this creature gains banding until end of turn" — and the banding
	# then hands the division to the Walls' controller.
	var caltrops := put_battlefield(1, "Wall of Caltrops")   # 2/1
	var stone := put_battlefield(1, "Wall of Stone")         # 0/8
	var wurm := put_battlefield(0, "Craw Wurm")              # 6/4
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {caltrops.id: wurm.id, stone.id: wurm.id}))
	resolve_stack()
	assert_true(caltrops.has_keyword(Mtg.Keyword.BANDING),
		"a Wall-only gang bands up")
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(caltrops.zone, Mtg.Zone.GRAVEYARD, "the cheap body ate it")
	assert_eq(stone.zone, Mtg.Zone.BATTLEFIELD, "the 0/8 is untouched")


# ============================================================================
# THE "IT NEEDS A PROMPT" ROWS
#
# A whole family of ledger rows blamed a missing "await-based human prompt"
# for a decision the card hands to `game.agents[pid]`. That premise is
# false and has been since the §1.3 pre-flight shipped: a question asked
# through the DecisionAgent funnel from inside a stack resolution IS the
# human seat's prompt — `MtgGame._preflight` holds the resolution open on
# it and `answer_choice` feeds the answer back (pinned end to end in
# tests/unit/test_choice_preflight.gd, on this very card shape). For every
# other seat, an agent answering its own question is not a shortcut; it is
# what an agent is.
#
# What the rows were really worth was a pin that the decision is DELEGATED
# rather than hard-coded. These are those pins: each installs a seat that
# answers against the heuristic and checks the card obeys.
# ============================================================================

## Refuses every optional offer, whatever the hint says.
class RefusingSeat extends DecisionAgent:
	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String,
			_hint: bool) -> bool:
		return false


## Accepts every optional offer, and picks a card by name when it can.
class EagerSeat extends DecisionAgent:
	var wanted := ""

	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String,
			_hint: bool) -> bool:
		return true

	func answer_card(game: MtgGame, pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		for inst in candidates:
			if inst.data.card_name == wanted:
				return inst
		return super(game, pid, candidates, prompt)


# ------------------------------------------------------------ upkeep rents --

func test_an_upkeep_rent_is_the_controllers_own_call() -> void:
	# "At the beginning of your upkeep, sacrifice this enchantment unless
	# you pay {U}." A seat that would rather let Stasis go does.
	var stasis := put_battlefield(0, "Stasis")
	put_battlefield(0, "Island")
	g.agents[0] = RefusingSeat.new()
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(stasis.zone, Mtg.Zone.GRAVEYARD, "they declined to pay")


func test_an_upkeep_rent_is_paid_when_the_seat_says_yes() -> void:
	var stasis := put_battlefield(0, "Stasis")
	put_battlefield(0, "Island")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(stasis.zone, Mtg.Zone.BATTLEFIELD, "the default pays it")


func test_cyclones_rent_can_be_declined() -> void:
	# "At the beginning of your upkeep, put a wind counter on this, then
	# sacrifice it unless you pay {G} for each wind counter."
	var cyclone := put_battlefield(0, "Cyclone")
	for _i in 4:
		put_battlefield(0, "Forest")
	g.agents[0] = RefusingSeat.new()
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(cyclone.zone, Mtg.Zone.GRAVEYARD, "they let the storm go")


func test_rohgahhs_rent_can_be_declined() -> void:
	# "...If you don't, tap Rohgahh and all Kobolds of Kher Keep, then an
	# opponent gains control of them."
	var rohgahh := put_battlefield(0, "Rohgahh of Kher Keep")
	for _i in 3:
		put_battlefield(0, "Mountain")
	g.agents[0] = RefusingSeat.new()
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(rohgahh.controller_id, 1, "the Kobolds deserted")


func test_demonic_hordes_land_is_the_opponents_choice() -> void:
	# "...sacrifice a land OF AN OPPONENT'S CHOICE." Theirs, not ours and
	# not battlefield order.
	var hordes := put_battlefield(0, "Demonic Hordes")
	var forest := put_battlefield(0, "Forest")
	var strip := put_battlefield(0, "Strip Mine")
	var picky := EagerSeat.new()
	picky.wanted = "Forest"
	g.agents[1] = picky
	g.agents[0] = RefusingSeat.new()      # we decline the {B}{B}{B}
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD, "they named the Forest")
	assert_eq(strip.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(hordes.tapped)


# ---------------------------------------------------------- ante ransoms --

func test_the_bronze_tablet_ransom_is_the_victims_call() -> void:
	# "That player may pay 10 life." A seat that would rather keep the life
	# and lose the creature can.
	var tablet := put_battlefield(0, "Bronze Tablet")
	tablet.tapped = false
	var hostage := put_battlefield(1, "Grizzly Bears")
	g.agents[1] = RefusingSeat.new()
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, tablet, 0, [TargetRef.card(hostage)]))
	resolve_stack()
	assert_eq(g.players[1].life, 20, "they kept the life")
	assert_eq(hostage.owner_id, 0, "and lost the creature for good")


# ----------------------------------------------------------------- Eureka --

func test_eureka_can_be_declined() -> void:
	# "Each player MAY put a permanent card from their hand onto the
	# battlefield." A seat holding something back keeps it.
	var kept := give_hand(1, "Shivan Dragon")
	var spell := give_hand(0, "Eureka")
	g.agents[1] = RefusingSeat.new()
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, spell, []))
	resolve_stack()
	assert_eq(kept.zone, Mtg.Zone.HAND, "they held it back")


# --------------------------------------------------------------- Cleansing --

func test_cleansing_lets_a_player_spend_their_last_life() -> void:
	# "...unless any player pays 1 life." CR 118.4 allows paying down to 0,
	# and the engine must not decide otherwise for a seat that says yes.
	var land := put_battlefield(0, "Forest")
	var spell := give_hand(0, "Cleansing")
	g.adjust_life(0, -19)                 # exactly 1 life
	g.agents[0] = EagerSeat.new()
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, spell, []))
	resolve_stack()
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD, "they bought it")
	assert_eq(g.players[0].life, 0, "with the last point they had")
	assert_true(g.game_over, "and lost to the state-based actions")


# ----------------------------------------------------- Verduran Enchantress --

func test_verduran_enchantress_may_decline_the_draw() -> void:
	# "Whenever you cast an enchantment spell, you MAY draw a card."
	put_battlefield(0, "Verduran Enchantress")
	var aura := give_hand(0, "Holy Strength")
	g.agents[0] = RefusingSeat.new()
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	var before := g.players[0].hand.size()
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(put_battlefield(0, "Grizzly Bears"))]))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), before - 1,
		"the Aura left the hand and nothing replaced it")


# --------------------------------------------------------- Imprison's toll --

func test_the_imprison_toll_can_be_declined_with_mana_to_spare() -> void:
	var tim := put_battlefield(1, "Prodigal Sorcerer")
	var aura := give_hand(0, "Imprison")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(tim)]))
	resolve_stack()
	g.agents[0] = RefusingSeat.new()
	advance_to_next_turn()
	add_mana(0, Mtg.ManaColor.C)      # affordable, and still declined
	assert_ok(g.activate_ability(1, tim, 0, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD, "the choice is really theirs")
	assert_eq(g.players[0].life, 19)


# ------------------------------- choices that used to be computed silently --
#
# These four cards worked out their own answer and never asked. Routing each
# through the DecisionAgent funnel is the whole fix; the value they used to
# compute is now only the hint.

## Answers every OPTION question with a fixed index.
class OptionSeat extends DecisionAgent:
	var index := 0

	func answer_option(_game: MtgGame, _pid: int, _prompt: String,
			_options: Array[String], _hint: int) -> int:
		return index


func test_jihads_colour_is_the_casters_choice() -> void:
	# "As this enchantment enters, choose a color and an opponent." The
	# opponent here holds only a red permanent, so naming BLUE makes the
	# third line fire at once and the Jihad eats itself.
	put_battlefield(1, "Mountain")
	put_battlefield(1, "Goblin King")     # red
	var jihad := give_hand(0, "Jihad")
	var blue := OptionSeat.new()
	blue.index = 1                        # white, BLUE, black, red, green
	g.agents[0] = blue
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, jihad, []))
	resolve_stack()
	g.check_state_based_actions()
	assert_eq(jihad.zone, Mtg.Zone.GRAVEYARD,
		"they named a colour the opponent does not have")


func test_primal_clays_shape_is_its_controllers_choice() -> void:
	# "As this creature enters, it becomes YOUR CHOICE of a 3/3, a 2/2 with
	# flying, or a 1/6 Wall with defender." With an empty board the hint is
	# the 3/3; a seat that wants the Wall gets the Wall.
	var wall := OptionSeat.new()
	wall.index = 2
	g.agents[0] = wall
	var clay := give_hand(0, "Primal Clay")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, clay, []))
	resolve_stack()
	assert_eq(clay.cur_power, 1)
	assert_eq(clay.cur_toughness, 6)
	assert_true(clay.has_keyword(Mtg.Keyword.DEFENDER))


func test_mind_bombs_count_is_each_players_own() -> void:
	# "Each player MAY discard UP TO THREE cards." How many is the player's
	# call; the hint only fires below 5 life.
	for _i in 3:
		give_hand(1, "Forest")
	var two := OptionSeat.new()
	two.index = 2                 # the labels are 0,1,2,3 — so "2"
	g.agents[1] = two
	var bomb := give_hand(0, "Mind Bomb")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, bomb, []))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 1, "they chose to pitch two")
	assert_eq(g.players[1].life, 19, "and took the remaining point")


func test_phantasmal_terrains_type_is_the_casters_choice() -> void:
	# "As this Aura enters, choose a basic land type." A seat that names
	# Mountain gets a Mountain, whatever the colour-screw hint says.
	var land := put_battlefield(1, "Forest")
	var aura := give_hand(0, "Phantasmal Terrain")
	var mountain := OptionSeat.new()
	mountain.index = 3            # Plains, Island, Swamp, MOUNTAIN, Forest
	g.agents[0] = mountain
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(land)]))
	resolve_stack()
	assert_true(land.has_subtype("mountain"))
	assert_false(land.has_subtype("forest"), "CR 305.7 replaces the type")


# ------------------------------------- the rest of the "copy choices" row --

func test_clone_copies_the_creature_its_controller_names() -> void:
	# "You may have Clone enter as a copy of any creature on the
	# battlefield" — a choice made on resolution, not a target, and one the
	# controller's own seat answers.
	put_battlefield(1, "Shivan Dragon")
	put_battlefield(1, "Grizzly Bears")
	var picky := EagerSeat.new()
	picky.wanted = "Grizzly Bears"     # NOT the biggest body
	g.agents[0] = picky
	var clone := give_hand(0, "Clone")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, clone, []))
	resolve_stack()
	assert_eq(clone.data.card_name, "Grizzly Bears", "their pick, not ours")


func test_triassic_egg_puts_down_the_creature_its_controller_names() -> void:
	var egg := put_battlefield(0, "Triassic Egg")
	give_hand(0, "Shivan Dragon")
	var bears := give_hand(0, "Grizzly Bears")
	var picky := EagerSeat.new()
	picky.wanted = "Grizzly Bears"     # again, not the biggest
	g.agents[0] = picky
	egg.counters["hatchling"] = 2      # already incubated
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, egg, 1, []))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "their pick came down")


func test_enchantment_alteration_moves_the_aura_where_it_is_told() -> void:
	# "Attach target Aura to another permanent it can enchant" — which
	# permanent is the caster's own answer.
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	put_battlefield(0, "Shivan Dragon")
	var strength := give_hand(0, "Holy Strength")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, strength, [TargetRef.card(bears)]))
	resolve_stack()
	var picky := EagerSeat.new()
	picky.wanted = "Hill Giant"        # not the Dragon the heuristic wants
	g.agents[0] = picky
	var move := give_hand(0, "Enchantment Alteration")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, move, [TargetRef.card(strength)]))
	resolve_stack()
	assert_eq(strength.attached_to, giant.id, "their pick, not the heuristic's")


func test_copy_artifact_copies_the_artifact_its_controller_names() -> void:
	put_battlefield(1, "Icy Manipulator")     # mana value 4 — the default
	put_battlefield(1, "Sol Ring")
	var picky := EagerSeat.new()
	picky.wanted = "Sol Ring"
	g.agents[0] = picky
	var copy := give_hand(0, "Copy Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, copy, []))
	resolve_stack()
	assert_eq(copy.data.card_name, "Sol Ring", "their pick")


func test_vesuvan_doppelganger_may_decline_the_upkeep_shift() -> void:
	# "At the beginning of your upkeep, YOU MAY have this creature become a
	# copy of target creature..." — declinable, through the controller's seat.
	var doppel := put_battlefield(0, "Vesuvan Doppelganger")
	put_battlefield(1, "Shivan Dragon")
	g.agents[0] = RefusingSeat.new()
	advance_to_next_turn()
	advance_to_next_turn()
	assert_ne(doppel.data.card_name, "Shivan Dragon", "they said no")


func test_metamorphosis_makes_the_colour_its_caster_names() -> void:
	put_battlefield(0, "Grizzly Bears")
	var spell := give_hand(0, "Metamorphosis")
	var red := ColourSeat.new()
	red.colour = Mtg.ManaColor.R
	g.agents[0] = red
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, spell, []))
	resolve_stack()
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.R), 3,
		"1 plus the Bears' mana value, in the colour they named")


func test_recall_returns_the_card_its_caster_names() -> void:
	var spell := give_hand(0, "Recall")
	give_hand(0, "Forest")
	var dragon := _make_in_graveyard(0, "Shivan Dragon")
	var bears := _make_in_graveyard(0, "Grizzly Bears")
	var picky := EagerSeat.new()
	picky.wanted = "Grizzly Bears"      # not the priciest
	g.agents[0] = picky
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_ok(g.cast_spell(0, spell, [], 1))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.HAND, "their pick came back")
	assert_eq(dragon.zone, Mtg.Zone.GRAVEYARD)


func test_lich_eats_the_permanent_its_controller_names() -> void:
	# "If you would gain life... / when damage would be dealt to you,
	# sacrifice that many permanents" — WHICH ones is the controller's.
	put_battlefield(0, "Lich")
	var ring := put_battlefield(0, "Sol Ring")
	put_battlefield(0, "Forest")
	var picky := EagerSeat.new()
	picky.wanted = "Sol Ring"           # not the cheapest
	g.agents[0] = picky
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD, "their pick was fed to it")


func test_glyph_of_reincarnation_raises_the_body_its_caster_names() -> void:
	# CR 609.3: the SPELL's controller carries out the instruction, so the
	# replacement body out of the opponent's graveyard is THEIR choice —
	# corrected 2026-09-01 (docs/audit-vs-s30.md), which is why the default
	# now offers the opponent's graveyard smallest-first.
	var wall := put_battlefield(0, "Wall of Stone")
	var victim := put_battlefield(1, "Hill Giant")
	_make_in_graveyard(1, "Grizzly Bears")
	var dragon := _make_in_graveyard(1, "Shivan Dragon")
	var picky := EagerSeat.new()
	picky.wanted = "Shivan Dragon"      # the WORST answer for them
	g.agents[0] = picky                 # the Glyph's controller chooses
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, []))
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [victim.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {wall.id: victim.id}))
	resolve_stack()
	var glyph := give_hand(0, "Glyph of Reincarnation")
	advance_to_step(Mtg.Step.MAIN2)   # "Cast this spell only after combat"
	add_mana(0, Mtg.ManaColor.G)
	if g.priority_player != 0:
		assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.cast_spell(0, glyph, [TargetRef.card(wall)]))
	resolve_stack()
	assert_eq(victim.zone, Mtg.Zone.GRAVEYARD, "the blocked creature dies")
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD,
		"the Glyph's controller named it — not the cheapest body the "
		+ "heuristic would have handed over, and not the victim's own pick")


## Setup helper: a card resting in [param pid]'s graveyard.
func _make_in_graveyard(pid: int, card_name: String) -> CardInstance:
	var inst := give_hand(pid, card_name)
	g.players[pid].hand.erase(inst)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst


## Answers every COLOUR question with a fixed colour.
class ColourSeat extends DecisionAgent:
	var colour := Mtg.ManaColor.R

	func answer_color(_game: MtgGame, _pid: int, _prompt: String,
			_hint: int) -> int:
		return colour


# ------------------------------------------- findings folded in from the --
# ------------------------------------------- s30/mage-go audit (§3b) ------

func test_land_tax_fetches_the_count_its_controller_names() -> void:
	# "Search your library for UP TO THREE basic land cards." The original
	# asked, three prompts deep — `@LANDTAX`, Program/prompts.txt.
	var tax := put_battlefield(0, "Land Tax")
	assert_not_null(tax)
	put_battlefield(1, "Forest")
	put_battlefield(1, "Forest")
	var one := OptionSeat.new()
	one.index = 1                       # labels 0,1,2,3 -> "1"
	g.agents[0] = one
	var before := g.players[0].library.size()
	advance_to_next_turn()
	advance_to_next_turn()
	# Two cards left the library: the ONE land they asked for, plus the
	# turn's ordinary draw. The default answer would have taken four.
	assert_eq(g.players[0].library.size(), before - 2,
		"they asked for one land, not three")


func test_demonic_hordes_tithe_survives_the_hordes_dying() -> void:
	# CR 603.6: a triggered ability resolves even if its source has left.
	# Sacrificing the Hordes in response must not refund the land.
	var hordes := put_battlefield(0, "Demonic Hordes")
	var forest := put_battlefield(0, "Forest")
	g.agents[0] = RefusingSeat.new()
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)
	assert_ok(g.pass_priority(0))       # let the trigger stack
	g.sacrifice_permanent(hordes)
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD,
		"the tithe was owed before the Hordes left")


func test_power_artifact_discounts_a_mana_ability_too() -> void:
	# "Enchanted artifact's ACTIVATED abilities cost {2} less" — and a mana
	# ability IS an activated ability (CR 605.1a).
	var prism := put_battlefield(0, "Celestial Prism")   # {2}, {T}: add a colour
	var aura := give_hand(0, "Power Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(prism.cur_mana_abilities[0].cost.generic, 2)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(prism)]))
	resolve_stack()
	assert_eq(prism.cur_mana_abilities[0].cost.generic, 1,
		"{2} falls to {1}, and the same floor applies")


func test_a_copy_permanent_may_decline_to_copy_anything() -> void:
	# "YOU MAY have this enchantment enter as a copy of any artifact" — a
	# forced copy of an opponent's Ankh of Mishra is worse than nothing.
	put_battlefield(1, "Ankh of Mishra")
	g.agents[0] = DecliningCopySeat.new()
	var copy := give_hand(0, "Copy Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, copy, []))
	resolve_stack()
	assert_eq(copy.data.card_name, "Copy Artifact", "it entered as printed")


## Declines every optional card choice (a null answer).
class DecliningCopySeat extends DecisionAgent:
	func answer_card(_game: MtgGame, _pid: int,
			_candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		return null


func test_mana_vault_does_not_trigger_while_it_is_untapped() -> void:
	# "At the beginning of your draw step, IF THIS ARTIFACT IS TAPPED" — an
	# intervening "if" (CR 603.4). An untapped Vault must not put a trigger
	# on the stack at all, so tapping it in response cannot make it burn.
	var vault := put_battlefield(0, "Mana Vault")
	vault.tapped = false
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.players[0].life, 20, "it was never tapped, so it never fired")


func test_primal_clays_shape_is_settled_as_it_enters() -> void:
	# "AS this creature enters" is a REPLACEMENT (CR 614.1c): nothing ever
	# sees the Clay on the battlefield in the wrong shape, so the stack is
	# empty the moment it resolves.
	var wall := OptionSeat.new()
	wall.index = 2
	g.agents[0] = wall
	var clay := give_hand(0, "Primal Clay")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, clay, []))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_true(g.stack.is_empty(), "no arrival trigger is waiting")
	assert_eq(clay.cur_toughness, 6, "and it is already the Wall")
