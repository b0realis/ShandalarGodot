extends GameTest
## The phasing liveness audit of 2026-10-03 — older card code that holds a
## permanent ACROSS TIME (an ability on the stack and its source, a
## "for as long as" lock, a roster, a damage redirect, an upkeep "if you
## do") used to ask `zone == BATTLEFIELD`, which a PHASED-OUT permanent
## still answers yes to (CR 702.26d). It is "treated as though it doesn't
## exist" (702.26b): nothing affects it, an effect resolving while it is
## gone never includes it (702.26e), and a "for as long as" duration that
## tracks it ends (702.26f). Phasing is still no zone change, so a link
## that waits for it to LEAVE survives (702.26d). One test per family of
## fix, each phasing the remembered permanent out with `phase_out`:
## - "for as long as" a tracked source (Giant Oyster);
## - an upkeep "you may sacrifice it; if you do" and a link that survives
##   (Safe Haven);
## - a damage redirect onto a creature that is gone at damage time
##   (Shimian Night Stalker);
## - an INDEFINITE effect from a resolving trigger (Brine Hag) and an
##   until-end-of-turn self-pump (Dragon Whelp);
## - a roster of remembered tokens (Tetravus);
## - an upkeep trigger on the phased-out permanent itself — counter
##   removal (Divine Intervention) and cumulative upkeep (Thought Lash).


func before_each() -> void:
	CardPacks.set_enabled("pack-4", true)   # Giant Oyster (Homelands)
	CardPacks.set_enabled("pack-5", true)   # Thought Lash (Alliances)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-4", false)
	CardPacks.set_enabled("pack-5", false)


## Fire an upkeep for [param pid] and check its trigger is really waiting
## on the stack before the test phases anything out — a test whose
## trigger never fired would pass for the wrong reason.
func _upkeep_trigger(pid: int) -> void:
	g.dispatch_event(Mtg.EventType.UPKEEP_START, {"player": pid})
	assert_false(g.stack.is_empty(), "the upkeep trigger is waiting on the stack")


# ------------------------------------------------- F1: "for as long as" --

func test_giant_oyster_lock_ends_when_the_oyster_phases_out() -> void:
	# CR 702.26f: "for as long as Giant Oyster remains tapped" tracks the
	# Oyster; once it phases out the duration can't see it and ends.
	var oyster := put_battlefield(0, "Giant Oyster")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.tap_permanent(bear)
	assert_ok(g.activate_ability(0, oyster, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.cur_skips_untap, "the lock holds while the Oyster stays tapped")
	assert_true(g.phase_out(oyster))
	assert_false(bear.cur_skips_untap, "a phased-out Oyster holds nothing (702.26f)")
	g.dispatch_event(Mtg.EventType.DRAW_STEP, {"player": 0})
	resolve_stack()
	assert_eq(int(bear.counters.get("-1/-1", 0)), 0,
		"no -1/-1 counter from an Oyster that isn't there")


func test_giant_oyster_activated_then_phased_out_never_starts_its_lock() -> void:
	# CR 611.2b with 702.26b: the duration ended before the effect would
	# begin, so the resolving ability does nothing — not even once the
	# Oyster is back, still tapped.
	var oyster := put_battlefield(0, "Giant Oyster")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.tap_permanent(bear)
	assert_ok(g.activate_ability(0, oyster, 0, [TargetRef.card(bear)]))
	assert_true(g.phase_out(oyster))
	resolve_stack()
	assert_false(bear.cur_skips_untap)
	assert_true(g.phase_in(oyster, true))
	assert_true(oyster.tapped)
	assert_false(bear.cur_skips_untap, "a duration that never began doesn't start now")


# ------------------------- F2: "if you do" and the link that survives --

func test_safe_haven_phased_out_cant_be_sacrificed_so_nothing_returns() -> void:
	var haven := put_battlefield(0, "Safe Haven")
	var bear := put_battlefield(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, haven, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.EXILE)
	_upkeep_trigger(0)
	assert_true(g.phase_out(haven))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.EXILE,
		"a phased-out Haven can't be sacrificed, so \"if you do\" fails (702.26b)")
	assert_eq(haven.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(haven.phased_out)
	# Phasing is no zone change (702.26d): the Haven that comes back is the
	# same object, still holding what it exiled.
	assert_true(g.phase_in(haven))
	_upkeep_trigger(0)
	resolve_stack()
	assert_eq(haven.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "the link survived the phasing")


# ------------------------------------- F2: a redirect at damage time --

func test_shimian_night_stalker_phased_out_lets_the_damage_through() -> void:
	# The replacement can't send damage to a creature that doesn't exist
	# (702.26b), so it doesn't apply and the blow lands on its player
	# (614.6) — it used to vanish into the phased-out Stalker.
	var stalker := put_battlefield(0, "Shimian Night Stalker")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.combat.attackers[bear.id] = true
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, stalker, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(g.phase_out(stalker))
	g.deal_damage(bear, TargetRef.player(0), 2, true)
	assert_eq(g.players[0].life, 18)
	assert_eq(stalker.damage, 0)


# ------------------------------- F3: an effect that names it (702.26e) --

func test_brine_hag_curse_skips_a_killer_that_phased_out() -> void:
	# "Change the base power and toughness of all creatures that dealt
	# damage to it this turn to 0/2. (This effect lasts indefinitely.)"
	var hag := put_battlefield(1, "Brine Hag")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.deal_damage(bear, TargetRef.card(hag), 2)
	g.check_state_based_actions()
	assert_eq(hag.zone, Mtg.Zone.GRAVEYARD)
	assert_false(g.stack.is_empty(), "the Hag's death trigger is waiting")
	assert_true(g.phase_out(bear))
	resolve_stack()
	assert_true(g.phase_in(bear))
	assert_eq(bear.cur_power, 2, "a resolving effect never included it (702.26e)")
	assert_eq(bear.cur_toughness, 2)


func test_dragon_whelp_pump_does_not_include_a_phased_out_whelp() -> void:
	var whelp := put_battlefield(0, "Dragon Whelp")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, whelp, 0))
	assert_true(g.phase_out(whelp))
	resolve_stack()
	assert_true(g.phase_in(whelp))
	assert_eq(whelp.cur_power, 2, "+1/+0 never included it, not even once back (702.26e)")


# ------------------------------------------------ F4: a roster of tokens --

func test_tetravus_keeps_a_phased_out_tetravite_but_cannot_absorb_it() -> void:
	var tetravus := put_battlefield(0, "Tetravus")
	g.remove_counters(tetravus, "+1/+1", int(tetravus.counters.get("+1/+1", 0)))
	g.add_counters(tetravus, "+1/+1", 2)
	_upkeep_trigger(0)
	resolve_stack()   # the heuristic sends both counters out as Tetravites
	var brood: Array[CardInstance] = []
	for inst in g.players[0].battlefield:
		if inst.is_token:
			brood.append(inst)
	assert_eq(brood.size(), 2)
	assert_eq(int(tetravus.counters.get("+1/+1", 0)), 0)
	var stray := brood[0]
	g.change_control(stray, 1)   # a stray is what the heuristic absorbs
	assert_true(g.phase_out(stray))
	_upkeep_trigger(0)
	resolve_stack()
	assert_true(stray.phased_out, "a phased-out token can't be exiled (702.26b)")
	assert_eq(int(tetravus.counters.get("+1/+1", 0)), 0,
		"and so no counter is put on Tetravus for it")
	# Phasing is no zone change (702.26d): back in, it is still a token
	# "created with this creature".
	assert_true(g.phase_in(stray))
	_upkeep_trigger(0)
	_resolve_one()   # the absorb trigger, above the budding one
	assert_ne(stray.zone, Mtg.Zone.BATTLEFIELD, "absorbed once it is back")
	assert_eq(int(tetravus.counters.get("+1/+1", 0)), 1)
	resolve_stack()


## Resolve only the top object of the stack (both players pass once).
func _resolve_one() -> void:
	var size := g.stack.size()
	var guard := 0
	while g.stack.size() >= size and guard < 4:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1


# ------------------ an upkeep trigger on the phased-out permanent itself --

func test_divine_intervention_phased_out_in_response_draws_nothing() -> void:
	var divine := put_battlefield(0, "Divine Intervention")
	g.remove_counters(divine, "intervention", 1)
	assert_eq(int(divine.counters.get("intervention", 0)), 1)
	_upkeep_trigger(0)
	assert_true(g.phase_out(divine))
	resolve_stack()
	assert_false(g.game_over, "no counter came off a phased-out enchantment (702.26b)")
	assert_eq(int(divine.counters.get("intervention", 0)), 1)


func test_thought_lash_phased_out_owes_no_cumulative_upkeep() -> void:
	# CR 702.24a: "if this permanent is on the battlefield" — a phased-out
	# one isn't, so no counter, no payment, no sacrifice and no library
	# exile. It used to exile the whole library while the sacrifice was
	# refused.
	var lash := put_battlefield(0, "Thought Lash")
	g.add_counters(lash, "age", 40)
	var library := g.players[0].library.size()
	_upkeep_trigger(0)
	assert_true(g.phase_out(lash))
	resolve_stack()
	assert_eq(g.players[0].library.size(), library)
	assert_eq(int(lash.counters.get("age", 0)), 40)
	assert_eq(lash.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(lash.phased_out)
