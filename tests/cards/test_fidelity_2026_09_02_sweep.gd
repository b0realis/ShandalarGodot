extends GameTest
## 2026-09-02 bug sweep — the read-only reviewer's card findings, pinned:
## Lesser Werewolf re-reads "if this creature's power is 1 or more" as each
## activation RESOLVES (CR 608.2c, Manalink card_lesser_werewolf); the
## three "for as long as this remains tapped" cards (Ashnod's Battle Gear,
## Tawnos's Weaponry, Phyrexian Gremlins) end for good when the source
## untaps and do not resume on a later tap (CR 611.2b, Manalink
## dnuimt_legacy); Tawnos's Coffin keeps one record per activation so an
## activation in response to its own release trigger loses nothing
## (CR 603.7 — each activation makes its own delayed trigger); a Fork copy
## carries the original's cast-time memory and costs paid (CR 707.10);
## Halfdane can borrow a NEGATIVE power; Spitting Slug blocking two
## attackers hears "blocks" once (CR 509.1h); and two oracle texts keep
## their printed reminder text.


# ---------------------------------------------------------- Lesser Werewolf --

func test_lesser_werewolf_rechecks_its_power_as_each_activation_resolves() -> void:
	# "If this creature's power is 1 or more" is part of the EFFECT, so it
	# is checked on resolution (CR 608.2c) — the activation-time refusal is
	# a courtesy. Four activations held in priority, all made at power 2:
	# the first two to resolve spend a point each, the last two find 0 and
	# do nothing. Manalink tests get_power() > 0 at EVENT_RESOLVE_ACTIVATION.
	# (A 4/5 victim: four counters would kill it, two leave it at 3.)
	var wolf := put_battlefield(1, "Lesser Werewolf")     # 2/4
	var elemental := put_battlefield(0, "Earth Elemental")   # 4/5
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [elemental.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wolf.id: elemental.id}))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.B, 4)
	for _i in 4:
		assert_ok(g.activate_ability(1, wolf, 0, [TargetRef.card(elemental)]))
	assert_eq(g.stack.size(), 4, "all four were legal to activate at power 2")
	resolve_stack()
	assert_eq(wolf.cur_power, 0, "two activations spent its two points")
	assert_eq(int(elemental.counters.get("-0/-1", 0)), 2,
		"the other two found power 0 as they resolved and did nothing")
	assert_eq(elemental.cur_toughness, 3)
	assert_eq(elemental.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------- "for as long as this remains tapped" --

func test_ashnods_battle_gear_bonus_does_not_come_back_on_a_later_tap() -> void:
	# CR 611.2b: the duration "for as long as this artifact remains tapped"
	# ends the moment the Gear untaps, and an ended effect never restarts —
	# an Icy Manipulator tapping the Gear later must not re-kill its old
	# target. Manalink's dnuimt_legacy kills the effect on the untap.
	var gear := put_battlefield(0, "Ashnod's Battle Gear")
	var angel := put_battlefield(0, "Serra Angel")   # 4/4
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, gear, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_eq(angel.cur_power, 6)
	g.untap_permanent(gear)
	resolve_stack()
	assert_eq(angel.cur_power, 4, "the bonus ended with the untap")
	g.tap_permanent(gear)
	g.recalculate()
	assert_eq(angel.cur_power, 4, "and does not resume when the Gear is tapped again")
	assert_eq(angel.cur_toughness, 4)


func test_tawnoss_weaponry_bonus_does_not_come_back_on_a_later_tap() -> void:
	var weaponry := put_battlefield(0, "Tawnos's Weaponry")
	var bear := put_battlefield(0, "Grizzly Bears")   # 2/2
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, weaponry, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 3)
	g.untap_permanent(weaponry)
	resolve_stack()
	assert_eq(bear.cur_power, 2)
	g.tap_permanent(weaponry)
	g.recalculate()
	assert_eq(bear.cur_power, 2, "an ended effect does not restart (CR 611.2b)")
	assert_eq(bear.cur_toughness, 2)


func test_phyrexian_gremlins_lock_does_not_come_back_when_they_attack() -> void:
	# The Gremlins lock an Icy, their controller lets them untap, and later
	# they attack (which taps them): the Icy must NOT be locked again — no
	# activation happened.
	var gremlins := put_battlefield(0, "Phyrexian Gremlins")
	var icy := put_battlefield(1, "Icy Manipulator")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, gremlins, 0, [TargetRef.card(icy)]))
	resolve_stack()
	assert_true(icy.tapped)
	assert_true(icy.cur_skips_untap)
	g.untap_permanent(gremlins)
	resolve_stack()
	assert_false(icy.cur_skips_untap, "the lock ended with the untap")
	g.tap_permanent(gremlins)
	g.recalculate()
	assert_false(icy.cur_skips_untap, "and does not resume on a later tap")
	advance_to_next_turn()   # the Icy's controller's untap step
	assert_false(icy.tapped, "the Icy untaps normally")


## Answers "Untap <name>." to the untap-step question.
class UntapsEverything extends DecisionAgent:
	func answer_option(_game: MtgGame, _pid: int, _prompt: String,
			_options: Array[String], _hint: int) -> int:
		return 0


func test_phyrexian_gremlins_lock_ends_through_the_untap_step_too() -> void:
	# The common real-game path: the controller answers "Untap" in their
	# own untap step. The engine fires the same BECAME_UNTAPPED there.
	var gremlins := put_battlefield(0, "Phyrexian Gremlins")
	var icy := put_battlefield(1, "Icy Manipulator")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, gremlins, 0, [TargetRef.card(icy)]))
	resolve_stack()
	g.set_agent(0, UntapsEverything.new())
	advance_to_next_turn()   # theirs: the Icy stays locked
	assert_true(icy.tapped)
	advance_to_next_turn()   # ours: the Gremlins untap on request
	resolve_stack()
	assert_false(gremlins.tapped)
	assert_false(icy.cur_skips_untap)
	run_combat([gremlins.id])
	assert_true(gremlins.tapped, "attacking tapped them")
	assert_false(icy.cur_skips_untap, "but the old lock is gone for good")


# ---------------------------------------------------------- Tawnos's Coffin --

func test_tawnos_coffin_keeps_one_record_per_activation() -> void:
	# The Coffin holds A. An untap puts its release trigger on the stack;
	# in response its controller pays {3},{T} on B. The trigger belongs to
	# the FIRST activation (CR 603.7 — each activation creates its own
	# delayed trigger), so A comes back and B stays in the Coffin until it
	# untaps again. Before the fix B's record overwrote A's and A was lost.
	var coffin := put_battlefield(0, "Tawnos's Coffin")
	var first := put_battlefield(1, "Serra Angel")
	var second := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, coffin, 0, [TargetRef.card(first)]))
	resolve_stack()
	assert_eq(first.zone, Mtg.Zone.EXILE)
	g.untap_permanent(coffin)
	assert_eq(g.stack.size(), 1, "the release trigger is waiting")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, coffin, 0, [TargetRef.card(second)]))
	resolve_stack()
	assert_eq(first.zone, Mtg.Zone.BATTLEFIELD, "the first prisoner is released")
	assert_true(first.tapped)
	assert_eq(second.zone, Mtg.Zone.EXILE, "the second stays until the next untap")
	assert_true(coffin.tapped)
	g.untap_permanent(coffin)
	resolve_stack()
	assert_eq(second.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(second.tapped)


func test_tawnos_coffin_leaving_releases_every_prisoner() -> void:
	# Two prisoners at once: A is held; the Coffin untaps (A's release
	# waits on the stack); B is buried in response; while both still wait,
	# the Coffin is destroyed. Its leaves-the-battlefield release frees
	# EVERY record it was holding (A and B), and A's untap release then
	# finds nothing left to do.
	var coffin := put_battlefield(0, "Tawnos's Coffin")
	var first := put_battlefield(1, "Serra Angel")
	var second := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, coffin, 0, [TargetRef.card(first)]))
	resolve_stack()
	g.untap_permanent(coffin)
	assert_eq(g.stack.size(), 1, "A's release is waiting")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, coffin, 0, [TargetRef.card(second)]))
	# Let ONLY the activation resolve (it is on top), keeping A's release
	# on the stack beneath it.
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_eq(second.zone, Mtg.Zone.EXILE, "B joined A in the Coffin")
	assert_eq(first.zone, Mtg.Zone.EXILE)
	assert_eq(g.stack.size(), 1, "A's release is still waiting")
	g.destroy(coffin, false)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(first.zone, Mtg.Zone.BATTLEFIELD, "the Coffin leaving frees everyone")
	assert_eq(second.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(first.tapped)
	assert_true(second.tapped)


func test_tawnos_coffin_untapping_twice_does_not_release_twice() -> void:
	# A delayed trigger fires once (CR 603.7b): an Icy untapping the Coffin
	# while its first release is still on the stack adds no second one.
	var coffin := put_battlefield(0, "Tawnos's Coffin")
	var victim := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, coffin, 0, [TargetRef.card(victim)]))
	resolve_stack()
	g.untap_permanent(coffin)
	assert_eq(g.stack.size(), 1)
	g.tap_permanent(coffin)
	g.untap_permanent(coffin)
	assert_eq(g.stack.size(), 1, "still the one release")
	resolve_stack()
	assert_eq(victim.zone, Mtg.Zone.BATTLEFIELD)


# --------------------------------------------------------------------- Fork --

func test_fork_copies_the_sacrificed_mana_value() -> void:
	# CR 707.10: a copy copies the choices made when casting and the
	# additional costs paid; "if an effect of the copy refers to objects
	# used to pay its costs, it uses the objects used to pay the costs of
	# the original". Sacrifice's mana value lives on the spell's memory.
	var dragon := put_battlefield(0, "Shivan Dragon")   # mana value 6
	var sacrifice := give_hand(0, "Sacrifice")
	var fork := give_hand(0, "Fork")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, sacrifice))
	assert_eq(dragon.zone, Mtg.Zone.GRAVEYARD, "the additional cost was paid")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, fork, [TargetRef.card(sacrifice)]))
	resolve_stack()
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 12,
		"six black from the copy and six from the original")


# ----------------------------------------------------------------- Halfdane --

func test_halfdane_can_borrow_a_negative_power() -> void:
	# "Change Halfdane's base power and toughness to the power and
	# toughness of target creature" — a creature under Weakness can have
	# power below zero, and that is what Halfdane copies.
	var halfdane := put_battlefield(0, "Halfdane")     # 3/3
	var wall := put_battlefield(1, "Wall of Wood")      # 0/3
	var weakness := give_hand(0, "Weakness")            # -2/-1
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, weakness, [TargetRef.card(wall)]))
	resolve_stack()
	assert_eq(wall.cur_power, -2)
	advance_to_next_turn()
	advance_to_next_turn()   # our upkeep fired on the way
	resolve_stack()
	assert_eq(halfdane.cur_power, -2, "a negative power is a power like any other")
	assert_eq(halfdane.cur_toughness, 2)


# ------------------------------------------------------------ Spitting Slug --

func test_spitting_slug_blocking_two_attackers_hears_blocks_once() -> void:
	# "Whenever this creature blocks" is one event per combat however many
	# attackers it blocks (CR 509.1h) — a Blaze of Glory conscript blocking
	# two attackers pays the rent once. The engine dispatches BLOCKED per
	# pair, so the card counts only the first attacker's dispatch.
	var slug := put_battlefield(1, "Spitting Slug")
	var giant_a := put_battlefield(0, "Hill Giant")
	var giant_b := put_battlefield(0, "Hill Giant")
	var blaze := give_hand(0, "Blaze of Glory")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant_a.id, giant_b.id]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, blaze, [TargetRef.card(slug)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	add_mana(1, Mtg.ManaColor.G)
	add_mana(1, Mtg.ManaColor.C)   # exactly one rent
	assert_ok(g.declare_blockers(1, {slug.id: [giant_a.id, giant_b.id]}))
	assert_eq(g.stack.size(), 1, "one trigger for the one declaration")
	resolve_stack()
	assert_true(slug.cur_keywords.has(Mtg.Keyword.FIRST_STRIKE), "the rent was paid")
	assert_false(giant_a.cur_keywords.has(Mtg.Keyword.FIRST_STRIKE),
		"no second trigger to fail to pay and arm the attackers")
	assert_false(giant_b.cur_keywords.has(Mtg.Keyword.FIRST_STRIKE))


# ------------------------------------------------------------ oracle texts --

func test_reminder_text_is_kept_on_scarwood_hag_and_master_of_the_hunt() -> void:
	assert_string_contains(CardRegistry.get_card("Scarwood Hag").oracle_text,
		"(It can't be blocked as long as defending player controls a Forest.)")
	assert_string_contains(CardRegistry.get_card("Master of the Hunt").oracle_text,
		"(Any creatures named Wolves of the Hunt can attack in a band")
